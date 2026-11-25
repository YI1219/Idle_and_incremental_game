//! Studies S3 (look) and S4 (island generation) on one tool. Throwaway code.
//!
//!   s34_study --layout=runtime/data/reference/layout_7301_0.json | --synthetic=4096
//!             [--seed=7301] [--body=karst|hull] [--look=n] [--hour=day|dusk|night] [--ssao=on|off|noblur] [--debug=ao|ssao|parts]
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
    /// Round r9: ramp strokes (ax, az, bx, bz, width), applied in order after loading.
    ramps: Vec<[f32; 5]>,
    /// Round r9: write the resulting layout (version 2) here.
    save_layout: Option<String>,
    /// Round r9: a synthetic island gets one ramp across each long terrace wall.
    synthetic_ramps: bool,
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
        ramps: Vec::new(),
        save_layout: None,
        synthetic_ramps: false,
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
            "--debug" => args.debug = match value { "ao" => 1.0, "ssao" => 2.0, "parts" => 3.0, _ => 0.0 },
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
            "--ramp" => {
                let v: Vec<f32> = value.split(',').map(|s| s.trim().parse().expect("--ramp=ax,az,bx,bz,width")).collect();
                assert!(v.len() == 5, "--ramp=ax,az,bx,bz,width");
                args.ramps.push([v[0], v[1], v[2], v[3], v[4]]);
            }
            "--save-layout" => args.save_layout = Some(value.to_string()),
            "--synthetic-ramps" => args.synthetic_ramps = true,
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
    /// My calibration of the falls per hour: linear factors on the sheet (1 would be the port as is).
    fall: [f32; 3],
    /// My calibration of the island's light (linear factors on sun, sky, ground and fill) and of the
    /// island stone on top of it, measured against the reference frames; 1 at day.
    near_gain: [f32; 3],
    stone_gain: [f32; 3],
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
            fill_colour: [0.6904, 0.7194, 0.8518],
            fill_energy: 0.084,
            ambient_colour: [0.5983, 0.6112, 0.7236],
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
            water_shallow: [0.36, 0.70, 0.70],
            water_deep: [0.03, 0.19, 0.18],
            moss: [0.88, 0.95, 0.80, 0.50],
            foam: [0.92, 0.90, 0.86],
            root_mist: 0.96,
            fall: [0.58, 0.77, 0.81],
            near_gain: [0.70, 0.70, 0.70],
            stone_gain: [1.26, 1.26, 1.40],
        },
        // Godot capture "night" (day progress 0.02): moonlight as recorded; backdrop from the 子 keyframe, lifted toward the captured frame.
        "night" => Hour {
            hour: 0.02,
            sun_rot: (-27.97, 28.14),
            sun_colour: [0.684, 0.822, 0.978],
            sun_energy: 0.854,
            shadow_opacity: 0.72,
            fill_rot: (-47.92, -96.53),
            fill_colour: [0.4629, 0.6420, 0.8225],
            fill_energy: 0.143,
            ambient_colour: [0.3625, 0.5020, 0.6616],
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
            water_shallow: [0.40, 0.64, 0.58],
            water_deep: [0.08, 0.28, 0.22],
            moss: [0.90, 0.95, 0.86, 0.45],
            foam: [0.80, 0.88, 0.95],
            root_mist: 0.96,
            fall: [0.574, 0.719, 0.695],
            near_gain: [0.72, 0.72, 0.72],
            stone_gain: [1.56, 1.18, 0.93],
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
            fall: [0.55, 0.80, 0.82],
            near_gain: [1.0, 1.0, 1.0],
            stone_gain: [1.0, 1.0, 1.0],
        },
    }
}

/// The frozen project's blended style preset at a capture's day progress: what
/// time_solar_system.gd `current_blended_preset()` returns (smoothstep blend of its KEYFRAMES),
/// computed by `tools/blend_preset.py` and checked there against each set's captures.json (sun,
/// fill, ambient, fog, shadow, ssao and grass entries agree to 1e-5). Display (source_color) values.
struct Preset {
    sky_zenith: [f32; 3],
    sky_mid: [f32; 3],
    sky_horizon: [f32; 3],
    sky_sun_glow: [f32; 3],
    sky_sun_core: [f32; 3],
    sky_cloud_dark: [f32; 3],
    sky_cloud_light: [f32; 3],
    mountain_dark: [f32; 3],
    mountain_light: [f32; 3],
    grass_base: [f32; 3],
    grass_highlight: [f32; 3],
    stone_shadow: [f32; 3],
    stone_mid: [f32; 3],
    stone_lit: [f32; 3],
    stone_mist: [f32; 3],
    water_deep: [f32; 3],
    decor_shadow: [f32; 3],
    decor_lit: [f32; 3],
    leaf_shadow: [f32; 3],
    leaf_mid: [f32; 3],
    leaf_lit: [f32; 3],
    lantern_glow: f32,
    lantern_color: [f32; 3],
}

fn preset(name: &str) -> Preset {
    match name {
        // day progress 0.83: keyframe 0.76 to 1.00 at t 0.2056
        "dusk" => Preset {
            sky_zenith: [0.4342, 0.5024, 0.6583],
            sky_mid: [0.7766, 0.6942, 0.6356],
            sky_horizon: [0.8531, 0.7786, 0.6721],
            sky_sun_glow: [0.9260, 0.7523, 0.5228],
            sky_sun_core: [0.9753, 0.9103, 0.7458],
            sky_cloud_dark: [0.4783, 0.5486, 0.6289],
            sky_cloud_light: [0.8978, 0.8430, 0.7603],
            mountain_dark: [0.4065, 0.3912, 0.4912],
            mountain_light: [0.6978, 0.6112, 0.5364],
            grass_base: [0.2294, 0.3156, 0.1962],
            grass_highlight: [0.3951, 0.4336, 0.2682],
            stone_shadow: [0.2077, 0.2338, 0.2979],
            stone_mid: [0.3394, 0.3359, 0.3423],
            stone_lit: [0.5230, 0.4718, 0.4106],
            stone_mist: [0.8172, 0.7704, 0.7194],
            water_deep: [0.0738, 0.2915, 0.2938],
            decor_shadow: [0.8153, 0.8200, 0.9041],
            decor_lit: [1.0151, 0.9559, 0.9008],
            leaf_shadow: [0.1097, 0.1718, 0.1200],
            leaf_mid: [0.2194, 0.2936, 0.1721],
            leaf_lit: [0.4307, 0.4533, 0.2700],
            lantern_glow: 0.6581,
            lantern_color: [1.0, 0.6559, 0.2359],
        },
        // day progress 0.02: keyframe 0.00 to 0.29 at t 0.0136
        "night" => Preset {
            sky_zenith: [0.1844, 0.2856, 0.4250],
            sky_mid: [0.3060, 0.4454, 0.5839],
            sky_horizon: [0.4472, 0.5845, 0.6815],
            sky_sun_glow: [0.6449, 0.8014, 0.9170],
            sky_sun_core: [0.8816, 0.9503, 0.9981],
            sky_cloud_dark: [0.2427, 0.3531, 0.4730],
            sky_cloud_light: [0.5853, 0.7030, 0.8001],
            mountain_dark: [0.2018, 0.2823, 0.3820],
            mountain_light: [0.3841, 0.5025, 0.6000],
            grass_base: [0.1512, 0.2613, 0.2199],
            grass_highlight: [0.2625, 0.3720, 0.3002],
            stone_shadow: [0.1607, 0.2108, 0.2918],
            stone_mid: [0.2631, 0.3220, 0.3910],
            stone_lit: [0.3861, 0.4442, 0.4919],
            stone_mist: [0.4264, 0.5448, 0.6430],
            water_deep: [0.0504, 0.2209, 0.2698],
            decor_shadow: [0.7197, 0.8200, 0.9201],
            decor_lit: [0.8823, 0.9411, 1.0189],
            leaf_shadow: [0.0705, 0.1408, 0.1205],
            leaf_mid: [0.1419, 0.2325, 0.1811],
            leaf_lit: [0.2452, 0.3548, 0.2729],
            lantern_glow: 0.9480,
            lantern_color: [1.0, 0.6416, 0.2225],
        },
        // day progress 0.29: keyframe 0.29 exactly (STYLE_PRESETS[0])
        _ => Preset {
            sky_zenith: [0.50, 0.69, 0.79],
            sky_mid: [0.74, 0.84, 0.87],
            sky_horizon: [0.97, 0.91, 0.79],
            sky_sun_glow: [1.0, 0.90, 0.70],
            sky_sun_core: [1.0, 0.97, 0.86],
            sky_cloud_dark: [0.44, 0.58, 0.69],
            sky_cloud_light: [0.97, 0.92, 0.81],
            mountain_dark: [0.33, 0.45, 0.53],
            mountain_light: [0.68, 0.68, 0.60],
            grass_base: [0.238, 0.352, 0.214],
            grass_highlight: [0.442, 0.518, 0.312],
            stone_shadow: [0.21, 0.27, 0.42],
            stone_mid: [0.49, 0.47, 0.46],
            stone_lit: [0.83, 0.75, 0.63],
            stone_mist: [0.89, 0.89, 0.86],
            water_deep: [0.076, 0.285, 0.258],
            decor_shadow: [0.70, 0.82, 0.93],
            decor_lit: [1.05, 1.02, 0.94],
            leaf_shadow: [0.11, 0.20, 0.16],
            leaf_mid: [0.28, 0.41, 0.26],
            leaf_lit: [0.62, 0.70, 0.48],
            lantern_glow: 0.08,
            lantern_color: [1.0, 0.76, 0.40],
        },
    }
}

/// An hour's light in the shader's slots (all linear), the direction to the sun, and the hour.
fn light_set(name: &str) -> ([[f32; 4]; render::LIGHT_SLOTS], Vec3, f32) {
    let h = hour_values(name);
    let p = preset(name);
    let day = preset("day");
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
    slots[18] = with_a(h.fall, 0.0);
    // Far field (sky_palette, cloud_deck, distant_mountain): Godot's source_color uniforms, linear.
    slots[20] = with_a(lin(p.sky_zenith), 0.0);
    slots[21] = with_a(lin(p.sky_mid), 0.0);
    slots[22] = with_a(lin(p.sky_horizon), 0.0);
    slots[23] = with_a(lin(p.sky_sun_glow), 0.0);
    slots[24] = with_a(lin(p.sky_sun_core), 0.0);
    slots[25] = with_a(lin(p.sky_cloud_dark), 0.0);
    slots[26] = with_a(lin(p.sky_cloud_light), 0.0);
    slots[27] = with_a(lin(p.mountain_dark), 0.0);
    slots[28] = with_a(lin(p.mountain_light), 0.0);
    // slots[29]: the landscape's centre (Godot keeps DistantLandscape under the camera's orbit
    // centre), set per view in main(); w the sky's haze parameter (editor.gd background_haze).
    slots[29] = [0.0, 0.0, 0.0, 0.68];
    // The hour's palette shift as linear ratios to the day preset (1 at day, so day is unchanged):
    // our near-field albedos are tuned against the day frames; Godot swaps its palette entries.
    let ratio = |a: [f32; 3], b: [f32; 3]| -> [f32; 4] {
        let (a, b) = (lin(a), lin(b));
        [a[0] / b[0].max(1e-4), a[1] / b[1].max(1e-4), a[2] / b[2].max(1e-4), 0.0]
    };
    let mix3 = |a: [f32; 3], b: [f32; 3], t: f32| [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
    slots[30] = ratio(p.stone_mid, day.stone_mid);
    slots[31] = ratio(mix3(p.grass_base, p.grass_highlight, 0.5), mix3(day.grass_base, day.grass_highlight, 0.5));
    slots[32] = ratio(p.leaf_shadow, day.leaf_shadow);
    slots[33] = ratio(p.leaf_mid, day.leaf_mid);
    slots[34] = ratio(p.leaf_lit, day.leaf_lit);
    slots[35] = ratio(p.decor_shadow, day.decor_shadow);
    slots[36] = ratio(p.decor_lit, day.decor_lit);
    slots[37] = ratio(p.stone_shadow, day.stone_shadow);
    slots[38] = ratio(p.stone_lit, day.stone_lit);
    // Island walls: cliff_rock's faces sit between mid and lit (its rock_mid .24 .. rock_top .64);
    // shaded parts toward mix(shadow, mid, .38).
    slots[39] = ratio(mix3(p.stone_mid, p.stone_lit, 0.45), mix3(day.stone_mid, day.stone_lit, 0.45));
    slots[40] = with_a(lin(p.lantern_color), p.lantern_glow);
    slots[41] = [0.0, 0.0, 0.0, 0.0];
    slots[42] = ratio(mix3(p.stone_shadow, p.stone_mid, 0.38), mix3(day.stone_shadow, day.stone_mid, 0.38));
    // The root mist: our day colour times the change of Godot's island mist (terrain_environment.gd:
    // mist_color = stone_mist.lerp(sky_cloud_light, 0.45)).
    let mist_k = ratio(mix3(p.stone_mist, p.sky_cloud_light, 0.45), mix3(day.stone_mist, day.sky_cloud_light, 0.45));
    let dh = hour_values("day");
    let (dl, ds) = (shown(dh.cloud_lit), shown(dh.cloud_shade));
    let day_mist = [0.965, 0.985, 1.03];
    slots[43] = [
        (ds[0] + (dl[0] - ds[0]) * 0.8) * day_mist[0] * mist_k[0],
        (ds[1] + (dl[1] - ds[1]) * 0.8) * day_mist[1] * mist_k[1],
        (ds[2] + (dl[2] - ds[2]) * 0.8) * day_mist[2] * mist_k[2],
        0.0,
    ];
    // Dusk and night: the root mist takes the shaded cloud sea's tone below the island in the
    // reference frames (measured), authored as displayed. Day keeps the value above.
    match name {
        "dusk" => slots[43] = with_a(shown([0.70, 0.655, 0.62]), 0.0),
        "night" => slots[43] = with_a(shown([0.37, 0.48, 0.58]), 0.0),
        _ => {}
    }
    slots[44] = with_a(h.near_gain, 0.0);
    slots[45] = with_a(h.stone_gain, 0.0);
    // Pond depth colour: ours (tuned on the day frames) times the preset's change of water_deep.
    let wd = ratio(p.water_deep, day.water_deep);
    slots[14] = [slots[14][0] * wd[0], slots[14][1] * wd[1], slots[14][2] * wd[2], 0.0];
    (slots, godot_light(h.sun_rot.0, h.sun_rot.1), h.hour)
}

/// distant_landscape.gd `_peak_bell`.
fn peak_bell(u: f32, centre: f32, width: f32, power: f32) -> f32 {
    let du = ((u - centre) * (u - centre) + 0.0032).sqrt() / width;
    (-du.powf(power)).exp()
}

/// distant_landscape.gd `_crest_height`.
fn crest_height(variant: usize, u: f32) -> f32 {
    let env = (1.0 - u * u).max(0.0).powf(0.85);
    if env <= 0.0001 {
        return 0.0;
    }
    let mut h = 0.0;
    match variant {
        0 => {
            h += 0.96 * peak_bell(u, -0.16, 0.28, 1.66);
            h += 0.68 * peak_bell(u, 0.38, 0.27, 1.72);
            h += 0.44 * peak_bell(u, -0.64, 0.25, 1.74);
            h += 0.30 * peak_bell(u, 0.72, 0.23, 1.76);
        }
        1 => {
            h += 0.92 * peak_bell(u, -0.34, 0.27, 1.66);
            h += 0.80 * peak_bell(u, 0.30, 0.28, 1.70);
            h += 0.38 * peak_bell(u, 0.68, 0.24, 1.74);
            h += 0.34 * peak_bell(u, -0.72, 0.23, 1.74);
        }
        _ => {
            h += 0.82 * peak_bell(u, 0.04, 0.32, 1.72);
            h += 0.68 * peak_bell(u, -0.48, 0.28, 1.70);
            h += 0.60 * peak_bell(u, 0.52, 0.27, 1.70);
            h += 0.22 * (0.5 + 0.5 * (u * 7.2 + 0.6).cos()) * env;
        }
    }
    let micro = 0.020 * (u * 8.5 + variant as f32 * 2.1).sin();
    ((h + micro * env) * env).clamp(0.0, 1.05)
}

/// The frozen project's far mountains: distant_landscape.gd's three rings (30, 34 and 38 ridges at
/// 460, 740 and 1060 m) of its `_mountain` mesh, posed exactly as Godot posed them (the poses come
/// from Godot itself: data/mountain_poses.json, written by data/godot_mountain_poses.gd, since its
/// RandomNumberGenerator is not reproduced here). Coordinates are relative to the landscape's
/// centre; vs_terms adds the view's centre (surface id 20). Each vertex carries the mesh's local
/// height (grad, over 1.05) and spine closeness (line) for distant_mountain.gdshader. The grid is
/// 96 x 20 instead of Godot's 144 x 36; normals are smooth (Godot softens them at 78 degrees).
fn far_mountains() -> Mesh {
    let text = std::fs::read_to_string("runtime/spikes/s34_study/data/mountain_poses.json").expect("mountain poses");
    let json: serde_json::Value = serde_json::from_str(&text).expect("poses json");
    let (nx, nz) = (96usize, 20usize);
    let mut mesh = Mesh::default();
    for pose in json["poses"].as_array().expect("poses") {
        let v: Vec<f32> = pose.as_array().unwrap().iter().map(|x| x.as_f64().unwrap() as f32).collect();
        let variant = v[0] as usize;
        let basis = glam::Mat3::from_cols(Vec3::new(v[1], v[2], v[3]), Vec3::new(v[4], v[5], v[6]), Vec3::new(v[7], v[8], v[9]));
        let origin = Vec3::new(v[10], v[11], v[12]);
        let normal_matrix = basis.inverse().transpose();
        let fv = variant as f32;
        // Local grid point and its spine closeness (1 - |v|).
        let local = |ix: usize, iz: usize| -> (Vec3, f32) {
            let u = ix as f32 / nx as f32 * 2.0 - 1.0;
            let ch = crest_height(variant, u);
            let spine_z = 0.15 * (u * 2.8 + fv * 1.4).sin() + 0.045 * (u * 5.8 - fv).cos();
            let w = iz as f32 / nz as f32 * 2.0 - 1.0;
            let d = ((w * w + 0.0020).sqrt() - 0.044).clamp(0.0, 1.0);
            let base_slope = (1.0 - d).max(0.0).powf(1.42);
            let spur_phase = u * 7.4 + fv * 1.85 + w * 1.15;
            let spur_fold = 0.11 * (0.5 + 0.5 * spur_phase.sin()).max(0.0).powi(2) * d * (1.0 - d).max(0.0).powf(0.85) * 2.4;
            let y = (ch * (base_slope + spur_fold)).max(0.0);
            let width_env = 0.35 + 0.65 * (1.0 - u * u).max(0.0).sqrt();
            let z = spine_z * (1.0 - 0.55 * d) + w * width_env;
            (Vec3::new(u * 1.45, y, z), (1.0 - w.abs()).clamp(0.0, 1.0))
        };
        let normal = |ix: usize, iz: usize| -> Vec3 {
            let (a, b) = (local(ix.saturating_sub(1), iz).0, local((ix + 1).min(nx), iz).0);
            let (c, e) = (local(ix, iz.saturating_sub(1)).0, local(ix, (iz + 1).min(nz)).0);
            let mut n = (e - c).cross(b - a);
            if n.y < 0.0 {
                n = -n;
            }
            // Godot's forward renderer turns a MultiMesh instance's normals by the instance basis
            // itself (model_normal_matrix * mat3(instance)), not its inverse transpose; with these
            // poses' strong non-uniform scale that leans the normals along each ridge and
            // flattens its front, which is what gives the reference ridges their lit and shaded
            // ends. Ported as Godot draws it.
            let _ = normal_matrix;
            let mut world = (basis * n).normalize_or_zero();
            if world.y < 0.0 {
                world = -world;
            }
            world
        };
        let vertex = |ix: usize, iz: usize| -> (Vec3, Vec3, Paint) {
            let (p, spine) = local(ix, iz);
            let paint = Paint::new(Family::Wood).sky(1.0).line(spine).id(20).grad(p.y / 1.05);
            (origin + basis * p, normal(ix, iz), paint)
        };
        let colour = Vec3::splat(0.8);
        for ix in 0..nx {
            for iz in 0..nz {
                let corners = [(ix, iz), (ix + 1, iz), (ix + 1, iz + 1), (ix, iz + 1)];
                if corners.iter().all(|&(x, z)| local(x, z).0.y < 0.002) {
                    continue;
                }
                let q = corners.map(|(x, z)| vertex(x, z));
                for tri in [[0, 1, 2], [0, 2, 3]] {
                    mesh.tri_full(tri.map(|i| q[i].0), tri.map(|i| q[i].1), [colour; 3], tri.map(|i| q[i].2));
                }
            }
        }
    }
    mesh
}

// Round r5: the r4 mounds and cloud sea are kept for the three-island wallpaper view only
// (--scene=trio), whose low camera looks along the cloud sea, where Godot's far field (decks
// only well below the horizon, the 460 m ridges filling the view) was never meant to be seen.
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
    // S34_HEIGHTS="x0,z0,x1,z1": the ground height on a 0.25 m grid (hole hunting).
    if let (Ok(spec), true) = (std::env::var("S34_HEIGHTS"), origin == Vec3::ZERO) {
        let v: Vec<f32> = spec.split(',').map(|s| s.parse().unwrap()).collect();
        let mut z = v[1];
        while z <= v[3] {
            let mut row = format!("HEIGHTS z {z:6.2}:");
            let mut x = v[0];
            while x <= v[2] {
                let p = Vec2::new(x, z);
                let mark = if field.water_at(p).is_some() { 'w' } else if field.nearest_wall(p, 0.15).is_some() { '|' } else { ' ' };
                row += &format!(" {:4.2}{mark}", field.height_at(p));
                x += 0.25;
            }
            println!("{row}");
            z += 0.25;
        }
    }
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
            // A layout's own scene is loaded where it stood; an island without one (synthetic) gets
            // that scene's props scattered over it.
            let report = if courtyard { props::load(dir, cells, &field, origin, library) } else { props::scatter(dir, cells, &field, origin, seed, library) };
            println!("{}", report.line(dir));
            prop_triangles = report.triangles;
            clear = report.clear;
            Mesh::default()
        }
        None if courtyard => decor::courtyard(cells, &field, &colours, seed, &mut clear),
        None => decor::scatter(cells, &field, &colours, seed, &mut clear),
    };
    lap("decor", &mut timings);
    let grass = grass::build(&field, &top.rim, &top.brows, &body.fringe, &clear, seed, origin, field::TopColours::default().lawn);
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
    Built { solid, water: water::build_water(cells, &field, origin), grass, faces: body.faces, columns: body.columns, timings, parts }
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
                        edited.entry(key).or_insert(field::Cell::flat(cells[&at].h, None));
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
    // Round r9: a ramp stroke across a terrace wall (the wall edge a third of the way through the
    // sorted list that takes a valid ramp). Besides the rim plan, the top surface (lawn, banks and
    // walls) is compared vertex by vertex: a vertex is changed when the other build has none within 1 cm.
    // Round r10: and a diagonal one, 45 degrees off the wall's normal, width 2, from the wall edge two
    // thirds of the way through the list.
    let walls = field::wall_edges(cells);
    for (label, angle, width, from) in [("ramp", 0.0_f32, 2.0_f32, walls.len() / 3), ("diag", 45.0, 2.0, walls.len() * 2 / 3)] {
    let mut stroke: Option<(Vec2, Vec2, Cells)> = None;
    for k in 0..walls.len() {
        let (k1, k2) = walls[(from + k) % walls.len()];
        let (a, b) = field::ramp_across_turned(cells, k1, k2, 0.3, angle);
        let mut edited = cells.clone();
        if let Ok(done) = field::ramp(&mut edited, a, b, width) {
            stroke = Some((done.a, done.b, edited));
            break;
        }
    }
    if let Some((a, b, edited)) = stroke {
        let to_stroke = |p: Vec2| {
            let ab = b - a;
            let t = ((p - a).dot(ab) / ab.length_squared()).clamp(0.0, 1.0);
            (p - (a + ab * t)).length()
        };
        let (after, _, _) = plan(&edited);
        let alike = |f: &body::Face, g: &body::Face| (f.a - g.a).length() <= 0.30 && (f.b - g.b).length() <= 0.30 && (f.top - g.top).abs() <= 0.26;
        let mut farthest: f32 = 0.0;
        let (mut changed, mut far) = (0, 0);
        for face in before.iter().filter(|f| !after.iter().any(|g| alike(f, g))).chain(after.iter().filter(|f| !before.iter().any(|g| alike(f, g)))) {
            changed += 1;
            let d = to_stroke(face.a).min(to_stroke(face.b));
            farthest = farthest.max(d);
            if d > 12.0 {
                far += 1;
            }
        }
        let top_points = |cells: &Cells| -> Vec<Vec3> {
            let field = field::Field::build(cells);
            let top = field::build_top(&field, &field::TopColours::default(), seed);
            let mut seen = std::collections::HashSet::new();
            top.mesh.vertices.iter().map(|v| Vec3::from(v.pos)).filter(|p| seen.insert(((p.x * 1e4) as i64, (p.y * 1e4) as i64, (p.z * 1e4) as i64))).collect()
        };
        let (p0, p1) = (top_points(cells), top_points(&edited));
        let index = |set: &[Vec3]| {
            let mut map: std::collections::HashMap<(i32, i32, i32), Vec<Vec3>> = std::collections::HashMap::new();
            for p in set {
                map.entry(((p.x * 10.0).floor() as i32, (p.y * 10.0).floor() as i32, (p.z * 10.0).floor() as i32)).or_default().push(*p);
            }
            map
        };
        let (i0, i1) = (index(&p0), index(&p1));
        let has = |map: &std::collections::HashMap<(i32, i32, i32), Vec<Vec3>>, p: Vec3| {
            let k = ((p.x * 10.0).floor() as i32, (p.y * 10.0).floor() as i32, (p.z * 10.0).floor() as i32);
            (-1..=1).any(|dx| (-1..=1).any(|dy| (-1..=1).any(|dz| map.get(&(k.0 + dx, k.1 + dy, k.2 + dz)).is_some_and(|l| l.iter().any(|q| (*q - p).length() < 0.01)))))
        };
        let mut top_far: f32 = 0.0;
        let mut top_changed = 0;
        let mut top_beyond = 0;
        for p in p0.iter().filter(|p| !has(&i1, **p)).chain(p1.iter().filter(|p| !has(&i0, **p))) {
            top_changed += 1;
            let d = to_stroke(Vec2::new(p.x, p.z));
            top_far = top_far.max(d);
            if d > 12.0 {
                top_beyond += 1;
            }
        }
        println!(
            "EDIT {label:8} a=({:.1}, {:.1}) b=({:.1}, {:.1}) width {width:.0}: {changed} faces changed, farthest {farthest:.2} m from the stroke, {far} beyond 12 m; top surface {top_changed} of {} vertices changed, farthest {top_far:.2} m, {top_beyond} beyond 12 m",
            a.x, a.y, b.x, b.y, p1.len()
        );
        lines.push(format!(
            "  {{\"stroke\": \"{label}\", \"a\": [{:.2}, {:.2}], \"b\": [{:.2}, {:.2}], \"width\": {width:.0}, \"faces_changed\": {changed}, \"farthest_change_m\": {farthest:.2}, \"changed_beyond_12m\": {far}, \"top_vertices_changed\": {top_changed}, \"top_farthest_m\": {top_far:.2}, \"top_beyond_12m\": {top_beyond}}}",
            a.x, a.y, b.x, b.y
        ));
    } else {
        println!("EDIT {label:8} no wall takes a valid ramp");
    }
    }
    lines.join(",\n")
}

/// Round r10: the ramp views (name, target, yaw, pitch, distance); see where they are added to the
/// cameras. ramp1..3: the three ramps of layout_7301_0_ramps.json; slope: the broad slope of
/// layout_4242_1_slope.json; diag1, diag2: the diagonal ramps of layout_2104_0_ramps.json.
const RAMP_VIEWS: [(&str, [f32; 3], f32, f32, f32); 6] = [
    ("ramp1", [-1.0, 2.0, 8.0], 125.0, 30.0, 14.0),
    ("ramp2", [-5.0, 3.0, 5.5], 35.0, 30.0, 14.0),
    ("ramp3", [-7.5, 4.25, -9.0], 200.0, 30.0, 14.0),
    ("slope", [5.0, 2.5, -3.0], 55.0, 28.0, 16.0),
    ("diag1", [-13.0, 4.25, -7.5], 25.0, 30.0, 13.0),
    ("diag2", [7.0, 2.5, -4.5], 95.0, 30.0, 14.0),
];

/// Round r9 (`--synthetic-ramps`): one ramp of width 2 across each long terrace wall (8 or more
/// cell edges between the same two levels), near the middle of the wall, deterministic. A ramp is
/// skipped when its strip would leave the two levels it joins, cover water, or come within 4 m of
/// another ramp.
fn synthetic_ramps(cells: &Cells) -> Vec<[f32; 5]> {
    let edges = field::wall_edges(cells);
    let n = edges.len();
    let mut group: Vec<usize> = (0..n).collect();
    fn root(group: &mut [usize], i: usize) -> usize {
        let mut r = i;
        while group[r] != r {
            r = group[r];
        }
        group[i] = r;
        r
    }
    let levels = |e: &((i32, i32), (i32, i32))| {
        let (a, b) = (cells[&e.0].h, cells[&e.1].h);
        ((a.max(b) * 4.0).round() as i32, (a.min(b) * 4.0).round() as i32)
    };
    let corners = |e: &((i32, i32), (i32, i32))| {
        let ((x, z), (x2, _)) = *e;
        if x2 != x { [(x + 1, z), (x + 1, z + 1)] } else { [(x, z + 1), (x + 1, z + 1)] }
    };
    let mut by_corner: std::collections::HashMap<(i32, i32), Vec<usize>> = std::collections::HashMap::new();
    for (i, e) in edges.iter().enumerate() {
        for c in corners(e) {
            by_corner.entry(c).or_default().push(i);
        }
    }
    let mut keys: Vec<(i32, i32)> = by_corner.keys().copied().collect();
    keys.sort();
    for c in keys {
        let list = by_corner[&c].clone();
        for &i in &list {
            for &j in &list {
                if i < j && levels(&edges[i]) == levels(&edges[j]) {
                    let (ri, rj) = (root(&mut group, i), root(&mut group, j));
                    group[ri.max(rj)] = ri.min(rj);
                }
            }
        }
    }
    let mut groups: std::collections::BTreeMap<usize, Vec<usize>> = std::collections::BTreeMap::new();
    for i in 0..n {
        let r = root(&mut group, i);
        groups.entry(r).or_default().push(i);
    }
    let mut out: Vec<[f32; 5]> = Vec::new();
    let mut centres: Vec<Vec2> = Vec::new();
    for (_, list) in groups {
        if list.len() < 8 {
            continue;
        }
        let mid_of = |i: usize| (field::centre_of(edges[i].0) + field::centre_of(edges[i].1)) * 0.5;
        let centroid = list.iter().map(|&i| mid_of(i)).sum::<Vec2>() / list.len() as f32;
        let mut order = list.clone();
        order.sort_by(|&i, &j| (mid_of(i) - centroid).length().partial_cmp(&(mid_of(j) - centroid).length()).unwrap().then(i.cmp(&j)));
        // Round r10: the ramps take turns at a direction and width, so the island mixes axis-aligned
        // and diagonal strokes (straight across the wall, then 30 and 45 degrees off it, width 2 or 3).
        let (angle, width) = [(0.0_f32, 2.0_f32), (30.0, 2.0), (45.0, 3.0), (-30.0, 3.0)][out.len() % 4];
        for &i in order.iter().take(8) {
            let (k1, k2) = edges[i];
            let (a, b) = field::ramp_across_turned(cells, k1, k2, 0.3, angle);
            let centre = (a + b) * 0.5;
            if centres.iter().any(|c| (*c - centre).length() < 4.0) {
                continue;
            }
            let (lo, hi) = (cells[&k1].h.min(cells[&k2].h), cells[&k1].h.max(cells[&k2].h));
            // The strip may only hold the two levels it joins, all dry and flat.
            let dir = (b - a).normalize();
            let length = (b - a).length();
            let strip_ok = cells.iter().all(|(&key, c)| {
                let p = field::centre_of(key);
                let t = (p - a).dot(dir) / length;
                let off = (p - (a + dir * length * t.clamp(0.0, 1.0))).length();
                if !(-1e-4..=1.0 + 1e-4).contains(&t) || off > width * 0.5 + 1e-4 {
                    return true;
                }
                c.water.is_none() && !c.sloped() && ((c.h - lo).abs() < 1e-3 || (c.h - hi).abs() < 1e-3)
            });
            // Both ends on the two levels the ramp joins.
            let ends_ok = [a, b].iter().all(|p| field::cell_surface(cells, *p).is_some_and(|(h, _)| (h - lo).abs() < 1e-3 || (h - hi).abs() < 1e-3));
            let mut test = cells.clone();
            if strip_ok && ends_ok && field::ramp(&mut test, a, b, width).is_ok() {
                out.push([a.x, a.y, b.x, b.y, width]);
                centres.push(centre);
                break;
            }
        }
    }
    out
}

fn main() {
    let args = parse_args();
    let mut cells = match (&args.layout, args.synthetic) {
        (Some(path), _) => field::load_layout(path),
        (None, count) if count > 0 => field::synthetic(count, args.seed),
        _ => panic!("give --layout=FILE or --synthetic=COUNT"),
    };
    // Round r9: ramp strokes, as a player's tool would make them.
    let mut strokes: Vec<[f32; 5]> = args.ramps.clone();
    if args.synthetic_ramps {
        strokes.extend(synthetic_ramps(&cells));
    }
    for r in &strokes {
        let (a, b) = (Vec2::new(r[0], r[1]), Vec2::new(r[2], r[3]));
        match field::ramp(&mut cells, a, b, r[4]) {
            Ok(done) => {
                let angle = (done.b - done.a).y.atan2((done.b - done.a).x).to_degrees();
                println!(
                    "RAMP a=({:.2}, {:.2}) b=({:.2}, {:.2}) width {:.1} (drawn ({:.2}, {:.2}) to ({:.2}, {:.2}), {:.0} deg) : {} cells, rise {:.2} m over {:.2} m, gradient {:.3}",
                    done.a.x, done.a.y, done.b.x, done.b.y, r[4], a.x, a.y, b.x, b.y, angle, done.cells, done.rise, done.length, done.gradient
                )
            }
            Err(reason) => println!("RAMP refused: {reason} (a=({:.2}, {:.2}) b=({:.2}, {:.2}) width {:.1})", a.x, a.y, b.x, b.y, r[4]),
        }
    }
    if let Some(path) = &args.save_layout {
        let (seed, preset) = match &args.layout {
            Some(p) => {
                let json: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(p).unwrap()).unwrap();
                (json["seed"].as_u64().unwrap_or(args.seed as u64) as u32, json["preset"].as_i64().unwrap_or(0))
            }
            None => (args.seed, 0),
        };
        field::save_layout(path, &cells, seed, preset);
        println!("LAYOUT saved {path} ({} cells, {} slope cells, version 2)", cells.len(), cells.values().filter(|c| c.sloped()).count());
    }
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
    // A synthetic island gets layout 7301's exported props scattered over it (unless --props=none
    // or another scene folder is given).
    let main_props = if args.synthetic > 0 && args.layout.is_none() {
        match args.props.as_str() {
            "none" => None,
            "auto" => Some(std::path::PathBuf::from("runtime/data/reference/scene_7301_0")),
            dir => Some(dir.into()),
        }
    } else {
        props_for(args.layout.as_deref(), true)
    };
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
    let wallpaper = args.scene == "trio";
    solid.append(&if wallpaper { far_mounds(args.seed) } else { far_mountains() });
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
    // The review set's whole-island view of the 623-cell layouts: the distance the near air is tuned for.
    let whole_reach = cameras.iter().find(|(n, _)| n == "whole").map_or(60.0, |(_, c)| (c.eye - c.target).length());
    cameras.push(("wallpaper".to_string(), Camera { eye: Vec3::new(26.0, 24.0, 122.0), target: Vec3::new(2.0, 0.0, -4.0), fov_deg: 31.0 }));
    cameras.push(("below".to_string(), Camera { eye: Vec3::new(14.0, -19.0, 30.0), target: Vec3::new(-1.0, -2.0, -1.0), fov_deg: 31.0 }));
    // Round r10: views that show the ramps, each named for a ramp of a reference layout and fixed in
    // the world, so the plain layout renders from the same camera (before and after). The camera
    // looks at the ramp's middle at its mid height from `dist` metres, `pitch` degrees down, from
    // the ramp's low side about 35 degrees off its axis, looking up the ramp: the incline rising
    // through the terrace wall it cuts, the wall's face on either side, on whichever side nothing
    // large stands in front. (From 60 degrees off, the raised cheek of the ramp's lower half faced
    // the camera and hid the incline.) `yaw` as in cameras.json (the eye lies toward (sin yaw,
    // cos yaw) from the target).
    for (name, target, yaw, pitch, dist) in RAMP_VIEWS {
        let (y, p) = (yaw.to_radians(), pitch.to_radians());
        let target = Vec3::from(target);
        cameras.push((name.to_string(), Camera { eye: target + Vec3::new(y.sin() * p.cos(), p.sin(), y.cos() * p.cos()) * dist, target, fov_deg: 31.0 }));
    }
    if args.synthetic > 0 {
        // A synthetic island has its own size: frame it whole and close.
        let reach = cells.keys().map(|&(x, z)| Vec2::new(x as f32, z as f32).length()).fold(0.0, f32::max);
        cameras.retain(|(name, _)| name != "whole" && name != "game");
        cameras.push(("whole".to_string(), Camera::orbit([0.0, 0.0], reach * 1.35, 16.0, 30.0)));
        cameras.push(("game".to_string(), Camera::orbit([reach * 0.2, reach * 0.1], reach * 0.55, 16.0, 27.0)));
    }
    // Ad hoc close-ups for hole hunting: S34_CAMERA="ex,ey,ez,tx,ty,tz,fov" adds a view named "probe".
    if let Ok(spec) = std::env::var("S34_CAMERA") {
        let v: Vec<f32> = spec.split(',').map(|s| s.trim().parse().expect("S34_CAMERA numbers")).collect();
        cameras.push(("probe".to_string(), Camera { eye: Vec3::new(v[0], v[1], v[2]), target: Vec3::new(v[3], v[4], v[5]), fov_deg: v[6] }));
    }
    let wanted: Vec<&str> = args.views.split(',').collect();
    // S34_PICK="view:x,y;x,y": the island point under output pixels (CPU ray cast on the solid mesh).
    if let Ok(spec) = std::env::var("S34_PICK") {
        let (view, list) = spec.split_once(':').expect("S34_PICK view:x,y;...");
        if let Some((_, cam)) = cameras.iter().find(|(n, _)| n == view) {
            let aspect = args.width as f32 / args.height as f32;
            let fwd = (cam.target - cam.eye).normalize();
            let right = fwd.cross(Vec3::Y).normalize();
            let up = right.cross(fwd);
            let half = (cam.fov_deg.to_radians() * 0.5).tan();
            for item in list.split(';') {
                let (x, y) = item.split_once(',').unwrap();
                let (x, y): (f32, f32) = (x.parse().unwrap(), y.parse().unwrap());
                let sx = ((x + 0.5) / args.width as f32 * 2.0 - 1.0) * half * aspect;
                let sy = (1.0 - (y + 0.5) / args.height as f32 * 2.0) * half;
                let dir = (fwd + right * sx + up * sy).normalize();
                let mut best: Option<(f32, usize)> = None;
                let v = &solid.vertices;
                for t in 0..casters / 3 {
                    let (p0, p1, p2) = (Vec3::from(v[t * 3].pos), Vec3::from(v[t * 3 + 1].pos), Vec3::from(v[t * 3 + 2].pos));
                    let (e1, e2) = (p1 - p0, p2 - p0);
                    let h = dir.cross(e2);
                    let a = e1.dot(h);
                    if a.abs() < 1e-9 {
                        continue;
                    }
                    let f = 1.0 / a;
                    let s = cam.eye - p0;
                    let u = f * s.dot(h);
                    if !(0.0..=1.0).contains(&u) {
                        continue;
                    }
                    let q = s.cross(e1);
                    let w = f * dir.dot(q);
                    if w < 0.0 || u + w > 1.0 {
                        continue;
                    }
                    let d = f * e2.dot(q);
                    if d > 0.01 && best.map_or(true, |b| d < b.0) {
                        best = Some((d, t));
                    }
                }
                match best {
                    Some((d, t)) => {
                        let p = cam.eye + dir * d;
                        let vx = &v[t * 3];
                        println!("PICK {view} ({x},{y}): at ({:.2}, {:.2}, {:.2}), {:.1} m, normal ({:.2}, {:.2}, {:.2}), paint id {}", p.x, p.y, p.z, d, vx.normal[0], vx.normal[1], vx.normal[2], vx.extra[0]);
                    }
                    None => println!("PICK {view} ({x},{y}): nothing"),
                }
            }
        }
    }

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
    if let Some(lamp) = library.lanterns.first() {
        light[41] = [lamp.x, lamp.y, lamp.z, 1.0];
    }
    std::fs::create_dir_all(&args.out).expect("output folder");
    let mut bench_lines = Vec::new();
    let mut frame_lines = Vec::new();
    for (name, camera) in cameras.iter() {
        let extra = name == "wallpaper" || name == "below" || RAMP_VIEWS.iter().any(|v| v.0 == name);
        if !(wanted.contains(&"all") && !extra) && !wanted.contains(&name.as_str()) {
            continue;
        }
        let mut light = light;
        // The near air scales with how far the camera stands from what it orbits (1 up to the
        // review set's whole-island view).
        light[16][0] = if wallpaper { 1.0 } else { ((camera.eye - camera.target).length() / whole_reach).max(1.0) };
        // Round r8: the root mist rises to where the Godot baseline's walls dissolve, at a fairly even
        // level 6 to 8 m under the lawn's edge (its stone_root_veil runs from y -2.5 to -5.7); the
        // hanging columns below are only soft shapes in it. The three-island view keeps the old
        // band (its islands stand at other heights).
        if !wallpaper {
            light[12][0] = -4.0;
            light[12][1] = -6.9;
        }
        // Godot keeps the distant landscape under the camera's orbit centre.
        if wallpaper {
            // The r4 far field (mounds built round the origin, the r4 cloud sea).
            light[29][1] = 1.0;
        } else {
            light[29][0] = camera.target.x;
            light[29][2] = camera.target.z;
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
