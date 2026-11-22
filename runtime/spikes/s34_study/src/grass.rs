//! The grass field: clumps of tapered blades over the whole lawn, baked into static world-space
//! geometry per 8 m chunk at three densities. The renderer picks one density per chunk each
//! frame from its distance to the camera. Shape, density and colour follow the frozen project's
//! `grass_field.gd` and `grass_blades.gdshader` (28 clumps a square metre, seven blades a clump:
//! three long arching plumes and four short leaves around a buried root).
//!
//! Where: inside the outline, not on water or the pale bank, not on cut-rock steps, thinner near
//! ponds, cleared around props (per-kind radii scaled by instance size). Near the outline and at
//! the top of a terrace step the clumps tip outward and stand taller, and a fringe row rooted on
//! the lawn lip leans out over it, so the island's edge is a soft grass fringe.
use std::collections::BTreeMap;
use std::ops::Range;

use glam::{Quat, Vec2, Vec3};

use crate::field::{Field, STEP};
use crate::mesh::{hash2, smoothstep, vnoise};

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct GrassVertex {
    pub pos: [f32; 3],
    /// xyz shading normal (snorm), w position across the blade (-127 one edge, 127 the other, 0 the tip).
    pub normal: [i8; 4],
    /// rgb tint around 128 (the shader doubles it), a position along the blade (0 root, 1 tip).
    pub colour: [u8; 4],
}

pub const LEVELS: usize = 3;
/// Clumps per square metre at each level.
pub const DENSITY: [f32; LEVELS] = [28.0, 14.0, 7.0];
/// Blade width at each level against Godot's blade: thin tapered blades near, a little wider at
/// the coarser levels so the coverage holds as the density drops (director, 2026-11-23: the
/// blades read several centimetres wide at Godot's width).
const WIDEN: [f32; LEVELS] = [0.55, 0.80, 1.10];
/// Segments of a long and of a short blade at each level.
const SEGMENTS: [(usize, usize); LEVELS] = [(3, 1), (2, 1), (1, 1)];
pub const CHUNK: f32 = 8.0;

pub struct Chunk {
    pub lo: Vec3,
    pub hi: Vec3,
    /// Index ranges of the three levels.
    pub ranges: [Range<u32>; LEVELS],
}

#[derive(Default)]
pub struct Grass {
    pub vertices: Vec<GrassVertex>,
    pub indices: Vec<u32>,
    pub chunks: Vec<Chunk>,
    /// Clumps at full density, and the triangles if every chunk were drawn at full density.
    pub clumps: usize,
    pub full_triangles: usize,
}

impl Grass {
    pub fn append(&mut self, other: Grass) {
        let (v0, i0) = (self.vertices.len() as u32, self.indices.len() as u32);
        self.vertices.extend_from_slice(&other.vertices);
        self.indices.extend(other.indices.iter().map(|i| i + v0));
        for chunk in other.chunks {
            self.chunks.push(Chunk { lo: chunk.lo, hi: chunk.hi, ranges: chunk.ranges.map(|r| r.start + i0..r.end + i0) });
        }
        self.clumps += other.clumps;
        self.full_triangles += other.full_triangles;
    }
}

/// Godot's world hash (grass_field.gd `_hash`).
fn ghash(x: f32, y: f32, salt: f32) -> f32 {
    let v = (x * 127.1 + y * 311.7 + salt * 74.7).sin() * 43758.5453;
    v - v.floor()
}

/// Godot's `_organic_drift`: a soft world field that gives neighbouring roots a shared stature.
fn organic_drift(x: f32, z: f32) -> f32 {
    let wx = x + (z * 0.52).sin() * 0.48;
    let wz = z + (x * 0.46).cos() * 0.48;
    let d1 = (wx * 0.78 + wz * 0.51 + 1.3).sin() * (wz * 0.69 - wx * 0.43 + 0.7).cos();
    let d2 = (wx * 1.63 - wz * 1.19 + 4.1).sin() * (wz * 1.41 + wx * 0.97 + 2.6).cos();
    (0.5 + 0.34 * d1 + 0.18 * d2).clamp(0.0, 1.0)
}

/// One of the seven blades of the clump (the same seven for every clump, as in Godot).
struct Blade {
    angle: f32,
    plume: bool,
    height: f32,
    lean: f32,
    width: f32,
    radius: f32,
    tone: f32,
}

fn blades() -> Vec<Blade> {
    (0..7)
        .map(|b| {
            let bf = b as f32;
            let plume = b < 3;
            let lerp = |a: f32, c: f32, t: f32| a + (c - a) * t;
            Blade {
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

/// Where one clump stands and how.
#[derive(Clone, Copy)]
struct Site {
    root: Vec3,
    /// Rotation from the clump's own frame (yaw included) to the world.
    turn: Quat,
    /// The same for the shading normal, which follows only part of an outward tilt so the
    /// fringe does not go dark against the sky.
    shade: Quat,
    scale: f32,
    h_scale: f32,
    tint: Vec3,
    /// Bit 0: in level 1, bit 1: in level 2.
    levels: u8,
}

fn snorm(v: f32) -> i8 {
    (v.clamp(-1.0, 1.0) * 127.0).round() as i8
}

fn emit_clump(out_v: &mut Vec<GrassVertex>, out_i: &mut Vec<u32>, site: &Site, level: usize, shapes: &[Blade], origin: Vec3) -> usize {
    let mut triangles = 0;
    for blade in shapes {
        let segments = if blade.plume { SEGMENTS[level].0 } else { SEGMENTS[level].1 };
        let width = blade.width * WIDEN[level];
        let dir = Vec3::new(blade.angle.cos(), 0.0, blade.angle.sin());
        let side = Vec3::new(-dir.z, 0.0, dir.x);
        let root = dir * blade.radius;
        let tone = 0.94 + 0.12 * blade.tone;
        let tint = (site.tint * tone * 0.5 * 255.0).clamp(Vec3::ZERO, Vec3::splat(255.0));
        let first = out_v.len() as u32;
        for i in 0..=segments {
            let t = i as f32 / segments as f32;
            let centre = root + dir * blade.lean * t.powf(1.35) + Vec3::Y * blade.height * (t * std::f32::consts::PI * 0.68).sin();
            let w = width * (1.0 - t * 0.985).powf(0.72);
            let sides: &[f32] = if i < segments { &[-1.0, 1.0] } else { &[0.0] };
            for &across in sides {
                let local = centre + side * (w * across);
                let local = Vec3::new(local.x * site.scale, local.y * site.h_scale, local.z * site.scale);
                let pos = site.root + site.turn * local + origin;
                // Mostly up, so the field shades as one soft surface; a little of the blade's curl.
                let curl = (Vec3::Y + dir * (0.10 + t * 0.70) + side * (across * 0.42)).normalize();
                let n = site.shade * Vec3::new(curl.x * 0.15, curl.y.max(0.95), curl.z * 0.15).normalize();
                out_v.push(GrassVertex {
                    pos: pos.to_array(),
                    normal: [snorm(n.x), snorm(n.y), snorm(n.z), snorm(across)],
                    colour: [tint.x as u8, tint.y as u8, tint.z as u8, (t * 255.0).round() as u8],
                });
            }
        }
        for i in 0..segments {
            let (l0, r0) = (first + 2 * i as u32, first + 2 * i as u32 + 1);
            if i + 1 < segments {
                let (l1, r1) = (l0 + 2, r0 + 2);
                out_i.extend_from_slice(&[l0, r0, r1, l0, r1, l1]);
                triangles += 2;
            } else {
                out_i.extend_from_slice(&[l0, r0, l0 + 2]);
                triangles += 1;
            }
        }
    }
    triangles
}

/// The lawn's soft large-scale tone: patches 3 to 6 m across, about plus or minus 4% in value,
/// shifting a little from yellow-green to green. A multiplier on the display colour, shared by
/// the blades and the ground under them.
pub fn lawn_tone(p: Vec2, seed: u32) -> Vec3 {
    let v = (vnoise(p.x * 0.21, p.y * 0.21, seed ^ 31) * 0.65 + vnoise(p.x * 0.37 + 5.1, p.y * 0.37 - 2.3, seed ^ 37) * 0.35 - 0.5) * 2.0;
    let v = v.clamp(-1.0, 1.0);
    Vec3::new(1.0 + 0.060 * v, 1.0 + 0.035 * v, 1.0 - 0.005 * v)
}

/// The rim of the top surface (segments on the outline), as `field::build_top` returns it.
pub type Rim = [(Vec3, Vec3)];

/// Builds the field for one island in its own coordinates, moved by `origin`.
/// `clear` holds circles (centre, radius) the blades keep out of.
pub fn build(field: &Field, rim: &Rim, clear: &[(Vec2, f32)], seed: u32, origin: Vec3) -> Grass {
    let shapes = blades();
    let spacing = 1.0 / DENSITY[0].sqrt();
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
    let water_surface = |p: Vec2| -> Option<f32> {
        let toward = field.gradient(&field.wet, p, STEP).normalize_or_zero();
        field.water_at(p).or_else(|| field.water_at(p + toward * 0.6)).or_else(|| field.water_at(p + toward * 1.2)).map(|level| level - crate::water::SINK)
    };
    let mut sites: BTreeMap<(i32, i32), Vec<Site>> = BTreeMap::new();
    let place = |root: Vec3, up: Vec3, scale: f32, h_scale: f32, levels: u8, salt: f32, accent: Vec3, sites: &mut BTreeMap<(i32, i32), Vec<Site>>| {
        let p = Vec2::new(root.x, root.z);
        let yaw = ghash(p.x * 2.13 + p.y * 0.71 + salt, p.y * 1.93 - p.x * 0.83, 4.0) * std::f32::consts::TAU;
        let turn = Quat::from_rotation_arc(Vec3::Y, up) * Quat::from_rotation_y(yaw);
        let shade = Quat::from_rotation_arc(Vec3::Y, Vec3::Y.lerp(up, 0.35).normalize()) * Quat::from_rotation_y(yaw);
        // The lawn's large soft tone patches (shared with the ground under the blades) and a very
        // small per-clump value, so the field reads calm.
        let fine = ghash(p.x * 1.7 + p.y * 0.5, p.x * 2.3, 5.0) - 0.5;
        let tint = lawn_tone(p, seed) * (1.0 + 0.025 * fine) * accent;
        let key = ((p.x / CHUNK).floor() as i32, (p.y / CHUNK).floor() as i32);
        sites.entry(key).or_default().push(Site { root, turn, shade, scale, h_scale, tint, levels });
    };

    // The field: a jittered lattice at the full density, world anchored.
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
            let g = field.gradient(&field.height, p, STEP);
            let ground_n = Vec3::new(-g.x, 1.0, -g.y).normalize();
            if ground_n.y < 0.62 {
                continue; // cut rock of a terrace step
            }
            let mut keep = 1.0;
            let wet = field.sample(&field.wet, p);
            if wet > 0.02 {
                if let Some(surface) = water_surface(p) {
                    if h < surface + 0.05 || (h - surface).abs() < 0.12 {
                        continue; // under water, or on the pale bank at the waterline
                    }
                }
                keep *= 1.0 - 0.65 * smoothstep(0.03, 0.45, wet);
            }
            let clear_k = clearance(p);
            if clear_k <= 0.0 {
                continue;
            }
            if hash2(i, j, seed ^ 203) > keep {
                continue;
            }
            // Tip outward near the outline and at the top of a terrace step.
            let mut up = Vec3::Y.lerp(ground_n, 0.5).normalize();
            let mut lift: f32 = 1.0;
            let gl = field.gradient(&field.land1, p, STEP);
            let edge = if gl.length() > 1e-3 { (land - 0.5) / gl.length() } else { 9.0 };
            let mut tilt = 0.0;
            let mut toward = Vec2::ZERO;
            if edge < 0.5 {
                let k = 1.0 - edge / 0.5;
                tilt = 0.60 * k.powf(1.2);
                toward = -gl.normalize();
                lift = 1.0 + 0.15 * k;
            }
            let gh = field.gradient(&field.height, p, 0.35);
            if gh.length() > 0.4 {
                let down = -gh.normalize();
                let drop = h - field.height_at(p + down * 0.45);
                if drop > 0.22 {
                    let k = smoothstep(0.22, 0.7, drop);
                    if 0.6 * k > tilt {
                        tilt = 0.6 * k;
                        toward = down;
                    }
                    lift = lift.max(1.0 + 0.15 * k);
                }
            }
            if tilt > 0.0 {
                up = (up * tilt.cos() + Vec3::new(toward.x, 0.0, toward.y) * tilt.sin()).normalize();
            }
            let drift = organic_drift(p.x * 2.1 + 1.3, p.y * 2.1 - 2.7);
            let tuft = smoothstep(0.46, 0.80, drift).powf(1.8);
            let lerp = |a: f32, b: f32, t: f32| a + (b - a) * t;
            let thin = lerp(0.55, 1.0, clear_k) * lerp(0.75, 1.0, keep);
            let mut scale = lerp(0.92, 1.08, ghash(p.y * 1.7 + p.x * 0.5, p.x * 2.3, 5.0)) * lerp(0.96, 1.08, tuft) * thin;
            let mut h_scale = lerp(0.86, 1.06, tuft) * lerp(0.94, 1.06, ghash(p.x * 1.9, p.y * 2.1 + p.x * 0.3, 6.0)) * thin * lift;
            // Levels 1 and 2 keep an even half and quarter of the lattice.
            let mut levels = (((i + j) & 1 == 0) as u8) | ((((i & 1) == 0 && (j & 1) == 0) as u8) << 1);
            // A sparse layer of distinct taller tufts, about one per 1.5 square metres: half as tall
            // again to twice, a little lighter and yellower, kept at every density level.
            let mut accent = Vec3::ONE;
            if hash2(i, j, seed ^ 209) < 1.0 / (DENSITY[0] * 1.5) && clear_k > 0.9 && tilt == 0.0 {
                h_scale *= 1.5 + 0.5 * hash2(i, j, seed ^ 210);
                scale *= 1.15;
                accent = Vec3::new(1.07, 1.06, 0.93);
                levels = 3;
            }
            place(Vec3::new(p.x, h - 0.015, p.y), up, scale, h_scale, levels, 0.0, accent, &mut sites);
        }
    }

    // The fringe: a short, soft row rooted on the lip itself, overhanging it by about 0.15 m at most.
    let mut counter = 0i32;
    for &(a, b) in rim {
        let length = (b - a).length();
        let want = length * 9.0;
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
            if field.sample(&field.wet, p) > 0.10 || clearance(p) < 0.5 {
                continue;
            }
            let inward = field.gradient(&field.land1, p, STEP).normalize_or_zero();
            let out = Vec3::new(-inward.x, 0.0, -inward.y);
            let tilt: f32 = 0.62 + 0.16 * hash2(counter, 8, seed ^ 206);
            let up = (Vec3::Y * tilt.cos() + out * tilt.sin()).normalize();
            let root = at + out * 0.02 - Vec3::Y * 0.05;
            let scale = 0.62 + 0.10 * hash2(counter, 9, seed ^ 207);
            let h_scale = 0.68 + 0.18 * hash2(counter, 10, seed ^ 208);
            let levels = ((counter & 1 == 0) as u8) | (((counter & 3 == 0) as u8) << 1);
            place(root, up, scale, h_scale, levels, 17.0, Vec3::ONE, &mut sites);
        }
    }

    // Bake each chunk at the three levels.
    let mut grass = Grass::default();
    for (_, list) in sites {
        let (mut lo3, mut hi3) = (Vec3::splat(f32::MAX), Vec3::splat(f32::MIN));
        for site in &list {
            lo3 = lo3.min(site.root + origin - Vec3::splat(0.6));
            hi3 = hi3.max(site.root + origin + Vec3::splat(0.6));
        }
        let mut ranges: [Range<u32>; LEVELS] = [0..0, 0..0, 0..0];
        for (level, range) in ranges.iter_mut().enumerate() {
            let start = grass.indices.len() as u32;
            for site in &list {
                let member = level == 0 || site.levels & (1 << (level - 1)) != 0;
                if member {
                    let tris = emit_clump(&mut grass.vertices, &mut grass.indices, site, level, &shapes, origin);
                    if level == 0 {
                        grass.clumps += 1;
                        grass.full_triangles += tris;
                    }
                }
            }
            *range = start..grass.indices.len() as u32;
        }
        grass.chunks.push(Chunk { lo: lo3, hi: hi3, ranges });
    }
    grass
}
