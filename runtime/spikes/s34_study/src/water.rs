//! Pond surfaces, falls and spray as live geometry. In the study the cells' water
//! flags stand in for basins filled by a spring.
//!
//! Round r4: the fall edges of one junction (cell edges where a pond spills into lower water or
//! off the island, joined at shared corners, same levels) become one straight sheet across the
//! whole junction, with a flat lip of the upper pond filling out to it, instead of one sheet per
//! cell edge (which gave side lobes along a diagonal junction).
use std::collections::BTreeMap;

use glam::{Vec2, Vec3};

use crate::field::Cells;

/// Ponds sit this far below their nominal level so a bank shows.
pub const SINK: f32 = 0.14;
/// Outer falls drop to this height, well inside the cloud sea.
const ABYSS: f32 = -17.0;

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct WaterVertex {
    pub pos: [f32; 3],
    /// x: 0 pond, 1 fall, 2 upright spray veil, 3 flat spray pool;
    /// falls: y metres across, z metres dropped from the lip, w the sheet's width;
    /// spray: y, z in 0..1 across the quad.
    pub data: [f32; 4],
}

/// One cell edge a pond spills over: its two corners (c0 to c1 with the outward side on the
/// right as built below), outward direction, upper surface and bottom.
#[derive(Clone, Copy)]
struct Edge {
    c0: Vec2,
    c1: Vec2,
    out: Vec2,
    y: f32,
    bottom: f32,
}

pub fn build_water(cells: &Cells, origin: Vec3) -> Vec<WaterVertex> {
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
    let mut edges: Vec<Edge> = Vec::new();
    for &(x, z) in &keys {
        let cell = cells[&(x, z)];
        let Some(level) = cell.water else { continue };
        let y = level - SINK;
        let pond = |x0: f32, z0: f32| [Vec3::new(x0, y, z0), Vec3::new(x0, y, z0 + 1.0), Vec3::new(x0 + 1.0, y, z0 + 1.0), Vec3::new(x0 + 1.0, y, z0)];
        push(&mut out, pond(x as f32, z as f32), [[0.0; 4]; 4]);
        // Reach under the banks, never over lower water or past the rim.
        for (dx, dz) in [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)] {
            let key = (x + dx, z + dz);
            if let Some(other) = cells.get(&key) {
                let higher_water = other.water.is_some_and(|w| w > level + 0.2);
                if (other.water.is_none() || higher_water) && other.h >= level - 0.3 {
                    push(&mut out, pond(key.0 as f32, key.1 as f32), [[0.0; 4]; 4]);
                }
            }
        }
        // Fall edges: over a step into lower water, or off the island.
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
            edges.push(Edge { c0, c1, out: Vec2::new(dx as f32, dz as f32), y, bottom });
        }
    }

    // Junctions: edges with the same levels joined through shared corners.
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
            if share && (a.y - b.y).abs() < 1e-3 && (a.bottom - b.bottom).abs() < 1e-3 {
                let (ra, rb) = (root(&mut group, i), root(&mut group, j));
                group[ra] = rb;
            }
        }
    }
    let mut junctions: BTreeMap<usize, Vec<Edge>> = BTreeMap::new();
    for i in 0..n {
        let r = root(&mut group, i);
        junctions.entry(r).or_default().push(edges[i]);
    }

    for (_, list) in junctions {
        let (y, bottom) = (list[0].y, list[0].bottom);
        let out_dir = list.iter().map(|e| e.out).sum::<Vec2>().normalize_or_zero();
        // Along the sheet: perpendicular to the outward direction, oriented like the edges.
        let mut along = Vec2::new(out_dir.y, -out_dir.x);
        if along.dot(list[0].c1 - list[0].c0) < 0.0 {
            along = -along;
        }
        let corners: Vec<Vec2> = list.iter().flat_map(|e| [e.c0, e.c1]).collect();
        let t_min = corners.iter().map(|p| p.dot(along)).fold(f32::MAX, f32::min);
        let t_max = corners.iter().map(|p| p.dot(along)).fold(f32::MIN, f32::max);
        // The lip line passes the outermost corner, so the whole junction pours over one edge.
        let o_max = corners.iter().map(|p| p.dot(out_dir)).fold(f32::MIN, f32::max);
        let c0 = along * t_min + out_dir * o_max;
        let c1 = along * t_max + out_dir * o_max;
        let width = t_max - t_min;
        // The upper pond filled out to the lip line over each spilling edge.
        for e in &list {
            let project = |p: Vec2| p + out_dir * (o_max - p.dot(out_dir));
            let (p0, p1) = (project(e.c0), project(e.c1));
            if (p0 - e.c0).length() + (p1 - e.c1).length() > 1e-3 {
                let at = |p: Vec2| Vec3::new(p.x, y, p.y);
                push(&mut out, [at(e.c0), at(p0), at(p1), at(e.c1)], [[0.0; 4]; 4]);
            }
        }
        let drop = y - bottom;
        let reach = 0.30 + 0.16 * drop.sqrt();
        let steps = 10;
        let across = |p: Vec2| (p - c0).dot(along);
        for s in 0..steps {
            let (t0, t1) = (s as f32 / steps as f32, (s + 1) as f32 / steps as f32);
            let at = |corner: Vec2, t: f32| {
                let p = corner + out_dir * (0.12 + reach * t);
                Vec3::new(p.x, y - drop * t * t, p.y)
            };
            push(
                &mut out,
                [at(c0, t0), at(c0, t1), at(c1, t1), at(c1, t0)],
                [
                    [1.0, across(c0), drop * t0 * t0, width],
                    [1.0, across(c0), drop * t1 * t1, width],
                    [1.0, across(c1), drop * t1 * t1, width],
                    [1.0, across(c1), drop * t0 * t0, width],
                ],
            );
        }
        // The lip: the pond surface runs out to where the sheet starts.
        let lip = |corner: Vec2, push: f32| {
            let p = corner + out_dir * push;
            Vec3::new(p.x, y, p.y)
        };
        push(&mut out, [lip(c0, 0.0), lip(c0, 0.12), lip(c1, 0.12), lip(c1, 0.0)], [[0.0; 4]; 4]);

        // Spray. `side` runs along the lip from c0 to c1.
        let side = along;
        let upright = |a: Vec2, b: Vec2, low: f32, high: f32| [Vec3::new(a.x, low, a.y), Vec3::new(a.x, high, a.y), Vec3::new(b.x, high, b.y), Vec3::new(b.x, low, b.y)];
        if bottom > ABYSS {
            // Where the fall meets the lower pond: a small soft foam, a low veil and a little pool of it.
            let foot = 0.12 + reach + 0.10;
            let (a, b) = (c0 + out_dir * foot - side * 0.25, c1 + out_dir * foot + side * 0.25);
            push(&mut spray, upright(a, b, bottom - 0.05, bottom + 0.22 * drop.min(1.0) + 0.10), card(2.0));
            let (near, far) = (foot - 0.30, foot + 0.55);
            let (p0, p1, p2, p3) = (c0 - side * 0.15 + out_dir * near, c0 - side * 0.15 + out_dir * far, c1 + side * 0.15 + out_dir * far, c1 + side * 0.15 + out_dir * near);
            let h = bottom + 0.03;
            push(&mut spray, [Vec3::new(p0.x, h, p0.y), Vec3::new(p1.x, h, p1.y), Vec3::new(p2.x, h, p2.y), Vec3::new(p3.x, h, p3.y)], card(3.0));
        } else {
            // Off the island: the sheet frays into a widening veil on its way down into the cloud sea.
            let foot = 0.12 + reach * 0.8 + 0.25;
            let (a, b) = (c0 + out_dir * foot - side * 0.8, c1 + out_dir * foot + side * 0.8);
            push(&mut spray, upright(a, b, y - 0.90 * drop, y - 0.30 * drop), card(2.0));
        }
    }
    out.extend_from_slice(&spray);
    out
}
