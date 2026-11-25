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
    /// Round r10d: the lawn's ground colour, for the lawn over a rim block that stands forward of the outline.
    pub lawn: Vec3,
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
        StoneColours { face: Vec3::new(0.650, 0.619, 0.580), warm: Vec3::new(0.676, 0.638, 0.584), cool: Vec3::new(0.587, 0.580, 0.581), under: Vec3::new(0.544, 0.542, 0.552), lawn: crate::field::TopColours::default().lawn }
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
            // Round k5: a narrow face (under 1.6 m) stands nearly flush: recessed 0.27 to 0.55 m it was a
            // dark slot under the lawn lip that read as a pipe.
            Role::Secondary if width < 1.6 => (-0.02 - 0.06 * h1, 2.2 + 1.6 * h2),
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

/// Round k1: a point of a block's plan after its corners are rounded.
#[derive(Clone, Copy)]
struct RingPt {
    p: Vec2,
    /// Shading normal (horizontal, outward).
    n: Vec2,
    /// For a point on a rounded corner: the plan corner it replaces, that corner's mitre and the
    /// arc's radius (an inset deeper than the radius collapses onto the mitre point). Otherwise
    /// `corner` is the point itself, `mitre` its own inset direction and `radius` 0.
    corner: Vec2,
    mitre: Vec2,
    radius: f32,
    /// The arc's own radial direction (the shading normal `n` may turn less, see `CornerTurn`).
    radial: Vec2,
    /// Up to 1 in the middle of a convex arc (worn lightening), -1 at a concave corner.
    wear: f32,
}

impl RingPt {
    /// The point moved inward by `h` (the inner edge of the top's roll).
    fn inset(&self, h: f32) -> Vec2 {
        if self.radius > 0.0 && h > self.radius {
            self.corner - self.mitre * h
        } else if self.radius > 0.0 {
            self.p - self.radial * h
        } else {
            self.p - self.mitre * h
        }
    }
}

/// Round k1: a rounded corner whose shading normal turns only `frac` of the way from the front's
/// normal toward the end side's (a block end standing out into a narrow V beside its neighbour,
/// see `rim_junction`). `front_incoming`: the front is the edge that arrives at the corner.
#[derive(Clone, Copy)]
struct CornerTurn {
    at: Vec2,
    frac: f32,
    front_incoming: bool,
}

/// The vector that moves both edges at a corner (outward normals n0, n1) outward by 1 m.
fn mitre_of(n0: Vec2, n1: Vec2) -> Vec2 {
    (n0 + n1) / (1.0 + n0.dot(n1)).max(0.25)
}

/// Round k1: a plan (outside on the left of each edge seen from above, so an edge's outward normal
/// is (d.y, -d.x)) with every convex corner turning by 12 degrees or more replaced by a circular
/// arc of `segments` pieces whose normals turn smoothly from one side's to the other's; its radius
/// is `radius(corner)`, less where an edge is too short. A concave corner keeps its point, shaded
/// with the mean of its sides' normals over 0.15 m either side (a soft junction, not a crease).
/// A gentler corner keeps its point with the mean normal.
fn rounded_ring(plan: &[Vec2], edges: &Edges, segments: usize) -> Vec<RingPt> {
    let mut pts: Vec<Vec2> = Vec::with_capacity(plan.len());
    for &p in plan {
        if pts.last().map_or(true, |q: &Vec2| (p - *q).length() > 0.01) {
            pts.push(p);
        }
    }
    while pts.len() > 3 && (pts[0] - pts[pts.len() - 1]).length() <= 0.01 {
        pts.pop();
    }
    let n = pts.len();
    let mut ring = Vec::with_capacity(n * (segments + 1));
    for k in 0..n {
        let (prev, p, next) = (pts[(k + n - 1) % n], pts[k], pts[(k + 1) % n]);
        let (l0, l1) = ((p - prev).length(), (next - p).length());
        let (d0, d1) = ((p - prev) / l0, (next - p) / l1);
        let (n0, n1) = (Vec2::new(d0.y, -d0.x), Vec2::new(d1.y, -d1.x));
        let theta = d0.dot(d1).clamp(-1.0, 1.0).acos();
        let convex = n0.dot(d1) < 0.0;
        let m = mitre_of(n0, n1);
        let plain = |q: Vec2, nn: Vec2, mm: Vec2, wear: f32| RingPt { p: q, n: nn, corner: q, mitre: mm, radius: 0.0, radial: nn, wear };
        if theta < 12.0_f32.to_radians() {
            ring.push(plain(p, (n0 + n1).normalize_or_zero(), m, 0.0));
        } else if !convex {
            let s = 0.15_f32.min(0.3 * l0).min(0.3 * l1);
            ring.push(plain(p - d0 * s, n0, n0, 0.0));
            ring.push(plain(p, (n0 + n1).normalize_or_zero(), m, -1.0));
            ring.push(plain(p + d1 * s, n1, n1, 0.0));
        } else {
            let half = (theta * 0.5).tan().max(1e-3);
            let t = (edges.radius(p) * half).min(0.45 * l0).min(0.45 * l1);
            let r = t / half;
            let centre = p - d0 * t - n0 * r;
            let sign = if n0.perp_dot(n1) >= 0.0 { 1.0 } else { -1.0 };
            let turn = edges.turn.iter().find(|c| (c.at - p).length() < 1e-3).copied();
            for s in 0..=segments {
                let f = s as f32 / segments as f32;
                let nn = rotate(n0, sign * theta * f);
                let shade = match turn {
                    Some(c) if c.front_incoming => rotate(n0, sign * theta * f * c.frac),
                    Some(c) => rotate(n1, -sign * theta * (1.0 - f) * c.frac),
                    None => nn,
                };
                let wear = (std::f32::consts::PI * f).sin() * turn.map_or(1.0, |c| c.frac);
                ring.push(RingPt { p: centre + nn * r, n: shade, corner: p, mitre: m, radius: r, radial: nn, wear });
            }
        }
    }
    ring
}

/// The normal of a block's side at a ring point: horizontal along the ring, following the side's
/// lean from `head` down to `foot`.
fn side_normal(n: Vec2, head: Vec3, foot: Vec3) -> Vec3 {
    let out = Vec3::new(n.x, 0.0, n.y);
    let along = Vec3::new(-n.y, 0.0, n.x);
    let normal = along.cross(foot - head).normalize_or_zero();
    if normal == Vec3::ZERO {
        out
    } else if normal.dot(out) < 0.0 {
        -normal
    } else {
        normal
    }
}

/// The upward normal of a height function at a point.
fn height_normal(top: &dyn Fn(Vec2) -> f32, p: Vec2) -> Vec3 {
    let e = 0.05;
    let gx = (top(p + Vec2::X * e) - top(p - Vec2::X * e)) / (2.0 * e);
    let gz = (top(p + Vec2::Y * e) - top(p - Vec2::Y * e)) / (2.0 * e);
    Vec3::new(-gx, 1.0, -gz).normalize()
}

/// Round k1: how a block's edges are rounded. `corner` is the radius range of its vertical edges
/// (a world-anchored hash picks one per corner), `roll` the reach of the rounded edge along its
/// top (0: a sharp top edge), `crown` fills the top with a small grid shaded by the height
/// function's own normals (a buttress slab's sloped top) instead of a flat fan.
#[derive(Clone)]
struct Edges {
    corner: (f32, f32),
    roll: f32,
    crown: bool,
    salt: u32,
    /// Corners whose shading turns less than the geometry (see `CornerTurn`).
    turn: Vec<CornerTurn>,
    /// Round k5: corners kept nearly square (3.5 cm): where two rim blocks meet nearly flush, two
    /// rounded corners side by side carved a groove that read as a thin dark joint.
    square: Vec<Vec2>,
}

impl Edges {
    fn radius(&self, p: Vec2) -> f32 {
        if self.square.iter().any(|q| (*q - p).length() < 1e-3) {
            return 0.035;
        }
        let h = hash2((p.x * 2.7 + 0.31).floor() as i32, (p.y * 2.7 + 0.53).floor() as i32, self.salt);
        self.corner.0 + (self.corner.1 - self.corner.0) * h
    }
}

fn rotate(v: Vec2, angle: f32) -> Vec2 {
    let (s, c) = angle.sin_cos();
    Vec2::new(c * v.x - s * v.y, s * v.x + c * v.y)
}

/// How far from a convex corner `rounded_ring` starts its arc along both edges (d0 arrives at the
/// corner, d1 leaves it, l0 and l1 the edges' lengths).
fn corner_cut(edges: &Edges, p: Vec2, d0: Vec2, d1: Vec2, l0: f32, l1: f32) -> f32 {
    let theta = d0.dot(d1).clamp(-1.0, 1.0).acos();
    (edges.radius(p) * (theta * 0.5).tan().max(1e-3)).min(0.45 * l0).min(0.45 * l1)
}

/// Round k1: a rim block, planned before it is built.
struct RimBlock {
    plan: Vec<Vec2>,
    b_index: usize,
    cap: f32,
    bottom: f32,
    tilt: Vec2,
    colour: Vec3,
    id: u8,
    lip: f32,
    lawn: bool,
    edges: Edges,
    /// Round k5: how the block leans: its foot moves by `shift`, plus `bow` outward (or inward) at
    /// the middle of its front, so the face is a slightly twisted plane, not an upright card.
    shift: Vec2,
    /// The foot's offset under the front's other end (`shift` is under its first end).
    shift_b: Vec2,
    bow: f32,
    /// The face's first end, its direction along the rim and width, and its outward normal.
    a: Vec2,
    chord: Vec2,
    width: f32,
    out: Vec2,
}

impl RimBlock {
    /// How far the foot under a plan point stands from the point (the lean).
    fn foot_at(&self, p: Vec2) -> Vec2 {
        let t = ((p - self.a).dot(self.chord) / self.width.max(0.1)).clamp(0.0, 1.0);
        self.shift.lerp(self.shift_b, t) + self.out * self.bow * (std::f32::consts::PI * t).sin()
    }

    /// Height of the top of the block's rock sides (under the stone cap's roll or the lawn's).
    /// The top of the block's stone: its flat cap, or the top of its rock sides under a lawn cap.
    fn top_surface(&self) -> f32 {
        if self.lawn {
            self.cap - LAWN_ROLL[LAWN_ROLL.len() - 1].1
        } else {
            self.cap
        }
    }

    /// The block's corner at its first (a) or last (b) front end, and its front edge there (from,
    /// to, in plan order).
    fn front_end(&self, b_end: bool) -> (Vec2, Vec2, Vec2) {
        let n = self.plan.len();
        if b_end {
            (self.plan[self.b_index], self.plan[(self.b_index + n - 1) % n], self.plan[self.b_index])
        } else {
            (self.plan[0], self.plan[0], self.plan[1])
        }
    }
}

/// Round k1: a concave fillet filling the V between a block's end and its neighbour's front.
struct Filler {
    /// The arc's points (from the end side to the front) and their shading normals.
    pts: Vec<Vec2>,
    normals: Vec<Vec2>,
    /// The V's apex (the fillet's cap and foot fan from it).
    apex: Vec2,
    top: f32,
    bottom: f32,
    colour: Vec3,
    id: u8,
    lip: f32,
    /// Round k5: the foot follows the leaning block it fills against.
    shift: Vec2,
}

/// Round k1: the junction of two neighbouring rim blocks where `pro`'s end stands out in front of
/// `other`'s front (`pro_left`: `pro` comes first along the rim, so its far front corner is the
/// one at the junction). Returns the shading turn for `pro`'s corner there and, where the end
/// stands out farther than its rounded corner reaches, a concave fillet across the V between its
/// end side and `other`'s front. The narrower the V, the less the corner's shading turns toward
/// the end side (a V under about 20 degrees is shaded as if the two fronts met in one rounded
/// edge); a V of 85 degrees or more (a straight step forward) keeps the full rounded corner.
fn rim_junction(pro: &RimBlock, other: &RimBlock, pro_left: bool) -> Option<(CornerTurn, Option<Filler>)> {
    let np = pro.plan.len();
    let no = other.plan.len();
    if np < 4 || no < 4 {
        return None;
    }
    // pro's corner P, its front direction (along the rim, plan order) and its end side (from P back).
    let (p, q, front_from, front_incoming) = if pro_left {
        (pro.plan[pro.b_index], pro.plan[(pro.b_index + 1) % np], pro.plan[(pro.b_index + np - 1) % np], true)
    } else {
        (pro.plan[0], pro.plan[np - 1], pro.plan[1], false)
    };
    let (l_end, l_front) = ((q - p).length(), (front_from - p).length());
    if l_end < 0.05 || l_front < 0.05 {
        return None;
    }
    let d_end = (q - p) / l_end;
    // other's front edge e0 -> e1 in plan order; its outward normal.
    let (e0, e1) = if pro_left { (other.plan[0], other.plan[1]) } else { (other.plan[(other.b_index + no - 1) % no], other.plan[other.b_index]) };
    let le = (e1 - e0).length();
    if le < 0.05 {
        return None;
    }
    let de = (e1 - e0) / le;
    let nf = Vec2::new(de.y, -de.x);
    // P must stand out in front of other's front.
    if (p - e0).dot(nf) < 0.03 {
        return None;
    }
    // Where pro's end side crosses other's front line.
    let denom = d_end.perp_dot(de);
    if denom.abs() < 1e-3 {
        return None;
    }
    let s = (e0 - p).perp_dot(de) / denom;
    let u = (e0 - p).perp_dot(d_end) / denom;
    if s < 0.02 || s > l_end - 0.02 || u < -0.3 || u > le + 0.3 {
        return None;
    }
    let v = p + d_end * s;
    // pro's front normal, and its end side's outward normal (plan order).
    let (n_front, n_end) = if front_incoming {
        let d = (p - front_from) / l_front;
        (Vec2::new(d.y, -d.x), Vec2::new(d_end.y, -d_end.x))
    } else {
        let d = (front_from - p) / l_front;
        let de2 = -d_end;
        (Vec2::new(d.y, -d.x), Vec2::new(de2.y, -de2.x))
    };
    let ray1 = -d_end;
    let ray2 = if de.dot(n_end) > 0.0 { de } else { -de };
    let alpha = ray1.dot(ray2).clamp(-1.0, 1.0).acos();
    if alpha > 150.0_f32.to_radians() {
        return None;
    }
    // A small step reads as a joint in one cliff, not as a free corner: the corner turns its shading
    // only as far as the step is deep (fully from 0.3 m).
    let step = (p - e0).dot(nf);
    let frac = smoothstep(20.0_f32.to_radians(), 85.0_f32.to_radians(), alpha) * (0.15 + 0.85 * smoothstep(0.03, 0.30, step));
    let turn = CornerTurn { at: p, frac, front_incoming };
    // Where pro's rounded corner ends on its end side.
    let (d0, d1, l0, l1) = if front_incoming { ((p - front_from) / l_front, d_end, l_front, l_end) } else { (-d_end, (front_from - p) / l_front, l_end, l_front) };
    let cut = corner_cut(&pro.edges, p, d0, d1, l0, l1);
    if s <= cut + 0.03 {
        return Some((turn, None));
    }
    // The room along other's front from the V to its far end.
    let room = if ray2.dot(de) > 0.0 { le - u } else { u };
    let reach = (s - cut).min(0.6).min(room - 0.05);
    if reach < 0.03 {
        return Some((turn, None));
    }
    let a = v + ray1 * reach;
    let b = v + ray2 * reach;
    let half = alpha * 0.5;
    let bis = (ray1 + ray2).normalize_or_zero();
    let centre = v + bis * (reach / half.cos().max(0.05));
    let rf = reach * half.tan();
    // The shading normal where pro's corner ends: its front normal turned `frac` of the way.
    let sign = if n_front.perp_dot(n_end) >= 0.0 { 1.0 } else { -1.0 };
    let n_a = rotate(n_front, sign * n_front.dot(n_end).clamp(-1.0, 1.0).acos() * frac);
    const SEG: usize = 4;
    let (ua, ub) = ((a - centre) / rf.max(1e-4), (b - centre) / rf.max(1e-4));
    let sweep = ua.perp_dot(ub).atan2(ua.dot(ub));
    let mut pts = Vec::with_capacity(SEG + 1);
    let mut normals = Vec::with_capacity(SEG + 1);
    for k in 0..=SEG {
        let f = k as f32 / SEG as f32;
        pts.push(centre + rotate(ua, sweep * f) * rf);
        normals.push(n_a.lerp(nf, f).normalize_or_zero());
    }
    let filler = Filler {
        pts,
        normals,
        apex: v,
        top: pro.top_surface().min(other.top_surface()) - 0.005,
        bottom: pro.bottom.max(other.bottom) + 0.5,
        colour: (pro.colour + other.colour) * 0.5,
        id: pro.id,
        lip: pro.lip.max(other.lip),
        shift: pro.foot_at(v),
    };
    Some((turn, Some(filler)))
}

/// Round k1: a junction's fillet, from its cap down to its foot, with a gentle baked contact shade
/// deepest in the middle of the fillet.
fn emit_filler(mesh: &mut Mesh, f: &Filler, colours: &StoneColours) {
    let n = f.pts.len();
    let low = f.colour.lerp(colours.under, 0.18);
    let at = |k: usize, y: f32| { let s = if y < f.top - 0.01 { f.shift } else { Vec2::ZERO }; Vec3::new(f.pts[k].x + s.x, y, f.pts[k].y + s.y) };
    let deep = |k: usize| (std::f32::consts::PI * k as f32 / (n - 1) as f32).sin();
    let paint = |k: usize, grad: f32| {
        let sky = if grad < 0.5 { 1.0 - 0.14 * deep(k) } else { 0.86 - 0.10 * deep(k) };
        Paint::new(Family::Stone).sky(sky).line(1.0).strokes(1.0).id(f.id).grad(grad).lip(f.lip)
    };
    for k in 0..n - 1 {
        let k2 = k + 1;
        let (na, nb) = (Vec3::new(f.normals[k].x, 0.0, f.normals[k].y), Vec3::new(f.normals[k2].x, 0.0, f.normals[k2].y));
        let (ta, tb) = (1.0 - 0.04 * deep(k), 1.0 - 0.04 * deep(k2));
        let q = [at(k, f.top), at(k2, f.top), at(k2, f.bottom), at(k, f.bottom)];
        crate::field::tri_facing(mesh, [q[0], q[1], q[2]], [na, nb, nb], [f.colour * ta, f.colour * tb, low * tb], [paint(k, 0.0), paint(k2, 0.0), paint(k2, 1.0)]);
        crate::field::tri_facing(mesh, [q[0], q[2], q[3]], [na, nb, na], [f.colour * ta, low * tb, low * ta], [paint(k, 0.0), paint(k2, 1.0), paint(k, 1.0)]);
    }
    // The cap and the foot: fans from the V's apex.
    let pc = Paint::new(Family::Stone).sky(1.0).line(1.0).strokes(0.5).id(f.id).grad(0.0);
    let pf = Paint::new(Family::Stone).sky(0.5).line(1.0).strokes(1.0).id(f.id).grad(1.0);
    let (apex_t, apex_b) = (Vec3::new(f.apex.x, f.top, f.apex.y), Vec3::new(f.apex.x + f.shift.x, f.bottom, f.apex.y + f.shift.y));
    for k in 0..n - 1 {
        crate::field::tri_facing(mesh, [apex_t, at(k, f.top), at(k + 1, f.top)], [Vec3::Y; 3], [f.colour; 3], [pc; 3]);
        crate::field::tri_facing(mesh, [apex_b, at(k, f.bottom), at(k + 1, f.bottom)], [Vec3::NEG_Y; 3], [low; 3], [pf; 3]);
    }
}

/// Worn lightening on a convex rounded edge, soft shade at a concave corner (baked into the colour).
fn wear_tone(wear: f32) -> f32 {
    1.0 + 0.035 * wear.max(0.0) - 0.05 * (-wear).max(0.0)
}

/// A hanging column: an n-sided prism whose foot is a single tilted cut and
/// whose sides lean inward as they descend. The first `front` plan edges are the block's
/// visible front (their ends and the two side faces after them sit in the joins with the
/// neighbouring blocks and are darkened there); `lip` is the lawn lip above it, for the brow.
/// Round k1: its vertical edges are rounded (0.15 to 0.22 m, two pieces), as a rim face's are.
#[allow(clippy::too_many_arguments)]
fn column(mesh: &mut Mesh, plan: &[Vec2], top: f32, depth: f32, lean_to: Vec2, taper: f32, tilt: Vec2, colour: Vec3, colours: &StoneColours, id: u8, tier: f32, ledge: bool, front: usize, lip: Option<f32>) {
    if front == 0 {
        rounded_column(mesh, plan, top, depth, lean_to, taper, tilt, colour, colours, id, tier, ledge, lip);
        return;
    }
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

/// Round k1: `column` without a front (the second tier under the island), its vertical edges
/// rounded. The same rings, colours and caps as before; the old softened arris (a quarter of the
/// neighbouring face's normal) is replaced by real arcs with smooth normals.
#[allow(clippy::too_many_arguments)]
fn rounded_column(mesh: &mut Mesh, plan: &[Vec2], top: f32, depth: f32, lean_to: Vec2, taper: f32, tilt: Vec2, colour: Vec3, colours: &StoneColours, id: u8, tier: f32, ledge: bool, lip: Option<f32>) {
    let centre = plan.iter().copied().sum::<Vec2>() / plan.len() as f32;
    let pivot = centre.lerp(lean_to, 0.5);
    // Two pieces per corner (they hang in the root mist; three cost a third more for nothing seen).
    let edges = Edges { corner: (0.15, 0.22), roll: 0.0, crown: false, salt: 0xC01 ^ id as u32, turn: Vec::new(), square: Vec::new() };
    let ring = rounded_ring(plan, &edges, 2);
    let n = ring.len();
    let foot: Vec<Vec3> = ring
        .iter()
        .map(|r| {
            let q = pivot + (r.p - pivot) * taper;
            Vec3::new(q.x, top - depth + (q - centre).dot(tilt), q.y)
        })
        .collect();
    let head: Vec<Vec3> = ring.iter().map(|r| Vec3::new(r.p.x, top, r.p.y)).collect();
    let paint = |grad: f32, sky: f32| {
        let p = Paint::new(Family::Stone).sky(sky).line(1.0).strokes(1.0).id(id).grad(grad);
        match lip {
            Some(y) => p.lip(y),
            None => p,
        }
    };
    let salt = (centre.x * 7.3 + centre.y * 3.1).floor() as i32;
    let at = 0.30 + 0.34 * hash2(salt, id as i32, 401);
    let waist: Vec<Vec3> = (0..n).map(|k| head[k].lerp(foot[k], at)).collect();
    let (c0, c1, c2) = (colour * 0.97, colour.lerp(colours.cool, 0.10), colour.lerp(colours.under, 0.25 + 0.30 * tier));
    let tone = |g: f32| if g < 0.45 { c0.lerp(c1, g / 0.45) } else { c1.lerp(c2, (g - 0.45) / 0.55) };
    let sky = |g: f32| (1.0 - 0.22 * tier) * (1.0 - 0.18 * g);
    let normals: Vec<Vec3> = (0..n).map(|k| side_normal(ring[k].n, head[k], foot[k])).collect();
    let rings: [(&Vec<Vec3>, f32); 3] = [(&head, 0.0), (&waist, at), (&foot, 1.0)];
    for r in 0..rings.len() - 1 {
        let ((a, ga), (b, gb)) = (rings[r], rings[r + 1]);
        let (pa, pb) = (paint(ga, sky(ga)), paint(gb, sky(gb)));
        for k in 0..n {
            let k2 = (k + 1) % n;
            let (w0, w1) = (wear_tone(ring[k].wear), wear_tone(ring[k2].wear));
            let (na, nb) = (normals[k], normals[k2]);
            mesh.tri_full([a[k], a[k2], b[k2]], [na, nb, nb], [tone(ga) * w0, tone(ga) * w1, tone(gb) * w1], [pa, pa, pb]);
            mesh.tri_full([a[k], b[k2], b[k]], [na, nb, na], [tone(ga) * w0, tone(gb) * w1, tone(gb) * w0], [pa, pb, pb]);
        }
    }
    let foot_centre = foot.iter().copied().sum::<Vec3>() / n as f32;
    for k in 0..n {
        mesh.tri(foot_centre, foot[k], foot[(k + 1) % n], colour.lerp(colours.under, 0.8), paint(1.0, 0.5));
    }
    let head_centre = head.iter().copied().sum::<Vec3>() / n as f32;
    let cap = if ledge { colour.lerp(colours.warm, 0.25) } else { colour };
    for k in 0..n {
        let paint = Paint::new(Family::Stone).sky(1.0).line(1.0).strokes(0.5).id(id);
        mesh.tri_full([head_centre, head[(k + 1) % n], head[k]], [Vec3::Y; 3], [cap; 3], [paint; 3]);
    }
}

/// Round r8: one tall vertical block, as the Godot baseline's cliff faces are: a prism whose sides
/// run straight down from the cap (no taper, no waist, no bedding step), capped at the top, its
/// foot cut on a tilted plane far down in the root mist. `plan` runs with the block's outside on
/// the left of each edge seen from above (the order `column` uses).
///
/// Round k1 (the owner: edges too sharp, the slab top's crease reads as a cut): every convex
/// vertical edge is a real rounded edge (`Edges::corner`, three pieces, normals turning smoothly
/// from one side's to the other's), a concave corner is shaded across softly, and unless a lawn
/// cap covers it the top edge rolls over: a curve of three pieces from the side, `Edges::roll`
/// under the edge, to the top, `roll` in from the edge, tangent to both, its normals turning from
/// the side's to the top's. Where a vertical edge meets the top the roll closes on the corner, so
/// three edges meet in one rounded corner. The rounded edges carry a slight worn lightening.
/// With `Edges::crown` the top is a small grid of rings shaded by the height function's own normals
/// (one surface, no crease); otherwise a flat fan.
#[allow(clippy::too_many_arguments)]
fn tall_block(mesh: &mut Mesh, plan: &[Vec2], top: &dyn Fn(Vec2) -> f32, bottom: f32, tilt: Vec2, shift: &dyn Fn(Vec2) -> Vec2, colour: Vec3, colours: &StoneColours, id: u8, lip: Option<f32>, cap_warm: f32, edges: Edges, lawn: Option<(Vec3, &Field)>, fringe: &mut Fringe) {
    let ring = rounded_ring(plan, &edges, 3);
    let n = ring.len();
    if n < 3 {
        return;
    }
    let centre = ring.iter().map(|r| r.p).sum::<Vec2>() / n as f32;
    // Round r10d: a lawn cap (a rim block standing forward of the lawn's outline) carries the lawn
    // out to its edges and rolls it over them; the rock sides start under the roll.
    let roll_drop = if lawn.is_some() { LAWN_ROLL[LAWN_ROLL.len() - 1].1 } else { 0.0 };
    let top_at = |p: Vec2| top(p) - roll_drop;
    let reach = if lawn.is_some() { 0.0 } else { edges.roll };
    // Per ring point: the edge's corner (on the top, over the plan), the roll's inner end (on the
    // top, `reach` in) and the side's top (under the corner by about the roll's length).
    let edge_pt: Vec<Vec3> = ring.iter().map(|r| Vec3::new(r.p.x, top_at(r.p), r.p.y)).collect();
    // The roll's tangent length at each point: `reach` on a square edge, less on an obtuse one
    // (radius x tan(turn / 2)), so a slab's front edge, where a top falling 34 to 48 degrees meets
    // the front, rounds with the same radius instead of turning into a long soft shoulder.
    let tangent: Vec<f32> = ring
        .iter()
        .map(|r| {
            if reach <= 0.0 {
                return 0.0;
            }
            let side = Vec3::new(r.n.x, 0.0, r.n.y);
            let turn = side.dot(height_normal(&top_at, r.p)).clamp(-1.0, 1.0).acos().clamp(20.0_f32.to_radians(), 110.0_f32.to_radians());
            reach * (turn * 0.5).tan()
        })
        .collect();
    let inner: Vec<Vec3> = ring
        .iter()
        .zip(&tangent)
        .map(|(r, &t)| {
            // Measured along the top: horizontally a little less where the top slopes.
            let q = r.inset(t * height_normal(&top_at, r.p).y);
            Vec3::new(q.x, top_at(q), q.y)
        })
        .collect();
    let head: Vec<Vec3> = (0..n).map(|k| edge_pt[k] - Vec3::Y * tangent[k]).collect();
    let foot: Vec<Vec3> = ring.iter().map(|r| { let s = shift(r.p); Vec3::new(r.p.x + s.x, bottom + (r.p - centre).dot(tilt), r.p.y + s.y) }).collect();
    let paint = |grad: f32, sky: f32| {
        let p = Paint::new(Family::Stone).sky(sky).line(1.0).strokes(1.0).id(id).grad(grad);
        match lip {
            Some(y) => p.lip(y),
            None => p,
        }
    };
    let low = colour.lerp(colours.under, 0.18);
    // The sides' normals: horizontal direction from the rounded ring (smooth round a corner), the
    // tilt from the faces themselves (head edge across, head to foot down), as before round k1. A
    // leaning slab's front is a twisted quad (sloped top, level foot); a tilt taken from each
    // vertical line alone lifted its low shoulder's normal and lit the whole front like its top.
    let face: Vec<Vec3> = (0..n).map(|k| (head[(k + 1) % n] - head[k]).cross(foot[k] - head[k]).normalize_or_zero()).collect();
    let side_n: Vec<Vec3> = (0..n)
        .map(|k| {
            let r = &ring[k];
            let (prev, next) = (face[(k + n - 1) % n], face[k]);
            let same_arc = |o: &RingPt| o.radius > 0.0 && (o.corner - r.corner).length() < 1e-4;
            // An arc's end takes the flat side's normal; any other point the mean of its two pieces.
            let a = if r.radius > 0.0 && r.wear.abs() < 1e-4 {
                if same_arc(&ring[(k + n - 1) % n]) { next } else { prev }
            } else {
                (prev + next).normalize_or_zero()
            };
            let g = a.y / Vec2::new(a.x, a.z).length().max(1e-3);
            let out = Vec3::new(r.n.x, g.clamp(-2.0, 2.0), r.n.y).normalize_or_zero();
            if out == Vec3::ZERO { side_normal(r.n, head[k], foot[k]) } else { out }
        })
        .collect();
    let wear: Vec<f32> = ring.iter().map(|r| wear_tone(r.wear)).collect();
    let (pt, pb) = (paint(0.0, 1.0), paint(1.0, 0.86));
    for k in 0..n {
        let k2 = (k + 1) % n;
        let (na, nb) = (side_n[k], side_n[k2]);
        let (ca, cb, la, lb) = (colour * wear[k], colour * wear[k2], low * wear[k], low * wear[k2]);
        mesh.tri_full([head[k], head[k2], foot[k2]], [na, nb, nb], [ca, cb, lb], [pt, pt, pb]);
        mesh.tri_full([head[k], foot[k2], foot[k]], [na, nb, na], [ca, lb, la], [pt, pb, pb]);
    }
    let foot_centre = foot.iter().copied().sum::<Vec3>() / n as f32;
    for k in 0..n {
        mesh.tri(foot_centre, foot[k], foot[(k + 1) % n], colour.lerp(colours.under, 0.8), paint(1.0, 0.5));
    }
    if let Some((lawn, field)) = lawn {
        let plan2: Vec<Vec2> = ring.iter().map(|r| r.p).collect();
        lawn_cap(mesh, &plan2, top, lawn, field, fringe);
        return;
    }
    let cap = colour.lerp(colours.warm, cap_warm);
    // The cap's paint carries no lip (as before); the roll's first piece is the side's.
    let pc = Paint::new(Family::Stone).sky(1.0).line(1.0).strokes(0.5).id(id).grad(0.0);
    let top_n: Vec<Vec3> = inner.iter().map(|q| height_normal(&top_at, Vec2::new(q.x, q.z))).collect();
    let mut cap_ring = head.clone();
    if reach > 0.0 {
        // The roll: a quadratic curve from the side's top through the edge's corner to the inner end.
        const ROWS: [f32; 4] = [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0];
        let at = |k: usize, s: f32| head[k] * (1.0 - s) * (1.0 - s) + edge_pt[k] * 2.0 * s * (1.0 - s) + inner[k] * s * s;
        let nrm = |k: usize, s: f32| (side_n[k] * (1.0 - s) + top_n[k] * s).normalize_or_zero();
        let col = |k: usize, s: f32| {
            let worn = if s > 0.0 && s < 1.0 { 1.035 } else { 1.0 };
            if s >= 1.0 { cap * wear[k] } else { colour * wear[k] * worn }
        };
        for r in 0..ROWS.len() - 1 {
            let (s0, s1) = (ROWS[r], ROWS[r + 1]);
            let p = if r == 0 { pt } else { pc };
            for k in 0..n {
                let k2 = (k + 1) % n;
                // Ordered as the sides are (upper edge first), so the roll faces out as they do.
                let q = [at(k, s1), at(k2, s1), at(k2, s0), at(k, s0)];
                let nn = [nrm(k, s1), nrm(k2, s1), nrm(k2, s0), nrm(k, s0)];
                let cc = [col(k, s1), col(k2, s1), col(k2, s0), col(k, s0)];
                mesh.tri_full([q[0], q[1], q[2]], [nn[0], nn[1], nn[2]], [cc[0], cc[1], cc[2]], [p; 3]);
                mesh.tri_full([q[0], q[2], q[3]], [nn[0], nn[2], nn[3]], [cc[0], cc[2], cc[3]], [p; 3]);
            }
        }
        cap_ring = inner.clone();
    }
    let ring_c = cap_ring.iter().map(|q| Vec2::new(q.x, q.z)).sum::<Vec2>() / n as f32;
    if edges.crown {
        // A small grid of rings toward the middle, each point on the height function and shaded by
        // its normal, so the sloped top reads as one surface with a slight crown.
        let scales = [1.0_f32, 0.66, 0.33];
        let rings: Vec<Vec<(Vec3, Vec3)>> = scales
            .iter()
            .map(|&s| {
                (0..n)
                    .map(|k| {
                        let q = ring_c + (Vec2::new(cap_ring[k].x, cap_ring[k].z) - ring_c) * s;
                        let p3 = if s == 1.0 { cap_ring[k] } else { Vec3::new(q.x, top_at(q), q.y) };
                        (p3, height_normal(&top_at, q))
                    })
                    .collect()
            })
            .collect();
        for r in 0..rings.len() - 1 {
            for k in 0..n {
                let k2 = (k + 1) % n;
                let (a, b, c, d) = (rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k]);
                let (ca, cb) = (if r == 0 { cap * wear[k] } else { cap }, if r == 0 { cap * wear[k2] } else { cap });
                mesh.tri_full([a.0, c.0, b.0], [a.1, c.1, b.1], [ca, cap, cb], [pc; 3]);
                mesh.tri_full([a.0, d.0, c.0], [a.1, d.1, c.1], [ca, cap, cap], [pc; 3]);
            }
        }
        let mid = Vec3::new(ring_c.x, top_at(ring_c), ring_c.y);
        let mid_n = height_normal(&top_at, ring_c);
        let last = &rings[rings.len() - 1];
        for k in 0..n {
            let (a, b) = (last[(k + 1) % n], last[k]);
            mesh.tri_full([mid, a.0, b.0], [mid_n, a.1, b.1], [cap; 3], [pc; 3]);
        }
    } else {
        // The flat cap under the lawn.
        let hc = cap_ring.iter().copied().sum::<Vec3>() / n as f32;
        for k in 0..n {
            let (a, b) = (cap_ring[(k + 1) % n], cap_ring[k]);
            let normal = (a - hc).cross(b - hc).normalize_or_zero();
            let normal = if normal.y < 0.0 { -normal } else if normal == Vec3::ZERO { Vec3::Y } else { normal };
            mesh.tri_full([hc, a, b], [normal; 3], [cap; 3], [pc; 3]);
        }
    }
}

/// Round r10d: the lawn's roll over a lawn-capped block's edges, as (inset from the edge, drop
/// under the cap) in metres, from the flat cap out to the top of the rock side.
const LAWN_ROLL: [(f32, f32); 4] = [(0.10, 0.0), (0.055, 0.014), (0.022, 0.045), (0.0, 0.095)];

/// Round r10d: where grass grows on lawn-capped rim blocks, for `grass::build`: the flat caps
/// (polygon, height) and the fringe along their open edges (from, to, outward).
#[derive(Default)]
pub struct Fringe {
    pub pads: Vec<(Vec<Vec2>, f32)>,
    pub edges: Vec<(Vec3, Vec3, Vec2)>,
}

/// The lawn over a rim block that stands forward of the outline (round r10d): the reference's
/// lawn reaches the cliff's edge and rolls over it, where a flat stone cap a little under the
/// lawn read as a bare, machined ledge. A flat lawn cap, then a rolled band down to the top of the
/// rock sides; the open edges (outside the island's outline) get the lip's fringe of grass.
fn lawn_cap(mesh: &mut Mesh, ring: &[Vec2], top: &dyn Fn(Vec2) -> f32, lawn: Vec3, field: &Field, fringe: &mut Fringe) {
    let n = ring.len();
    let c = ring.iter().copied().sum::<Vec2>() / n as f32;
    let edge_out: Vec<Vec2> = (0..n)
        .map(|k| {
            let (p, q) = (ring[k], ring[(k + 1) % n]);
            let d = (q - p).normalize_or_zero();
            let o = Vec2::new(d.y, -d.x);
            if o.dot((p + q) * 0.5 - c) < 0.0 { -o } else { o }
        })
        .collect();
    // Per corner, the offset that moves both of its edges inward by 1 m.
    let bis: Vec<Vec2> = (0..n)
        .map(|k| {
            let (n0, n1) = (edge_out[(k + n - 1) % n], edge_out[k]);
            let m = (n0 + n1).normalize_or_zero();
            m / m.dot(n1).max(0.5)
        })
        .collect();
    let rings: Vec<Vec<Vec3>> = LAWN_ROLL
        .iter()
        .map(|&(inset, drop)| (0..n).map(|k| { let p = ring[k] - bis[k] * inset; Vec3::new(p.x, top(ring[k]) - drop, p.y) }).collect())
        .collect();
    let tilt = [0.0, 0.30, 0.55, 0.72];
    let normals: Vec<Vec<Vec3>> = tilt
        .iter()
        .map(|&w| (0..n).map(|k| { let s = bis[k].normalize_or_zero(); (Vec3::Y * (1.0 - w) + Vec3::new(s.x, 0.0, s.y) * w).normalize() }).collect())
        .collect();
    let paint = Paint::new(Family::Ground).sky(1.0).line(0.35).id(1);
    let col = |p: Vec3| crate::grass::lawn_ground(lawn, Vec2::new(p.x, p.z));
    let inner = &rings[0];
    let hc = inner.iter().copied().sum::<Vec3>() / n as f32;
    for k in 0..n {
        let (a, b) = (inner[(k + 1) % n], inner[k]);
        crate::field::tri_facing(mesh, [hc, a, b], [Vec3::Y; 3], [col(hc), col(a), col(b)], [paint; 3]);
    }
    for r in 0..rings.len() - 1 {
        for k in 0..n {
            let k2 = (k + 1) % n;
            let q = [rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k]];
            let nn = [normals[r][k], normals[r][k2], normals[r + 1][k2], normals[r + 1][k]];
            crate::field::tri_facing(mesh, [q[0], q[1], q[2]], [nn[0], nn[1], nn[2]], [col(q[0]), col(q[1]), col(q[2])], [paint; 3]);
            crate::field::tri_facing(mesh, [q[0], q[2], q[3]], [nn[0], nn[2], nn[3]], [col(q[0]), col(q[2]), col(q[3])], [paint; 3]);
        }
    }
    fringe.pads.push((inner.iter().map(|p| Vec2::new(p.x, p.z)).collect(), hc.y));
    // The fringe on the roll, only where the edge lies off the island (an edge under the lawn
    // behind the outline would plant a row of tufts across the lawn).
    let mid = &rings[1];
    for k in 0..n {
        let (a, b) = (mid[k], mid[(k + 1) % n]);
        let pieces = ((b - a).length() / 0.25).ceil().max(1.0) as usize;
        for s in 0..pieces {
            let (p0, p1) = (a.lerp(b, s as f32 / pieces as f32), a.lerp(b, (s + 1) as f32 / pieces as f32));
            let m = (p0 + p1) * 0.5;
            if field.sample(&field.land1, Vec2::new(m.x, m.z)) < 0.42 {
                fringe.edges.push((p0, p1, edge_out[k]));
            }
        }
    }
}

pub struct Body {
    pub mesh: Mesh,
    pub faces: Vec<Face>,
    pub columns: usize,
    pub fringe: Fringe,
}

pub fn build_body(kind: Kind, field: &Field, outlines: &[Outline], colours: &StoneColours, seed: u32, spacing: f32) -> Body {
    let mut mesh = build_hull(field, colours, seed, if kind == Kind::Hull { 2.4 } else { 2.0 }, kind == Kind::Karst);
    let Some(outer) = outlines.iter().find(|o| !o.is_hole) else {
        return Body { mesh, faces: Vec::new(), columns: 0, fringe: Fringe::default() };
    };
    let faces = plan_faces(outer, field, seed, spacing);
    let mut columns = 0;
    let mut fringe = Fringe::default();
    if kind == Kind::Karst {
        // Tier one: the rim faces, each the front of a hanging block. Round k1: the blocks are planned
        // first and built after their junctions are looked at (see `rim_junction`).
        let mut blocks: Vec<RimBlock> = Vec::with_capacity(faces.len());
        for (index, face) in faces.iter().enumerate() {
            let chord = (face.b - face.a).normalize_or_zero();
            let out = Vec2::new(chord.y, -chord.x);
            let mid = (face.a + face.b) * 0.5;
            // Outward must point away from the island at the middle of the face.
            let out = if field.sample(&field.land2, mid + out) < field.sample(&field.land2, mid - out) { out } else { -out };
            let key = ((mid.x * 0.5 + 0.137).floor() as i32, (mid.y * 0.5 + 0.291).floor() as i32);
            let (h1, h2, h3) = (hash2(key.0, key.1, seed ^ 81), hash2(key.0, key.1, seed ^ 82), hash2(key.0, key.1, seed ^ 83));
            let base_thick: f32 = 2.4 + 1.6 * h1 + if face.role == Role::Primary { 0.8 } else { 0.0 };
            // Round r8, after the Godot baseline's cliff columns: each rim face is one tall vertical
            // face from just under the lawn's lip down into the root mist, crisp at its edges, set
            // forward or back of its neighbours by its role (a narrow face stands back as a recess),
            // turned by a degree or two at most. The shelves, shoulders, waists and bedding steps of
            // earlier rounds are gone.
            let front = face.step - 0.12;
            let side = 0.22;
            let turn = (h2 - 0.5) * 0.05;
            let (front_a, front_b) = (front - turn * face.width * 0.5, front + turn * face.width * 0.5);
            // Round r10d: where a terrace wall of this face's own level meets the outline near one of
            // its ends, the block must not stand over the lower lawn beyond the wall, and must not be
            // cut thin by the wall behind it either: before, the end reached 0.22 m past the face over
            // the lower lawn, or the whole block was cut to 0.6 m by the wall and stood wholly in front
            // of the outline, and either way a dark slot opened between block and wall (the "empty
            // cavity" read). Such an end takes its back corner on the wall's line, just behind the
            // wall's face, at the block's full depth; its front corner stays at the rim (pulled back
            // only as far as needed), so the end side runs from the rim to the wall.
            // Returns a point on that line (5 cm behind the wall's cut) and its direction inland.
            let wall_line = |end: Vec2| -> Option<(Vec2, Vec2)> {
                let i = field.nearest_wall(end - out * 0.3, 0.9)?;
                let st = field.steps[i];
                if !st.wall() || st.high < face.top - 0.05 || st.low > face.top - 0.3 {
                    return None;
                }
                let mut d = (st.b - st.a).normalize_or_zero();
                if d.dot(-out) < 0.0 {
                    d = -d;
                }
                (d.dot(-out) >= 0.2).then(|| (st.a - st.normal_near(end) * 0.05, d))
            };
            let (wall_a, wall_b) = (wall_line(face.a), wall_line(face.b));
            // The block reaches back only as far as the ground over it stays at its top: a pond or
            // a lower terrace behind the rim would otherwise show its top through the bed or lawn.
            // (Not probed at an end that meets a wall: there the end side follows the wall.)
            let mut thick = base_thick;
            for (start, skip) in [(face.a, wall_a.is_some()), (mid, false), (face.b, wall_b.is_some())] {
                if skip {
                    continue;
                }
                let mut d = 0.25;
                while d < thick + 0.3 {
                    if field.height_at(start - out * d) < face.top - 0.12 {
                        thick = thick.min((d - 0.35).max(0.6));
                        break;
                    }
                    d += 0.25;
                }
            }
            // Round r10d: a block that stands forward of the outline carries the lawn out over its
            // top (see `lawn_cap`); its cap sits just under the lawn, so it needs the ground over all
            // of it to stay at the lawn's level, else it keeps the stone cap 0.2 m down.
            // The probes start a little in from the face's ends, which may lie on a step's line.
            // Not where the rim steps within the face (a terrace wall or a bank reaching the outline
            // inside it): there the block stands at the lowest level and the skirt closes the step.
            // (The points within about a metre of the face's ends are left out: a break is placed at
            // a step, so its neighbours may sample the other level.)
            let n_out = outer.points.len();
            let count_out = (face.to + n_out - face.from) % n_out;
            let level_rim = (2..=count_out.saturating_sub(2)).all(|k| {
                let i = (face.from + k) % n_out;
                field.height_at(outer.points[i] - outer.outward[i] * 0.7) < face.top + 0.05
            });
            let mut lawn = level_rim && front + (turn * face.width * 0.5).abs() > 0.03;
            if lawn {
                let inset = (face.width * 0.5).min(0.35);
                let mut lawn_thick = thick;
                for (start, skip) in [(face.a + chord * inset, wall_a.is_some()), (mid, false), (face.b - chord * inset, wall_b.is_some())] {
                    if skip {
                        continue;
                    }
                    let mut d = 0.15;
                    while d < lawn_thick + 0.05 {
                        if field.height_at(start - out * d) < face.top - 0.015 {
                            lawn_thick = lawn_thick.min(d - 0.2);
                            break;
                        }
                        d += 0.2;
                    }
                }
                if lawn_thick < 0.6_f32.max(front + 0.45) {
                    lawn = false;
                } else {
                    thick = lawn_thick;
                }
            }
            let cap = if lawn { face.top - 0.03 } else { face.top - 0.20 };
            // The back corner of an end: on the wall's line at the block's depth, or straight back.
            let back_of = |front_corner: Vec2, wall: Option<(Vec2, Vec2)>, skew: Vec2| -> Vec2 {
                if let Some((p, d)) = wall {
                    let f0 = face.a + out * front;
                    let u = (thick - (p - f0).dot(-out)) / d.dot(-out);
                    let k = p + d * u;
                    // Only when the wall's line meets the back line within a few metres of the end.
                    if (k - front_corner).length() < thick + 3.0 {
                        return k;
                    }
                }
                front_corner - out * thick + skew
            };
            // Each end reaches 0.22 m past the face along the rim, unless the ground under the end
            // side (from its front corner to its back corner) falls below the cap: there it is pulled
            // back until the end side stands on high ground, then let 0.12 m back out over the lower
            // side so it meets the wall's face (or the bank) instead of leaving a gap.
            let reach = |end: Vec2, away: Vec2, front_e: f32, wall: Option<(Vec2, Vec2)>, skew: Vec2| -> (Vec2, Vec2, bool, Option<Vec2>) {
                let corner = |s: f32| end + away * s + out * front_e;
                // Round r10d: an end at a wall of this level runs from its front corner straight back
                // to the rim where the wall meets it, then along the wall's line to its back corner,
                // so the stone covers the rim right up to the wall (a straight end side cut back from
                // the wall left the upper lip over an open gap).
                if let Some((_, d)) = wall {
                    let k = back_of(corner(0.0), wall, skew);
                    if (k - (corner(0.0) - out * thick)).length() > 1e-3 {
                        let mut p = k;
                        let mut walked = 0.0;
                        while field.sample(&field.land1, p) >= 0.5 && walked < 8.0 {
                            p -= d * 0.05;
                            walked += 0.05;
                        }
                        let s = (p - end).dot(away) + 0.03;
                        if walked < 8.0 && s > -1.5 && s < side + 0.6 {
                            return (corner(s), k, true, Some(p));
                        }
                    }
                }
                let mut s = side;
                while s > -1.5 {
                    let (f, k) = (corner(s), back_of(corner(s), wall, skew));
                    let span = (k - f).length();
                    let count = (span / 0.2).ceil().max(1.0) as usize;
                    let ok = (0..=count).all(|j| {
                        let q = f.lerp(k, j as f32 / count as f32);
                        field.sample(&field.land1, q) < 0.5 || field.height_at(q) >= cap + 0.02
                    });
                    if ok {
                        if s >= side {
                            return (f, k, false, None);
                        }
                        let s2 = (s + 0.12).min(side);
                        return (corner(s2), back_of(corner(s2), wall, skew), true, None);
                    }
                    s -= 0.02;
                }
                (corner(s), back_of(corner(s), wall, skew), true, None)
            };
            let (skew_b, skew_a) = (chord * (0.2 * (h3 - 0.3)), -chord * (0.2 * (h1 - 0.3)));
            let (a, back_a, clip_a, prow_a) = reach(face.a, -chord, front_a, wall_a, skew_a);
            let (b, back_b, clip_b, prow_b) = reach(face.b, chord, front_b, wall_b, skew_b);
            // Round k5: a face wider than 2.6 m is folded once (wider than 5.5 m twice), 8 to 22 cm in
            // or out, so a broad face reads as a few planes of one rock, not one flat card. (Before,
            // only faces over 5 m were folded, by at most 15 cm.)
            let mut plan = vec![a];
            if face.width > 2.6 {
                let folds = if face.width > 5.5 { 2 } else { 1 };
                for f in 0..folds {
                    let hf = hash2(key.0 + 7 * f, key.1, seed ^ 84);
                    let t = (f as f32 + 1.0) / (folds as f32 + 1.0) + (hf - 0.5) * 0.24 / folds as f32;
                    let hp = hash2(key.0, key.1 + 1 + 5 * f, seed ^ 85);
                    let push = if hp < 0.5 { -1.0 } else { 1.0 } * (0.08 + 0.14 * (2.0 * (hp - 0.5).abs()));
                    plan.push(a.lerp(b, t) + out * push);
                }
            }
            // A pulled-back end keeps its back corner from leaning out past it again.
            let lean_in = |front_corner: Vec2, back: Vec2, clipped: bool, away: Vec2| -> Vec2 {
                if clipped && (back - front_corner).dot(away) > 0.0 {
                    back - away * (back - front_corner).dot(away)
                } else {
                    back
                }
            };
            let b_index = plan.len();
            plan.push(b);
            plan.extend(prow_b);
            plan.extend([lean_in(b, back_b, clip_b && prow_b.is_none(), chord), lean_in(a, back_a, clip_a && prow_a.is_none(), -chord)]);
            plan.extend(prow_a);
            if std::env::var("S34_BLOCKDBG").is_ok_and(|v| v == "all" || v.split(',').any(|s| s == (100 + index % 70).to_string())) {
                println!("BLOCK {} a {:?} b {:?} out {:?} clip {} {} wall {} {} thick {:.2} lawn {} plan {:?}", 100 + index % 70, face.a, face.b, out, clip_a, clip_b, prow_a.is_some(), prow_b.is_some(), thick, lawn, plan);
            }
            let tone = 1.0 + (h3 - 0.5) * 0.06;
            let colour = colours.face * tone;
            // The foot: 7.6 to 9.4 m under the cap, cut a little out of level; it lies in the mist.
            // Round k5: the foot is cut more out of level along the rim (up to 14 cm a metre, from
            // 5), so the root's lower edge is not one even line.
            let tilt = (-out) * (0.04 + 0.05 * h2) + chord * (h1 - 0.5) * 0.28;
            // Round k5: the block leans: its foot stands 0.15 to 1.0 m further in than its top (a
            // lean of 1 to 7 degrees over its height, so the island narrows toward its root as the
            // reference's does), up to 0.3 m sideways, and the middle of its front bows up to 0.3 m
            // in or out at the foot. The lean follows a smooth world-anchored noise (about 6 m across)
            // plus a little per face, so neighbours lean nearly alike and step gently in and out of
            // each other below the lawn; per-face leans alone opened dark wedge-shaped slits between
            // them. World-anchored, so an edit changes leans only where it changes faces.
            // The lean is a field over the world (inward from the island's mid-scale outline, its
            // amount and a sideways drift from smooth noise), taken at the two ends of the front: two
            // neighbours meeting at a junction take the same lean there, so no gap opens between
            // them below the lawn.
            let lean_at = |p: Vec2| -> Vec2 {
                let inward = field.inward(p);
                let amount = 0.15 + 0.85 * vnoise(p.x * 0.16 + 3.1, p.y * 0.16, seed ^ 99);
                let drift = Vec2::new(vnoise(p.x * 0.16, p.y * 0.16 + 7.7, seed ^ 100) - 0.5, vnoise(p.x * 0.16 + 11.3, p.y * 0.16, seed ^ 113) - 0.5) * 0.6;
                inward * amount + drift
            };
            let (shift, shift_b) = (lean_at(face.a), lean_at(face.b));
            let bow = (hash2(key.0, key.1, seed ^ 101) - 0.5) * 0.4;
            // Round k1: every vertical edge is rounded, 0.12 to 0.22 m (it replaces round r10's flat
            // 0.20 m bevel at the front corners, shaded a third of the way round); neighbouring
            // blocks overlap 0.22 m along the rim and stand up to about 0.2 m forward or back of each
            // other, so the forward block's rounded corner spans the step. The top edge of a stone
            // cap rolls over 0.14 m (a lawn cap rolls the lawn over it instead).
            let edges = Edges { corner: (0.12, 0.22), roll: 0.14, crown: false, salt: seed ^ 0x6B31, turn: Vec::new(), square: Vec::new() };
            blocks.push(RimBlock { plan, b_index, cap, bottom: face.top - 0.20 - 7.6 - 1.8 * h2, tilt, colour, id: 100 + (index % 70) as u8, lip: face.top, lawn, edges, shift, shift_b, bow, a: face.a, chord, width: face.width.max(0.1), out });
        }
        // Round k1: where one block's end stands out past its neighbour's front (a step forward, or a
        // convex turn of the rim, where the two blocks' overlap left a narrow V-shaped slit that read
        // as a black line), the slit is filled with a concave fillet and the corner is shaded softly.
        let nb = blocks.len();
        let mut fillers: Vec<Filler> = Vec::new();
        for i in 0..nb {
            let j = (i + 1) % nb;
            if i == j {
                continue;
            }
            // Each block's corner at the junction and how far it stands in front of the other's front.
            let (ci, fi0, fi1) = blocks[i].front_end(true);
            let (cj, fj0, fj1) = blocks[j].front_end(false);
            let normal_of = |a: Vec2, b: Vec2| {
                let d = (b - a).normalize_or_zero();
                Vec2::new(d.y, -d.x)
            };
            let (off_i, off_j) = ((ci - fj0).dot(normal_of(fj0, fj1)), (cj - fi1).dot(normal_of(fi0, fi1)));
            let step = off_i.max(off_j).max(0.0);
            // The corner that stands back (or both, where the fronts are flush) turns its shading only
            // as far as the step is deep: two fully rounded corners side by side made a dark groove.
            let back_frac = 0.15 + 0.85 * smoothstep(0.10, 0.40, step);
            if (ci - cj).length() > 0.8 {
                continue;
            }
            if step < 0.25 {
                // Round k5: at a small step (under 25 cm) the two corners stay square (they overlap
                // along the rim, and the backing plate below closes the joint): two rounded corners side
                // by side carved a groove that read as a thin dark joint or a pipe.
                blocks[i].edges.square.push(ci);
                blocks[j].edges.square.push(cj);
            } else if let Some((turn, filler)) = rim_junction(&blocks[i], &blocks[j], true) {
                blocks[i].edges.turn.push(turn);
                blocks[j].edges.turn.push(CornerTurn { at: cj, frac: back_frac, front_incoming: false });
                fillers.extend(filler);
            } else if let Some((turn, filler)) = rim_junction(&blocks[j], &blocks[i], false) {
                blocks[j].edges.turn.push(turn);
                blocks[i].edges.turn.push(CornerTurn { at: ci, frac: back_frac, front_incoming: true });
                fillers.extend(filler);
            }
        }
        for b in &blocks {
            let lawn_colour = b.lawn.then_some((colours.lawn, field));
            let cap = b.cap;
            tall_block(&mut mesh, &b.plan, &|_| cap, b.bottom, b.tilt, &|p| b.foot_at(p), b.colour, colours, b.id, Some(b.lip), 0.0, b.edges.clone(), lawn_colour, &mut fringe);
            columns += 1;
        }
        for f in &fillers {
            emit_filler(&mut mesh, f, colours);
        }
        // Round k5: a backing plate 6 cm behind every junction of two rim blocks, from the lower of
        // their tops down to the higher foot, each end following its own block's lean. Where two
        // fronts meet at a slight angle (or lean apart below the lawn) a hairline crack showed the
        // dark inside of the island; now it shows lit stone a little recessed, as a joint.
        for i in 0..nb {
            let j = (i + 1) % nb;
            if i == j {
                continue;
            }
            let (ci, _, _) = blocks[i].front_end(true);
            let (cj, _, _) = blocks[j].front_end(false);
            if (ci - cj).length() > 1.5 {
                continue;
            }
            let along = {
                let d = cj - ci;
                if d.length() > 0.02 { d.normalize() } else { blocks[i].chord }
            };
            let n = (blocks[i].out + blocks[j].out).normalize_or_zero();
            let (p0, p1) = (ci - along * 0.25 - n * 0.025, cj + along * 0.25 - n * 0.025);
            let top = blocks[i].top_surface().min(blocks[j].top_surface()) - 0.02;
            let bottom = blocks[i].bottom.max(blocks[j].bottom) + 0.3;
            let (s0, s1) = (blocks[i].foot_at(ci), blocks[j].foot_at(cj));
            let q = [Vec3::new(p0.x, top, p0.y), Vec3::new(p1.x, top, p1.y), Vec3::new(p1.x + s1.x, bottom, p1.y + s1.y), Vec3::new(p0.x + s0.x, bottom, p0.y + s0.y)];
            let nn = Vec3::new(n.x, 0.0, n.y);
            let colour = (blocks[i].colour + blocks[j].colour) * 0.5 * 0.97;
            let low = colour.lerp(colours.under, 0.18);
            let lip = blocks[i].lip.max(blocks[j].lip);
            let (pt, pb) = (Paint::new(Family::Stone).sky(0.85).line(1.0).strokes(1.0).id(blocks[i].id).grad(0.0).lip(lip), Paint::new(Family::Stone).sky(0.7).line(1.0).strokes(1.0).id(blocks[i].id).grad(1.0).lip(lip));
            crate::field::tri_facing(&mut mesh, [q[0], q[1], q[2]], [nn; 3], [colour, colour, low], [pt, pt, pb]);
            crate::field::tri_facing(&mut mesh, [q[0], q[2], q[3]], [nn; 3], [colour, low, low], [pt, pb, pb]);
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
            let wide = f.width >= 3.0 || (f.width >= 2.6 && h > 0.8);
            (wide && f.role != Role::Secondary && h > 0.32 && field.notch(mid) < 0.05 && field.notch(f.a) < 0.05 && field.notch(f.b) < 0.05).then_some(h)
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
            let (s6, s7, s8, s9) = (hash2(key.0, key.1, seed ^ 102), hash2(key.0, key.1, seed ^ 103), hash2(key.0, key.1, seed ^ 104), hash2(key.0, key.1, seed ^ 105));
            // Round k5: slab sizes vary more (2.8 to 6 m wide, 3.4 to 6.2 m tall), and one slab in
            // two gets a smaller companion leaning against its side, set lower and turned the other
            // way (Godot's shoulder groups hold one to three slabs).
            let width = (face.width * (0.80 + 0.40 * s1)).clamp(2.8, 6.0).min(face.width + 1.2);
            let centre = mid + chord * (s2 - 0.5) * (face.width - width * 0.8).max(0.0) * 0.5;
            let wall = face.step - 0.12;
            let side = if s8 < 0.5 { -1.0 } else { 1.0 };
            let mut slabs = vec![(centre, width, 0.85 + 0.6 * s3, face.top - 1.5 - 2.0 * s1 * s2.max(0.4), 3.4 + 2.8 * s7, 0.0_f32, 1.0_f32)];
            if s9 > 0.5 {
                let w2 = width * (0.45 + 0.2 * s8);
                let c2 = centre + chord * side * (width * 0.5 + w2 * 0.15);
                slabs.push((c2, w2, 0.55 + 0.5 * s2, slabs[0].3 - 0.7 - 1.1 * s9, slabs[0].4 * (0.6 + 0.2 * s1), 1.0, -1.0));
            }
            for (n, &(centre, width, proud, back_top, height, second, turn_sign)) in slabs.iter().enumerate() {
                let salt = n as i32 * 13;
                let r = |k: u32| hash2(key.0 + salt, key.1, seed ^ k);
                // Round k5: turned 11 to 27 degrees off the wall, never square to it (a slab parallel
                // to the wall, seen face on with its rounded rim, read as a framed door).
                let yaw = if s6 < 0.5 { -1.0 } else { 1.0 } * turn_sign * (0.20 + 0.27 * r(106));
                // `across` runs so that the outside lies on the left of fa -> fb (the order `tall_block` wants).
                let across0 = Vec2::new(-out.y, out.x);
                let across = Vec2::new(across0.x * yaw.cos() - across0.y * yaw.sin(), across0.x * yaw.sin() + across0.y * yaw.cos());
                let ahead = Vec2::new(across.y, -across.x);
                let (fa, fb) = (centre - across * width * 0.5 + ahead * (wall + proud), centre + across * width * 0.5 + ahead * (wall + proud));
                let (ba, bb) = (centre - across * width * 0.5 + ahead * (wall - 0.7), centre + across * width * 0.5 + ahead * (wall - 0.7));
                // Round k5: the front is folded once, 12 to 32 cm out at a point off its middle, so it
                // is two planes, not one flat card.
                let fold = fa.lerp(fb, 0.38 + 0.24 * r(107)) + ahead * (0.12 + 0.20 * r(108));
                let plan = [fa, fold, fb, bb, ba];
                // Top 1.5 to 3.5 m under the lawn's edge at the wall (a companion lower), falling
                // outward 34 to 48 degrees.
                let slope = (34.0 + 14.0 * r(109)).to_radians().tan();
                let base = centre + ahead * wall;
                // The wedge: the top also falls along the slab's length (16 to 30 degrees, either
                // way), so the front is a trapezoid with one high and one low shoulder.
                let along = (16.0 + 14.0 * s3).to_radians().tan() * if (s4 < 0.5) == (second < 0.5) { 1.0 } else { -1.0 };
                // Round k1: the fold where the top meets the wall is eased over about 0.12 m, and the
                // visible part of the top carries a slight crown, 3 to 6 cm at its middle.
                let s5 = r(97);
                let (crown, vis_mid, vis_half) = (0.03 + 0.03 * s5, wall + proud * 0.5, proud * 0.5 + 0.30);
                let ease = |x: f32| 0.5 * (x + (x * x + 0.0144).sqrt());
                let top = move |p: Vec2| {
                    let (u, v) = ((p - centre).dot(across) / (width * 0.5), ((p - centre).dot(ahead) - vis_mid) / vis_half);
                    back_top - ease((p - base).dot(ahead)) * slope - ((p - centre).dot(across) + width * 0.5 * along.signum()) * along * 0.7 + crown * (1.0 - u * u).max(0.0) * (1.0 - v * v).max(0.0)
                };
                // Round k5: leaning against the wall and rolled sideways: the foot stands 0.35 to
                // 0.9 m farther out than the top and up to 0.7 m to one side (before: 0.25 to 0.55 m
                // out, 5 cm sideways), so slabs read as fallen and propped, not stood up.
                let lean = across * (r(110) - 0.5) * 1.4 + ahead * (0.35 + 0.55 * s1);
                let colour = colours.face.lerp(colours.warm, 0.15) * (1.0 + (r(111) - 0.5) * 0.06);
                // Round k1: vertical edges rounded 0.18 to 0.30 m, the top's edges 0.18 to 0.28 m.
                let edges = Edges { corner: (0.18, 0.30), roll: 0.18 + 0.10 * r(98), crown: true, salt: seed ^ 0x5B1A, turn: Vec::new(), square: Vec::new() };
                if std::env::var("S34_BLOCKDBG").is_ok_and(|v| v == "slabs") {
                    println!("SLAB {} front {:?} {:?} out {:?} back_top {:.2} lawn {:.2}", 30 + i % 9, fa, fb, ahead, back_top, face.top);
                }
                tall_block(&mut mesh, &plan, &top, back_top - height, Vec2::new(0.0, 0.0), &move |_| lean, colour, colours, 30 + ((i + n) % 9) as u8, Some(face.top), 0.0, edges, None, &mut fringe);
                columns += 1;
            }
        }
        // Where the rim steps down (a terrace wall reaching the outline, a pond's bank), a face's
        // block stands at the lowest ground along it, so under the higher lawn's lip there would be a
        // gap into the island's inside. A sheer skirt of rock at the outline closes it, from just
        // under the lip down past the block's top.
        for (face, block) in faces.iter().zip(&blocks) {
            rim_skirt(&mut mesh, outer, field, colours, face, &block.plan[..=block.b_index], block.cap, &mut fringe);
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
    Body { mesh, faces, columns, fringe }
}

/// The skirt under one face's stretch of outline: wherever the lawn's lip stands higher than the
/// face's block top (a terrace wall or a pond's bank reaching the outline), rock from the block's
/// top up to just under the lawn. Round k5: it stands flush with the block's front below it, and the
/// lawn is carried out over it to that front with the lip's roll and a fringe of grass, as on a
/// lawn-capped block. (It was a band at the outline, behind the block's front, so the block's top
/// showed as a short stone shelf under a recessed band.)
fn rim_skirt(mesh: &mut Mesh, outer: &Outline, field: &Field, colours: &StoneColours, face: &Face, front: &[Vec2], block_top: f32, fringe: &mut Fringe) {
    let n = outer.points.len();
    let bottom = block_top - 0.10;
    let count = (face.to + n - face.from) % n;
    const SUB: usize = 4;
    // How far along `o` from `p` the block's front lies (none if the ray misses it).
    let to_front = |p: Vec2, o: Vec2| -> Option<f32> {
        let mut best: Option<f32> = None;
        for w in front.windows(2) {
            let e = w[1] - w[0];
            let denom = o.perp_dot(e);
            if denom.abs() < 1e-5 {
                continue;
            }
            let t = (w[0] - p).perp_dot(e) / denom;
            let u = (w[0] - p).perp_dot(o) / denom;
            if (-0.05..=1.05).contains(&u) && t > -0.6 && t < 1.5 && best.map_or(true, |b: f32| t.abs() < b.abs()) {
                best = Some(t);
            }
        }
        best
    };
    let sample = |k: usize, t: f32| -> (Vec2, Vec2, f32, f32) {
        let (a, b) = (outer.points[k % n], outer.points[(k + 1) % n]);
        let p = a.lerp(b, t);
        let o = outer.outward[k % n].lerp(outer.outward[(k + 1) % n], t).normalize_or_zero();
        let d = to_front(p, o).map_or(0.045, |t| (t + 0.004).max(0.045));
        (p, o, field.height_at(p), d)
    };
    let lawn_paint = Paint::new(Family::Ground).sky(1.0).line(0.35).id(1);
    let tilt = [0.0_f32, 0.30, 0.55, 0.72];
    for step in 0..count {
        let k = face.from + step;
        for s in 0..SUB {
            let (p0, o0, h0, d0) = sample(k, s as f32 / SUB as f32);
            let (p1, o1, h1, d1) = sample(k, (s + 1) as f32 / SUB as f32);
            if h0.max(h1) - 0.03 < block_top + 0.06 {
                continue;
            }
            // The lawn's level over the skirt (never under the block's top).
            let (y0, y1) = ((h0 - 0.03).max(block_top), (h1 - 0.03).max(block_top));
            // Rings of the lawn: 0.15 m inside the outline, then the roll at the front edge.
            let ring = |r: usize| -> [Vec3; 2] {
                let (inset, drop) = LAWN_ROLL[r];
                let (q0, q1) = (p0 + o0 * (d0 - inset), p1 + o1 * (d1 - inset));
                [Vec3::new(q0.x, y0 - drop, q0.y), Vec3::new(q1.x, y1 - drop, q1.y)]
            };
            let nrm = |r: usize, o: Vec2| (Vec3::Y * (1.0 - tilt[r]) + Vec3::new(o.x, 0.0, o.y) * tilt[r]).normalize();
            let col = |q: Vec3| crate::grass::lawn_ground(colours.lawn, Vec2::new(q.x, q.z));
            let back = [Vec3::new(p0.x - o0.x * 0.15, y0, p0.y - o0.y * 0.15), Vec3::new(p1.x - o1.x * 0.15, y1, p1.y - o1.y * 0.15)];
            let first = ring(0);
            crate::field::tri_facing(mesh, [back[0], back[1], first[1]], [Vec3::Y; 3], [col(back[0]), col(back[1]), col(first[1])], [lawn_paint; 3]);
            crate::field::tri_facing(mesh, [back[0], first[1], first[0]], [Vec3::Y; 3], [col(back[0]), col(first[1]), col(first[0])], [lawn_paint; 3]);
            for r in 0..LAWN_ROLL.len() - 1 {
                let (a, b) = (ring(r), ring(r + 1));
                let (na, nb) = ([nrm(r, o0), nrm(r, o1)], [nrm(r + 1, o0), nrm(r + 1, o1)]);
                crate::field::tri_facing(mesh, [a[0], a[1], b[1]], [na[0], na[1], nb[1]], [col(a[0]), col(a[1]), col(b[1])], [lawn_paint; 3]);
                crate::field::tri_facing(mesh, [a[0], b[1], b[0]], [na[0], nb[1], nb[0]], [col(a[0]), col(b[1]), col(b[0])], [lawn_paint; 3]);
            }
            let mid = ring(1);
            fringe.edges.push((mid[0], mid[1], (o0 + o1).normalize_or_zero()));
            // The rock face, from under the roll down into the block's top.
            let last = ring(LAWN_ROLL.len() - 1);
            let (f0, f1) = (p0 + o0 * d0, p1 + o1 * d1);
            let quad = [last[0], last[1], Vec3::new(f1.x, bottom, f1.y), Vec3::new(f0.x, bottom, f0.y)];
            let (n0, n1) = (Vec3::new(o0.x, 0.0, o0.y), Vec3::new(o1.x, 0.0, o1.y));
            let lip = y0.max(y1);
            let top = Paint::new(Family::Stone).sky(0.86).line(0.9).strokes(0.8).id(4).grad(0.0).lip(lip);
            let low = Paint::new(Family::Stone).sky(0.80).line(0.9).strokes(0.8).id(4).grad(0.3).lip(lip);
            let (ct, cb) = (colours.face, colours.face.lerp(colours.cool, 0.10));
            crate::field::tri_facing(mesh, [quad[0], quad[1], quad[2]], [n0, n1, n1], [ct, ct, cb], [top, top, low]);
            crate::field::tri_facing(mesh, [quad[0], quad[2], quad[3]], [n0, n1, n0], [ct, cb, cb], [top, low, low]);
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
