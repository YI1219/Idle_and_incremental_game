//! Pond surfaces and falls as live geometry. In the study the cells' water
//! flags stand in for basins already filled by a spring.
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
    /// x: 0 pond, 1 fall; y: metres across the fall; z: metres dropped from the lip.
    pub data: [f32; 3],
}

pub fn build_water(cells: &Cells, origin: Vec3) -> Vec<WaterVertex> {
    let mut out = Vec::new();
    let mut keys: Vec<(i32, i32)> = cells.keys().copied().collect();
    keys.sort();
    let mut quad = |corners: [Vec3; 4], data: [[f32; 3]; 4]| {
        for i in [0, 1, 2, 0, 2, 3] {
            out.push(WaterVertex { pos: (corners[i] + origin).to_array(), data: data[i] });
        }
    };
    for &(x, z) in &keys {
        let cell = cells[&(x, z)];
        let Some(level) = cell.water else { continue };
        let y = level - SINK;
        let pond = |x0: f32, z0: f32| [Vec3::new(x0, y, z0), Vec3::new(x0, y, z0 + 1.0), Vec3::new(x0 + 1.0, y, z0 + 1.0), Vec3::new(x0 + 1.0, y, z0)];
        quad(pond(x as f32, z as f32), [[0.0; 3]; 4]);
        // Reach under the banks, never over lower water or past the rim.
        for (dx, dz) in [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)] {
            let key = (x + dx, z + dz);
            if let Some(other) = cells.get(&key) {
                if other.water.is_none() && other.h >= level - 0.3 {
                    quad(pond(key.0 as f32, key.1 as f32), [[0.0; 3]; 4]);
                }
            }
        }
        // Falls: over a step into lower water, or off the island.
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
            let out_dir = Vec2::new(dx as f32, dz as f32);
            let drop = y - bottom;
            let reach = 0.30 + 0.16 * drop.sqrt();
            let across = |p: Vec2| p.x * out_dir.y.abs() + p.y * out_dir.x.abs();
            let steps = 8;
            for s in 0..steps {
                let (t0, t1) = (s as f32 / steps as f32, (s + 1) as f32 / steps as f32);
                let at = |corner: Vec2, t: f32| {
                    let p = corner + out_dir * (0.12 + reach * t);
                    Vec3::new(p.x, y - drop * t * t, p.y)
                };
                quad(
                    [at(c0, t0), at(c0, t1), at(c1, t1), at(c1, t0)],
                    [[1.0, across(c0), drop * t0 * t0], [1.0, across(c0), drop * t1 * t1], [1.0, across(c1), drop * t1 * t1], [1.0, across(c1), drop * t0 * t0]],
                );
            }
            // The lip: the pond surface runs out to where the sheet starts.
            let lip = |corner: Vec2, push: f32| {
                let p = corner + out_dir * push;
                Vec3::new(p.x, y, p.y)
            };
            quad([lip(c0, 0.0), lip(c0, 0.12), lip(c1, 0.12), lip(c1, 0.0)], [[0.0; 3]; 4]);
        }
    }
    out
}
