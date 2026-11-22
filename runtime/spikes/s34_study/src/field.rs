//! Cells and the smooth fields derived from them. The cell grid stays the
//! authority for where land is; everything drawn is derived from blurred copies
//! of it, so forms are soft and every derived value depends only on cells within
//! a few metres (which is what keeps an edit local).
use std::collections::HashMap;

use glam::{Vec2, Vec3};

use crate::mesh::{hash2, smoothstep, vnoise, Family, Mesh, Paint};

#[derive(Clone, Copy)]
pub struct Cell {
    pub h: f32,
    /// Absolute water level when the cell holds water; its bed is `h`.
    pub water: Option<f32>,
}

pub type Cells = HashMap<(i32, i32), Cell>;

/// Reads a layout exported by tools/export/export_layouts.gd.
pub fn load_layout(path: &str) -> Cells {
    let text = std::fs::read_to_string(path).unwrap_or_else(|e| panic!("cannot read {path}: {e}"));
    let json: serde_json::Value = serde_json::from_str(&text).expect("layout json");
    let mut cells = Cells::new();
    for record in json["cells"].as_array().expect("cells") {
        let x = record["x"].as_f64().unwrap() as i32;
        let z = record["z"].as_f64().unwrap() as i32;
        let h = record["height"].as_f64().unwrap() as f32;
        let level = record["water"].as_f64().unwrap();
        cells.insert((x, z), Cell { h, water: if level >= 0.0 { Some(level as f32 * 0.5) } else { None } });
    }
    cells
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
            cells.insert((x, z), Cell { h, water: None });
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
                cells.insert(key, Cell { h: want - 0.5, water: Some(want) });
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
    pub high: f32,
    pub low: f32,
    pub high_water: Option<f32>,
    pub low_water: Option<f32>,
}

impl Step {
    /// The high side holds a pond that the low side does not share.
    pub fn pond_wall(&self) -> bool {
        match self.high_water {
            Some(level) => self.low_water.map_or(true, |other| other < level - 0.2),
            None => false,
        }
    }

    /// A hard step with a rock face. A step in the bed under one pond is not (it would show
    /// through the water as a pale line); it stays a soft slope.
    pub fn wall(&self) -> bool {
        let same_pond = matches!((self.high_water, self.low_water), (Some(a), Some(b)) if (a - b).abs() < 1e-3);
        (self.high - self.low >= 0.75 && !same_pond) || self.pond_wall()
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
}

/// The relaxed terrace contours of a set of cells.
fn build_steps(cells: &Cells) -> Vec<Step> {
    let mut keys: Vec<(i32, i32)> = cells.keys().copied().collect();
    keys.sort();
    let mut edges: Vec<((i32, i32), (i32, i32), StepLabel)> = Vec::new();
    for &(x, z) in &keys {
        let a = cells[&(x, z)];
        for (dx, dz) in [(1, 0), (0, 1)] {
            let Some(b) = cells.get(&(x + dx, z + dz)) else { continue };
            if (a.h - b.h).abs() < 1e-4 {
                continue;
            }
            let (c0, c1) = if dx == 1 { ((x + 1, z), (x + 1, z + 1)) } else { ((x, z + 1), (x + 1, z + 1)) };
            let dir = Vec2::new(dx as f32, dz as f32);
            let (hi, lo, toward_low) = if a.h > b.h { (a, *b, dir) } else { (*b, a, -dir) };
            edges.push((c0, c1, StepLabel { high: hi.h, low: lo.h, high_water: hi.water, low_water: lo.water, toward_low }));
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

    let mut steps = Vec::new();
    for (corners, spans, closed) in chains {
        let corner = |c: (i32, i32)| Vec2::new(c.0 as f32, c.1 as f32);
        // Points at the corners and the edge midpoints; one label per 0.5 m piece.
        let mut points: Vec<Vec2> = Vec::new();
        let mut labels: Vec<StepLabel> = Vec::new();
        for (k, &e) in spans.iter().enumerate() {
            let a = corner(corners[k]);
            let b = if k + 1 < corners.len() { corner(corners[k + 1]) } else { corner(corners[0]) };
            points.push(a);
            points.push((a + b) * 0.5);
            labels.push(edges[e].2);
            labels.push(edges[e].2);
        }
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
        for k in 0..pieces {
            let before = if k > 0 { Some(k - 1) } else if closed { Some(pieces - 1) } else { None };
            let after = if k + 1 < pieces { Some(k + 1) } else if closed { Some(0) } else { None };
            let l = labels[k];
            steps.push(Step { a: points[k], b: points[(k + 1) % n], na: joint(k, before), nb: joint(k, after), high: l.high, low: l.low, high_water: l.high_water, low_water: l.low_water });
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
                steps.push(Step { a: points[end], b: points[end] + dir * 1.5, na: normal, nb: normal, high: label.high, low: label.low, high_water: label.high_water, low_water: label.low_water });
            }
        }
    }
    steps
}

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
    cells: Cells,
    floor: f32,
}

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
        let steps = build_steps(cells);
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
        };
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
    fn cell_near(&self, p: Vec2) -> Option<Cell> {
        let (x, z) = (p.x.floor() as i32, p.y.floor() as i32);
        if let Some(c) = self.cells.get(&(x, z)) {
            return Some(*c);
        }
        let mut best: Option<(Cell, f32)> = None;
        for dz in -1..=1 {
            for dx in -1..=1 {
                if let Some(c) = self.cells.get(&(x + dx, z + dz)) {
                    let lo = Vec2::new((x + dx) as f32, (z + dz) as f32);
                    let d = (p - p.clamp(lo, lo + Vec2::ONE)).length();
                    if best.map_or(true, |b| d < b.1) {
                        best = Some((*c, d));
                    }
                }
            }
        }
        best.map(|b| b.0)
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
        if !s.wall() {
            return s.low + (s.high - s.low) * smoothstep(-SOFT_HALF, SOFT_HALF, sd);
        }
        if !high {
            return s.low;
        }
        match s.high_water {
            Some(level) if s.pond_wall() => self.rim(p, level, sd, s.high),
            _ => s.high,
        }
    }

    /// The exact ground height at p (the grid holds it at its samples).
    pub fn surface(&self, p: Vec2) -> f32 {
        let mut h = match self.nearest_step(p) {
            Some((i, sd, _)) => self.side_height(i, p, sd >= 0.0),
            None => self.cell_near(p).map_or(self.floor, |c| c.h),
        };
        // A pond at the outline is held by a bank too.
        if let Some(level) = self.cell_near(p).and_then(|c| c.water) {
            let land = self.sample(&self.land1, p);
            if land < 0.97 {
                h = self.rim(p, level, (land - 0.5) / 0.89, h);
            }
        }
        h
    }

    /// The ground normal at p, taken on p's own side of a nearby wall.
    pub fn ground_normal(&self, p: Vec2) -> Vec3 {
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
fn tri_facing(mesh: &mut Mesh, p: [Vec3; 3], n: [Vec3; 3], c: [Vec3; 3], paint: [Paint; 3]) {
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
            riser: Vec3::new(0.655, 0.618, 0.555),
            bed: Vec3::new(0.22, 0.32, 0.28),
            bank: Vec3::new(0.74, 0.71, 0.58),
        }
    }
}

/// The top surface: one smooth height field clipped at the outline.
pub fn build_top(field: &Field, colours: &TopColours, seed: u32) -> Top {
    let mut mesh = Mesh::default();
    let mut rim = Vec::new();
    let mut brows = Vec::new();
    // A top vertex; `side` forces the height (and its slope) onto one side of a wall.
    let surface = |p: Vec2, side: Option<(usize, bool)>| -> (Vec3, Vec3, Vec3, Paint) {
        let (h, g) = match side {
            Some((i, high)) => {
                let e = 0.12;
                let g = Vec2::new(
                    field.side_height(i, p + Vec2::X * e, high) - field.side_height(i, p - Vec2::X * e, high),
                    field.side_height(i, p + Vec2::Y * e, high) - field.side_height(i, p - Vec2::Y * e, high),
                ) / (2.0 * e);
                (field.side_height(i, p, high), g)
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
            let level = field.water_at(p).or_else(|| field.water_at(p + toward * 0.6)).or_else(|| field.water_at(p + toward * 1.2));
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
            let vertex = |p: Vec2, side: Option<(usize, bool)>| -> TopVertex {
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
                        let fan: Vec<(Vec3, Vec3, Vec3, Paint)> = part.iter().map(|p| vertex(*p, Some((wi, high)))).collect();
                        emit_fan(&mut mesh, field, colours, &fan, centre, seed);
                    }
                    if cross.len() == 2 {
                        wall_ribbon(&mut mesh, &mut brows, field, colours, wi, cross[0], cross[1], &surface, seed);
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

type TopVertex = (Vec3, Vec3, Vec3, Paint);

/// One piece of the top surface. A piece that is steep (a soft step too steep for lawn) or that
/// bridges two levels (where walls meet and the cut cannot follow both) is cut rock, facing the
/// nearest step's low side.
fn emit_fan(mesh: &mut Mesh, field: &Field, colours: &TopColours, fan: &[TopVertex], centre: Vec2, seed: u32) {
    let (lo, hi) = fan.iter().fold((f32::MAX, f32::MIN), |(a, b), v| (a.min(v.0.y), b.max(v.0.y)));
    let cell_normal = field.ground_normal(centre);
    let bridge = hi - lo > 0.45 && field.nearest_wall(centre, 0.6).is_some();
    if cell_normal.y < 0.60 || bridge {
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
            tri_facing(mesh, [fan[0].0, fan[k].0, fan[k + 1].0], [face; 3], [rock(&fan[0]), rock(&fan[k]), rock(&fan[k + 1])], [paint; 3]);
        }
    } else {
        for k in 1..fan.len() - 1 {
            mesh.tri_full([fan[0].0, fan[k].0, fan[k + 1].0], [fan[0].1, fan[k].1, fan[k + 1].1], [fan[0].2, fan[k].2, fan[k + 1].2], [fan[0].3, fan[k].3, fan[k + 1].3]);
        }
    }
}

/// The face of a terrace wall across one grid cell, from c0 to c1 on its relaxed contour: a short
/// roll of the upper lawn over the edge (3.5 cm out, 5 cm down), then cut rock straight down to
/// the lower level, in the bed's colour under a pond's surface.
#[allow(clippy::too_many_arguments)]
fn wall_ribbon(mesh: &mut Mesh, brows: &mut Vec<(Vec3, Vec3, Vec2)>, field: &Field, colours: &TopColours, wi: usize, c0: Vec2, c1: Vec2, surface: &dyn Fn(Vec2, Option<(usize, bool)>) -> TopVertex, seed: u32) {
    let step = field.steps[wi];
    if (c1 - c0).length() < 1e-4 {
        return;
    }
    // Each piece reaches 2 cm past its ends so neighbouring pieces overlap instead of leaving slits.
    let dir = (c1 - c0).normalize();
    let (c0, c1) = (c0 - dir * 0.02, c1 + dir * 0.02);
    let mid = (c0 + c1) * 0.5;
    let notch = step.pond_wall() && field.notch(mid) > 0.5;
    // The face stands 3.5 cm out from the cut everywhere (in a notch the roll above it is flat).
    let (roll_out, roll_down) = if notch { (0.035, 0.0) } else { (0.035, 0.05) };
    struct End {
        c: Vec2,
        n: Vec2,
        n3: Vec3,
        top: f32,
        low: f32,
        colour: Vec3,
    }
    let end = |c: Vec2| {
        let v = surface(c, Some((wi, true)));
        let n = step.normal_near(c);
        End { c, n, n3: Vec3::new(n.x, 0.0, n.y), top: v.0.y, low: field.side_height(wi, c, false), colour: v.2 }
    };
    let e = [end(c0), end(c1)];
    let at = |e: &End, out: f32, y: f32| Vec3::new(e.c.x + e.n.x * out, y, e.c.y + e.n.y * out);
    {
        let paint = Paint::new(Family::Ground).sky(1.0).line(0.35).id(1);
        let rn = [(Vec3::Y * 0.6 + e[0].n3 * 0.4).normalize(), (Vec3::Y * 0.6 + e[1].n3 * 0.4).normalize()];
        let q = [at(&e[0], 0.0, e[0].top), at(&e[1], 0.0, e[1].top), at(&e[1], roll_out, e[1].top - roll_down), at(&e[0], roll_out, e[0].top - roll_down)];
        tri_facing(mesh, [q[0], q[1], q[2]], [rn[0], rn[1], rn[1]], [e[0].colour, e[1].colour, e[1].colour], [paint; 3]);
        tri_facing(mesh, [q[0], q[2], q[3]], [rn[0], rn[1], rn[0]], [e[0].colour, e[1].colour, e[0].colour], [paint; 3]);
    }
    // Rows of the rock face; split at the lower side's water surface when it lies on the face.
    let below = step.low_water.map(|level| level - crate::water::SINK);
    // A wall faces straight out (the cells it replaced leaned back and took more sky), so its rock
    // is a little lighter to keep the terrace walls at the reference tone.
    let tone = (0.94 + 0.10 * hash2((mid.x * 1.3).floor() as i32, (mid.y * 1.3).floor() as i32, seed ^ 33)) * 1.04;
    let lip = e[0].top.max(e[1].top);
    let paint = Paint::new(Family::Stone).sky(0.86).line(0.9).strokes(0.8).id(2).lip(lip);
    let mut rows: Vec<(f32, bool)> = vec![(0.0, false)];
    if let Some(surface_y) = below {
        let t = ((e[0].top - roll_down - surface_y) / (e[0].top - roll_down - e[0].low).max(1e-3)).clamp(0.0, 1.0);
        if t > 0.02 && t < 0.98 {
            rows.push((t, true));
        }
    }
    rows.push((1.0, true));
    let y_of = |e: &End, t: f32| (e.top - roll_down) + (e.low - (e.top - roll_down)) * t;
    for k in 0..rows.len() - 1 {
        let (t0, t1) = (rows[k].0, rows[k + 1].0);
        let wet = below.is_some() && k > 0;
        let colour = if wet { colours.bed } else { colours.riser * tone };
        let q = [at(&e[0], roll_out, y_of(&e[0], t0)), at(&e[1], roll_out, y_of(&e[1], t0)), at(&e[1], roll_out, y_of(&e[1], t1)), at(&e[0], roll_out, y_of(&e[0], t1))];
        tri_facing(mesh, [q[0], q[1], q[2]], [e[0].n3, e[1].n3, e[1].n3], [colour; 3], [paint; 3]);
        tri_facing(mesh, [q[0], q[2], q[3]], [e[0].n3, e[1].n3, e[0].n3], [colour; 3], [paint; 3]);
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
