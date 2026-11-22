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
        let weight = gaussian(&land, nx, nz, 0.20);
        let mut height = gaussian(&raw, nx, nz, 0.20);
        for (h, w) in height.iter_mut().zip(&weight) {
            *h = if *w > 1e-4 { *h / *w } else { 0.0 };
        }
        Field {
            nx,
            nz,
            origin,
            land1: gaussian(&land, nx, nz, 0.45),
            land2: gaussian(&land, nx, nz, 2.5),
            land3: gaussian(&land, nx, nz, 7.0),
            height,
            water,
            wet: gaussian(&wet, nx, nz, 0.5),
        }
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
}

/// Colours of the top surface. Kept together so the look study can swap them.
#[derive(Clone, Copy)]
pub struct TopColours {
    pub lawn: Vec3,
    pub lawn_warm: Vec3,
    pub lawn_cool: Vec3,
    pub riser: Vec3,
    pub bed: Vec3,
    pub bank: Vec3,
}

impl Default for TopColours {
    fn default() -> TopColours {
        TopColours {
            lawn: Vec3::new(0.44, 0.60, 0.27),
            lawn_warm: Vec3::new(0.56, 0.65, 0.28),
            lawn_cool: Vec3::new(0.35, 0.54, 0.30),
            riser: Vec3::new(0.70, 0.68, 0.60),
            bed: Vec3::new(0.36, 0.42, 0.36),
            bank: Vec3::new(0.74, 0.71, 0.58),
        }
    }
}

/// The top surface: one smooth height field clipped at the outline.
pub fn build_top(field: &Field, colours: &TopColours, seed: u32) -> Top {
    let mut mesh = Mesh::default();
    let mut rim = Vec::new();
    let surface = |p: Vec2| -> (Vec3, Vec3, Vec3, Paint) {
        let h = field.height_at(p);
        let g = field.gradient(&field.height, p, STEP);
        let normal = Vec3::new(-g.x, 1.0, -g.y).normalize();
        let slope = g.length();
        // Steps are cut as whole facets where the triangles are emitted; vertices stay lawn.
        let stone = 0.0 * slope;
        let patch = vnoise(p.x * 0.11, p.y * 0.11, seed ^ 31);
        let fine = vnoise(p.x * 0.45, p.y * 0.45, seed ^ 32) - 0.5;
        let mut lawn = if patch > 0.5 { colours.lawn.lerp(colours.lawn_warm, (patch - 0.5) * 1.6) } else { colours.lawn.lerp(colours.lawn_cool, (0.5 - patch) * 1.6) };
        lawn += Vec3::splat(fine * 0.025);
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
    for j in 0..field.nz - 1 {
        for i in 0..field.nx - 1 {
            let corners = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)];
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
            let fan: Vec<(Vec3, Vec3, Vec3, Paint)> = polygon.iter().map(|p| surface(*p)).collect();
            for k in 1..fan.len() - 1 {
                let p = [fan[0].0, fan[k].0, fan[k + 1].0];
                let mut face = (p[1] - p[0]).cross(p[2] - p[0]).normalize_or_zero();
                if face.y < 0.0 {
                    face = -face;
                }
                if face.y < 0.60 && face != Vec3::ZERO {
                    // A terrace step is cut rock: whole facets, flat shaded, with their own edge,
                    // not a slope smeared between lawn and stone.
                    let mid = (p[0] + p[1] + p[2]) / 3.0;
                    let tone = 0.94 + 0.10 * hash2((mid.x * 1.3).floor() as i32, (mid.z * 1.3).floor() as i32, seed ^ 33);
                    let paint = Paint::new(Family::Stone).sky(0.86).line(0.9).strokes(0.8).id(2);
                    mesh.tri_full(p, [face; 3], [colours.riser * tone; 3], [paint; 3]);
                } else {
                    mesh.tri_full(p, [fan[0].1, fan[k].1, fan[k + 1].1], [fan[0].2, fan[k].2, fan[k + 1].2], [fan[0].3, fan[k].3, fan[k + 1].3]);
                }
            }
            if crossings.len() == 2 {
                let (a, b) = (crossings[0], crossings[1]);
                rim.push((Vec3::new(a.x, field.height_at(a), a.y), Vec3::new(b.x, field.height_at(b), b.y)));
            }
        }
    }
    // The lip: the lawn rolls over the edge and tucks under, covering the join with the rock.
    // Outward direction per end point, so neighbouring pieces share normals and the lip reads as one roll.
    let outward = |p: Vec3| -> Vec3 {
        let inward = field.gradient(&field.land1, Vec2::new(p.x, p.z), STEP * 1.5).normalize_or_zero();
        Vec3::new(-inward.x, 0.0, -inward.y)
    };
    for &(a, b) in &rim {
        let mid = Vec2::new((a.x + b.x) * 0.5, (a.z + b.z) * 0.5);
        let (out_a, out_b) = (outward(a), outward(b));
        let tone = colours.lawn.lerp(colours.lawn_cool, 0.5) * (0.94 + 0.06 * vnoise(mid.x * 0.6, mid.y * 0.6, seed));
        let rings = [(0.0, 0.0), (0.10, 0.07), (0.12, 0.20), (0.03, 0.36), (-0.16, 0.42)];
        for k in 0..rings.len() - 1 {
            let (o0, d0) = rings[k];
            let (o1, d1) = rings[k + 1];
            let normal = |out3: Vec3| (out3 * (d1 - d0) + Vec3::Y * (o1 - o0)).normalize_or_zero();
            let paint = Paint::new(Family::Ground).sky(1.0 - 0.18 * k as f32).line(0.35).id(1);
            let shade = tone * (1.0 - 0.07 * k as f32);
            let quad = [a + out_a * o0 - Vec3::Y * d0, b + out_b * o0 - Vec3::Y * d0, b + out_b * o1 - Vec3::Y * d1, a + out_a * o1 - Vec3::Y * d1];
            let (na, nb) = (normal(out_a), normal(out_b));
            mesh.tri_full([quad[0], quad[1], quad[2]], [na, nb, nb], [shade; 3], [paint; 3]);
            mesh.tri_full([quad[0], quad[2], quad[3]], [na, nb, na], [shade; 3], [paint; 3]);
        }
    }
    Top { mesh, rim }
}

/// One closed outline of the island as evenly spaced points, with the direction
/// pointing out of the island at each.
pub struct Outline {
    pub points: Vec<Vec2>,
    pub outward: Vec<Vec2>,
    pub is_hole: bool,
}

/// Outlines traced on the cell grid, smoothed, pulled onto the 0.5 contour of
/// the fine field, and resampled every `spacing` metres.
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
            let n = points.len();
            let length: f32 = (0..n).map(|k| (points[(k + 1) % n] - points[k]).length()).sum();
            let count = (length / spacing).round().max(8.0) as usize;
            let step = length / count as f32;
            let mut even = Vec::with_capacity(count);
            let (mut k, mut walked, mut target) = (0usize, 0.0_f32, 0.0_f32);
            while even.len() < count {
                let (a, b) = (points[k % n], points[(k + 1) % n]);
                let seg = (b - a).length();
                if walked + seg >= target && seg > 1e-6 {
                    even.push(a.lerp(b, (target - walked) / seg));
                    target += step;
                } else {
                    walked += seg;
                    k += 1;
                }
            }
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
