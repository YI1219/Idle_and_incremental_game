//! Cells and the smooth fields derived from them. The cell grid stays the
//! authority for where land is; everything drawn is derived from blurred copies
//! of it, so forms are soft and every derived value depends only on cells within
//! a few metres (which is what keeps an edit local).
use std::collections::HashMap;

use glam::{Vec2, Vec3};

use crate::mesh::{hash2, smoothstep, vnoise, Family, Mesh, Paint};

#[derive(Clone, Copy)]
pub struct Cell {
    /// Surface height at the cell's centre (the whole cell when flat).
    pub h: f32,
    /// Absolute water level when the cell holds water; its bed is `h`.
    pub water: Option<f32>,
    /// Round r9: rise in metres per metre toward +x and +z (zero for a flat cell). A slope cell's
    /// surface is the plane through (centre, h) with this gradient; it holds no water.
    pub slope: Vec2,
}

impl Cell {
    pub fn flat(h: f32, water: Option<f32>) -> Cell {
        Cell { h, water, slope: Vec2::ZERO }
    }

    pub fn sloped(&self) -> bool {
        self.slope != Vec2::ZERO
    }

    /// The cell's own plane at p (anywhere, extrapolated outside the cell).
    pub fn plane(&self, key: (i32, i32), p: Vec2) -> f32 {
        self.h + self.slope.dot(p - centre_of(key))
    }
}

pub fn centre_of(key: (i32, i32)) -> Vec2 {
    Vec2::new(key.0 as f32 + 0.5, key.1 as f32 + 0.5)
}

pub type Cells = HashMap<(i32, i32), Cell>;

/// The largest gradient a slope cell may have (about 31 degrees).
pub const MAX_GRADIENT: f32 = 0.6;
/// Two neighbouring dry surfaces (one of them a slope) that agree along their shared edge to within
/// this at both ends are continuous there (no step): round r10 raised it from 0.08 so the staircase
/// ends of a diagonal ramp (its plane off the flat terrace by up to about 0.7 m times the gradient)
/// blend into one surface over the rounded crease instead of forming little banks.
pub const CONTINUOUS: f32 = 0.25;

/// Reads a layout exported by tools/export/export_layouts.gd (version 1), or one written by
/// `save_layout` (version 2: real heights and an optional `"slope": [gx, gz]` per cell).
pub fn load_layout(path: &str) -> Cells {
    let text = std::fs::read_to_string(path).unwrap_or_else(|e| panic!("cannot read {path}: {e}"));
    let json: serde_json::Value = serde_json::from_str(&text).expect("layout json");
    let mut cells = Cells::new();
    for record in json["cells"].as_array().expect("cells") {
        let x = record["x"].as_f64().unwrap() as i32;
        let z = record["z"].as_f64().unwrap() as i32;
        let h = record["height"].as_f64().unwrap() as f32;
        let level = record["water"].as_f64().unwrap();
        let slope = match record.get("slope").and_then(|s| s.as_array()) {
            Some(g) => Vec2::new(g[0].as_f64().unwrap() as f32, g[1].as_f64().unwrap() as f32),
            None => Vec2::ZERO,
        };
        assert!(slope.length() <= MAX_GRADIENT + 1e-3, "slope cell ({x}, {z}) is steeper than {MAX_GRADIENT}");
        let water = if level >= 0.0 { Some(level as f32 * 0.5) } else { None };
        assert!(water.is_none() || slope == Vec2::ZERO, "slope cell ({x}, {z}) holds water");
        cells.insert((x, z), Cell { h, water, slope });
    }
    cells
}

/// Writes a version-2 layout (seed and preset as given).
pub fn save_layout(path: &str, cells: &Cells, seed: u32, preset: i64) {
    let mut keys: Vec<(i32, i32)> = cells.keys().copied().collect();
    keys.sort_by_key(|k| (k.1, k.0));
    let records: Vec<String> = keys
        .iter()
        .map(|&(x, z)| {
            let c = cells[&(x, z)];
            let water = c.water.map_or(-1, |l| (l * 2.0).round() as i64);
            let slope = if c.sloped() { format!(",\"slope\":[{:.5},{:.5}]", c.slope.x, c.slope.y) } else { String::new() };
            let height = if c.sloped() { format!("{:.5}", c.h) } else { format!("{:.1}", c.h) };
            format!("{{\"height\":{height},\"water\":{water},\"x\":{x},\"z\":{z}{slope}}}")
        })
        .collect();
    let text = format!("{{\"cells\":[{}],\"preset\":{preset},\"seed\":{seed},\"version\":2}}\n", records.join(","));
    std::fs::write(path, text).unwrap_or_else(|e| panic!("cannot write {path}: {e}"));
}

/// The surface height of the cells at p (the plane of the cell under p), if p is on a cell.
pub fn cell_surface(cells: &Cells, p: Vec2) -> Option<(f32, Cell)> {
    let key = (p.x.floor() as i32, p.y.floor() as i32);
    cells.get(&key).map(|c| (c.plane(key, p), *c))
}

/// What a ramp stroke did.
pub struct RampDone {
    /// The stroke's ends after snapping (see `snap_stroke`).
    pub a: Vec2,
    pub b: Vec2,
    pub cells: usize,
    pub rise: f32,
    pub length: f32,
    pub gradient: f32,
}

/// Round r10: the stroke rule. A stroke within 7.5 degrees of a grid axis is made exactly
/// axis-aligned and snapped so the ramp is exactly `width` cells across and ends on cell edges: its
/// centre line on a cell edge for an even width, on a row of cell centres for an odd one, its ends on
/// the nearest cell edge along the axis. Any other stroke is kept as drawn; the ramp is then the
/// cells whose centres lie in the strip, and its ends and sides follow staircases of cell edges.
pub fn snap_stroke(a: Vec2, b: Vec2, width: f32) -> (Vec2, Vec2) {
    let d = b - a;
    if d.length() < 1e-6 {
        return (a, b);
    }
    let along_x = d.x.abs() >= d.y.abs();
    let off_axis = if along_x { (d.y / d.x).atan().abs() } else { (d.x / d.y).atan().abs() };
    if off_axis > 7.5_f32.to_radians() {
        return (a, b);
    }
    let w = width.round().max(1.0) as i32;
    let across = |v: f32| if w % 2 == 0 { v.round() } else { (v - 0.5).round() + 0.5 };
    if along_x {
        let z = across((a.y + b.y) * 0.5);
        (Vec2::new(a.x.round(), z), Vec2::new(b.x.round(), z))
    } else {
        let x = across((a.x + b.x) * 0.5);
        (Vec2::new(x, a.y.round()), Vec2::new(x, b.y.round()))
    }
}

/// The ramp stroke (round r9, snapped since r10): the ends' heights are those of the cells under
/// the drawn points a and b; the stroke is snapped (`snap_stroke`), and every cell whose centre lies
/// within `width / 2` of the snapped segment and between its ends becomes a slope cell on the plane
/// from (a, ha) to (b, hb).
pub fn ramp(cells: &mut Cells, a: Vec2, b: Vec2, width: f32) -> Result<RampDone, String> {
    let (ha, ca) = cell_surface(cells, a).ok_or_else(|| format!("start ({:.2}, {:.2}) is off the island", a.x, a.y))?;
    let (hb, cb) = cell_surface(cells, b).ok_or_else(|| format!("end ({:.2}, {:.2}) is off the island", b.x, b.y))?;
    if ca.water.is_some() {
        return Err(format!("start ({:.2}, {:.2}) is water", a.x, a.y));
    }
    if cb.water.is_some() {
        return Err(format!("end ({:.2}, {:.2}) is water", b.x, b.y));
    }
    let (a, b) = snap_stroke(a, b, width);
    let length = (b - a).length();
    if length < 2.0 {
        return Err(format!("too short ({length:.2} m, at least 2 m)"));
    }
    let rise = hb - ha;
    if rise.abs() < 0.05 {
        return Err(format!("both ends at the same height ({ha:.2} m)"));
    }
    let gradient = rise.abs() / length;
    if gradient > MAX_GRADIENT {
        return Err(format!("too steep (gradient {gradient:.2}, at most {MAX_GRADIENT})"));
    }
    let dir = (b - a) / length;
    let mut picked = Vec::new();
    for (&key, cell) in cells.iter() {
        let c = centre_of(key);
        let t = (c - a).dot(dir) / length;
        if !(-1e-4..=1.0 + 1e-4).contains(&t) {
            continue;
        }
        let off = (c - (a + dir * length * t)).length();
        if off > width * 0.5 + 1e-4 {
            continue;
        }
        if cell.water.is_some() {
            return Err(format!("the strip covers water at ({}, {})", key.0, key.1));
        }
        picked.push((key, t.clamp(0.0, 1.0)));
    }
    let slope = dir * (rise / length);
    for &(key, t) in &picked {
        cells.insert(key, Cell { h: ha + rise * t, water: None, slope });
    }
    Ok(RampDone { a, b, cells: picked.len(), rise, length, gradient })
}

/// The cells of one terrace wall (an edge between two dry flat cells rising 0.75 m or more), for
/// placing ramps across walls (`--synthetic-ramps`, the edit test).
pub fn wall_edges(cells: &Cells) -> Vec<((i32, i32), (i32, i32))> {
    let mut keys: Vec<(i32, i32)> = cells.keys().copied().collect();
    keys.sort();
    let mut out = Vec::new();
    for &(x, z) in &keys {
        let a = cells[&(x, z)];
        for (dx, dz) in [(1, 0), (0, 1)] {
            let Some(b) = cells.get(&(x + dx, z + dz)) else { continue };
            if a.water.is_none() && b.water.is_none() && !a.sloped() && !b.sloped() && (a.h - b.h).abs() >= 0.75 {
                out.push(((x, z), (x + dx, z + dz)));
            }
        }
    }
    out
}

/// A ramp of `width` across the wall edge between cells k1 and k2 (one of them higher), long
/// enough for a gradient near `want`; its centre line runs on a cell edge so a width of 2 takes
/// two rows of cells. Returns (a, b) from the low side to the high side.
pub fn ramp_across(cells: &Cells, k1: (i32, i32), k2: (i32, i32), want: f32) -> (Vec2, Vec2) {
    let (c1, c2) = (cells[&k1], cells[&k2]);
    let (low, high) = if c1.h < c2.h { (k1, k2) } else { (k2, k1) };
    let up = Vec2::new((high.0 - low.0) as f32, (high.1 - low.1) as f32);
    let across = Vec2::new(-up.y, up.x);
    let rise = (cells[&high].h - cells[&low].h).abs();
    // An even number of metres, half on each side of the wall.
    let half = ((rise / want) * 0.5).ceil().max(1.0);
    let edge = (centre_of(low) + centre_of(high)) * 0.5;
    let mid = edge + across * 0.5;
    (mid - up * half, mid + up * half)
}

/// Round r10: a ramp across the wall edge between k1 and k2 turned `angle_deg` from the wall's
/// normal (0 gives `ramp_across`), centred on the edge's midpoint, about `rise / want` long.
/// Returns (a, b) from the low side to the high side.
pub fn ramp_across_turned(cells: &Cells, k1: (i32, i32), k2: (i32, i32), want: f32, angle_deg: f32) -> (Vec2, Vec2) {
    if angle_deg.abs() < 1e-3 {
        return ramp_across(cells, k1, k2, want);
    }
    let (c1, c2) = (cells[&k1], cells[&k2]);
    let (low, high) = if c1.h < c2.h { (k1, k2) } else { (k2, k1) };
    let up = Vec2::new((high.0 - low.0) as f32, (high.1 - low.1) as f32);
    let (s, c) = angle_deg.to_radians().sin_cos();
    let dir = Vec2::new(up.x * c - up.y * s, up.x * s + up.y * c);
    let rise = (cells[&high].h - cells[&low].h).abs();
    let half = ((rise / want) * 0.5).ceil().max(1.0) + 0.5;
    let mid = (centre_of(low) + centre_of(high)) * 0.5;
    (mid - dir * half, mid + dir * half)
}

fn smooth_min(a: f32, b: f32, k: f32) -> f32 {
    let h = (0.5 + 0.5 * (b - a) / k).clamp(0.0, 1.0);
    b + (a - b) * h - k * h * (1.0 - h)
}

/// A terraced island of about `target` cells with two ponds, for sizes the
/// exported layouts do not cover (the 4,096-cell design size).
pub fn synthetic(target: usize, seed: u32) -> Cells {
    let inside = |x: i32, z: i32, scale: f32| -> bool {
        let p = Vec2::new(x as f32 + 0.5, z as f32 + 0.5) / scale;
        let lobe = |c: Vec2, r: Vec2| ((p - c) / r).length();
        let d = smooth_min(
            smooth_min(lobe(Vec2::new(-0.35, -0.10), Vec2::new(0.75, 0.50)), lobe(Vec2::new(0.40, 0.15), Vec2::new(0.60, 0.45)), 0.4),
            lobe(Vec2::new(0.0, 0.45), Vec2::new(0.50, 0.30)),
            0.4,
        );
        d < 1.0 + 0.16 * (vnoise(p.x * 3.1, p.y * 3.1, seed) - 0.5)
    };
    let (mut low, mut high) = (4.0_f32, 120.0_f32);
    let mut scale = 30.0;
    for _ in 0..24 {
        scale = 0.5 * (low + high);
        let reach = (scale * 1.6) as i32 + 2;
        let count = (-reach..=reach).flat_map(|z| (-reach..=reach).map(move |x| (x, z))).filter(|&(x, z)| inside(x, z, scale)).count();
        if count > target {
            high = scale;
        } else {
            low = scale;
        }
    }
    let reach = (scale * 1.6) as i32 + 2;
    let mut cells = Cells::new();
    for z in -reach..=reach {
        for x in -reach..=reach {
            if !inside(x, z, scale) {
                continue;
            }
            let n = vnoise(x as f32 * 0.045 + 11.0, z as f32 * 0.045 + 7.0, seed ^ 77);
            let v = 0.6 * n + 0.4 * (0.5 - z as f32 / (2.0 * scale));
            let h = if v > 0.66 {
                5.0
            } else if v > 0.50 {
                3.5
            } else if v > 0.34 {
                2.5
            } else {
                1.5
            };
            cells.insert((x, z), Cell::flat(h, None));
        }
    }
    let grow = (target as f32 / 623.0).sqrt().clamp(1.0, 2.2);
    for (want, at, radius) in [
        (3.5_f32, Vec2::new(-0.30 * scale, -0.10 * scale), Vec2::new(5.5, 3.3) * grow),
        (1.5_f32, Vec2::new(0.35 * scale, 0.30 * scale), Vec2::new(6.5, 3.6) * grow),
    ] {
        let mut best: Option<((i32, i32), f32)> = None;
        for (&key, cell) in &cells {
            if (cell.h - want).abs() > 0.01 {
                continue;
            }
            let d = (Vec2::new(key.0 as f32, key.1 as f32) - at).length();
            if best.map_or(true, |(_, bd)| d < bd) {
                best = Some((key, d));
            }
        }
        let Some((centre, _)) = best else { continue };
        let keys: Vec<(i32, i32)> = cells.keys().copied().collect();
        for key in keys {
            let offset = Vec2::new((key.0 - centre.0) as f32, (key.1 - centre.1) as f32) / radius;
            if offset.length() < 1.0 && (cells[&key].h - want).abs() < 0.01 {
                cells.insert(key, Cell::flat(want - 0.5, Some(want)));
            }
        }
    }
    cells
}

/// Fine sample spacing in metres.
pub const STEP: f32 = 0.25;
/// Empty margin kept around the cells so the widest blur has room.
const MARGIN: f32 = 18.0;

// Terrace steps (round r6). Every cell edge between two land cells of different heights is a
// step. The steps form a graph on the cell corners; its chains (between junctions of three or
// more steps and the rim) are subdivided at 0.5 m, relaxed like the outline and kept within
// `STEP_MAX_MOVE` of the cell edges, so a stair of cells becomes one straight or gently curved
// run. Each piece keeps the levels of the cell edge it came from, so two levels that step down
// at the same cell edge stay one wall. Heights near a step come from which side of its smooth
// contour a point lies on; a step of 0.75 m or more (or one that holds a pond) is a wall: a hard
// step that the top surface is cut along and a ribbon of cut rock fills.
/// How far a point looks for a step.
const STEP_BAND: f32 = 1.2;
/// The most a relaxed contour point may move from its cell corner or edge midpoint.
const STEP_MAX_MOVE: f32 = 0.6;
/// Relaxation passes on the 0.5 m chain points (a Gaussian of about 1.6 m along the chain).
const STEP_RELAX: usize = 20;
/// Half width of a soft step (rises under 0.75 m): a lawn slope, not a wall.
const SOFT_HALF: f32 = 0.22;
/// A pond's rim above its surface where a wall or the outline holds it, and the sill under the
/// surface in a fall's notch.
const RIM_UP: f32 = 0.10;
const SILL: f32 = -0.03;

/// One piece of a relaxed terrace contour.
#[derive(Clone, Copy, Debug)]
pub struct Step {
    pub a: Vec2,
    pub b: Vec2,
    /// Unit normals toward the low side at a and b.
    pub na: Vec2,
    pub nb: Vec2,
    /// The levels of the two sides at the middle of this piece's cell edge (exact for flat cells).
    pub high: f32,
    pub low: f32,
    pub high_water: Option<f32>,
    pub low_water: Option<f32>,
    /// Round r9: the cells of the high and low side (their planes give each side's height).
    pub high_cell: (i32, i32),
    pub low_cell: (i32, i32),
    /// Whether this piece is a wall (decided per chain where a slope cell is involved).
    pub is_wall: bool,
    /// Round r10: distance along the chain from a (resp. b) to a free end of the chain (a corner
    /// inside the island where only this chain's step ends: the tip of a ramp's cheek), or infinity.
    pub fade0: f32,
    pub fade1: f32,
}

/// The old rule for one cell edge: a rise of 0.75 m or more (not in the bed under one pond), or
/// the high side holds a pond the low side does not share.
fn wall_rule(rise: f32, high_water: Option<f32>, low_water: Option<f32>) -> bool {
    let same_pond = matches!((high_water, low_water), (Some(a), Some(b)) if (a - b).abs() < 1e-3);
    (rise >= 0.75 && !same_pond) || pond_wall_rule(high_water, low_water)
}

fn pond_wall_rule(high_water: Option<f32>, low_water: Option<f32>) -> bool {
    match high_water {
        Some(level) => low_water.map_or(true, |other| other < level - 0.2),
        None => false,
    }
}

impl Step {
    /// The high side holds a pond that the low side does not share.
    pub fn pond_wall(&self) -> bool {
        pond_wall_rule(self.high_water, self.low_water)
    }

    /// A hard step with a rock face. A step in the bed under one pond is not (it would show
    /// through the water as a pale line); it stays a soft slope.
    pub fn wall(&self) -> bool {
        self.is_wall
    }

    fn closest(&self, p: Vec2) -> (Vec2, f32) {
        let ab = self.b - self.a;
        let t = ((p - self.a).dot(ab) / ab.length_squared().max(1e-9)).clamp(0.0, 1.0);
        (self.a + ab * t, t)
    }

    pub fn normal_at(&self, t: f32) -> Vec2 {
        self.na.lerp(self.nb, t).normalize_or_zero()
    }

    /// Distance and signed distance (positive on the high side).
    pub fn signed(&self, p: Vec2) -> (f32, f32) {
        let (q, t) = self.closest(p);
        let d = (p - q).length();
        if (q - p).dot(self.normal_at(t)) >= 0.0 {
            (d, d)
        } else {
            (d, -d)
        }
    }

    /// A linear signed value across the step near this piece (positive on the high side), for cutting.
    pub fn line_sd(&self, p: Vec2) -> f32 {
        let (q, t) = self.closest(p);
        (q - p).dot(self.normal_at(t))
    }

    /// Round r10: how far along the chain p lies from its free end (negative beyond it), or infinity.
    pub fn tip_distance(&self, p: Vec2) -> f32 {
        if self.fade0.is_infinite() && self.fade1.is_infinite() {
            return f32::INFINITY;
        }
        let ab = self.b - self.a;
        let len = ab.length().max(1e-6);
        let u = (p - self.a).dot(ab) / len;
        (self.fade0 + u).min(self.fade1 + len - u)
    }

    /// The low-side normal at the point of this piece closest to p.
    pub fn normal_near(&self, p: Vec2) -> Vec2 {
        let (_, t) = self.closest(p);
        self.normal_at(t)
    }
}

#[derive(Clone, Copy)]
struct StepLabel {
    high: f32,
    low: f32,
    high_water: Option<f32>,
    low_water: Option<f32>,
    toward_low: Vec2,
    high_cell: (i32, i32),
    low_cell: (i32, i32),
    /// A slope cell on either side.
    sloped: bool,
    /// The largest rise over this half edge.
    rise: f32,
    /// Round r10: the rise at the half edge's two ends (in its own direction).
    r0: f32,
    r1: f32,
}

impl StepLabel {
    fn reversed(mut self) -> StepLabel {
        std::mem::swap(&mut self.r0, &mut self.r1);
        self
    }
}

/// Whether the edge between two neighbouring cells is a step, and its labels per half edge (from
/// c0 to the midpoint, from the midpoint to c1). Flat cells step wherever their heights differ; a
/// slope cell is continuous with a dry neighbour whose surface agrees with its own along the shared
/// edge to within `CONTINUOUS` at both ends.
fn edge_labels(ka: (i32, i32), a: Cell, kb: (i32, i32), b: Cell, c0: Vec2, c1: Vec2) -> Option<[StepLabel; 2]> {
    let dir = Vec2::new((kb.0 - ka.0) as f32, (kb.1 - ka.1) as f32);
    let sloped = a.sloped() || b.sloped();
    if !sloped {
        if (a.h - b.h).abs() < 1e-4 {
            return None;
        }
        let (hi, lo, toward_low, hk, lk) = if a.h > b.h { (a, b, dir, ka, kb) } else { (b, a, -dir, kb, ka) };
        let label = StepLabel { high: hi.h, low: lo.h, high_water: hi.water, low_water: lo.water, toward_low, high_cell: hk, low_cell: lk, sloped: false, rise: hi.h - lo.h, r0: hi.h - lo.h, r1: hi.h - lo.h };
        return Some([label, label]);
    }
    let diff = |p: Vec2| a.plane(ka, p) - b.plane(kb, p);
    let (d0, d1) = (diff(c0), diff(c1));
    let wet = a.water.is_some() || b.water.is_some();
    let tolerance = if wet { 1e-4 } else { CONTINUOUS };
    if d0.abs() <= tolerance && d1.abs() <= tolerance {
        return None;
    }
    let mid = (c0 + c1) * 0.5;
    let half = |p0: Vec2, p1: Vec2| {
        let q = (p0 + p1) * 0.5;
        let mut d = diff(q);
        if d.abs() < 1e-5 {
            d = d0 + d1;
        }
        let (hi, lo, toward_low, hk, lk) = if d > 0.0 { (a, b, dir, ka, kb) } else { (b, a, -dir, kb, ka) };
        StepLabel {
            high: hi.plane(hk, q),
            low: lo.plane(lk, q),
            high_water: hi.water,
            low_water: lo.water,
            toward_low,
            high_cell: hk,
            low_cell: lk,
            sloped: true,
            rise: diff(p0).abs().max(diff(p1).abs()),
            r0: diff(p0).abs(),
            r1: diff(p1).abs(),
        }
    };
    Some([half(c0, mid), half(mid, c1)])
}

/// The relaxed terrace contours of a set of cells, and the cell corners inside the island where
/// three or more steps meet.
fn build_steps(cells: &Cells) -> (Vec<Step>, Vec<(i32, i32)>) {
    let mut keys: Vec<(i32, i32)> = cells.keys().copied().collect();
    keys.sort();
    let mut edges: Vec<((i32, i32), (i32, i32), [StepLabel; 2])> = Vec::new();
    for &(x, z) in &keys {
        let a = cells[&(x, z)];
        for (dx, dz) in [(1, 0), (0, 1)] {
            let Some(b) = cells.get(&(x + dx, z + dz)) else { continue };
            let (c0, c1) = if dx == 1 { ((x + 1, z), (x + 1, z + 1)) } else { ((x, z + 1), (x + 1, z + 1)) };
            let corner = |c: (i32, i32)| Vec2::new(c.0 as f32, c.1 as f32);
            if let Some(labels) = edge_labels((x, z), a, (x + dx, z + dz), *b, corner(c0), corner(c1)) {
                edges.push((c0, c1, labels));
            }
        }
    }
    let mut at: HashMap<(i32, i32), Vec<usize>> = HashMap::new();
    for (i, e) in edges.iter().enumerate() {
        at.entry(e.0).or_default().push(i);
        at.entry(e.1).or_default().push(i);
    }
    let on_rim = |c: (i32, i32)| [(c.0 - 1, c.1 - 1), (c.0, c.1 - 1), (c.0 - 1, c.1), (c.0, c.1)].iter().any(|k| !cells.contains_key(k));
    let fixed = |c: (i32, i32)| at[&c].len() != 2 || on_rim(c);
    let mut used = vec![false; edges.len()];
    // (corners, edge per span, closed)
    let mut chains: Vec<(Vec<(i32, i32)>, Vec<usize>, bool)> = Vec::new();
    let mut walk = |start: (i32, i32), first: usize, used: &mut Vec<bool>| -> (Vec<(i32, i32)>, Vec<usize>, bool) {
        let mut corners = vec![start];
        let mut spans = Vec::new();
        let (mut at_corner, mut e) = (start, first);
        loop {
            used[e] = true;
            spans.push(e);
            let next = if edges[e].0 == at_corner { edges[e].1 } else { edges[e].0 };
            if next == start {
                return (corners, spans, true);
            }
            corners.push(next);
            if fixed(next) {
                return (corners, spans, false);
            }
            let mut options: Vec<usize> = at[&next].iter().copied().filter(|&k| !used[k]).collect();
            options.sort();
            match options.first() {
                Some(&k) => {
                    at_corner = next;
                    e = k;
                }
                None => return (corners, spans, false),
            }
        }
    };
    let mut corners_sorted: Vec<(i32, i32)> = at.keys().copied().collect();
    corners_sorted.sort();
    for &c in &corners_sorted {
        if !fixed(c) {
            continue;
        }
        let mut list = at[&c].clone();
        list.sort();
        for e in list {
            if !used[e] {
                chains.push(walk(c, e, &mut used));
            }
        }
    }
    for e in 0..edges.len() {
        if !used[e] {
            chains.push(walk(edges[e].0, e, &mut used));
        }
    }

    // Labels per chain (one per 0.5 m piece) and whether each chain beside a slope cell is a wall.
    let corner = |c: (i32, i32)| Vec2::new(c.0 as f32, c.1 as f32);
    let chain_labels: Vec<Vec<StepLabel>> = chains
        .iter()
        .map(|(corners, spans, _)| {
            let mut labels: Vec<StepLabel> = Vec::new();
            for (k, &e) in spans.iter().enumerate() {
                // The half labels run from the edge's c0; a span walked the other way takes them reversed.
                let [h0, h1] = edges[e].2;
                let (first, second) = if corners[k] == edges[e].0 { (h0, h1) } else { (h1.reversed(), h0.reversed()) };
                labels.push(first);
                labels.push(second);
            }
            labels
        })
        .collect();
    // Round r9: a chain beside a slope cell is a wall as a whole when its rise reaches 0.75 m
    // anywhere (so a ramp's cheek is one wedge of wall that tapers to nothing); a chain of flat
    // cells keeps the rule per piece.
    let sloped_chain: Vec<bool> = chain_labels.iter().map(|ls| ls.iter().any(|l| l.sloped)).collect();
    let mut chain_wall: Vec<bool> = chain_labels.iter().map(|ls| ls.iter().any(|l| wall_rule(l.rise, l.high_water, l.low_water))).collect();
    // Round r10: where a ramp cuts through a terrace wall, the wall ends at a corner where the ramp's
    // cheeks begin. A cheek lower than 0.75 m was a soft bank, steep enough to be painted as a bare
    // facet, and the wall's end stood open against it (a dark slit, the backing). A sloped chain that
    // starts where a wall ends (a junction of three or more steps inside the island) with a rise of
    // 0.12 m or more there is now a wall too: the wall turns into the ramp's cheeks, which taper away.
    let mut wall_ends: HashMap<(i32, i32), usize> = HashMap::new();
    for (i, (corners, _, closed)) in chains.iter().enumerate() {
        if *closed {
            continue;
        }
        let ls = &chain_labels[i];
        let wall_at = |l: &StepLabel| if sloped_chain[i] { chain_wall[i] } else { wall_rule(l.high - l.low, l.high_water, l.low_water) };
        if wall_at(&ls[0]) {
            *wall_ends.entry(corners[0]).or_default() += 1;
        }
        if wall_at(&ls[ls.len() - 1]) {
            *wall_ends.entry(*corners.last().unwrap()).or_default() += 1;
        }
    }
    let junction_corner = |c: (i32, i32)| at[&c].len() >= 3 && !on_rim(c);
    for (i, (corners, _, closed)) in chains.iter().enumerate() {
        if *closed || !sloped_chain[i] || chain_wall[i] {
            continue;
        }
        let ls = &chain_labels[i];
        let ends = [(corners[0], ls[0].r0), (*corners.last().unwrap(), ls[ls.len() - 1].r1)];
        if ends.iter().any(|&(c, rise)| junction_corner(c) && wall_ends.get(&c).copied().unwrap_or(0) > 0 && rise >= 0.12) {
            chain_wall[i] = true;
        }
    }
    let mut steps = Vec::new();
    for (ci, (corners, spans, closed)) in chains.into_iter().enumerate() {
        let mut points: Vec<Vec2> = Vec::new();
        for k in 0..spans.len() {
            let a = corner(corners[k]);
            let b = if k + 1 < corners.len() { corner(corners[k + 1]) } else { corner(corners[0]) };
            points.push(a);
            points.push((a + b) * 0.5);
        }
        let labels = &chain_labels[ci];
        let (sloped, whole_wall) = (sloped_chain[ci], chain_wall[ci]);
        let is_wall = |l: &StepLabel| if sloped { whole_wall } else { wall_rule(l.high - l.low, l.high_water, l.low_water) };
        // Free ends (round r10): a corner inside the island where only this chain's step ends.
        let free = |c: (i32, i32)| at[&c].len() == 1 && !on_rim(c);
        let (free0, free1) = if closed { (false, false) } else { (free(corners[0]), free(*corners.last().unwrap())) };
        if !closed {
            points.push(corner(*corners.last().unwrap()));
        }
        let original = points.clone();
        let n = points.len();
        for _ in 0..STEP_RELAX {
            let copy = points.clone();
            for k in 0..n {
                let (prev, next) = if closed {
                    ((k + n - 1) % n, (k + 1) % n)
                } else if k == 0 || k == n - 1 {
                    continue;
                } else {
                    (k - 1, k + 1)
                };
                let relaxed = copy[k] * 0.5 + (copy[prev] + copy[next]) * 0.25;
                let moved = relaxed - original[k];
                points[k] = original[k] + moved.clamp_length_max(STEP_MAX_MOVE);
            }
        }
        let pieces = if closed { n } else { n - 1 };
        let mut normals: Vec<Vec2> = Vec::with_capacity(pieces);
        for k in 0..pieces {
            let d = points[(k + 1) % n] - points[k];
            let mut normal = Vec2::new(-d.y, d.x).normalize_or_zero();
            if normal.dot(labels[k].toward_low) < 0.0 {
                normal = -normal;
            }
            normals.push(normal);
        }
        let joint = |k: usize, other: Option<usize>| -> Vec2 { other.map_or(normals[k], |o| (normals[k] + normals[o]).normalize_or_zero()) };
        // Arc length to each point, for the distance to a free end.
        let mut arc = vec![0.0_f32; pieces + 1];
        for k in 0..pieces {
            arc[k + 1] = arc[k] + (points[(k + 1) % n] - points[k]).length();
        }
        let total = arc[pieces];
        for k in 0..pieces {
            let before = if k > 0 { Some(k - 1) } else if closed { Some(pieces - 1) } else { None };
            let after = if k + 1 < pieces { Some(k + 1) } else if closed { Some(0) } else { None };
            let l = labels[k];
            let fade0 = if free0 { arc[k] } else { f32::INFINITY };
            let fade1 = if free1 { total - arc[k + 1] } else { f32::INFINITY };
            steps.push(Step {
                fade0,
                fade1,
                a: points[k],
                b: points[(k + 1) % n],
                na: joint(k, before),
                nb: joint(k, after),
                high: l.high,
                low: l.low,
                high_water: l.high_water,
                low_water: l.low_water,
                high_cell: l.high_cell,
                low_cell: l.low_cell,
                is_wall: is_wall(&l),
            });
        }
        // Chains that end at the rim run on past it, so points beyond the cells still find their side.
        if !closed && pieces > 0 {
            for (end, inner, label) in [(0usize, 1usize, labels[0]), (n - 1, n - 2, labels[pieces - 1])] {
                let c = corners[if end == 0 { 0 } else { corners.len() - 1 }];
                if !on_rim(c) {
                    continue;
                }
                let dir = (points[end] - points[inner]).normalize_or_zero();
                let piece = if end == 0 { 0 } else { pieces - 1 };
                let normal = normals[piece];
                steps.push(Step {
                    fade0: f32::INFINITY,
                    fade1: f32::INFINITY,
                    a: points[end],
                    b: points[end] + dir * 1.5,
                    na: normal,
                    nb: normal,
                    high: label.high,
                    low: label.low,
                    high_water: label.high_water,
                    low_water: label.low_water,
                    high_cell: label.high_cell,
                    low_cell: label.low_cell,
                    is_wall: is_wall(&label),
                });
            }
        }
    }
    let junctions = corners_sorted.iter().copied().filter(|&c| at[&c].len() >= 3 && !on_rim(c)).collect();
    (steps, junctions)
}

/// Round r9 (F1): a cell corner inside the island where three or more steps meet and one of them
/// is a wall. Within `JUNCTION_REACH` of it the top surface is cut into sectors by the first piece
/// of every step leaving it, and the wall ribbons run to the corner itself and share its vertical
/// edge, so the wall turns the corner as one piece of stone.
#[derive(Clone, Debug)]
pub struct Junction {
    pub at: Vec2,
    /// The step pieces that start or end at the corner, by angle (counter-clockwise).
    pub rays: Vec<usize>,
    /// Unit direction of each ray away from the corner.
    pub dirs: Vec<Vec2>,
}

/// Grid cells whose centre lies this close to a junction are cut into its sectors.
const JUNCTION_REACH: f32 = 0.45;

pub struct Field {
    pub nx: usize,
    pub nz: usize,
    /// World position of sample (0, 0).
    pub origin: Vec2,
    /// Blurred occupancy, sigma 0.45 m. The outline is its 0.5 contour.
    pub land1: Vec<f32>,
    /// Blurred occupancy, sigma 2.5 m: how far inside the rim a point is, locally.
    pub land2: Vec<f32>,
    /// Blurred occupancy, sigma 7 m: the same on the scale of the whole body.
    pub land3: Vec<f32>,
    /// Smoothed top height.
    pub height: Vec<f32>,
    /// Water level of the cell under the sample, or NaN.
    pub water: Vec<f32>,
    /// Blurred "is water" mask, sigma 0.5 m, for banks.
    pub wet: Vec<f32>,
    /// Relaxed terrace contours and a 1 m bucket index of them.
    pub steps: Vec<Step>,
    buckets: HashMap<(i32, i32), Vec<u32>>,
    /// Where ponds spill (falls), placed on the walls and the outline.
    pub spills: Vec<crate::water::Spill>,
    /// Per sample: a wall within 0.4 m (the grid cannot interpolate across it).
    near_wall: Vec<bool>,
    pub cells: Cells,
    floor: f32,
    /// Round r9: any slope cell (otherwise every height comes from flat cells, as before).
    pub has_slopes: bool,
    slope_near: std::collections::HashSet<(i32, i32)>,
    /// Per step piece: a side lies on or beside a slope cell (its ground is not its flat level).
    step_sloped: Vec<bool>,
    /// Round r9: where three or more steps meet with a wall among them, by corner.
    pub junctions: Vec<Junction>,
    junction_at: HashMap<(i32, i32), usize>,
}

/// Half width of the rounding where a slope meets a continuous neighbour (a ramp's foot and top).
/// Round r10: 0.4 (from 0.3), so the small mismatches now counted as continuous roll out softly.
const CREASE: f32 = 0.4;
/// Round r10: how far from a cheek's free tip its two sides start closing on each other.
const TIP_FADE: f32 = 0.7;

fn gaussian(grid: &[f32], nx: usize, nz: usize, sigma_m: f32) -> Vec<f32> {
    let sigma = sigma_m / STEP;
    let radius = (sigma * 3.0).ceil() as i32;
    let kernel: Vec<f32> = (-radius..=radius).map(|i| (-(i * i) as f32 / (2.0 * sigma * sigma)).exp()).collect();
    let total: f32 = kernel.iter().sum();
    let mut pass = vec![0.0; grid.len()];
    for z in 0..nz {
        for x in 0..nx {
            let mut sum = 0.0;
            for (k, weight) in kernel.iter().enumerate() {
                let sx = (x as i32 + k as i32 - radius).clamp(0, nx as i32 - 1) as usize;
                sum += grid[z * nx + sx] * weight;
            }
            pass[z * nx + x] = sum / total;
        }
    }
    let mut out = vec![0.0; grid.len()];
    for z in 0..nz {
        for x in 0..nx {
            let mut sum = 0.0;
            for (k, weight) in kernel.iter().enumerate() {
                let sz = (z as i32 + k as i32 - radius).clamp(0, nz as i32 - 1) as usize;
                sum += pass[sz * nx + x] * weight;
            }
            out[z * nx + x] = sum / total;
        }
    }
    out
}

impl Field {
    pub fn build(cells: &Cells) -> Field {
        let (mut x0, mut x1, mut z0, mut z1) = (i32::MAX, i32::MIN, i32::MAX, i32::MIN);
        for &(x, z) in cells.keys() {
            x0 = x0.min(x);
            x1 = x1.max(x + 1);
            z0 = z0.min(z);
            z1 = z1.max(z + 1);
        }
        // Samples sit at half-step offsets so none lies on a cell boundary.
        let origin = Vec2::new(x0 as f32 - MARGIN + STEP * 0.5, z0 as f32 - MARGIN + STEP * 0.5);
        let nx = (((x1 - x0) as f32 + 2.0 * MARGIN) / STEP) as usize;
        let nz = (((z1 - z0) as f32 + 2.0 * MARGIN) / STEP) as usize;
        let mut land = vec![0.0; nx * nz];
        let mut raw = vec![0.0; nx * nz];
        let mut water = vec![f32::NAN; nx * nz];
        let mut wet = vec![0.0; nx * nz];
        for j in 0..nz {
            for i in 0..nx {
                let p = origin + Vec2::new(i as f32, j as f32) * STEP;
                if let Some(cell) = cells.get(&(p.x.floor() as i32, p.y.floor() as i32)) {
                    land[j * nx + i] = 1.0;
                    raw[j * nx + i] = cell.h;
                    if let Some(level) = cell.water {
                        water[j * nx + i] = level;
                        wet[j * nx + i] = 1.0;
                    }
                }
            }
        }
        let _ = raw;
        let land1 = gaussian(&land, nx, nz, 0.45);
        let floor = cells.values().map(|c| c.h).fold(f32::MAX, f32::min);
        let (steps, corners) = build_steps(cells);
        let has_slopes = cells.values().any(|c| c.sloped());
        // Slope cells and their eight neighbours (four before r10): the only cells whose ground is
        // not their flat height.
        let mut slope_near = std::collections::HashSet::new();
        for (&(x, z), c) in cells.iter() {
            if c.sloped() {
                for dz in -1..=1 {
                    for dx in -1..=1 {
                        slope_near.insert((x + dx, z + dz));
                    }
                }
            }
        }
        let mut junctions = Vec::new();
        let mut junction_at = HashMap::new();
        for c in corners {
            let at = Vec2::new(c.0 as f32, c.1 as f32);
            let mut rays: Vec<(f32, usize, Vec2)> = Vec::new();
            for (i, s) in steps.iter().enumerate() {
                let other = if s.a == at { s.b } else if s.b == at { s.a } else { continue };
                let d = (other - at).normalize_or_zero();
                rays.push((d.y.atan2(d.x), i, d));
            }
            if rays.len() < 3 || !rays.iter().any(|r| steps[r.1].wall()) {
                continue;
            }
            rays.sort_by(|x, y| x.0.partial_cmp(&y.0).unwrap());
            junction_at.insert(c, junctions.len());
            junctions.push(Junction { at, rays: rays.iter().map(|r| r.1).collect(), dirs: rays.iter().map(|r| r.2).collect() });
        }
        let mut buckets: HashMap<(i32, i32), Vec<u32>> = HashMap::new();
        for (i, s) in steps.iter().enumerate() {
            let lo = s.a.min(s.b) - Vec2::splat(STEP_BAND);
            let hi = s.a.max(s.b) + Vec2::splat(STEP_BAND);
            for z in lo.y.floor() as i32..=hi.y.floor() as i32 {
                for x in lo.x.floor() as i32..=hi.x.floor() as i32 {
                    buckets.entry((x, z)).or_default().push(i as u32);
                }
            }
        }
        let mut field = Field {
            nx,
            nz,
            origin,
            land1,
            land2: gaussian(&land, nx, nz, 2.5),
            land3: gaussian(&land, nx, nz, 7.0),
            height: vec![0.0; nx * nz],
            water,
            wet: gaussian(&wet, nx, nz, 0.5),
            steps,
            buckets,
            spills: Vec::new(),
            near_wall: vec![false; nx * nz],
            cells: cells.clone(),
            floor,
            has_slopes,
            step_sloped: Vec::new(),
            slope_near,
            junctions,
            junction_at,
        };
        field.step_sloped = field.steps.iter().map(|s| field.slope_near.contains(&s.high_cell) || field.slope_near.contains(&s.low_cell)).collect();
        field.spills = crate::water::junctions(cells).into_iter().map(|s| field.place_spill(s)).collect();
        for j in 0..nz {
            for i in 0..nx {
                let p = field.point(i, j);
                let s = j * nx + i;
                field.height[s] = field.surface(p);
                field.near_wall[s] = field.nearest_step(p).is_some_and(|(k, _, d)| d < 0.4 && field.steps[k].wall());
            }
        }
        field
    }

    /// The nearest step piece within the band: (index, signed distance, distance).
    pub fn nearest_step(&self, p: Vec2) -> Option<(usize, f32, f32)> {
        let list = self.buckets.get(&(p.x.floor() as i32, p.y.floor() as i32))?;
        let mut best: Option<(usize, f32, f32)> = None;
        for &i in list {
            let (d, sd) = self.steps[i as usize].signed(p);
            if best.map_or(true, |b| d < b.2) {
                best = Some((i as usize, sd, d));
            }
        }
        best.filter(|b| b.2 <= STEP_BAND)
    }

    /// The junction whose cut zone holds p, if any.
    pub fn junction_near(&self, p: Vec2) -> Option<usize> {
        let key = (p.x.round() as i32, p.y.round() as i32);
        let j = *self.junction_at.get(&key)?;
        ((p - self.junctions[j].at).length() <= JUNCTION_REACH).then_some(j)
    }

    /// The ground of the sector of junction `j` that lies counter-clockwise of its ray `r`, at p.
    pub fn sector_height(&self, j: usize, r: usize, p: Vec2) -> f32 {
        let jn = &self.junctions[j];
        let n = jn.rays.len();
        let (r0, r1) = (jn.rays[r], jn.rays[(r + 1) % n]);
        // Which side of each bounding ray the sector is on, from a point inside it near the corner.
        let mid = {
            let (u0, u1) = (jn.dirs[r], jn.dirs[(r + 1) % n]);
            let mut span = u1.y.atan2(u1.x) - u0.y.atan2(u0.x);
            if span <= 0.0 {
                span += std::f32::consts::TAU;
            }
            let a = u0.y.atan2(u0.x) + span * 0.5;
            jn.at + Vec2::new(a.cos(), a.sin()) * 0.15
        };
        let side = |i: usize| self.steps[i].line_sd(mid) >= 0.0;
        // The ground of the bounding step nearer to p: next to a wall its side (a pond's held rim
        // included), next to a soft step its blend, which the sector across it shares; so the
        // sectors meet the cells round the junction, which take the nearest step too.
        let (d0, d1) = (self.steps[r0].signed(p).0, self.steps[r1].signed(p).0);
        // Round r10: blended by distance instead of taking the nearer step outright. Where the two
        // bounding steps give different grounds (a wall's top beside a pond's soft shore), the pick
        // jumped along the sector's bisector, and the lawn lip at the corner showed a small angled
        // step. On each ray the ground is still exactly that step's; at the corner a wall's.
        if d0 + d1 < 1e-4 {
            let pick = if self.steps[r0].wall() { r0 } else { r1 };
            return self.side_height(pick, p, side(pick));
        }
        // The blend fades back to the nearer step's ground by 0.3 m from the corner, so the samples
        // at the edge of the cut zone still meet the uncut cells round it.
        let (h0, h1) = (self.side_height(r0, p, side(r0)), self.side_height(r1, p, side(r1)));
        let picked = if d0 < d1 { h0 } else { h1 };
        let w0 = d1 * d1 / (d0 * d0 + d1 * d1);
        let blend = 1.0 - smoothstep(0.12, 0.3, (p - jn.at).length());
        picked + (h0 * w0 + h1 * (1.0 - w0) - picked) * blend
    }

    /// The nearest wall piece within `reach`.
    pub fn nearest_wall(&self, p: Vec2, reach: f32) -> Option<usize> {
        let list = self.buckets.get(&(p.x.floor() as i32, p.y.floor() as i32))?;
        let mut best: Option<(usize, f32)> = None;
        for &i in list {
            let s = &self.steps[i as usize];
            if !s.wall() {
                continue;
            }
            let (d, _) = s.signed(p);
            if d <= reach && best.map_or(true, |b| d < b.1) {
                best = Some((i as usize, d));
            }
        }
        best.map(|b| b.0)
    }

    /// The cell under p, or the nearest one round it.
    fn cell_near(&self, p: Vec2) -> Option<((i32, i32), Cell)> {
        let (x, z) = (p.x.floor() as i32, p.y.floor() as i32);
        if let Some(c) = self.cells.get(&(x, z)) {
            return Some(((x, z), *c));
        }
        let mut best: Option<((i32, i32), Cell, f32)> = None;
        for dz in -1..=1 {
            for dx in -1..=1 {
                if let Some(c) = self.cells.get(&(x + dx, z + dz)) {
                    let lo = Vec2::new((x + dx) as f32, (z + dz) as f32);
                    let d = (p - p.clamp(lo, lo + Vec2::ONE)).length();
                    if best.map_or(true, |b| d < b.2) {
                        best = Some(((x + dx, z + dz), *c, d));
                    }
                }
            }
        }
        best.map(|b| (b.0, b.1))
    }

    /// The slope of the cell under p (zero when flat or off the cells).
    pub fn slope_at(&self, p: Vec2) -> Vec2 {
        self.cells.get(&(p.x.floor() as i32, p.y.floor() as i32)).map_or(Vec2::ZERO, |c| c.slope)
    }

    /// Whether two neighbouring cells meet without a step (round r9: within `CONTINUOUS` at both
    /// ends of the shared edge when a slope cell is involved and neither holds water).
    fn continuous(&self, ka: (i32, i32), a: &Cell, kb: (i32, i32), b: &Cell) -> bool {
        if !a.sloped() && !b.sloped() {
            return (a.h - b.h).abs() < 1e-4;
        }
        if a.water.is_some() || b.water.is_some() {
            return false;
        }
        let dx = kb.0 - ka.0;
        let (c0, c1) = if dx != 0 {
            let x = ka.0.max(kb.0) as f32;
            (Vec2::new(x, ka.1 as f32), Vec2::new(x, ka.1 as f32 + 1.0))
        } else {
            let z = ka.1.max(kb.1) as f32;
            (Vec2::new(ka.0 as f32, z), Vec2::new(ka.0 as f32 + 1.0, z))
        };
        (a.plane(ka, c0) - b.plane(kb, c0)).abs() <= CONTINUOUS && (a.plane(ka, c1) - b.plane(kb, c1)).abs() <= CONTINUOUS
    }

    /// The ground of cell `key` at p: its plane, rounded where it meets a continuous neighbour with
    /// another plane (the crease at a ramp's foot and top), over `CREASE` either side of the edge.
    /// Exactly the cell's height on an island without slopes.
    pub fn cell_ground(&self, key: (i32, i32), p: Vec2) -> f32 {
        let Some(cell) = self.cells.get(&key) else { return self.floor };
        if !self.has_slopes || !self.slope_near.contains(&key) {
            return cell.h;
        }
        // Round r10: a blend over the 2 x 2 cells round the corner of this cell nearest to p, with
        // smooth weights per axis that sum to one. A neighbour joins with its own plane where it is
        // continuous with this cell (the diagonal one through either edge neighbour); otherwise it
        // takes the bilinear stand-in, so a step is left to the step code. At a staircase corner of a
        // diagonal ramp the planes of all four cells meet in one smooth surface.
        let own = cell.plane(key, p);
        let centre = centre_of(key);
        let (sx, sz) = (if p.x >= centre.x { 1 } else { -1 }, if p.y >= centre.y { 1 } else { -1 });
        let wx = smoothstep(-CREASE, CREASE, (p.x - centre.x) * sx as f32 - 0.5);
        let wz = smoothstep(-CREASE, CREASE, (p.y - centre.y) * sz as f32 - 0.5);
        if wx <= 0.0 && wz <= 0.0 {
            return own;
        }
        let (kx, kz, kd) = ((key.0 + sx, key.1), (key.0, key.1 + sz), (key.0 + sx, key.1 + sz));
        let joined = |k: (i32, i32), with: (i32, i32), c: &Cell| -> Option<Cell> {
            let other = self.cells.get(&k)?;
            self.continuous(with, c, k, other).then_some(*other)
        };
        let cx = joined(kx, key, cell);
        let cz = joined(kz, key, cell);
        let vx = cx.map_or(own, |c| c.plane(kx, p));
        let vz = cz.map_or(own, |c| c.plane(kz, p));
        let cd = cx.and_then(|c| joined(kd, kx, &c)).or_else(|| cz.and_then(|c| joined(kd, kz, &c)));
        let vd = cd.map_or(vx + vz - own, |c| c.plane(kd, p));
        own * (1.0 - wx) * (1.0 - wz) + vx * wx * (1.0 - wz) + vz * (1.0 - wx) * wz + vd * wx * wz
    }

    /// How much of a fall's notch p is in (1 inside, 0 outside, soft at its sides).
    pub fn notch(&self, p: Vec2) -> f32 {
        let mut k: f32 = 0.0;
        for s in &self.spills {
            let d = p - s.centre;
            let (u, o) = (d.dot(s.along).abs(), d.dot(s.out));
            if o > -1.0 && o < 0.8 {
                k = k.max(1.0 - smoothstep(s.width * 0.5 - 0.05, s.width * 0.5 + 0.12, u));
            }
        }
        k
    }

    /// A pond's rim where it is held: a narrow flat bank above its surface `RIM_UP`, falling to
    /// `base` over 0.18 to 0.40 m inward; in a notch a sill just under the surface.
    fn rim(&self, p: Vec2, level: f32, inward: f32, base: f32) -> f32 {
        let top = level - crate::water::SINK + RIM_UP + (SILL - RIM_UP) * self.notch(p);
        let k = 1.0 - smoothstep(0.18, 0.40, inward.max(0.0));
        base.max(base + (top - base) * k)
    }

    /// The ground height on one side of step `i` at p.
    pub fn side_height(&self, i: usize, p: Vec2, high: bool) -> f32 {
        let s = &self.steps[i];
        let sd = s.line_sd(p);
        // Round r9: each side is its cell's ground (a plane on a slope cell), so a step's rise varies
        // along it; on flat cells these are the two levels as before.
        let sloped = self.step_sloped.get(i).copied().unwrap_or(false);
        let (mut hi, mut lo) = if sloped { (self.cell_ground(s.high_cell, p), self.cell_ground(s.low_cell, p)) } else { (s.high, s.low) };
        if !s.wall() {
            // Round r10: a soft step beside a slope is as wide as its rise needs to stay a lawn bank
            // (at most about 45 degrees), not a steep facet painted as bare rock.
            let half = if sloped { SOFT_HALF.max((hi - lo).abs() * 0.55) } else { SOFT_HALF };
            return lo + (hi - lo) * smoothstep(-half, half, sd);
        }
        // Round r10: toward a free end (a cheek's tip) both sides close on their middle, so the
        // rise runs out to nothing at the tip whatever the cells' mismatch there; beyond the tip the
        // ground passes back to the cell's own over 0.9 m.
        if sloped {
            let tip = s.tip_distance(p);
            if tip < TIP_FADE {
                let k = smoothstep(0.0, TIP_FADE, tip);
                let mid = (hi + lo) * 0.5;
                if tip <= 0.0 {
                    let own = self.cell_near(p).map_or(mid, |(key, _)| self.cell_ground(key, p));
                    return mid + (own - mid) * smoothstep(0.0, 0.9, -tip);
                }
                hi = mid + (hi - mid) * k;
                lo = mid + (lo - mid) * k;
            }
        }
        if !high {
            return lo;
        }
        match s.high_water {
            Some(level) if s.pond_wall() => self.rim(p, level, sd, hi),
            _ => hi,
        }
    }

    /// The exact ground height at p (the grid holds it at its samples).
    pub fn surface(&self, p: Vec2) -> f32 {
        let mut h = match self.nearest_step(p) {
            Some((i, sd, _)) => self.side_height(i, p, sd >= 0.0),
            None => self.cell_near(p).map_or(self.floor, |(k, c)| if self.has_slopes && self.slope_near.contains(&k) { self.cell_ground(k, p) } else { c.h }),
        };
        // A pond at the outline is held by a bank too.
        if let Some(level) = self.cell_near(p).and_then(|(_, c)| c.water) {
            let land = self.sample(&self.land1, p);
            if land < 0.97 {
                h = self.rim(p, level, (land - 0.5) / 0.89, h);
            }
        }
        h
    }

    /// The ground normal at p, taken on p's own side of a nearby wall.
    pub fn ground_normal(&self, p: Vec2) -> Vec3 {
        // Round r8 (the owner's "hollow joint"): within a metre of a wall the grid's central
        // difference reads samples across the wall, so the lawn at a wall's foot was tilted toward
        // the wall and lit as a slope facing away from the sun: a dark band wherever no grass
        // covered it (props keep the grass clear). Take exact heights on each side, and per axis
        // the one-sided difference that does not jump.
        if !self.near_wall_at(p) && self.nearest_wall(p, 1.0).is_some() {
            let e = 0.12;
            let c = self.surface(p);
            let axis = |d: Vec2| {
                let (a, b) = (self.surface(p + d * e) - c, c - self.surface(p - d * e));
                if a.abs() < 0.3 && b.abs() < 0.3 {
                    (a + b) / (2.0 * e)
                } else if a.abs() < b.abs() {
                    a / e
                } else {
                    b / e
                }
            };
            let g = Vec2::new(axis(Vec2::X), axis(Vec2::Y));
            return Vec3::new(-g.x, 1.0, -g.y).normalize();
        }
        let g = if self.near_wall_at(p) {
            match self.nearest_wall(p, 0.6) {
                Some(i) => {
                    let high = self.steps[i].line_sd(p) >= 0.0;
                    let e = 0.12;
                    Vec2::new(
                        self.side_height(i, p + Vec2::X * e, high) - self.side_height(i, p - Vec2::X * e, high),
                        self.side_height(i, p + Vec2::Y * e, high) - self.side_height(i, p - Vec2::Y * e, high),
                    ) / (2.0 * e)
                }
                None => self.gradient(&self.height, p, STEP),
            }
        } else {
            self.gradient(&self.height, p, STEP)
        };
        Vec3::new(-g.x, 1.0, -g.y).normalize()
    }

    fn near_wall_at(&self, p: Vec2) -> bool {
        let g = (p - self.origin) / STEP;
        let (i, j) = (g.x.floor().clamp(0.0, self.nx as f32 - 2.0) as usize, g.y.floor().clamp(0.0, self.nz as f32 - 2.0) as usize);
        self.near_wall[j * self.nx + i] || self.near_wall[j * self.nx + i + 1] || self.near_wall[(j + 1) * self.nx + i] || self.near_wall[(j + 1) * self.nx + i + 1]
    }

    /// Puts a fall found on the cells onto the relaxed wall or the outline.
    fn place_spill(&self, mut s: crate::water::Spill) -> crate::water::Spill {
        if s.outer {
            for _ in 0..4 {
                let g = self.gradient(&self.land1, s.centre, STEP);
                let len2 = g.length_squared();
                if len2 > 1e-6 {
                    s.centre -= g * ((self.sample(&self.land1, s.centre) - 0.5) / len2).clamp(-0.6, 0.6);
                }
            }
            let out = (-self.gradient(&self.land1, s.centre, STEP * 2.0)).normalize_or_zero();
            if out != Vec2::ZERO {
                s.out = out;
            }
        } else {
            for _ in 0..4 {
                let Some(list) = self.buckets.get(&(s.centre.x.floor() as i32, s.centre.y.floor() as i32)) else { break };
                let best = list
                    .iter()
                    .map(|&i| &self.steps[i as usize])
                    .filter(|st| st.pond_wall() && st.high_water.is_some_and(|l| (l - s.level).abs() < 1e-3))
                    .map(|st| (st, st.signed(s.centre).0))
                    .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
                let Some((st, _)) = best else { break };
                let (q, t) = st.closest(s.centre);
                s.centre = q;
                s.out = st.normal_at(t);
            }
        }
        s.along = Vec2::new(-s.out.y, s.out.x);
        s
    }

    pub fn point(&self, i: usize, j: usize) -> Vec2 {
        self.origin + Vec2::new(i as f32, j as f32) * STEP
    }

    /// Bilinear sample of one of the grids at a world position.
    pub fn sample(&self, grid: &[f32], p: Vec2) -> f32 {
        let g = (p - self.origin) / STEP;
        let (gx, gz) = (g.x.clamp(0.0, self.nx as f32 - 1.001), g.y.clamp(0.0, self.nz as f32 - 1.001));
        let (i, j) = (gx.floor() as usize, gz.floor() as usize);
        let (fx, fz) = (gx - i as f32, gz - j as f32);
        let at = |i: usize, j: usize| grid[j * self.nx + i];
        let a = at(i, j) + (at(i + 1, j) - at(i, j)) * fx;
        let b = at(i, j + 1) + (at(i + 1, j + 1) - at(i, j + 1)) * fx;
        a + (b - a) * fz
    }

    pub fn gradient(&self, grid: &[f32], p: Vec2, reach: f32) -> Vec2 {
        Vec2::new(
            self.sample(grid, p + Vec2::X * reach) - self.sample(grid, p - Vec2::X * reach),
            self.sample(grid, p + Vec2::Y * reach) - self.sample(grid, p - Vec2::Y * reach),
        ) / (2.0 * reach)
    }

    pub fn height_at(&self, p: Vec2) -> f32 {
        if self.near_wall_at(p) {
            return self.surface(p);
        }
        self.sample(&self.height, p)
    }

    pub fn inside(&self, p: Vec2) -> bool {
        self.sample(&self.land1, p) >= 0.5
    }

    /// Water level of the cell under `p`, if any (nearest sample, no blending).
    pub fn water_at(&self, p: Vec2) -> Option<f32> {
        let g = (p - self.origin) / STEP;
        let (i, j) = ((g.x.round() as usize).min(self.nx - 1), (g.y.round() as usize).min(self.nz - 1));
        let level = self.water[j * self.nx + i];
        if level.is_nan() {
            None
        } else {
            Some(level)
        }
    }

    /// Unit direction pointing into the island at `p`, from the mid-scale field.
    pub fn inward(&self, p: Vec2) -> Vec2 {
        self.gradient(&self.land2, p, 0.75).normalize_or_zero()
    }
}

/// How much of the sky a ground point sees, from the height field alone.
fn ground_sky(field: &Field, p: Vec2, h: f32) -> f32 {
    let mut blocked = 0.0;
    for k in 0..8 {
        let angle = k as f32 * std::f32::consts::FRAC_PI_4;
        let dir = Vec2::new(angle.cos(), angle.sin());
        let mut worst: f32 = 0.0;
        for dist in [0.5_f32, 1.0, 1.8, 3.0] {
            let q = p + dir * dist;
            if field.sample(&field.land1, q) < 0.35 {
                continue;
            }
            worst = worst.max((field.height_at(q) - h) / dist);
        }
        blocked += (worst - 0.08).clamp(0.0, 1.2);
    }
    1.0 - (blocked / 8.0 * 0.9).clamp(0.0, 0.6)
}

pub struct Top {
    pub mesh: Mesh,
    /// Boundary segments of the top surface, for the lip.
    pub rim: Vec<(Vec3, Vec3)>,
    /// The upper edges of the terrace walls (island coordinates) with the direction over the edge.
    pub brows: Vec<(Vec3, Vec3, Vec2)>,
}

/// A triangle whose winding is turned to face along its shading normals.
pub(crate) fn tri_facing(mesh: &mut Mesh, p: [Vec3; 3], n: [Vec3; 3], c: [Vec3; 3], paint: [Paint; 3]) {
    let face = (p[1] - p[0]).cross(p[2] - p[0]);
    if face.dot(n[0] + n[1] + n[2]) < 0.0 {
        mesh.tri_full([p[0], p[2], p[1]], [n[0], n[2], n[1]], [c[0], c[2], c[1]], [paint[0], paint[2], paint[1]]);
    } else {
        mesh.tri_full(p, n, c, paint);
    }
}

/// Splits a convex polygon by the sign of `value` at its corners (linear between them):
/// the part where it is >= 0, the part where it is < 0, and the crossing points.
fn split_polygon(polygon: &[Vec2], value: &[f32]) -> (Vec<Vec2>, Vec<Vec2>, Vec<Vec2>) {
    let (mut pos, mut neg, mut cross) = (Vec::new(), Vec::new(), Vec::new());
    let n = polygon.len();
    for k in 0..n {
        let (a, b) = (polygon[k], polygon[(k + 1) % n]);
        let (va, vb) = (value[k], value[(k + 1) % n]);
        if va >= 0.0 {
            pos.push(a);
        } else {
            neg.push(a);
        }
        if (va >= 0.0) != (vb >= 0.0) {
            let c = a.lerp(b, va / (va - vb));
            pos.push(c);
            neg.push(c);
            cross.push(c);
        }
    }
    (pos, neg, cross)
}

/// Colours of the top surface. Kept together so the look study can swap them.
#[derive(Clone, Copy)]
pub struct TopColours {
    pub lawn: Vec3,
    pub lawn_cool: Vec3,
    pub riser: Vec3,
    pub bed: Vec3,
    pub bank: Vec3,
}

impl Default for TopColours {
    fn default() -> TopColours {
        // The ground under the grass field: close to the blades' mid colour.
        TopColours {
            lawn: Vec3::new(0.450, 0.535, 0.280),
            lawn_cool: Vec3::new(0.42, 0.53, 0.267),
            // Round r8: lifted a little against the island stone's darker shade, to hold the reference tone.
            riser: Vec3::new(0.676, 0.640, 0.585),
            // Round r8: a pale sandy stone bed; the water pass tints and darkens it with depth.
            bed: Vec3::new(0.60, 0.57, 0.47),
            bank: Vec3::new(0.74, 0.71, 0.58),
        }
    }
}

/// The top surface: one smooth height field clipped at the outline.
pub fn build_top(field: &Field, colours: &TopColours, seed: u32) -> Top {
    let mut mesh = Mesh::default();
    let mut rim = Vec::new();
    let mut brows = Vec::new();
    // A top vertex; `side` forces the height (and its slope) onto one side of a wall, or (round r9)
    // onto one sector of a junction.
    let surface = |p: Vec2, side: Option<Side>| -> (Vec3, Vec3, Vec3, Paint) {
        let (h, g) = match side {
            Some(side) => {
                let e = 0.12;
                let g = Vec2::new(side.height(field, p + Vec2::X * e) - side.height(field, p - Vec2::X * e), side.height(field, p + Vec2::Y * e) - side.height(field, p - Vec2::Y * e)) / (2.0 * e);
                (side.height(field, p), g)
            }
            None => {
                let n = field.ground_normal(p);
                (field.height_at(p), Vec2::new(-n.x / n.y, -n.z / n.y))
            }
        };
        // The meadow's broad cushions tilt the light a little (ground.gdshader: pillow gradient
        // 0.14 plus the cover slope 0.10).
        let pillow = crate::grass::pillow_grad(p) * 0.20;
        let normal = Vec3::new(-g.x - pillow.x, 1.0, -g.y - pillow.y).normalize();
        let slope = g.length();
        // Steps are cut as whole facets where the triangles are emitted; vertices stay lawn.
        let stone = 0.0 * slope;
        // The ground under the rosettes: ground_cover's soft patches round the authored colour;
        // the rosettes take their colour from it (grass_blades.gdshader).
        let lawn = crate::grass::lawn_ground(colours.lawn, p);
        let mut colour = lawn.lerp(colours.riser, stone);
        let mut family = if stone > 0.5 { Family::Stone } else { Family::Ground };
        let wet = field.sample(&field.wet, p);
        if wet > 0.02 {
            // The nearest water level, looked for a little further in when p is on the bank.
            let toward = field.gradient(&field.wet, p, STEP).normalize_or_zero();
            // Round r8: a level found by looking toward the water must belong to this ground: the
            // lower lawn at the foot of a pond's wall found the upper pond's level, counted itself
            // 2 m under water and was painted in the bed's dark colour (the owner's hollow joint).
            let level = field.water_at(p).or_else(|| [0.6_f32, 1.2].iter().filter_map(|d| field.water_at(p + toward * *d)).find(|l| h > l - crate::water::SINK - 0.3));
            if let Some(level) = level {
                let surface = level - crate::water::SINK;
                // A narrow pale bank at the waterline, the bed below it; the lawn runs right up to the bank.
                let bank = 1.0 - smoothstep(0.03, 0.22, (h - surface).abs());
                colour = colour.lerp(colours.bank, bank * 0.8);
                if h < surface - 0.04 {
                    colour = colours.bank.lerp(colours.bed, smoothstep(0.0, 0.32, surface - h));
                    family = Family::Stone;
                }
            }
        }
        let sky = ground_sky(field, p, h);
        let line = if stone > 0.5 { 0.8 } else { 0.25 };
        (Vec3::new(p.x, h, p.y), normal, colour, Paint::new(family).sky(sky).line(line).strokes(if stone > 0.5 { 0.6 } else { 0.25 }).id(1))
    };
    // Every grid sample inside the outline is a corner of up to four cells: made once.
    let cache: Vec<Option<TopVertex>> = (0..field.nx * field.nz).map(|s| if field.land1[s] >= 0.5 { Some(surface(field.point(s % field.nx, s / field.nx), None)) } else { None }).collect();
    for j in 0..field.nz - 1 {
        for i in 0..field.nx - 1 {
            let corners = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)];
            let vertex = |p: Vec2, side: Option<Side>| -> TopVertex {
                for c in corners {
                    if field.point(c.0, c.1) == p {
                        if let Some(v) = cache[c.1 * field.nx + c.0] {
                            return v;
                        }
                    }
                }
                surface(p, side)
            };
            let value = |c: (usize, usize)| field.land1[c.1 * field.nx + c.0] - 0.5;
            let values = corners.map(value);
            if values.iter().all(|v| *v < 0.0) {
                continue;
            }
            let mut polygon: Vec<Vec2> = Vec::with_capacity(6);
            let mut crossings: Vec<Vec2> = Vec::with_capacity(2);
            for k in 0..4 {
                let (a, b) = (corners[k], corners[(k + 1) % 4]);
                let (va, vb) = (values[k], values[(k + 1) % 4]);
                let (pa, pb) = (field.point(a.0, a.1), field.point(b.0, b.1));
                if va >= 0.0 {
                    polygon.push(pa);
                }
                if (va >= 0.0) != (vb >= 0.0) {
                    let cross = pa.lerp(pb, va / (va - vb));
                    polygon.push(cross);
                    crossings.push(cross);
                }
            }
            if polygon.len() < 3 {
                continue;
            }
            let centre = field.point(i, j) + Vec2::splat(STEP * 0.5);
            // Round r9 (F1): near a corner where three or more steps meet with a wall among them, the
            // grid cell is cut into the junction's sectors, each at its own ground, and every wall
            // ray gets its ribbon up to the corner itself.
            if let Some(ji) = field.junction_near(centre) {
                let jn = &field.junctions[ji];
                let n = jn.dirs.len();
                for r in 0..n {
                    let (u0, u1) = (jn.dirs[r], jn.dirs[(r + 1) % n]);
                    let mut span = u1.y.atan2(u1.x) - u0.y.atan2(u0.x);
                    if span <= 0.0 {
                        span += std::f32::consts::TAU;
                    }
                    // Wedges wider than a half turn are cut in two along their bisector (convex parts).
                    let a0 = u0.y.atan2(u0.x);
                    let bounds: Vec<(Vec2, Vec2)> = if span > std::f32::consts::PI {
                        let b = Vec2::new((a0 + span * 0.5).cos(), (a0 + span * 0.5).sin());
                        vec![(u0, b), (b, u1)]
                    } else {
                        vec![(u0, u1)]
                    };
                    for (from, to) in bounds {
                        let cross2 = |u: Vec2, q: Vec2| u.x * q.y - u.y * q.x;
                        let left = clip_line(&polygon, &|q: Vec2| cross2(from, q - jn.at));
                        let part = clip_line(&left, &|q: Vec2| -cross2(to, q - jn.at));
                        if part.len() < 3 {
                            continue;
                        }
                        let side = Side::Sector(ji, r);
                        // A grid corner keeps its shared vertex only where that is this sector's
                        // ground; near the corner it may belong to another sector.
                        let fan: Vec<TopVertex> = part
                            .iter()
                            .map(|p| {
                                let own = surface(*p, Some(side));
                                let shared = vertex(*p, Some(side));
                                if (shared.0.y - own.0.y).abs() < 0.05 { shared } else { own }
                            })
                            .collect();
                        emit_fan(&mut mesh, field, colours, &fan, centre, seed);
                    }
                }
                // Each wall ray's piece within this grid cell, from the corner outward.
                for r in 0..n {
                    let si = jn.rays[r];
                    if !field.steps[si].wall() {
                        continue;
                    }
                    let u = jn.dirs[r];
                    let Some((t0, t1)) = clip_segment(&polygon, jn.at, u, 1.0) else { continue };
                    if t1 - t0 < 1e-4 {
                        continue;
                    }
                    // The sectors on the ray's two sides: counter-clockwise of it is sector r, clockwise sector r - 1.
                    let (ccw, cw) = (Side::Sector(ji, r), Side::Sector(ji, (r + n - 1) % n));
                    let probe = jn.at + u * 0.2 + Vec2::new(-u.y, u.x) * 0.05;
                    let ccw_high = field.steps[si].line_sd(probe) >= 0.0;
                    let (high, low) = if ccw_high { (ccw, cw) } else { (cw, ccw) };
                    ribbon(&mut mesh, &mut brows, field, colours, si, jn.at + u * t0, jn.at + u * t1, high, low, (t0 < 1e-4, false), &surface, seed);
                }
                if crossings.len() == 2 {
                    let (a, b) = (crossings[0], crossings[1]);
                    rim.push((Vec3::new(a.x, field.height_at(a), a.y), Vec3::new(b.x, field.height_at(b), b.y)));
                }
                continue;
            }
            // A terrace wall through this grid cell: cut the cell along its relaxed contour, each part
            // at its own level, and fill the cut with a ribbon of rock.
            if let Some(wi) = field.nearest_wall(centre, STEP * 1.2) {
                let step = field.steps[wi];
                // Signed distance to the nearest wall at each corner, so neighbouring grid cells cut a
                // shared edge at the same point (no seams between their pieces of the ribbon).
                let values: Vec<f32> = polygon.iter().map(|p| field.nearest_wall(*p, 1.0).map_or_else(|| step.line_sd(*p), |k| field.steps[k].signed(*p).1)).collect();
                if values.iter().any(|v| *v >= 0.0) && values.iter().any(|v| *v < 0.0) {
                    let (upper, lower, cross) = split_polygon(&polygon, &values);
                    for (part, high) in [(&upper, true), (&lower, false)] {
                        if part.len() < 3 {
                            continue;
                        }
                        // Grid corners as everywhere else (so cut and uncut cells meet); the cut's own
                        // points on the side they belong to.
                        let fan: Vec<(Vec3, Vec3, Vec3, Paint)> = part.iter().map(|p| vertex(*p, Some(Side::Step(wi, high)))).collect();
                        emit_fan(&mut mesh, field, colours, &fan, centre, seed);
                    }
                    if cross.len() == 2 {
                        ribbon(&mut mesh, &mut brows, field, colours, wi, cross[0], cross[1], Side::Step(wi, true), Side::Step(wi, false), (false, false), &surface, seed);
                    }
                    if crossings.len() == 2 {
                        let (a, b) = (crossings[0], crossings[1]);
                        rim.push((Vec3::new(a.x, field.height_at(a), a.y), Vec3::new(b.x, field.height_at(b), b.y)));
                    }
                    continue;
                }
            }
            let fan: Vec<(Vec3, Vec3, Vec3, Paint)> = polygon.iter().map(|p| vertex(*p, None)).collect();
            emit_fan(&mut mesh, field, colours, &fan, centre, seed);
            if crossings.len() == 2 {
                let (a, b) = (crossings[0], crossings[1]);
                rim.push((Vec3::new(a.x, field.height_at(a), a.y), Vec3::new(b.x, field.height_at(b), b.y)));
            }
        }
    }
    // The lip (round r4): the lawn rolls over the outline by a small radius in its own colour, its
    // light kept close to the lawn's (normals mostly up), and under the roll a short band of rock
    // tucks in under the lawn, where the stone's mossy brow begins.
    // Outward direction per end point, so neighbouring pieces share normals and the lip reads as one roll.
    let outward = |p: Vec3| -> Vec3 {
        let inward = field.gradient(&field.land1, Vec2::new(p.x, p.z), STEP * 1.5).normalize_or_zero();
        Vec3::new(-inward.x, 0.0, -inward.y)
    };
    let _ = seed;
    for &(a, b) in &rim {
        let (out_a, out_b) = (outward(a), outward(b));
        let (lawn_a, lawn_b) = (crate::grass::lawn_ground(colours.lawn, Vec2::new(a.x, a.z)), crate::grass::lawn_ground(colours.lawn, Vec2::new(b.x, b.z)));
        // (out, down) in metres; the first three spans are lawn, then rock straight down, so the
        // wall reads as reaching up to the roll.
        let rings = [(0.0, 0.0), (0.040, 0.020), (0.060, 0.065), (0.055, 0.115), (0.050, 0.22), (0.045, 0.32)];
        for k in 0..rings.len() - 1 {
            let (o0, d0) = rings[k];
            let (o1, d1) = rings[k + 1];
            let geometric = |out3: Vec3| (out3 * (d1 - d0) + Vec3::Y * (o1 - o0)).normalize_or_zero();
            let quad = [a + out_a * o0 - Vec3::Y * d0, b + out_b * o0 - Vec3::Y * d0, b + out_b * o1 - Vec3::Y * d1, a + out_a * o1 - Vec3::Y * d1];
            if k < 3 {
                let normal = |out3: Vec3| (Vec3::Y * 0.70 + geometric(out3) * 0.30).normalize();
                let paint = Paint::new(Family::Ground).sky(1.0 - 0.05 * k as f32).line(0.35).id(1);
                let (na, nb) = (normal(out_a), normal(out_b));
                mesh.tri_full([quad[0], quad[1], quad[2]], [na, nb, nb], [lawn_a, lawn_b, lawn_b], [paint; 3]);
                mesh.tri_full([quad[0], quad[2], quad[3]], [na, nb, na], [lawn_a, lawn_b, lawn_a], [paint; 3]);
            } else {
                let lip = a.y.max(b.y);
                // grad 0 marks this band for the terms pass (full mossy brow); its baked occlusion
                // reads it as the shaded top of the wall under the roll (round r5).
                let paint = Paint::new(Family::Stone).sky(0.62).line(0.9).strokes(0.8).id(2).grad(0.0).lip(lip);
                let tone = colours.riser;
                let (na, nb) = (geometric(out_a), geometric(out_b));
                mesh.tri_full([quad[0], quad[1], quad[2]], [na, nb, nb], [tone; 3], [paint; 3]);
                mesh.tri_full([quad[0], quad[2], quad[3]], [na, nb, na], [tone; 3], [paint; 3]);
            }
        }
    }
    Top { mesh, rim, brows }
}

/// Which ground a cut vertex takes: one side of a step, or (round r9) one sector of a junction.
#[derive(Clone, Copy)]
enum Side {
    Step(usize, bool),
    Sector(usize, usize),
}

impl Side {
    fn height(&self, field: &Field, p: Vec2) -> f32 {
        match *self {
            Side::Step(i, high) => field.side_height(i, p, high),
            Side::Sector(j, r) => field.sector_height(j, r, p),
        }
    }
}

/// Sutherland-Hodgman clip of a convex polygon to where `value` >= 0 (linear along its edges).
fn clip_line(polygon: &[Vec2], value: &dyn Fn(Vec2) -> f32) -> Vec<Vec2> {
    let n = polygon.len();
    let mut out = Vec::with_capacity(n + 2);
    for k in 0..n {
        let (a, b) = (polygon[k], polygon[(k + 1) % n]);
        let (va, vb) = (value(a), value(b));
        if va >= 0.0 {
            out.push(a);
        }
        if (va >= 0.0) != (vb >= 0.0) {
            out.push(a.lerp(b, va / (va - vb)));
        }
    }
    out
}

/// The part of the segment from `at` along `u` (0 to `reach`) inside a convex polygon, as (t0, t1).
fn clip_segment(polygon: &[Vec2], at: Vec2, u: Vec2, reach: f32) -> Option<(f32, f32)> {
    let n = polygon.len();
    // Orientation of the polygon, so "inside" is the same side of every edge.
    let mut area = 0.0;
    for k in 0..n {
        let (a, b) = (polygon[k], polygon[(k + 1) % n]);
        area += a.x * b.y - b.x * a.y;
    }
    let (mut t0, mut t1) = (0.0_f32, reach);
    for k in 0..n {
        let (a, b) = (polygon[k], polygon[(k + 1) % n]);
        let e = b - a;
        // Inside: cross(e, p - a) has the sign of the area.
        let inside = |p: Vec2| (e.x * (p.y - a.y) - e.y * (p.x - a.x)) * area.signum();
        let (v0, v1) = (inside(at + u * t0), inside(at + u * t1));
        if v0 < 0.0 && v1 < 0.0 {
            return None;
        }
        if v0 < 0.0 || v1 < 0.0 {
            let t = t0 + (t1 - t0) * v0 / (v0 - v1);
            if v0 < 0.0 {
                t0 = t;
            } else {
                t1 = t;
            }
        }
    }
    (t1 > t0).then_some((t0, t1))
}

type TopVertex = (Vec3, Vec3, Vec3, Paint);

/// One piece of the top surface. A piece that is steep (a soft step too steep for lawn) or that
/// bridges two levels (where walls meet and the cut cannot follow both) is cut rock, facing the
/// nearest step's low side.
fn emit_fan(mesh: &mut Mesh, field: &Field, colours: &TopColours, fan: &[TopVertex], centre: Vec2, seed: u32) {
    let (lo, hi) = fan.iter().fold((f32::MAX, f32::MIN), |(a, b), v| (a.min(v.0.y), b.max(v.0.y)));
    let cell_normal = field.ground_normal(centre);
    let bridge = hi - lo > 0.45 && field.nearest_wall(centre, 0.6).is_some();
    // The piece's own tilt (Newell's normal of the fan): a piece that lies flat is lawn even where the
    // field's gradient is steep (beside a fall's sill), so it is not lit as a slope facing away (r7).
    let mut own = Vec3::ZERO;
    for k in 0..fan.len() {
        let (a, b) = (fan[k].0, fan[(k + 1) % fan.len()].0);
        own += Vec3::new((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y));
    }
    let flat = own.normalize_or_zero().y.abs() > 0.85;
    if (cell_normal.y < 0.60 && !flat) || bridge {
        let tone = 0.94 + 0.10 * hash2((centre.x * 1.3).floor() as i32, (centre.y * 1.3).floor() as i32, seed ^ 33);
        let face = if bridge {
            field.nearest_step(centre).map(|(i, _, _)| field.steps[i].normal_near(centre)).map_or(cell_normal, |n| Vec3::new(n.x, 0.0, n.y))
        } else {
            cell_normal
        };
        let lip = if bridge { hi } else {
            let up = Vec2::new(-cell_normal.x, -cell_normal.z).normalize_or_zero();
            field.height_at(centre + up * 0.8).max(field.height_at(centre + up * 0.4))
        };
        let paint = Paint::new(Family::Stone).sky(0.86).line(0.9).strokes(0.8).id(2).lip(lip);
        // Under a pond the cut rock takes the bed's colour per vertex, so the waterline follows the
        // smooth surface instead of the cells' outline.
        let rock = |c: &TopVertex| {
            let under = field.water_at(Vec2::new(c.0.x, c.0.z)).is_some_and(|level| c.0.y < level - crate::water::SINK - 0.02);
            if under && c.3.family == Family::Stone && !bridge { c.2 } else { colours.riser * tone }
        };
        for k in 1..fan.len() - 1 {
            let p = [fan[0].0, fan[k].0, fan[k + 1].0];
            // A bridge piece faces the way it actually tilts, upward (round r7): the nearest step's
            // horizontal normal could point away from the piece's open side and paint it dark.
            let n = if bridge {
                let g = (p[1] - p[0]).cross(p[2] - p[0]).normalize_or_zero();
                let g = if g.y < 0.0 { -g } else { g };
                if g == Vec3::ZERO { face } else { (g + face * 0.25).normalize() }
            } else {
                face
            };
            tri_facing(mesh, p, [n; 3], [rock(&fan[0]), rock(&fan[k]), rock(&fan[k + 1])], [paint; 3]);
        }
    } else {
        for k in 1..fan.len() - 1 {
            mesh.tri_full([fan[0].0, fan[k].0, fan[k + 1].0], [fan[0].1, fan[k].1, fan[k + 1].1], [fan[0].2, fan[k].2, fan[k + 1].2], [fan[0].3, fan[k].3, fan[k + 1].3]);
        }
    }
}

/// The face of a terrace wall across one grid cell, from c0 to c1 on its relaxed contour: a short
/// roll of the upper lawn over the edge (3.5 cm out, up to 5 cm down), then cut rock straight down
/// to the lower ground, in the bed's colour under a pond's surface. Round r9: the two grounds are
/// given (`high`, `low`: a step's sides or a junction's sectors), so the rise may vary along the
/// piece and run out (a ramp's cheek is a wedge of wall); where the sides swap over within a piece
/// it is split at the crossing and each part faces its own lower side. `mitre` marks an end at a
/// junction's corner: there the face runs exactly to the corner (no overlap, no roll) and shares
/// the corner's vertical edge with the other walls of the junction.
#[allow(clippy::too_many_arguments)]
fn ribbon(
    mesh: &mut Mesh,
    brows: &mut Vec<(Vec3, Vec3, Vec2)>,
    field: &Field,
    colours: &TopColours,
    wi: usize,
    c0: Vec2,
    c1: Vec2,
    high: Side,
    low: Side,
    mitre: (bool, bool),
    surface: &dyn Fn(Vec2, Option<Side>) -> TopVertex,
    seed: u32,
) {
    let step = field.steps[wi];
    if (c1 - c0).length() < 1e-4 {
        return;
    }
    let rise = |c: Vec2| high.height(field, c) - low.height(field, c);
    let (r0, r1) = (rise(c0), rise(c1));
    if (r0 < 0.0) != (r1 < 0.0) {
        let t = r0 / (r0 - r1);
        if t > 0.02 && t < 0.98 {
            let m = c0.lerp(c1, t);
            ribbon(mesh, brows, field, colours, wi, c0, m, high, low, (mitre.0, false), surface, seed);
            ribbon(mesh, brows, field, colours, wi, m, c1, high, low, (false, mitre.1), surface, seed);
            return;
        }
    }
    let flipped = r0 + r1 < 0.0;
    let (high, low) = if flipped { (low, high) } else { (high, low) };
    // Each piece reaches 2 cm past its ends so neighbouring pieces overlap instead of leaving slits;
    // not at a junction's corner, where the faces meet exactly.
    let dir = (c1 - c0).normalize();
    let (c0, c1) = (if mitre.0 { c0 } else { c0 - dir * 0.02 }, if mitre.1 { c1 } else { c1 + dir * 0.02 });
    let mid = (c0 + c1) * 0.5;
    let notch = step.pond_wall() && field.notch(mid) > 0.5;
    struct End {
        c: Vec2,
        n: Vec2,
        n3: Vec3,
        top: f32,
        low: f32,
        colour: Vec3,
        out: f32,
        down: f32,
    }
    let end = |c: Vec2, corner: bool| {
        let v = surface(c, Some(high));
        let n = if flipped { -step.normal_near(c) } else { step.normal_near(c) };
        let top = v.0.y;
        let low_y = low.height(field, c).min(top);
        // The face stands 3.5 cm out from the cut; the roll above it drops 5 cm, less on a low
        // wedge, none in a fall's notch or at a junction's corner.
        // Round r10: at a junction's corner the roll keeps its drop (only its reach out is zero, so
        // the walls still share the corner's edge): without it the rock rose to the lawn there and the
        // lip showed a small angled step where the roll ran out.
        let out = if corner { 0.0 } else { 0.035 };
        let down = if notch { 0.0 } else { 0.05_f32.min((top - low_y) * 0.5) };
        End { c, n, n3: Vec3::new(n.x, 0.0, n.y), top, low: low_y, colour: v.2, out, down }
    };
    let e = [end(c0, mitre.0), end(c1, mitre.1)];
    if e[0].top - e[0].low < 1e-3 && e[1].top - e[1].low < 1e-3 {
        return;
    }
    let at = |e: &End, out: f32, y: f32| Vec3::new(e.c.x + e.n.x * out, y, e.c.y + e.n.y * out);
    {
        let paint = Paint::new(Family::Ground).sky(1.0).line(0.35).id(1);
        let rn = [(Vec3::Y * 0.6 + e[0].n3 * 0.4).normalize(), (Vec3::Y * 0.6 + e[1].n3 * 0.4).normalize()];
        let q = [at(&e[0], 0.0, e[0].top), at(&e[1], 0.0, e[1].top), at(&e[1], e[1].out, e[1].top - e[1].down), at(&e[0], e[0].out, e[0].top - e[0].down)];
        tri_facing(mesh, [q[0], q[1], q[2]], [rn[0], rn[1], rn[1]], [e[0].colour, e[1].colour, e[1].colour], [paint; 3]);
        tri_facing(mesh, [q[0], q[2], q[3]], [rn[0], rn[1], rn[0]], [e[0].colour, e[1].colour, e[0].colour], [paint; 3]);
    }
    // Rows of the rock face; split at the lower side's water surface when it lies on the face.
    let below = if flipped { None } else { step.low_water.map(|level| level - crate::water::SINK) };
    // A wall faces straight out (the cells it replaced leaned back and took more sky), so its rock
    // is a little lighter to keep the terrace walls at the reference tone.
    let tone = (0.94 + 0.10 * hash2((mid.x * 1.3).floor() as i32, (mid.y * 1.3).floor() as i32, seed ^ 33)) * 1.04;
    let lip = e[0].top.max(e[1].top);
    let paint = Paint::new(Family::Stone).sky(0.86).line(0.9).strokes(0.8).id(2).lip(lip);
    let mut rows: Vec<f32> = vec![0.0];
    if let Some(surface_y) = below {
        let t = ((e[0].top - e[0].down - surface_y) / (e[0].top - e[0].down - e[0].low).max(1e-3)).clamp(0.0, 1.0);
        if t > 0.02 && t < 0.98 {
            rows.push(t);
        }
    }
    rows.push(1.0);
    let y_of = |e: &End, t: f32| (e.top - e.down) + (e.low - (e.top - e.down)) * t;
    for k in 0..rows.len() - 1 {
        let (t0, t1) = (rows[k], rows[k + 1]);
        let wet = below.is_some() && k > 0;
        let colour = if wet { colours.bed } else { colours.riser * tone };
        let q = [at(&e[0], e[0].out, y_of(&e[0], t0)), at(&e[1], e[1].out, y_of(&e[1], t0)), at(&e[1], e[1].out, y_of(&e[1], t1)), at(&e[0], e[0].out, y_of(&e[0], t1))];
        tri_facing(mesh, [q[0], q[1], q[2]], [e[0].n3, e[1].n3, e[1].n3], [colour; 3], [paint; 3]);
        tri_facing(mesh, [q[0], q[2], q[3]], [e[0].n3, e[1].n3, e[0].n3], [colour; 3], [paint; 3]);
    }
    // A backing face 5 cm behind the cut (8.5 cm behind the face), reaching 0.20 m past both ends
    // (not past a junction's corner) and 0.2 m under the lower level: where a wall ends against
    // another step, the pieces of ribbon could leave thin slits, and through them this rock shows
    // instead of the island's dark inside. Under the upper lawn everywhere else, so it is never seen whole.
    {
        let back = -0.05;
        let low = e[0].low.min(e[1].low) - 0.2;
        let mut corners: Vec<(Vec3, Vec3, Vec3)> = Vec::with_capacity(2);
        for (k, sign) in [(0usize, -1.0_f32), (1, 1.0)] {
            let mut reach: f32 = if (k == 0 && mitre.0) || (k == 1 && mitre.1) { 0.0 } else { 0.20 };
            let mut p = e[k].c + dir * sign * reach + e[k].n * back;
            // Round r10: nor past the end where the ground falls below the wall's foot (a pond's
            // bank or bed beside the corner), where the backing stood in the open as a sliver.
            while reach > 0.0 && (field.sample(&field.land1, p) < 0.6 || field.height_at(p) < e[k].low - 0.03) {
                reach -= 0.05;
                p = e[k].c + dir * sign * reach.max(0.0) + e[k].n * back;
            }
            let top = (e[k].top - 0.08).min(field.height_at(p) - 0.06).max(low + 0.05);
            corners.push((Vec3::new(p.x, top, p.y), Vec3::new(p.x, low, p.y), e[k].n3));
        }
        let colour = colours.riser * tone;
        let paint = Paint::new(Family::Stone).sky(0.86).line(0.9).strokes(0.8).id(3).lip(lip);
        let (a, b) = (corners[0], corners[1]);
        tri_facing(mesh, [a.0, b.0, b.1], [a.2, b.2, b.2], [colour; 3], [paint; 3]);
        tri_facing(mesh, [a.0, b.1, a.1], [a.2, b.2, a.2], [colour; 3], [paint; 3]);
    }
    if !notch && !step.pond_wall() {
        brows.push((Vec3::new(c0.x, e[0].top, c0.y), Vec3::new(c1.x, e[1].top, c1.y), (e[0].n + e[1].n).normalize_or_zero()));
    }
}

/// One closed outline of the island as world-anchored points, with the direction
/// pointing out of the island at each.
pub struct Outline {
    pub points: Vec<Vec2>,
    pub outward: Vec<Vec2>,
    pub is_hole: bool,
}

/// Outlines traced on the cell grid, smoothed, pulled onto the 0.5 contour of
/// the fine field, and sampled where they cross the lattice lines `spacing` apart.
pub fn outlines(cells: &Cells, field: &Field, spacing: f32) -> Vec<Outline> {
    // Directed unit edges with land on the left.
    let mut next: HashMap<(i32, i32), Vec<(i32, i32)>> = HashMap::new();
    for &(x, z) in cells.keys() {
        let mut edge = |from: (i32, i32), to: (i32, i32), neighbour: (i32, i32)| {
            if !cells.contains_key(&neighbour) {
                next.entry(from).or_default().push(to);
            }
        };
        edge((x, z), (x + 1, z), (x, z - 1));
        edge((x + 1, z), (x + 1, z + 1), (x + 1, z));
        edge((x + 1, z + 1), (x, z + 1), (x, z + 1));
        edge((x, z + 1), (x, z), (x - 1, z));
    }
    let mut starts: Vec<(i32, i32)> = next.keys().copied().collect();
    starts.sort();
    let mut result = Vec::new();
    for start in starts {
        while next.get(&start).map_or(false, |list| !list.is_empty()) {
            let mut loop_points = vec![start];
            let mut at = start;
            loop {
                let Some(list) = next.get_mut(&at) else { break };
                let Some(to) = list.pop() else { break };
                if to == start {
                    break;
                }
                loop_points.push(to);
                at = to;
            }
            if loop_points.len() < 4 {
                continue;
            }
            // Signed area: positive loops (in x, z) have land on the left as outer boundaries.
            let mut area = 0.0;
            for k in 0..loop_points.len() {
                let (a, b) = (loop_points[k], loop_points[(k + 1) % loop_points.len()]);
                area += (a.0 * b.1 - b.0 * a.1) as f32;
            }
            // Subdivide, relax, snap to the smooth contour, resample.
            let mut points: Vec<Vec2> = Vec::new();
            for k in 0..loop_points.len() {
                let a = Vec2::new(loop_points[k].0 as f32, loop_points[k].1 as f32);
                let b = Vec2::new(loop_points[(k + 1) % loop_points.len()].0 as f32, loop_points[(k + 1) % loop_points.len()].1 as f32);
                points.push(a);
                points.push((a + b) * 0.5);
            }
            for _ in 0..6 {
                let copy = points.clone();
                let n = copy.len();
                for k in 0..n {
                    points[k] = copy[k] * 0.5 + (copy[(k + n - 1) % n] + copy[(k + 1) % n]) * 0.25;
                }
            }
            for _ in 0..3 {
                for p in points.iter_mut() {
                    let g = field.gradient(&field.land1, *p, STEP);
                    let len2 = g.length_squared();
                    if len2 > 1e-6 {
                        *p -= g * ((field.sample(&field.land1, *p) - 0.5) / len2).clamp(-0.6, 0.6);
                    }
                }
            }
            // The crossings are taken on the relaxed and snapped polyline itself, which depends only on
            // nearby cells. (A dense arc-length resampling as an intermediate slides with the loop's
            // total length and moved far points by a few millimetres, enough to flip the plan.)
            let dense = points;
            // World-anchored points: where the loop crosses the lattice lines x = (i + 0.5) * spacing
            // and z = (j + 0.5) * spacing, so a distant change of the outline does not move them.
            // The half offset keeps the lines off the cell edges: a straight stretch of rim lies on a
            // cell edge, and float noise there would make crossings appear and vanish with the resampling.
            let mut even: Vec<Vec2> = Vec::new();
            let m = dense.len();
            for k in 0..m {
                let (a, b) = (dense[k], dense[(k + 1) % m]);
                let mut hits: Vec<(f32, Vec2)> = Vec::new();
                for axis in 0..2 {
                    let (va, vb) = if axis == 0 { (a.x, b.x) } else { (a.y, b.y) };
                    let (fa, fb) = ((va / spacing - 0.5).floor() as i32, (vb / spacing - 0.5).floor() as i32);
                    for line in fa.min(fb) + 1..=fa.max(fb) {
                        let at = (line as f32 + 0.5) * spacing;
                        let t = ((at - va) / (vb - va)).clamp(0.0, 1.0);
                        let mut p = a.lerp(b, t);
                        if axis == 0 {
                            p.x = at;
                        } else {
                            p.y = at;
                        }
                        hits.push((t, p));
                    }
                }
                hits.sort_by(|x, y| x.0.partial_cmp(&y.0).unwrap());
                for (_, p) in hits {
                    if even.last().map_or(true, |q: &Vec2| (p - *q).length() >= 0.15) {
                        even.push(p);
                    }
                }
            }
            while even.len() > 1 && (even[even.len() - 1] - even[0]).length() < 0.15 {
                even.pop();
            }
            if even.len() < 8 {
                continue;
            }
            let count = even.len();
            let outward = (0..count)
                .map(|k| {
                    let g = field.gradient(&field.land1, even[k], STEP * 2.0);
                    (-g).normalize_or_zero()
                })
                .collect();
            result.push(Outline { points: even, outward, is_hole: area < 0.0 });
        }
    }
    result.sort_by(|a, b| b.points.len().cmp(&a.points.len()));
    result
}
