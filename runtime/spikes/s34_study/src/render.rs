//! Off-screen renderer for the studies: shadow map once, then terms, resolve,
//! water and a downsample with paper grain, written out as a PNG.
use std::time::Instant;

use glam::{Mat4, Vec3};
use wgpu::util::DeviceExt;

use crate::mesh::Vertex;
use crate::water::WaterVertex;

const SHADOW_SIZE: u32 = 4096;
const TERM_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba8Unorm;
const WORK_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba16Float;
const FINAL_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba8Unorm;
const DEPTH_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Depth32Float;

#[derive(Clone, Copy)]
pub struct Camera {
    pub eye: Vec3,
    pub target: Vec3,
    pub fov_deg: f32,
}

impl Camera {
    /// The frozen Godot project's rule: orbit `height` above the plane y = 0, looking at (cx, 0, cz).
    pub fn orbit(centre: [f32; 2], height: f32, yaw_deg: f32, pitch_deg: f32) -> Camera {
        let (yaw, pitch) = (yaw_deg.to_radians(), pitch_deg.to_radians());
        let flat = height / pitch.tan();
        Camera { eye: Vec3::new(centre[0] + yaw.sin() * flat, height, centre[1] + yaw.cos() * flat), target: Vec3::new(centre[0], 0.0, centre[1]), fov_deg: 31.0 }
    }
}

/// Everything that changes with the hour and the look.
#[derive(Clone, Copy)]
pub struct Frame {
    pub camera: Camera,
    pub sun_dir: Vec3,
    pub time: f32,
    pub hour: f32,
    pub look: [f32; 4],
    pub palette: [[f32; 4]; 16],
}

pub struct Renderer {
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    pub width: u32,
    pub height: u32,
    pub scale: u32,
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
    down_pipeline: wgpu::RenderPipeline,
    down_group: wgpu::BindGroup,
    base_view: wgpu::TextureView,
    terms_view: wgpu::TextureView,
    normal_view: wgpu::TextureView,
    depth_view: wgpu::TextureView,
    work_view: wgpu::TextureView,
    final_texture: wgpu::Texture,
    final_view: wgpu::TextureView,
    solid: Option<(wgpu::Buffer, u32)>,
    casters: u32,
    water: Option<(wgpu::Buffer, u32)>,
    bounds: (Vec3, Vec3),
}

fn target(device: &wgpu::Device, label: &str, width: u32, height: u32, format: wgpu::TextureFormat, extra: wgpu::TextureUsages) -> wgpu::Texture {
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
    pub fn new(width: u32, height: u32, scale: u32) -> Renderer {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions { power_preference: wgpu::PowerPreference::HighPerformance, ..Default::default() })).expect("adapter");
        let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default())).expect("device");
        let (iw, ih) = (width * scale, height * scale);
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor { label: Some("study"), source: wgpu::ShaderSource::Wgsl(include_str!("shader.wgsl").into()) });

        let globals = device.create_buffer(&wgpu::BufferDescriptor { label: Some("globals"), size: 132 * 4, usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST, mapped_at_creation: false });
        let globals_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("globals"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                ty: wgpu::BindingType::Buffer { ty: wgpu::BufferBindingType::Uniform, has_dynamic_offset: false, min_binding_size: None },
                count: None,
            }],
        });
        let globals_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &globals_layout, entries: &[wgpu::BindGroupEntry { binding: 0, resource: globals.as_entire_binding() }] });

        let shadow_view = target(&device, "shadow", SHADOW_SIZE, SHADOW_SIZE, DEPTH_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let base_view = target(&device, "base", iw, ih, TERM_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let terms_view = target(&device, "terms", iw, ih, TERM_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let normal_view = target(&device, "normal", iw, ih, TERM_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let depth_view = target(&device, "depth", iw, ih, DEPTH_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let work_view = target(&device, "work", iw, ih, WORK_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let final_texture = target(&device, "final", width, height, FINAL_FORMAT, wgpu::TextureUsages::COPY_SRC);
        let final_view = final_texture.create_view(&Default::default());

        let vertex_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<Vertex>() as u64,
            step_mode: wgpu::VertexStepMode::Vertex,
            attributes: &[
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 0, shader_location: 0 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 12, shader_location: 1 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 24, shader_location: 2 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 28, shader_location: 3 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 32, shader_location: 4 },
            ],
        };
        let depth_state = |bias: wgpu::DepthBiasState| {
            Some(wgpu::DepthStencilState { format: DEPTH_FORMAT, depth_write_enabled: Some(true), depth_compare: Some(wgpu::CompareFunction::Less), stencil: wgpu::StencilState::default(), bias })
        };
        let layout_of = |groups: &[Option<&wgpu::BindGroupLayout>]| device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor { label: None, bind_group_layouts: groups, immediate_size: 0 });
        let full_screen = |label: &str, layout: &wgpu::PipelineLayout, entry: &str, format: wgpu::TextureFormat| {
            device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: Some(label),
                layout: Some(layout),
                vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_full"), buffers: &[], compilation_options: Default::default() },
                fragment: Some(wgpu::FragmentState { module: &shader, entry_point: Some(entry), targets: &[Some(format.into())], compilation_options: Default::default() }),
                primitive: wgpu::PrimitiveState::default(),
                depth_stencil: None,
                multisample: wgpu::MultisampleState::default(),
                multiview_mask: None,
                cache: None,
            })
        };

        let shadow_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("shadow"),
            layout: Some(&layout_of(&[Some(&globals_layout)])),
            vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_shadow"), buffers: &[Some(vertex_layout.clone())], compilation_options: Default::default() },
            fragment: None,
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: depth_state(wgpu::DepthBiasState { constant: 2, slope_scale: 2.0, clamp: 0.0 }),
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        let terms_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("terms"),
            entries: &[texture_entry(0, true), wgpu::BindGroupLayoutEntry { binding: 1, visibility: wgpu::ShaderStages::FRAGMENT, ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Comparison), count: None }],
        });
        let shadow_sampler = device.create_sampler(&wgpu::SamplerDescriptor { label: Some("shadow"), mag_filter: wgpu::FilterMode::Linear, min_filter: wgpu::FilterMode::Linear, compare: Some(wgpu::CompareFunction::LessEqual), ..Default::default() });
        let terms_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &terms_bind,
            entries: &[wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&shadow_view) }, wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::Sampler(&shadow_sampler) }],
        });
        let terms_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("terms"),
            layout: Some(&layout_of(&[Some(&globals_layout), Some(&terms_bind)])),
            vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_terms"), buffers: &[Some(vertex_layout.clone())], compilation_options: Default::default() },
            fragment: Some(wgpu::FragmentState { module: &shader, entry_point: Some("fs_terms"), targets: &[Some(TERM_FORMAT.into()), Some(TERM_FORMAT.into()), Some(TERM_FORMAT.into())], compilation_options: Default::default() }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: depth_state(wgpu::DepthBiasState::default()),
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        let resolve_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("resolve"), entries: &[texture_entry(0, false), texture_entry(1, false), texture_entry(2, false), texture_entry(3, true)] });
        let resolve_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &resolve_bind,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&base_view) },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::TextureView(&terms_view) },
                wgpu::BindGroupEntry { binding: 2, resource: wgpu::BindingResource::TextureView(&normal_view) },
                wgpu::BindGroupEntry { binding: 3, resource: wgpu::BindingResource::TextureView(&depth_view) },
            ],
        });
        let resolve_pipeline = full_screen("resolve", &layout_of(&[Some(&globals_layout), Some(&resolve_bind)]), "fs_resolve", WORK_FORMAT);

        let one_depth = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("water"), entries: &[texture_entry(0, true)] });
        let water_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &one_depth, entries: &[wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&depth_view) }] });
        let water_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("water"),
            layout: Some(&layout_of(&[Some(&globals_layout), Some(&one_depth)])),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_water"),
                buffers: &[Some(wgpu::VertexBufferLayout {
                    array_stride: 24,
                    step_mode: wgpu::VertexStepMode::Vertex,
                    attributes: &[
                        wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 0, shader_location: 0 },
                        wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 12, shader_location: 1 },
                    ],
                })],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs_water"),
                targets: &[Some(wgpu::ColorTargetState { format: WORK_FORMAT, blend: Some(wgpu::BlendState::ALPHA_BLENDING), write_mask: wgpu::ColorWrites::ALL })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        let one_colour = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("down"), entries: &[texture_entry(0, false)] });
        let down_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &one_colour, entries: &[wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&work_view) }] });
        let down_pipeline = full_screen("down", &layout_of(&[Some(&globals_layout), Some(&one_colour)]), "fs_down", FINAL_FORMAT);

        Renderer {
            device,
            queue,
            width,
            height,
            scale,
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
            down_pipeline,
            down_group,
            base_view,
            terms_view,
            normal_view,
            depth_view,
            work_view,
            final_texture,
            final_view,
            solid: None,
            casters: 0,
            water: None,
            bounds: (Vec3::ZERO, Vec3::ZERO),
        }
    }

    /// Uploads the baked scene. The first `casters` vertices cast shadows (the islands);
    /// the rest (distant peaks) do not.
    pub fn set_scene(&mut self, vertices: &[Vertex], casters: usize, water: &[WaterVertex]) {
        self.solid = Some((self.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("solid"), contents: bytemuck::cast_slice(vertices), usage: wgpu::BufferUsages::VERTEX }), vertices.len() as u32));
        self.casters = casters as u32;
        self.water = if water.is_empty() { None } else { Some((self.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("water"), contents: bytemuck::cast_slice(water), usage: wgpu::BufferUsages::VERTEX }), water.len() as u32)) };
        let (mut low, mut high) = (Vec3::splat(f32::MAX), Vec3::splat(f32::MIN));
        for vertex in &vertices[..casters] {
            let p = Vec3::from_array(vertex.pos);
            low = low.min(p);
            high = high.max(p);
        }
        self.bounds = (low, high);
    }

    fn light_matrix(&self, sun_dir: Vec3) -> Mat4 {
        let (low, high) = self.bounds;
        let centre = (low + high) * 0.5;
        let view = Mat4::look_at_rh(centre + sun_dir * 600.0, centre, Vec3::Y);
        let (mut a, mut b) = (Vec3::splat(f32::MAX), Vec3::splat(f32::MIN));
        for corner in 0..8 {
            let p = view.transform_point3(Vec3::new(if corner & 1 == 0 { low.x } else { high.x }, if corner & 2 == 0 { low.y } else { high.y }, if corner & 4 == 0 { low.z } else { high.z }));
            a = a.min(p);
            b = b.max(p);
        }
        Mat4::orthographic_rh(a.x - 1.0, b.x + 1.0, a.y - 1.0, b.y + 1.0, -b.z - 5.0, -a.z + 5.0) * view
    }

    fn write_globals(&self, frame: &Frame) {
        let (near, far) = (0.5_f32, 4000.0_f32);
        let projection = Mat4::perspective_rh(frame.camera.fov_deg.to_radians(), self.width as f32 / self.height as f32, near, far);
        let view_proj = projection * Mat4::look_at_rh(frame.camera.eye, frame.camera.target, Vec3::Y);
        let mut data = [0.0_f32; 132];
        data[0..16].copy_from_slice(&view_proj.to_cols_array());
        data[16..32].copy_from_slice(&view_proj.inverse().to_cols_array());
        data[32..48].copy_from_slice(&self.light_matrix(frame.sun_dir).to_cols_array());
        data[48..51].copy_from_slice(&frame.sun_dir.to_array());
        data[52..55].copy_from_slice(&frame.camera.eye.to_array());
        data[56..60].copy_from_slice(&[frame.time, frame.hour, 1.0 / (self.width * self.scale) as f32, 1.0 / (self.height * self.scale) as f32]);
        data[60..64].copy_from_slice(&[near, far, -15.0, self.scale as f32]);
        data[64..68].copy_from_slice(&frame.look);
        for (index, entry) in frame.palette.iter().enumerate() {
            data[68 + index * 4..72 + index * 4].copy_from_slice(entry);
        }
        self.queue.write_buffer(&self.globals, 0, bytemuck::cast_slice(&data));
    }

    fn encode(&self, encoder: &mut wgpu::CommandEncoder, shadow: bool) {
        let clear = |view| Some(wgpu::RenderPassColorAttachment { view, depth_slice: None, resolve_target: None, ops: wgpu::Operations { load: wgpu::LoadOp::Clear(wgpu::Color::BLACK), store: wgpu::StoreOp::Store } });
        let depth = |view| Some(wgpu::RenderPassDepthStencilAttachment { view, depth_ops: Some(wgpu::Operations { load: wgpu::LoadOp::Clear(1.0), store: wgpu::StoreOp::Store }), stencil_ops: None });
        let Some((solid, count)) = &self.solid else { return };
        if shadow {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("shadow"), color_attachments: &[], depth_stencil_attachment: depth(&self.shadow_view), timestamp_writes: None, occlusion_query_set: None, multiview_mask: None });
            pass.set_pipeline(&self.shadow_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_vertex_buffer(0, solid.slice(..));
            pass.draw(0..self.casters, 0..1);
        }
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("terms"),
                color_attachments: &[clear(&self.base_view), clear(&self.terms_view), clear(&self.normal_view)],
                depth_stencil_attachment: depth(&self.depth_view),
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_pipeline(&self.terms_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, &self.terms_group, &[]);
            pass.set_vertex_buffer(0, solid.slice(..));
            pass.draw(0..*count, 0..1);
        }
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("resolve"), color_attachments: &[clear(&self.work_view)], depth_stencil_attachment: None, timestamp_writes: None, occlusion_query_set: None, multiview_mask: None });
            pass.set_pipeline(&self.resolve_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, &self.resolve_group, &[]);
            pass.draw(0..3, 0..1);
        }
        if let Some((water, count)) = &self.water {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("water"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment { view: &self.work_view, depth_slice: None, resolve_target: None, ops: wgpu::Operations { load: wgpu::LoadOp::Load, store: wgpu::StoreOp::Store } })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_pipeline(&self.water_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, &self.water_group, &[]);
            pass.set_vertex_buffer(0, water.slice(..));
            pass.draw(0..*count, 0..1);
        }
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("down"), color_attachments: &[clear(&self.final_view)], depth_stencil_attachment: None, timestamp_writes: None, occlusion_query_set: None, multiview_mask: None });
            pass.set_pipeline(&self.down_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, &self.down_group, &[]);
            pass.draw(0..3, 0..1);
        }
    }

    pub fn wait(&self) {
        self.device.poll(wgpu::PollType::wait_indefinitely()).expect("poll");
    }

    /// Renders one frame, shadow map included.
    pub fn render(&self, frame: &Frame) {
        self.write_globals(frame);
        let mut encoder = self.device.create_command_encoder(&Default::default());
        self.encode(&mut encoder, true);
        self.queue.submit([encoder.finish()]);
    }

    /// Milliseconds per frame for `frames` frames with the camera orbiting; the shadow
    /// map is not redrawn (it is cached). Off screen, so no compositor ceiling applies.
    pub fn bench(&self, frame: &Frame, frames: u32) -> f64 {
        self.render(frame);
        self.wait();
        let start = Instant::now();
        for index in 0..frames {
            let mut moved = *frame;
            let turn = glam::Quat::from_rotation_y(index as f32 * 0.012);
            moved.camera.eye = frame.camera.target + turn * (frame.camera.eye - frame.camera.target);
            self.write_globals(&moved);
            let mut encoder = self.device.create_command_encoder(&Default::default());
            self.encode(&mut encoder, false);
            self.queue.submit([encoder.finish()]);
            if index % 8 == 7 {
                self.wait();
            }
        }
        self.wait();
        start.elapsed().as_secs_f64() * 1000.0 / frames as f64
    }

    pub fn save_png(&self, path: &str) -> PictureStats {
        let row = (self.width * 4).div_ceil(256) * 256;
        let buffer = self.device.create_buffer(&wgpu::BufferDescriptor { label: Some("readback"), size: (row * self.height) as u64, usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ, mapped_at_creation: false });
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
        let file = std::io::BufWriter::new(std::fs::File::create(path).unwrap_or_else(|e| panic!("cannot write {path}: {e}")));
        let mut encoder = png::Encoder::new(file, self.width, self.height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        encoder.write_header().expect("png header").write_image_data(&pixels).expect("png data");
        PictureStats::measure(&pixels, self.width as usize, self.height as usize)
    }
}

/// Checks for the art goal's "comfortable all day" and "not muddy" properties,
/// measured on the frame as written (display-encoded values, 0 to 1).
#[derive(Clone, Copy)]
pub struct PictureStats {
    pub luma_p05: f32,
    pub luma_p50: f32,
    pub luma_p95: f32,
    /// Share of the frame brighter than 0.94 or darker than 0.08.
    pub near_white: f32,
    pub near_black: f32,
    pub saturation_mean: f32,
    pub saturation_p99: f32,
    /// Share of 32 x 32 blocks with almost no detail: room for icons and windows.
    pub quiet_share: f32,
}

impl PictureStats {
    fn measure(pixels: &[u8], width: usize, height: usize) -> PictureStats {
        let mut luma_hist = [0u32; 256];
        let mut sat_hist = [0u32; 256];
        let (mut count, mut sat_sum) = (0u32, 0.0f64);
        let luma = |x: usize, y: usize| -> f32 {
            let i = (y * width + x) * 4;
            (0.2126 * pixels[i] as f32 + 0.7152 * pixels[i + 1] as f32 + 0.0722 * pixels[i + 2] as f32) / 255.0
        };
        for y in (0..height).step_by(2) {
            for x in (0..width).step_by(2) {
                let i = (y * width + x) * 4;
                let (r, g, b) = (pixels[i] as f32 / 255.0, pixels[i + 1] as f32 / 255.0, pixels[i + 2] as f32 / 255.0);
                let (high, low) = (r.max(g).max(b), r.min(g).min(b));
                let saturation = if high > 0.0 { (high - low) / high } else { 0.0 };
                luma_hist[(luma(x, y) * 255.0) as usize] += 1;
                sat_hist[(saturation * 255.0) as usize] += 1;
                sat_sum += saturation as f64;
                count += 1;
            }
        }
        let percentile = |hist: &[u32; 256], q: f32| -> f32 {
            let target = (count as f32 * q) as u32;
            let mut seen = 0;
            for (value, n) in hist.iter().enumerate() {
                seen += n;
                if seen >= target {
                    return value as f32 / 255.0;
                }
            }
            1.0
        };
        let share = |range: std::ops::Range<usize>| luma_hist[range].iter().sum::<u32>() as f32 / count as f32;
        let (mut blocks, mut quiet) = (0u32, 0u32);
        for by in (0..height.saturating_sub(32)).step_by(32) {
            for bx in (0..width.saturating_sub(32)).step_by(32) {
                let (mut sum, mut sum2) = (0.0f32, 0.0f32);
                for y in (by..by + 32).step_by(4) {
                    for x in (bx..bx + 32).step_by(4) {
                        let v = luma(x, y);
                        sum += v;
                        sum2 += v * v;
                    }
                }
                let mean = sum / 64.0;
                blocks += 1;
                if (sum2 / 64.0 - mean * mean).max(0.0).sqrt() < 0.012 {
                    quiet += 1;
                }
            }
        }
        PictureStats {
            luma_p05: percentile(&luma_hist, 0.05),
            luma_p50: percentile(&luma_hist, 0.50),
            luma_p95: percentile(&luma_hist, 0.95),
            near_white: share(240..256),
            near_black: share(0..21),
            saturation_mean: (sat_sum / count as f64) as f32,
            saturation_p99: percentile(&sat_hist, 0.99),
            quiet_share: quiet as f32 / blocks.max(1) as f32,
        }
    }
}
