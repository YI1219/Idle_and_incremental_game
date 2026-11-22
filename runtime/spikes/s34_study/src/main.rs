//! Studies S3 (look) and S4 (island generation) on one tool. Throwaway code.
//!
//!   s34_study --layout=runtime/data/reference/layout_7301_0.json | --synthetic=4096
//!             [--seed=7301] [--body=karst|hull] [--look=n] [--hour=day|dusk|night] [--ssao=on|off|noblur] [--debug=ao]
//!             [--scene=single|trio] [--views=whole,game|all|wallpaper]
//!             [--cameras=runtime/data/reference/cameras.json]
//!             [--size=3024x1964] [--scale=2] [--fxaa] [--out=DIR] [--tag=NAME]
//!             [--props=DIR|none] [--grass=on|off] [--ssr=on|off] [--metrics=FILE.json] [--bench] [--edit-test]
//!
//! `--scale=2` (four samples a pixel) is the resting-camera mode used for review stills;
//! `--scale=1 --fxaa` is the moving-camera mode. `--props` defaults to the exported Godot
//! scene beside the layout (`layout_7301_0.json` -> `scene_7301_0`); `none` keeps the stand-ins.
mod body;
mod decor;
mod field;
mod grass;
mod mesh;
mod props;
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
    ssao: bool,
    ssao_blur: bool,
    debug: f32,
    hour: String,
    scene: String,
    views: String,
    cameras: String,
    width: u32,
    height: u32,
    scale: u32,
    fxaa: bool,
    /// "auto" (from the layout name), "none", or a scene folder.
    props: String,
    /// Draw the grass field (off only to measure what it costs).
    grass: bool,
    /// Screen-space reflections on the ponds.
    ssr: bool,
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
        look: "n".into(),
        ssao: true,
        ssao_blur: true,
        debug: 0.0,
        hour: "day".into(),
        scene: "single".into(),
        views: "whole".into(),
        cameras: "runtime/data/reference/cameras.json".into(),
        width: 3024,
        height: 1964,
        scale: 2,
        fxaa: false,
        props: "auto".into(),
        grass: true,
        ssr: true,
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
            "--ssao" => {
                args.ssao = value != "off";
                args.ssao_blur = value != "noblur";
            }
            "--debug" => args.debug = match value { "ao" => 1.0, "ssao" => 2.0, _ => 0.0 },
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
            "--fxaa" => args.fxaa = true,
            "--props" => args.props = value.to_string(),
            "--grass" => args.grass = value != "off",
            "--ssr" => args.ssr = value != "off",
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

/// sRGB display value to linear.
fn lin(c: [f32; 3]) -> [f32; 3] {
    c.map(|v| if v <= 0.04045 { v / 12.92 } else { ((v + 0.055) / 1.055).powf(2.4) })
}

/// Godot 4's filmic curve, as in shader.wgsl.
fn filmic(x: f32) -> f32 {
    let (a, b, c, d, e, f) = (0.88, 0.60, 0.10, 0.20, 0.01, 0.30);
    ((x * (a * x + c * b) + d * e) / (x * (a * x + b) + d * f)) - e / f
}

/// Toward the light for a Godot DirectionalLight3D with rotation_degrees (x, y, 0): minus its -Z axis.
fn godot_light(x_deg: f32, y_deg: f32) -> Vec3 {
    let (x, y) = (x_deg.to_radians(), y_deg.to_radians());
    Vec3::new(x.cos() * y.sin(), -x.sin(), x.cos() * y.cos()).normalize()
}

/// What an hour's light is, as recorded in the frozen project (display colours, energies,
/// Godot rotations). `light_set` turns it into the shader's linear slots.
struct Hour {
    hour: f32,
    sun_rot: (f32, f32),
    sun_colour: [f32; 3],
    sun_energy: f32,
    shadow_opacity: f32,
    fill_rot: (f32, f32),
    fill_colour: [f32; 3],
    fill_energy: f32,
    ambient_colour: [f32; 3],
    ambient_energy: f32,
    /// Godot mixes the sky's own light into the ambient by this share.
    sky_share: f32,
    /// My multiplier on the recorded ambient energy: stands in for the bounce (SSIL 0.4) and sky
    /// reflections the Godot frames had and this tool does not.
    ambient_gain: f32,
    /// Sky (up) and ground bounce (down) colours that the hemisphere mixes with the ambient colour.
    sky_up: [f32; 3],
    ground: [f32; 3],
    exposure: f32,
    white: f32,
    contrast: f32,
    saturation: f32,
    ssao_intensity: f32,
    ssao_power: f32,
    /// Backdrop colours, authored as they should appear on screen.
    zenith: [f32; 3],
    haze: [f32; 3],
    glow: [f32; 3],
    cloud_lit: [f32; 3],
    cloud_shade: [f32; 3],
    fog: [f32; 3],
    fog_density: f32,
    far_density: f32,
    water_shallow: [f32; 3],
    water_deep: [f32; 3],
    moss: [f32; 4],
    foam: [f32; 3],
    root_mist: f32,
    /// Body tint of a waterfall sheet (display value).
    fall: [f32; 3],
}

fn hour_values(name: &str) -> Hour {
    match name {
        // Godot capture "dusk" (day progress 0.83): sun, fill, ambient and fog as recorded; backdrop from the 酉 keyframe.
        "dusk" => Hour {
            hour: 0.83,
            sun_rot: (-23.23, 32.77),
            sun_colour: [0.934, 0.804, 0.646],
            sun_energy: 1.285,
            shadow_opacity: 0.80,
            fill_rot: (-45.62, -96.0),
            fill_colour: [0.75, 0.74, 0.86],
            fill_energy: 0.084,
            ambient_colour: [0.66, 0.64, 0.74],
            ambient_energy: 0.316,
            sky_share: 0.34,
            ambient_gain: 2.2,
            sky_up: [0.90, 0.76, 0.65],
            ground: [0.86, 0.74, 0.62],
            exposure: 1.05,
            white: 5.2,
            contrast: 1.05,
            saturation: 1.03,
            ssao_intensity: 1.18,
            ssao_power: 1.25,
            zenith: [0.72, 0.74, 0.82],
            haze: [0.95, 0.88, 0.80],
            glow: [1.0, 0.74, 0.42],
            cloud_lit: [0.96, 0.90, 0.82],
            cloud_shade: [0.66, 0.68, 0.78],
            fog: [0.63, 0.70, 0.76],
            fog_density: 0.000496,
            far_density: 0.0030,
            water_shallow: [0.36, 0.62, 0.62],
            water_deep: [0.08, 0.31, 0.30],
            moss: [0.88, 0.95, 0.80, 0.50],
            foam: [0.92, 0.90, 0.86],
            root_mist: 0.96,
            fall: [0.62, 0.70, 0.66],
        },
        // Godot capture "night" (day progress 0.02): moonlight as recorded; backdrop from the 子 keyframe, lifted toward the captured frame.
        "night" => Hour {
            hour: 0.02,
            sun_rot: (-27.97, 28.14),
            sun_colour: [0.684, 0.822, 0.978],
            sun_energy: 0.854,
            shadow_opacity: 0.72,
            fill_rot: (-47.92, -96.53),
            fill_colour: [0.46, 0.64, 0.82],
            fill_energy: 0.143,
            ambient_colour: [0.36, 0.50, 0.66],
            ambient_energy: 0.378,
            sky_share: 0.34,
            ambient_gain: 1.8,
            sky_up: [0.30, 0.44, 0.58],
            ground: [0.40, 0.48, 0.56],
            exposure: 1.05,
            white: 5.2,
            contrast: 1.05,
            saturation: 1.02,
            ssao_intensity: 1.08,
            ssao_power: 1.25,
            zenith: [0.26, 0.36, 0.50],
            haze: [0.52, 0.62, 0.72],
            glow: [0.64, 0.80, 0.92],
            cloud_lit: [0.66, 0.75, 0.84],
            cloud_shade: [0.36, 0.47, 0.60],
            fog: [0.326, 0.455, 0.584],
            fog_density: 0.000555,
            far_density: 0.0030,
            water_shallow: [0.22, 0.48, 0.52],
            water_deep: [0.05, 0.22, 0.27],
            moss: [0.90, 0.95, 0.86, 0.45],
            foam: [0.80, 0.88, 0.95],
            root_mist: 0.96,
            fall: [0.40, 0.52, 0.58],
        },
        // Godot capture "day" (day progress 0.29) and terrain_environment.gd's day keyframe.
        _ => Hour {
            hour: 0.29,
            sun_rot: (-25.5, 38.0),
            sun_colour: [1.0, 0.94, 0.80],
            sun_energy: 1.86,
            shadow_opacity: 0.90,
            fill_rot: (-42.0, -135.0),
            fill_colour: [0.67, 0.79, 1.0],
            fill_energy: 0.38,
            ambient_colour: [0.54, 0.65, 0.78],
            ambient_energy: 0.20,
            sky_share: 0.34,
            ambient_gain: 2.1,
            sky_up: [0.74, 0.84, 0.87],
            ground: [0.90, 0.85, 0.74],
            exposure: 1.05,
            white: 5.2,
            contrast: 1.04,
            saturation: 1.02,
            ssao_intensity: 0.95,
            ssao_power: 1.25,
            zenith: [0.62, 0.76, 0.86],
            // Sky at the horizon and the far haze: the reference's pale cyan.
            haze: [0.83, 0.875, 0.875],
            glow: [1.0, 0.90, 0.70],
            // The cloud sea is two-toned: warm cream lit tops, blue-grey shadow sides and troughs.
            cloud_lit: [0.945, 0.925, 0.875],
            cloud_shade: [0.62, 0.69, 0.75],
            fog: [0.78, 0.84, 0.88],
            fog_density: 0.00016,
            far_density: 0.0030,
            water_shallow: [0.36, 0.66, 0.56],
            water_deep: [0.03, 0.16, 0.15],
            // The brow under the lawn lip: a multiplicative green tint (rgb) and its strength (a).
            moss: [0.88, 0.96, 0.79, 0.55],
            foam: [0.95, 0.96, 0.94],
            root_mist: 0.96,
            fall: [0.58, 0.74, 0.70],
        },
    }
}

/// An hour's light in the shader's slots (all linear), the direction to the sun, and the hour.
fn light_set(name: &str) -> ([[f32; 4]; render::LIGHT_SLOTS], Vec3, f32) {
    let h = hour_values(name);
    // Backdrop colours are authored as displayed: invert the tone curve so they come out as written.
    let shown = |c: [f32; 3]| -> [f32; 3] {
        lin(c).map(|target| {
            let (mut low, mut high) = (0.0_f32, 64.0_f32);
            for _ in 0..40 {
                let mid = 0.5 * (low + high);
                if filmic(mid * h.exposure) / filmic(h.white) < target {
                    low = mid;
                } else {
                    high = mid;
                }
            }
            0.5 * (low + high)
        })
    };
    let scaled = |c: [f32; 3], k: f32| -> [f32; 4] {
        let l = lin(c);
        [l[0] * k, l[1] * k, l[2] * k, 0.0]
    };
    let with_a = |c: [f32; 3], a: f32| [c[0], c[1], c[2], a];
    let mixed = |a: [f32; 3], b: [f32; 3], t: f32| -> [f32; 3] {
        let (a, b) = (lin(a), lin(b));
        [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]
    };
    let sky = mixed(h.ambient_colour, h.sky_up, h.sky_share).map(|v| v * h.ambient_energy * h.ambient_gain);
    let ground = mixed(h.ambient_colour, h.ground, 0.6).map(|v| v * h.ambient_energy * h.ambient_gain);
    let fill_dir = godot_light(h.fill_rot.0, h.fill_rot.1);
    let glow = lin(h.glow);
    let mut slots = [[0.0_f32; 4]; render::LIGHT_SLOTS];
    slots[0] = { let mut s = scaled(h.sun_colour, h.sun_energy); s[3] = h.shadow_opacity; s };
    slots[1] = scaled(h.fill_colour, h.fill_energy);
    slots[2] = [fill_dir.x, fill_dir.y, fill_dir.z, 0.0];
    slots[3] = with_a(sky, 0.0);
    slots[4] = with_a(ground, 0.0);
    slots[5] = [h.exposure, h.white, h.contrast, h.saturation];
    slots[6] = with_a(shown(h.zenith), 0.0);
    slots[7] = with_a(shown(h.haze), 0.0);
    slots[8] = [glow[0] * 0.6, glow[1] * 0.6, glow[2] * 0.6, 6.0];
    slots[9] = with_a(shown(h.cloud_lit), 0.0);
    slots[10] = with_a(shown(h.cloud_shade), 0.0);
    slots[11] = with_a(shown(h.fog), h.fog_density);
    // My estimator counts fewer occluded taps than Godot's for the same crease, so its intensity is scaled by 1.8.
    slots[12] = [-5.5, -16.5, h.ssao_intensity * 1.8, h.ssao_power];
    slots[13] = with_a(lin(h.water_shallow), 0.0);
    slots[14] = with_a(lin(h.water_deep), 0.0);
    slots[15] = h.moss;
    slots[16] = [0.0, 0.0, 0.0, h.far_density];
    slots[17] = with_a(lin(h.foam), h.root_mist);
    slots[18] = with_a(lin(h.fall), 0.0);
    (slots, godot_light(h.sun_rot.0, h.sun_rot.1), h.hour)
}

/// What the frozen project has far off: a few very large, smooth, pale mounds rising out of the
/// cloud sea, low in contrast, more a tone than an object. Each is a long soft ridge (after
/// distant_landscape.gd's `_mountain`: a crest that rises and falls along its length over smooth
/// flanks), not a dome; shading normals lean toward the sky so the sun only lifts one side a little.
fn far_mounds(seed: u32) -> Mesh {
    let mut mesh = Mesh::default();
    let mut rng = Rng::new(seed, 77);
    let (nx, nz) = (72usize, 18usize);
    // One ring about 480 m out, as the frozen project's nearest ring (radius 460 m, bases near
    // -180 m): the crests fall well below the cloud plane, which puts them in the upper part of
    // the review frames, and the resolve dissolves their lower slopes into the cloud sea seen
    // along the same ray (this tool's cloud sea is a backdrop, not geometry).
    let count = 14;
    for index in 0..count {
        let angle = (index as f32 + rng.range(-0.3, 0.3)) / count as f32 * std::f32::consts::TAU;
        let distance = rng.range(440.0, 540.0);
        let at = Vec2::new(angle.cos(), angle.sin()) * distance;
        let crest = rng.range(-95.0, -55.0);
        let base = -195.0;
        // Long across the line of sight, shallow along it, turned a little off square.
        let turn = angle + std::f32::consts::FRAC_PI_2 + rng.range(-0.3, 0.3);
        let across = Vec2::new(turn.cos(), turn.sin());
        let along = Vec2::new(-across.y, across.x);
        let (long, deep) = (rng.range(170.0, 260.0), rng.range(70.0, 105.0));
        let (p1, p2, k1) = (rng.range(0.0, 6.28), rng.range(0.0, 6.28), rng.range(1.6, 2.6));
        // Crest height along the ridge (u in -1..1): a broad rise with one or two soft summits.
        let crest_at = |u: f32| -> f32 {
            let env = (1.0 - u * u).max(0.0).powf(0.55);
            let summits = 0.78 + 0.16 * (u * k1 * 1.9 + p1).sin() + 0.08 * (u * 5.3 + p2).cos();
            base + (crest - base) * env * summits
        };
        let point = |ix: usize, iz: usize| -> Vec3 {
            let u = ix as f32 / nx as f32 * 2.0 - 1.0;
            let v = iz as f32 / nz as f32 * 2.0 - 1.0;
            let spine = 0.15 * (u * 2.8 + p1).sin();
            let width = 0.35 + 0.65 * (1.0 - u * u).max(0.0).sqrt();
            let d = v.abs();
            // Smooth flank plus descending spur ridges (distant_landscape.gd), so lit and shaded faces
            // alternate down the flanks.
            let spur = 0.11 * (0.5 + 0.5 * (u * 7.4 + p2 + v * 1.15).sin()).max(0.0).powi(2) * d * (1.0 - d).max(0.0).powf(0.85) * 2.4;
            let y = base + (crest_at(u) - base) * ((1.0 - d).max(0.0).powf(1.42) + spur);
            let p = at + across * (u * long) + along * ((spine * (1.0 - 0.55 * d) + v * width) * deep);
            Vec3::new(p.x, y, p.y)
        };
        let normal = |ix: usize, iz: usize| -> Vec3 {
            let (a, b) = (point(ix.saturating_sub(1), iz), point((ix + 1).min(nx), iz));
            let (c, e) = (point(ix, iz.saturating_sub(1)), point(ix, (iz + 1).min(nz)));
            let mut n = (e - c).cross(b - a).normalize_or_zero();
            if n.y < 0.0 {
                n = -n;
            }
            (n + Vec3::Y * 0.1).normalize()
        };
        let colour = Vec3::new(0.86, 0.84, 0.78);
        // grad: how far below the crest a point lies (0 at the crest, 1 at the base); the resolve
        // shows only the upper band and dissolves the rest into the cloud sea.
        let paint = |p: Vec3| Paint::new(Family::Wood).sky(1.0).line(0.0).id(20).grad(((crest - p.y) / (crest - base)).clamp(0.0, 1.0));
        for ix in 0..nx {
            for iz in 0..nz {
                let q = [(ix, iz), (ix + 1, iz), (ix + 1, iz + 1), (ix, iz + 1)];
                let p = q.map(|(x, z)| point(x, z));
                let n = q.map(|(x, z)| normal(x, z));
                mesh.tri_full([p[0], p[1], p[2]], [n[0], n[1], n[2]], [colour; 3], [paint(p[0]), paint(p[1]), paint(p[2])]);
                mesh.tri_full([p[0], p[2], p[3]], [n[0], n[2], n[3]], [colour; 3], [paint(p[0]), paint(p[2]), paint(p[3])]);
            }
        }
    }
    mesh
}

struct Built {
    solid: Mesh,
    water: Vec<water::WaterVertex>,
    grass: grass::Grass,
    faces: Vec<body::Face>,
    columns: usize,
    timings: Vec<(&'static str, f64)>,
    parts: Vec<(&'static str, usize)>,
}

/// Builds one island. With `props` the exported Godot props are loaded into `library` and the
/// procedural trees, bamboo, rocks, stones and lily pads are not made (rim tufts stay).
fn build_island(cells: &Cells, kind: body::Kind, seed: u32, origin: Vec3, courtyard: bool, props: Option<&std::path::Path>, library: &mut props::Library) -> Built {
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
    let mut prop_triangles = 0;
    let mut clear = Vec::new();
    let things = match props {
        Some(dir) => {
            let report = props::load(dir, cells, &field, origin, library);
            println!("{}", report.line(dir));
            prop_triangles = report.triangles;
            clear = report.clear;
            Mesh::default()
        }
        None if courtyard => decor::courtyard(cells, &field, &colours, seed, &mut clear),
        None => decor::scatter(cells, &field, &colours, seed, &mut clear),
    };
    lap("decor", &mut timings);
    let grass = grass::build(&field, &top.rim, &clear, seed, origin, field::TopColours::default().lawn);
    lap("grass", &mut timings);
    parts.push(("top", top.mesh.triangles()));
    parts.push(("body", body.mesh.triangles()));
    parts.push(("decor", things.triangles()));
    parts.push(("props", prop_triangles));
    parts.push(("grass full", grass.clumps.len() * grass::meshes().triangles(0) as usize));
    let mut solid = Mesh::default();
    solid.append(&top.mesh);
    solid.append(&body.mesh);
    solid.append(&things);
    solid.offset(origin);
    Built { solid, water: water::build_water(cells, origin), grass, faces: body.faces, columns: body.columns, timings, parts }
}

/// How far from an edit the rim plan changes: the locality test of S4.
fn edit_test(cells: &Cells, seed: u32) -> String {
    let plan = |cells: &Cells| {
        let field = field::Field::build(cells);
        let outlines = field::outlines(cells, &field, 0.5);
        let outer = outlines.iter().find(|o| !o.is_hole).expect("outline");
        let mut trace = Vec::new();
        let faces = body::plan_traced(outer, &field, seed, &mut trace);
        (faces, outer.points.clone(), trace)
    };
    let (before, before_points, before_trace) = plan(cells);
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
        let (after, after_points, after_trace) = plan(&edited);
        let centre = Vec2::new(at.0 as f32 + if name == "expand" { 2.5 } else { -0.5 }, at.1 as f32 + 0.5);
        // A face is unchanged when the other plan has one with both ends within 0.30 m and a top within 0.26.
        let alike = |f: &body::Face, g: &body::Face| (f.a - g.a).length() <= 0.30 && (f.b - g.b).length() <= 0.30 && (f.top - g.top).abs() <= 0.26;
        let mut farthest: f32 = 0.0;
        let (mut changed, mut far) = (0, 0);
        let gone = before.iter().filter(|f| !after.iter().any(|g| alike(f, g))).map(|f| (f, "before"));
        let new = after.iter().filter(|f| !before.iter().any(|g| alike(f, g))).map(|f| (f, "after"));
        for (face, side) in gone.chain(new) {
            changed += 1;
            let nearest = (face.a - centre).length().min((face.b - centre).length());
            farthest = farthest.max(nearest);
            if nearest > 12.0 {
                far += 1;
                if far == 1 {
                    // Where does this change first show? Compare each stage of both plans at the face's end points.
                    let (mine, other, mine_trace, other_trace) =
                        if side == "before" { (&before_points, &after_points, &before_trace, &after_trace) } else { (&after_points, &before_points, &after_trace, &before_trace) };
                    let near = |set: &[Vec2], p: Vec2| set.iter().map(|q| (*q - p).length()).fold(f32::MAX, f32::min);
                    let mut stage = "role or top".to_string();
                    'found: for (label, p) in [("a", face.a), ("b", face.b)] {
                        if near(other, p) > 1e-3 {
                            stage = format!("outline point at end {label} {p:?} (nearest other {:.3} m)", near(other, p));
                            break 'found;
                        }
                        for (s, name) in ["break set", "split", "pairing"].iter().enumerate() {
                            if near(&mine_trace[s], p) < 1e-3 && near(&other_trace[s], p) > 1e-3 {
                                let close: Vec<String> = other_trace[s].iter().filter(|q| (**q - p).length() < 2.0).map(|q| format!("{q:?}")).collect();
                                stage = format!("{name} at end {label} {p:?}, other plan's {name} near it: [{}]", close.join(" "));
                                break 'found;
                            }
                        }
                    }
                    let other_faces = if side == "before" { &after } else { &before };
                    {
                        let lo = face.a.min(face.b) - Vec2::splat(0.8);
                        let hi = face.a.max(face.b) + Vec2::splat(0.8);
                        let inside = |set: &[Vec2]| set.iter().filter(|p| p.cmpge(lo).all() && p.cmple(hi).all()).map(|p| format!("({:.2},{:.2})", p.x, p.y)).collect::<Vec<_>>().join(" ");
                        for s in 0..3 {
                            println!("EDITDIAG {name}: stage {s} breaks here, this plan [{}] other plan [{}]", inside(&mine_trace[s]), inside(&other_trace[s]));
                        }
                    }
                    if let Some(twin) = other_faces.iter().find(|g| (g.a - face.a).length() < 1e-3 && (g.b - face.b).length() < 1e-3) {
                        // Outline points between the ends that the other plan does not have.
                        let lo = face.a.min(face.b) - Vec2::splat(0.8);
                        let hi = face.a.max(face.b) + Vec2::splat(0.8);
                        let odd: Vec<String> = mine.iter().filter(|p| p.cmpge(lo).all() && p.cmple(hi).all() && near(other, **p) > 1e-3).map(|p| format!("{p:?}")).collect();
                        println!("EDITDIAG {name}: top {:.3} vs {:.3} in the other plan; points near this face missing from the other outline: [{}]", face.top, twin.top, odd.join(" "));
                    }
                    println!("EDITDIAG {name}: {side} face {:?}..{:?} ({:.1} m away) first differs in {stage}", face.a, face.b, nearest);
                }
            }
        }
        lines.push(format!("  {{\"stroke\": \"{name}\", \"at\": [{}, {}], \"faces_before\": {}, \"faces_after\": {}, \"faces_changed\": {changed}, \"farthest_change_m\": {farthest:.2}, \"changed_beyond_12m\": {far}}}", at.0, at.1, before.len(), after.len()));
        println!("EDIT {name:8} at {at:?}: {changed} faces changed, farthest {farthest:.2} m from the stroke, {far} beyond 12 m");
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
    // Props folder for a layout: given, from its name, or none (synthetic islands keep the stand-ins).
    let props_for = |layout: Option<&str>, given: bool| -> Option<std::path::PathBuf> {
        match (args.props.as_str(), layout) {
            ("none", _) | (_, None) => None,
            ("auto", Some(path)) => props::default_dir(path).filter(|dir| dir.join("scene.json").exists()),
            (dir, Some(path)) => if given { Some(dir.into()) } else { props::default_dir(path).filter(|d| d.join("scene.json").exists()) },
        }
    };
    let mut library = props::Library::default();
    let total = Instant::now();
    let main_props = props_for(args.layout.as_deref(), true);
    let mut main_island = build_island(&cells, args.body, args.seed, Vec3::ZERO, courtyard, main_props.as_deref(), &mut library);
    let build_ms = total.elapsed().as_secs_f64() * 1000.0;
    let mut solid = Mesh::default();
    solid.append(&main_island.solid);
    let mut water = main_island.water.clone();
    let mut all_grass = std::mem::take(&mut main_island.grass);
    if args.scene == "trio" {
        // Two more islands, staggered in space and height, built by the same code.
        let folder = std::path::Path::new(args.layout.as_deref().unwrap_or("runtime/data/reference/x")).parent().unwrap().to_path_buf();
        for (file, seed, origin) in [("layout_4242_1.json", 4242, Vec3::new(46.0, 9.5, -30.0)), ("layout_913_2.json", 913, Vec3::new(-42.0, -7.5, 16.0))] {
            let path = folder.join(file);
            let other = field::load_layout(path.to_str().unwrap());
            let other_props = props_for(path.to_str(), false);
            let built = build_island(&other, args.body, seed, origin, true, other_props.as_deref(), &mut library);
            solid.append(&built.solid);
            water.extend_from_slice(&built.water);
            all_grass.append(built.grass);
        }
    }
    let casters = solid.vertices.len();
    solid.append(&far_mounds(args.seed));
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
    cameras.push(("wallpaper".to_string(), Camera { eye: Vec3::new(26.0, 24.0, 122.0), target: Vec3::new(2.0, 0.0, -4.0), fov_deg: 31.0 }));
    cameras.push(("below".to_string(), Camera { eye: Vec3::new(14.0, -19.0, 30.0), target: Vec3::new(-1.0, -2.0, -1.0), fov_deg: 31.0 }));
    if args.synthetic > 0 {
        // A synthetic island has its own size: frame it whole and close.
        let reach = cells.keys().map(|&(x, z)| Vec2::new(x as f32, z as f32).length()).fold(0.0, f32::max);
        cameras.retain(|(name, _)| name != "whole" && name != "game");
        cameras.push(("whole".to_string(), Camera::orbit([0.0, 0.0], reach * 1.35, 16.0, 30.0)));
        cameras.push(("game".to_string(), Camera::orbit([reach * 0.2, reach * 0.1], reach * 0.55, 16.0, 27.0)));
    }
    let wanted: Vec<&str> = args.views.split(',').collect();

    let mut renderer = Renderer::new(args.width, args.height, args.scale, args.fxaa);
    renderer.set_scene(&solid.vertices, casters, &water);
    renderer.set_props(&library);
    if args.grass {
        renderer.set_grass(&all_grass);
    }
    // Looks A, B and C (line, flat wash, paper) were removed; they are in git at 6be0388.
    assert!(args.look == "n", "only look n exists now; looks a, b and c are in git at 6be0388");
    let (mut light, sun_dir, hour) = light_set(&args.hour);
    light[19][0] = if args.ssr { 1.0 } else { 0.0 };
    std::fs::create_dir_all(&args.out).expect("output folder");
    let mut bench_lines = Vec::new();
    let mut frame_lines = Vec::new();
    for (name, camera) in cameras.iter() {
        if !(wanted.contains(&"all") && name != "wallpaper" && name != "below") && !wanted.contains(&name.as_str()) {
            continue;
        }
        let frame = Frame { camera: *camera, sun_dir, time: 3.0, hour, ssao: args.ssao, ssao_blur: args.ssao_blur, debug: args.debug, light };
        let drawn = renderer.render(&frame);
        let path = format!("{}/{}_{}.png", args.out, args.tag, name);
        let stats = renderer.save_png(&path);
        println!(
            "GRASS {name}: {} clumps, {} triangles full, {} drawn, chunks by level {}/{}/{}/{} (two bends, one bend, half roots, quarter roots)",
            all_grass.clumps.len(),
            all_grass.clumps.len() as u64 * grass::meshes().triangles(0),
            drawn.triangles,
            drawn.chunks[0],
            drawn.chunks[1],
            drawn.chunks[2],
            drawn.chunks[3]
        );
        println!("FRAME {path}");
        println!(
            "STATS {name}: p05 {:.3} p50 {:.3} p95 {:.3} white {:.3} black {:.3} sat_mean {:.3} sat_p99 {:.3} quiet {:.3}",
            stats.luma_p05, stats.luma_p50, stats.luma_p95, stats.near_white, stats.near_black, stats.saturation_mean, stats.saturation_p99, stats.quiet_share
        );
        frame_lines.push(format!(
            "  {{\"view\": \"{name}\", \"p05\": {:.3}, \"p50\": {:.3}, \"p95\": {:.3}, \"white\": {:.3}, \"black\": {:.3}, \"sat_mean\": {:.3}, \"sat_p99\": {:.3}, \"quiet\": {:.3}}}",
            stats.luma_p05, stats.luma_p50, stats.luma_p95, stats.near_white, stats.near_black, stats.saturation_mean, stats.saturation_p99, stats.quiet_share
        ));
        if args.bench {
            let ms = renderer.bench(&frame, 120);
            println!(
                "BENCH {name}: {ms:.2} ms a frame at {}x{} with {}x supersampling, ssao {}, fxaa {}, props {}",
                args.width,
                args.height,
                args.scale,
                if !args.ssao { "off" } else if args.ssao_blur { "on" } else { "on, no blur" },
                if args.fxaa { "on" } else { "off" },
                if library.buckets.iter().any(|b| !b.is_empty()) { "on" } else { "off" }
            );
            bench_lines.push(format!("  {{\"view\": \"{name}\", \"ms\": {ms:.3}}}"));
        }
    }
    if let Some(path) = &args.metrics {
        let widths: Vec<String> = main_island.faces.iter().map(|f| format!("{:.1}", f.width)).collect();
        let text = format!(
            "{{\n \"cells\": {},\n \"body\": \"{:?}\",\n \"triangles\": {},\n \"parts\": {{{}}},\n \"build_ms\": {:.2},\n \"stages_ms\": {{{}}},\n \"faces\": {},\n \"columns\": {},\n \"face_widths_m\": [{}],\n \"width_min_m\": {:.2},\n \"width_max_m\": {:.2},\n \"width_spread\": {:.3},\n \"step_spread_m\": {:.3},\n \"longest_alike_run\": {},\n \"longest_alike_run_m\": {:.2},\n \"edit_locality\": [\n{}\n ],\n \"bench\": [\n{}\n ],\n \"frames\": [\n{}\n ]\n}}\n",
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
            bench_lines.join(",\n"),
            frame_lines.join(",\n")
        );
        std::fs::write(path, text).expect("write metrics");
    }
}
