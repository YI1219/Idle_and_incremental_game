//! Studies S3 (look) and S4 (island generation) on one tool. Throwaway code.
//!
//!   s34_study --layout=runtime/data/reference/layout_7301_0.json | --synthetic=4096
//!             [--seed=7301] [--body=karst|hull] [--look=a|b|c] [--hour=day|dusk|night]
//!             [--scene=single|trio] [--views=whole,game|all|wallpaper]
//!             [--cameras=runtime/data/reference/cameras.json]
//!             [--size=3024x1964] [--scale=2] [--out=DIR] [--tag=NAME]
//!             [--metrics=FILE.json] [--bench] [--edit-test]
mod body;
mod decor;
mod field;
mod mesh;
mod render;
mod water;

use std::time::Instant;

use glam::{Vec2, Vec3};

use field::Cells;
use mesh::{Family, Mesh, Paint, Rng};
use render::{Camera, Frame, Renderer};

struct Args {
    layout: Option<String>,
    synthetic: usize,
    seed: u32,
    body: body::Kind,
    look: String,
    hour: String,
    scene: String,
    views: String,
    cameras: String,
    width: u32,
    height: u32,
    scale: u32,
    out: String,
    tag: String,
    metrics: Option<String>,
    bench: bool,
    edit_test: bool,
}

fn parse_args() -> Args {
    let mut args = Args {
        layout: None,
        synthetic: 0,
        seed: 7301,
        body: body::Kind::Karst,
        look: "b".into(),
        hour: "day".into(),
        scene: "single".into(),
        views: "whole".into(),
        cameras: "runtime/data/reference/cameras.json".into(),
        width: 3024,
        height: 1964,
        scale: 2,
        out: "/tmp/tsw_study".into(),
        tag: "study".into(),
        metrics: None,
        bench: false,
        edit_test: false,
    };
    for arg in std::env::args().skip(1) {
        let (key, value) = arg.split_once('=').unwrap_or((arg.as_str(), ""));
        match key {
            "--layout" => args.layout = Some(value.to_string()),
            "--synthetic" => args.synthetic = value.parse().expect("synthetic cell count"),
            "--seed" => args.seed = value.parse().expect("seed"),
            "--body" => args.body = if value == "hull" { body::Kind::Hull } else { body::Kind::Karst },
            "--look" => args.look = value.to_string(),
            "--hour" => args.hour = value.to_string(),
            "--scene" => args.scene = value.to_string(),
            "--views" => args.views = value.to_string(),
            "--cameras" => args.cameras = value.to_string(),
            "--size" => {
                let (w, h) = value.split_once('x').expect("size as WxH");
                args.width = w.parse().expect("width");
                args.height = h.parse().expect("height");
            }
            "--scale" => args.scale = value.parse().expect("scale"),
            "--out" => args.out = value.to_string(),
            "--tag" => args.tag = value.to_string(),
            "--metrics" => args.metrics = Some(value.to_string()),
            "--bench" => args.bench = true,
            "--edit-test" => args.edit_test = true,
            other => panic!("unknown argument {other}"),
        }
    }
    args
}

/// The palette of an hour. Slots are named in shader.wgsl.
fn palette(hour: &str) -> ([[f32; 4]; 16], Vec3, f32) {
    let sun = |elevation: f32, azimuth: f32| {
        let (e, a) = (elevation.to_radians(), azimuth.to_radians());
        Vec3::new(a.sin() * e.cos(), e.sin(), a.cos() * e.cos()).normalize()
    };
    match hour {
        "dusk" => (
            [
                [1.13, 0.93, 0.74, 0.60],
                [0.52, 0.58, 0.66, 1.0],
                [0.55, 0.56, 0.74, 1.0],
                [0.44, 0.54, 0.62, 1.0],
                [0.56, 0.54, 0.68, 1.0],
                [0.94, 0.85, 0.76, 0.96],
                [0.56, 0.61, 0.74, 1.0],
                [0.96, 0.81, 0.68, 1.0],
                [0.25, 0.19, 0.20, 0.78],
                [0.62, 0.74, 0.66, 1.0],
                [0.24, 0.38, 0.46, 1.0],
                [0.52, 0.54, 0.38, 0.40],
                [0.97, 0.87, 0.77, 1.0],
                [0.76, 0.73, 0.80, 1.0],
                [0.88, 0.79, 0.76, 0.0007],
                [-5.5, -16.5, 1.0, 0.0],
            ],
            sun(22.0, 34.0),
            0.76,
        ),
        "night" => (
            [
                [0.60, 0.72, 0.90, 0.62],
                [0.50, 0.60, 0.80, 1.0],
                [0.50, 0.58, 0.82, 1.0],
                [0.46, 0.58, 0.78, 1.0],
                [0.50, 0.56, 0.78, 1.0],
                [0.42, 0.50, 0.60, 0.96],
                [0.17, 0.23, 0.35, 1.0],
                [0.36, 0.44, 0.56, 1.0],
                [0.09, 0.11, 0.17, 0.80],
                [0.34, 0.54, 0.58, 1.0],
                [0.11, 0.24, 0.34, 1.0],
                [0.40, 0.50, 0.42, 0.40],
                [0.47, 0.55, 0.65, 1.0],
                [0.31, 0.39, 0.51, 1.0],
                [0.36, 0.44, 0.56, 0.0007],
                [-5.5, -16.5, 0.80, 0.0],
            ],
            sun(28.0, 28.0),
            0.0,
        ),
        _ => (
            [
                [1.07, 1.00, 0.89, 0.60],
                [0.56, 0.70, 0.66, 1.0],
                [0.50, 0.60, 0.78, 1.0],
                [0.50, 0.67, 0.66, 1.0],
                [0.60, 0.62, 0.72, 1.0],
                [0.91, 0.90, 0.85, 0.96],
                [0.62, 0.73, 0.78, 1.0],
                [0.89, 0.89, 0.85, 1.0],
                [0.21, 0.19, 0.18, 0.86],
                [0.44, 0.73, 0.65, 1.0],
                [0.15, 0.41, 0.42, 1.0],
                [0.50, 0.58, 0.40, 0.45],
                [0.94, 0.93, 0.89, 1.0],
                [0.81, 0.86, 0.89, 1.0],
                [0.80, 0.85, 0.88, 0.0007],
                [-5.5, -16.5, 1.0, 0.0],
            ],
            sun(25.5, 38.0),
            0.29,
        ),
    }
}

fn look(name: &str) -> [f32; 4] {
    match name {
        // A: the new lighting model alone. B: line and flat wash. C: B with brushwork.
        "a" => [0.0, 0.0, 0.0, 0.0],
        "c" => [1.0, 1.0, 1.0, 1.0],
        _ => [1.0, 1.0, 0.0, 0.6],
    }
}

/// Rock stacks standing in the cloud sea: low ones near the island, tall ones far off.
fn far_peaks(seed: u32) -> Mesh {
    let mut mesh = Mesh::default();
    let mut rng = Rng::new(seed, 77);
    let mut peak = |mesh: &mut Mesh, at: Vec2, height: f32, radius: f32, rng: &mut Rng| {
        // A rounded tower with uneven shoulders, not a crystal: nine sides, six levels, each ring its own wobble.
        let sides = 9;
        let base = -27.0;
        let levels = [(0.0, 1.20), (0.30, 1.02), (0.55, 0.86), (0.75, 0.66), (0.90, 0.40), (0.97, 0.18), (1.0, 0.0)];
        let spin = rng.range(0.0, 6.28);
        let tip = Vec2::new(rng.range(-0.35, 0.35), rng.range(-0.35, 0.35)) * radius;
        let wobble: Vec<f32> = (0..sides * levels.len()).map(|_| rng.range(0.72, 1.22)).collect();
        let ring = |level: usize, k: usize| -> Vec3 {
            let (t, r) = levels[level];
            let angle = spin + k as f32 / sides as f32 * std::f32::consts::TAU;
            let p = at + tip * t + Vec2::new(angle.cos(), angle.sin()) * radius * r * wobble[level * sides + k % sides];
            Vec3::new(p.x, base + height * t, p.y)
        };
        let tone = |t: f32| Vec3::new(0.86, 0.88, 0.87).lerp(Vec3::new(0.58, 0.68, 0.66), t * t);
        for level in 0..levels.len() - 1 {
            for k in 0..sides {
                let k2 = (k + 1) % sides;
                let (a, b, c, d) = (ring(level, k), ring(level, k2), ring(level + 1, k2), ring(level + 1, k));
                let n = (b - a).cross(d - a).normalize_or_zero();
                let (c0, c1) = (tone(levels[level].0), tone(levels[level + 1].0));
                let paint = Paint::new(Family::Stone).sky(1.0).line(0.12).id(20);
                mesh.tri_full([a, b, c], [n; 3], [c0, c0, c1], [paint; 3]);
                mesh.tri_full([a, c, d], [n; 3], [c0, c1, c1], [paint; 3]);
            }
        }
    };
    for cluster in 0..34 {
        let near = cluster < 10;
        let angle = rng.range(0.0, std::f32::consts::TAU);
        let distance = if near { rng.range(120.0, 250.0) } else { rng.range(320.0, 1100.0) };
        let centre = Vec2::new(angle.cos(), angle.sin()) * distance;
        for _ in 0..2 + (rng.next() * 3.0) as usize {
            let at = centre + Vec2::new(rng.range(-1.0, 1.0), rng.range(-1.0, 1.0)) * distance * 0.14;
            let height = if near { rng.range(15.0, 34.0) } else { rng.range(80.0, 230.0) * (0.6 + distance / 1100.0) };
            let radius = height * rng.range(0.16, 0.28);
            peak(&mut mesh, at, height, radius, &mut rng);
        }
    }
    mesh
}

struct Built {
    solid: Mesh,
    water: Vec<water::WaterVertex>,
    faces: Vec<body::Face>,
    columns: usize,
    timings: Vec<(&'static str, f64)>,
    parts: Vec<(&'static str, usize)>,
}

fn build_island(cells: &Cells, kind: body::Kind, seed: u32, origin: Vec3, courtyard: bool) -> Built {
    let mut timings = Vec::new();
    let mut parts = Vec::new();
    let mut clock = Instant::now();
    let mut lap = |name: &'static str, timings: &mut Vec<(&'static str, f64)>| {
        timings.push((name, clock.elapsed().as_secs_f64() * 1000.0));
        clock = Instant::now();
    };
    let field = field::Field::build(cells);
    lap("fields", &mut timings);
    let top = field::build_top(&field, &field::TopColours::default(), seed);
    lap("top", &mut timings);
    let outlines = field::outlines(cells, &field, 0.5);
    let body = body::build_body(kind, &field, &outlines, &body::StoneColours::default(), seed, 0.5);
    lap("body", &mut timings);
    let colours = decor::DecorColours::default();
    let things = if courtyard { decor::courtyard(cells, &field, &colours, seed) } else { decor::scatter(cells, &field, &colours, seed) };
    let tufts = decor::tufts(&field, &top.rim, &colours, seed, 1.0);
    lap("decor", &mut timings);
    parts.push(("top", top.mesh.triangles()));
    parts.push(("body", body.mesh.triangles()));
    parts.push(("decor", things.triangles()));
    parts.push(("tufts", tufts.triangles()));
    let mut solid = Mesh::default();
    solid.append(&top.mesh);
    solid.append(&body.mesh);
    solid.append(&things);
    solid.append(&tufts);
    solid.offset(origin);
    Built { solid, water: water::build_water(cells, origin), faces: body.faces, columns: body.columns, timings, parts }
}

/// How far from an edit the rim plan changes: the locality test of S4.
fn edit_test(cells: &Cells, seed: u32) -> String {
    let plan = |cells: &Cells| {
        let field = field::Field::build(cells);
        let outlines = field::outlines(cells, &field, 0.5);
        let outer = outlines.iter().find(|o| !o.is_hole).expect("outline");
        body::plan_faces(outer, &field, seed, 0.5)
    };
    let before = plan(cells);
    let mut lines = Vec::new();
    // Three strokes at the rim: add a 3 x 3 patch outside it, remove one inside it, raise one on it.
    let mut rim: Vec<(i32, i32)> = cells.keys().copied().filter(|&(x, z)| !cells.contains_key(&(x + 1, z))).collect();
    rim.sort();
    for (name, pick) in [("expand", rim.len() / 5), ("contract", rim.len() / 2), ("raise", rim.len() * 4 / 5)] {
        let at = rim[pick];
        let mut edited = cells.clone();
        for dz in -1..=1 {
            for dx in -1..=1 {
                let key = if name == "expand" { (at.0 + 2 + dx, at.1 + dz) } else { (at.0 - 1 + dx, at.1 + dz) };
                match name {
                    "expand" => {
                        edited.entry(key).or_insert(field::Cell { h: cells[&at].h, water: None });
                    }
                    "contract" => {
                        edited.remove(&key);
                    }
                    _ => {
                        if let Some(cell) = edited.get_mut(&key) {
                            if cell.water.is_none() {
                                cell.h += 1.0;
                            }
                        }
                    }
                }
            }
        }
        let after = plan(&edited);
        let centre = Vec2::new(at.0 as f32 + if name == "expand" { 2.5 } else { -0.5 }, at.1 as f32 + 0.5);
        let key = |f: &body::Face| ((f.a.x * 5.0).round() as i32, (f.a.y * 5.0).round() as i32, (f.b.x * 5.0).round() as i32, (f.b.y * 5.0).round() as i32, (f.top * 4.0).round() as i32);
        let old: std::collections::HashSet<_> = before.iter().map(key).collect();
        let new: std::collections::HashSet<_> = after.iter().map(key).collect();
        let mut farthest: f32 = 0.0;
        let mut changed = 0;
        for face in before.iter().filter(|f| !new.contains(&key(f))).chain(after.iter().filter(|f| !old.contains(&key(f)))) {
            changed += 1;
            let nearest = (face.a - centre).length().min((face.b - centre).length());
            farthest = farthest.max(nearest);
        }
        lines.push(format!("  {{\"stroke\": \"{name}\", \"at\": [{}, {}], \"faces_before\": {}, \"faces_after\": {}, \"faces_changed\": {changed}, \"farthest_change_m\": {farthest:.2}}}", at.0, at.1, before.len(), after.len()));
        println!("EDIT {name:8} at {at:?}: {changed} faces changed, farthest {farthest:.2} m from the stroke");
    }
    lines.join(",\n")
}

fn main() {
    let args = parse_args();
    let cells = match (&args.layout, args.synthetic) {
        (Some(path), _) => field::load_layout(path),
        (None, count) if count > 0 => field::synthetic(count, args.seed),
        _ => panic!("give --layout=FILE or --synthetic=COUNT"),
    };
    let courtyard = args.layout.is_some();
    let total = Instant::now();
    let main_island = build_island(&cells, args.body, args.seed, Vec3::ZERO, courtyard);
    let build_ms = total.elapsed().as_secs_f64() * 1000.0;
    let mut solid = Mesh::default();
    solid.append(&main_island.solid);
    let mut water = main_island.water.clone();
    if args.scene == "trio" {
        // Two more islands, staggered in space and height, built by the same code.
        let folder = std::path::Path::new(args.layout.as_deref().unwrap_or("runtime/data/reference/x")).parent().unwrap().to_path_buf();
        for (file, seed, origin) in [("layout_4242_1.json", 4242, Vec3::new(56.0, 10.5, -36.0)), ("layout_913_2.json", 913, Vec3::new(-52.0, -8.5, 20.0))] {
            let other = field::load_layout(folder.join(file).to_str().unwrap());
            let built = build_island(&other, args.body, seed, origin, true);
            solid.append(&built.solid);
            water.extend_from_slice(&built.water);
        }
    }
    let casters = solid.vertices.len();
    solid.append(&far_peaks(args.seed));
    println!(
        "island: {} cells, {} faces, {} columns, {} triangles ({}), built in {:.1} ms ({})",
        cells.len(),
        main_island.faces.len(),
        main_island.columns,
        main_island.solid.triangles(),
        main_island.parts.iter().map(|(n, c)| format!("{n} {c}")).collect::<Vec<_>>().join(", "),
        build_ms,
        main_island.timings.iter().map(|(n, ms)| format!("{n} {ms:.1}")).collect::<Vec<_>>().join(", ")
    );
    let metrics = body::form_metrics(&main_island.faces);
    println!(
        "form: {} faces, widths {:.1} to {:.1} m (spread {:.2}), step spread {:.2} m, longest alike run {} faces / {:.1} m",
        metrics.faces, metrics.width_min, metrics.width_max, metrics.width_spread, metrics.step_spread, metrics.longest_like_run, metrics.longest_like_run_m
    );
    let edit_json = if args.edit_test { edit_test(&cells, args.seed) } else { String::new() };

    // Cameras: the frozen project's review set, plus a low wallpaper view for several islands.
    let mut cameras: Vec<(String, Camera)> = Vec::new();
    let text = std::fs::read_to_string(&args.cameras).unwrap_or_else(|e| panic!("cannot read {}: {e}", args.cameras));
    let json: serde_json::Value = serde_json::from_str(&text).expect("cameras json");
    for entry in json["cameras"].as_array().expect("cameras") {
        let centre = [entry["center"][0].as_f64().unwrap() as f32, entry["center"][1].as_f64().unwrap() as f32];
        cameras.push((entry["name"].as_str().unwrap().to_string(), Camera::orbit(centre, entry["height"].as_f64().unwrap() as f32, entry["yaw"].as_f64().unwrap() as f32, entry["pitch"].as_f64().unwrap() as f32)));
    }
    cameras.push(("wallpaper".to_string(), Camera { eye: Vec3::new(34.0, 21.0, 92.0), target: Vec3::new(2.0, 1.5, -6.0), fov_deg: 31.0 }));
    if args.synthetic > 0 {
        // A synthetic island has its own size: frame it whole and close.
        let reach = cells.keys().map(|&(x, z)| Vec2::new(x as f32, z as f32).length()).fold(0.0, f32::max);
        cameras.retain(|(name, _)| name != "whole" && name != "game");
        cameras.push(("whole".to_string(), Camera::orbit([0.0, 0.0], reach * 1.35, 16.0, 30.0)));
        cameras.push(("game".to_string(), Camera::orbit([reach * 0.2, reach * 0.1], reach * 0.55, 16.0, 27.0)));
    }
    let wanted: Vec<&str> = args.views.split(',').collect();

    let mut renderer = Renderer::new(args.width, args.height, args.scale);
    renderer.set_scene(&solid.vertices, casters, &water);
    let (pal, sun_dir, hour) = palette(&args.hour);
    std::fs::create_dir_all(&args.out).expect("output folder");
    let mut bench_lines = Vec::new();
    for (name, camera) in cameras.iter() {
        if !(wanted.contains(&"all") && name != "wallpaper") && !wanted.contains(&name.as_str()) {
            continue;
        }
        let frame = Frame { camera: *camera, sun_dir, time: 3.0, hour, look: look(&args.look), palette: pal };
        renderer.render(&frame);
        let path = format!("{}/{}_{}.png", args.out, args.tag, name);
        renderer.save_png(&path);
        println!("FRAME {path}");
        if args.bench {
            let ms = renderer.bench(&frame, 120);
            println!("BENCH {name}: {ms:.2} ms a frame at {}x{} with {}x supersampling", args.width, args.height, args.scale);
            bench_lines.push(format!("  {{\"view\": \"{name}\", \"ms\": {ms:.3}}}"));
        }
    }
    if let Some(path) = &args.metrics {
        let widths: Vec<String> = main_island.faces.iter().map(|f| format!("{:.1}", f.width)).collect();
        let text = format!(
            "{{\n \"cells\": {},\n \"body\": \"{:?}\",\n \"triangles\": {},\n \"parts\": {{{}}},\n \"build_ms\": {:.2},\n \"stages_ms\": {{{}}},\n \"faces\": {},\n \"columns\": {},\n \"face_widths_m\": [{}],\n \"width_min_m\": {:.2},\n \"width_max_m\": {:.2},\n \"width_spread\": {:.3},\n \"step_spread_m\": {:.3},\n \"longest_alike_run\": {},\n \"longest_alike_run_m\": {:.2},\n \"edit_locality\": [\n{}\n ],\n \"bench\": [\n{}\n ]\n}}\n",
            cells.len(),
            args.body,
            main_island.solid.triangles(),
            main_island.parts.iter().map(|(n, c)| format!("\"{n}\": {c}")).collect::<Vec<_>>().join(", "),
            build_ms,
            main_island.timings.iter().map(|(n, ms)| format!("\"{n}\": {ms:.2}")).collect::<Vec<_>>().join(", "),
            metrics.faces,
            main_island.columns,
            widths.join(", "),
            metrics.width_min,
            metrics.width_max,
            metrics.width_spread,
            metrics.step_spread,
            metrics.longest_like_run,
            metrics.longest_like_run_m,
            edit_json,
            bench_lines.join(",\n")
        );
        std::fs::write(path, text).expect("write metrics");
    }
}
