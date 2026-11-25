//! Round k5: `--window`, the study's picture on the Mac's screen in real time, with the presented
//! frame rate and pacing measured, not only the off-screen render time.
//!
//!   s34_study --window --layout=runtime/data/reference/layout_7301_0.json
//!             [--scenarios=idle,moving,editing] [--seconds=20] [--warmup=2]
//!             [--present-mode=fifo|immediate] [--latency=2] [--fullscreen=cover|native]
//!             [--present=direct|blit] [--upload=worker|main] [--scale=1] [--fxaa=on|off]
//!             [--edit=raise] [--edit-period=2.5] [--presented-time=on|off] [--gpu-time=on|off]
//!             [--shadow=cached|always] [--hour=day] [--out=DIR] [--tag=NAME]
//!
//! One borderless full-screen window on the main display; the existing `Renderer` draws every
//! frame at the window's drawable size (3600 x 2338 on the owner's scaled 1800 x 1169 mode), and
//! its last pass writes straight into the surface texture (`--present=direct`) or into the
//! renderer's final texture, which a full-screen pass then copies (`--present=blit`). The
//! renderer's final values are display-encoded, so the surface is plain `Bgra8Unorm` (no sRGB
//! encode on write) tagged sRGB for the compositor.
//!
//! Scenarios, each `--seconds` long, camera `game` of cameras.json, day light:
//! - `idle`: camera still, the shadow map drawn once and cached;
//! - `moving`: the camera orbits its target at 0.72 rad/s (`Renderer::bench`'s 0.012 rad a frame
//!   at 60 frames a second), shadow map cached;
//! - `editing`: camera still; every `--edit-period` seconds one settle edit (settle.rs
//!   `sequences()`, default `raise`) is issued, alternating with its undo. The island is rebuilt
//!   on a worker thread (`rebuild_island`, the one function to swap for an incremental update),
//!   which also builds the settle map and prepares the upload; the frame loop keeps presenting,
//!   installs the result when it arrives and starts the settle clock in that frame. While the
//!   motion runs the shadow map is redrawn every frame.
//!
//! Per presented frame (CSV): CPU times of the frame's start, surface acquire, submit and
//! present call (CACurrentMediaTime seconds), the GPU span of the frame's passes from timestamp
//! queries (gputime.rs), and, with `--presented-time=on`, the time the frame reached the glass
//! (`MTLDrawable.presentedTime`, read in a presented handler attached to every drawable the
//! layer hands out).
use std::sync::atomic::Ordering;
use std::sync::mpsc;
use std::sync::Arc;

use glam::{Vec2, Vec3};
use winit::application::ApplicationHandler;
use winit::dpi::PhysicalPosition;
use winit::event::{ElementState, KeyEvent, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::keyboard::{Key, NamedKey};
use winit::window::{Fullscreen, Window, WindowId, WindowLevel};

use crate::field::{self, Cells};
use crate::grass::Grass;
use crate::mesh::{Mesh, Vertex};
use crate::props::{Library, Placement};
use crate::render::{Camera, Frame, Renderer, LIGHT_SLOTS, SETTLE_SLOT};
use crate::settle::{self, SettleMap};
use crate::water::WaterVertex;

/// The camera's orbit speed in the moving scenario (radians a second).
const ORBIT_RATE: f32 = 0.72;
/// The settle motion is over this long after its clock started (settle::END plus the ripple).
const MOTION_SECONDS: f32 = settle::END + 0.6;
/// Statistics skip this much of the start of each scenario (seconds).
const SETTLE_IN: f64 = 0.5;

struct Opts {
    layout: String,
    seed: u32,
    scale: u32,
    fxaa: bool,
    hour: String,
    scenarios: Vec<String>,
    seconds: f64,
    warmup: f64,
    present_mode: wgpu::PresentMode,
    latency: u32,
    fullscreen: String,
    direct: bool,
    worker_upload: bool,
    edit: String,
    edit_period: f64,
    presented_time: bool,
    gpu_time: bool,
    shadow_always: bool,
    /// Disclosed quality option: draw at this fraction of the surface size, stretched (1: native).
    render_scale: f32,
    /// Frame pacing: start frames at this rate, phase-locked to the display (0: as fast as Fifo allows).
    pace: f64,
    /// Sample the frame's state after the drawable is acquired (late latching) or before.
    late_latch: bool,
    out: String,
    tag: String,
}

fn parse() -> Opts {
    let mut o = Opts {
        layout: "runtime/data/reference/layout_7301_0.json".into(),
        seed: 7301,
        scale: 1,
        fxaa: true,
        hour: "day".into(),
        scenarios: vec!["idle".into(), "moving".into(), "editing".into()],
        seconds: 20.0,
        warmup: 2.0,
        present_mode: wgpu::PresentMode::Fifo,
        latency: 2,
        fullscreen: "cover".into(),
        direct: true,
        worker_upload: true,
        edit: "raise".into(),
        edit_period: 2.5,
        presented_time: true,
        gpu_time: true,
        shadow_always: false,
        render_scale: 1.0,
        pace: 0.0,
        late_latch: true,
        out: "/tmp/tsw_present/runs".into(),
        tag: "win".into(),
    };
    for arg in std::env::args().skip(1) {
        let (key, value) = arg.split_once('=').unwrap_or((arg.as_str(), ""));
        let on = value != "off";
        match key {
            "--window" => {}
            "--layout" => o.layout = value.into(),
            "--seed" => o.seed = value.parse().expect("seed"),
            "--scale" => o.scale = value.parse().expect("scale"),
            "--fxaa" => o.fxaa = on,
            "--hour" => o.hour = value.into(),
            "--scenarios" => o.scenarios = value.split(',').map(|s| s.to_string()).collect(),
            "--seconds" => o.seconds = value.parse().expect("seconds"),
            "--warmup" => o.warmup = value.parse().expect("warmup"),
            "--present-mode" => {
                o.present_mode = match value {
                    "immediate" => wgpu::PresentMode::Immediate,
                    "mailbox" => wgpu::PresentMode::Mailbox,
                    _ => wgpu::PresentMode::Fifo,
                }
            }
            "--latency" => o.latency = value.parse().expect("latency"),
            "--fullscreen" => o.fullscreen = value.into(),
            "--present" => o.direct = value != "blit",
            "--upload" => o.worker_upload = value != "main",
            "--edit" => o.edit = value.into(),
            "--edit-period" => o.edit_period = value.parse().expect("edit period"),
            "--presented-time" => o.presented_time = on,
            "--gpu-time" => o.gpu_time = on,
            "--shadow" => o.shadow_always = value == "always",
            "--render-scale" => o.render_scale = value.parse().expect("render scale"),
            "--pace" => o.pace = value.parse().expect("pace Hz"),
            "--latch" => o.late_latch = value != "early",
            "--out" => o.out = value.into(),
            "--tag" => o.tag = value.into(),
            other => panic!("unknown argument for --window: {other}"),
        }
    }
    o
}

/// Seconds on the host clock that `MTLDrawable.presentedTime` uses (CACurrentMediaTime).
fn now() -> f64 {
    mac::now()
}

// ---------------------------------------------------------------------------------------------
// The island and its edits.

/// What the scene is built from (shared with the worker thread).
#[derive(Clone)]
pub struct SceneSpec {
    pub props: Option<std::path::PathBuf>,
    pub body: crate::body::Kind,
    pub seed: u32,
}

/// THE rebuild after an edit: today the whole island, as the study always did (about 70 to 90 ms
/// on layout 7301). Swap this one function for an incremental update; everything else (settle map,
/// upload preparation, the frame loop) stays.
pub fn rebuild_island(cells: &Cells, placed: &[Placement], spec: &SceneSpec) -> (crate::Built, Library) {
    let mut library = Library::default();
    let built = crate::build_island(cells, spec.body, spec.seed, Vec3::ZERO, true, spec.props.as_deref(), &mut library, placed);
    (built, library)
}

/// The island ready for upload: vertices with the far mountains appended (the first `casters`
/// cast shadows), water, grass and props.
struct Scene {
    vertices: Vec<Vertex>,
    casters: usize,
    water: Vec<WaterVertex>,
    grass: Grass,
    library: Library,
}

fn scene_of(built: crate::Built, library: Library, far: &Mesh) -> (Scene, field::Field) {
    let mut solid = Mesh::default();
    solid.append(&built.solid);
    let casters = solid.vertices.len();
    solid.append(far);
    (Scene { vertices: solid.vertices, casters, water: built.water, grass: built.grass, library }, built.field)
}

/// GPU buffers made on the worker thread (`--upload=worker`): the frame loop only swaps them in.
struct Buffers {
    upload: crate::render::Prepared,
}

struct Job {
    index: usize,
    forward: bool,
}

struct Done {
    index: usize,
    rebuild_ms: f64,
    map_ms: f64,
    prep_ms: f64,
    finished: f64,
    scene: Option<Scene>,
    buffers: Option<Buffers>,
    map: SettleMap,
    items: Vec<[f32; 4]>,
}

/// The worker: holds the island's current cells and fields, applies the edit or its undo, rebuilds,
/// builds the settle map against the state before, and prepares the upload.
fn spawn_worker(base: Cells, field: field::Field, edit: (Cells, Vec<Placement>, Vec2, Vec2, Vec2), spec: SceneSpec, far: Mesh, device: Option<wgpu::Device>) -> (mpsc::Sender<Job>, mpsc::Receiver<Done>) {
    let (job_tx, job_rx) = mpsc::channel::<Job>();
    let (done_tx, done_rx) = mpsc::channel::<Done>();
    std::thread::spawn(move || {
        let (edited, placed, lo, hi, centre) = edit;
        let mut current = (base.clone(), field);
        for job in job_rx {
            let (target, items_placed): (&Cells, &[Placement]) = if job.forward { (&edited, &placed) } else { (&base, &[]) };
            let start = now();
            let (built, library) = rebuild_island(target, items_placed, &spec);
            let rebuilt = now();
            let (items, regrow) = settle::instance_table(&library, items_placed, centre);
            let map = settle::build_map(&current.0, &current.1, target, &built.field, lo, hi, centre, &regrow);
            let mapped = now();
            let (scene, buffers, field) = match &device {
                // The island's vertices and the far mountains go straight into one mapped buffer.
                Some(device) => {
                    let upload = crate::render::Renderer::prepare(device, &built.solid.vertices, &far.vertices, &built.water, &library, &built.grass, &map.texels, &items);
                    (None, Some(Buffers { upload }), built.field)
                }
                None => {
                    let (scene, field) = scene_of(built, library, &far);
                    (Some(scene), None, field)
                }
            };
            let prepared = now();
            current = (target.clone(), field);
            let done = Done {
                index: job.index,
                rebuild_ms: (rebuilt - start) * 1000.0,
                map_ms: (mapped - rebuilt) * 1000.0,
                prep_ms: (prepared - mapped) * 1000.0,
                finished: prepared,
                scene,
                buffers,
                map,
                items,
            };
            if done_tx.send(done).is_err() {
                break;
            }
        }
    });
    (job_tx, done_rx)
}

// ---------------------------------------------------------------------------------------------
// Records.

#[derive(Clone, Default)]
struct Row {
    frame: u64,
    scenario: usize,
    /// Seconds since the scenario started (at the frame's start).
    t: f64,
    begin: f64,
    acquired: f64,
    /// When the frame's state (camera, clock, edits) was sampled.
    sampled: f64,
    encoded: f64,
    submitted: f64,
    presented: f64,
    upload_ms: f64,
    shadow: bool,
    clock: f32,
    gpu_ms: Option<f64>,
    glass: Option<f64>,
}

#[derive(Clone, Default)]
struct EditRec {
    index: usize,
    forward: bool,
    issued: f64,
    worker_done: f64,
    installed: f64,
    rebuild_ms: f64,
    map_ms: f64,
    prep_ms: f64,
    upload_ms: f64,
    first_frame: Option<u64>,
}

struct Scenario {
    name: String,
    start: f64,
    edits: Vec<EditRec>,
}

/// Value at quantile q of a sorted list.
fn pick(sorted: &[f64], q: f64) -> f64 {
    if sorted.is_empty() {
        return f64::NAN;
    }
    sorted[((sorted.len() - 1) as f64 * q).round() as usize]
}

fn sorted(mut v: Vec<f64>) -> Vec<f64> {
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    v
}

// ---------------------------------------------------------------------------------------------
// The window.

struct Gpu {
    surface: wgpu::Surface<'static>,
    device: wgpu::Device,
    queue: wgpu::Queue,
    config: wgpu::SurfaceConfiguration,
    renderer: Renderer,
    blit: Option<(wgpu::RenderPipeline, wgpu::BindGroup)>,
}

struct Motion {
    start: f64,
    slots: [[f32; 4]; 2],
}

struct App {
    o: Opts,
    window: Option<Arc<Window>>,
    gpu: Option<Gpu>,
    notes: Vec<String>,
    opened: f64,
    /// Rendering (and recording) starts once the window has settled.
    begin_at: f64,
    // Scene.
    initial: Option<(Scene, field::Field)>,
    base: Cells,
    spec: SceneSpec,
    far: Mesh,
    edit: Option<(Cells, Vec<Placement>, Vec2, Vec2, Vec2)>,
    camera: Camera,
    light: [[f32; 4]; LIGHT_SLOTS],
    sun_dir: Vec3,
    hour: f32,
    // Running.
    worker: Option<(mpsc::Sender<Job>, mpsc::Receiver<Done>)>,
    frame: u64,
    rows: Vec<Row>,
    passes: Vec<(u64, &'static str, f64)>,
    scenarios: Vec<Scenario>,
    current: Option<usize>,
    warm_until: f64,
    shadow_dirty: bool,
    motion: Option<Motion>,
    next_edit: f64,
    edit_count: usize,
    pending_install: Vec<usize>,
    skipped: u64,
    refresh_hz: f64,
    max_fps: i64,
    pace_origin: Option<f64>,
    finished: bool,
}

impl App {
    fn note(&mut self, text: String) {
        println!("WINDOW {text}");
        self.notes.push(text);
    }

    fn init_gpu(&mut self) {
        let window = self.window.clone().unwrap();
        let size = window.inner_size();
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
        let surface = instance.create_surface(window.clone()).expect("surface");
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions { power_preference: wgpu::PowerPreference::HighPerformance, compatible_surface: Some(&surface), ..Default::default() })).expect("adapter");
        let wanted = wgpu::Features::TIMESTAMP_QUERY | wgpu::Features::TIMESTAMP_QUERY_INSIDE_ENCODERS | wgpu::Features::TIMESTAMP_QUERY_INSIDE_PASSES;
        let features = if self.o.gpu_time { adapter.features() & wanted } else { wgpu::Features::empty() };
        let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor { required_features: features, ..Default::default() })).expect("device");
        let caps = surface.get_capabilities(&adapter);
        self.note(format!("adapter {} ({:?}); timestamp features on device: {:?}", adapter.get_info().name, adapter.get_info().backend, features));
        self.note(format!("surface caps: formats {:?}, present modes {:?}, alpha {:?}", caps.formats, caps.present_modes, caps.alpha_modes));
        let mut config = surface.get_default_config(&adapter, size.width.max(1), size.height.max(1)).expect("surface config");
        // The renderer writes display values itself: a plain 8-bit target, no encode on write.
        config.format = if caps.formats.contains(&wgpu::TextureFormat::Bgra8Unorm) { wgpu::TextureFormat::Bgra8Unorm } else { caps.formats.iter().copied().find(|f| !f.is_srgb()).expect("a non-sRGB surface format") };
        if !caps.present_modes.contains(&self.o.present_mode) {
            self.note(format!("present mode {:?} not offered; using Fifo", self.o.present_mode));
            self.o.present_mode = wgpu::PresentMode::Fifo;
        }
        config.present_mode = self.o.present_mode;
        config.desired_maximum_frame_latency = self.o.latency;
        config.alpha_mode = wgpu::CompositeAlphaMode::Opaque;
        config.usage = wgpu::TextureUsages::RENDER_ATTACHMENT;
        surface.configure(&device, &config);
        self.note(format!("surface configured: {}x{} {:?} colour space {:?}, {:?}, desired_maximum_frame_latency {}", config.width, config.height, config.format, config.color_space, config.present_mode, config.desired_maximum_frame_latency));
        // A render scale below 1 is a disclosed quality option: the picture is drawn smaller and
        // stretched to the surface with a bilinear filter in the blit.
        if self.o.render_scale != 1.0 {
            self.o.direct = false;
        }
        let (rw, rh) = ((config.width as f32 * self.o.render_scale).round() as u32, (config.height as f32 * self.o.render_scale).round() as u32);
        let out_format = if self.o.direct { config.format } else { wgpu::TextureFormat::Rgba8Unorm };
        let mut renderer = Renderer::with_device(device.clone(), queue.clone(), rw, rh, self.o.scale, self.o.fxaa, out_format);
        renderer.timer = crate::gputime::GpuTimer::new(&device, &queue);
        self.note(format!(
            "renderer {}x{} (render scale {}) internal scale {} fxaa {} present {} gpu timer {} (period {} ns) pace {}",
            rw,
            rh,
            self.o.render_scale,
            self.o.scale,
            self.o.fxaa,
            if self.o.direct { "direct" } else { "blit" },
            renderer.timer.is_some(),
            queue.get_timestamp_period(),
            if self.o.pace > 0.0 { format!("{} Hz", self.o.pace) } else { "off".into() }
        ));
        let (scene, field) = self.initial.take().expect("initial scene");
        renderer.set_scene(&scene.vertices, scene.casters, &scene.water);
        renderer.set_props(&scene.library);
        renderer.set_grass(&scene.grass);
        renderer.clear_settle();
        let blit = (!self.o.direct).then(|| {
            let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor { label: Some("blit"), source: wgpu::ShaderSource::Wgsl(BLIT.replace("SURFACE", &format!("vec2<f32>({}.0, {}.0)", config.width, config.height)).into()) });
            let layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("blit"),
                entries: &[
                    wgpu::BindGroupLayoutEntry { binding: 0, visibility: wgpu::ShaderStages::FRAGMENT, ty: wgpu::BindingType::Texture { sample_type: wgpu::TextureSampleType::Float { filterable: true }, view_dimension: wgpu::TextureViewDimension::D2, multisampled: false }, count: None },
                    wgpu::BindGroupLayoutEntry { binding: 1, visibility: wgpu::ShaderStages::FRAGMENT, ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering), count: None },
                ],
            });
            let sampler = device.create_sampler(&wgpu::SamplerDescriptor { label: Some("blit"), mag_filter: wgpu::FilterMode::Linear, min_filter: wgpu::FilterMode::Linear, ..Default::default() });
            let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout: &layout,
                entries: &[wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(renderer.final_view()) }, wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::Sampler(&sampler) }],
            });
            let pl = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor { label: None, bind_group_layouts: &[Some(&layout)], immediate_size: 0 });
            let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: Some("blit"),
                layout: Some(&pl),
                vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs"), buffers: &[], compilation_options: Default::default() },
                fragment: Some(wgpu::FragmentState { module: &shader, entry_point: Some(if self.o.render_scale != 1.0 { "fs_scaled" } else { "fs" }), targets: &[Some(config.format.into())], compilation_options: Default::default() }),
                primitive: wgpu::PrimitiveState::default(),
                depth_stencil: None,
                multisample: wgpu::MultisampleState::default(),
                multiview_mask: None,
                cache: None,
            });
            (pipeline, group)
        });
        if let Some(edit) = self.edit.clone() {
            let device = self.o.worker_upload.then(|| device.clone());
            self.worker = Some(spawn_worker(self.base.clone(), field, edit, self.spec.clone(), { let mut far = Mesh::default(); far.append(&self.far); far }, device));
        }
        self.gpu = Some(Gpu { surface, device, queue, config, renderer, blit });
        self.warm_until = now() + self.o.warmup;
        self.shadow_dirty = true;
    }

    fn light_now(&self, clock: Option<f32>) -> [[f32; 4]; LIGHT_SLOTS] {
        let mut light = self.light;
        if let (Some(clock), Some(m)) = (clock, &self.motion) {
            light[SETTLE_SLOT] = [clock, m.slots[0][1], m.slots[0][2], m.slots[0][3]];
            light[SETTLE_SLOT + 1] = m.slots[1];
        }
        light
    }

    /// Starts the next scenario, or finishes.
    fn next_scenario(&mut self, t: f64) {
        let index = self.current.map_or(0, |i| i + 1);
        if index >= self.o.scenarios.len() {
            self.finished = true;
            return;
        }
        let name = self.o.scenarios[index].clone();
        self.note(format!("scenario {name} starts at frame {}", self.frame));
        self.scenarios.push(Scenario { name, start: t, edits: Vec::new() });
        self.current = Some(index);
        self.next_edit = t + self.o.edit_period * 0.5;
    }

    /// The next drawable and when it arrived (None: skipped, counted).
    fn acquire(&mut self) -> Option<(wgpu::SurfaceTexture, f64)> {
        let gpu = self.gpu.as_mut().unwrap();
        mac::CURRENT_FRAME.store(self.frame, Ordering::Relaxed);
        match gpu.surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(t) | wgpu::CurrentSurfaceTexture::Suboptimal(t) => Some((t, now())),
            wgpu::CurrentSurfaceTexture::Occluded | wgpu::CurrentSurfaceTexture::Timeout => {
                self.skipped += 1;
                None
            }
            _ => {
                gpu.surface.configure(&gpu.device, &gpu.config);
                self.skipped += 1;
                None
            }
        }
    }

    fn frame(&mut self) {
        // Frame pacing (`--pace`): start each frame on a fixed grid phase-locked to a presented
        // frame (a vsync), a little after it; a frame that overruns its slot waits for the next.
        if self.o.pace > 0.0 {
            if self.pace_origin.is_none() {
                self.pace_origin = mac::latest_presented().map(|t| t + 0.001);
            }
            if let Some(origin) = self.pace_origin {
                let period = 1.0 / self.o.pace;
                let target = origin + ((now() - origin) / period).ceil() * period;
                let wait = target - now() - 0.0005;
                if wait > 0.0 {
                    std::thread::sleep(std::time::Duration::from_secs_f64(wait));
                }
                while now() < target {
                    std::hint::spin_loop();
                }
            }
        }
        let begin = now();
        if begin < self.warm_until {
            // Warm-up frames: drawn and presented, not recorded.
        } else if self.current.is_none() {
            self.next_scenario(begin);
        } else if begin - self.scenarios.last().unwrap().start >= self.o.seconds && self.pending_install.is_empty() {
            self.next_scenario(begin);
        }
        if self.finished {
            return;
        }
        let recording = self.current.is_some();
        let scenario = self.current.map(|i| self.o.scenarios[i].clone()).unwrap_or_default();
        let s_start = self.scenarios.last().map_or(begin, |s| s.start);
        // Late latching (default): take the drawable first, then sample the frame's state (camera,
        // clock, finished edits), so what is drawn is as fresh as possible when it goes to the GPU;
        // with `--latch=early` the state is sampled before the (blocking) acquire.
        let mut acquired = None;
        if self.o.late_latch {
            match self.acquire() {
                Some(a) => acquired = Some(a),
                None => return,
            }
        }
        let sampled = now();
        let t = sampled - s_start;
        let gpu = self.gpu.as_mut().unwrap();
        // GPU times of earlier frames.
        let _ = gpu.device.poll(wgpu::PollType::Poll);
        if let Some(timer) = &gpu.renderer.timer {
            absorb(&mut self.rows, &mut self.passes, timer.collect());
        }
        // Editing: issue edits on time; install finished rebuilds.
        let mut upload_ms = 0.0;
        if scenario == "editing" && sampled >= self.next_edit && sampled - s_start < self.o.seconds - 0.5 {
            if let Some((tx, _)) = &self.worker {
                let forward = self.edit_count % 2 == 0;
                let index = self.edit_count;
                tx.send(Job { index, forward }).expect("worker");
                self.scenarios.last_mut().unwrap().edits.push(EditRec { index, forward, issued: sampled, ..Default::default() });
                self.pending_install.push(index);
                self.edit_count += 1;
            }
            self.next_edit += self.o.edit_period;
        }
        if let Some((_, rx)) = &self.worker {
            if let Ok(done) = rx.try_recv() {
                let up = now();
                let renderer = &mut gpu.renderer;
                match (done.scene, done.buffers) {
                    (_, Some(buffers)) => renderer.install(buffers.upload),
                    (Some(scene), None) => {
                        renderer.set_scene(&scene.vertices, scene.casters, &scene.water);
                        renderer.set_props(&scene.library);
                        renderer.set_grass(&scene.grass);
                        renderer.set_settle(&done.map.texels, &done.items);
                    }
                    _ => {}
                }
                let installed = now();
                upload_ms = (installed - up) * 1000.0;
                self.motion = Some(Motion { start: installed, slots: done.map.slots(0.0, done.items.len()) });
                self.shadow_dirty = true;
                self.pending_install.retain(|i| *i != done.index);
                if let Some(rec) = self.scenarios.iter_mut().flat_map(|s| s.edits.iter_mut()).find(|e| e.index == done.index) {
                    rec.worker_done = done.finished;
                    rec.installed = installed;
                    rec.rebuild_ms = done.rebuild_ms;
                    rec.map_ms = done.map_ms;
                    rec.prep_ms = done.prep_ms;
                    rec.upload_ms = upload_ms;
                    rec.first_frame = Some(self.frame);
                }
            }
        }
        // The frame's camera, clock and shadow.
        let mut camera = self.camera;
        if scenario == "moving" {
            let turn = glam::Quat::from_rotation_y(t as f32 * ORBIT_RATE);
            camera.eye = camera.target + turn * (camera.eye - camera.target);
        }
        let mut clock = None;
        if let Some(m) = &self.motion {
            let c = (now() - m.start) as f32;
            if c <= MOTION_SECONDS {
                clock = Some(c);
            } else {
                self.motion = None;
                // One more shadow with the motion off.
                self.shadow_dirty = true;
            }
        }
        let shadow = self.shadow_dirty || clock.is_some() || self.o.shadow_always;
        self.shadow_dirty = false;
        let light = self.light_now(clock);
        let frame = Frame { camera, sun_dir: self.sun_dir, time: 3.0 + (sampled - self.opened) as f32, hour: self.hour, ssao: true, ssao_blur: true, debug: 0.0, light };
        // Acquire (unless done already), draw, submit, present.
        if acquired.is_none() {
            acquired = self.acquire();
            if acquired.is_none() {
                self.shadow_dirty |= shadow;
                return;
            }
        }
        let (surface_texture, acquired_at) = acquired.unwrap();
        let gpu = self.gpu.as_mut().unwrap();
        let view = surface_texture.texture.create_view(&Default::default());
        let mut encoder = gpu.device.create_command_encoder(&Default::default());
        if let Some(timer) = &gpu.renderer.timer {
            timer.begin_frame(self.frame);
        }
        gpu.renderer.draw(&mut encoder, &frame, shadow, if self.o.direct { Some(&view) } else { None });
        if let Some((pipeline, group)) = &gpu.blit {
            let ts = gpu.renderer.timer.as_ref().and_then(|t| t.pass("blit"));
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("blit"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment { view: &view, depth_slice: None, resolve_target: None, ops: wgpu::Operations { load: wgpu::LoadOp::Clear(wgpu::Color::BLACK), store: wgpu::StoreOp::Store } })],
                depth_stencil_attachment: None,
                timestamp_writes: ts,
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_pipeline(pipeline);
            pass.set_bind_group(0, group, &[]);
            pass.draw(0..3, 0..1);
        }
        if let Some(timer) = &gpu.renderer.timer {
            timer.end_frame(&mut encoder);
        }
        let encoded = now();
        gpu.queue.submit([encoder.finish()]);
        if let Some(timer) = &gpu.renderer.timer {
            timer.after_submit();
        }
        let submitted = now();
        gpu.queue.present(surface_texture);
        let presented = now();
        if recording {
            self.rows.push(Row {
                frame: self.frame,
                scenario: self.current.unwrap(),
                t,
                begin,
                acquired: acquired_at,
                sampled,
                encoded,
                submitted,
                presented,
                upload_ms,
                shadow,
                clock: clock.unwrap_or(-1.0),
                gpu_ms: None,
                glass: None,
            });
        }
        self.frame += 1;
    }

    /// Drains the GPU and presentation times, then writes the CSVs and the summary.
    fn finish(&mut self) {
        if let Some(gpu) = &self.gpu {
            if let Some(timer) = &gpu.renderer.timer {
                let _ = gpu.device.poll(wgpu::PollType::wait_indefinitely());
                absorb(&mut self.rows, &mut self.passes, timer.collect());
                let mut encoder = gpu.device.create_command_encoder(&Default::default());
                timer.flush(&mut encoder);
                gpu.queue.submit([encoder.finish()]);
                timer.after_submit();
                let _ = gpu.device.poll(wgpu::PollType::wait_indefinitely());
                absorb(&mut self.rows, &mut self.passes, timer.collect());
            }
        }
        std::thread::sleep(std::time::Duration::from_millis(150));
        let glass = mac::presented_times();
        let mut by_frame = std::collections::HashMap::new();
        for (frame, t) in glass {
            by_frame.insert(frame, t);
        }
        for row in &mut self.rows {
            row.glass = by_frame.get(&row.frame).copied();
        }
        std::fs::create_dir_all(&self.o.out).expect("out folder");
        let refresh_ms = 1000.0 / self.refresh_hz;
        let mut summary = String::new();
        summary += &format!("# {} {}\n", self.o.tag, chrono_like());
        for n in &self.notes {
            summary += &format!("# {n}\n");
        }
        summary += &format!(
            "# settings: present mode {:?}, desired_maximum_frame_latency {}, fullscreen {}, present {}, upload {}, latch {}, pace {}, render scale {}, scale {}, fxaa {}, shadow {}, display refresh {:.1} Hz (NSScreen maximumFramesPerSecond {}), skipped acquires {}\n",
            self.o.present_mode,
            self.o.latency,
            self.o.fullscreen,
            if self.o.direct { "direct" } else { "blit" },
            if self.o.worker_upload { "worker" } else { "main" },
            if self.o.late_latch { "late" } else { "early" },
            self.o.pace,
            self.o.render_scale,
            self.o.scale,
            self.o.fxaa,
            if self.o.shadow_always { "always" } else { "cached" },
            self.refresh_hz,
            self.max_fps,
            self.skipped
        );
        let mut json = Vec::new();
        for (si, sc) in self.scenarios.iter().enumerate() {
            let rows: Vec<&Row> = self.rows.iter().filter(|r| r.scenario == si).collect();
            let path = format!("{}/{}_{}.csv", self.o.out, self.o.tag, sc.name);
            let mut csv = String::from("frame,t_s,interval_ms,acquire_wait_ms,encode_ms,submit_ms,present_call_ms,cpu_frame_ms,upload_ms,gpu_ms,glass_interval_ms,sample_to_glass_ms,shadow,settle_clock\n");
            let mut prev: Option<&Row> = None;
            let mut prev_glass: Option<f64> = None;
            for r in &rows {
                let interval = prev.map(|p| (r.presented - p.presented) * 1000.0);
                let gl = r.glass.filter(|g| *g > 0.0);
                let gi = match (gl, prev_glass) {
                    (Some(a), Some(b)) => Some((a - b) * 1000.0),
                    _ => None,
                };
                if gl.is_some() {
                    prev_glass = gl;
                }
                let f = |v: Option<f64>| v.map_or(String::new(), |x| format!("{x:.3}"));
                csv += &format!(
                    "{},{:.4},{},{:.3},{:.3},{:.3},{:.3},{:.3},{:.3},{},{},{},{},{:.3}\n",
                    r.frame,
                    r.t,
                    f(interval),
                    (r.acquired - r.begin) * 1000.0,
                    (r.encoded - r.acquired) * 1000.0,
                    (r.submitted - r.encoded) * 1000.0,
                    (r.presented - r.submitted) * 1000.0,
                    (r.presented - r.begin) * 1000.0,
                    r.upload_ms,
                    f(r.gpu_ms),
                    f(gi),
                    f(gl.map(|g| (g - r.sampled) * 1000.0)),
                    r.shadow as u8,
                    r.clock
                );
                prev = Some(r);
            }
            std::fs::write(&path, csv).expect("write csv");
            // Passes, long format.
            let frames: std::collections::HashSet<u64> = rows.iter().map(|r| r.frame).collect();
            let mut pcsv = String::from("frame,pass,ms\n");
            let mut per_pass: std::collections::BTreeMap<&str, Vec<f64>> = std::collections::BTreeMap::new();
            for (frame, label, ms) in &self.passes {
                if frames.contains(frame) {
                    pcsv += &format!("{frame},{label},{ms:.4}\n");
                    per_pass.entry(label).or_default().push(*ms);
                }
            }
            std::fs::write(format!("{}/{}_{}_passes.csv", self.o.out, self.o.tag, sc.name), pcsv).expect("write passes");
            // Statistics over the scenario after its first SETTLE_IN seconds.
            let kept: Vec<&&Row> = rows.iter().filter(|r| r.t >= SETTLE_IN).collect();
            let intervals = sorted(kept.windows(2).map(|w| (w[1].presented - w[0].presented) * 1000.0).collect());
            let duration = kept.last().map_or(0.0, |l| l.presented) - kept.first().map_or(0.0, |f| f.presented);
            let fps = if duration > 0.0 { (kept.len() - 1) as f64 / duration } else { 0.0 };
            let missed = intervals.iter().filter(|&&x| x > 1.5 * refresh_ms).count();
            let missed60 = intervals.iter().filter(|&&x| x > 1.5 * 1000.0 / 60.0).count();
            let gl: Vec<f64> = kept.iter().filter_map(|r| r.glass.filter(|g| *g > 0.0)).collect();
            let dropped = kept.iter().filter(|r| r.glass == Some(0.0)).count();
            let glass_iv = sorted(gl.windows(2).map(|w| (w[1] - w[0]) * 1000.0).collect());
            let glass_missed = glass_iv.iter().filter(|&&x| x > 1.5 * refresh_ms).count();
            let glass_fps = if gl.len() > 1 { (gl.len() - 1) as f64 / (gl[gl.len() - 1] - gl[0]) } else { 0.0 };
            let glass_lat = sorted(kept.iter().filter_map(|r| r.glass.filter(|g| *g > 0.0).map(|g| (g - r.sampled) * 1000.0)).collect());
            let gpu = sorted(kept.iter().filter_map(|r| r.gpu_ms).collect());
            let cpu = sorted(kept.iter().map(|r| (r.presented - r.acquired) * 1000.0).collect());
            let acq = sorted(kept.iter().map(|r| (r.acquired - r.begin) * 1000.0).collect());
            summary += &format!(
                "\n{}: {} frames over {:.2} s\n  present-call cadence (CPU): {:.2} fps, interval p50 {:.2} p95 {:.2} p99 {:.2} max {:.2} ms, intervals > 1.5x refresh ({:.2} ms): {}, > 25 ms: {}\n",
                sc.name,
                kept.len(),
                duration,
                fps,
                pick(&intervals, 0.5),
                pick(&intervals, 0.95),
                pick(&intervals, 0.99),
                pick(&intervals, 1.0),
                1.5 * refresh_ms,
                missed,
                missed60
            );
            summary += &format!(
                "  on glass (presentedTime): {} frames, {:.2} fps, interval p50 {:.2} p95 {:.2} p99 {:.2} max {:.2} ms, > 1.5x refresh: {}, dropped (presentedTime 0): {}; state sampled to glass p50 {:.1} p95 {:.1} ms\n",
                gl.len(),
                glass_fps,
                pick(&glass_iv, 0.5),
                pick(&glass_iv, 0.95),
                pick(&glass_iv, 0.99),
                pick(&glass_iv, 1.0),
                glass_missed,
                dropped,
                pick(&glass_lat, 0.5),
                pick(&glass_lat, 0.95)
            );
            summary += &format!(
                "  GPU frame span: {} timed, p50 {:.2} p95 {:.2} max {:.2} ms; CPU acquire wait p50 {:.2} p95 {:.2} ms; CPU acquire to present call p50 {:.2} p95 {:.2} ms\n",
                gpu.len(),
                pick(&gpu, 0.5),
                pick(&gpu, 0.95),
                pick(&gpu, 1.0),
                pick(&acq, 0.5),
                pick(&acq, 0.95),
                pick(&cpu, 0.5),
                pick(&cpu, 0.95)
            );
            let mut pass_text = Vec::new();
            for (label, v) in per_pass {
                let v = sorted(v);
                pass_text.push(format!("{label} {:.3}/{:.3}", pick(&v, 0.5), pick(&v, 0.95)));
            }
            summary += &format!("  passes, own share p50/p95 ms: {}\n", pass_text.join(", "));
            let mut edit_json = Vec::new();
            for e in &sc.edits {
                let first = e.first_frame.and_then(|f| rows.iter().find(|r| r.frame == f));
                let cpu_lat = first.map(|r| (r.presented - e.issued) * 1000.0);
                let glass_lat = first.and_then(|r| r.glass.filter(|g| *g > 0.0)).map(|g| (g - e.issued) * 1000.0);
                let hitch = first.and_then(|r| rows.iter().find(|q| q.frame + 1 == r.frame).map(|p| (r.presented - p.presented) * 1000.0));
                summary += &format!(
                    "  edit {} ({}): rebuild {:.1} ms, settle map {:.2} ms, upload prep {:.1} ms (worker); install on the frame loop {:.2} ms; issued to first motion frame's present call {}, to glass {}; that frame's interval {}\n",
                    e.index,
                    if e.forward { "edit" } else { "undo" },
                    e.rebuild_ms,
                    e.map_ms,
                    e.prep_ms,
                    e.upload_ms,
                    cpu_lat.map_or("-".into(), |x| format!("{x:.1} ms")),
                    glass_lat.map_or("-".into(), |x| format!("{x:.1} ms")),
                    hitch.map_or("-".into(), |x| format!("{x:.1} ms"))
                );
                edit_json.push(format!(
                    "{{\"index\": {}, \"forward\": {}, \"rebuild_ms\": {:.2}, \"map_ms\": {:.3}, \"prep_ms\": {:.2}, \"install_ms\": {:.3}, \"to_present_ms\": {}, \"to_glass_ms\": {}, \"interval_ms\": {}}}",
                    e.index,
                    e.forward,
                    e.rebuild_ms,
                    e.map_ms,
                    e.prep_ms,
                    e.upload_ms,
                    cpu_lat.map_or("null".into(), |x| format!("{x:.2}")),
                    glass_lat.map_or("null".into(), |x| format!("{x:.2}")),
                    hitch.map_or("null".into(), |x| format!("{x:.2}"))
                ));
            }
            json.push(format!(
                "  {{\"scenario\": \"{}\", \"frames\": {}, \"fps\": {:.3}, \"interval_ms\": [{:.3}, {:.3}, {:.3}, {:.3}], \"missed_1_5x\": {}, \"over_25ms\": {}, \"glass_fps\": {:.3}, \"glass_interval_ms\": [{:.3}, {:.3}, {:.3}, {:.3}], \"glass_missed_1_5x\": {}, \"glass_dropped\": {}, \"gpu_ms\": [{:.3}, {:.3}], \"edits\": [{}]}}",
                sc.name,
                kept.len(),
                fps,
                pick(&intervals, 0.5),
                pick(&intervals, 0.95),
                pick(&intervals, 0.99),
                pick(&intervals, 1.0),
                missed,
                missed60,
                glass_fps,
                pick(&glass_iv, 0.5),
                pick(&glass_iv, 0.95),
                pick(&glass_iv, 0.99),
                pick(&glass_iv, 1.0),
                glass_missed,
                dropped,
                pick(&gpu, 0.5),
                pick(&gpu, 0.95),
                edit_json.join(", ")
            ));
        }
        let json = format!("[\n{}\n]\n", json.join(",\n")).replace("NaN", "null");
        std::fs::write(format!("{}/{}_summary.json", self.o.out, self.o.tag), json).expect("write json");
        std::fs::write(format!("{}/{}_summary.txt", self.o.out, self.o.tag), &summary).expect("write summary");
        print!("{summary}");
    }
}

fn chrono_like() -> String {
    let secs = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map_or(0, |d| d.as_secs());
    format!("(unix time {secs})")
}

/// Frame GPU span (first pass start to last pass end) and each pass's own share: its end minus
/// the later of its start and the previous pass's end (passes finish in order; on a tiled GPU a
/// pass's vertex stage may start long before the pass before it has finished).
fn absorb(rows: &mut [Row], passes: &mut Vec<(u64, &'static str, f64)>, timed: Vec<crate::gputime::Timed>) {
    for t in timed {
        let (lo, hi) = t.passes.iter().fold((f64::MAX, f64::MIN), |(lo, hi), p| (lo.min(p.1), hi.max(p.2)));
        if let Some(row) = rows.iter_mut().rev().find(|r| r.frame == t.frame) {
            row.gpu_ms = Some((hi - lo) / 1.0e6);
            let mut prev_end = f64::MIN;
            for (label, a, b) in &t.passes {
                passes.push((t.frame, label, (b - a.max(prev_end)) / 1.0e6));
                prev_end = prev_end.max(*b);
            }
        }
    }
}

const BLIT: &str = r#"
@group(0) @binding(0) var src: texture_2d<f32>;
@group(0) @binding(1) var smp: sampler;
@fragment
fn fs_scaled(@builtin(position) p: vec4<f32>) -> @location(0) vec4<f32> {
    // The source sampled at the same relative place (render-scale option).
    return textureSampleLevel(src, smp, p.xy / SURFACE, 0.0);
}
@vertex
fn vs(@builtin(vertex_index) i: u32) -> @builtin(position) vec4<f32> {
    let x = f32((i << 1u) & 2u);
    let y = f32(i & 2u);
    return vec4<f32>(x * 2.0 - 1.0, 1.0 - y * 2.0, 0.0, 1.0);
}
@fragment
fn fs(@builtin(position) p: vec4<f32>) -> @location(0) vec4<f32> {
    return textureLoad(src, vec2<i32>(p.xy), 0);
}
"#;

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }
        let monitor = event_loop.primary_monitor().or_else(|| event_loop.available_monitors().next());
        let mut attributes = Window::default_attributes().with_title("s34_study window");
        if let Some(m) = &monitor {
            self.refresh_hz = m.refresh_rate_millihertz().map_or(60.0, |mhz| mhz as f64 / 1000.0);
            self.note(format!("monitor {:?} {}x{} scale {} refresh {:?} mHz", m.name(), m.size().width, m.size().height, m.scale_factor(), m.refresh_rate_millihertz()));
            if self.o.fullscreen == "cover" {
                attributes = attributes
                    .with_decorations(false)
                    .with_resizable(false)
                    .with_position(PhysicalPosition::new(m.position().x, m.position().y))
                    .with_inner_size(m.size())
                    .with_window_level(WindowLevel::AlwaysOnTop);
            } else {
                attributes = attributes.with_fullscreen(Some(Fullscreen::Borderless(Some(m.clone()))));
            }
        }
        let window = Arc::new(event_loop.create_window(attributes).expect("window"));
        self.window = Some(window);
        self.opened = now();
        // The native full-screen transition takes most of a second; the drawable is sized after it.
        self.begin_at = self.opened + if self.o.fullscreen == "cover" { 0.5 } else { 1.5 };
        event_loop.set_control_flow(ControlFlow::Poll);
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => event_loop.exit(),
            WindowEvent::KeyboardInput { event: KeyEvent { logical_key: Key::Named(NamedKey::Escape), state: ElementState::Pressed, .. }, .. } => {
                self.note("Escape pressed: stopping early".into());
                self.finished = true;
            }
            WindowEvent::Resized(size) => {
                if let Some(gpu) = &mut self.gpu {
                    if size.width != gpu.config.width || size.height != gpu.config.height {
                        let text = format!("resized to {}x{} after the renderer was made ({}x{}); kept the renderer's size", size.width, size.height, gpu.config.width, gpu.config.height);
                        self.note(text);
                    }
                }
            }
            WindowEvent::Occluded(o) => self.note(format!("occluded={o} at {:.3} s", now() - self.opened)),
            _ => {}
        }
    }

    fn about_to_wait(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_none() {
            return;
        }
        if self.gpu.is_none() {
            if now() < self.begin_at {
                return;
            }
            let window = self.window.clone().unwrap();
            let size = window.inner_size();
            self.note(format!("window inner {}x{} physical, scale factor {}", size.width, size.height, window.scale_factor()));
            self.max_fps = mac::max_fps(&window);
            if self.o.presented_time {
                let ok = mac::install_presented_handler();
                self.note(format!("presentedTime handler installed: {ok}"));
            }
            self.init_gpu();
        }
        if !self.finished {
            self.frame();
        }
        if self.finished {
            self.finish();
            event_loop.exit();
        }
    }
}

pub fn main() {
    let o = parse();
    // The scene, built before the window opens.
    let cells = field::load_layout(&o.layout);
    let props = crate::props::default_dir(&o.layout).filter(|dir| dir.join("scene.json").exists());
    let spec = SceneSpec { props, body: crate::body::Kind::Karst, seed: o.seed };
    let far = crate::far_mountains();
    let start = now();
    let (built, library) = rebuild_island(&cells, &[], &spec);
    println!("WINDOW island built in {:.1} ms", (now() - start) * 1000.0);
    let lantern = library.lanterns.first().copied();
    let initial = scene_of(built, library, &far);
    // Light and camera as the stills of view `game` (main.rs).
    let (mut light, sun_dir, hour) = crate::light_set(&o.hour);
    light[19][0] = 1.0;
    if let Some(lamp) = lantern {
        light[41] = [lamp.x, lamp.y, lamp.z, 1.0];
    }
    let text = std::fs::read_to_string("runtime/data/reference/cameras.json").expect("cameras.json");
    let json: serde_json::Value = serde_json::from_str(&text).expect("cameras json");
    let find = |name: &str| -> Camera {
        let e = json["cameras"].as_array().unwrap().iter().find(|e| e["name"] == name).expect("camera");
        Camera::orbit([e["center"][0].as_f64().unwrap() as f32, e["center"][1].as_f64().unwrap() as f32], e["height"].as_f64().unwrap() as f32, e["yaw"].as_f64().unwrap() as f32, e["pitch"].as_f64().unwrap() as f32)
    };
    let camera = find("game");
    let whole = find("whole");
    light[16][0] = ((camera.eye - camera.target).length() / (whole.eye - whole.target).length()).max(1.0);
    light[12][0] = -4.0;
    light[12][1] = -6.9;
    light[29][0] = camera.target.x;
    light[29][2] = camera.target.z;
    // The edit and its rectangle (plus 4 m, as settle::run).
    let edit = o.scenarios.iter().any(|s| s == "editing").then(|| {
        let seq = settle::sequences().into_iter().find(|q| q.name == o.edit).unwrap_or_else(|| panic!("no settle sequence {}", o.edit));
        let (edited, (lo, hi), placed) = settle::apply(&cells, &seq.edit);
        (edited, placed, lo - Vec2::splat(4.0), hi + Vec2::splat(4.0), seq.centre)
    });
    let event_loop = EventLoop::new().expect("event loop");
    let mut app = App {
        o,
        window: None,
        gpu: None,
        notes: Vec::new(),
        opened: 0.0,
        begin_at: f64::MAX,
        initial: Some(initial),
        base: cells,
        spec,
        far,
        edit,
        camera,
        light,
        sun_dir,
        hour,
        worker: None,
        frame: 0,
        rows: Vec::new(),
        passes: Vec::new(),
        scenarios: Vec::new(),
        current: None,
        warm_until: f64::MAX,
        shadow_dirty: true,
        motion: None,
        next_edit: 0.0,
        edit_count: 0,
        pending_install: Vec::new(),
        skipped: 0,
        refresh_hz: 60.0,
        max_fps: -1,
        pace_origin: None,
        finished: false,
    };
    event_loop.run_app(&mut app).expect("run");
}

#[cfg(target_os = "macos")]
mod mac {
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::sync::Mutex;

    use block2::RcBlock;
    use objc2::msg_send;
    use objc2::runtime::{AnyClass, AnyObject, Imp, Sel};
    use objc2::sel;
    use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};

    #[link(name = "QuartzCore", kind = "framework")]
    extern "C" {
        fn CACurrentMediaTime() -> f64;
    }

    pub fn now() -> f64 {
        unsafe { CACurrentMediaTime() }
    }

    /// The frame the loop is about to acquire a drawable for.
    pub static CURRENT_FRAME: AtomicU64 = AtomicU64::new(0);
    static ORIGINAL: Mutex<Option<usize>> = Mutex::new(None);
    static PRESENTED: Mutex<Vec<(u64, f64)>> = Mutex::new(Vec::new());
    static LATEST: Mutex<f64> = Mutex::new(0.0);

    type NextDrawable = unsafe extern "C-unwind" fn(*mut AnyObject, Sel) -> *mut AnyObject;

    /// `-[CAMetalLayer nextDrawable]` wrapped: every drawable handed out gets a presented handler
    /// that records `presentedTime` (0 when it was never shown) against the loop's frame number.
    /// Nothing is retained, so the layer's drawable pool is not disturbed.
    unsafe extern "C-unwind" fn next_drawable(this: *mut AnyObject, sel: Sel) -> *mut AnyObject {
        let original: NextDrawable = std::mem::transmute(ORIGINAL.lock().unwrap().expect("original nextDrawable"));
        let drawable = original(this, sel);
        if !drawable.is_null() {
            let frame = CURRENT_FRAME.load(Ordering::Relaxed);
            let block = RcBlock::new(move |d: *mut AnyObject| {
                let t: f64 = if d.is_null() { 0.0 } else { msg_send![&*d, presentedTime] };
                PRESENTED.lock().unwrap().push((frame, t));
                if t > 0.0 {
                    *LATEST.lock().unwrap() = t;
                }
            });
            let _: () = msg_send![&*drawable, addPresentedHandler: &*block];
        }
        drawable
    }

    pub fn install_presented_handler() -> bool {
        let Some(class) = AnyClass::get(c"CAMetalLayer") else { return false };
        unsafe {
            let method = objc2::ffi::class_getInstanceMethod(class, sel!(nextDrawable));
            if method.is_null() {
                return false;
            }
            let ours: Imp = std::mem::transmute(next_drawable as NextDrawable);
            let old = objc2::ffi::method_setImplementation(method as *mut _, ours);
            match old {
                Some(old) => {
                    *ORIGINAL.lock().unwrap() = Some(old as usize);
                    true
                }
                None => false,
            }
        }
    }

    pub fn latest_presented() -> Option<f64> {
        let t = *LATEST.lock().unwrap();
        (t > 0.0).then_some(t)
    }

    pub fn presented_times() -> Vec<(u64, f64)> {
        std::mem::take(&mut *PRESENTED.lock().unwrap())
    }

    /// NSScreen.maximumFramesPerSecond of the window's screen (macOS 12+), -1 if unknown.
    pub fn max_fps(window: &winit::window::Window) -> i64 {
        let Ok(handle) = window.window_handle() else { return -1 };
        let RawWindowHandle::AppKit(appkit) = handle.as_raw() else { return -1 };
        unsafe {
            let view = appkit.ns_view.as_ptr() as *mut AnyObject;
            let ns_window: *mut AnyObject = msg_send![&*view, window];
            if ns_window.is_null() {
                return -1;
            }
            let screen: *mut AnyObject = msg_send![&*ns_window, screen];
            if screen.is_null() {
                return -1;
            }
            let n: isize = msg_send![&*screen, maximumFramesPerSecond];
            n as i64
        }
    }
}

#[cfg(not(target_os = "macos"))]
mod mac {
    use std::sync::atomic::AtomicU64;
    pub static CURRENT_FRAME: AtomicU64 = AtomicU64::new(0);
    pub fn now() -> f64 {
        use std::sync::OnceLock;
        static START: OnceLock<std::time::Instant> = OnceLock::new();
        START.get_or_init(std::time::Instant::now).elapsed().as_secs_f64()
    }
    pub fn install_presented_handler() -> bool {
        false
    }
    pub fn latest_presented() -> Option<f64> {
        None
    }

    pub fn presented_times() -> Vec<(u64, f64)> {
        Vec::new()
    }
    pub fn max_fps(_window: &winit::window::Window) -> i64 {
        -1
    }
}

