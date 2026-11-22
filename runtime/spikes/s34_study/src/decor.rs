//! What stands on the island when no exported scene is loaded: trees as masses, rocks,
//! stepping stones, bamboo and lily pads. All procedural, all baked like the rest. Each
//! reports where the grass keeps clear of it. (The rim tufts were replaced by grass.rs.)
use glam::{Vec2, Vec3};

use crate::field::{Cells, Field};
use crate::mesh::{hash2, icosphere, Family, Mesh, Paint, Rng};

#[derive(Clone, Copy)]
pub struct DecorColours {
    pub bark: Vec3,
    pub pine_top: Vec3,
    pub pine_under: Vec3,
    pub leaf_top: Vec3,
    pub leaf_under: Vec3,
    pub rock: Vec3,
    pub bamboo: Vec3,
    pub pad: Vec3,
}

impl Default for DecorColours {
    fn default() -> DecorColours {
        DecorColours {
            bark: Vec3::new(0.34, 0.26, 0.21),
            pine_top: Vec3::new(0.33, 0.48, 0.30),
            pine_under: Vec3::new(0.19, 0.31, 0.24),
            leaf_top: Vec3::new(0.47, 0.60, 0.31),
            leaf_under: Vec3::new(0.26, 0.40, 0.26),
            rock: Vec3::new(0.82, 0.78, 0.69),
            bamboo: Vec3::new(0.42, 0.55, 0.33),
            pad: Vec3::new(0.38, 0.54, 0.33),
        }
    }
}

/// A tube along a path with a radius per point; smooth shading.
fn tube(mesh: &mut Mesh, path: &[Vec3], radius: &[f32], sides: usize, colour: Vec3, id: u8) {
    let ring = |k: usize| -> Vec<(Vec3, Vec3)> {
        let dir = (path[(k + 1).min(path.len() - 1)] - path[k.saturating_sub(1)]).normalize_or_zero();
        let side = dir.cross(Vec3::X).normalize_or_zero();
        let side = if side == Vec3::ZERO { Vec3::Z } else { side };
        let up = side.cross(dir).normalize_or_zero();
        (0..sides)
            .map(|s| {
                let angle = s as f32 / sides as f32 * std::f32::consts::TAU;
                let n = side * angle.cos() + up * angle.sin();
                (path[k] + n * radius[k], n)
            })
            .collect()
    };
    let paint = Paint::new(Family::Wood).sky(0.7).line(0.9).strokes(0.8).id(id);
    for k in 0..path.len() - 1 {
        let (a, b) = (ring(k), ring(k + 1));
        for s in 0..sides {
            let s2 = (s + 1) % sides;
            mesh.tri_full([a[s].0, a[s2].0, b[s2].0], [a[s].1, a[s2].1, b[s2].1], [colour; 3], [paint; 3]);
            mesh.tri_full([a[s].0, b[s2].0, b[s].0], [a[s].1, b[s2].1, b[s].1], [colour; 3], [paint; 3]);
        }
    }
}

/// A foliage mass: a lumpy flattened ball with soft, rounded shading normals,
/// lighter on top and dark underneath.
#[allow(clippy::too_many_arguments)]
fn clump(mesh: &mut Mesh, sphere: &[[Vec3; 3]], centre: Vec3, size: Vec3, lobes: f32, phase: f32, top: Vec3, under: Vec3, id: u8, salt: u32) {
    let shape = |v: Vec3| -> (Vec3, Vec3, Vec3, Paint) {
        let around = v.z.atan2(v.x);
        let scallop = 1.0 + 0.16 * (around * lobes + phase).sin() + 0.10 * (hash2((v.x * 4.0) as i32 + salt as i32, (v.z * 4.0 + v.y * 2.0) as i32, salt) - 0.5);
        let squash = if v.y < 0.0 { 0.55 } else { 1.0 };
        let p = centre + Vec3::new(v.x * size.x * scallop, v.y * size.y * squash, v.z * size.z * scallop);
        let n = (Vec3::new(v.x / size.x, v.y / size.y, v.z / size.z).normalize_or_zero() + Vec3::Y * 0.30).normalize();
        let lift = (v.y * 0.5 + 0.5).clamp(0.0, 1.0);
        let colour = under.lerp(top, lift * lift * (3.0 - 2.0 * lift));
        (p, n, colour, Paint::new(Family::Leaf).sky(0.45 + 0.55 * lift).line(0.85).strokes(0.7).id(id))
    };
    for tri in sphere {
        let (a, b, c) = (shape(tri[0]), shape(tri[1]), shape(tri[2]));
        mesh.tri_full([a.0, b.0, c.0], [a.1, b.1, c.1], [a.2, b.2, c.2], [a.3, b.3, c.3]);
    }
}

/// A pruned pine: a leaning, bending trunk and tiers of flat foliage pads.
pub fn pine(mesh: &mut Mesh, foot: Vec3, height: f32, lean: Vec2, colours: &DecorColours, rng: &mut Rng, id: u8) {
    let sphere = icosphere(2);
    let lean3 = Vec3::new(lean.x, 0.0, lean.y);
    let side3 = Vec3::new(-lean.y, 0.0, lean.x);
    let bend = rng.range(0.5, 0.9);
    let points = 8;
    let spine = |t: f32| -> Vec3 { foot + Vec3::Y * (height * t) + lean3 * (height * 0.34 * (t * 2.6).sin() * bend) + side3 * (height * 0.10 * (t * 5.2 + 0.6).sin()) };
    let path: Vec<Vec3> = (0..=points).map(|k| spine(k as f32 / points as f32)).collect();
    let radius: Vec<f32> = (0..=points).map(|k| 0.20 * height / 4.5 * (1.0 - 0.72 * k as f32 / points as f32) + 0.03).collect();
    tube(mesh, &path, &radius, 7, colours.bark, id);
    let tiers = [(0.40, 1.0), (0.52, 0.96), (0.64, 0.88), (0.75, 0.80), (0.85, 0.68), (0.94, 0.56)];
    for (index, (t, scale)) in tiers.iter().enumerate() {
        let from = spine(*t);
        let sign = if index % 2 == 0 { 1.0 } else { -1.0 };
        let dir = (side3 * sign * rng.range(0.6, 1.0) + lean3 * rng.range(-0.7, 0.8)).normalize_or_zero();
        let reach = height * 0.30 * scale * rng.range(0.85, 1.15);
        let end = from + dir * reach + Vec3::Y * (height * 0.05);
        tube(mesh, &[from, from.lerp(end, 0.5) + Vec3::Y * 0.08, end], &[0.08, 0.06, 0.04], 5, colours.bark, id);
        let size = Vec3::new(height * 0.33 * scale * rng.range(0.9, 1.15), height * 0.085 * rng.range(0.9, 1.2), height * 0.26 * scale * rng.range(0.9, 1.15));
        clump(mesh, &sphere, end + Vec3::Y * size.y * 0.35, size, rng.range(5.0, 8.5).round(), rng.range(0.0, 6.0), colours.pine_top, colours.pine_under, id.wrapping_add(1 + index as u8), id as u32 * 13 + index as u32);
    }
    let crown = spine(1.0);
    let size = Vec3::new(height * 0.24, height * 0.085, height * 0.20);
    clump(mesh, &sphere, crown + Vec3::Y * size.y * 0.3, size, 6.0, rng.range(0.0, 6.0), colours.pine_top, colours.pine_under, id.wrapping_add(8), id as u32 * 13 + 9);
}

/// A broad-leaved tree: a forked trunk and a dome of overlapping leaf masses.
pub fn broadleaf(mesh: &mut Mesh, foot: Vec3, height: f32, lean: Vec2, colours: &DecorColours, rng: &mut Rng, id: u8) {
    let sphere = icosphere(2);
    let lean3 = Vec3::new(lean.x, 0.0, lean.y);
    let fork = foot + Vec3::Y * (height * 0.42) + lean3 * (height * 0.10);
    tube(mesh, &[foot, foot + Vec3::Y * (height * 0.2) + lean3 * (height * 0.03), fork], &[0.30 * height / 6.0 + 0.08, 0.24 * height / 6.0 + 0.06, 0.18 * height / 6.0 + 0.05], 8, colours.bark, id);
    let crown = fork + Vec3::Y * (height * 0.26) + lean3 * (height * 0.06);
    let spread = height * 0.40;
    // A low wide ring, a tighter ring above it and a cap: many modest masses, not a few balls.
    let masses = 19;
    for k in 0..masses {
        let (ring, lift, count, first) = if k < 10 { (1.0, 0.0, 10.0, 0) } else if k < 16 { (0.58, 0.17, 6.0, 10) } else { (0.20, 0.30, 3.0, 16) };
        let angle = (k - first) as f32 / count * std::f32::consts::TAU + rng.range(-0.25, 0.25) + ring * 2.0;
        let centre = crown + Vec3::new(angle.cos() * spread * ring * rng.range(0.82, 1.05), height * (lift + rng.range(-0.05, 0.05)), angle.sin() * spread * ring * rng.range(0.82, 1.05));
        if k < 10 && k % 3 == 1 {
            tube(mesh, &[fork, fork.lerp(centre, 0.55) + Vec3::Y * 0.1, centre], &[0.11, 0.07, 0.04], 5, colours.bark, id);
        }
        let r = height * rng.range(0.135, 0.19) * (1.0 + 0.15 * (1.0 - ring));
        clump(mesh, &sphere, centre, Vec3::new(r * 1.12, r * 0.74, r * 1.12), rng.range(5.0, 8.0).round(), rng.range(0.0, 6.0), colours.leaf_top, colours.leaf_under, id.wrapping_add(1 + k as u8), id as u32 * 17 + k as u32);
    }
}

/// A faceted boulder, slightly sunk into the ground.
pub fn rock(mesh: &mut Mesh, at: Vec3, size: Vec3, colours: &DecorColours, rng: &mut Rng, id: u8) {
    let sphere = icosphere(1);
    let salt = (rng.next() * 9973.0) as i32;
    let tone = rng.range(-0.04, 0.04);
    let shape = |v: Vec3| -> Vec3 {
        let wobble = 0.78 + 0.44 * hash2((v.x * 2.4).round() as i32 + salt, (v.y * 3.1 + v.z * 5.7).round() as i32, 91);
        let y = if v.y < -0.25 { -0.25 } else { v.y };
        at + Vec3::new(v.x * size.x * wobble, y * size.y * wobble + size.y * 0.2, v.z * size.z * wobble)
    };
    for tri in &sphere {
        let p = [shape(tri[0]), shape(tri[1]), shape(tri[2])];
        let n = (p[1] - p[0]).cross(p[2] - p[0]).normalize_or_zero();
        let sky = 0.6 + 0.4 * (n.y * 0.5 + 0.5);
        mesh.tri_full(p, [n; 3], [colours.rock + Vec3::splat(tone); 3], [Paint::new(Family::Stone).sky(sky).line(1.0).strokes(0.9).id(id); 3]);
    }
}

fn bamboo(mesh: &mut Mesh, at: Vec3, colours: &DecorColours, rng: &mut Rng, id: u8) {
    for stalk in 0..9 {
        let foot = at + Vec3::new(rng.range(-0.55, 0.55), 0.0, rng.range(-0.45, 0.45));
        let height = rng.range(2.4, 3.6);
        let sway = Vec3::new(rng.range(-0.25, 0.25), 0.0, rng.range(-0.25, 0.25));
        let path = [foot, foot + Vec3::Y * height * 0.5 + sway * 0.3, foot + Vec3::Y * height + sway];
        tube(mesh, &path, &[0.035, 0.03, 0.02], 4, colours.bamboo * 0.9, id);
        for leaf in 0..7 {
            let t = rng.range(0.45, 1.0);
            let base = path[1].lerp(path[2], (t - 0.5) * 2.0);
            let dir = Vec3::new(rng.range(-1.0, 1.0), rng.range(-0.5, 0.1), rng.range(-1.0, 1.0)).normalize_or_zero();
            let side = dir.cross(Vec3::Y).normalize_or_zero() * 0.045;
            let tip = base + dir * rng.range(0.28, 0.46);
            let colour = colours.bamboo * rng.range(0.9, 1.12);
            let paint = Paint::new(Family::Leaf).sky(0.9).line(0.3).id(id.wrapping_add(1 + (stalk + leaf) as u8 % 5));
            mesh.tri_full([base, base.lerp(tip, 0.45) + side, tip], [Vec3::Y; 3], [colour; 3], [paint; 3]);
            mesh.tri_full([base, tip, base.lerp(tip, 0.45) - side], [Vec3::Y; 3], [colour; 3], [paint; 3]);
        }
    }
}

fn lily_pad(mesh: &mut Mesh, at: Vec3, radius: f32, colours: &DecorColours, rng: &mut Rng, id: u8) {
    let sides = 9;
    let gap = rng.range(0.0, std::f32::consts::TAU);
    let colour = colours.pad * rng.range(0.92, 1.08);
    let paint = Paint::new(Family::Leaf).sky(1.0).line(0.6).id(id);
    for k in 0..sides - 1 {
        let (a0, a1) = (gap + k as f32 / sides as f32 * std::f32::consts::TAU, gap + (k + 1) as f32 / sides as f32 * std::f32::consts::TAU);
        mesh.tri_full([at, at + Vec3::new(a1.cos(), 0.0, a1.sin()) * radius, at + Vec3::new(a0.cos(), 0.0, a0.sin()) * radius], [Vec3::Y; 3], [colour; 3], [paint; 3]);
    }
}

/// Nearest dry land point to `want`, searching outward; None if the island has none nearby.
fn dry_spot(cells: &Cells, field: &Field, want: Vec2) -> Option<Vec2> {
    for ring in 0..40 {
        let radius = ring as f32 * 0.5;
        let steps = (ring * 6).max(1);
        for s in 0..steps {
            let angle = s as f32 / steps as f32 * std::f32::consts::TAU;
            let p = want + Vec2::new(angle.cos(), angle.sin()) * radius;
            let key = (p.x.floor() as i32, p.y.floor() as i32);
            if let Some(cell) = cells.get(&key) {
                if cell.water.is_none() && field.sample(&field.land1, p) > 0.93 && field.sample(&field.wet, p) < 0.05 {
                    return Some(p);
                }
            }
        }
    }
    None
}

/// The courtyard of the review layouts: a main group at the rear left, a single
/// accent tree, a pair at the right end, a stone path to the upper pond, rocks
/// by the water. Positions adapt to the nearest dry ground on other layouts.
pub fn courtyard(cells: &Cells, field: &Field, colours: &DecorColours, seed: u32, clear: &mut Vec<(Vec2, f32)>) -> Mesh {
    let mut mesh = Mesh::default();
    let mut rng = Rng::new(seed, 5);
    let ground = |p: Vec2| Vec3::new(p.x, field.height_at(p), p.y);
    let mut id: u8 = 60;
    let mut next_id = || {
        id = id.wrapping_add(11);
        id
    };
    let trees: [(&str, Vec2, f32, Vec2); 6] = [
        ("leaf", Vec2::new(-14.2, -7.2), 7.0, Vec2::new(0.6, 0.3)),
        ("pine", Vec2::new(-10.0, -9.2), 5.2, Vec2::new(-0.7, 0.5)),
        ("pine", Vec2::new(-1.6, -8.0), 4.8, Vec2::new(0.8, 0.4)),
        ("leaf", Vec2::new(13.2, 1.6), 6.2, Vec2::new(-0.5, 0.5)),
        ("pine", Vec2::new(10.4, -1.4), 3.9, Vec2::new(0.6, -0.6)),
        ("pine", Vec2::new(-17.5, 1.0), 4.2, Vec2::new(0.4, 0.8)),
    ];
    for (kind, want, height, lean) in trees {
        let Some(p) = dry_spot(cells, field, want) else { continue };
        let lean = lean.normalize();
        if kind == "pine" {
            clear.push((p, 0.30));
            pine(&mut mesh, ground(p), height, lean, colours, &mut rng, next_id());
        } else {
            clear.push((p, 0.35));
            broadleaf(&mut mesh, ground(p), height, lean, colours, &mut rng, next_id());
        }
    }
    if let Some(p) = dry_spot(cells, field, Vec2::new(-5.6, -7.4)) {
        clear.push((p, 0.75));
        bamboo(&mut mesh, ground(p), colours, &mut rng, next_id());
    }
    // A standing stone as the group's accent.
    if let Some(p) = dry_spot(cells, field, Vec2::new(-7.6, -6.0)) {
        clear.push((p, 0.75));
        rock(&mut mesh, ground(p) + Vec3::Y * 0.5, Vec3::new(0.42, 1.25, 0.36), colours, &mut rng, next_id());
        rock(&mut mesh, ground(p) + Vec3::new(0.35, 0.0, 0.25), Vec3::new(0.45, 0.3, 0.4), colours, &mut rng, next_id());
    }
    // Stepping stones from the stone down to the upper pond.
    for k in 0..9 {
        let t = k as f32 / 8.0;
        let want = Vec2::new(-7.4, -5.1).lerp(Vec2::new(-6.6, -2.3), t) + Vec2::new((t * 3.4).sin() * 0.9, 0.0);
        if let Some(p) = dry_spot(cells, field, want) {
            if (p - want).length() < 0.8 {
                clear.push((p, 0.42));
                rock(&mut mesh, ground(p) - Vec3::Y * 0.02, Vec3::new(rng.range(0.30, 0.42), 0.07, rng.range(0.24, 0.34)), colours, &mut rng, next_id());
            }
        }
    }
    // Rocks by the water and on the lawn.
    let rocks = [(-8.6, 1.6, 0.55), (1.9, -1.7, 0.5), (2.6, 2.0, 0.6), (3.4, 5.6, 0.45), (12.0, 5.4, 0.55), (-11.0, 3.0, 0.4), (-15.2, -1.2, 0.6), (6.5, -1.6, 0.42), (0.2, 3.2, 0.38), (-3.0, 3.9, 0.36)];
    for (x, z, size) in rocks {
        if let Some(p) = dry_spot(cells, field, Vec2::new(x, z)) {
            clear.push((p, size * 1.4));
            rock(&mut mesh, ground(p), Vec3::new(size * rng.range(0.9, 1.3), size * rng.range(0.55, 0.8), size * rng.range(0.8, 1.2)), colours, &mut rng, next_id());
            if rng.next() < 0.5 {
                rock(&mut mesh, ground(p) + Vec3::new(size * 1.1, 0.0, size * 0.5), Vec3::splat(size * 0.5), colours, &mut rng, next_id());
            }
        }
    }
    // Lily pads on the ponds.
    let mut water_cells: Vec<(i32, i32)> = cells.iter().filter(|(_, c)| c.water.is_some()).map(|(k, _)| *k).collect();
    water_cells.sort();
    for &(x, z) in &water_cells {
        if hash2(x, z, seed ^ 7) < 0.16 {
            let level = cells[&(x, z)].water.unwrap() - crate::water::SINK + 0.012;
            let all_wet = (-1..=1).all(|dz| (-1..=1).all(|dx| cells.get(&(x + dx, z + dz)).map_or(false, |c| c.water.is_some())));
            if all_wet {
                let at = Vec3::new(x as f32 + rng.range(0.2, 0.8), level, z as f32 + rng.range(0.2, 0.8));
                lily_pad(&mut mesh, at, rng.range(0.16, 0.26), colours, &mut rng, next_id());
                if rng.next() < 0.6 {
                    lily_pad(&mut mesh, at + Vec3::new(0.38, 0.0, 0.2), rng.range(0.10, 0.17), colours, &mut rng, next_id());
                }
            }
        }
    }
    mesh
}

/// Procedural scatter for islands without an authored courtyard.
pub fn scatter(cells: &Cells, field: &Field, colours: &DecorColours, seed: u32, clear: &mut Vec<(Vec2, f32)>) -> Mesh {
    let mut mesh = Mesh::default();
    let mut rng = Rng::new(seed, 6);
    let mut land: Vec<(i32, i32)> = cells.iter().filter(|(_, c)| c.water.is_none()).map(|(k, _)| *k).collect();
    land.sort();
    let ground = |p: Vec2| Vec3::new(p.x, field.height_at(p), p.y);
    let mut id: u8 = 60;
    let groups = (land.len() / 130).max(2);
    for _ in 0..groups {
        let cell = land[(rng.next() * land.len() as f32) as usize % land.len()];
        let centre = Vec2::new(cell.0 as f32 + 0.5, cell.1 as f32 + 0.5);
        let members = 1 + (rng.next() * 3.0) as usize;
        for m in 0..members {
            let want = centre + Vec2::new(rng.range(-3.5, 3.5), rng.range(-3.5, 3.5)) * if m == 0 { 0.0 } else { 1.0 };
            let Some(p) = dry_spot(cells, field, want) else { continue };
            id = id.wrapping_add(11);
            let lean = Vec2::new(rng.range(-1.0, 1.0), rng.range(-1.0, 1.0)).normalize_or_zero();
            if rng.next() < 0.6 {
                clear.push((p, 0.30));
                pine(&mut mesh, ground(p), rng.range(3.2, 4.8), lean, colours, &mut rng, id);
            } else {
                clear.push((p, 0.35));
                broadleaf(&mut mesh, ground(p), rng.range(4.6, 6.4), lean, colours, &mut rng, id);
            }
        }
        for _ in 0..2 {
            if let Some(p) = dry_spot(cells, field, centre + Vec2::new(rng.range(-5.0, 5.0), rng.range(-5.0, 5.0))) {
                id = id.wrapping_add(7);
                let size = rng.range(0.35, 0.7);
                clear.push((p, size * 1.3));
                rock(&mut mesh, ground(p), Vec3::new(size * 1.1, size * 0.7, size), colours, &mut rng, id);
            }
        }
    }
    mesh
}
