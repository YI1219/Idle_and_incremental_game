//! Round k2: the appear-and-settle motion after an edit (owner request of 2026-11-25, after Tiny
//! Glade's feel). Not a growth simulation: the island is rebuilt once when the edit lands, and for
//! about a second after it the vertex shaders ease the new shape in from the old one: changed ground
//! rises (or sinks) from its old height to its new one and settles with a small overshoot; grass on
//! changed ground and the items an edit placed grow from nothing with a slight overshoot, in a ripple
//! out from the stroke.
//!
//! What moves where is one small table over the edit's dirty rectangle only (a 0.25 m grid of
//! the old height, the new height, a weight and a start delay, `SettleMap`), plus one start delay per
//! prop instance. The frames of the motion need no mesh work at all: one clock value in the globals
//! drives it (`L_SETTLE` in shader.wgsl), and with the clock off the shaders skip it.
//!
//! `--settle=raise,lower,expand,place,ramp` renders each edit on layout 7301 as a sequence of frames
//! from a camera fixed for it (`SEQUENCES`), and prints what the edit cost (`SETTLE ... latency`).

use std::time::Instant;

use glam::{Vec2, Vec3};

use crate::field::{self, Cell, Cells, Field};
use crate::props::{self, Library, Placement};
use crate::render::{Camera, Frame, Renderer};

/// Grid step of the settle map (metres), as the field's.
pub const STEP: f32 = 0.25;
/// New land (cells the edit added) rises from this far below its final height.
const RISE: f32 = 0.6;
/// Start delay per metre from the stroke's centre (seconds): the ripple.
pub const DELAY_PER_M: f32 = 0.045;
/// The ground's motion, the grass's and a placed item's (seconds; shader.wgsl SETTLE_*).
pub const END: f32 = 1.5;
/// Placed items start one after another, this far apart (seconds).
const ITEM_STAGGER: f32 = 0.09;
/// Grass round a placed item regrows within its clearing plus this (metres).
const REGROW_REACH: f32 = 0.0;
/// The vertical band round the old and new ground that a compressed vertex must lie in (metres).
const BAND: f32 = 0.25;

/// One texel of the settle map: `a` = (anchor height, new height, band low, band high),
/// `b` = (weight, translate share, start delay, grass regrowth), `c` (round k5) = (edge dip: land
/// left standing beside land an edit removed, water fill: water that rose or appeared, ghost zone:
/// land the edit removed and the rim that hung off it, spare). See shader.wgsl `settle_at`.
#[repr(C)]
#[derive(Clone, Copy, Default, bytemuck::Pod, bytemuck::Zeroable)]
pub struct Texel {
    pub a: [f32; 4],
    pub b: [f32; 4],
    pub c: [f32; 4],
}

pub struct SettleMap {
    pub x0: f32,
    pub z0: f32,
    pub nx: usize,
    pub nz: usize,
    pub texels: Vec<Texel>,
}

impl SettleMap {
    /// The settle map's slots in the light set: clock, origin, size (shader.wgsl L_SETTLE, L_SETTLE_N).
    pub fn slots(&self, clock: f32, items: usize) -> [[f32; 4]; 2] {
        [[clock, self.x0, self.z0, STEP], [self.nx as f32, self.nz as f32, items as f32, 0.0]]
    }

    /// The nearest texel to a ground point, if the point lies on the map.
    pub fn texel(&self, p: Vec2) -> Option<&Texel> {
        let q = (p - Vec2::new(self.x0, self.z0)) / STEP;
        let (i, j) = (q.x.round(), q.y.round());
        if i < 0.0 || j < 0.0 || i >= self.nx as f32 || j >= self.nz as f32 {
            return None;
        }
        Some(&self.texels[j as usize * self.nx + i as usize])
    }

    /// True where the edit removed land (or the rim that hung off it): old geometry there leaves as
    /// a ghost.
    pub fn ghost_zone(&self, p: Vec2) -> bool {
        self.texel(p).is_some_and(|t| t.c[2] > 0.5)
    }
}

/// Builds the settle map over `lo..hi` (island coordinates) from the fields before and after the
/// edit. Ground whose height changed is compressed toward its old height (a raised patch grows out
/// of the old lawn, a lowered one sinks from it); land the edit added is lifted `RISE` below its
/// final place with everything under it. `regrow` adds circles (centre, radius, delay) where the grass
/// regrows although the ground did not change (round a placed item).
pub fn build_map(before_cells: &Cells, before: &Field, after_cells: &Cells, after: &Field, lo: Vec2, hi: Vec2, centre: Vec2, regrow: &[(Vec2, f32, f32)]) -> SettleMap {
    let nx = ((hi.x - lo.x) / STEP).ceil() as usize + 1;
    let nz = ((hi.y - lo.y) / STEP).ceil() as usize + 1;
    let at = |i: usize, j: usize| Vec2::new(lo.x + i as f32 * STEP, lo.y + j as f32 * STEP);
    let cell_of = |p: Vec2| (p.x.floor() as i32, p.y.floor() as i32);
    // Raw values: changed (0 or 1), anchor, new height, mode (1 translate), band.
    let n = nx * nz;
    let mut changed = vec![0.0_f32; n];
    // New land is kept apart from height changes: it moves whole (with everything under it) and its
    // weight stops at its own texels, so the old land beside it does not tear into slanted faces.
    let mut added = vec![0.0_f32; n];
    let mut old_land = vec![false; n];
    // Round k5: land the edit removed, land standing after it, water that rose or appeared.
    let mut gone = vec![false; n];
    let mut new_land = vec![false; n];
    let mut fill = vec![0.0_f32; n];
    let mut anchor = vec![0.0_f32; n];
    let mut fresh = vec![0.0_f32; n];
    let mut mode = vec![0.0_f32; n];
    let mut band = vec![(f32::MAX, f32::MIN); n];
    for j in 0..nz {
        for i in 0..nx {
            let p = at(i, j);
            let k = j * nx + i;
            let (was, is) = (before_cells.contains_key(&cell_of(p)) && before.inside(p), after_cells.contains_key(&cell_of(p)) && after.inside(p));
            let h_new = if is { after.height_at(p) } else { before.height_at(p) };
            let h_old = if was { before.height_at(p) } else { h_new };
            fresh[k] = h_new;
            anchor[k] = h_old;
            old_land[k] = was;
            gone[k] = was && !is;
            new_land[k] = is;
            if is {
                if let Some(level) = after.water_at(p) {
                    let old = if was { before.water_at(p) } else { None };
                    if old.map_or(true, |o| level > o + 0.01) {
                        fill[k] = 1.0;
                    }
                }
            }
            if is && !was {
                added[k] = 1.0;
                mode[k] = 1.0;
                anchor[k] = h_new - RISE;
                band[k] = (-1.0e4, h_new + BAND);
            } else if is && (h_new - h_old).abs() > 0.01 {
                changed[k] = 1.0;
                band[k] = (h_old.min(h_new) - BAND, h_old.max(h_new) + BAND);
            } else {
                band[k] = (h_new - BAND, h_new + BAND);
            }
        }
    }
    // New land reaches 1 m past its outline into what was not land before, so the rim blocks hung
    // at the new outline rise with it (each such texel copies the nearest new-land texel).
    {
        let reach = 4_i32;
        let source = added.clone();
        for j in 0..nz as i32 {
            for i in 0..nx as i32 {
                let k = (j as usize) * nx + i as usize;
                if source[k] > 0.0 {
                    continue;
                }
                let mut best: Option<(i32, usize)> = None;
                for dj in -reach..=reach {
                    for di in -reach..=reach {
                        let (a, b) = (i + di, j + dj);
                        if a < 0 || b < 0 || a >= nx as i32 || b >= nz as i32 {
                            continue;
                        }
                        let q = (b as usize) * nx + a as usize;
                        let d = di * di + dj * dj;
                        if source[q] > 0.0 && d <= reach * reach && best.map_or(true, |(e, _)| d < e) {
                            best = Some((d, q));
                        }
                    }
                }
                if old_land[k] {
                    // Round k5: old land beside new land (a lower terrace the new land meets): its
                    // band reaches up to the new land's top, so the wall between them moves with the
                    // new land instead of standing up as thin slivers for the first tenth of a second.
                    if let Some((d, q)) = best {
                        if d <= 4 {
                            band[k].1 = band[k].1.max(band[q].1);
                        }
                    }
                    continue;
                }
                if let Some((_, q)) = best {
                    added[k] = 1.0;
                    mode[k] = 1.0;
                    fresh[k] = fresh[q];
                    anchor[k] = anchor[q];
                    band[k] = band[q];
                }
            }
        }
    }
    // The weight: the change grown by 0.5 m, then softened twice with a 3 x 3 box (about 0.5 m of
    // falloff). The band and the mode take the widest of the changed texels within 0.5 m.
    let reach = 2_i32;
    let mut grown = vec![0.0_f32; n];
    let mut wide = band.clone();
    let mut mode_grown = mode.clone();
    for j in 0..nz as i32 {
        for i in 0..nx as i32 {
            let k = (j as usize) * nx + i as usize;
            for dj in -reach..=reach {
                for di in -reach..=reach {
                    let (a, b) = (i + di, j + dj);
                    if a < 0 || b < 0 || a >= nx as i32 || b >= nz as i32 {
                        continue;
                    }
                    let q = (b as usize) * nx + a as usize;
                    if changed[q] > 0.0 {
                        grown[k] = 1.0;
                        wide[k] = (wide[k].0.min(band[q].0), wide[k].1.max(band[q].1));
                        mode_grown[k] = mode_grown[k].max(mode[q]);
                    }
                }
            }
        }
    }
    let blur = |src: &[f32]| -> Vec<f32> {
        let mut out = vec![0.0_f32; n];
        for j in 0..nz as i32 {
            for i in 0..nx as i32 {
                let mut sum = 0.0;
                for dj in -1..=1 {
                    for di in -1..=1 {
                        let (a, b) = ((i + di).clamp(0, nx as i32 - 1), (j + dj).clamp(0, nz as i32 - 1));
                        sum += src[(b as usize) * nx + a as usize];
                    }
                }
                out[(j as usize) * nx + i as usize] = sum / 9.0;
            }
        }
        out
    };
    let mut weight = blur(&blur(&grown));
    for k in 0..n {
        weight[k] = weight[k].max(added[k]);
    }
    // The map's border carries no motion, so nothing jumps where the map ends.
    for j in 0..nz {
        for i in 0..nx {
            if i == 0 || j == 0 || i + 1 == nx || j + 1 == nz {
                weight[j * nx + i] = 0.0;
            }
        }
    }
    // Round k5: the ghost zone (land removed, and what is not land after the edit within 1.5 m of
    // it: the rim blocks that hung off it), the edge dip (land left standing within 1.5 m of land
    // removed, falling off with distance) and the water fill (grown a texel, softened once).
    let mut zone = vec![0.0_f32; n];
    let mut edge = vec![0.0_f32; n];
    if gone.iter().any(|g| *g) {
        let reach = 6_i32;
        for j in 0..nz as i32 {
            for i in 0..nx as i32 {
                let k = (j as usize) * nx + i as usize;
                if gone[k] {
                    zone[k] = 1.0;
                    continue;
                }
                let mut nearest = f32::MAX;
                for dj in -reach..=reach {
                    for di in -reach..=reach {
                        let (a, b) = (i + di, j + dj);
                        if a < 0 || b < 0 || a >= nx as i32 || b >= nz as i32 {
                            continue;
                        }
                        if gone[(b as usize) * nx + a as usize] {
                            nearest = nearest.min(((di * di + dj * dj) as f32).sqrt() * STEP);
                        }
                    }
                }
                if nearest <= 1.5 {
                    if new_land[k] {
                        edge[k] = 1.0 - nearest / 1.5;
                    } else {
                        zone[k] = 1.0;
                    }
                }
            }
        }
    }
    let fill = blur(&fill.iter().enumerate().map(|(k, f)| if *f > 0.0 || (k >= 1 && fill[k - 1] > 0.0) || (k + 1 < n && fill[k + 1] > 0.0) { 1.0 } else { 0.0 }).collect::<Vec<f32>>());
    let mut texels = Vec::with_capacity(n);
    for j in 0..nz {
        for i in 0..nx {
            let k = j * nx + i;
            let p = at(i, j);
            let mut grass = weight[k];
            let mut delay = DELAY_PER_M * (p - centre).length();
            for &(c, r, d) in regrow {
                let s = 1.0 - crate::mesh::smoothstep(r + 0.15, r + 0.55, (p - c).length());
                if s > grass {
                    grass = s;
                    delay = d;
                }
            }
            let border = i == 0 || j == 0 || i + 1 == nx || j + 1 == nz;
            let (edge, fill) = if border { (0.0, 0.0) } else { (edge[k], fill[k]) };
            texels.push(Texel { a: [anchor[k], fresh[k], wide[k].0, wide[k].1], b: [weight[k], mode_grown[k], delay, grass], c: [edge, fill, zone[k], 0.0] });
        }
    }
    // S34_SETTLE_DUMP="x,z0,z1": the texels along one line of x (checking a map).
    if let Ok(spec) = std::env::var("S34_SETTLE_DUMP") {
        let v: Vec<f32> = spec.split(',').map(|s| s.parse().unwrap()).collect();
        let i = ((v[0] - lo.x) / STEP).round() as usize;
        let mut z = v[1];
        while z <= v[2] && i < nx {
            let j = ((z - lo.y) / STEP).round() as usize;
            if j < nz {
                let t = &texels[j * nx + i];
                println!("SETTLE texel ({:.2}, {z:.2}): anchor {:.2} new {:.2} band {:.2}..{:.2} weight {:.2} lift {:.0} delay {:.2} grass {:.2}", v[0], t.a[0], t.a[1], t.a[2], t.a[3], t.b[0], t.b[1], t.b[2], t.b[3]);
            }
            z += STEP;
        }
    }
    SettleMap { x0: lo.x, z0: lo.y, nx, nz, texels }
}

/// One start delay per prop instance (origin xyz, delay; a negative delay: the instance does not
/// grow, it only rides the ground under its origin). An instance grows when it stands where an
/// item was placed (same kind, within 5 cm).
pub fn instance_table(library: &Library, placed: &[Placement], centre: Vec2) -> (Vec<[f32; 4]>, Vec<(Vec2, f32, f32)>) {
    let mut table = Vec::with_capacity(library.instances.len().max(1));
    let mut regrow = Vec::new();
    for inst in &library.instances {
        let p = Vec2::new(inst.origin.x, inst.origin.z);
        let order = placed.iter().position(|e| e.kind == inst.kind && (e.at - p).length() < 0.05);
        let delay = match order {
            Some(index) => {
                let d = ITEM_STAGGER * index as f32 + DELAY_PER_M * (p - centre).length();
                let r = props::clear_radius_of(&inst.kind).unwrap_or(0.2) * placed[index].size;
                regrow.push((p, r + REGROW_REACH, d + 0.05));
                d
            }
            None => -1.0,
        };
        table.push([inst.origin.x, inst.origin.y, inst.origin.z, delay]);
    }
    if table.is_empty() {
        table.push([0.0, 0.0, 0.0, -1.0]);
    }
    (table, regrow)
}

/// Round k5: an island as an edit sees it: its cells, what was built from them, its props.
pub struct Island {
    pub cells: Cells,
    pub built: crate::Built,
    pub library: Library,
}

/// Round k5: everything the GPU needs to play one edit's motion: the settle map, one record per
/// prop instance of the island after the edit (with the ghosts of removed props appended to its
/// library), and the ghosts of removed land, water and grass (old geometry that leaves: it falls
/// away, drains or shrinks, then is hidden). Ghosts are found by comparing the islands before and
/// after, so an item dropped with the land under it leaves the same way as one removed by hand.
pub struct Transition {
    pub map: SettleMap,
    pub items: Vec<[f32; 4]>,
    pub ghost_solid: Vec<crate::mesh::Vertex>,
    pub ghost_water: Vec<crate::water::WaterVertex>,
    pub ghost_clumps: Vec<crate::grass::Clump>,
    pub ghost_props: usize,
}

/// A removed prop's record: shrinks from `delay` (shader.wgsl `settle_prop`).
fn ghost_record(delay: f32) -> f32 {
    -10.0 - delay
}

/// Builds the transition from `before` to `after` (whose library gets the removed props' ghosts
/// appended). `lo..hi`: the dirty rectangle; `centre`: where the stroke was; `placed`: items the edit
/// placed (they grow in).
pub fn transition(before: &Island, after: &mut Island, lo: Vec2, hi: Vec2, centre: Vec2, placed: &[Placement]) -> Transition {
    // Props: kept (same kind within 5 cm in plan), placed (grow), or gone (ghost, shrinks).
    let (mut items, regrow) = instance_table(&after.library, placed, centre);
    let gone: Vec<usize> = {
        let kept = |kind: &str, p: Vec2| after.library.instances.iter().any(|i| i.kind == kind && (Vec2::new(i.origin.x, i.origin.z) - p).length() < 0.05);
        before
            .library
            .instances
            .iter()
            .enumerate()
            .filter(|(_, inst)| {
                let p = Vec2::new(inst.origin.x, inst.origin.z);
                !kept(&inst.kind, p) && p.cmpge(lo).all() && p.cmple(hi).all()
            })
            .map(|(id, _)| id)
            .collect()
    };
    let mut ghost_ids: Vec<(usize, usize)> = Vec::new();
    for id in gone {
        let inst = &before.library.instances[id];
        let p = Vec2::new(inst.origin.x, inst.origin.z);
        {
            let new_id = after.library.instances.len();
            after.library.instances.push(inst.clone());
            ghost_ids.push((id, new_id));
            let delay = DELAY_PER_M * (p - centre).length();
            if items.len() == 1 && after.library.instances.len() == 1 {
                items.clear();
            }
            items.push([inst.origin.x, inst.origin.y, inst.origin.z, ghost_record(delay)]);
        }
    }
    for (class, bucket) in before.library.buckets.iter().enumerate() {
        for v in bucket {
            let id = v.mat[2] as usize + v.mat[3] as usize * 256;
            if let Some(&(_, new_id)) = ghost_ids.iter().find(|(o, _)| *o == id) {
                let mut g = *v;
                g.mat[2] = (new_id & 255) as u8;
                g.mat[3] = (new_id >> 8) as u8;
                after.library.buckets[class].push(g);
            }
        }
    }
    let map = build_map(&before.cells, &before.built.field, &after.cells, &after.built.field, lo, hi, centre, &regrow);
    // Land, water and grass that leave: old geometry over the ghost zone (land removed and the rim
    // that hung off it), and old water where none stands after the edit.
    let centroid = |p: [[f32; 3]; 3]| Vec2::new((p[0][0] + p[1][0] + p[2][0]) / 3.0, (p[0][2] + p[1][2] + p[2][2]) / 3.0);
    let mut ghost_solid = Vec::new();
    for tri in before.built.solid.vertices.chunks_exact(3) {
        if map.ghost_zone(centroid([tri[0].pos, tri[1].pos, tri[2].pos])) {
            ghost_solid.extend_from_slice(tri);
        }
    }
    let mut ghost_water = Vec::new();
    for tri in before.built.water.chunks_exact(3) {
        let c = centroid([tri[0].pos, tri[1].pos, tri[2].pos]);
        let inside = c.cmpge(lo).all() && c.cmple(hi).all();
        if inside && (map.ghost_zone(c) || (after.built.field.water_at(c).is_none() && before.built.field.water_at(c).is_some())) {
            ghost_water.extend_from_slice(tri);
        }
    }
    let mut ghost_clumps = Vec::new();
    for clump in &before.built.grass.clumps {
        if map.ghost_zone(Vec2::new(clump.root[0], clump.root[2])) {
            let mut g = *clump;
            g.misc[3] = 255;
            ghost_clumps.push(g);
        }
    }
    let ghost_props = ghost_ids.len();
    Transition { map, items, ghost_solid, ghost_water, ghost_clumps, ghost_props }
}

/// An edit of a sequence.
enum Edit {
    /// Cells x0..=x1, z0..=z1 change height by `by` (dry cells only).
    Height { x0: i32, z0: i32, x1: i32, z1: i32, by: f32 },
    /// Cells x0..=x1, z0..=z1 become land at height `h` where they were none.
    Add { x0: i32, z0: i32, x1: i32, z1: i32, h: f32 },
    /// A ramp stroke (field::ramp).
    Ramp { a: Vec2, b: Vec2, width: f32 },
    /// Items placed on the lawn.
    Place(&'static [Placement]),
    /// Round k5: a stroke of the brush tools (brush.rs), the path every edit of the runtime takes.
    Brush(crate::brush::Stroke),
}

/// The sequences on layout 7301: name, the edit, its centre, and the camera (target, yaw, pitch,
/// distance; yaw as in cameras.json). Places chosen on clear lawn away from water and props.
const PLACED: [Placement; 6] = [
    Placement { kind: "tree", at: Vec2::new(2.6, -6.3), yaw: 0.6, size: 0.75, pick: 1 },
    Placement { kind: "bush", at: Vec2::new(1.2, -5.0), yaw: 2.1, size: 1.0, pick: 0 },
    Placement { kind: "bush", at: Vec2::new(3.9, -7.6), yaw: 4.0, size: 0.9, pick: 2 },
    Placement { kind: "surface_rock", at: Vec2::new(4.2, -5.3), yaw: 1.2, size: 1.0, pick: 0 },
    Placement { kind: "surface_rock", at: Vec2::new(4.9, -5.9), yaw: 3.4, size: 0.6, pick: 1 },
    Placement { kind: "flower", at: Vec2::new(0.4, -6.6), yaw: 0.3, size: 1.0, pick: 0 },
];

struct Sequence {
    name: &'static str,
    /// Strokes applied first, without motion, to set the island up (a pit, a pond in it).
    pre: Vec<crate::brush::Stroke>,
    edit: Edit,
    centre: Vec2,
    camera: ([f32; 3], f32, f32, f32),
}

fn stroke(tool: crate::brush::Tool, path: &[(f32, f32)], radius: f32) -> crate::brush::Stroke {
    crate::brush::Stroke { tool, path: path.iter().map(|&(x, z)| Vec2::new(x, z)).collect(), radius, level: 0.0, width: 2.0, item: None }
}

fn sequences() -> Vec<Sequence> {
    use crate::brush::Tool;
    // A pit (lowered 1 m, 3 x 3 cells) on the main terrace, and a pond in it (level 3.0, between the
    // pit's floor at 2.5 and the lawn at 3.5).
    let pit = Edit::Height { x0: 2, z0: -7, x1: 4, z1: -5, by: -1.0 };
    let pit_stroke = || crate::brush::Stroke { tool: Tool::Lower, path: vec![Vec2::new(3.5, -5.5)], radius: 1.6, level: 0.0, width: 2.0, item: None };
    let pond = || crate::brush::Stroke { tool: Tool::Water, path: vec![Vec2::new(3.5, -5.5)], radius: 1.6, level: 3.0, width: 2.0, item: None };
    let lower_twice = || vec![pit_stroke(), pit_stroke()];
    vec![
        Sequence { name: "raise", pre: vec![], edit: Edit::Height { x0: -5, z0: -7, x1: -3, z1: -5, by: 1.0 }, centre: Vec2::new(-3.5, -5.5), camera: ([-3.5, 3.9, -5.5], 20.0, 30.0, 12.0) },
        Sequence { name: "lower", pre: vec![], edit: pit, centre: Vec2::new(3.5, -5.5), camera: ([3.5, 3.0, -5.5], 20.0, 36.0, 12.0) },
        Sequence { name: "expand", pre: vec![], edit: Edit::Add { x0: -15, z0: 5, x1: -12, z1: 7, h: 3.5 }, centre: Vec2::new(-13.0, 6.0), camera: ([-12.5, 2.5, 5.5], 25.0, 22.0, 17.0) },
        Sequence { name: "place", pre: vec![], edit: Edit::Place(&PLACED), centre: Vec2::new(2.6, -6.2), camera: ([2.7, 4.8, -6.3], 20.0, 26.0, 15.0) },
        Sequence { name: "ramp", pre: vec![], edit: Edit::Ramp { a: Vec2::new(-7.0, 3.5), b: Vec2::new(-7.0, 7.5), width: 2.0 }, centre: Vec2::new(-7.0, 5.5), camera: ([-7.0, 3.0, 5.5], 35.0, 30.0, 12.0) },
        // Round k5: removal, through the brush path.
        Sequence { name: "erase", pre: vec![], edit: Edit::Brush(stroke(Tool::Contract, &[(-14.0, 4.2), (-12.0, 4.8)], 1.6)), centre: Vec2::new(-13.0, 4.5), camera: ([-12.5, 2.5, 4.5], 25.0, 24.0, 17.0) },
        Sequence { name: "remove", pre: vec![], edit: Edit::Brush(stroke(Tool::Remove, &[(-15.6, -4.4)], 1.4)), centre: Vec2::new(-15.6, -4.4), camera: ([-15.6, 4.6, -4.4], 25.0, 26.0, 13.0) },
        Sequence { name: "unraise", pre: vec![stroke(Tool::Raise, &[(-3.5, -5.5)], 1.6), stroke(Tool::Raise, &[(-3.5, -5.5)], 1.6)], edit: Edit::Brush(stroke(Tool::Lower, &[(-3.5, -5.5)], 1.6)), centre: Vec2::new(-3.5, -5.5), camera: ([-3.5, 3.9, -5.5], 20.0, 30.0, 12.0) },
        Sequence { name: "fill", pre: lower_twice(), edit: Edit::Brush(pond()), centre: Vec2::new(3.5, -5.5), camera: ([3.5, 3.0, -5.5], 20.0, 36.0, 12.0) },
        Sequence { name: "drain", pre: { let mut v = lower_twice(); v.push(pond()); v }, edit: Edit::Brush(stroke(Tool::Dry, &[(3.5, -5.5)], 1.8)), centre: Vec2::new(3.5, -5.5), camera: ([3.5, 3.0, -5.5], 20.0, 36.0, 12.0) },
    ]
}

fn view(target: [f32; 3], yaw: f32, pitch: f32, dist: f32) -> Camera {
    let (y, p) = (yaw.to_radians(), pitch.to_radians());
    let target = Vec3::from(target);
    Camera { eye: target + Vec3::new(y.sin() * p.cos(), p.sin(), y.cos() * p.cos()) * dist, target, fov_deg: 31.0 }
}

/// Applies an edit; returns the edited cells and items, the rectangle it touched, its centre and
/// the placements.
fn apply(cells: &Cells, items: &props::Items, library: &Library, edit: &Edit) -> (Cells, props::Items, (Vec2, Vec2), Option<Vec2>, Vec<Placement>) {
    let mut out = cells.clone();
    let mut items = items.clone();
    match edit {
        Edit::Height { x0, z0, x1, z1, by } => {
            for z in *z0..=*z1 {
                for x in *x0..=*x1 {
                    if let Some(c) = out.get_mut(&(x, z)) {
                        assert!(c.water.is_none() && !c.sloped(), "settle edit on water or slope at ({x}, {z})");
                        c.h += by;
                    }
                }
            }
            (out, items, (Vec2::new(*x0 as f32, *z0 as f32), Vec2::new(*x1 as f32 + 1.0, *z1 as f32 + 1.0)), None, Vec::new())
        }
        Edit::Add { x0, z0, x1, z1, h } => {
            for z in *z0..=*z1 {
                for x in *x0..=*x1 {
                    out.entry((x, z)).or_insert(Cell::flat(*h, None));
                }
            }
            (out, items, (Vec2::new(*x0 as f32, *z0 as f32), Vec2::new(*x1 as f32 + 1.0, *z1 as f32 + 1.0)), None, Vec::new())
        }
        Edit::Ramp { a, b, width } => {
            let done = field::ramp(&mut out, *a, *b, *width).unwrap_or_else(|e| panic!("settle ramp refused: {e}"));
            println!("SETTLE ramp: {} cells, rise {:.2} m over {:.2} m", done.cells, done.rise, done.length);
            let (lo, hi) = (done.a.min(done.b) - Vec2::splat(*width), done.a.max(done.b) + Vec2::splat(*width));
            (out, items, (lo, hi), None, Vec::new())
        }
        Edit::Place(list) => {
            let lo = list.iter().fold(Vec2::splat(f32::MAX), |m, e| m.min(e.at)) - Vec2::splat(1.0);
            let hi = list.iter().fold(Vec2::splat(f32::MIN), |m, e| m.max(e.at)) + Vec2::splat(1.0);
            items.placed.extend_from_slice(list);
            (out, items, (lo, hi), None, list.to_vec())
        }
        Edit::Brush(stroke) => {
            let done = crate::brush::apply(&mut out, &mut items, library, stroke);
            println!("SETTLE brush {}: {} changed{}", stroke.tool.name(), done.changed, done.refused.as_deref().map(|r| format!(" (refused: {r})")).unwrap_or_default());
            (out, items, (done.lo, done.hi), Some(done.centre), done.placed)
        }
    }
}

/// Times of the frames: `times` if given, else 30 a second from 0 to `END`.
pub fn frame_times(times: &[f32]) -> Vec<f32> {
    if !times.is_empty() {
        return times.to_vec();
    }
    (0..=((END * 30.0).round() as i32)).map(|i| i as f32 / 30.0).collect()
}

pub struct Settings<'a> {
    pub layout: &'a str,
    pub props: Option<std::path::PathBuf>,
    pub body: crate::body::Kind,
    pub seed: u32,
    pub out: &'a str,
    pub tag: &'a str,
    pub names: Vec<String>,
    pub times: Vec<f32>,
    pub bench: bool,
    pub ssao: bool,
    pub ssao_blur: bool,
    pub light: [[f32; 4]; crate::render::LIGHT_SLOTS],
    pub sun_dir: Vec3,
    pub hour: f32,
    pub width: u32,
    pub height: u32,
    pub scale: u32,
    pub fxaa: bool,
    pub grass: bool,
}

/// Builds an island from cells and items (the same build every edit does).
pub fn build(s_body: crate::body::Kind, seed: u32, props_dir: Option<&std::path::Path>, cells: Cells, items: &props::Items) -> Island {
    let mut library = Library::default();
    let built = crate::build_island(&cells, s_body, seed, Vec3::ZERO, true, props_dir, &mut library, items);
    Island { cells, built, library }
}

/// The settle slots of a frame: clock, map, item count, ghost ranges.
pub fn settle_slots(light: &mut [[f32; 4]; crate::render::LIGHT_SLOTS], clock: f32, motion: Option<(&Transition, [f32; 4])>) {
    let base = crate::render::SETTLE_SLOT;
    match motion {
        Some((t, ranges)) => {
            let slots = t.map.slots(clock, t.items.len());
            light[base] = slots[0];
            light[base + 1] = slots[1];
            light[base + 2] = ranges;
        }
        None => {
            light[base] = [-1.0, 0.0, 0.0, STEP];
            light[base + 1] = [0.0; 4];
            light[base + 2] = [0.0; 4];
        }
    }
}

/// Renders the asked sequences. For each: the island before the edit (frame `t-before`), then the
/// edit (rebuild, settle map, upload: the latency), then the frames of the motion; with `bench`
/// three frame costs at the sequence's camera: the settled island with the shadow map cached (as
/// the other benches), the same with the shadow map redrawn every frame, and the motion running
/// (clock cycling over the whole motion, shadow map redrawn every frame).
pub fn run(s: &Settings, renderer: &mut Renderer) -> Vec<String> {
    let base_cells = field::load_layout(s.layout);
    let far = crate::far_mountains();
    let mut lines = Vec::new();
    for seq in sequences().into_iter().filter(|q| s.names.iter().any(|n| n == q.name || n == "all")) {
        // S34_SETTLE_CAMERA="tx,ty,tz,yaw,pitch,dist" replaces the sequence's camera (checking).
        let camera = match std::env::var("S34_SETTLE_CAMERA") {
            Ok(spec) => {
                let v: Vec<f32> = spec.split(',').map(|x| x.trim().parse().expect("S34_SETTLE_CAMERA numbers")).collect();
                view([v[0], v[1], v[2]], v[3], v[4], v[5])
            }
            Err(_) => view(seq.camera.0, seq.camera.1, seq.camera.2, seq.camera.3),
        };
        let frame_at = |clock: f32, motion: Option<(&Transition, [f32; 4])>| {
            let mut light = s.light;
            light[16][0] = 1.0;
            light[12][0] = -4.0;
            light[12][1] = -6.9;
            light[29][0] = camera.target.x;
            light[29][2] = camera.target.z;
            settle_slots(&mut light, clock, motion);
            Frame { camera, sun_dir: s.sun_dir, time: 3.0, hour: s.hour, ssao: s.ssao, ssao_blur: s.ssao_blur, debug: 0.0, light }
        };
        // Before (after the set-up strokes, if any).
        let mut cells = base_cells.clone();
        let mut items = props::Items::scene();
        for st in &seq.pre {
            crate::brush::apply(&mut cells, &mut items, &Library::default(), st);
        }
        let before = build(s.body, s.seed, s.props.as_deref(), cells, &items);
        upload(renderer, &before, &far, s.grass, None);
        renderer.render(&frame_at(-1.0, None));
        let path = format!("{}/{}_{}_before.png", s.out, s.tag, seq.name);
        renderer.save_png(&path);
        println!("FRAME {path}");
        // The edit: what an interactive build would do when the stroke lands.
        let (edited, after_items, (lo, hi), centre, placed) = apply(&before.cells, &items, &before.library, &seq.edit);
        let centre = centre.unwrap_or(seq.centre);
        let start = Instant::now();
        let mut after = build(s.body, s.seed, s.props.as_deref(), edited, &after_items);
        let rebuilt = start.elapsed().as_secs_f64() * 1000.0;
        let lap = Instant::now();
        // The dirty rectangle: what the edit touched plus 4 m (the top surface changes at most 4 m
        // from a stroke, README "Locality").
        let (lo, hi) = (lo - Vec2::splat(4.0), hi + Vec2::splat(4.0));
        let motion = transition(&before, &mut after, lo, hi, centre, &placed);
        let mapped = lap.elapsed().as_secs_f64() * 1000.0;
        let lap = Instant::now();
        let ranges = upload(renderer, &after, &far, s.grass, Some(&motion));
        renderer.wait();
        let uploaded = lap.elapsed().as_secs_f64() * 1000.0;
        let line = format!(
            "SETTLE {} latency: rebuild {rebuilt:.1} ms ({}), settle map and ghosts {mapped:.2} ms ({} x {} texels, {:.1} x {:.1} m; ghosts: {} land triangles, {} water triangles, {} grass clumps, {} items), upload {uploaded:.1} ms, total {:.1} ms; {} placed items",
            seq.name,
            after.built.timings.iter().map(|(n, ms)| format!("{n} {ms:.1}")).collect::<Vec<_>>().join(", "),
            motion.map.nx,
            motion.map.nz,
            hi.x - lo.x,
            hi.y - lo.y,
            motion.ghost_solid.len() / 3,
            motion.ghost_water.len() / 3,
            motion.ghost_clumps.len(),
            motion.ghost_props,
            rebuilt + mapped + uploaded,
            placed.len()
        );
        println!("{line}");
        lines.push(format!(
            "  {{\"sequence\": \"{}\", \"rebuild_ms\": {rebuilt:.2}, \"stages_ms\": {{{}}}, \"settle_map_ms\": {mapped:.3}, \"texels\": {}, \"upload_ms\": {uploaded:.2}}}",
            seq.name,
            after.built.timings.iter().map(|(n, ms)| format!("\"{n}\": {ms:.2}")).collect::<Vec<_>>().join(", "),
            motion.map.nx * motion.map.nz
        ));
        for t in frame_times(&s.times) {
            renderer.render(&frame_at(t, Some((&motion, ranges))));
            let path = format!("{}/{}_{}_t{:04}.png", s.out, s.tag, seq.name, (t * 1000.0).round() as i32);
            renderer.save_png(&path);
            println!("FRAME {path}");
        }
        if s.bench {
            let still = renderer.bench(&frame_at(END + 1.0, Some((&motion, ranges))), 120);
            let shadowed = renderer.bench_settle(&frame_at(END + 1.0, Some((&motion, ranges))), 120, None);
            let moving = renderer.bench_settle(&frame_at(0.0, Some((&motion, ranges))), 120, Some(END));
            let line = format!(
                "BENCH settle_{}: settled {still:.2} ms (shadow cached), {shadowed:.2} ms (shadow redrawn), during the motion {moving:.2} ms (shadow redrawn) a frame at {}x{} with {}x supersampling, fxaa {}",
                seq.name,
                s.width,
                s.height,
                s.scale,
                if s.fxaa { "on" } else { "off" }
            );
            println!("{line}");
            lines.push(format!("  {{\"sequence\": \"{}\", \"bench_settled_ms\": {still:.3}, \"bench_shadow_redrawn_ms\": {shadowed:.3}, \"bench_moving_ms\": {moving:.3}}}", seq.name));
        }
    }
    lines
}

/// Uploads an island (and, with a transition, its motion: the ghosts are drawn after the island's
/// own geometry, in ranges the shaders are told of). Returns the ghost ranges for light slot
/// `SETTLE_SLOT + 2` (solid start and end, water start and end; zeros without a transition).
pub fn upload(renderer: &mut Renderer, island: &Island, far: &crate::mesh::Mesh, grass: bool, motion: Option<&Transition>) -> [f32; 4] {
    let mut solid = crate::mesh::Mesh::default();
    solid.append(&island.built.solid);
    let island_end = solid.vertices.len();
    let mut ranges = [0.0_f32; 4];
    let mut water = island.built.water.clone();
    if let Some(t) = motion {
        solid.vertices.extend_from_slice(&t.ghost_solid);
        ranges[0] = island_end as f32;
        ranges[1] = solid.vertices.len() as f32;
        ranges[2] = water.len() as f32;
        water.extend_from_slice(&t.ghost_water);
        ranges[3] = water.len() as f32;
    }
    let casters = solid.vertices.len();
    solid.append(far);
    renderer.set_scene(&solid.vertices, casters, &water);
    renderer.set_props(&island.library);
    if grass {
        match motion.filter(|t| !t.ghost_clumps.is_empty()) {
            Some(t) => {
                let mut clumps = island.built.grass.clumps.clone();
                let mut chunks = island.built.grass.chunks.clone();
                let first = clumps.len() as u32;
                let (mut lo, mut hi) = (Vec3::splat(f32::MAX), Vec3::splat(f32::MIN));
                for c in &t.ghost_clumps {
                    lo = lo.min(Vec3::from(c.root) - Vec3::splat(1.0));
                    hi = hi.max(Vec3::from(c.root) + Vec3::new(1.0, 1.5, 1.0));
                }
                // The ghosts fall up to GHOST_FALL m: the chunk's bounds reach that far down.
                lo.y -= 7.0;
                clumps.extend_from_slice(&t.ghost_clumps);
                let n = t.ghost_clumps.len() as u32;
                chunks.push(crate::grass::Chunk { lo, hi, first, counts: [n, n, n], parent_lo: lo, parent_hi: hi });
                renderer.set_grass(&crate::grass::Grass { clumps, chunks });
            }
            None => renderer.set_grass(&island.built.grass),
        }
    }
    match motion {
        Some(t) => renderer.set_settle(&t.map.texels, &t.items),
        None => renderer.clear_settle(),
    }
    ranges
}
