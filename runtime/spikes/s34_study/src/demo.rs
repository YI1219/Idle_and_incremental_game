//! Round k5: the construction demonstration (owner request of 2026-11-26): an island built from one
//! standalone mound by brush strokes, recorded frame by frame.
//!
//! The script (`--demo=FILE`, JSON) gives the starting mound, the camera's keyframes and the
//! strokes: tool, the pointer's path over the island, radius and the tool's settings, how long the
//! pointer takes to draw it and how long to watch afterwards. Each stroke goes through
//! `brush::apply` (the edit path of the runtime), the island is rebuilt as after any edit, and the
//! appear-and-settle (or removal) motion of settle.rs plays from the moment the stroke is released.
//! While a stroke is drawn, the brush's outline on the ground is printed for every frame
//! (`OVERLAY` lines, screen pixels), so the recording can show the pointer.
//!
//! What this does not exercise: the mouse and the picking of a point under it (the paths are
//! given in island coordinates, as picking would deliver them), and the jade preview while
//! dragging. Everything from the stroke onward is the runtime's own path.

use std::time::Instant;

use glam::{Mat4, Vec2, Vec3, Vec4};

use crate::brush::{self, Stroke, Tool};
use crate::field::{Cell, Cells};
use crate::props::{Items, Placement};
use crate::render::{Camera, Frame, Renderer};
use crate::settle::{self, Island, Transition};

struct Key {
    t: f32,
    target: Vec3,
    yaw: f32,
    pitch: f32,
    dist: f32,
}

struct Step {
    stroke: Stroke,
    drag: f32,
    after: f32,
    caption: String,
}

pub struct Script {
    mound: (Vec2, f32, f32, f32, f32),
    fps: f32,
    hold_start: f32,
    hold_end: f32,
    keys: Vec<Key>,
    steps: Vec<Step>,
}

fn v2(v: &serde_json::Value) -> Vec2 {
    Vec2::new(v[0].as_f64().unwrap() as f32, v[1].as_f64().unwrap() as f32)
}

fn f(v: &serde_json::Value, key: &str, default: f32) -> f32 {
    v.get(key).and_then(|x| x.as_f64()).map_or(default, |x| x as f32)
}

pub fn load(path: &str) -> Script {
    let text = std::fs::read_to_string(path).unwrap_or_else(|e| panic!("cannot read {path}: {e}"));
    let j: serde_json::Value = serde_json::from_str(&text).expect("demo json");
    let m = &j["mound"];
    let mound = (v2(&m["centre"]), f(m, "radius", 3.5), f(m, "height", 1.0), f(m, "crown_radius", 1.8), f(m, "crown_height", 1.5));
    let keys = j["camera"]
        .as_array()
        .expect("camera")
        .iter()
        .map(|k| Key {
            t: f(k, "t", 0.0),
            target: Vec3::new(k["target"][0].as_f64().unwrap() as f32, k["target"][1].as_f64().unwrap() as f32, k["target"][2].as_f64().unwrap() as f32),
            yaw: f(k, "yaw", 20.0),
            pitch: f(k, "pitch", 30.0),
            dist: f(k, "dist", 20.0),
        })
        .collect();
    let steps = j["steps"]
        .as_array()
        .expect("steps")
        .iter()
        .map(|s| {
            let tool = Tool::parse(s["tool"].as_str().expect("tool")).expect("known tool");
            let item = s.get("item").map(|it| Placement {
                kind: Box::leak(it["kind"].as_str().expect("item kind").to_string().into_boxed_str()),
                at: Vec2::ZERO,
                yaw: f(it, "yaw", 0.0),
                size: f(it, "size", 1.0),
                pick: it.get("pick").and_then(|p| p.as_u64()).unwrap_or(0) as usize,
            });
            Step {
                stroke: Stroke { tool, path: s["path"].as_array().expect("path").iter().map(v2).collect(), radius: f(s, "radius", 2.2), level: f(s, "level", 0.0), width: f(s, "width", 2.0), item },
                drag: f(s, "drag", 0.8),
                after: f(s, "after", 1.4),
                caption: s.get("caption").and_then(|c| c.as_str()).unwrap_or("").to_string(),
            }
        })
        .collect();
    Script { mound, fps: f(&j, "fps", 30.0), hold_start: f(&j, "hold_start", 1.5), hold_end: f(&j, "hold_end", 2.5), keys, steps }
}

/// The starting island: one round mound (a disc of cells at `height`, a crown at `crown_height`).
fn mound_cells(s: &Script) -> Cells {
    let (c, r, h, cr, ch) = s.mound;
    let mut cells = Cells::new();
    let n = r.ceil() as i32 + 1;
    for z in -n..=n {
        for x in -n..=n {
            let p = Vec2::new(x as f32 + 0.5, z as f32 + 0.5);
            let d = (p - c).length();
            if d <= r {
                cells.insert((x + c.x.floor() as i32, z + c.y.floor() as i32), Cell::flat(if d <= cr { ch } else { h }, None));
            }
        }
    }
    cells
}

fn camera_at(keys: &[Key], t: f32) -> Camera {
    let i = keys.iter().rposition(|k| k.t <= t).unwrap_or(0);
    let (a, b) = (&keys[i], &keys[(i + 1).min(keys.len() - 1)]);
    let u = if b.t > a.t { ((t - a.t) / (b.t - a.t)).clamp(0.0, 1.0) } else { 0.0 };
    let u = u * u * (3.0 - 2.0 * u);
    let lerp = |x: f32, y: f32| x + (y - x) * u;
    let (yaw, pitch, dist) = (lerp(a.yaw, b.yaw).to_radians(), lerp(a.pitch, b.pitch).to_radians(), lerp(a.dist, b.dist));
    let target = a.target.lerp(b.target, u);
    Camera { eye: target + Vec3::new(yaw.sin() * pitch.cos(), pitch.sin(), yaw.cos() * pitch.cos()) * dist, target, fov_deg: 31.0 }
}

fn view_proj(camera: &Camera, width: u32, height: u32) -> Mat4 {
    Mat4::perspective_rh(camera.fov_deg.to_radians(), width as f32 / height as f32, 0.5, 4000.0) * Mat4::look_at_rh(camera.eye, camera.target, Vec3::Y)
}

/// Screen pixels of a ground point (None behind the camera).
fn project(m: &Mat4, p: Vec3, width: u32, height: u32) -> Option<(f32, f32)> {
    let c = *m * Vec4::new(p.x, p.y, p.z, 1.0);
    if c.w <= 0.01 {
        return None;
    }
    Some(((c.x / c.w * 0.5 + 0.5) * width as f32, (0.5 - c.y / c.w * 0.5) * height as f32))
}

pub struct Settings<'a> {
    pub script: &'a str,
    pub props: std::path::PathBuf,
    pub body: crate::body::Kind,
    pub seed: u32,
    pub out: &'a str,
    pub tag: &'a str,
    pub light: [[f32; 4]; crate::render::LIGHT_SLOTS],
    pub sun_dir: Vec3,
    pub hour: f32,
    pub ssao: bool,
    pub ssao_blur: bool,
    pub width: u32,
    pub height: u32,
    pub grass: bool,
    /// Only the island before the first stroke and after the last, from `stills` cameras.
    pub stills: Option<Vec<(String, Camera)>>,
}

/// Plays the script. Prints `FRAME`, `OVERLAY` and per-stroke `DEMO` lines (with the edit's
/// latency: rebuild, transition, upload).
pub fn run(s: &Settings, renderer: &mut Renderer) {
    let script = load(s.script);
    let far = crate::far_mountains();
    let build = |cells: Cells, items: &Items| settle::build(s.body, s.seed, Some(s.props.as_path()), cells, items);
    let mut items = Items { scene: false, placed: Vec::new(), removed: Vec::new() };
    let mut island = build(mound_cells(&script), &items);
    println!("DEMO start: one mound, {} cells", island.cells.len());
    let frame_of = |camera: Camera, clock: f32, motion: Option<(&Transition, [f32; 4])>| {
        let mut light = s.light;
        light[16][0] = 1.0;
        light[12][0] = -4.0;
        light[12][1] = -6.9;
        light[29][0] = camera.target.x;
        light[29][2] = camera.target.z;
        settle::settle_slots(&mut light, clock, motion);
        Frame { camera, sun_dir: s.sun_dir, time: 3.0, hour: s.hour, ssao: s.ssao, ssao_blur: s.ssao_blur, debug: 0.0, light }
    };
    if let Some(stills) = &s.stills {
        settle::upload(renderer, &island, &far, s.grass, None);
        for (name, cam) in stills {
            renderer.render(&frame_of(*cam, -1.0, None));
            let path = format!("{}/{}_before_{name}.png", s.out, s.tag);
            renderer.save_png(&path);
            println!("FRAME {path}");
        }
        for step in &script.steps {
            let mut cells = island.cells.clone();
            let done = brush::apply(&mut cells, &mut items, &island.library, &step.stroke);
            if let Some(why) = &done.refused {
                println!("DEMO {}: refused ({why})", step.stroke.tool.name());
            } else {
                island = build(cells, &items);
            }
        }
        settle::upload(renderer, &island, &far, s.grass, None);
        for (name, cam) in stills {
            renderer.render(&frame_of(*cam, -1.0, None));
            let path = format!("{}/{}_after_{name}.png", s.out, s.tag);
            renderer.save_png(&path);
            println!("FRAME {path}");
        }
        println!("DEMO end: {} cells, {} items", island.cells.len(), island.library.instances.len());
        return;
    }
    let dt = 1.0 / script.fps;
    let mut frame = 0usize;
    let mut t = 0.0_f32;
    let mut motion: Option<(Transition, [f32; 4], f32)> = None;
    settle::upload(renderer, &island, &far, s.grass, None);
    let mut emit = |renderer: &mut Renderer, t: f32, motion: &Option<(Transition, [f32; 4], f32)>, overlay: String, caption: &str, frame: &mut usize| {
        let camera = camera_at(&script.keys, t);
        let fr = match motion {
            Some((m, ranges, start)) => frame_of(camera, t - start, Some((m, *ranges))),
            None => frame_of(camera, -1.0, None),
        };
        renderer.render(&fr);
        let path = format!("{}/{}_{:05}.png", s.out, s.tag, *frame);
        renderer.save_png(&path);
        println!("FRAME {path}");
        println!("OVERLAY {} {:.3}|{}|{}", *frame, t, caption, overlay);
        *frame += 1;
    };
    // The mound alone.
    while t < script.hold_start {
        emit(renderer, t, &motion, String::new(), "One standalone mound", &mut frame);
        t += dt;
    }
    for (index, step) in script.steps.iter().enumerate() {
        let caption = format!("{}. {}{}", index + 1, step.stroke.tool.name(), if step.caption.is_empty() { String::new() } else { format!(": {}", step.caption) });
        // Drawing the stroke: the pointer moves along the path.
        let start = t;
        while t < start + step.drag {
            let u = ((t - start) / step.drag.max(0.01)).clamp(0.0, 1.0);
            let camera = camera_at(&script.keys, t);
            let m = view_proj(&camera, s.width, s.height);
            let overlay = cursor(&step.stroke, u, &island, &m, s.width, s.height);
            emit(renderer, t, &motion, overlay, &caption, &mut frame);
            t += dt;
        }
        // Release: the edit.
        let clock = Instant::now();
        let mut cells = island.cells.clone();
        let mut next_items = items.clone();
        let done = brush::apply(&mut cells, &mut next_items, &island.library, &step.stroke);
        if let Some(why) = &done.refused {
            println!("DEMO step {} {}: refused ({why})", index + 1, step.stroke.tool.name());
        } else {
            let mut after = build(cells, &next_items);
            let rebuilt = clock.elapsed().as_secs_f64() * 1000.0;
            let lap = Instant::now();
            let lo = done.lo - Vec2::splat(4.0);
            let hi = done.hi + Vec2::splat(4.0);
            let tr = settle::transition(&island, &mut after, lo, hi, done.centre, &done.placed);
            let mapped = lap.elapsed().as_secs_f64() * 1000.0;
            let lap = Instant::now();
            let ranges = settle::upload(renderer, &after, &far, s.grass, Some(&tr));
            renderer.wait();
            let uploaded = lap.elapsed().as_secs_f64() * 1000.0;
            println!(
                "DEMO step {} {}: {} changed, {} cells, rebuild {rebuilt:.1} ms ({}), transition {mapped:.2} ms, upload {uploaded:.1} ms",
                index + 1,
                step.stroke.tool.name(),
                done.changed,
                after.cells.len(),
                after.built.timings.iter().map(|(n, ms)| format!("{n} {ms:.1}")).collect::<Vec<_>>().join(", ")
            );
            items = next_items;
            island = Island { cells: after.cells, built: after.built, library: after.library };
            motion = Some((tr, ranges, t));
        }
        let start = t;
        while t < start + step.after {
            emit(renderer, t, &motion, String::new(), &caption, &mut frame);
            t += dt;
        }
    }
    let start = t;
    while t < start + script.hold_end {
        emit(renderer, t, &motion, String::new(), "Built from one mound with the brush tools", &mut frame);
        t += dt;
    }
    println!("DEMO end: {} frames, {} cells, {} items", frame, island.cells.len(), island.library.instances.len());
}

/// The brush's outline for frame `u` of a stroke being drawn, as screen pixels "x,y x,y ...;"
/// (one polyline per shape; a ramp shows its strip, items a ring per point reached).
fn cursor(stroke: &Stroke, u: f32, island: &Island, m: &Mat4, w: u32, h: u32) -> String {
    let path = &stroke.path;
    // The pointer's position along the path at u (by length).
    let lengths: Vec<f32> = path.windows(2).map(|p| (p[1] - p[0]).length()).collect();
    let total: f32 = lengths.iter().sum();
    let mut left = total * u;
    let mut at = path[0];
    let mut reached = 1;
    for (i, l) in lengths.iter().enumerate() {
        if left <= *l || i + 1 == lengths.len() {
            at = path[i].lerp(path[i + 1], (left / l.max(1e-4)).clamp(0.0, 1.0));
            reached = i + 1;
            break;
        }
        left -= l;
        reached = i + 2;
    }
    let ground = |p: Vec2| -> f32 {
        let f = &island.built.field;
        if f.inside(p) { f.height_at(p) + 0.06 } else { island.cells.values().map(|c| c.h).fold(f32::MIN, f32::max).min(f.height_at(p)) + 0.06 }
    };
    let ring = |c: Vec2, r: f32| -> String {
        (0..=48)
            .filter_map(|k| {
                let a = k as f32 / 48.0 * std::f32::consts::TAU;
                let p = c + Vec2::new(a.cos(), a.sin()) * r;
                project(m, Vec3::new(p.x, ground(p), p.y), w, h).map(|(x, y)| format!("{x:.1},{y:.1}"))
            })
            .collect::<Vec<_>>()
            .join(" ")
    };
    match stroke.tool {
        Tool::Place => path[..reached.min(path.len())].iter().map(|p| ring(*p, 0.35)).collect::<Vec<_>>().join(";"),
        Tool::Ramp => {
            let a = path[0];
            let d = (at - a).normalize_or_zero();
            let side = Vec2::new(-d.y, d.x) * stroke.width * 0.5;
            let corners = [a + side, at + side, at - side, a - side, a + side];
            corners.iter().filter_map(|p| project(m, Vec3::new(p.x, ground(*p), p.y), w, h).map(|(x, y)| format!("{x:.1},{y:.1}"))).collect::<Vec<_>>().join(" ")
        }
        _ => {
            let mut shapes = vec![ring(at, stroke.radius)];
            // The trail already painted, as a thin line.
            let mut trail: Vec<Vec2> = path[..reached.min(path.len())].to_vec();
            trail.push(at);
            shapes.push(trail.iter().filter_map(|p| project(m, Vec3::new(p.x, ground(*p), p.y), w, h).map(|(x, y)| format!("{x:.1},{y:.1}"))).collect::<Vec<_>>().join(" "));
            shapes.join(";")
        }
    }
}

