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
        // Pale rice-grey pigment with almost equal channels: the sun warms it, the sky cools it.
        // (The earlier face (0.72, 0.70, 0.63) and green-grey cool and under tones read khaki-olive
        // under the blue sky light: a yellowish pigment times a cyan light gives green.)
        // Round r5: face and warm raised about 3% and cooled a little (x 1.025, 1.026, 1.036) to meet
        // the reference's sunlit hanging-block face.
        // Round r8: darker and warmer (x 0.885, 0.865, 0.83 on display values), toward the Godot
        // baseline's warm beige walls (sunlit about 0.71, 0.67, 0.59).
        StoneColours { face: Vec3::new(0.650, 0.619, 0.580), warm: Vec3::new(0.676, 0.638, 0.584), cool: Vec3::new(0.587, 0.580, 0.581), under: Vec3::new(0.544, 0.542, 0.552) }
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
            // The rim edge runs straight between crossings up to a grid apart, so near a terrace
            // step a vertex at the upper level would lift the edge above the lower lawn: take the
            // lowest ground on the island within 0.7 of a grid cell (round r7).
            let mut low = field.height_at(p);
            for ring in [0.35_f32, 0.7] {
                for k in 0..8 {
                    let angle = k as f32 * std::f32::consts::FRAC_PI_4;
                    let q = p + Vec2::new(angle.cos(), angle.sin()) * grid * ring;
                    if field.sample(&field.land1, q) >= 0.5 {
                        low = low.min(field.height_at(q));
                    }
                }
            }
            Vec3::new(p.x, low - 0.30, p.y)
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
                // The lawn lip over this triangle: the highest rim corner, or the ground above its middle.
                let lip = [a, b, c].iter().map(|v| v.y + 0.30).fold(field.height_at(Vec2::new(mid.x, mid.z)), f32::max);
                let paint = Paint::new(Family::Stone)
                    .sky(if hidden { 0.70 } else { 1.0 - 0.5 * smoothstep(0.0, 10.0, depth) })
                    .line(0.9)
                    .strokes(0.8)
                    .id(40 + ((mid.x * 0.37 + mid.z * 0.91).abs() as u32 % 60) as u8)
                    .grad(if hidden { 0.6 } else { smoothstep(-1.0, 10.0, depth) })
                    .lip(lip);
                mesh.tri(a, b, c, colour, paint);
            }
        }
    }
    mesh
}

/// A hanging column: an n-sided prism whose foot is a single tilted cut and
/// whose sides lean inward as they descend. The first `front` plan edges are the block's
/// visible front (their ends and the two side faces after them sit in the joins with the
/// neighbouring blocks and are darkened there); `lip` is the lawn lip above it, for the brow.
#[allow(clippy::too_many_arguments)]
fn column(mesh: &mut Mesh, plan: &[Vec2], top: f32, depth: f32, lean_to: Vec2, taper: f32, tilt: Vec2, colour: Vec3, colours: &StoneColours, id: u8, tier: f32, ledge: bool, front: usize, lip: Option<f32>) {
    let n = plan.len();
    // Arc position of each front plan point, and the front's width.
    let mut along = vec![0.0_f32; n];
    for k in 0..front.min(n - 1) {
        along[k + 1] = along[k] + (plan[k + 1] - plan[k]).length();
    }
    let width = if front > 0 { along[front.min(n - 1)] } else { 0.0 };
    // Per edge k (plan[k] -> plan[k + 1]): the join coordinate at its two ends and the width (0: none).
    let join_of = |k: usize| -> (f32, f32, f32) {
        if front == 0 || width <= 0.0 {
            (0.0, 0.0, 0.0)
        } else if k < front {
            (along[k] / width, along[k + 1] / width, width)
        } else if k == front || k == n - 1 {
            // The side faces: wholly inside a join.
            (0.0, 0.0, width)
        } else {
            (0.0, 0.0, 0.0)
        }
    };
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
    let paint = |grad: f32, sky: f32| {
        let p = Paint::new(Family::Stone).sky(sky).line(1.0).strokes(1.0).id(id).grad(grad);
        match lip {
            Some(y) => p.lip(y),
            None => p,
        }
    };
    // A waist part of the way down: below it the rock steps in or out a little, which gives the
    // face a bedding line and breaks its height into two unequal parts.
    let salt = (centre.x * 7.3 + centre.y * 3.1).floor() as i32;
    let (w1, w2) = (hash2(salt, id as i32, 401), hash2(salt, id as i32, 402));
    let at = 0.30 + 0.34 * w1;
    // Round r8: no bedding step (the reference has no horizontal joints); the rings coincide and
    // the zero-height band between them is skipped.
    let _ = w2;
    let scale = 1.0;
    let upper: Vec<Vec3> = (0..n).map(|k| head[k].lerp(foot[k], at)).collect();
    let waist_centre = upper.iter().copied().sum::<Vec3>() / n as f32;
    let lower: Vec<Vec3> = upper.iter().map(|p| waist_centre + (*p - waist_centre) * Vec3::new(scale, 1.0, scale)).collect();
    // Colour sits heavy at the top of a face and thins toward the foot, as a wash does.
    let (c0, c1, c2) = (colour * 0.97, colour.lerp(colours.cool, 0.10), colour.lerp(colours.under, 0.25 + 0.30 * tier));
    let tone = |g: f32| if g < 0.45 { c0.lerp(c1, g / 0.45) } else { c1.lerp(c2, (g - 0.45) / 0.55) };
    let sky = |g: f32| (1.0 - 0.22 * tier) * (1.0 - 0.18 * g);
    let rings: [(&Vec<Vec3>, f32); 4] = [(&head, 0.0), (&upper, at), (&lower, at), (&foot, 1.0)];
    for r in 0..rings.len() - 1 {
        let ((a, ga), (b, gb)) = (rings[r], rings[r + 1]);
        let normals: Vec<Vec3> = (0..n).map(|k| (a[(k + 1) % n] - a[k]).cross(b[k] - a[k]).normalize_or_zero()).collect();
        // Each vertical edge takes a quarter of the neighbouring face's normal, so a face stays
        // nearly flat in the middle but its edges turn the light: a softened arris, no extra geometry.
        let soften = |own: Vec3, other: Vec3| if other == Vec3::ZERO { own } else { (own * 0.88 + other * 0.12).normalize_or_zero() };
        for k in 0..n {
            let k2 = (k + 1) % n;
            let normal = normals[k];
            if normal == Vec3::ZERO {
                continue;
            }
            let (left, right) = (soften(normal, normals[(k + n - 1) % n]), soften(normal, normals[k2]));
            let (pa, pb) = (paint(ga, sky(ga)), paint(gb, sky(gb)));
            let (u0, u1, w) = join_of(k);
            let (pa0, pa1, pb0, pb1) = (pa.join(u0, w), pa.join(u1, w), pb.join(u0, w), pb.join(u1, w));
            mesh.tri_full([a[k], a[k2], b[k2]], [left, right, right], [tone(ga), tone(ga), tone(gb)], [pa0, pa1, pb1]);
            mesh.tri_full([a[k], b[k2], b[k]], [left, right, left], [tone(ga), tone(gb), tone(gb)], [pa0, pb1, pb0]);
        }
    }
    let foot_centre = foot.iter().copied().sum::<Vec3>() / n as f32;
    for k in 0..n {
        mesh.tri(foot_centre, foot[k], foot[(k + 1) % n], colour.lerp(colours.under, 0.8), paint(1.0, 0.5));
    }
    // Every column is capped (round r7): an open top showed the column's inside wherever the lawn
    // above did not cover it (a block standing out past the outline, a block at a terrace end).
    // A ledge is the warm sunlit shelf; other caps sit under the lawn and are rarely seen.
    let head_centre = head.iter().copied().sum::<Vec3>() / n as f32;
    let cap = if ledge { colour.lerp(colours.warm, 0.25) } else { colour };
    for k in 0..n {
        let paint = Paint::new(Family::Stone).sky(1.0).line(1.0).strokes(0.5).id(id);
        mesh.tri_full([head_centre, head[(k + 1) % n], head[k]], [Vec3::Y; 3], [cap; 3], [paint; 3]);
    }
}

/// Round r8: one tall vertical block, as the Godot baseline's cliff faces are: a prism whose sides
/// run straight down from the cap (no taper, no waist, no bedding step), whose sharp corners carry
/// a narrow chamfer (the light bevel on the reference's vertical edges), capped flat at the top,
/// its foot cut on a tilted plane far down in the root mist. `plan` runs with the block's outside
/// on the left of each edge seen from above (the order `column` uses).
#[allow(clippy::too_many_arguments)]
fn tall_block(mesh: &mut Mesh, plan: &[Vec2], top: &dyn Fn(Vec2) -> f32, bottom: f32, tilt: Vec2, shift: Vec2, colour: Vec3, colours: &StoneColours, id: u8, lip: Option<f32>, cap_warm: f32, wide: (&[usize], f32, Vec2)) {
    let n0 = plan.len();
    // Chamfer every corner that turns by more than 25 degrees; the corners listed in `wide` take a
    // broader rounded bevel of `wide.1` (round r10: a rim block's front corners, see the caller).
    // `wide.2` is the block's outward direction: a broad bevel is shaded as a shallow rounded edge,
    // its normal turning from the front face's only a third of the way to the end side's.
    let mut ring: Vec<Vec2> = Vec::with_capacity(n0 * 2);
    // Whether the side from ring[k] to ring[k + 1] is a chamfer: 0 no, 1 narrow, 2 broad.
    let mut soft: Vec<u8> = Vec::with_capacity(n0 * 2);
    for k in 0..n0 {
        let (prev, p, next) = (plan[(k + n0 - 1) % n0], plan[k], plan[(k + 1) % n0]);
        let (d0, d1) = ((prev - p).normalize_or_zero(), (next - p).normalize_or_zero());
        let turn = 180.0 - d0.dot(d1).clamp(-1.0, 1.0).acos().to_degrees();
        if turn > 25.0 {
            let size = if wide.0.contains(&k) { wide.1 } else { 0.075 };
            let c = size.min((prev - p).length() * 0.3).min((next - p).length() * 0.3);
            ring.push(p + d0 * c);
            soft.push(if wide.0.contains(&k) { 2 } else { 1 });
            ring.push(p + d1 * c);
            soft.push(0);
        } else {
            ring.push(p);
            soft.push(0);
        }
    }
    let n = ring.len();
    let centre = ring.iter().copied().sum::<Vec2>() / n as f32;
    let head: Vec<Vec3> = ring.iter().map(|p| Vec3::new(p.x, top(*p), p.y)).collect();
    let foot: Vec<Vec3> = ring.iter().map(|p| Vec3::new(p.x + shift.x, bottom + (*p - centre).dot(tilt), p.y + shift.y)).collect();
    let paint = |grad: f32, sky: f32| {
        let p = Paint::new(Family::Stone).sky(sky).line(1.0).strokes(1.0).id(id).grad(grad);
        match lip {
            Some(y) => p.lip(y),
            None => p,
        }
    };
    let low = colour.lerp(colours.under, 0.18);
    let normals: Vec<Vec3> = (0..n).map(|k| (head[(k + 1) % n] - head[k]).cross(foot[k] - head[k]).normalize_or_zero()).collect();
    for k in 0..n {
        let k2 = (k + 1) % n;
        let normal = normals[k];
        if normal == Vec3::ZERO {
            continue;
        }
        // Round r10: a chamfer is shaded as a rounded edge, its normal turning from one neighbouring
        // face's to the other's. Lit flat, the chamfer at a rim face's end turned away from the sun
        // and read as a black hairline between two faces. A broad bevel (a rim block's front corner,
        // where it may stand proud of its neighbour) turns only a third of the way from the front
        // face toward the end side: with the full turn, the bevel's middle faced away from the sun,
        // took the corner's occlusion as well and still read as a dark line.
        let (prev, next) = (normals[(k + n - 1) % n], normals[k2]);
        let (na, nb) = match soft[k] {
            1 => (prev, next),
            2 => {
                let out = Vec3::new(wide.2.x, 0.0, wide.2.y);
                let (front, side) = if prev.dot(out) >= next.dot(out) { (prev, next) } else { (next, prev) };
                let partial = front.lerp(side, 0.33).normalize_or_zero();
                if front == prev { (front, partial) } else { (partial, front) }
            }
            _ => (normal, normal),
        };
        let (pt, pb) = (paint(0.0, 1.0), paint(1.0, 0.86));
        mesh.tri_full([head[k], head[k2], foot[k2]], [na, nb, nb], [colour, colour, low], [pt, pt, pb]);
        mesh.tri_full([head[k], foot[k2], foot[k]], [na, nb, na], [colour, low, low], [pt, pb, pb]);
    }
    let foot_centre = foot.iter().copied().sum::<Vec3>() / n as f32;
    for k in 0..n {
        mesh.tri(foot_centre, foot[k], foot[(k + 1) % n], colour.lerp(colours.under, 0.8), paint(1.0, 0.5));
    }
    // The cap: flat where it sits under the lawn, the sloped wedge top on a buttress slab.
    let head_centre = head.iter().copied().sum::<Vec3>() / n as f32;
    let cap = colour.lerp(colours.warm, cap_warm);
    for k in 0..n {
        let (a, b) = (head[(k + 1) % n], head[k]);
        let normal = (a - head_centre).cross(b - head_centre).normalize_or_zero();
        let normal = if normal.y < 0.0 { -normal } else { normal };
        let p = Paint::new(Family::Stone).sky(1.0).line(1.0).strokes(0.5).id(id).grad(0.0);
        mesh.tri_full([head_centre, a, b], [normal; 3], [cap; 3], [p; 3]);
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
            let mut thick: f32 = 2.4 + 1.6 * h1 + if face.role == Role::Primary { 0.8 } else { 0.0 };
            // The block reaches back only as far as the ground over it stays at its top: a pond or
            // a lower terrace behind the rim would otherwise show its top through the bed or lawn.
            for start in [face.a, mid, face.b] {
                let mut d = 0.25;
                while d < thick + 0.3 {
                    if field.height_at(start - out * d) < face.top - 0.12 {
                        thick = thick.min((d - 0.35).max(0.6));
                        break;
                    }
                    d += 0.25;
                }
            }
            // Round r8, after the Godot baseline's cliff columns: each rim face is one tall vertical
            // face from just under the lawn's lip down into the root mist, crisp at its edges, set
            // forward or back of its neighbours by its role (a narrow face stands back as a recess),
            // turned by a degree or two at most. The shelves, shoulders, waists and bedding steps of
            // earlier rounds are gone.
            let front = face.step - 0.12;
            let side = 0.22;
            let turn = (h2 - 0.5) * 0.05;
            let (a, b) = (face.a - chord * side + out * (front - turn * face.width * 0.5), face.b + chord * side + out * (front + turn * face.width * 0.5));
            // Only a very broad face is folded once, gently, so it is not one flat card.
            let mut plan = vec![a];
            if face.width > 5.0 {
                let t = 0.35 + 0.3 * hash2(key.0, key.1, seed ^ 84);
                let push = (hash2(key.0, key.1 + 1, seed ^ 85) - 0.5) * 0.30;
                plan.push(a.lerp(b, t) + out * push);
            }
            plan.extend([b, b - out * thick + chord * 0.2 * (h3 - 0.3), a - out * thick - chord * 0.2 * (h1 - 0.3)]);
            let tone = 1.0 + (h3 - 0.5) * 0.06;
            let colour = colours.face * tone;
            // The foot: 7.6 to 9.4 m under the cap, cut a little out of level; it lies in the mist.
            let cap = face.top - 0.20;
            let tilt = (-out) * (0.04 + 0.05 * h2) + chord * (h1 - 0.5) * 0.10;
            // Round r10: the two front corners take a 0.20 m rounded bevel. Neighbouring blocks
            // overlap 0.22 m along the rim and stand up to about 0.2 m forward or back of each other;
            // with the narrow chamfer the forward block's end side showed in the step, turned from
            // the sun, as a black hairline. The bevel spans the step and is shaded as a shallow rounded
            // edge (see `tall_block`), so the joint reads as a soft
            // rounded edge of shaded stone.
            let corners = [0, plan.len() - 3];
            tall_block(&mut mesh, &plan, &|_| cap, cap - 7.6 - 1.8 * h2, tilt, Vec2::ZERO, colour, colours, 100 + (index % 70) as u8, Some(face.top), 0.0, (&corners, 0.20, out));
            columns += 1;
        }
        // Buttress slabs (Godot's shoulder groups): a few broad slabs standing against the wall,
        // each with one broad wedge top sloping out, its top well under the lawn's edge, standing a
        // metre or two proud, leaning a little. A face offers one when it is broad enough; of two
        // neighbours that both offer, the one with the higher world-anchored number keeps it (one
        // hop, so an edit changes slabs only near itself). About one every 8 to 12 m of rim.
        let nf = faces.len();
        let offer = |i: usize| -> Option<f32> {
            let f = &faces[i];
            let mid = (f.a + f.b) * 0.5;
            let key = ((mid.x * 0.5 + 0.137).floor() as i32, (mid.y * 0.5 + 0.291).floor() as i32);
            let h = hash2(key.0, key.1, seed ^ 87);
            let wide = f.width >= 3.4 || (f.width >= 2.8 && h > 0.85);
            (wide && f.role != Role::Secondary && h > 0.42 && field.notch(mid) < 0.05 && field.notch(f.a) < 0.05 && field.notch(f.b) < 0.05).then_some(h)
        };
        for i in 0..nf {
            let Some(h) = offer(i) else { continue };
            if offer((i + nf - 1) % nf).is_some_and(|o| o > h) || offer((i + 1) % nf).is_some_and(|o| o > h) {
                continue;
            }
            let face = &faces[i];
            let chord = (face.b - face.a).normalize_or_zero();
            let out = Vec2::new(chord.y, -chord.x);
            let mid = (face.a + face.b) * 0.5;
            let out = if field.sample(&field.land2, mid + out) < field.sample(&field.land2, mid - out) { out } else { -out };
            let key = ((mid.x * 0.5 + 0.137).floor() as i32, (mid.y * 0.5 + 0.291).floor() as i32);
            let (s1, s2, s3, s4) = (hash2(key.0, key.1, seed ^ 88), hash2(key.0, key.1, seed ^ 89), hash2(key.0, key.1, seed ^ 90), hash2(key.0, key.1, seed ^ 96));
            let width = (face.width * (0.92 + 0.25 * s1)).clamp(3.8, 6.0).min(face.width + 1.2);
            let centre = mid + chord * (s2 - 0.5) * (face.width - width * 0.8).max(0.0) * 0.5;
            let wall = face.step - 0.12;
            let proud = 0.85 + 0.6 * s3;
            // `across` runs so that the outside lies on the left of fa -> fb (the order `tall_block` wants).
            let yaw = (s4 - 0.5) * 0.36;
            let across0 = Vec2::new(-out.y, out.x);
            let across = Vec2::new(across0.x * yaw.cos() - across0.y * yaw.sin(), across0.x * yaw.sin() + across0.y * yaw.cos());
            let ahead = Vec2::new(across.y, -across.x);
            let (fa, fb) = (centre - across * width * 0.5 + ahead * (wall + proud), centre + across * width * 0.5 + ahead * (wall + proud));
            let (ba, bb) = (centre - across * width * 0.5 + ahead * (wall - 0.7), centre + across * width * 0.5 + ahead * (wall - 0.7));
            let plan = [fa, fb, bb, ba];
            // Top 1.5 to 3.5 m under the lawn's edge at the wall, falling outward 34 to 48 degrees.
            let back_top = face.top - 1.5 - 2.0 * s1 * s2.max(0.4);
            let slope = (34.0 + 14.0 * s2).to_radians().tan();
            let base = centre + ahead * wall;
            // The wedge: the top also falls along the slab's length (16 to 30 degrees, either way), so
            // the front is a trapezoid with one high and one low shoulder.
            let along = (16.0 + 14.0 * s3).to_radians().tan() * if s4 < 0.5 { 1.0 } else { -1.0 };
            let top = move |p: Vec2| back_top - ((p - base).dot(ahead)).max(0.0) * slope - ((p - centre).dot(across) + width * 0.5 * along.signum()) * along * 0.7;
            let height = 3.8 + 1.4 * s4;
            // Leaning against the wall: the foot stands 0.25 to 0.55 m farther out than the top, and
            // steps a little sideways.
            let lean = across * (s3 - 0.5) * 0.10 + ahead * (0.25 + 0.30 * s1);
            let colour = colours.face.lerp(colours.warm, 0.15) * (1.0 + (s1 - 0.5) * 0.05);
            tall_block(&mut mesh, &plan, &top, back_top - height, Vec2::new(0.0, 0.0), lean, colour, colours, 30 + (i % 9) as u8, Some(face.top), 0.0, (&[], 0.0, Vec2::ZERO));
            columns += 1;
        }
        // Where the rim steps down (a terrace wall reaching the outline, a pond's bank), a face's
        // block stands at the lowest ground along it, so under the higher lawn's lip there would be a
        // gap into the island's inside. A sheer skirt of rock at the outline closes it, from just
        // under the lip down past the block's top.
        for face in &faces {
            rim_skirt(&mut mesh, outer, field, colours, face);
        }
        // Tier two: deeper masses behind the rim, on a jittered lattice, hanging below the liner.
        // Round r8: fewer and larger, so the underside reads as a few soft masses in the mist.
        let lattice = 5.2;
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
                let radius = 2.4 + 1.4 * h4;
                let spin = h3 * std::f32::consts::TAU;
                let plan: Vec<Vec2> = (0..sides)
                    .map(|k| {
                        let angle = spin + k as f32 / sides as f32 * std::f32::consts::TAU;
                        let wobble = 0.82 + 0.36 * hash2(i * 7 + k as i32, j * 5 - k as i32, seed ^ 95);
                        centre + Vec2::new(angle.cos(), angle.sin()) * radius * wobble
                    })
                    .collect();
                // Under the lowest ground anywhere over the column, not only at its corners: a pond
                // or a lower terrace inside the plan would otherwise show the column's top through it.
                let mut top = plan.iter().map(|p| field.height_at(*p)).fold(f32::MAX, f32::min);
                for ring in 0..3 {
                    for k in 0..12 {
                        let angle = k as f32 / 12.0 * std::f32::consts::TAU;
                        top = top.min(field.height_at(centre + Vec2::new(angle.cos(), angle.sin()) * radius * 1.2 * ring as f32 / 2.0));
                    }
                }
                let top = top - 0.55;
                let far = smoothstep(0.52, 0.97, field.sample(&field.land3, centre));
                // Feet about 2 to 3 m under the root mist's full level, so the underside ends evenly.
                let depth_to = (underside(field, centre, seed) + 2.0 + 1.6 * h4 + 1.5 * far * h1).min(top + 8.0 + 1.0 * h4);
                let lean = centre + field.inward(centre) * 4.0;
                let tilt = Vec2::new(h1 - 0.5, h2 - 0.5) * 0.7;
                let tier = 0.55 + 0.45 * far;
                let colour = colours.face.lerp(colours.cool, 0.30 + 0.25 * far) * (1.0 + (h2 - 0.5) * 0.08);
                column(&mut mesh, &plan, top, top + depth_to, lean, 0.62 + 0.14 * h3, tilt, colour, colours, 170 + ((i * 3 + j * 5).rem_euclid(80)) as u8, tier, false, 0, None);
                columns += 1;
            }
        }
    }
    // Holes through the island (cells missing inside it, as on layout 913): a stone-lined pit
    // under the lawn lip with a floor, as the frozen project shows, instead of a view into the
    // unlit inside of the liner.
    for hole in outlines.iter().filter(|o| o.is_hole) {
        line_hole(&mut mesh, hole, field, colours, seed);
    }
    Body { mesh, faces, columns }
}

/// The skirt under one face's stretch of outline: wherever the lawn's lip stands higher than the
/// face's block top, a vertical band of rock from 0.22 m under the lip (behind the lip's 0.32 m
/// roll) down to 0.28 m under the block top. Zero height (and not emitted) on a level rim.
fn rim_skirt(mesh: &mut Mesh, outer: &Outline, field: &Field, colours: &StoneColours, face: &Face) {
    let n = outer.points.len();
    let bottom = face.top - 0.28;
    let count = (face.to + n - face.from) % n;
    const SUB: usize = 4;
    let sample = |k: usize, t: f32| -> (Vec2, Vec2, f32) {
        let (a, b) = (outer.points[k % n], outer.points[(k + 1) % n]);
        let p = a.lerp(b, t);
        let out = outer.outward[k % n].lerp(outer.outward[(k + 1) % n], t).normalize_or_zero();
        (p, out, field.height_at(p) - 0.22)
    };
    for step in 0..count {
        let k = face.from + step;
        for s in 0..SUB {
            let (p0, o0, y0) = sample(k, s as f32 / SUB as f32);
            let (p1, o1, y1) = sample(k, (s + 1) as f32 / SUB as f32);
            if y0.max(y1) < bottom + 0.06 {
                continue;
            }
            let (y0, y1) = (y0.max(bottom), y1.max(bottom));
            let (q0, q1) = (p0 + o0 * 0.045, p1 + o1 * 0.045);
            let quad = [Vec3::new(q0.x, y0, q0.y), Vec3::new(q1.x, y1, q1.y), Vec3::new(q1.x, bottom, q1.y), Vec3::new(q0.x, bottom, q0.y)];
            let (n0, n1) = (Vec3::new(o0.x, 0.0, o0.y), Vec3::new(o1.x, 0.0, o1.y));
            let lip = y0.max(y1) + 0.22;
            let top = Paint::new(Family::Stone).sky(0.86).line(0.9).strokes(0.8).id(4).grad(0.0).lip(lip);
            let low = Paint::new(Family::Stone).sky(0.80).line(0.9).strokes(0.8).id(4).grad(0.3).lip(lip);
            let (ct, cb) = (colours.face, colours.face.lerp(colours.cool, 0.15));
            mesh.tri_full([quad[0], quad[1], quad[2]], [n0, n1, n1], [ct, ct, cb], [top, top, low]);
            mesh.tri_full([quad[0], quad[2], quad[3]], [n0, n1, n0], [ct, cb, cb], [top, low, low]);
        }
    }
}

fn line_hole(mesh: &mut Mesh, hole: &Outline, field: &Field, colours: &StoneColours, seed: u32) {
    let n = hole.points.len();
    let deep = 3.2;
    let centre = hole.points.iter().copied().sum::<Vec2>() / n as f32;
    let rim = |k: usize| {
        let p = hole.points[k];
        let lip = field.height_at(p - hole.outward[k] * 0.6);
        (Vec3::new(p.x, lip - 0.30, p.y), lip)
    };
    let floor_y = (0..n).map(|k| rim(k).1).fold(f32::MAX, f32::min) - deep;
    let mut along = 0.0_f32;
    for k in 0..n {
        let k2 = (k + 1) % n;
        let ((a, lip_a), (b, lip_b)) = (rim(k), rim(k2));
        let (fa, fb) = (Vec3::new(a.x, floor_y, a.z), Vec3::new(b.x, floor_y, b.z));
        // Facing into the hole; the wall tips back a little toward the island as it rises.
        let normal = Vec3::new(hole.outward[k].x + hole.outward[k2].x, 0.0, hole.outward[k].y + hole.outward[k2].y).normalize_or_zero();
        let tone = 0.96 + 0.08 * hash2((along * 0.8) as i32, 3, seed ^ 41);
        let lip = 0.5 * (lip_a + lip_b);
        let top = Paint::new(Family::Stone).sky(0.78).id(36).grad(0.1).lip(lip);
        let low = Paint::new(Family::Stone).sky(0.45).id(36).grad(0.9).lip(lip);
        let (ct, cb) = (colours.face * tone, colours.face.lerp(colours.under, 0.6) * tone);
        mesh.tri_full([a, b, fb], [normal; 3], [ct, ct, cb], [top, top, low]);
        mesh.tri_full([a, fb, fa], [normal; 3], [ct, cb, cb], [top, low, low]);
        along += (b - a).length();
    }
    let floor = Paint::new(Family::Stone).sky(0.40).id(37);
    let fc = Vec3::new(centre.x, floor_y, centre.y);
    for k in 0..n {
        let (a, b) = (rim(k).0, rim((k + 1) % n).0);
        mesh.tri_full([fc, Vec3::new(b.x, floor_y, b.z), Vec3::new(a.x, floor_y, a.z)], [Vec3::Y; 3], [colours.under; 3], [floor; 3]);
    }
}
