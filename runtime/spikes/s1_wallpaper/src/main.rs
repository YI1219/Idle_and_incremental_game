//! Spike S1 (throwaway): can a wgpu window hang as a true desktop wallpaper on
//! macOS, stop presenting when it is covered, keep a simulation stand-in
//! ticking with no frames, and pace itself cheaply at 30 frames a second?
//!
//!   s1_wallpaper --mode=wallpaper|cover|window [--fps=30] [--seconds=30]
//!                [--when-covered=stop|draw] [--out=/abs/log.json]
//!
//! `wallpaper`: borderless window at the desktop window level (behind the
//! icons, above the system picture), on all Spaces, ignoring the mouse.
//! `cover`: an opaque full-screen window above everything, used by the test to
//! cover the wallpaper. `window`: an ordinary window, for comparison.
use std::sync::Arc;
use std::time::{Duration, Instant};

use winit::application::ApplicationHandler;
use winit::dpi::{PhysicalPosition, PhysicalSize};
use winit::event::WindowEvent;
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::window::{Window, WindowId, WindowLevel};

#[derive(Clone, Copy, PartialEq, Debug)]
enum Mode {
    Wallpaper,
    Cover,
    Window,
}

struct Args {
    mode: Mode,
    fps: f64,
    seconds: f64,
    draw_when_covered: bool,
    out: Option<String>,
}

fn parse_args() -> Args {
    let mut args = Args { mode: Mode::Wallpaper, fps: 30.0, seconds: 30.0, draw_when_covered: false, out: None };
    for arg in std::env::args().skip(1) {
        if let Some(value) = arg.strip_prefix("--mode=") {
            args.mode = match value {
                "wallpaper" => Mode::Wallpaper,
                "cover" => Mode::Cover,
                "window" => Mode::Window,
                other => panic!("unknown mode {other}"),
            };
        } else if let Some(value) = arg.strip_prefix("--fps=") {
            args.fps = value.parse().expect("fps");
        } else if let Some(value) = arg.strip_prefix("--seconds=") {
            args.seconds = value.parse().expect("seconds");
        } else if let Some(value) = arg.strip_prefix("--when-covered=") {
            args.draw_when_covered = value == "draw";
        } else if let Some(value) = arg.strip_prefix("--out=") {
            args.out = Some(value.to_string());
        } else {
            panic!("unknown argument {arg}");
        }
    }
    args
}

const SHADER: &str = r#"
struct Globals { time: f32, pad0: f32, pad1: f32, pad2: f32 };
@group(0) @binding(0) var<uniform> globals: Globals;

struct VsOut { @builtin(position) pos: vec4<f32>, @location(0) uv: vec2<f32> };

@vertex
fn vs(@builtin(vertex_index) index: u32) -> VsOut {
    var out: VsOut;
    let x = f32((index << 1u) & 2u);
    let y = f32(index & 2u);
    out.uv = vec2<f32>(x, y);
    out.pos = vec4<f32>(x * 2.0 - 1.0, 1.0 - y * 2.0, 0.0, 1.0);
    return out;
}

@fragment
fn fs(in: VsOut) -> @location(0) vec4<f32> {
    // A calm mist gradient with one slow drifting band, so a still frame shows
    // the window is there and two frames differ.
    let top = vec3<f32>(0.62, 0.70, 0.72);
    let bottom = vec3<f32>(0.86, 0.84, 0.78);
    var colour = mix(top, bottom, in.uv.y);
    let band = 0.5 + 0.5 * sin((in.uv.x * 3.0 + in.uv.y * 1.5 + globals.time * 0.35) * 3.14159);
    colour = colour + vec3<f32>(0.035, 0.04, 0.03) * band;
    return vec4<f32>(colour, 1.0);
}
"#;

struct Gpu {
    surface: wgpu::Surface<'static>,
    device: wgpu::Device,
    queue: wgpu::Queue,
    config: wgpu::SurfaceConfiguration,
    pipeline: wgpu::RenderPipeline,
    globals: wgpu::Buffer,
    bind_group: wgpu::BindGroup,
    adapter_name: String,
}

impl Gpu {
    fn new(window: Arc<Window>) -> Gpu {
        let size = window.inner_size();
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
        let surface = instance.create_surface(window).expect("surface");
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            compatible_surface: Some(&surface),
            ..Default::default()
        }))
        .expect("adapter");
        let adapter_name = adapter.get_info().name;
        let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default())).expect("device");
        let mut config = surface.get_default_config(&adapter, size.width.max(1), size.height.max(1)).expect("surface config");
        config.present_mode = wgpu::PresentMode::Fifo;
        let format = config.format;
        surface.configure(&device, &config);
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("s1"),
            source: wgpu::ShaderSource::Wgsl(SHADER.into()),
        });
        let globals = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("globals"),
            size: 16,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: None,
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer { ty: wgpu::BufferBindingType::Uniform, has_dynamic_offset: false, min_binding_size: None },
                count: None,
            }],
        });
        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &layout,
            entries: &[wgpu::BindGroupEntry { binding: 0, resource: globals.as_entire_binding() }],
        });
        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: None,
            bind_group_layouts: &[Some(&layout)],
            immediate_size: 0,
        });
        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("s1"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs"), buffers: &[], compilation_options: Default::default() },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs"),
                targets: &[Some(format.into())],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });
        Gpu { surface, device, queue, config, pipeline, globals, bind_group, adapter_name }
    }

    fn resize(&mut self, size: PhysicalSize<u32>) {
        if size.width == 0 || size.height == 0 {
            return;
        }
        self.config.width = size.width;
        self.config.height = size.height;
        self.surface.configure(&self.device, &self.config);
    }

    /// Draws and presents one frame. Returns false when no frame was presented.
    fn draw(&mut self, time: f32) -> bool {
        let frame = match self.surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(frame) | wgpu::CurrentSurfaceTexture::Suboptimal(frame) => frame,
            wgpu::CurrentSurfaceTexture::Occluded | wgpu::CurrentSurfaceTexture::Timeout => return false,
            _ => {
                self.surface.configure(&self.device, &self.config);
                return false;
            }
        };
        self.queue.write_buffer(&self.globals, 0, &[time.to_le_bytes(), [0; 4], [0; 4], [0; 4]].concat());
        let view = frame.texture.create_view(&wgpu::TextureViewDescriptor::default());
        let mut encoder = self.device.create_command_encoder(&wgpu::CommandEncoderDescriptor::default());
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: None,
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    depth_slice: None,
                    resolve_target: None,
                    ops: wgpu::Operations { load: wgpu::LoadOp::Clear(wgpu::Color::BLACK), store: wgpu::StoreOp::Store },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_pipeline(&self.pipeline);
            pass.set_bind_group(0, &self.bind_group, &[]);
            pass.draw(0..3, 0..1);
        }
        self.queue.submit([encoder.finish()]);
        self.queue.present(frame);
        true
    }
}

fn cpu_seconds() -> f64 {
    unsafe {
        let mut usage: libc::rusage = std::mem::zeroed();
        libc::getrusage(libc::RUSAGE_SELF, &mut usage);
        let user = usage.ru_utime.tv_sec as f64 + usage.ru_utime.tv_usec as f64 * 1e-6;
        let system = usage.ru_stime.tv_sec as f64 + usage.ru_stime.tv_usec as f64 * 1e-6;
        user + system
    }
}

#[cfg(target_os = "macos")]
mod mac {
    use objc2::msg_send;
    use objc2::runtime::AnyObject;
    use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};
    use winit::window::Window;

    #[link(name = "CoreGraphics", kind = "framework")]
    extern "C" {
        fn CGWindowLevelForKey(key: i32) -> i32;
    }
    const DESKTOP_WINDOW_LEVEL_KEY: i32 = 2;
    const DESKTOP_ICON_WINDOW_LEVEL_KEY: i32 = 18;
    // NSWindowCollectionBehavior: canJoinAllSpaces | stationary | ignoresCycle
    const BEHAVIOR: usize = (1 << 0) | (1 << 4) | (1 << 6);

    fn ns_window(window: &Window) -> Option<*mut AnyObject> {
        let handle = window.window_handle().ok()?;
        let RawWindowHandle::AppKit(appkit) = handle.as_raw() else {
            return None;
        };
        let view = appkit.ns_view.as_ptr() as *mut AnyObject;
        let ns_window: *mut AnyObject = unsafe { msg_send![view, window] };
        if ns_window.is_null() {
            None
        } else {
            Some(ns_window)
        }
    }

    /// Puts the window at the desktop level: above the system picture, behind
    /// the Finder's icons, on every Space, out of window cycling, deaf to the
    /// mouse. Returns a one-line description of what was set and read back.
    pub fn hang_as_wallpaper(window: &Window) -> String {
        let Some(ns_window) = ns_window(window) else {
            return "no NSWindow".to_string();
        };
        unsafe {
            let level = CGWindowLevelForKey(DESKTOP_WINDOW_LEVEL_KEY) as isize;
            let icon_level = CGWindowLevelForKey(DESKTOP_ICON_WINDOW_LEVEL_KEY) as isize;
            let _: () = msg_send![ns_window, setLevel: level];
            let _: () = msg_send![ns_window, setCollectionBehavior: BEHAVIOR];
            let _: () = msg_send![ns_window, setIgnoresMouseEvents: true];
            let _: () = msg_send![ns_window, setHasShadow: false];
            let _: () = msg_send![ns_window, orderBack: std::ptr::null::<AnyObject>()];
            let read_level: isize = msg_send![ns_window, level];
            let read_behavior: usize = msg_send![ns_window, collectionBehavior];
            format!("level={read_level} (desktop={level}, icons={icon_level}) behavior={read_behavior}")
        }
    }

    /// NSWindowOcclusionStateVisible is bit 1.
    pub fn occlusion_visible(window: &Window) -> Option<bool> {
        let ns_window = ns_window(window)?;
        let state: usize = unsafe { msg_send![ns_window, occlusionState] };
        Some(state & (1 << 1) != 0)
    }
}

#[derive(Default, Clone)]
struct Second {
    at: f64,
    frames: u32,
    sim_ticks: u32,
    occluded: bool,
    cpu_ms: f64,
    max_gap_ms: f64,
}

struct App {
    args: Args,
    window: Option<Arc<Window>>,
    gpu: Option<Gpu>,
    start: Instant,
    next_frame: Instant,
    next_tick: Instant,
    next_second: Instant,
    last_present: Option<Instant>,
    occluded: bool,
    current: Second,
    cpu_mark: f64,
    seconds: Vec<Second>,
    gaps_ms: Vec<f64>,
    notes: Vec<String>,
    total_frames: u64,
    total_ticks: u64,
}

impl App {
    fn new(args: Args) -> App {
        let now = Instant::now();
        App {
            args,
            window: None,
            gpu: None,
            start: now,
            next_frame: now,
            next_tick: now,
            next_second: now + Duration::from_secs(1),
            last_present: None,
            occluded: false,
            current: Second::default(),
            cpu_mark: cpu_seconds(),
            seconds: Vec::new(),
            gaps_ms: Vec::new(),
            notes: Vec::new(),
            total_frames: 0,
            total_ticks: 0,
        }
    }

    fn note(&mut self, text: String) {
        let at = self.start.elapsed().as_secs_f64();
        println!("[{at:7.3}] {text}");
        self.notes.push(format!("{at:.3} {text}"));
    }

    fn drawing(&self) -> bool {
        !self.occluded || self.args.draw_when_covered
    }

    fn write_log(&self) {
        let Some(path) = &self.args.out else { return };
        let mut text = String::from("{\n");
        text += &format!(" \"mode\": \"{:?}\",\n \"fps_target\": {},\n \"when_covered\": \"{}\",\n", self.args.mode, self.args.fps, if self.args.draw_when_covered { "draw" } else { "stop" });
        if let Some(gpu) = &self.gpu {
            text += &format!(" \"adapter\": \"{}\",\n \"surface\": [{}, {}],\n \"format\": \"{:?}\",\n", gpu.adapter_name, gpu.config.width, gpu.config.height, gpu.config.format);
        }
        text += &format!(" \"total_frames\": {},\n \"total_sim_ticks\": {},\n", self.total_frames, self.total_ticks);
        let mut sorted = self.gaps_ms.clone();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let pick = |q: f64| -> f64 {
            if sorted.is_empty() {
                0.0
            } else {
                sorted[((sorted.len() - 1) as f64 * q).round() as usize]
            }
        };
        text += &format!(" \"present_gap_ms\": {{\"count\": {}, \"p50\": {:.3}, \"p95\": {:.3}, \"p99\": {:.3}, \"max\": {:.3}}},\n", sorted.len(), pick(0.5), pick(0.95), pick(0.99), pick(1.0));
        text += " \"notes\": [\n";
        for (index, note) in self.notes.iter().enumerate() {
            text += &format!("  \"{}\"{}\n", note.replace('"', "'"), if index + 1 < self.notes.len() { "," } else { "" });
        }
        text += " ],\n \"seconds\": [\n";
        for (index, second) in self.seconds.iter().enumerate() {
            text += &format!(
                "  {{\"t\": {:.1}, \"frames\": {}, \"sim_ticks\": {}, \"occluded\": {}, \"cpu_ms\": {:.2}, \"max_gap_ms\": {:.2}}}{}\n",
                second.at,
                second.frames,
                second.sim_ticks,
                second.occluded,
                second.cpu_ms,
                second.max_gap_ms,
                if index + 1 < self.seconds.len() { "," } else { "" }
            );
        }
        text += " ]\n}\n";
        std::fs::write(path, text).expect("write log");
    }
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }
        let monitor = event_loop.primary_monitor().or_else(|| event_loop.available_monitors().next());
        let mut attributes = Window::default_attributes().with_title("s1_wallpaper");
        if let Some(monitor) = &monitor {
            if self.args.mode != Mode::Window {
                attributes = attributes
                    .with_decorations(false)
                    .with_resizable(false)
                    .with_position(PhysicalPosition::new(monitor.position().x, monitor.position().y))
                    .with_inner_size(monitor.size());
            }
        }
        if self.args.mode == Mode::Cover {
            attributes = attributes.with_window_level(WindowLevel::AlwaysOnTop);
        }
        if self.args.mode == Mode::Window {
            attributes = attributes.with_inner_size(PhysicalSize::new(1280u32, 720u32));
        }
        let window = Arc::new(event_loop.create_window(attributes).expect("window"));
        let monitor_text = monitor.map(|m| format!("{}x{} scale {}", m.size().width, m.size().height, m.scale_factor())).unwrap_or_default();
        self.note(format!("window inner {}x{} monitor {}", window.inner_size().width, window.inner_size().height, monitor_text));
        #[cfg(target_os = "macos")]
        if self.args.mode == Mode::Wallpaper {
            let report = mac::hang_as_wallpaper(&window);
            self.note(format!("wallpaper: {report}"));
        }
        let gpu = Gpu::new(window.clone());
        self.note(format!("adapter {} surface {}x{} {:?}", gpu.adapter_name, gpu.config.width, gpu.config.height, gpu.config.format));
        self.gpu = Some(gpu);
        self.window = Some(window);
        self.start = Instant::now();
        self.next_frame = self.start;
        self.next_tick = self.start;
        self.next_second = self.start + Duration::from_secs(1);
        self.cpu_mark = cpu_seconds();
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => event_loop.exit(),
            WindowEvent::Resized(size) => {
                if let Some(gpu) = &mut self.gpu {
                    gpu.resize(size);
                }
            }
            WindowEvent::Occluded(occluded) => {
                self.occluded = occluded;
                self.note(format!("occluded={occluded}"));
                if !occluded {
                    self.next_frame = Instant::now();
                }
            }
            WindowEvent::RedrawRequested => {
                if !self.drawing() {
                    return;
                }
                let time = self.start.elapsed().as_secs_f32();
                if let Some(gpu) = &mut self.gpu {
                    if gpu.draw(time) {
                        let now = Instant::now();
                        if let Some(last) = self.last_present {
                            let gap = (now - last).as_secs_f64() * 1000.0;
                            // A gap across a covered stretch is not a pacing sample.
                            if gap < 500.0 {
                                self.gaps_ms.push(gap);
                                self.current.max_gap_ms = self.current.max_gap_ms.max(gap);
                            }
                        }
                        self.last_present = Some(now);
                        self.current.frames += 1;
                        self.total_frames += 1;
                    }
                }
            }
            _ => {}
        }
    }

    fn about_to_wait(&mut self, event_loop: &ActiveEventLoop) {
        let now = Instant::now();
        if now.duration_since(self.start).as_secs_f64() >= self.args.seconds {
            self.write_log();
            event_loop.exit();
            return;
        }
        // The simulation stand-in: four steps a second whether or not a frame is drawn.
        while now >= self.next_tick {
            self.current.sim_ticks += 1;
            self.total_ticks += 1;
            self.next_tick += Duration::from_millis(250);
        }
        while now >= self.next_second {
            let cpu = cpu_seconds();
            self.current.at = self.next_second.duration_since(self.start).as_secs_f64();
            self.current.cpu_ms = (cpu - self.cpu_mark) * 1000.0;
            self.current.occluded = self.occluded;
            self.cpu_mark = cpu;
            self.seconds.push(std::mem::take(&mut self.current));
            self.next_second += Duration::from_secs(1);
        }
        let frame_step = Duration::from_secs_f64(1.0 / self.args.fps);
        let mut wake = self.next_tick.min(self.next_second);
        if self.drawing() {
            if now >= self.next_frame {
                if let Some(window) = &self.window {
                    window.request_redraw();
                }
                self.next_frame += frame_step;
                if self.next_frame < now {
                    self.next_frame = now + frame_step;
                }
            }
            wake = wake.min(self.next_frame);
        }
        event_loop.set_control_flow(ControlFlow::WaitUntil(wake));
    }
}

fn main() {
    let args = parse_args();
    let mut builder = EventLoop::builder();
    #[cfg(target_os = "macos")]
    {
        use winit::platform::macos::{ActivationPolicy, EventLoopBuilderExtMacOS};
        if args.mode != Mode::Window {
            // No Dock icon and never the active application.
            builder.with_activation_policy(ActivationPolicy::Accessory);
        }
    }
    let event_loop = builder.build().expect("event loop");
    let mut app = App::new(args);
    event_loop.run_app(&mut app).expect("run");
    #[cfg(target_os = "macos")]
    if let Some(window) = &app.window {
        let _ = mac::occlusion_visible(window);
    }
}
