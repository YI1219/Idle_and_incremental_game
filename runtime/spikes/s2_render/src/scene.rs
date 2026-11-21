//! Spike S2 stand-in scene. Not the island generator: a quick procedural island
//! with about the triangle load, draw-call count and screen coverage the new
//! renderer is expected to carry, so frame cost can be measured before the real
//! generator exists. Everything is baked into world space with per-vertex
//! shading terms, as cache A of the plan would hold it.
use std::collections::{BTreeMap, HashMap};

use glam::{Vec2, Vec3};

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct Vertex {
    pub pos: [f32; 3],
    pub normal: [f32; 3],
    /// rgb base colour, a = material family (0 ground, 1 stone, 2 leaf, 3 built) / 3.
    pub colour: [u8; 4],
    /// r = baked sky occlusion, g = bounce, b = line importance, a = spare.
    pub terms: [u8; 4],
}

pub const GROUND: u8 = 0;
pub const STONE: u8 = 85;
pub const LEAF: u8 = 170;
pub const BUILT: u8 = 255;

#[derive(Clone, Copy)]
pub struct Cell {
    pub h: f32,
    pub water: Option<f32>,
}

pub struct IslandMesh {
    pub vertices: Vec<Vertex>,
    /// One draw per 8 m chunk: (first vertex, vertex count).
    pub chunks: Vec<(u32, u32)>,
    pub water: Vec<[f32; 3]>,
    pub cells: usize,
    pub centre: Vec3,
    pub radius: f32,
}

fn hash2(x: i32, z: i32, seed: u32) -> f32 {
    let mut h = (x as u32).wrapping_mul(0x9E37_79B1) ^ (z as u32).wrapping_mul(0x85EB_CA77) ^ seed.wrapping_mul(0xC2B2_AE3D);
    h ^= h >> 15;
    h = h.wrapping_mul(0x2C1B_3C6D);
    h ^= h >> 12;
    h = h.wrapping_mul(0x297A_2D39);
    h ^= h >> 15;
    (h & 0x00FF_FFFF) as f32 / 16_777_216.0
}

fn vnoise(x: f32, z: f32, seed: u32) -> f32 {
    let (x0, z0) = (x.floor(), z.floor());
    let (fx, fz) = (x - x0, z - z0);
    let (sx, sz) = (fx * fx * (3.0 - 2.0 * fx), fz * fz * (3.0 - 2.0 * fz));
    let (ix, iz) = (x0 as i32, z0 as i32);
    let a = hash2(ix, iz, seed);
    let b = hash2(ix + 1, iz, seed);
    let c = hash2(ix, iz + 1, seed);
    let d = hash2(ix + 1, iz + 1, seed);
    a + (b - a) * sx + (c - a) * sz + (a - b - c + d) * sx * sz
}

struct Rng(u64);
impl Rng {
    fn next(&mut self) -> f32 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        ((self.0 >> 40) as f32) / 16_777_216.0
    }
    fn range(&mut self, low: f32, high: f32) -> f32 {
        low + (high - low) * self.next()
    }
}

fn smooth_min(a: f32, b: f32, k: f32) -> f32 {
    let h = (0.5 + 0.5 * (b - a) / k).clamp(0.0, 1.0);
    b + (a - b) * h - k * h * (1.0 - h)
}

fn inside(x: i32, z: i32, scale: f32, seed: u32) -> bool {
    let p = Vec2::new(x as f32 + 0.5, z as f32 + 0.5) / scale;
    let lobe = |c: Vec2, r: Vec2| ((p - c) / r).length();
    let d = smooth_min(
        smooth_min(lobe(Vec2::new(-0.35, -0.10), Vec2::new(0.75, 0.50)), lobe(Vec2::new(0.40, 0.15), Vec2::new(0.60, 0.45)), 0.4),
        lobe(Vec2::new(0.0, 0.45), Vec2::new(0.50, 0.30)),
        0.4,
    );
    d < 1.0 + 0.16 * (vnoise(p.x * 3.1, p.y * 3.1, seed) - 0.5)
}

/// A terraced island of about `target` cells with two ponds.
pub fn make_cells(target: usize, seed: u32) -> HashMap<(i32, i32), Cell> {
    let (mut low, mut high) = (4.0_f32, 120.0_f32);
    let mut scale = 30.0;
    for _ in 0..24 {
        scale = 0.5 * (low + high);
        let reach = (scale * 1.6) as i32 + 2;
        let mut count = 0;
        for z in -reach..=reach {
            for x in -reach..=reach {
                if inside(x, z, scale, seed) {
                    count += 1;
                }
            }
        }
        if count > target {
            high = scale;
        } else {
            low = scale;
        }
    }
    let reach = (scale * 1.6) as i32 + 2;
    let mut cells = HashMap::new();
    for z in -reach..=reach {
        for x in -reach..=reach {
            if !inside(x, z, scale, seed) {
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
    // Two ponds: one on a middle terrace, one on the lowest.
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
            let cell = cells[&key];
            if offset.length() < 1.0 && (cell.h - want).abs() < 0.01 {
                cells.insert(key, Cell { h: want - 0.5, water: Some(want - 0.12) });
            }
        }
    }
    cells
}

fn rgb(c: Vec3, family: u8) -> [u8; 4] {
    let q = |v: f32| (v.clamp(0.0, 1.0) * 255.0 + 0.5) as u8;
    [q(c.x), q(c.y), q(c.z), family]
}

fn term(sky: f32, bounce: f32, line: f32) -> [u8; 4] {
    let q = |v: f32| (v.clamp(0.0, 1.0) * 255.0 + 0.5) as u8;
    [q(sky), q(bounce), q(line), 255]
}

struct Builder {
    chunks: BTreeMap<(i32, i32), Vec<Vertex>>,
    origin: Vec3,
}

impl Builder {
    fn push(&mut self, p: [Vec3; 3], n: [Vec3; 3], colour: [u8; 4], terms: [u8; 4]) {
        let mid = (p[0] + p[1] + p[2]) / 3.0;
        let key = ((mid.x / 8.0).floor() as i32, (mid.z / 8.0).floor() as i32);
        let list = self.chunks.entry(key).or_default();
        for i in 0..3 {
            list.push(Vertex { pos: (p[i] + self.origin).to_array(), normal: n[i].to_array(), colour, terms });
        }
    }
    fn tri(&mut self, a: Vec3, b: Vec3, c: Vec3, colour: [u8; 4], terms: [u8; 4]) {
        let mut n = (b - a).cross(c - a).normalize_or_zero();
        if n == Vec3::ZERO {
            n = Vec3::Y;
        }
        self.push([a, b, c], [n, n, n], colour, terms);
    }
    fn quad(&mut self, a: Vec3, b: Vec3, c: Vec3, d: Vec3, colour: [u8; 4], terms: [u8; 4]) {
        self.tri(a, b, c, colour, terms);
        self.tri(a, c, d, colour, terms);
    }
}

/// Unit icosphere as a triangle list (level 2: 320 triangles).
fn icosphere(level: u32) -> Vec<[Vec3; 3]> {
    let t = (1.0 + 5.0_f32.sqrt()) / 2.0;
    let v: Vec<Vec3> = [
        (-1.0, t, 0.0), (1.0, t, 0.0), (-1.0, -t, 0.0), (1.0, -t, 0.0), (0.0, -1.0, t), (0.0, 1.0, t),
        (0.0, -1.0, -t), (0.0, 1.0, -t), (t, 0.0, -1.0), (t, 0.0, 1.0), (-t, 0.0, -1.0), (-t, 0.0, 1.0),
    ]
    .iter()
    .map(|&(x, y, z)| Vec3::new(x, y, z).normalize())
    .collect();
    let faces = [
        [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
        [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
    ];
    let mut tris: Vec<[Vec3; 3]> = faces.iter().map(|f| [v[f[0]], v[f[1]], v[f[2]]]).collect();
    for _ in 0..level {
        let mut next = Vec::with_capacity(tris.len() * 4);
        for [a, b, c] in tris {
            let ab = ((a + b) * 0.5).normalize();
            let bc = ((b + c) * 0.5).normalize();
            let ca = ((c + a) * 0.5).normalize();
            next.extend([[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]);
        }
        tris = next;
    }
    tris
}

/// Builds one island's baked mesh. `detail` scales tufts, rocks and trees.
pub fn build_island(cells: &HashMap<(i32, i32), Cell>, origin: Vec3, seed: u32, detail: f32) -> IslandMesh {
    let mut b = Builder { chunks: BTreeMap::new(), origin };
    let mut rng = Rng(0x9E37_79B9_7F4A_7C15 ^ ((seed as u64) << 20) | 1);
    let sphere = icosphere(2);
    let count = cells.len().max(1) as f32;
    let mut centroid = Vec2::ZERO;
    for key in cells.keys() {
        centroid += Vec2::new(key.0 as f32 + 0.5, key.1 as f32 + 0.5);
    }
    centroid /= count;
    let mut radius: f32 = 1.0;
    for key in cells.keys() {
        radius = radius.max((Vec2::new(key.0 as f32 + 0.5, key.1 as f32 + 0.5) - centroid).length());
    }
    let sides = [(1, 0), (0, 1), (-1, 0), (0, -1)];
    let mut water = Vec::new();
    let mut lip_cells: Vec<(i32, i32)> = Vec::new();
    let mut land_cells: Vec<(i32, i32)> = Vec::new();

    for (&(x, z), cell) in cells {
        let h = cell.h;
        let tone = hash2(x, z, seed ^ 5) - 0.5;
        let mut higher = 0.0;
        let mut on_rim = false;
        for (dx, dz) in sides {
            match cells.get(&(x + dx, z + dz)) {
                Some(other) if other.h > h + 0.01 => higher += 1.0,
                None => on_rim = true,
                _ => {}
            }
        }
        let wet = cell.water.is_some();
        let lawn = if wet { Vec3::new(0.40, 0.43, 0.36) } else { Vec3::new(0.50 + tone * 0.05, 0.56 + tone * 0.05, 0.33 + tone * 0.03) };
        let sky = 1.0 - 0.14 * higher - if wet { 0.1 } else { 0.0 };
        // Top: 2 x 2 patches.
        for sz in 0..2 {
            for sx in 0..2 {
                let (x0, z0) = (x as f32 + sx as f32 * 0.5, z as f32 + sz as f32 * 0.5);
                b.quad(
                    Vec3::new(x0, h, z0),
                    Vec3::new(x0, h, z0 + 0.5),
                    Vec3::new(x0 + 0.5, h, z0 + 0.5),
                    Vec3::new(x0 + 0.5, h, z0),
                    rgb(lawn, GROUND),
                    term(sky, 0.25, 0.2),
                );
            }
        }
        if let Some(level) = cell.water {
            for (ax, az) in [(0.0, 0.0), (0.0, 1.0), (1.0, 1.0), (0.0, 0.0), (1.0, 1.0), (1.0, 0.0)] {
                water.push([x as f32 + ax + origin.x, level + origin.y, z as f32 + az + origin.z]);
            }
        } else {
            land_cells.push((x, z));
            if on_rim {
                lip_cells.push((x, z));
            }
        }
        // Inner steps and the outer cliff.
        for (dx, dz) in sides {
            let (c0, c1) = match (dx, dz) {
                (1, 0) => ((x + 1, z + 1), (x + 1, z)),
                (0, 1) => ((x, z + 1), (x + 1, z + 1)),
                (-1, 0) => ((x, z), (x, z + 1)),
                _ => ((x + 1, z), (x, z)),
            };
            let stone_tone = hash2(c0.0 * 3 + dx, c0.1 * 3 + dz, seed ^ 9) - 0.5;
            let stone = Vec3::new(0.70, 0.67, 0.60) * (1.0 + stone_tone * 0.10);
            match cells.get(&(x + dx, z + dz)) {
                Some(other) if other.h < h - 0.01 => {
                    let steps = ((h - other.h) / 0.5).round().max(1.0) as i32;
                    for s in 0..steps {
                        let (top, bottom) = (h - s as f32 * 0.5, h - (s + 1) as f32 * 0.5);
                        b.quad(
                            Vec3::new(c0.0 as f32, top, c0.1 as f32),
                            Vec3::new(c0.0 as f32, bottom, c0.1 as f32),
                            Vec3::new(c1.0 as f32, bottom, c1.1 as f32),
                            Vec3::new(c1.0 as f32, top, c1.1 as f32),
                            rgb(stone, STONE),
                            term(0.9 - 0.18 * (s + 1) as f32 / steps as f32, 0.4, 0.7),
                        );
                    }
                }
                None => {
                    const RINGS: i32 = 8;
                    let ring = |corner: (i32, i32), k: i32| -> Vec3 {
                        let flat = Vec2::new(corner.0 as f32, corner.1 as f32);
                        let t = k as f32 / RINGS as f32;
                        if k == 0 {
                            return Vec3::new(flat.x, h, flat.y);
                        }
                        let out = (flat - centroid).normalize_or_zero();
                        let root = -6.5 - 3.5 * vnoise(flat.x * 0.08, flat.y * 0.08, seed ^ 3);
                        let bulge = 0.55 * (std::f32::consts::PI * (t * 1.6).min(1.0)).sin();
                        let s = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
                        let taper = s * s * (3.0 - 2.0 * s) * 0.62;
                        let jitter = (hash2(corner.0 * 31 + k, corner.1 * 17 - k, seed ^ 21) - 0.5) * 0.7;
                        let p = flat + out * (bulge + jitter * 0.6) + (centroid - flat) * taper + Vec2::new(-out.y, out.x) * jitter * 0.4;
                        Vec3::new(p.x, 1.2 + (root - 1.2) * t.powf(0.9), p.y)
                    };
                    for k in 0..RINGS {
                        let t = (k as f32 + 0.5) / RINGS as f32;
                        b.quad(ring(c0, k), ring(c0, k + 1), ring(c1, k + 1), ring(c1, k), rgb(stone * (1.0 - 0.10 * t), STONE), term(1.0 - 0.55 * t, 0.3, 1.0));
                    }
                    let tip = Vec3::new(centroid.x, -11.5, centroid.y);
                    b.tri(ring(c0, RINGS), tip, ring(c1, RINGS), rgb(stone * 0.85, STONE), term(0.35, 0.2, 1.0));
                }
                _ => {}
            }
        }
    }
    land_cells.sort();
    lip_cells.sort();
    let top = |cell: (i32, i32)| cells[&cell].h;

    // Tufts: dense along the rim, sparse inside.
    let tuft = |b: &mut Builder, rng: &mut Rng, cell: (i32, i32)| {
        let base = Vec3::new(cell.0 as f32 + rng.next(), top(cell), cell.1 as f32 + rng.next());
        let shade = rng.range(-0.04, 0.05);
        for _ in 0..3 {
            let yaw = rng.range(0.0, std::f32::consts::TAU);
            let side = Vec3::new(yaw.cos(), 0.0, yaw.sin()) * 0.05;
            let lean = Vec3::new(rng.range(-0.08, 0.08), rng.range(0.22, 0.42), rng.range(-0.08, 0.08));
            let normal = Vec3::new(lean.x * 0.6, 1.0, lean.z * 0.6).normalize();
            let colour = rgb(Vec3::new(0.52 + shade, 0.60 + shade, 0.34 + shade * 0.5), GROUND);
            let (p0, p1, p2) = (base - side, base + side, base + lean);
            b.push([p0, p1, p2], [normal; 3], colour, term(0.95, 0.3, 0.0));
            b.push([p1, p0, p2 + side * 0.4], [normal; 3], colour, term(0.95, 0.3, 0.0));
        }
    };
    for &cell in &lip_cells {
        for _ in 0..(16.0 * detail) as i32 {
            tuft(&mut b, &mut rng, cell);
        }
    }
    for &cell in &land_cells {
        for _ in 0..(5.0 * detail) as i32 {
            tuft(&mut b, &mut rng, cell);
        }
    }

    // Rocks.
    let rocks = (count / 34.0 * detail) as usize;
    for _ in 0..rocks {
        let cell = if rng.next() < 0.6 && !lip_cells.is_empty() { lip_cells[(rng.next() * lip_cells.len() as f32) as usize % lip_cells.len()] } else { land_cells[(rng.next() * land_cells.len() as f32) as usize % land_cells.len()] };
        let centre = Vec3::new(cell.0 as f32 + 0.5, top(cell) + 0.15, cell.1 as f32 + 0.5);
        let size = Vec3::new(rng.range(0.35, 0.95), rng.range(0.3, 0.8), rng.range(0.35, 0.95));
        let tone = rng.range(-0.05, 0.05);
        let salt = (rng.next() * 1000.0) as i32;
        let shape = |v: Vec3| -> Vec3 {
            let wobble = 0.8 + 0.4 * hash2((v.x * 2.9).round() as i32 + salt, (v.y * 2.9 + v.z * 5.3).round() as i32, seed ^ 41);
            centre + v * size * wobble
        };
        for tri in &sphere {
            let p = [shape(tri[0]), shape(tri[1]), shape(tri[2])];
            let n = (p[1] - p[0]).cross(p[2] - p[0]).normalize_or_zero();
            let sky = 0.62 + 0.38 * (n.y * 0.5 + 0.5);
            b.push(p, [n; 3], rgb(Vec3::new(0.69 + tone, 0.66 + tone, 0.60 + tone), STONE), term(sky, 0.35, 0.9));
        }
    }

    // Trees: a trunk and five crown clumps.
    let trees = (count / 90.0 * detail) as usize;
    for _ in 0..trees {
        let cell = land_cells[(rng.next() * land_cells.len() as f32) as usize % land_cells.len()];
        let foot = Vec3::new(cell.0 as f32 + 0.5, top(cell), cell.1 as f32 + 0.5);
        let height = rng.range(2.4, 4.2);
        for i in 0..6 {
            let (a0, a1) = (i as f32 / 6.0 * std::f32::consts::TAU, (i + 1) as f32 / 6.0 * std::f32::consts::TAU);
            let (r0, r1) = (Vec3::new(a0.cos(), 0.0, a0.sin()) * 0.16, Vec3::new(a1.cos(), 0.0, a1.sin()) * 0.16);
            b.quad(foot + r0, foot + r1, foot + r1 * 0.7 + Vec3::Y * height, foot + r0 * 0.7 + Vec3::Y * height, rgb(Vec3::new(0.36, 0.30, 0.24), BUILT), term(0.6, 0.3, 0.8));
        }
        let leaf_tone = rng.range(-0.04, 0.04);
        for _ in 0..5 {
            let centre = foot + Vec3::new(rng.range(-0.9, 0.9), height + rng.range(-0.3, 0.9), rng.range(-0.9, 0.9));
            let size = Vec3::new(rng.range(0.9, 1.5), rng.range(0.6, 1.0), rng.range(0.9, 1.5));
            for tri in &sphere {
                let p = [centre + tri[0] * size, centre + tri[1] * size, centre + tri[2] * size];
                let sky = [0.55 + 0.45 * (tri[0].y * 0.5 + 0.5), 0.55 + 0.45 * (tri[1].y * 0.5 + 0.5), 0.55 + 0.45 * (tri[2].y * 0.5 + 0.5)];
                let colour = rgb(Vec3::new(0.33 + leaf_tone, 0.45 + leaf_tone, 0.30 + leaf_tone * 0.5), LEAF);
                // Soft rounded normals; occlusion varies per face, not per corner, in this stand-in.
                b.push(p, [tri[0], tri[1], tri[2]], colour, term((sky[0] + sky[1] + sky[2]) / 3.0, 0.3, 0.6));
            }
        }
    }

    // A few buildings: a box and a roof.
    let buildings = (count / 160.0) as usize;
    for _ in 0..buildings {
        let cell = land_cells[(rng.next() * land_cells.len() as f32) as usize % land_cells.len()];
        let base = Vec3::new(cell.0 as f32 + 0.5, top(cell), cell.1 as f32 + 0.5);
        let (w, d, h) = (rng.range(1.2, 2.2), rng.range(1.0, 1.8), rng.range(1.8, 2.6));
        let corner = |sx: f32, sy: f32, sz: f32| base + Vec3::new(sx * w, sy * h, sz * d);
        let wall = rgb(Vec3::new(0.80, 0.78, 0.72), BUILT);
        let roof = rgb(Vec3::new(0.42, 0.48, 0.52), BUILT);
        b.quad(corner(-1.0, 1.0, 1.0), corner(-1.0, 0.0, 1.0), corner(1.0, 0.0, 1.0), corner(1.0, 1.0, 1.0), wall, term(0.8, 0.4, 1.0));
        b.quad(corner(1.0, 1.0, -1.0), corner(1.0, 0.0, -1.0), corner(-1.0, 0.0, -1.0), corner(-1.0, 1.0, -1.0), wall, term(0.8, 0.4, 1.0));
        b.quad(corner(1.0, 1.0, 1.0), corner(1.0, 0.0, 1.0), corner(1.0, 0.0, -1.0), corner(1.0, 1.0, -1.0), wall, term(0.8, 0.4, 1.0));
        b.quad(corner(-1.0, 1.0, -1.0), corner(-1.0, 0.0, -1.0), corner(-1.0, 0.0, 1.0), corner(-1.0, 1.0, 1.0), wall, term(0.8, 0.4, 1.0));
        let ridge0 = base + Vec3::new(-w * 1.15, h * 1.45, 0.0);
        let ridge1 = base + Vec3::new(w * 1.15, h * 1.45, 0.0);
        let eave = |sx: f32, sz: f32| base + Vec3::new(sx * w * 1.2, h, sz * d * 1.25);
        b.quad(ridge0, eave(-1.0, 1.0), eave(1.0, 1.0), ridge1, roof, term(0.95, 0.3, 1.0));
        b.quad(ridge1, eave(1.0, -1.0), eave(-1.0, -1.0), ridge0, roof, term(0.95, 0.3, 1.0));
        b.tri(ridge0, eave(-1.0, -1.0), eave(-1.0, 1.0), wall, term(0.8, 0.3, 1.0));
        b.tri(ridge1, eave(1.0, 1.0), eave(1.0, -1.0), wall, term(0.8, 0.3, 1.0));
    }

    let mut vertices = Vec::new();
    let mut chunks = Vec::new();
    for list in b.chunks.values() {
        chunks.push((vertices.len() as u32, list.len() as u32));
        vertices.extend_from_slice(list);
    }
    IslandMesh { vertices, chunks, water, cells: cells.len(), centre: origin + Vec3::new(centroid.x, 2.0, centroid.y), radius }
}
