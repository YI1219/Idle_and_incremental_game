//! Pond surfaces, falls and spray as live geometry. In the study the cells' water
//! flags stand in for basins filled by a spring.
//!
//! The cell edges where a pond spills into lower water or off the island are joined into
//! junctions (shared corners, same levels). Each junction pours through one notch: a sheet
//! `min(junction width, SHEET_MAX)` wide, centred on the junction and placed on the relaxed wall
//! (field.rs) or the outline. Beside the notch the pond is held by a narrow bank (field.rs `rim`),
//! so a wide junction keeps its water. Pond surfaces are the water cells (plus the cells round
//! them, under the banks), clipped where a wall that holds the pond, or the outline, passes.
use std::collections::{BTreeMap, HashSet};

use glam::{Vec2, Vec3};

use crate::field::{Cells, Field};

/// Ponds sit this far below their nominal level so a bank shows.
pub const SINK: f32 = 0.14;
/// Outer falls drop to this height, well inside the cloud sea.
const ABYSS: f32 = -17.0;
/// The widest a fall's sheet gets; a wider junction is closed by the bank beside the notch.
pub const SHEET_MAX: f32 = 1.6;

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct WaterVertex {
    pub pos: [f32; 3],
    /// x: 0 pond, 1 fall, 2 upright spray veil, 3 flat foam pool;
    /// falls: y metres across, z metres dropped from the lip, w the sheet's width;
    /// spray: y, z in 0..1 across the quad.
    pub data: [f32; 4],
}

/// Where a pond spills: the middle of its notch, the directions along and out of it, the sheet's
/// width, the junction's width, the surface it leaves, where it lands, the pond's level.
#[derive(Clone, Copy, Debug)]
pub struct Spill {
    pub centre: Vec2,
    pub along: Vec2,
    pub out: Vec2,
    pub width: f32,
    pub junction: f32,
    pub y: f32,
    pub bottom: f32,
    pub level: f32,
    pub outer: bool,
}

/// One cell edge a pond spills over.
#[derive(Clone, Copy)]
struct Edge {
    c0: Vec2,
    c1: Vec2,
    out: Vec2,
    level: f32,
    bottom: f32,
}

/// The junctions of a set of cells, placed on the cell edges (field.rs moves them onto the
/// relaxed walls and the outline).
pub fn junctions(cells: &Cells) -> Vec<Spill> {
    let mut keys: Vec<(i32, i32)> = cells.keys().copied().collect();
    keys.sort();
    let mut edges: Vec<Edge> = Vec::new();
    for &(x, z) in &keys {
        let Some(level) = cells[&(x, z)].water else { continue };
        for (dx, dz) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
            let bottom = match cells.get(&(x + dx, z + dz)) {
                Some(other) => match other.water {
                    Some(lower) if lower < level - 0.2 => lower - SINK,
                    _ => continue,
                },
                None => ABYSS,
            };
            let (c0, c1) = match (dx, dz) {
                (1, 0) => (Vec2::new(x as f32 + 1.0, z as f32 + 1.0), Vec2::new(x as f32 + 1.0, z as f32)),
                (0, 1) => (Vec2::new(x as f32, z as f32 + 1.0), Vec2::new(x as f32 + 1.0, z as f32 + 1.0)),
                (-1, 0) => (Vec2::new(x as f32, z as f32), Vec2::new(x as f32, z as f32 + 1.0)),
                _ => (Vec2::new(x as f32 + 1.0, z as f32), Vec2::new(x as f32, z as f32)),
            };
            edges.push(Edge { c0, c1, out: Vec2::new(dx as f32, dz as f32), level, bottom });
        }
    }
    let n = edges.len();
    let mut group: Vec<usize> = (0..n).collect();
    fn root(group: &mut Vec<usize>, i: usize) -> usize {
        let mut r = i;
        while group[r] != r {
            r = group[r];
        }
        group[i] = r;
        r
    }
    for i in 0..n {
        for j in i + 1..n {
            let (a, b) = (edges[i], edges[j]);
            let share = [a.c0, a.c1].iter().any(|p| (*p - b.c0).length() < 1e-3 || (*p - b.c1).length() < 1e-3);
            if share && (a.level - b.level).abs() < 1e-3 && (a.bottom - b.bottom).abs() < 1e-3 {
                let (ra, rb) = (root(&mut group, i), root(&mut group, j));
                group[ra] = rb;
            }
        }
    }
    let mut groups: BTreeMap<usize, Vec<Edge>> = BTreeMap::new();
    for i in 0..n {
        let r = root(&mut group, i);
        groups.entry(r).or_default().push(edges[i]);
    }
    let mut out = Vec::new();
    for (_, list) in groups {
        let out_dir = list.iter().map(|e| e.out).sum::<Vec2>().normalize_or_zero();
        let along = Vec2::new(-out_dir.y, out_dir.x);
        let corners: Vec<Vec2> = list.iter().flat_map(|e| [e.c0, e.c1]).collect();
        let t_min = corners.iter().map(|p| p.dot(along)).fold(f32::MAX, f32::min);
        let t_max = corners.iter().map(|p| p.dot(along)).fold(f32::MIN, f32::max);
        let o_max = corners.iter().map(|p| p.dot(out_dir)).fold(f32::MIN, f32::max);
        let junction = t_max - t_min;
        out.push(Spill {
            centre: along * ((t_min + t_max) * 0.5) + out_dir * o_max,
            along,
            out: out_dir,
            width: junction.min(SHEET_MAX),
            junction,
            y: list[0].level - SINK,
            bottom: list[0].bottom,
            level: list[0].level,
            outer: list[0].bottom <= ABYSS + 1e-3,
        });
    }
    out
}

/// Sutherland-Hodgman clip of a polygon to where `value` >= 0 (linear between corners).
fn clip(polygon: &[Vec2], value: &dyn Fn(Vec2) -> f32) -> Vec<Vec2> {
    let n = polygon.len();
    let values: Vec<f32> = polygon.iter().map(|p| value(*p)).collect();
    let mut out = Vec::with_capacity(n + 2);
    for k in 0..n {
        let (a, b) = (polygon[k], polygon[(k + 1) % n]);
        let (va, vb) = (values[k], values[(k + 1) % n]);
        if va >= 0.0 {
            out.push(a);
        }
        if (va >= 0.0) != (vb >= 0.0) {
            out.push(a.lerp(b, va / (va - vb)));
        }
    }
    out
}

pub fn build_water(cells: &Cells, field: &Field, origin: Vec3) -> Vec<WaterVertex> {
    let mut out = Vec::new();
    // Spray goes last so it blends over the ponds and falls it sits on.
    let mut spray = Vec::new();
    let mut keys: Vec<(i32, i32)> = cells.keys().copied().collect();
    keys.sort();
    let push = |list: &mut Vec<WaterVertex>, corners: [Vec3; 4], data: [[f32; 4]; 4]| {
        for i in [0, 1, 2, 0, 2, 3] {
            list.push(WaterVertex { pos: (corners[i] + origin).to_array(), data: data[i] });
        }
    };
    let card = |kind: f32| [[kind, 0.0, 0.0, 0.0], [kind, 0.0, 1.0, 0.0], [kind, 1.0, 1.0, 0.0], [kind, 1.0, 0.0, 0.0]];

    // Pond surfaces. A square is kept where the outline and every wall holding this pond allow;
    // squares of lower cells only up to such a wall (where its relaxed contour bulges past the cells).
    let mut done: HashSet<(i32, i32, i32)> = HashSet::new();
    for &(x, z) in &keys {
        let cell = cells[&(x, z)];
        let Some(level) = cell.water else { continue };
        let y = level - SINK;
        let this = |w: Option<f32>| w.is_some_and(|l| (l - level).abs() < 1e-3);
        // At a wall: water on its low side only if that side is this pond; on its high side it is
        // under the ground there or held by the rim. Squares of lower cells keep only what lies on
        // the high side of this pond's own wall.
        let keep = |p: Vec2, own: bool| -> f32 {
            let mut v = (field.sample(&field.land1, p) - 0.5) / 0.89;
            match field.nearest_step(p) {
                Some((i, sd, _)) if field.steps[i].wall() => {
                    let s = field.steps[i];
                    if this(s.low_water) && !this(s.high_water) {
                        if !own {
                            v = -1.0;
                        }
                    } else if s.low < y {
                        v = v.min(sd);
                        if !own && !this(s.high_water) {
                            v = -1.0;
                        }
                    } else if !own {
                        v = -1.0;
                    }
                }
                _ if !own => v = -1.0,
                _ => {}
            }
            v
        };
        let mut squares: Vec<((i32, i32), bool)> = vec![((x, z), true)];
        for (dx, dz) in [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)] {
            let key = (x + dx, z + dz);
            let Some(other) = cells.get(&key) else { continue };
            let higher_water = other.water.is_some_and(|w| w > level + 0.2);
            if (other.water.is_none() || higher_water) && other.h >= level - 0.3 {
                // Reach under the banks.
                squares.push((key, true));
            } else if (dx == 0 || dz == 0) && other.h < cell.h - 1e-3 {
                squares.push((key, false));
            }
        }
        for (key, own) in squares {
            if !done.insert((key.0, key.1, (level * 64.0).round() as i32)) {
                continue;
            }
            let lo = Vec2::new(key.0 as f32, key.1 as f32);
            let probe = [lo, lo + Vec2::X, lo + Vec2::ONE, lo + Vec2::Y, lo + Vec2::splat(0.5)];
            let at = |p: Vec2| Vec3::new(p.x, y, p.y);
            let clear = |p: &Vec2| field.sample(&field.land1, *p) > 0.97 && field.nearest_step(*p).map_or(true, |(i, _, d)| !field.steps[i].wall() || d > 1.0);
            if own && probe.iter().all(clear) {
                push(&mut out, [at(lo), at(lo + Vec2::Y), at(lo + Vec2::ONE), at(lo + Vec2::X)], [[0.0; 4]; 4]);
                continue;
            }
            for sz in 0..4 {
                for sx in 0..4 {
                    let s0 = lo + Vec2::new(sx as f32, sz as f32) * 0.25;
                    let square = [s0, s0 + Vec2::new(0.0, 0.25), s0 + Vec2::splat(0.25), s0 + Vec2::new(0.25, 0.0)];
                    let polygon = clip(&square, &|p| keep(p, own));
                    for k in 1..polygon.len().saturating_sub(1) {
                        for p in [polygon[0], polygon[k], polygon[k + 1]] {
                            out.push(WaterVertex { pos: (at(p) + origin).to_array(), data: [0.0; 4] });
                        }
                    }
                }
            }
        }
    }

    // Falls.
    for s in &field.spills {
        let (y, bottom, width) = (s.y, s.bottom, s.width);
        let drop = y - bottom;
        let reach = 0.30 + 0.16 * drop.sqrt();
        let (along, outd) = (s.along, s.out);
        // Columns across the sheet; the middle of the lip bulges forward a little as the water rolls over.
        let columns = 6;
        let column = |c: usize| -> (Vec2, f32, f32) {
            let u = c as f32 / columns as f32;
            (s.centre + along * ((u - 0.5) * width), u * width, (u * std::f32::consts::PI).sin())
        };
        // Rows: on the pond just behind the lip, the roll over it, then the fall's arc.
        let mut rows: Vec<(f32, f32, f32)> = vec![(-0.12, y + 0.004, -0.05), (0.0, y - 0.006, 0.006), (0.05, y - 0.03, 0.03)];
        let steps = 12;
        for k in 1..=steps {
            let t = k as f32 / steps as f32;
            let fall = 0.03 + (drop - 0.03) * t * t;
            rows.push((0.05 + reach * t + 0.04 * t, y - fall, fall));
        }
        for r in 0..rows.len() - 1 {
            for c in 0..columns {
                let corner = |r: usize, c: usize| {
                    let (base, across, bulge) = column(c);
                    let (o, h, d) = rows[r];
                    let lean = if r >= 1 { 0.035 * bulge } else { 0.0 };
                    let p = base + outd * (o + lean);
                    (Vec3::new(p.x, h, p.y), [1.0, across, d, width])
                };
                let q = [corner(r, c), corner(r + 1, c), corner(r + 1, c + 1), corner(r, c + 1)];
                push(&mut out, [q[0].0, q[1].0, q[2].0, q[3].0], [q[0].1, q[1].1, q[2].1, q[3].1]);
            }
        }

        // Spray. `side` runs along the lip.
        let side = along;
        let c0 = s.centre - along * (width * 0.5);
        let c1 = s.centre + along * (width * 0.5);
        let upright = |a: Vec2, b: Vec2, low: f32, high: f32| [Vec3::new(a.x, low, a.y), Vec3::new(a.x, high, a.y), Vec3::new(b.x, high, b.y), Vec3::new(b.x, low, b.y)];
        if !s.outer {
            // Where the fall meets the lower pond: a soft white foam on the water spreading from the
            // foot, and a low veil of spray over it.
            let foot = 0.05 + reach * 1.04;
            let (a, b) = (c0 + outd * foot - side * 0.35, c1 + outd * foot + side * 0.35);
            push(&mut spray, upright(a, b, bottom - 0.05, bottom + 0.30 * drop.min(1.5) + 0.12), card(2.0));
            let (near, far) = (foot - 0.45, foot + 1.10);
            let (p0, p1, p2, p3) = (c0 - side * 0.45 + outd * near, c0 - side * 0.45 + outd * far, c1 + side * 0.45 + outd * far, c1 + side * 0.45 + outd * near);
            let h = bottom + 0.02;
            push(&mut spray, [Vec3::new(p0.x, h, p0.y), Vec3::new(p1.x, h, p1.y), Vec3::new(p2.x, h, p2.y), Vec3::new(p3.x, h, p3.y)], card(3.0));
        } else {
            // Off the island: the sheet frays into a widening veil on its way down into the cloud sea.
            let foot = 0.05 + reach * 0.8 + 0.25;
            let (a, b) = (c0 + outd * foot - side * 0.8, c1 + outd * foot + side * 0.8);
            push(&mut spray, upright(a, b, y - 0.90 * drop, y - 0.30 * drop), card(2.0));
        }
    }
    let _ = keys;
    out.extend_from_slice(&spray);
    out
}
