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
/// `b` = (weight, translate share, start delay, grass regrowth). See shader.wgsl `settle_at`.
#[repr(C)]
#[derive(Clone, Copy, Default, bytemuck::Pod, bytemuck::Zeroable)]
pub struct Texel {
    pub a: [f32; 4],
    pub b: [f32; 4],
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
                if source[k] > 0.0 || old_land[k] {
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
            texels.push(Texel { a: [anchor[k], fresh[k], wide[k].0, wide[k].1], b: [weight[k], mode_grown[k], delay, grass] });
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

/// An edit of a sequence.
pub(crate) enum Edit {
    /// Cells x0..=x1, z0..=z1 change height by `by` (dry cells only).
    Height { x0: i32, z0: i32, x1: i32, z1: i32, by: f32 },
    /// Cells x0..=x1, z0..=z1 become land at height `h` where they were none.
    Add { x0: i32, z0: i32, x1: i32, z1: i32, h: f32 },
    /// A ramp stroke (field::ramp).
    Ramp { a: Vec2, b: Vec2, width: f32 },
    /// Items placed on the lawn.
    Place(&'static [Placement]),
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

pub(crate) struct Sequence {
    pub(crate) name: &'static str,
    pub(crate) edit: Edit,
    pub(crate) centre: Vec2,
    camera: ([f32; 3], f32, f32, f32),
}

pub(crate) fn sequences() -> Vec<Sequence> {
    vec![
        Sequence { name: "raise", edit: Edit::Height { x0: -5, z0: -7, x1: -3, z1: -5, by: 1.0 }, centre: Vec2::new(-3.5, -5.5), camera: ([-3.5, 3.9, -5.5], 20.0, 30.0, 12.0) },
        Sequence { name: "lower", edit: Edit::Height { x0: 2, z0: -7, x1: 4, z1: -5, by: -1.0 }, centre: Vec2::new(3.5, -5.5), camera: ([3.5, 3.0, -5.5], 20.0, 36.0, 12.0) },
        Sequence { name: "expand", edit: Edit::Add { x0: -15, z0: 5, x1: -12, z1: 7, h: 3.5 }, centre: Vec2::new(-13.0, 6.0), camera: ([-12.5, 2.5, 5.5], 25.0, 22.0, 17.0) },
        Sequence { name: "place", edit: Edit::Place(&PLACED), centre: Vec2::new(2.6, -6.2), camera: ([2.7, 4.8, -6.3], 20.0, 26.0, 15.0) },
        Sequence { name: "ramp", edit: Edit::Ramp { a: Vec2::new(-7.0, 3.5), b: Vec2::new(-7.0, 7.5), width: 2.0 }, centre: Vec2::new(-7.0, 5.5), camera: ([-7.0, 3.0, 5.5], 35.0, 30.0, 12.0) },
    ]
}

fn view(target: [f32; 3], yaw: f32, pitch: f32, dist: f32) -> Camera {
    let (y, p) = (yaw.to_radians(), pitch.to_radians());
    let target = Vec3::from(target);
    Camera { eye: target + Vec3::new(y.sin() * p.cos(), p.sin(), y.cos() * p.cos()) * dist, target, fov_deg: 31.0 }
}

/// Applies an edit; returns the edited cells, the cell rectangle it touched and the placements.
pub(crate) fn apply(cells: &Cells, edit: &Edit) -> (Cells, (Vec2, Vec2), Vec<Placement>) {
    let mut out = cells.clone();
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
            (out, (Vec2::new(*x0 as f32, *z0 as f32), Vec2::new(*x1 as f32 + 1.0, *z1 as f32 + 1.0)), Vec::new())
        }
        Edit::Add { x0, z0, x1, z1, h } => {
            for z in *z0..=*z1 {
                for x in *x0..=*x1 {
                    out.entry((x, z)).or_insert(Cell::flat(*h, None));
                }
            }
            (out, (Vec2::new(*x0 as f32, *z0 as f32), Vec2::new(*x1 as f32 + 1.0, *z1 as f32 + 1.0)), Vec::new())
        }
        Edit::Ramp { a, b, width } => {
            let done = field::ramp(&mut out, *a, *b, *width).unwrap_or_else(|e| panic!("settle ramp refused: {e}"));
            println!("SETTLE ramp: {} cells, rise {:.2} m over {:.2} m", done.cells, done.rise, done.length);
            let (lo, hi) = (done.a.min(done.b) - Vec2::splat(*width), done.a.max(done.b) + Vec2::splat(*width));
            (out, (lo, hi), Vec::new())
        }
        Edit::Place(items) => {
            let lo = items.iter().fold(Vec2::splat(f32::MAX), |m, e| m.min(e.at)) - Vec2::splat(1.0);
            let hi = items.iter().fold(Vec2::splat(f32::MIN), |m, e| m.max(e.at)) + Vec2::splat(1.0);
            (out, (lo, hi), items.to_vec())
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

/// Renders the asked sequences. For each: the island before the edit (frame `t-before`), then the
/// edit (rebuild, settle map, upload: the latency), then the frames of the motion; with `bench`
/// three frame costs at the sequence's camera: the settled island with the shadow map cached (as
/// the other benches), the same with the shadow map redrawn every frame, and the motion running
/// (clock cycling over the whole motion, shadow map redrawn every frame).
pub fn run(s: &Settings, renderer: &mut Renderer) -> Vec<String> {
    let cells = field::load_layout(s.layout);
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
        let frame_at = |clock: f32, map: Option<&SettleMap>, items: usize| {
            let mut light = s.light;
            light[16][0] = 1.0;
            light[12][0] = -4.0;
            light[12][1] = -6.9;
            light[29][0] = camera.target.x;
            light[29][2] = camera.target.z;
            let slots = map.map_or([[-1.0, 0.0, 0.0, STEP], [0.0; 4]], |m| m.slots(clock, items));
            light[crate::render::SETTLE_SLOT] = slots[0];
            light[crate::render::SETTLE_SLOT + 1] = slots[1];
            Frame { camera, sun_dir: s.sun_dir, time: 3.0, hour: s.hour, ssao: s.ssao, ssao_blur: s.ssao_blur, debug: 0.0, light }
        };
        // Before.
        let mut library = Library::default();
        let before = crate::build_island(&cells, s.body, s.seed, Vec3::ZERO, true, s.props.as_deref(), &mut library, &[]);
        upload(renderer, &before, &library, &far, s.grass);
        renderer.render(&frame_at(-1.0, None, 0));
        let path = format!("{}/{}_{}_before.png", s.out, s.tag, seq.name);
        renderer.save_png(&path);
        println!("FRAME {path}");
        // The edit: what an interactive build would do when the stroke lands.
        let (edited, (lo, hi), placed) = apply(&cells, &seq.edit);
        let start = Instant::now();
        let mut library = Library::default();
        let after = crate::build_island(&edited, s.body, s.seed, Vec3::ZERO, true, s.props.as_deref(), &mut library, &placed);
        let rebuilt = start.elapsed().as_secs_f64() * 1000.0;
        let lap = Instant::now();
        // The dirty rectangle: what the edit touched plus 4 m (the top surface changes at most 4 m
        // from a stroke, README "Locality").
        let (lo, hi) = (lo - Vec2::splat(4.0), hi + Vec2::splat(4.0));
        let (items, regrow) = instance_table(&library, &placed, seq.centre);
        let map = build_map(&cells, &before.field, &edited, &after.field, lo, hi, seq.centre, &regrow);
        let mapped = lap.elapsed().as_secs_f64() * 1000.0;
        let lap = Instant::now();
        upload(renderer, &after, &library, &far, s.grass);
        renderer.set_settle(&map.texels, &items);
        renderer.wait();
        let uploaded = lap.elapsed().as_secs_f64() * 1000.0;
        let line = format!(
            "SETTLE {} latency: rebuild {rebuilt:.1} ms ({}), settle map {mapped:.2} ms ({} x {} texels, {:.1} x {:.1} m), upload {uploaded:.1} ms, total {:.1} ms; {} placed items",
            seq.name,
            after.timings.iter().map(|(n, ms)| format!("{n} {ms:.1}")).collect::<Vec<_>>().join(", "),
            map.nx,
            map.nz,
            hi.x - lo.x,
            hi.y - lo.y,
            rebuilt + mapped + uploaded,
            placed.len()
        );
        println!("{line}");
        lines.push(format!(
            "  {{\"sequence\": \"{}\", \"rebuild_ms\": {rebuilt:.2}, \"stages_ms\": {{{}}}, \"settle_map_ms\": {mapped:.3}, \"texels\": {}, \"upload_ms\": {uploaded:.2}}}",
            seq.name,
            after.timings.iter().map(|(n, ms)| format!("\"{n}\": {ms:.2}")).collect::<Vec<_>>().join(", "),
            map.nx * map.nz
        ));
        for t in frame_times(&s.times) {
            renderer.render(&frame_at(t, Some(&map), items.len()));
            let path = format!("{}/{}_{}_t{:04}.png", s.out, s.tag, seq.name, (t * 1000.0).round() as i32);
            renderer.save_png(&path);
            println!("FRAME {path}");
        }
        if s.bench {
            let still = renderer.bench(&frame_at(END + 1.0, Some(&map), items.len()), 120);
            let shadowed = renderer.bench_settle(&frame_at(END + 1.0, Some(&map), items.len()), 120, None);
            let moving = renderer.bench_settle(&frame_at(0.0, Some(&map), items.len()), 120, Some(END));
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

fn upload(renderer: &mut Renderer, built: &crate::Built, library: &Library, far: &crate::mesh::Mesh, grass: bool) {
    let mut solid = crate::mesh::Mesh::default();
    solid.append(&built.solid);
    let casters = solid.vertices.len();
    solid.append(far);
    renderer.set_scene(&solid.vertices, casters, &built.water);
    renderer.set_props(library);
    if grass {
        renderer.set_grass(&built.grass);
    }
    renderer.clear_settle();
}
