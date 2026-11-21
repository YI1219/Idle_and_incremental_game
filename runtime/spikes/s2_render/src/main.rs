//! Spike S2 (throwaway): what does a frame cost when the island is drawn from a
//! bake into shading terms and resolved with a palette, line and mist, with
//! water live on top? Measures the plan's Moving path (terms + resolve + water)
//! and Still path (resolve + water over cached terms) off screen, so the window
//! compositor cannot clip the numbers.
//!
//!   s2_render [--size=3024x1964] [--scene=bench|starter] [--detail=1.0]
//!             [--frames=240] [--rounds=3] [--out=/abs/result.json] [--png=/abs/prefix]
mod scene;

use std::time::Instant;

use glam::{Mat4, Vec3};
use wgpu::util::DeviceExt;

const SHADOW_SIZE: u32 = 4096;
const TERM_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba8Unorm;
const FINAL_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba8UnormSrgb;
const DEPTH_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Depth32Float;

struct Args {
    width: u32,
    height: u32,
    scene: String,
    detail: f32,
    frames: u32,
    rounds: u32,
    out: Option<String>,
    png: Option<String>,
}

fn parse_args() -> Args {
    let mut args = Args { width: 3024, height: 1964, scene: "bench".into(), detail: 1.0, frames: 240, rounds: 3, out: None, png: None };
    for arg in std::env::args().skip(1) {
        if let Some(value) = arg.strip_prefix("--size=") {
            let (w, h) = value.split_once('x').expect("size as WxH");
            args.width = w.parse().expect("width");
            args.height = h.parse().expect("height");
        } else if let Some(value) = arg.strip_prefix("--scene=") {
            args.scene = value.to_string();
        } else if let Some(value) = arg.strip_prefix("--detail=") {
            args.detail = value.parse().expect("detail");
        } else if let Some(value) = arg.strip_prefix("--frames=") {
            args.frames = value.parse().expect("frames");
        } else if let Some(value) = arg.strip_prefix("--rounds=") {
            args.rounds = value.parse().expect("rounds");
        } else if let Some(value) = arg.strip_prefix("--out=") {
            args.out = Some(value.to_string());
        } else if let Some(value) = arg.strip_prefix("--png=") {
            args.png = Some(value.to_string());
        } else {
            panic!("unknown argument {arg}");
        }
    }
    args
}

struct IslandGpu {
    vertices: wgpu::Buffer,
    chunks: Vec<(u32, u32)>,
    water: Option<(wgpu::Buffer, u32)>,
}

#[derive(Clone, Copy)]
struct View {
    name: &'static str,
    target: Vec3,
    distance: f32,
    pitch_deg: f32,
}

struct Renderer {
    device: wgpu::Device,
    queue: wgpu::Queue,
    width: u32,
    height: u32,
    globals: wgpu::Buffer,
    globals_group: wgpu::BindGroup,
    shadow_view: wgpu::TextureView,
    shadow_pipeline: wgpu::RenderPipeline,
    terms_pipeline: wgpu::RenderPipeline,
    terms_group: wgpu::BindGroup,
    resolve_pipeline: wgpu::RenderPipeline,
    resolve_group: wgpu::BindGroup,
    water_pipeline: wgpu::RenderPipeline,
    water_group: wgpu::BindGroup,
    base_view: wgpu::TextureView,
    terms_view: wgpu::TextureView,
    normal_view: wgpu::TextureView,
    depth_view: wgpu::TextureView,
    final_texture: wgpu::Texture,
    final_view: wgpu::TextureView,
    islands: Vec<IslandGpu>,
    light_view_proj: Mat4,
    sun_dir: Vec3,
}

#[derive(Clone, Copy, PartialEq)]
enum Pass {
    Shadow,
    Terms,
    Resolve,
    Water,
}

fn target_texture(device: &wgpu::Device, label: &str, width: u32, height: u32, format: wgpu::TextureFormat, extra: wgpu::TextureUsages) -> wgpu::Texture {
    device.create_texture(&wgpu::TextureDescriptor {
        label: Some(label),
        size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING | extra,
        view_formats: &[],
    })
}

fn texture_entry(binding: u32, depth: bool) -> wgpu::BindGroupLayoutEntry {
    wgpu::BindGroupLayoutEntry {
        binding,
        visibility: wgpu::ShaderStages::FRAGMENT,
        ty: wgpu::BindingType::Texture {
            sample_type: if depth { wgpu::TextureSampleType::Depth } else { wgpu::TextureSampleType::Float { filterable: false } },
            view_dimension: wgpu::TextureViewDimension::D2,
            multisampled: false,
        },
        count: None,
    }
}

impl Renderer {
    fn new(args: &Args, meshes: &[scene::IslandMesh]) -> Renderer {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            ..Default::default()
        }))
        .expect("adapter");
        println!("adapter: {}", adapter.get_info().name);
        let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default())).expect("device");
        let (width, height) = (args.width, args.height);
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("s2"),
            source: wgpu::ShaderSource::Wgsl(include_str!("shader.wgsl").into()),
        });

        let globals = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("globals"),
            size: 64 * 4,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let globals_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("globals"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                ty: wgpu::BindingType::Buffer { ty: wgpu::BufferBindingType::Uniform, has_dynamic_offset: false, min_binding_size: None },
                count: None,
            }],
        });
        let globals_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &globals_layout,
            entries: &[wgpu::BindGroupEntry { binding: 0, resource: globals.as_entire_binding() }],
        });

        let shadow_texture = target_texture(&device, "shadow", SHADOW_SIZE, SHADOW_SIZE, DEPTH_FORMAT, wgpu::TextureUsages::empty());
        let shadow_view = shadow_texture.create_view(&Default::default());
        let base = target_texture(&device, "base", width, height, TERM_FORMAT, wgpu::TextureUsages::empty());
        let terms = target_texture(&device, "terms", width, height, TERM_FORMAT, wgpu::TextureUsages::empty());
        let normal = target_texture(&device, "normal", width, height, TERM_FORMAT, wgpu::TextureUsages::empty());
        let depth = target_texture(&device, "depth", width, height, DEPTH_FORMAT, wgpu::TextureUsages::empty());
        let final_texture = target_texture(&device, "final", width, height, FINAL_FORMAT, wgpu::TextureUsages::COPY_SRC);
        let (base_view, terms_view, normal_view, depth_view, final_view) = (
            base.create_view(&Default::default()),
            terms.create_view(&Default::default()),
            normal.create_view(&Default::default()),
            depth.create_view(&Default::default()),
            final_texture.create_view(&Default::default()),
        );

        let vertex_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<scene::Vertex>() as u64,
            step_mode: wgpu::VertexStepMode::Vertex,
            attributes: &[
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 0, shader_location: 0 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 12, shader_location: 1 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 24, shader_location: 2 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 28, shader_location: 3 },
            ],
        };
        let depth_state = |bias: wgpu::DepthBiasState| {
            Some(wgpu::DepthStencilState {
                format: DEPTH_FORMAT,
                depth_write_enabled: Some(true),
                depth_compare: Some(wgpu::CompareFunction::Less),
                stencil: wgpu::StencilState::default(),
                bias,
            })
        };

        // Shadow map: depth only.
        let shadow_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor { label: None, bind_group_layouts: &[Some(&globals_layout)], immediate_size: 0 });
        let shadow_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("shadow"),
            layout: Some(&shadow_layout),
            vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_shadow"), buffers: &[Some(vertex_layout.clone())], compilation_options: Default::default() },
            fragment: None,
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: depth_state(wgpu::DepthBiasState { constant: 2, slope_scale: 2.0, clamp: 0.0 }),
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        // Terms pass: three colour targets and depth; reads the cached shadow map.
        let terms_bind_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("terms"),
            entries: &[
                texture_entry(0, true),
                wgpu::BindGroupLayoutEntry { binding: 1, visibility: wgpu::ShaderStages::FRAGMENT, ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Comparison), count: None },
            ],
        });
        let shadow_sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("shadow"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            compare: Some(wgpu::CompareFunction::LessEqual),
            ..Default::default()
        });
        let terms_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &terms_bind_layout,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&shadow_view) },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::Sampler(&shadow_sampler) },
            ],
        });
        let terms_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor { label: None, bind_group_layouts: &[Some(&globals_layout), Some(&terms_bind_layout)], immediate_size: 0 });
        let terms_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("terms"),
            layout: Some(&terms_layout),
            vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_terms"), buffers: &[Some(vertex_layout.clone())], compilation_options: Default::default() },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs_terms"),
                targets: &[Some(TERM_FORMAT.into()), Some(TERM_FORMAT.into()), Some(TERM_FORMAT.into())],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: depth_state(wgpu::DepthBiasState::default()),
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        // Resolve pass: full screen, reads the four cached targets.
        let resolve_bind_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("resolve"),
            entries: &[texture_entry(0, false), texture_entry(1, false), texture_entry(2, false), texture_entry(3, true)],
        });
        let resolve_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &resolve_bind_layout,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&base_view) },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::TextureView(&terms_view) },
                wgpu::BindGroupEntry { binding: 2, resource: wgpu::BindingResource::TextureView(&normal_view) },
                wgpu::BindGroupEntry { binding: 3, resource: wgpu::BindingResource::TextureView(&depth_view) },
            ],
        });
        let resolve_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor { label: None, bind_group_layouts: &[Some(&globals_layout), Some(&resolve_bind_layout)], immediate_size: 0 });
        let resolve_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("resolve"),
            layout: Some(&resolve_layout),
            vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_full"), buffers: &[], compilation_options: Default::default() },
            fragment: Some(wgpu::FragmentState { module: &shader, entry_point: Some("fs_resolve"), targets: &[Some(FINAL_FORMAT.into())], compilation_options: Default::default() }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        // Water: alpha blended over the resolved picture, depth tested by hand against the cached depth.
        let water_bind_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("water"), entries: &[texture_entry(0, true)] });
        let water_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &water_bind_layout,
            entries: &[wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&depth_view) }],
        });
        let water_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor { label: None, bind_group_layouts: &[Some(&globals_layout), Some(&water_bind_layout)], immediate_size: 0 });
        let water_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("water"),
            layout: Some(&water_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_water"),
                buffers: &[Some(wgpu::VertexBufferLayout {
                    array_stride: 12,
                    step_mode: wgpu::VertexStepMode::Vertex,
                    attributes: &[wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 0, shader_location: 0 }],
                })],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs_water"),
                targets: &[Some(wgpu::ColorTargetState { format: FINAL_FORMAT, blend: Some(wgpu::BlendState::ALPHA_BLENDING), write_mask: wgpu::ColorWrites::ALL })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        let islands = meshes
            .iter()
            .map(|mesh| IslandGpu {
                vertices: device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("island"), contents: bytemuck::cast_slice(&mesh.vertices), usage: wgpu::BufferUsages::VERTEX }),
                chunks: mesh.chunks.clone(),
                water: if mesh.water.is_empty() {
                    None
                } else {
                    Some((
                        device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("water"), contents: bytemuck::cast_slice(&mesh.water), usage: wgpu::BufferUsages::VERTEX }),
                        mesh.water.len() as u32,
                    ))
                },
            })
            .collect();

        // The sun of the morning keyframe: elevation about 25 degrees, azimuth about 38.
        let (elevation, azimuth) = (25.5_f32.to_radians(), 38.0_f32.to_radians());
        let sun_dir = Vec3::new(azimuth.sin() * elevation.cos(), elevation.sin(), azimuth.cos() * elevation.cos()).normalize();
        let mut low = Vec3::splat(f32::MAX);
        let mut high = Vec3::splat(f32::MIN);
        let light_view = Mat4::look_at_rh(sun_dir * 400.0, Vec3::ZERO, Vec3::Y);
        for mesh in meshes {
            for corner in 0..8 {
                let r = mesh.radius + 4.0;
                let offset = Vec3::new(if corner & 1 == 0 { -r } else { r }, if corner & 2 == 0 { -14.0 } else { 12.0 }, if corner & 4 == 0 { -r } else { r });
                let p = light_view.transform_point3(mesh.centre + offset);
                low = low.min(p);
                high = high.max(p);
            }
        }
        let light_view_proj = Mat4::orthographic_rh(low.x, high.x, low.y, high.y, -high.z - 5.0, -low.z + 5.0) * light_view;

        Renderer {
            device,
            queue,
            width,
            height,
            globals,
            globals_group,
            shadow_view,
            shadow_pipeline,
            terms_pipeline,
            terms_group,
            resolve_pipeline,
            resolve_group,
            water_pipeline,
            water_group,
            base_view,
            terms_view,
            normal_view,
            depth_view,
            final_texture,
            final_view,
            islands,
            light_view_proj,
            sun_dir,
        }
    }

    fn set_camera(&self, view: View, yaw_deg: f32, time: f32) {
        let (yaw, pitch) = (yaw_deg.to_radians(), view.pitch_deg.to_radians());
        let eye = view.target + Vec3::new(yaw.sin() * pitch.cos(), pitch.sin(), yaw.cos() * pitch.cos()) * view.distance;
        let (near, far) = (0.5_f32, 1200.0_f32);
        let projection = Mat4::perspective_rh(31.0_f32.to_radians(), self.width as f32 / self.height as f32, near, far);
        let view_proj = projection * Mat4::look_at_rh(eye, view.target, Vec3::Y);
        let mut data = [0.0_f32; 64];
        data[0..16].copy_from_slice(&view_proj.to_cols_array());
        data[16..32].copy_from_slice(&view_proj.inverse().to_cols_array());
        data[32..48].copy_from_slice(&self.light_view_proj.to_cols_array());
        data[48..51].copy_from_slice(&self.sun_dir.to_array());
        data[52..55].copy_from_slice(&eye.to_array());
        data[56..60].copy_from_slice(&[time, 0.29, 1.0 / self.width as f32, 1.0 / self.height as f32]);
        data[60..62].copy_from_slice(&[near, far]);
        self.queue.write_buffer(&self.globals, 0, bytemuck::cast_slice(&data));
    }

    fn draw_islands(&self, pass: &mut wgpu::RenderPass) {
        for island in &self.islands {
            pass.set_vertex_buffer(0, island.vertices.slice(..));
            for &(first, count) in &island.chunks {
                pass.draw(first..first + count, 0..1);
            }
        }
    }

    fn encode(&self, encoder: &mut wgpu::CommandEncoder, pass: Pass) {
        let colour = |view| {
            Some(wgpu::RenderPassColorAttachment {
                view,
                depth_slice: None,
                resolve_target: None,
                ops: wgpu::Operations { load: wgpu::LoadOp::Clear(wgpu::Color::BLACK), store: wgpu::StoreOp::Store },
            })
        };
        let depth = |view| {
            Some(wgpu::RenderPassDepthStencilAttachment { view, depth_ops: Some(wgpu::Operations { load: wgpu::LoadOp::Clear(1.0), store: wgpu::StoreOp::Store }), stencil_ops: None })
        };
        match pass {
            Pass::Shadow => {
                let mut rp = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("shadow"), color_attachments: &[], depth_stencil_attachment: depth(&self.shadow_view), timestamp_writes: None, occlusion_query_set: None, multiview_mask: None });
                rp.set_pipeline(&self.shadow_pipeline);
                rp.set_bind_group(0, &self.globals_group, &[]);
                self.draw_islands(&mut rp);
            }
            Pass::Terms => {
                let mut rp = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                    label: Some("terms"),
                    color_attachments: &[colour(&self.base_view), colour(&self.terms_view), colour(&self.normal_view)],
                    depth_stencil_attachment: depth(&self.depth_view),
                    timestamp_writes: None,
                    occlusion_query_set: None,
                    multiview_mask: None,
                });
                rp.set_pipeline(&self.terms_pipeline);
                rp.set_bind_group(0, &self.globals_group, &[]);
                rp.set_bind_group(1, &self.terms_group, &[]);
                self.draw_islands(&mut rp);
            }
            Pass::Resolve => {
                let mut rp = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("resolve"), color_attachments: &[colour(&self.final_view)], depth_stencil_attachment: None, timestamp_writes: None, occlusion_query_set: None, multiview_mask: None });
                rp.set_pipeline(&self.resolve_pipeline);
                rp.set_bind_group(0, &self.globals_group, &[]);
                rp.set_bind_group(1, &self.resolve_group, &[]);
                rp.draw(0..3, 0..1);
            }
            Pass::Water => {
                let mut rp = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                    label: Some("water"),
                    color_attachments: &[Some(wgpu::RenderPassColorAttachment { view: &self.final_view, depth_slice: None, resolve_target: None, ops: wgpu::Operations { load: wgpu::LoadOp::Load, store: wgpu::StoreOp::Store } })],
                    depth_stencil_attachment: None,
                    timestamp_writes: None,
                    occlusion_query_set: None,
                    multiview_mask: None,
                });
                rp.set_pipeline(&self.water_pipeline);
                rp.set_bind_group(0, &self.globals_group, &[]);
                rp.set_bind_group(1, &self.water_group, &[]);
                for island in &self.islands {
                    if let Some((buffer, count)) = &island.water {
                        rp.set_vertex_buffer(0, buffer.slice(..));
                        rp.draw(0..*count, 0..1);
                    }
                }
            }
        }
    }

    fn wait(&self) {
        self.device.poll(wgpu::PollType::wait_indefinitely()).expect("poll");
    }

    /// Renders `frames` frames of the given passes with the camera orbiting, and
    /// returns milliseconds per frame once the GPU has finished all of them.
    fn bench(&self, passes: &[Pass], view: View, frames: u32, orbit: bool) -> f64 {
        // S2_BATCH=1 waits for the GPU after every frame: a cross-check of the batched timing.
        let batch: u32 = std::env::var("S2_BATCH").ok().and_then(|v| v.parse().ok()).unwrap_or(8).max(1);
        self.wait();
        let start = Instant::now();
        for frame in 0..frames {
            let yaw = 16.0 + if orbit { frame as f32 * 0.75 } else { 0.0 };
            self.set_camera(view, yaw, frame as f32 / 60.0);
            let mut encoder = self.device.create_command_encoder(&Default::default());
            for &pass in passes {
                self.encode(&mut encoder, pass);
            }
            self.queue.submit([encoder.finish()]);
            if frame % batch == batch - 1 {
                self.wait();
            }
        }
        self.wait();
        start.elapsed().as_secs_f64() * 1000.0 / frames as f64
    }

    fn save_png(&self, path: &str) {
        let row = (self.width * 4).div_ceil(256) * 256;
        let buffer = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("readback"),
            size: (row * self.height) as u64,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });
        let mut encoder = self.device.create_command_encoder(&Default::default());
        encoder.copy_texture_to_buffer(
            wgpu::TexelCopyTextureInfo { texture: &self.final_texture, mip_level: 0, origin: wgpu::Origin3d::ZERO, aspect: wgpu::TextureAspect::All },
            wgpu::TexelCopyBufferInfo { buffer: &buffer, layout: wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(row), rows_per_image: Some(self.height) } },
            wgpu::Extent3d { width: self.width, height: self.height, depth_or_array_layers: 1 },
        );
        self.queue.submit([encoder.finish()]);
        buffer.slice(..).map_async(wgpu::MapMode::Read, |result| result.expect("map"));
        self.wait();
        let data = buffer.slice(..).get_mapped_range().expect("mapped range");
        let mut pixels = Vec::with_capacity((self.width * self.height * 4) as usize);
        for y in 0..self.height {
            let begin = (y * row) as usize;
            pixels.extend_from_slice(&data[begin..begin + (self.width * 4) as usize]);
        }
        let file = std::io::BufWriter::new(std::fs::File::create(path).expect("png file"));
        let mut encoder = png::Encoder::new(file, self.width, self.height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        encoder.write_header().expect("png header").write_image_data(&pixels).expect("png data");
    }
}

fn median(values: &mut Vec<f64>) -> f64 {
    values.sort_by(|a, b| a.partial_cmp(b).unwrap());
    values[values.len() / 2]
}

fn main() {
    let args = parse_args();
    let build_start = Instant::now();
    let mut meshes = Vec::new();
    if args.scene == "starter" {
        meshes.push(scene::build_island(&scene::make_cells(623, 7301), Vec3::ZERO, 7301, args.detail));
    } else {
        // One full island in focus and two more, staggered in space at other heights.
        meshes.push(scene::build_island(&scene::make_cells(4096, 7301), Vec3::ZERO, 7301, args.detail));
        meshes.push(scene::build_island(&scene::make_cells(650, 2104), Vec3::new(74.0, 9.0, -46.0), 2104, args.detail));
        meshes.push(scene::build_island(&scene::make_cells(650, 4242), Vec3::new(-78.0, -7.0, 30.0), 4242, args.detail));
    }
    let build_ms = build_start.elapsed().as_secs_f64() * 1000.0;
    let triangles: usize = meshes.iter().map(|m| m.vertices.len() / 3).sum();
    let draws: usize = meshes.iter().map(|m| m.chunks.len()).sum();
    let cells: Vec<usize> = meshes.iter().map(|m| m.cells).collect();
    println!("scene {}: cells {:?}, {} triangles, {} draws, built in {:.0} ms", args.scene, cells, triangles, draws, build_ms);

    let renderer = Renderer::new(&args, &meshes);
    let focus = meshes[0].centre;
    let reach = meshes[0].radius;
    let views = [
        View { name: "whole", target: focus, distance: reach * 3.4, pitch_deg: 27.0 },
        View { name: "game", target: focus + Vec3::new(reach * 0.2, 0.0, reach * 0.1), distance: reach * 1.25, pitch_deg: 27.0 },
        View { name: "low", target: focus, distance: reach * 2.4, pitch_deg: 19.0 },
    ];

    // The shadow map is rendered once: it is cache B of the plan.
    renderer.set_camera(views[0], 16.0, 0.0);
    let shadow_ms = renderer.bench(&[Pass::Shadow], views[0], 8, false);
    println!("shadow map refresh: {:.2} ms", shadow_ms);

    let mut lines = Vec::new();
    for view in views {
        // Warm up, then measure. Still frames reuse the terms of the last Moving frame.
        renderer.bench(&[Pass::Terms, Pass::Resolve, Pass::Water], view, 30, true);
        let mut moving = Vec::new();
        let mut terms = Vec::new();
        let mut still = Vec::new();
        for _ in 0..args.rounds {
            moving.push(renderer.bench(&[Pass::Terms, Pass::Resolve, Pass::Water], view, args.frames, true));
            terms.push(renderer.bench(&[Pass::Terms], view, args.frames, true));
            renderer.bench(&[Pass::Terms], view, 1, false);
            still.push(renderer.bench(&[Pass::Resolve, Pass::Water], view, args.frames, false));
        }
        let (m, t, s) = (median(&mut moving), median(&mut terms), median(&mut still));
        println!("RESULT {}x{} {:6} moving {:6.2} ms ({:5.1} fps)  terms only {:6.2} ms  still {:6.2} ms", args.width, args.height, view.name, m, 1000.0 / m, t, s);
        lines.push(format!(
            "  {{\"view\": \"{}\", \"moving_ms\": {:.3}, \"terms_only_ms\": {:.3}, \"still_ms\": {:.3}, \"moving_rounds\": {:?}, \"still_rounds\": {:?}}}",
            view.name, m, t, s, moving, still
        ));
        if let Some(prefix) = &args.png {
            renderer.set_camera(view, 16.0, 2.0);
            let mut encoder = renderer.device.create_command_encoder(&Default::default());
            for pass in [Pass::Terms, Pass::Resolve, Pass::Water] {
                renderer.encode(&mut encoder, pass);
            }
            renderer.queue.submit([encoder.finish()]);
            renderer.save_png(&format!("{prefix}_{}.png", view.name));
        }
    }
    // Worst case after an edit: rebuild the whole focus island's mesh, upload it and refresh the
    // shadow map. The real pipeline is meant to rebuild only what a stroke touches; this is the
    // ceiling if it rebuilt everything.
    let focus_cells = scene::make_cells(if args.scene == "starter" { 623 } else { 4096 }, 7301);
    let mut mesh_ms = Vec::new();
    let mut total_ms = Vec::new();
    for _ in 0..5 {
        let start = Instant::now();
        let mesh = scene::build_island(&focus_cells, Vec3::ZERO, 7301, args.detail);
        mesh_ms.push(start.elapsed().as_secs_f64() * 1000.0);
        let buffer = renderer.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("rebuild"), contents: bytemuck::cast_slice(&mesh.vertices), usage: wgpu::BufferUsages::VERTEX });
        let mut encoder = renderer.device.create_command_encoder(&Default::default());
        renderer.encode(&mut encoder, Pass::Shadow);
        renderer.queue.submit([encoder.finish()]);
        renderer.wait();
        drop(buffer);
        total_ms.push(start.elapsed().as_secs_f64() * 1000.0);
    }
    let (rebuild_mesh, rebuild_total) = (median(&mut mesh_ms), median(&mut total_ms));
    println!("REBUILD focus island ({} cells): mesh {:.1} ms, with upload and shadow refresh {:.1} ms", focus_cells.len(), rebuild_mesh, rebuild_total);
    if let Some(path) = &args.out {
        let text = format!(
            "{{\n \"size\": [{}, {}],\n \"scene\": \"{}\",\n \"detail\": {},\n \"cells\": {:?},\n \"triangles\": {},\n \"draws\": {},\n \"frames\": {},\n \"rounds\": {},\n \"scene_build_ms\": {:.1},\n \"shadow_refresh_ms\": {:.3},\n \"full_rebuild_mesh_ms\": {:.2},\n \"full_rebuild_with_upload_and_shadow_ms\": {:.2},\n \"views\": [\n{}\n ]\n}}\n",
            args.width, args.height, args.scene, args.detail, cells, triangles, draws, args.frames, args.rounds, build_ms, shadow_ms, rebuild_mesh, rebuild_total, lines.join(",\n")
        );
        std::fs::write(path, text).expect("write result");
    }
}
