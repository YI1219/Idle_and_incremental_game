//! Study S4: constructions for the island's body (everything below the lawn).
//!
//! Two constructions share one rim plan:
//!   `Hull`  : a faceted inverted terrain, one closed surface under the island.
//!   `Karst` : the same hull as a liner, plus hanging rock columns in two tiers,
//!             rim faces in a deliberate rhythm in front and deeper masses behind.
//! Every decision reads only the smooth fields within a few metres, so an edit
//! changes the body only near itself.
use glam::{Vec2, Vec3};

use crate::field::{Field, Outline};
use crate::mesh::{hash2, smoothstep, vnoise, Family, Mesh, Paint};

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Kind {
    Hull,
    Karst,
}

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Role {
    Primary,
    Secondary,
    Plain,
}

#[derive(Clone, Debug)]
pub struct Face {
    pub from: usize,
    pub to: usize,
    pub a: Vec2,
    pub b: Vec2,
    pub width: f32,
    pub role: Role,
    /// How far the face stands outside (+) or inside (-) the outline.
    pub step: f32,
    pub depth: f32,
    pub top: f32,
}

#[derive(Clone, Copy)]
pub struct StoneColours {
    pub face: Vec3,
    pub warm: Vec3,
    pub cool: Vec3,
    pub under: Vec3,
}

impl Default for StoneColours {
    fn default() -> StoneColours {
        StoneColours { face: Vec3::new(0.72, 0.70, 0.63), warm: Vec3::new(0.78, 0.73, 0.62), cool: Vec3::new(0.59, 0.65, 0.66), under: Vec3::new(0.50, 0.56, 0.60) }
    }
}

/// Underside depth of the liner at a point: shallow under the rim, deep under
/// the middle of wide parts, so the body reads as an inverted mountain.
pub fn underside(field: &Field, p: Vec2, seed: u32) -> f32 {
    let near = smoothstep(0.50, 0.96, field.sample(&field.land2, p));
    let far = smoothstep(0.52, 0.97, field.sample(&field.land3, p));
    let ridge = vnoise(p.x * 0.16, p.y * 0.16, seed ^ 51) - 0.5;
    2.2 + 4.8 * near + 8.5 * far * far + ridge * 2.4 * (0.3 + far)
}

/// Splits the outline into faces. A point becomes a break when its score is
/// the highest within its own window: corners and changes of rim height score
/// high, and a world-anchored hash supplies the irregular rhythm in between.
/// Outline points are world-anchored and unevenly spaced, so every length here is
/// arc length in metres, never a count of points.
pub fn plan_faces(outline: &Outline, field: &Field, seed: u32, _spacing: f32) -> Vec<Face> {
    plan_traced(outline, field, seed, &mut Vec::new())
}

/// `plan_faces`, also recording the break positions after each stage (break set, split, pairing).
pub fn plan_traced(outline: &Outline, field: &Field, seed: u32, trace: &mut Vec<Vec<Vec2>>) -> Vec<Face> {
    let n = outline.points.len();
    let ni = n as isize;
    let wrap = |k: isize| k.rem_euclid(ni) as usize;
    let at = |k: isize| outline.points[wrap(k)];
    let seg: Vec<f32> = (0..n).map(|k| (outline.points[(k + 1) % n] - outline.points[k]).length()).collect();
    let total: f32 = seg.iter().sum();
    // Forward arc length from one point to another, summed locally so it does not depend on where the
    // loop starts (a difference of running sums carries rounding from the whole loop and flips
    // thresholds such as "at least 2 m" that sit on multiples of the lattice). A full loop when equal.
    let ahead = |from: usize, to: usize| {
        if from == to {
            return total;
        }
        let (mut k, mut sum) = (from, 0.0_f32);
        while k != to {
            sum += seg[k];
            k = (k + 1) % n;
        }
        sum
    };
    // The point nearest to a signed arc offset `d` from point `k`.
    let offset = |k: usize, d: f32| -> usize {
        let dir: isize = if d >= 0.0 { 1 } else { -1 };
        let (mut j, mut walked) = (k as isize, 0.0_f32);
        loop {
            let next = j + dir;
            let seg = (at(next) - at(j)).length();
            if walked + seg >= d.abs() {
                return if d.abs() - walked < walked + seg - d.abs() { wrap(j) } else { wrap(next) };
            }
            walked += seg;
            j = next;
            if (j - k as isize).abs() >= ni {
                return wrap(j);
            }
        }
    };
    let rim_height = |k: usize| field.height_at(outline.points[k] - outline.outward[k] * 0.7);
    // Hash keys carry a fixed offset: the points lie exactly on lattice lines, where floor can flip.
    let cell = |p: Vec2, k: f32| ((p.x * k + 0.137).floor() as i32, (p.y * k + 0.291).floor() as i32);
    let mut score = vec![0.0_f32; n];
    let mut window = vec![0.0_f32; n];
    let mut tie = vec![0.0_f32; n];
    for k in 0..n {
        let p = outline.points[k];
        let (d0, d1) = ((p - outline.points[offset(k, -1.5)]).normalize_or_zero(), (outline.points[offset(k, 1.5)] - p).normalize_or_zero());
        // A dead zone of one degree: on a straight stretch the turn is float noise, and two points in
        // the same hash cell would then be ranked by that noise.
        let turn = (d0.perp_dot(d1).abs().clamp(0.0, 1.0).asin().to_degrees() - 1.0).max(0.0);
        let jump = (rim_height(offset(k, 0.5)) - rim_height(offset(k, -0.5))).abs();
        let c1 = cell(p, 1.0);
        score[k] = hash2(c1.0, c1.1, seed ^ 61) + 0.7 * (turn / 40.0).min(1.0) + if jump > 0.3 { 2.0 } else { 0.0 };
        let c4 = cell(p, 4.0);
        tie[k] = hash2(c4.0, c4.1, seed ^ 66);
        let c5 = cell(p, 0.2);
        let coarse = hash2(c5.0, c5.1, seed ^ 62);
        // Windows of 2 to 6 metres either side give faces from about 2.5 to 12 metres.
        window[k] = 2.0 + 4.0 * coarse * coarse;
    }
    let mut breaks: Vec<usize> = Vec::new();
    for k in 0..n {
        let (w, mine) = (window[k], score[k]);
        // Ties go to a fine world-anchored hash first; the index (which shifts when the loop changes) is last.
        let beats = |j: usize| score[j] > mine || (score[j] == mine && (tie[j] > tie[k] || (tie[j] == tie[k] && j < k)));
        let mut best = true;
        let mut j = k;
        loop {
            j = (j + 1) % n;
            if j == k || ahead(k, j) > w {
                break;
            }
            if beats(j) {
                best = false;
                break;
            }
        }
        if best {
            j = k;
            loop {
                j = (j + n - 1) % n;
                if j == k || ahead(j, k) > w {
                    break;
                }
                if beats(j) {
                    best = false;
                    break;
                }
            }
        }
        if best {
            breaks.push(k);
        }
    }
    if breaks.len() < 3 {
        breaks = (0..6).map(|i| offset(0, i as f32 * total / 6.0)).collect();
    }
    trace.push(breaks.iter().map(|&k| outline.points[k]).collect());
    // A long face over a curved rim would cut far inside the lawn: split it where it sags most.
    let mut changed = true;
    while changed {
        changed = false;
        let mut next = Vec::with_capacity(breaks.len() + 4);
        for i in 0..breaks.len() {
            let (from, to) = (breaks[i], breaks[(i + 1) % breaks.len()]);
            next.push(from);
            let count = (to + n - from) % n;
            let (a, b) = (outline.points[from], outline.points[to]);
            let chord = (b - a).normalize_or_zero();
            let (mut worst, mut worst_at) = (0.0_f32, 0usize);
            for step in 1..count {
                let p = outline.points[(from + step) % n];
                let sag = (p - a).perp_dot(chord).abs();
                if sag > worst {
                    worst = sag;
                    worst_at = (from + step) % n;
                }
            }
            if worst > 0.85 && ahead(from, to) > 3.0 {
                next.push(worst_at);
                changed = true;
            }
        }
        breaks = next;
    }
    trace.push(breaks.iter().map(|&k| outline.points[k]).collect());
    // Rhythm: a long face becomes a pair, one broad and one narrow, in an order chosen locally.
    // This is what keeps a gently curved rim from turning into a row of equal chords.
    // Two passes, so the broad part of a very long face is paired again and no face stays a wall.
    for pass in 0..2u32 {
        let mut paired = Vec::with_capacity(breaks.len() * 2);
        for i in 0..breaks.len() {
            let (from, to) = (breaks[i], breaks[(i + 1) % breaks.len()]);
            paired.push(from);
            let span = ahead(from, to);
            if span > if pass == 0 { 5.2 } else { 6.2 } {
                let key = cell(outline.points[from], 0.5);
                let h = hash2(key.0, key.1, seed ^ (65 + pass));
                let share = if h < 0.5 { 0.24 + 0.16 * h } else { 0.60 + 0.16 * h };
                let cut = offset(from, span * share);
                let first = if cut == from { 0.0 } else { ahead(from, cut) };                if first >= 2.0 && span - first >= 2.0 {
                    paired.push(cut);
                }
            }
        }
        breaks = paired;
    }
    trace.push(breaks.iter().map(|&k| outline.points[k]).collect());
    let mut faces = Vec::with_capacity(breaks.len());
    for i in 0..breaks.len() {
        let (from, to) = (breaks[i], breaks[(i + 1) % breaks.len()]);
        let count = (to + n - from) % n;
        let (a, b) = (outline.points[from], outline.points[to]);
        let width = ahead(from, to);
        let mid = (a + b) * 0.5;
        let key = cell(mid, 0.5);
        let (h1, h2) = (hash2(key.0, key.1, seed ^ 63), hash2(key.0, key.1, seed ^ 64));
        let role = if width >= 4.8 {
            Role::Primary
        } else if width <= 3.2 {
            Role::Secondary
        } else {
            Role::Plain
        };
        let mut top = f32::MAX;
        for step in 0..=count {
            top = top.min(rim_height((from + step) % n));
        }
        let (step, depth) = match role {
            Role::Primary => (0.15 + 0.75 * h1, 5.4 + 2.8 * h2 + if h1 > 0.62 { 2.6 } else { 0.0 }),
            Role::Secondary => (-0.15 - 0.28 * h1, 2.2 + 1.6 * h2),
            Role::Plain => (-0.10 + 0.30 * h1, 3.4 + 2.2 * h2),
        };
        faces.push(Face { from, to, a, b, width, role, step, depth, top });
    }
    faces
}

/// Form metrics of a rim plan, for the tests that replace parity with Godot.
pub struct FormMetrics {
    pub faces: usize,
    pub longest_like_run: usize,
    pub longest_like_run_m: f32,
    pub width_min: f32,
    pub width_max: f32,
    pub width_spread: f32,
    pub step_spread: f32,
}

pub fn form_metrics(faces: &[Face]) -> FormMetrics {
    let n = faces.len();
    let mean = faces.iter().map(|f| f.width).sum::<f32>() / n as f32;
    let var = faces.iter().map(|f| (f.width - mean).powi(2)).sum::<f32>() / n as f32;
    let step_mean = faces.iter().map(|f| f.step).sum::<f32>() / n as f32;
    let step_var = faces.iter().map(|f| (f.step - step_mean).powi(2)).sum::<f32>() / n as f32;
    // A run is "alike" while neighbours differ by under a quarter in width and under 0.3 m in step.
    let (mut longest, mut longest_m) = (1usize, 0.0_f32);
    for start in 0..n {
        let (mut run, mut metres) = (1usize, faces[start].width);
        while run < n {
            let (a, b) = (&faces[(start + run - 1) % n], &faces[(start + run) % n]);
            if (a.width - b.width).abs() / a.width.max(b.width) > 0.25 || (a.step - b.step).abs() > 0.30 {
                break;
            }
            metres += b.width;
            run += 1;
        }
        if run > longest {
            longest = run;
            longest_m = metres;
        }
    }
    FormMetrics {
        faces: n,
        longest_like_run: longest,
        longest_like_run_m: longest_m,
        width_min: faces.iter().map(|f| f.width).fold(f32::MAX, f32::min),
        width_max: faces.iter().map(|f| f.width).fold(0.0, f32::max),
        width_spread: var.sqrt() / mean,
        step_spread: step_var.sqrt(),
    }
}

/// The liner: a low-polygon inverted terrain under the whole island, with a
/// wall of facets from just under the lip down to its first inner row.
pub fn build_hull(field: &Field, colours: &StoneColours, seed: u32, grid: f32, hidden: bool) -> Mesh {
    let mut mesh = Mesh::default();
    let cols = ((field.nx as f32 * crate::field::STEP) / grid) as i32 + 1;
    let rows = ((field.nz as f32 * crate::field::STEP) / grid) as i32 + 1;
    let vertex = |i: i32, j: i32| -> Vec2 {
        let jitter = Vec2::new(hash2(i, j, seed ^ 71) - 0.5, hash2(i, j, seed ^ 72) - 0.5) * grid * 0.55;
        field.origin + Vec2::new(i as f32, j as f32) * grid + jitter
    };
    // As a liner behind hanging rock the hull sits well inside the rim, so recessed faces stay in front of it.
    let level = if hidden { 0.90 } else { 0.60 };
    let place = |p: Vec2, on_rim: bool| -> Vec3 {
        if on_rim {
            Vec3::new(p.x, field.height_at(p) - 0.30, p.y)
        } else {
            Vec3::new(p.x, -underside(field, p, seed), p.y)
        }
    };
    for j in 0..rows {
        for i in 0..cols {
            let corners = [vertex(i, j), vertex(i, j + 1), vertex(i + 1, j + 1), vertex(i + 1, j)];
            let values = corners.map(|p| field.sample(&field.land1, p) - level);
            if values.iter().all(|v| *v < 0.0) {
                continue;
            }
            let mut polygon: Vec<Vec3> = Vec::with_capacity(6);
            for k in 0..4 {
                let (pa, pb) = (corners[k], corners[(k + 1) % 4]);
                let (va, vb) = (values[k], values[(k + 1) % 4]);
                if va >= 0.0 {
                    polygon.push(place(pa, false));
                }
                if (va >= 0.0) != (vb >= 0.0) {
                    polygon.push(place(pa.lerp(pb, va / (va - vb)), true));
                }
            }
            for k in 1..polygon.len().saturating_sub(1) {
                let (a, b, c) = (polygon[0], polygon[k + 1], polygon[k]);
                let mid = (a + b + c) / 3.0;
                let depth = (-mid.y).max(0.0);
                let tone = hash2((mid.x * 0.7) as i32, (mid.z * 0.7) as i32, seed ^ 73) - 0.5;
                let colour = if hidden { (colours.face * 0.90).lerp(colours.under, 0.25 + 0.6 * smoothstep(0.0, 8.0, depth)) } else { colours.face.lerp(colours.under, smoothstep(1.0, 9.0, depth)) } * (1.0 + tone * 0.08);
                let paint = Paint::new(Family::Stone)
                    .sky(if hidden { 0.70 } else { 1.0 - 0.5 * smoothstep(0.0, 10.0, depth) })
                    .line(0.9)
                    .strokes(0.8)
                    .id(40 + ((mid.x * 0.37 + mid.z * 0.91).abs() as u32 % 60) as u8)
                    .grad(if hidden { 0.6 } else { smoothstep(-1.0, 10.0, depth) });
                mesh.tri(a, b, c, colour, paint);
            }
        }
    }
    mesh
}

/// A hanging column: an n-sided prism whose foot is a single tilted cut and
/// whose sides lean inward as they descend.
#[allow(clippy::too_many_arguments)]
fn column(mesh: &mut Mesh, plan: &[Vec2], top: f32, depth: f32, lean_to: Vec2, taper: f32, tilt: Vec2, colour: Vec3, colours: &StoneColours, id: u8, tier: f32, ledge: bool) {
    let n = plan.len();
    let centre = plan.iter().copied().sum::<Vec2>() / n as f32;
    let pivot = centre.lerp(lean_to, 0.5);
    let foot: Vec<Vec3> = plan
        .iter()
        .map(|p| {
            let q = pivot + (*p - pivot) * taper;
            Vec3::new(q.x, top - depth + (q - centre).dot(tilt), q.y)
        })
        .collect();
    let head: Vec<Vec3> = plan.iter().map(|p| Vec3::new(p.x, top, p.y)).collect();
    let paint = |grad: f32, sky: f32| Paint::new(Family::Stone).sky(sky).line(1.0).strokes(1.0).id(id).grad(grad);
    // A waist part of the way down: below it the rock steps in or out a little, which gives the
    // face a bedding line and breaks its height into two unequal parts.
    let salt = (centre.x * 7.3 + centre.y * 3.1).floor() as i32;
    let (w1, w2) = (hash2(salt, id as i32, 401), hash2(salt, id as i32, 402));
    let at = 0.30 + 0.34 * w1;
    let scale = if w2 < 0.5 { 0.90 + 0.06 * w2 } else { 1.02 + 0.06 * (w2 - 0.5) };
    let upper: Vec<Vec3> = (0..n).map(|k| head[k].lerp(foot[k], at)).collect();
    let waist_centre = upper.iter().copied().sum::<Vec3>() / n as f32;
    let lower: Vec<Vec3> = upper.iter().map(|p| waist_centre + (*p - waist_centre) * Vec3::new(scale, 1.0, scale)).collect();
    // Colour sits heavy at the top of a face and thins toward the foot, as a wash does.
    let (c0, c1, c2) = (colour * 0.90, colour.lerp(colours.cool, 0.12), colour.lerp(colours.under, 0.30 + 0.30 * tier) * 1.06);
    let tone = |g: f32| if g < 0.45 { c0.lerp(c1, g / 0.45) } else { c1.lerp(c2, (g - 0.45) / 0.55) };
    let sky = |g: f32| (1.0 - 0.22 * tier) * (1.0 - 0.38 * g);
    let rings: [(&Vec<Vec3>, f32); 4] = [(&head, 0.0), (&upper, at), (&lower, at), (&foot, 1.0)];
    for r in 0..rings.len() - 1 {
        let ((a, ga), (b, gb)) = (rings[r], rings[r + 1]);
        for k in 0..n {
            let k2 = (k + 1) % n;
            let normal = (a[k2] - a[k]).cross(b[k] - a[k]).normalize_or_zero();
            if normal == Vec3::ZERO {
                continue;
            }
            let (pa, pb) = (paint(ga, sky(ga)), paint(gb, sky(gb)));
            mesh.tri_full([a[k], a[k2], b[k2]], [normal; 3], [tone(ga), tone(ga), tone(gb)], [pa, pa, pb]);
            mesh.tri_full([a[k], b[k2], b[k]], [normal; 3], [tone(ga), tone(gb), tone(gb)], [pa, pb, pb]);
        }
    }
    let foot_centre = foot.iter().copied().sum::<Vec3>() / n as f32;
    for k in 0..n {
        mesh.tri(foot_centre, foot[k], foot[(k + 1) % n], colour.lerp(colours.under, 0.8), paint(1.0, 0.5));
    }
    if ledge {
        let head_centre = head.iter().copied().sum::<Vec3>() / n as f32;
        for k in 0..n {
            mesh.tri(head_centre, head[(k + 1) % n], head[k], colour.lerp(colours.warm, 0.25), Paint::new(Family::Stone).sky(1.0).line(1.0).strokes(0.5).id(id));
        }
    }
}

pub struct Body {
    pub mesh: Mesh,
    pub faces: Vec<Face>,
    pub columns: usize,
}

pub fn build_body(kind: Kind, field: &Field, outlines: &[Outline], colours: &StoneColours, seed: u32, spacing: f32) -> Body {
    let mut mesh = build_hull(field, colours, seed, if kind == Kind::Hull { 2.4 } else { 2.0 }, kind == Kind::Karst);
    let Some(outer) = outlines.iter().find(|o| !o.is_hole) else {
        return Body { mesh, faces: Vec::new(), columns: 0 };
    };
    let faces = plan_faces(outer, field, seed, spacing);
    let mut columns = 0;
    if kind == Kind::Karst {
        // Tier one: the rim faces, each the front of a hanging block.
        for (index, face) in faces.iter().enumerate() {
            let chord = (face.b - face.a).normalize_or_zero();
            let out = Vec2::new(chord.y, -chord.x);
            let mid = (face.a + face.b) * 0.5;
            // Outward must point away from the island at the middle of the face.
            let out = if field.sample(&field.land2, mid + out) < field.sample(&field.land2, mid - out) { out } else { -out };
            let key = ((mid.x * 0.5 + 0.137).floor() as i32, (mid.y * 0.5 + 0.291).floor() as i32);
            let (h1, h2, h3) = (hash2(key.0, key.1, seed ^ 81), hash2(key.0, key.1, seed ^ 82), hash2(key.0, key.1, seed ^ 83));
            let thick = 2.4 + 1.6 * h1 + if face.role == Role::Primary { 0.8 } else { 0.0 };
            let front = face.step - 0.12;
            let side = 0.22;
            let turn = (h2 - 0.5) * 0.14;
            let (a, b) = (face.a - chord * side + out * (front - turn * face.width * 0.5), face.b + chord * side + out * (front + turn * face.width * 0.5));
            // A broad face is folded once or twice so it turns in the light instead of lying flat.
            let mut plan = vec![a];
            let folds = if face.width > 4.6 { 1 } else { 0 };
            for fold in 0..folds {
                let t = (fold as f32 + 0.35 + 0.5 * hash2(key.0 + fold, key.1, seed ^ 84)) / (folds as f32 + 0.6);
                let push = (hash2(key.0, key.1 + fold, seed ^ 85) - 0.5) * 0.5;
                plan.push(a.lerp(b, t.clamp(0.2, 0.8)) + out * push);
            }
            plan.extend([b, b - out * thick + chord * 0.2 * (h3 - 0.3), a - out * thick - chord * 0.2 * (h1 - 0.3)]);
            let inward = mid - out * (thick + 3.0);
            let tone = 1.0 + (h3 - 0.5) * 0.10;
            let colour = if face.role == Role::Primary { colours.face.lerp(colours.warm, 0.35) } else { colours.face } * tone;
            let tilt = (-out) * (-0.16 - 0.14 * h2) + chord * (h1 - 0.5) * 0.30;
            // Some broad faces stop short of the lawn and show a bare rock shelf under the lip.
            let shelf = if face.role == Role::Primary && h2 > 0.62 && face.width < 6.5 { 0.5 + 1.1 * h3 } else { 0.0 };
            column(&mut mesh, &plan, face.top - 0.20 - shelf, face.depth - shelf * 0.5, inward, 0.80 - 0.10 * h2, tilt, colour, colours, 100 + (index % 70) as u8, 0.0, face.step > 0.28 || shelf > 0.0);
            columns += 1;
            // And some carry a lower shoulder in front: the local protrusion of that stretch of wall.
            if face.role == Role::Primary && h3 > 0.52 && face.width > 5.5 {
                let share = 0.34 + 0.18 * h1;
                let begin = if h2 < 0.5 { 0.06 } else { 0.94 - share };
                let (s0, s1) = (face.a + (face.b - face.a) * begin, face.a + (face.b - face.a) * (begin + share));
                let stand = front + 0.55 + 0.55 * h2;
                let deep = 1.5 + 1.0 * h1;
                let shoulder = [s0 + out * stand, s1 + out * (stand - 0.25 * (h3 - 0.5)), s1 + out * (stand - deep), s0 + out * (stand - deep)];
                let drop = 1.4 + 1.8 * h1;
                let shoulder_tilt = out * (0.10 + 0.25 * h3) + chord * (h2 - 0.5) * 0.5;
                column(&mut mesh, &shoulder, face.top - 0.20 - shelf - drop, face.depth * 0.55, inward, 0.84, shoulder_tilt, colour * 1.03, colours, 30 + (index % 9) as u8, 0.0, true);
                columns += 1;
            }
        }
        // Tier two: deeper masses behind the rim, on a jittered lattice, hanging below the liner.
        let lattice = 3.4;
        let cols = ((field.nx as f32 * crate::field::STEP) / lattice) as i32 + 1;
        let rows = ((field.nz as f32 * crate::field::STEP) / lattice) as i32 + 1;
        for j in 0..rows {
            for i in 0..cols {
                let (h1, h2, h3, h4) = (hash2(i, j, seed ^ 91), hash2(i, j, seed ^ 92), hash2(i, j, seed ^ 93), hash2(i, j, seed ^ 94));
                let centre = field.origin + (Vec2::new(i as f32, j as f32) + Vec2::new(h1, h2) * 0.8) * lattice;
                let inside = field.sample(&field.land2, centre);
                if inside < 0.70 || field.sample(&field.land1, centre) < 0.9 {
                    continue;
                }
                let sides = 5 + (h3 * 2.0) as usize;
                let radius = 1.7 + 1.3 * h4;
                let spin = h3 * std::f32::consts::TAU;
                let plan: Vec<Vec2> = (0..sides)
                    .map(|k| {
                        let angle = spin + k as f32 / sides as f32 * std::f32::consts::TAU;
                        let wobble = 0.82 + 0.36 * hash2(i * 7 + k as i32, j * 5 - k as i32, seed ^ 95);
                        centre + Vec2::new(angle.cos(), angle.sin()) * radius * wobble
                    })
                    .collect();
                let top = plan.iter().map(|p| field.height_at(*p)).fold(f32::MAX, f32::min) - 0.55;
                let far = smoothstep(0.52, 0.97, field.sample(&field.land3, centre));
                let depth_to = underside(field, centre, seed) + 1.2 + 3.2 * h4 + 2.5 * far * h1;
                let lean = centre + field.inward(centre) * 4.0;
                let tilt = Vec2::new(h1 - 0.5, h2 - 0.5) * 0.7;
                let tier = 0.55 + 0.45 * far;
                let colour = colours.face.lerp(colours.cool, 0.30 + 0.25 * far) * (1.0 + (h2 - 0.5) * 0.08);
                column(&mut mesh, &plan, top, top + depth_to, lean, 0.62 + 0.14 * h3, tilt, colour, colours, 170 + ((i * 3 + j * 5).rem_euclid(80)) as u8, tier, false);
                columns += 1;
            }
        }
    }
    Body { mesh, faces, columns }
}
