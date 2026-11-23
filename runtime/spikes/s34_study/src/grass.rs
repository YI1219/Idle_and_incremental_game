//! The grass field (round r4): the frozen project's meadow rosettes, drawn instanced. One clump
//! mesh per detail level (seven leaves on a buried root, `grass_field.gd` `clump_mesh()`) and one
//! record per root (place, turn, size, the ground colour under it), grouped in 8 m chunks. The
//! renderer picks one level per chunk each frame from how wide a leaf is on screen.
//!
//! Placement follows `grass_field.gd` `build()`: 28 roots a square metre, random yaw, sizes from
//! the world `tuft_patch` drift field (fuller tufts gather in drifts between low calm lawn), lip
//! plants aligned to the lip and raised so fans hang over the edge. Colour follows the vertex
//! function of `grass_blades.gdshader`: relative to the ground colour under the root, darker heart
//! and lighter tips only on the tall tufts. Kept from earlier rounds: clearings round props, no
//! roots on water, the pale bank or cut-rock steps, thinner near ponds.
use std::collections::BTreeMap;
use std::sync::OnceLock;

use glam::{Quat, Vec2, Vec3};

use crate::field::{Field, STEP};
use crate::mesh::{hash2, smoothstep};

/// One vertex of a clump mesh, in the clump's own frame (root at the origin, unscaled).
#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct LeafVertex {
    pub pos: [f32; 3],
    /// xyz the leaf's curl normal (snorm), w position across the leaf (-127 one edge, 127 the other, 0 the tip).
    pub normal: [i8; 4],
    /// x position along the leaf (0 root, 255 tip), y the leaf's tone, z, w spare.
    pub data: [u8; 4],
}

/// One root.
#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct Clump {
    pub root: [f32; 3],
    /// Rotation from the clump frame to the world (yaw, and the lip tilt), snorm16 quaternion.
    pub turn: [i16; 4],
    /// Horizontal and vertical scale, unorm16 over 0..4.
    pub size: [u16; 2],
    /// Ground display colour under the root (rgb), a the tuft volume.
    pub ground: [u8; 4],
    /// x the ground's tone patch (gc_noise), y and z the pillow gradient (128 = 0, 1/64 per unit), w spare.
    pub misc: [u8; 4],
}

/// Detail levels: two bends a leaf, one bend, one bend at half the roots with wider leaves, and a
/// flat leaf at a quarter of the roots with wider leaves still.
pub const LEVELS: usize = 4;
const SEGMENTS: [usize; LEVELS] = [3, 2, 2, 1];
const WIDEN: [f32; LEVELS] = [1.0, 1.0, 1.6, 2.3];
/// Projected width of a leaf (output pixels) below which each coarser level is used.
pub const LEVEL_PX: [f32; LEVELS - 1] = [5.0, 1.5, 0.75];
/// A representative leaf's full width in metres (Godot's half-widths 0.028 to 0.046).
pub const LEAF_WIDTH: f32 = 0.075;
pub const CHUNK: f32 = 8.0;
const DENSITY: f32 = 28.0;
/// Lip plants a metre of outline.
const LIP_DENSITY: f32 = 6.0;

pub struct Chunk {
    pub lo: Vec3,
    pub hi: Vec3,
    /// First clump and the counts at full, half and quarter density (the clumps of a chunk are
    /// ordered quarter members first, then half members).
    pub first: u32,
    pub counts: [u32; 3],
}

#[derive(Default)]
pub struct Grass {
    pub clumps: Vec<Clump>,
    pub chunks: Vec<Chunk>,
}

impl Grass {
    pub fn append(&mut self, other: Grass) {
        let base = self.clumps.len() as u32;
        self.clumps.extend_from_slice(&other.clumps);
        for chunk in other.chunks {
            self.chunks.push(Chunk { first: chunk.first + base, ..chunk });
        }
    }
}

/// The clump meshes of all levels, one after another: vertices, indices, and per level its
/// vertex offset and index range.
pub struct Meshes {
    pub vertices: Vec<LeafVertex>,
    pub indices: Vec<u32>,
    pub levels: [(u32, std::ops::Range<u32>); LEVELS],
}

impl Meshes {
    pub fn triangles(&self, level: usize) -> u64 {
        ((self.levels[level].1.end - self.levels[level].1.start) / 3) as u64
    }
}

/// Godot's world hash (grass_field.gd `_hash`).
fn ghash(x: f32, y: f32, salt: f32) -> f32 {
    let v = ((x as f64) * 127.1 + (y as f64) * 311.7 + (salt as f64) * 74.7).sin() * 43758.5453;
    (v - v.floor()) as f32
}

/// Godot's `_organic_drift`.
fn organic_drift(x: f32, z: f32) -> f32 {
    let wx = x + (z * 0.52).sin() * 0.48;
    let wz = z + (x * 0.46).cos() * 0.48;
    let d1 = (wx * 0.78 + wz * 0.51 + 1.3).sin() * (wz * 0.69 - wx * 0.43 + 0.7).cos();
    let d2 = (wx * 1.63 - wz * 1.19 + 4.1).sin() * (wz * 1.41 + wx * 0.97 + 2.6).cos();
    (0.5 + 0.34 * d1 + 0.18 * d2).clamp(0.0, 1.0)
}

/// The fuller-tuft field (grass_field.gd): 0 in the calm lawn, rising to 1 in the drifts.
pub fn tuft_patch(p: Vec2) -> f32 {
    smoothstep(0.46, 0.80, organic_drift(p.x * 2.1 + 1.3, p.y * 2.1 - 2.7)).powf(1.8)
}

// ---- ground_cover.gdshaderinc, ported for the colour of the ground under the lawn and the roots

fn gc_hash(p: Vec2) -> f32 {
    let v = ((p.x as f64) * 127.1 + (p.y as f64) * 311.7).sin() * 43758.5453;
    (v - v.floor()) as f32
}

pub fn gc_noise(p: Vec2) -> f32 {
    let i = p.floor();
    let f = p - i;
    let u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    let a = gc_hash(i);
    let b = gc_hash(i + Vec2::X);
    let c = gc_hash(i + Vec2::Y);
    let d = gc_hash(i + Vec2::ONE);
    let ab = a + (b - a) * u.x;
    let cd = c + (d - c) * u.x;
    ab + (cd - ab) * u.y
}

fn rot_a(p: Vec2) -> Vec2 {
    Vec2::new(0.8 * p.x - 0.6 * p.y, 0.6 * p.x + 0.8 * p.y)
}

fn rot_b(p: Vec2) -> Vec2 {
    Vec2::new(-0.44 * p.x - 0.90 * p.y, 0.90 * p.x - 0.44 * p.y)
}

fn pillow_core(p: Vec2) -> f32 {
    gc_noise(rot_a(p) * 0.34 + Vec2::new(3.7, 8.2)) * 0.62 + gc_noise(rot_b(p) * 0.68 + Vec2::new(14.3, 5.9)) * 0.38
}

/// Godot's `gc_pillow_grad`: the slope of the broad moss cushions (per metre).
pub fn pillow_grad(p: Vec2) -> Vec2 {
    let e = 0.22;
    let h0 = pillow_core(p);
    Vec2::new(pillow_core(p + Vec2::new(e, 0.0)) - h0, pillow_core(p + Vec2::new(0.0, e)) - h0) / e
}

fn lin(c: f32) -> f32 {
    if c <= 0.04045 {
        c / 12.92
    } else {
        ((c + 0.055) / 1.055).powf(2.4)
    }
}

fn unlin(c: f32) -> f32 {
    if c <= 0.0031308 {
        c * 12.92
    } else {
        1.055 * c.max(0.0).powf(1.0 / 2.4) - 0.055
    }
}

pub fn to_linear(c: Vec3) -> Vec3 {
    Vec3::new(lin(c.x), lin(c.y), lin(c.z))
}

pub fn to_display(c: Vec3) -> Vec3 {
    Vec3::new(unlin(c.x), unlin(c.y), unlin(c.z))
}

/// `ground_cover()` without its constant factors and the paths: linear albedo of the meadow.
fn cover(p: Vec2) -> Vec3 {
    let base = to_linear(Vec3::new(0.45, 0.52, 0.35));
    let high = to_linear(Vec3::new(0.68, 0.69, 0.47));
    let broad = gc_noise(rot_a(p) * 0.32 + Vec2::new(4.3, 9.1));
    let wash = gc_noise(rot_b(p) * 0.72 + Vec2::new(13.7, 2.4));
    let pillow = pillow_core(p);
    let pigment = smoothstep(0.14, 0.88, broad * 0.64 + wash * 0.36);
    let moss = base.lerp(high, 0.38 + pigment * 0.52);
    let cool = moss * Vec3::new(0.96, 1.04, 0.95);
    let warm = moss * Vec3::new(1.28, 1.20, 1.02);
    let colour = cool.lerp(warm, smoothstep(0.12, 0.88, pillow * 0.58 + wash * 0.42));
    let paper = gc_noise(rot_b(p) * 2.1 + Vec2::new(6.1, 11.4));
    colour * (1.015 + 0.030 * paper)
}

/// The mean of `cover` over a large area, so the soft patches vary round the authored colour.
fn cover_mean() -> Vec3 {
    static MEAN: OnceLock<Vec3> = OnceLock::new();
    *MEAN.get_or_init(|| {
        let mut sum = Vec3::ZERO;
        let n = 160;
        for j in 0..n {
            for i in 0..n {
                sum += cover(Vec2::new(i as f32 * 0.613 - 49.0, j as f32 * 0.587 - 47.0));
            }
        }
        sum / (n * n) as f32
    })
}

/// The lawn's ground colour at `p` (display values): `base` carrying ground_cover's soft patches.
pub fn lawn_ground(base: Vec3, p: Vec2) -> Vec3 {
    to_display(to_linear(base) * cover(p) / cover_mean())
}

// ---- the clump

/// One of the seven leaves of the clump (the same seven for every clump, as in Godot).
struct Leaf {
    angle: f32,
    plume: bool,
    height: f32,
    lean: f32,
    width: f32,
    radius: f32,
    tone: f32,
}

fn leaves() -> Vec<Leaf> {
    let lerp = |a: f32, c: f32, t: f32| a + (c - a) * t;
    (0..7)
        .map(|b| {
            let bf = b as f32;
            let plume = b < 3;
            Leaf {
                angle: std::f32::consts::TAU * bf / 7.0 + (ghash(bf, 1.0, 3.0) - 0.5) * 0.42,
                plume,
                height: if plume { lerp(0.16, 0.26, ghash(bf, 2.0, 5.0)) } else { lerp(0.07, 0.12, ghash(bf, 2.0, 5.0)) },
                lean: if plume { lerp(0.16, 0.23, ghash(bf, 3.0, 7.0)) } else { lerp(0.09, 0.15, ghash(bf, 3.0, 7.0)) },
                width: if plume { lerp(0.032, 0.046, ghash(bf, 4.0, 9.0)) } else { lerp(0.028, 0.040, ghash(bf, 4.0, 9.0)) },
                radius: lerp(0.025, 0.075, ghash(bf, 5.0, 11.0)),
                tone: (ghash(bf, 7.0, 17.0) + if plume { 0.12 } else { -0.04 }).clamp(0.0, 1.0),
            }
        })
        .collect()
}

fn snorm(v: f32) -> i8 {
    (v.clamp(-1.0, 1.0) * 127.0).round() as i8
}

/// The clump meshes of every level: each leaf a ribbon of `SEGMENTS` quads ending in a point,
/// centre line `root + dir*lean*t^1.35 + up*height*sin(t*pi*0.68)`, half-width
/// `w*(1 - 0.985 t)^0.72` (the centre ridge of Godot's near mesh is left out).
pub fn meshes() -> Meshes {
    let shapes = leaves();
    let mut vertices = Vec::new();
    let mut indices = Vec::new();
    let mut levels: [(u32, std::ops::Range<u32>); LEVELS] = std::array::from_fn(|_| (0, 0..0));
    for level in 0..LEVELS {
        let v0 = vertices.len() as u32;
        let i0 = indices.len() as u32;
        let segments = SEGMENTS[level];
        for leaf in &shapes {
            let width = leaf.width * WIDEN[level];
            let dir = Vec3::new(leaf.angle.cos(), 0.0, leaf.angle.sin());
            let side = Vec3::new(-dir.z, 0.0, dir.x);
            let root = dir * leaf.radius;
            let first = vertices.len() as u32 - v0;
            for i in 0..=segments {
                let t = i as f32 / segments as f32;
                let centre = root + dir * leaf.lean * t.powf(1.35) + Vec3::Y * leaf.height * (t * std::f32::consts::PI * 0.68).sin();
                let w = width * (1.0 - t * 0.985).powf(0.72);
                let sides: &[f32] = if i < segments { &[-1.0, 1.0] } else { &[0.0] };
                for &across in sides {
                    let pos = centre + side * (w * across);
                    let n = (Vec3::Y + dir * (0.10 + t * 0.70) + side * (across * 0.42)).normalize();
                    vertices.push(LeafVertex {
                        pos: pos.to_array(),
                        normal: [snorm(n.x), snorm(n.y), snorm(n.z), snorm(across)],
                        data: [(t * 255.0).round() as u8, (leaf.tone * 255.0).round() as u8, leaf.plume as u8, 0],
                    });
                }
            }
            for i in 0..segments as u32 {
                let (l0, r0) = (first + 2 * i, first + 2 * i + 1);
                if (i as usize) + 1 < segments {
                    indices.extend_from_slice(&[l0, r0, r0 + 2, l0, r0 + 2, l0 + 2]);
                } else {
                    indices.extend_from_slice(&[l0, r0, l0 + 2]);
                }
            }
        }
        levels[level] = (v0, i0..indices.len() as u32);
    }
    Meshes { vertices, indices, levels }
}

// ---- placement

/// The rim of the top surface (segments on the outline), as `field::build_top` returns it.
pub type Rim = [(Vec3, Vec3)];

/// One placed root before packing, with its level membership (1 half, 2 quarter).
struct Site {
    clump: Clump,
    member: u8,
}

fn unorm16(v: f32, range: f32) -> u16 {
    ((v / range).clamp(0.0, 1.0) * 65535.0).round() as u16
}

fn snorm16(v: f32) -> i16 {
    (v.clamp(-1.0, 1.0) * 32767.0).round() as i16
}

/// Builds the field for one island in its own coordinates, moved by `origin`.
/// `clear` holds circles (centre, radius) the roots keep out of; `lawn` is the base ground colour.
pub fn build(field: &Field, rim: &Rim, brows: &[(Vec3, Vec3, Vec2)], clear: &[(Vec2, f32)], seed: u32, origin: Vec3, lawn: Vec3) -> Grass {
    let spacing = 1.0 / DENSITY.sqrt();
    let lo = field.origin;
    let hi = field.origin + Vec2::new(field.nx as f32, field.nz as f32) * STEP;
    // Clearings bucketed by chunk (with their reach) so each root tests only a few.
    let mut clear_by_chunk: BTreeMap<(i32, i32), Vec<(Vec2, f32)>> = BTreeMap::new();
    for &(c, r) in clear {
        let reach = r + 0.35;
        for cz in ((c.y - reach) / CHUNK).floor() as i32..=((c.y + reach) / CHUNK).floor() as i32 {
            for cx in ((c.x - reach) / CHUNK).floor() as i32..=((c.x + reach) / CHUNK).floor() as i32 {
                clear_by_chunk.entry((cx, cz)).or_default().push((c, r));
            }
        }
    }
    let none: Vec<(Vec2, f32)> = Vec::new();
    // How far from every clearing a point is, as a scale: 0 inside one, rising to 1 over 0.35 m.
    let clearance = |p: Vec2| -> f32 {
        let key = ((p.x / CHUNK).floor() as i32, (p.y / CHUNK).floor() as i32);
        let mut k: f32 = 1.0;
        for &(c, r) in clear_by_chunk.get(&key).unwrap_or(&none) {
            let d = (p - c).length();
            k = k.min(smoothstep(r, r + 0.35, d));
        }
        k
    };
    // A level found by looking toward the water only counts when this ground is near it (round r8:
    // the lawn at the foot of a pond's wall took the upper pond's level and went bare).
    let water_surface = |p: Vec2, h: f32| -> Option<f32> {
        let toward = field.gradient(&field.wet, p, STEP).normalize_or_zero();
        field
            .water_at(p)
            .or_else(|| [0.6_f32, 1.2].iter().filter_map(|d| field.water_at(p + toward * *d)).find(|l| h > l - crate::water::SINK - 0.3))
            .map(|level| level - crate::water::SINK)
    };
    let lerp = |a: f32, b: f32, t: f32| a + (b - a) * t;
    let diag: Option<Vec2> = std::env::var("S34_GRASSDIAG").ok().map(|s| {
        let v: Vec<f32> = s.split(',').map(|x| x.parse().unwrap()).collect();
        Vec2::new(v[0], v[1])
    });
    let mut sites: BTreeMap<(i32, i32), Vec<Site>> = BTreeMap::new();
    let place = |root: Vec3, up: Vec3, scale: f32, h_scale: f32, member: u8, sites: &mut BTreeMap<(i32, i32), Vec<Site>>| {
        let p = Vec2::new(root.x, root.z);
        let yaw = ghash(p.x * 2.13 + p.y * 0.71, p.y * 1.93 - p.x * 0.83, 4.0) * std::f32::consts::TAU;
        let turn = Quat::from_rotation_arc(Vec3::Y, up) * Quat::from_rotation_y(yaw);
        let ground = lawn_ground(lawn, p);
        // grass_blades.gdshader: the root's height scale is the tuft's pigment weight.
        let tuft_volume = smoothstep(0.82, 1.28, h_scale);
        let patch = gc_noise(p * 0.55 + Vec2::new(4.1, 2.7));
        let pg = pillow_grad(p) * 0.14;
        let q = turn.to_array();
        let clump = Clump {
            root: (root + origin).to_array(),
            turn: [snorm16(q[0]), snorm16(q[1]), snorm16(q[2]), snorm16(q[3])],
            size: [unorm16(scale, 4.0), unorm16(h_scale, 4.0)],
            ground: [
                (ground.x.clamp(0.0, 1.0) * 255.0).round() as u8,
                (ground.y.clamp(0.0, 1.0) * 255.0).round() as u8,
                (ground.z.clamp(0.0, 1.0) * 255.0).round() as u8,
                (tuft_volume * 255.0).round() as u8,
            ],
            misc: [(patch * 255.0).round() as u8, (128.0 + pg.x * 64.0).round().clamp(0.0, 255.0) as u8, (128.0 + pg.y * 64.0).round().clamp(0.0, 255.0) as u8, 0],
        };
        let key = ((p.x / CHUNK).floor() as i32, (p.y / CHUNK).floor() as i32);
        sites.entry(key).or_default().push(Site { clump, member });
    };

    // The field: a jittered lattice at 28 roots a square metre, world anchored.
    let (i0, i1) = ((lo.x / spacing).floor() as i32, (hi.x / spacing).ceil() as i32);
    let (j0, j1) = ((lo.y / spacing).floor() as i32, (hi.y / spacing).ceil() as i32);
    for j in j0..j1 {
        for i in i0..i1 {
            let jitter = Vec2::new(hash2(i, j, seed ^ 201), hash2(i, j, seed ^ 202));
            let p = (Vec2::new(i as f32, j as f32) + jitter) * spacing;
            let land = field.sample(&field.land1, p);
            if land < 0.5 || field.water_at(p).is_some() {
                continue;
            }
            let h = field.height_at(p);
            let ground_n = field.ground_normal(p);
            let ny = ground_n.y;
            if ny < 0.62 {
                continue; // cut rock of a terrace step
            }
            let mut keep = 1.0;
            let wet = field.sample(&field.wet, p);
            if wet > 0.02 {
                if let Some(surface) = water_surface(p, h) {
                    if h < surface + 0.05 || (h - surface).abs() < 0.12 {
                        continue; // under water, or on the pale bank at the waterline
                    }
                }
                keep *= 1.0 - 0.65 * smoothstep(0.03, 0.45, wet);
            }
            let mut clear_k = clearance(p);
            if let Some(at) = diag {
                if (p - at).length() < 0.5 {
                    let w = field.nearest_wall(p, 0.7).map(|i| field.steps[i].signed(p));
                    println!("GRASSDIAG ({:.2},{:.2}) h {h:.2} ny {ny:.2} wet {wet:.3} clear {clear_k:.2} wall {w:?}", p.x, p.y);
                }
            }
            // Round r8: the foot of a terrace wall is always planted. A prop's clearing that reached a
            // wall left bare ground there, and in the prop's shadow that bare strip read as a dark
            // cavity under the wall (the owner's hollow joint). Props stand at least 0.4 m off walls.
            if clear_k < 1.0 {
                if let Some(i) = field.nearest_wall(p, 0.7) {
                    let (d, sd) = field.steps[i].signed(p);
                    if sd < 0.0 {
                        clear_k = clear_k.max(0.85 * (1.0 - smoothstep(0.42, 0.70, d)));
                    }
                }
            }
            if clear_k <= 0.0 {
                continue;
            }
            // Godot: steeper lawn carries fewer, smaller plants; the brow of a terrace step is a lip.
            let lip_factor = smoothstep(0.78, 0.97, ny).clamp(0.42, 1.0);
            if hash2(i, j, seed ^ 203) > keep * lerp(0.62, 1.0, lip_factor) {
                continue;
            }
            let soft_lip = ny < 0.88;
            let tuft = tuft_patch(p);
            // Our clearings stand in for Godot's path taper (0.55 at the edge of a clearing).
            let thin = lerp(0.55, 1.0, clear_k) * lerp(0.75, 1.0, keep);
            let mut scale = lerp(0.88, 1.18, ghash(p.y * 1.7 + p.x * 0.5, p.x * 2.3, 5.0)) * lerp(0.90, 1.35, tuft) * lerp(0.72, 1.0, lip_factor) * thin;
            let slope_height = if soft_lip { 1.0 } else { lerp(0.46, 1.0, lip_factor) };
            let mut h_scale = lerp(0.68, 1.35, tuft) * lerp(0.88, 1.14, ghash(p.x * 1.9, p.y * 2.1 + p.x * 0.3, 6.0)) * slope_height * thin;
            let mut up = Vec3::Y;
            let mut root = Vec3::new(p.x, h - 0.01, p.y);
            if soft_lip {
                // The edge keeps a planted fringe with taller fans where the tuft field is high,
                // aligned to the lip surface.
                scale = scale.max(lerp(0.98, 1.75, tuft) * thin);
                h_scale = h_scale.max(lerp(0.80, 1.70, tuft) * thin);
                up = ground_n;
                root = Vec3::new(p.x, h, p.y) - up * 0.008;
            }
            let member = (((i + j) & 1 == 0) as u8) | ((((i & 1) == 0 && (j & 1) == 0) as u8) << 1);
            place(root, up, scale, h_scale, member, &mut sites);
        }
    }

    // Lip plants on the outline's roll, aligned to it, raised as Godot's lip samples are, so leaf
    // fans hang over the edge at irregular intervals (wherever the tuft field is high).
    let mut counter = 0i32;
    // The outline's rim (outward from the occupancy field) and the terrace walls' brows (outward
    // given): the same planted fringe.
    let edges: Vec<(Vec3, Vec3, Option<Vec2>)> = rim.iter().map(|&(a, b)| (a, b, None)).chain(brows.iter().map(|&(a, b, n)| (a, b, Some(n)))).collect();
    for &(a, b, given) in &edges {
        let length = (b - a).length();
        let want = length * LIP_DENSITY;
        let mut count = want.floor() as i32;
        let mid = Vec2::new((a.x + b.x) * 0.5, (a.z + b.z) * 0.5);
        if hash2((mid.x * 31.0) as i32, (mid.y * 31.0) as i32, seed ^ 204) < want - count as f32 {
            count += 1;
        }
        for k in 0..count {
            counter += 1;
            let u = (k as f32 + hash2(counter, 7, seed ^ 205)) / count.max(1) as f32;
            let at = a.lerp(b, u.min(1.0));
            let p = Vec2::new(at.x, at.z);
            if field.sample(&field.wet, p) > 0.10 {
                continue;
            }
            let clear_k = clearance(p);
            if clear_k < 0.5 {
                continue;
            }
            let outward = given.unwrap_or_else(|| -field.gradient(&field.land1, p, STEP * 1.5).normalize_or_zero());
            let out = Vec3::new(outward.x, 0.0, outward.y);
            // On the upper part of the roll, tipped 30 to 52 degrees out (Godot keeps lip
            // triangles up to about 54 degrees).
            let tilt: f32 = (30.0 + 22.0 * hash2(counter, 8, seed ^ 206)).to_radians();
            let up = (Vec3::Y * tilt.cos() + out * tilt.sin()).normalize();
            let root = at + out * (0.015 + 0.02 * hash2(counter, 11, seed ^ 209)) - Vec3::Y * 0.012 - up * 0.008;
            let tuft = tuft_patch(p);
            let thin = lerp(0.55, 1.0, clear_k);
            let lip_factor = 0.42;
            let scale = (lerp(0.88, 1.18, ghash(p.y * 1.7 + p.x * 0.5, p.x * 2.3, 5.0)) * lerp(0.90, 1.35, tuft) * lerp(0.72, 1.0, lip_factor) * thin).max(lerp(0.98, 1.75, tuft) * thin);
            let h_scale = (lerp(0.68, 1.35, tuft) * lerp(0.88, 1.14, ghash(p.x * 1.9, p.y * 2.1 + p.x * 0.3, 6.0)) * thin).max(lerp(0.80, 1.70, tuft) * thin);
            let member = ((counter & 1 == 0) as u8) | (((counter & 3 == 0) as u8) << 1);
            place(root, up, scale, h_scale, member, &mut sites);
        }
    }

    // Pack: per chunk the quarter members first, then the half members, then the rest.
    let mut grass = Grass::default();
    for (_, mut list) in sites {
        list.sort_by_key(|s| if s.member & 2 != 0 { 0 } else if s.member & 1 != 0 { 1 } else { 2 });
        let (mut lo3, mut hi3) = (Vec3::splat(f32::MAX), Vec3::splat(f32::MIN));
        for site in &list {
            let r = Vec3::from_array(site.clump.root);
            lo3 = lo3.min(r - Vec3::new(0.5, 0.4, 0.5));
            hi3 = hi3.max(r + Vec3::new(0.5, 0.5, 0.5));
        }
        let quarter = list.iter().filter(|s| s.member & 2 != 0).count() as u32;
        let half = list.iter().filter(|s| s.member != 0).count() as u32;
        let first = grass.clumps.len() as u32;
        grass.clumps.extend(list.iter().map(|s| s.clump));
        grass.chunks.push(Chunk { lo: lo3, hi: hi3, first, counts: [list.len() as u32, half, quarter] });
    }
    grass
}
