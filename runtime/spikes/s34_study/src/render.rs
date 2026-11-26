//! Off-screen renderer for the studies: shadow map once, then terms (island and props),
//! occlusion and its blur at the output resolution, resolve in linear light (occlusion
//! upsampled with depth awareness), water, and a downsample that tone maps and encodes
//! to display values once, optionally followed by FXAA, written out as a PNG.
use std::time::Instant;

use glam::{Mat4, Vec3};
use wgpu::util::DeviceExt;

use crate::grass::{self, Clump, Grass, LeafVertex};
use crate::mesh::Vertex;
use crate::props::{self, PropVertex};
use crate::water::WaterVertex;

const SHADOW_SIZE: u32 = 4096;
const TERM_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba8Unorm;
const WORK_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba16Float;
/// Round r9 (F3): the far field behind the root mist is drawn at 1/FAR_LOW of the output size per axis.
const FAR_LOW: u32 = 4;
/// Plain 8-bit, not sRGB: the down pass writes display-encoded values itself.
const FINAL_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Rgba8Unorm;
const AO_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::R8Unorm;
const AOD_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::R32Float;
const AOD_MIPS: u32 = 5;
pub const LIGHT_SLOTS: usize = 49;
/// Round k2: slots 46 and 47 carry the settle motion's clock and map (settle.rs, shader.wgsl L_SETTLE).
pub const SETTLE_SLOT: usize = 46;
const GLOBAL_FLOATS: usize = 68 + LIGHT_SLOTS * 4;
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
    /// Screen-space occlusion on or off.
    pub ssao: bool,
    /// Blur the occlusion (off only to measure what the blur costs).
    pub ssao_blur: bool,
    /// 0 picture, 1 occlusion only (for checking the occlusion pass).
    pub debug: f32,
    /// The light set in linear values; slots are named in shader.wgsl.
    pub light: [[f32; 4]; LIGHT_SLOTS],
}

pub struct Renderer {
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    pub width: u32,
    pub height: u32,
    pub scale: u32,
    globals: wgpu::Buffer,
    globals_group: wgpu::BindGroup,
    globals_layout: wgpu::BindGroupLayout,
    /// Round k2: the settle map (two vec4 a texel) and the prop instances' settle records.
    settle_map: wgpu::Buffer,
    settle_items: wgpu::Buffer,
    shadow_view: wgpu::TextureView,
    shadow_pipeline: wgpu::RenderPipeline,
    terms_pipeline: wgpu::RenderPipeline,
    terms_group: wgpu::BindGroup,
    aod_pipeline: wgpu::RenderPipeline,
    aod_group: wgpu::BindGroup,
    aod_view: wgpu::TextureView,
    /// One view per pyramid level (render targets), and the downsample's bind groups (level k reads k - 1).
    aod_levels: Vec<wgpu::TextureView>,
    aod_down_groups: Vec<wgpu::BindGroup>,
    aod_down_pipeline: wgpu::RenderPipeline,
    ssao_pipeline: wgpu::RenderPipeline,
    ssao_group: wgpu::BindGroup,
    blur_h_pipeline: wgpu::RenderPipeline,
    blur_h_group: wgpu::BindGroup,
    blur_v_pipeline: wgpu::RenderPipeline,
    blur_v_group: wgpu::BindGroup,
    ao_a_view: wgpu::TextureView,
    ao_b_view: wgpu::TextureView,
    resolve_pipeline: wgpu::RenderPipeline,
    resolve_group: wgpu::BindGroup,
    far_low_pipeline: wgpu::RenderPipeline,
    far_low_group: wgpu::BindGroup,
    far_low_view: wgpu::TextureView,
    water_pipeline: wgpu::RenderPipeline,
    water_group: wgpu::BindGroup,
    down_pipeline: wgpu::RenderPipeline,
    down_group: wgpu::BindGroup,
    base_view: wgpu::TextureView,
    terms_view: wgpu::TextureView,
    normal_view: wgpu::TextureView,
    depth_view: wgpu::TextureView,
    work_view: wgpu::TextureView,
    water_view: wgpu::TextureView,
    final_texture: wgpu::Texture,
    final_view: wgpu::TextureView,
    solid: Option<(wgpu::Buffer, u32)>,
    casters: u32,
    water: Option<(wgpu::Buffer, u32)>,
    bounds: (Vec3, Vec3),
    /// FXAA after the tone curve: the down pass writes `ldr`, FXAA writes `final`.
    fxaa: Option<(wgpu::TextureView, wgpu::RenderPipeline, wgpu::BindGroup)>,
    props_bind: wgpu::BindGroupLayout,
    /// The props' texture bind group and the folder it was read from (kept across uploads: an
    /// edit re-uploads the props' vertices, not their textures).
    props_textures: Option<(std::path::PathBuf, wgpu::BindGroup)>,
    props_materials: wgpu::Buffer,
    prop_terms_pipelines: [wgpu::RenderPipeline; 3],
    /// Round r9 (F4): leaf cards depth only (cut-out), then shaded with an equal depth test.
    prop_leaf_depth_pipeline: wgpu::RenderPipeline,
    prop_leaf_shade_pipeline: wgpu::RenderPipeline,
    leaf_prepass: bool,
    /// S34_SKIP=leaf,grass: leave parts out of the terms pass, to measure what they cost.
    skip: String,
    prop_shadow_pipeline: wgpu::RenderPipeline,
    prop_shadow_leaf_pipeline: wgpu::RenderPipeline,
    /// Vertex buffer, the bind group, and the vertex ranges of stone, decor and leaf.
    props: Option<(wgpu::Buffer, wgpu::BindGroup, [std::ops::Range<u32>; 3])>,
    /// Props per class and 8 m chunk: class, vertex range, bounds.
    prop_chunks: Vec<(usize, std::ops::Range<u32>, Vec3, Vec3)>,
    grass_pipeline: wgpu::RenderPipeline,
    /// Vertices, indices, and per chunk its bounds and the index ranges of its three levels.
    grass: Option<GrassGpu>,
    /// Round k5: GPU timestamps per pass (window mode only; gputime.rs).
    pub timer: Option<crate::gputime::GpuTimer>,
}

/// The grass on the GPU: the clump meshes of all levels, the roots (instances), and per chunk
/// its bounds, first root and root counts at full, half and quarter density.
struct GrassGpu {
    mesh: wgpu::Buffer,
    index: wgpu::Buffer,
    levels: [(u32, std::ops::Range<u32>); grass::LEVELS],
    clumps: wgpu::Buffer,
    chunks: Vec<(Vec3, Vec3, u32, [u32; 3], Vec3, Vec3)>,
}

/// Round k5: an edit's upload made off the frame loop (`Renderer::prepare`, `install`).
pub struct Prepared {
    solid: (wgpu::Buffer, u32),
    casters: u32,
    water: Option<(wgpu::Buffer, u32)>,
    bounds: (Vec3, Vec3),
    props: Option<(wgpu::Buffer, [std::ops::Range<u32>; 3], Vec<(usize, std::ops::Range<u32>, Vec3, Vec3)>, Vec<[f32; 4]>, std::path::PathBuf)>,
    grass: Option<GrassGpu>,
    settle: (wgpu::Buffer, wgpu::Buffer),
}

/// One vertex buffer holding `parts` back to back, written once into mapped memory (no
/// concatenated copy on the CPU first).
fn concat_buffer(device: &wgpu::Device, label: &str, parts: &[&[u8]]) -> wgpu::Buffer {
    let size: usize = parts.iter().map(|p| p.len()).sum();
    let buffer = device.create_buffer(&wgpu::BufferDescriptor { label: Some(label), size: size.max(4).next_multiple_of(4) as u64, usage: wgpu::BufferUsages::VERTEX, mapped_at_creation: true });
    {
        let mut view = buffer.slice(..).get_mapped_range_mut().expect("mapped vertex buffer");
        let mut at = 0;
        for part in parts {
            view.slice(at..at + part.len()).copy_from_slice(part);
            at += part.len();
        }
    }
    buffer.unmap();
    buffer
}

/// The grass field's buffers: the clump meshes of all levels and the roots.
fn grass_gpu(device: &wgpu::Device, grass: &Grass) -> Option<GrassGpu> {
    if grass.clumps.is_empty() {
        return None;
    }
    let meshes = grass::meshes();
    let mesh = device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("clump mesh"), contents: bytemuck::cast_slice(&meshes.vertices), usage: wgpu::BufferUsages::VERTEX });
    let index = device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("clump index"), contents: bytemuck::cast_slice(&meshes.indices), usage: wgpu::BufferUsages::INDEX });
    let clumps = device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("clumps"), contents: bytemuck::cast_slice(&grass.clumps), usage: wgpu::BufferUsages::VERTEX });
    let chunks = grass.chunks.iter().map(|c| (c.lo, c.hi, c.first, c.counts, c.parent_lo, c.parent_hi)).collect();
    Some(GrassGpu { mesh, index, levels: meshes.levels.clone(), clumps, chunks })
}

/// The props baked for upload: one contiguous range per class, chunks with bounds, the material table.
struct BakedProps {
    vertices: Vec<PropVertex>,
    ranges: [std::ops::Range<u32>; 3],
    chunks: Vec<(usize, std::ops::Range<u32>, Vec3, Vec3)>,
    bounds: (Vec3, Vec3),
    table: Vec<[f32; 4]>,
}

fn bake_props(library: &props::Library, total: usize) -> BakedProps {
    // Within each class the triangles are grouped in 8 m chunks of the plan with their bounds,
    // so the terms pass draws only the chunks in view, nearest first (the shadow pass, cached,
    // draws each class whole).
    let mut all: Vec<PropVertex> = Vec::with_capacity(total);
    let mut ranges: [std::ops::Range<u32>; 3] = [0..0, 0..0, 0..0];
    let mut chunks = Vec::new();
    // Round r9 (F4): 4 m chunks (8 m before) cull the crowns more tightly to the view.
    let size: f32 = std::env::var("S34_PROP_CHUNK").ok().and_then(|v| v.parse().ok()).unwrap_or(4.0);
    for (class, bucket) in library.buckets.iter().enumerate() {
        let start = all.len() as u32;
        let mut by_chunk: std::collections::BTreeMap<(i32, i32), Vec<PropVertex>> = std::collections::BTreeMap::new();
        for tri in bucket.chunks_exact(3) {
            let c = (Vec3::from_array(tri[0].pos) + Vec3::from_array(tri[1].pos) + Vec3::from_array(tri[2].pos)) / 3.0;
            by_chunk.entry(((c.x / size).floor() as i32, (c.z / size).floor() as i32)).or_default().extend_from_slice(tri);
        }
        for (_, list) in by_chunk {
            let first = all.len() as u32;
            let (mut lo, mut hi) = (Vec3::splat(f32::MAX), Vec3::splat(f32::MIN));
            for v in &list {
                lo = lo.min(Vec3::from_array(v.pos));
                hi = hi.max(Vec3::from_array(v.pos));
            }
            all.extend_from_slice(&list);
            chunks.push((class, first..all.len() as u32, lo, hi));
        }
        ranges[class] = start..all.len() as u32;
    }
    let (mut low, mut high) = (Vec3::splat(f32::MAX), Vec3::splat(f32::MIN));
    for vertex in &all {
        let p = Vec3::from_array(vertex.pos);
        low = low.min(p);
        high = high.max(p);
    }
    let mut table = vec![[0.0_f32; 4]; props::MAX_MATERIALS * props::MATERIAL_ROWS];
    for (index, rows) in library.materials.iter().enumerate() {
        for (r, row) in rows.iter().enumerate() {
            table[index * props::MATERIAL_ROWS + r] = *row;
        }
    }
    BakedProps { vertices: all, ranges, chunks, bounds: (low, high), table }
}

/// What one frame drew of the grass: triangles, and chunks at each level.
#[derive(Clone, Copy, Default)]
pub struct GrassDrawn {
    pub triangles: u64,
    pub chunks: [u32; grass::LEVELS],
}

/// Where the island's stone pigment is read from (relative to the repository root).
const STONE_WASH: &str = "assets/terrain_editor/gouache_stone_sol61.png";
/// distant_landscape.gd's cloud-deck billow image (256 x 256, made by Godot: data/godot_billow.gd).
const BILLOW: &str = "runtime/spikes/s34_study/data/billow_4127.png";
/// The sky's painted cloud band (sky_surface.gdshaderinc `cloud_backdrop`).
const CLOUD_BACKDROP: &str = "assets/terrain_editor/cloud_backdrop_v01.png";

/// True when the box lies wholly outside one plane of the view volume.
fn outside(view_proj: &Mat4, lo: Vec3, hi: Vec3) -> bool {
    let corners: [glam::Vec4; 8] = std::array::from_fn(|i| *view_proj * glam::Vec4::new(if i & 1 == 0 { lo.x } else { hi.x }, if i & 2 == 0 { lo.y } else { hi.y }, if i & 4 == 0 { lo.z } else { hi.z }, 1.0));
    let all = |test: &dyn Fn(&glam::Vec4) -> bool| corners.iter().all(test);
    all(&|c| c.x < -c.w) || all(&|c| c.x > c.w) || all(&|c| c.y < -c.w) || all(&|c| c.y > c.w) || all(&|c| c.z < 0.0) || all(&|c| c.z > c.w)
}

/// An RGBA8 texture with a full box-filtered mip chain.
fn mip_texture(device: &wgpu::Device, queue: &wgpu::Queue, label: &str, image: &props::Image, format: wgpu::TextureFormat) -> wgpu::TextureView {
    let levels = 32 - image.width.max(image.height).leading_zeros();
    let texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some(label),
        size: wgpu::Extent3d { width: image.width, height: image.height, depth_or_array_layers: 1 },
        mip_level_count: levels,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    });
    let (mut w, mut h, mut data) = (image.width, image.height, image.rgba.clone());
    for level in 0..levels {
        queue.write_texture(
            wgpu::TexelCopyTextureInfo { texture: &texture, mip_level: level, origin: wgpu::Origin3d::ZERO, aspect: wgpu::TextureAspect::All },
            &data,
            wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(w * 4), rows_per_image: Some(h) },
            wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
        );
        let (nw, nh) = ((w / 2).max(1), (h / 2).max(1));
        let mut next = vec![0u8; (nw * nh * 4) as usize];
        for y in 0..nh {
            for x in 0..nw {
                for c in 0..4 {
                    let mut sum = 0u32;
                    for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
                        let (sx, sy) = ((x * 2 + dx).min(w - 1), (y * 2 + dy).min(h - 1));
                        sum += data[((sy * w + sx) * 4 + c) as usize] as u32;
                    }
                    next[((y * nw + x) * 4 + c) as usize] = ((sum + 2) / 4) as u8;
                }
            }
        }
        (w, h, data) = (nw, nh, next);
    }
    texture.create_view(&Default::default())
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

fn filtered_entry(binding: u32) -> wgpu::BindGroupLayoutEntry {
    wgpu::BindGroupLayoutEntry {
        binding,
        visibility: wgpu::ShaderStages::FRAGMENT,
        ty: wgpu::BindingType::Texture { sample_type: wgpu::TextureSampleType::Float { filterable: true }, view_dimension: wgpu::TextureViewDimension::D2, multisampled: false },
        count: None,
    }
}

fn sampler_entry(binding: u32) -> wgpu::BindGroupLayoutEntry {
    wgpu::BindGroupLayoutEntry { binding, visibility: wgpu::ShaderStages::FRAGMENT, ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering), count: None }
}

impl Renderer {
    pub fn new(width: u32, height: u32, scale: u32, fxaa: bool) -> Renderer {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions { power_preference: wgpu::PowerPreference::HighPerformance, ..Default::default() })).expect("adapter");
        let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default())).expect("device");
        Renderer::with_device(device, queue, width, height, scale, fxaa, FINAL_FORMAT)
    }

    /// Round k5: on a given device (the window's), with the last pass (down, or FXAA when on)
    /// writing `out_format`, so it can draw straight into a surface texture (window.rs).
    pub fn with_device(device: wgpu::Device, queue: wgpu::Queue, width: u32, height: u32, scale: u32, fxaa: bool, out_format: wgpu::TextureFormat) -> Renderer {
        let (iw, ih) = (width * scale, height * scale);
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor { label: Some("study"), source: wgpu::ShaderSource::Wgsl(include_str!("shader.wgsl").into()) });

        let globals = device.create_buffer(&wgpu::BufferDescriptor { label: Some("globals"), size: (GLOBAL_FLOATS * 4) as u64, usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST, mapped_at_creation: false });
        let globals_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("globals"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                    ty: wgpu::BindingType::Buffer { ty: wgpu::BufferBindingType::Uniform, has_dynamic_offset: false, min_binding_size: None },
                    count: None,
                },
                // Round k2: the settle map and the prop instances' settle records (vertex stages).
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::VERTEX,
                    ty: wgpu::BindingType::Buffer { ty: wgpu::BufferBindingType::Storage { read_only: true }, has_dynamic_offset: false, min_binding_size: None },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 2,
                    visibility: wgpu::ShaderStages::VERTEX,
                    ty: wgpu::BindingType::Buffer { ty: wgpu::BufferBindingType::Storage { read_only: true }, has_dynamic_offset: false, min_binding_size: None },
                    count: None,
                },
            ],
        });
        let settle_map = device.create_buffer(&wgpu::BufferDescriptor { label: Some("settle map"), size: std::mem::size_of::<crate::settle::Texel>() as u64, usage: wgpu::BufferUsages::STORAGE, mapped_at_creation: false });
        let settle_items = device.create_buffer(&wgpu::BufferDescriptor { label: Some("settle items"), size: 16, usage: wgpu::BufferUsages::STORAGE, mapped_at_creation: false });
        let globals_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &globals_layout,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: globals.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 1, resource: settle_map.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 2, resource: settle_items.as_entire_binding() },
            ],
        });

        let shadow_view = target(&device, "shadow", SHADOW_SIZE, SHADOW_SIZE, DEPTH_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let base_view = target(&device, "base", iw, ih, TERM_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let terms_view = target(&device, "terms", iw, ih, TERM_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let normal_view = target(&device, "normal", iw, ih, TERM_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let depth_view = target(&device, "depth", iw, ih, DEPTH_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let work_view = target(&device, "work", iw, ih, WORK_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        // The water pass draws premultiplied into its own target (cleared each frame), so it can read
        // the resolved picture for its reflections; the down pass composites it over the picture.
        let water_view = target(&device, "water", iw, ih, WORK_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        // Occlusion and its blur run at the output resolution whatever the internal scale is.
        // Occlusion targets: half the internal resolution (shader.wgsl AO_STRIDE).
        let (aw, ah) = ((iw / 2).max(1), (ih / 2).max(1));
        let ao_a_view = target(&device, "ao a", aw, ah, AO_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let ao_b_view = target(&device, "ao b", aw, ah, AO_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
        let final_texture = target(&device, "final", width, height, out_format, wgpu::TextureUsages::COPY_SRC);
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

        // Terms: the sun's depth map, and the gouache wash the island's stone is painted with.
        let terms_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("terms"),
            entries: &[
                texture_entry(0, true),
                wgpu::BindGroupLayoutEntry { binding: 1, visibility: wgpu::ShaderStages::FRAGMENT, ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Comparison), count: None },
                filtered_entry(2),
                sampler_entry(3),
            ],
        });
        let shadow_sampler = device.create_sampler(&wgpu::SamplerDescriptor { label: Some("shadow"), mag_filter: wgpu::FilterMode::Linear, min_filter: wgpu::FilterMode::Linear, compare: Some(wgpu::CompareFunction::LessEqual), ..Default::default() });
        let wash = mip_texture(&device, &queue, "stone wash", &props::load_png(std::path::Path::new(STONE_WASH)), wgpu::TextureFormat::Rgba8UnormSrgb);
        let wash_sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("wash"),
            address_mode_u: wgpu::AddressMode::Repeat,
            address_mode_v: wgpu::AddressMode::Repeat,
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            mipmap_filter: wgpu::MipmapFilterMode::Linear,
            anisotropy_clamp: 8,
            ..Default::default()
        });
        let terms_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &terms_bind,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: wgpu::BindingResource::TextureView(&shadow_view) },
                wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::Sampler(&shadow_sampler) },
                view_entry(2, &wash),
                wgpu::BindGroupEntry { binding: 3, resource: wgpu::BindingResource::Sampler(&wash_sampler) },
            ],
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

        // The grass field: two-sided rosettes, instanced (clump mesh per level, one record per root),
        // drawn into the terms after the island and the props.
        let grass_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("grass"),
            layout: Some(&layout_of(&[Some(&globals_layout), Some(&terms_bind)])),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_grass"),
                buffers: &[
                    Some(wgpu::VertexBufferLayout {
                        array_stride: std::mem::size_of::<LeafVertex>() as u64,
                        step_mode: wgpu::VertexStepMode::Vertex,
                        attributes: &[
                            wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 0, shader_location: 0 },
                            wgpu::VertexAttribute { format: wgpu::VertexFormat::Snorm8x4, offset: 12, shader_location: 1 },
                            wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 16, shader_location: 2 },
                        ],
                    }),
                    Some(wgpu::VertexBufferLayout {
                        array_stride: std::mem::size_of::<Clump>() as u64,
                        step_mode: wgpu::VertexStepMode::Instance,
                        attributes: &[
                            wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 0, shader_location: 3 },
                            wgpu::VertexAttribute { format: wgpu::VertexFormat::Snorm16x4, offset: 12, shader_location: 4 },
                            wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm16x2, offset: 20, shader_location: 5 },
                            wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 24, shader_location: 6 },
                            wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 28, shader_location: 7 },
                        ],
                    }),
                ],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState { module: &shader, entry_point: Some("fs_grass"), targets: &[Some(TERM_FORMAT.into()), Some(TERM_FORMAT.into()), Some(TERM_FORMAT.into())], compilation_options: Default::default() }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: depth_state(wgpu::DepthBiasState::default()),
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        // View distance of each output pixel's internal representative (-1 for sky): what the
        // occlusion taps, the blur and the upsample read, so none of them strides through the
        // internal depth buffer.
        // With a pyramid of AOD_MIPS levels (one of every 2 x 2 texels each) for far occlusion taps.
        let aod_texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("ao depth"),
            size: wgpu::Extent3d { width: aw, height: ah, depth_or_array_layers: 1 },
            mip_level_count: AOD_MIPS,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: AOD_FORMAT,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING,
            view_formats: &[],
        });
        let aod_view = aod_texture.create_view(&Default::default());
        let aod_level = |level: u32| aod_texture.create_view(&wgpu::TextureViewDescriptor { base_mip_level: level, mip_level_count: Some(1), ..Default::default() });
        let aod_levels: Vec<wgpu::TextureView> = (0..AOD_MIPS).map(aod_level).collect();
        let aod_down_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("ao depth down"), entries: &[texture_entry(0, false)] });
        let aod_down_groups: Vec<wgpu::BindGroup> = (1..AOD_MIPS as usize).map(|k| device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &aod_down_bind, entries: &[view_entry(0, &aod_levels[k - 1])] })).collect();
        let aod_down_pipeline = full_screen("ao depth down", &layout_of(&[Some(&globals_layout), Some(&aod_down_bind)]), "fs_aod_down", AOD_FORMAT);
        let aod_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("ao depth"), entries: &[texture_entry(0, true)] });
        let aod_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &aod_bind, entries: &[view_entry(0, &depth_view)] });
        let aod_pipeline = full_screen("ao depth", &layout_of(&[Some(&globals_layout), Some(&aod_bind)]), "fs_ao_depth", AOD_FORMAT);
        let ssao_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("ssao"), entries: &[texture_entry(0, true), texture_entry(1, false), texture_entry(2, false)] });
        let ssao_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &ssao_bind, entries: &[view_entry(0, &depth_view), view_entry(1, &normal_view), view_entry(2, &aod_view)] });
        let ssao_pipeline = full_screen("ssao", &layout_of(&[Some(&globals_layout), Some(&ssao_bind)]), "fs_ssao", AO_FORMAT);
        let blur_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("blur"), entries: &[texture_entry(0, false), texture_entry(1, false)] });
        let blur_h_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &blur_bind, entries: &[view_entry(0, &ao_a_view), view_entry(1, &aod_view)] });
        let blur_v_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &blur_bind, entries: &[view_entry(0, &ao_b_view), view_entry(1, &aod_view)] });
        let blur_layout = layout_of(&[Some(&globals_layout), Some(&blur_bind)]);
        let blur_h_pipeline = full_screen("blur h", &blur_layout, "fs_blur_h", AO_FORMAT);
        let blur_v_pipeline = full_screen("blur v", &blur_layout, "fs_blur_v", AO_FORMAT);

        // Far field: Godot's cloud-deck billow (distant_landscape.gd's FastNoiseLite image, written
        // by Godot itself) and the sky's painted cloud backdrop (source_color, so sRGB).
        let billow = mip_texture(&device, &queue, "billow", &props::load_png(std::path::Path::new(BILLOW)), wgpu::TextureFormat::Rgba8Unorm);
        let backdrop = mip_texture(&device, &queue, "cloud backdrop", &props::load_png(std::path::Path::new(CLOUD_BACKDROP)), wgpu::TextureFormat::Rgba8UnormSrgb);
        let far_sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("far"),
            address_mode_u: wgpu::AddressMode::Repeat,
            address_mode_v: wgpu::AddressMode::Repeat,
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            mipmap_filter: wgpu::MipmapFilterMode::Linear,
            ..Default::default()
        });
        // Round r9 (F3): the far field at a quarter of the output resolution, for the root's mist to
        // dissolve into (what lies behind it along the same ray), so the per-pixel cloud decks are
        // paid only for the sky itself.
        let (fw, fh) = ((width / FAR_LOW).max(1), (height / FAR_LOW).max(1));
        let far_low_texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("far low"),
            size: wgpu::Extent3d { width: fw, height: fh, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: WORK_FORMAT,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING,
            view_formats: &[],
        });
        let far_low_view = far_low_texture.create_view(&Default::default());
        let far_low_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("far low"), entries: &[filtered_entry(6), sampler_entry(7), filtered_entry(8)] });
        let far_low_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &far_low_bind,
            entries: &[view_entry(6, &billow), wgpu::BindGroupEntry { binding: 7, resource: wgpu::BindingResource::Sampler(&far_sampler) }, view_entry(8, &backdrop)],
        });
        let far_low_pipeline = full_screen("far low", &layout_of(&[Some(&globals_layout), Some(&far_low_bind)]), "fs_far_low", WORK_FORMAT);
        let resolve_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("resolve"),
            entries: &[
                texture_entry(0, false),
                texture_entry(1, false),
                texture_entry(2, false),
                texture_entry(3, true),
                texture_entry(4, false),
                texture_entry(5, false),
                filtered_entry(6),
                sampler_entry(7),
                filtered_entry(8),
                filtered_entry(9),
            ],
        });
        let resolve_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &resolve_bind,
            entries: &[
                view_entry(0, &base_view),
                view_entry(1, &terms_view),
                view_entry(2, &normal_view),
                view_entry(3, &depth_view),
                view_entry(4, &ao_a_view),
                view_entry(5, &aod_view),
                view_entry(6, &billow),
                wgpu::BindGroupEntry { binding: 7, resource: wgpu::BindingResource::Sampler(&far_sampler) },
                view_entry(8, &backdrop),
                view_entry(9, &far_low_view),
            ],
        });
        let resolve_pipeline = full_screen("resolve", &layout_of(&[Some(&globals_layout), Some(&resolve_bind)]), "fs_resolve", WORK_FORMAT);

        let one_depth = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("water"), entries: &[texture_entry(0, true), texture_entry(1, false)] });
        let water_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &one_depth, entries: &[view_entry(0, &depth_view), view_entry(1, &work_view)] });
        let water_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("water"),
            layout: Some(&layout_of(&[Some(&globals_layout), Some(&one_depth)])),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_water"),
                buffers: &[Some(wgpu::VertexBufferLayout {
                    array_stride: 28,
                    step_mode: wgpu::VertexStepMode::Vertex,
                    attributes: &[
                        wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 0, shader_location: 0 },
                        wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x4, offset: 12, shader_location: 1 },
                    ],
                })],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs_water"),
                targets: &[Some(wgpu::ColorTargetState { format: WORK_FORMAT, blend: Some(wgpu::BlendState::PREMULTIPLIED_ALPHA_BLENDING), write_mask: wgpu::ColorWrites::ALL })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        let one_colour = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("down"), entries: &[texture_entry(0, false), texture_entry(1, false)] });
        let down_group = device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &one_colour, entries: &[view_entry(0, &work_view), view_entry(1, &water_view)] });
        let down_pipeline = full_screen("down", &layout_of(&[Some(&globals_layout), Some(&one_colour)]), "fs_down", if fxaa { FINAL_FORMAT } else { out_format });

        let clamp_sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("clamp"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            mipmap_filter: wgpu::MipmapFilterMode::Linear,
            ..Default::default()
        });
        let fxaa = fxaa.then(|| {
            let ldr_view = target(&device, "ldr", width, height, FINAL_FORMAT, wgpu::TextureUsages::empty()).create_view(&Default::default());
            let bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor { label: Some("fxaa"), entries: &[filtered_entry(0), sampler_entry(1)] });
            let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout: &bind,
                entries: &[view_entry(0, &ldr_view), wgpu::BindGroupEntry { binding: 1, resource: wgpu::BindingResource::Sampler(&clamp_sampler) }],
            });
            let pipeline = full_screen("fxaa", &layout_of(&[Some(&globals_layout), Some(&bind)]), "fs_fxaa", out_format);
            (ldr_view, pipeline, group)
        });

        // Props: textures, a sampler and the material table in group 2.
        let props_bind = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("props"),
            entries: &[
                filtered_entry(0),
                filtered_entry(1),
                filtered_entry(2),
                sampler_entry(3),
                sampler_entry(4),
                wgpu::BindGroupLayoutEntry {
                    binding: 5,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer { ty: wgpu::BufferBindingType::Uniform, has_dynamic_offset: false, min_binding_size: None },
                    count: None,
                },
            ],
        });
        let props_materials = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("prop materials"),
            size: (props::MAX_MATERIALS * props::MATERIAL_ROWS * 16) as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let prop_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<PropVertex>() as u64,
            step_mode: wgpu::VertexStepMode::Vertex,
            attributes: &[
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 0, shader_location: 0 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 12, shader_location: 1 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x2, offset: 24, shader_location: 2 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Float32x3, offset: 32, shader_location: 3 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Unorm8x4, offset: 44, shader_location: 4 },
                wgpu::VertexAttribute { format: wgpu::VertexFormat::Uint8x4, offset: 48, shader_location: 5 },
            ],
        };
        let prop_terms_layout = layout_of(&[Some(&globals_layout), Some(&terms_bind), Some(&props_bind)]);
        let prop_terms = |label: &str, entry: &str, cull: Option<wgpu::Face>| {
            device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: Some(label),
                layout: Some(&prop_terms_layout),
                vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_prop"), buffers: &[Some(prop_layout.clone())], compilation_options: Default::default() },
                fragment: Some(wgpu::FragmentState { module: &shader, entry_point: Some(entry), targets: &[Some(TERM_FORMAT.into()), Some(TERM_FORMAT.into()), Some(TERM_FORMAT.into())], compilation_options: Default::default() }),
                primitive: wgpu::PrimitiveState { cull_mode: cull, front_face: wgpu::FrontFace::Ccw, ..Default::default() },
                depth_stencil: depth_state(wgpu::DepthBiasState::default()),
                multisample: wgpu::MultisampleState::default(),
                multiview_mask: None,
                cache: None,
            })
        };
        // Godot draws stone and decor with back faces culled and leaf cards from both sides.
        let prop_terms_pipelines = [
            prop_terms("prop stone", "fs_prop_stone", Some(wgpu::Face::Back)),
            prop_terms("prop decor", "fs_prop_decor", Some(wgpu::Face::Back)),
            prop_terms("prop leaf", "fs_prop_leaf", None),
        ];
        // Round r9 (F4): leaf cards in two steps within the terms pass.
        let leaf_pipeline = |label: &str, vertex: &str, entry: &str, write: wgpu::ColorWrites, depth: wgpu::DepthStencilState| {
            let target = |format: wgpu::TextureFormat| Some(wgpu::ColorTargetState { format, blend: None, write_mask: write });
            device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: Some(label),
                layout: Some(&prop_terms_layout),
                vertex: wgpu::VertexState { module: &shader, entry_point: Some(vertex), buffers: &[Some(prop_layout.clone())], compilation_options: Default::default() },
                fragment: Some(wgpu::FragmentState { module: &shader, entry_point: Some(entry), targets: &[target(TERM_FORMAT), target(TERM_FORMAT), target(TERM_FORMAT)], compilation_options: Default::default() }),
                primitive: wgpu::PrimitiveState { cull_mode: None, front_face: wgpu::FrontFace::Ccw, ..Default::default() },
                depth_stencil: Some(depth),
                multisample: wgpu::MultisampleState::default(),
                multiview_mask: None,
                cache: None,
            })
        };
        let depth_only = wgpu::DepthStencilState { format: DEPTH_FORMAT, depth_write_enabled: Some(true), depth_compare: Some(wgpu::CompareFunction::Less), stencil: wgpu::StencilState::default(), bias: wgpu::DepthBiasState::default() };
        let depth_equal = wgpu::DepthStencilState { format: DEPTH_FORMAT, depth_write_enabled: Some(false), depth_compare: Some(wgpu::CompareFunction::Equal), stencil: wgpu::StencilState::default(), bias: wgpu::DepthBiasState::default() };
        let prop_leaf_depth_pipeline = leaf_pipeline("prop leaf depth", "vs_prop_depth", "fs_prop_leaf_depth", wgpu::ColorWrites::empty(), depth_only);
        let prop_leaf_shade_pipeline = leaf_pipeline("prop leaf shade", "vs_prop", "fs_prop_leaf_shade", wgpu::ColorWrites::ALL, depth_equal);
        let shadow_bias = wgpu::DepthBiasState { constant: 2, slope_scale: 2.0, clamp: 0.0 };
        let prop_shadow_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("prop shadow"),
            layout: Some(&layout_of(&[Some(&globals_layout)])),
            vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_prop_shadow"), buffers: &[Some(prop_layout.clone())], compilation_options: Default::default() },
            fragment: None,
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: depth_state(shadow_bias),
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });
        // Leaf cards cast leaf-shaped shadows: the atlas cut-out runs in the shadow pass too.
        let prop_shadow_leaf_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("prop shadow leaf"),
            layout: Some(&layout_of(&[Some(&globals_layout), None, Some(&props_bind)])),
            vertex: wgpu::VertexState { module: &shader, entry_point: Some("vs_prop_shadow_leaf"), buffers: &[Some(prop_layout.clone())], compilation_options: Default::default() },
            fragment: Some(wgpu::FragmentState { module: &shader, entry_point: Some("fs_prop_shadow_leaf"), targets: &[], compilation_options: Default::default() }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: depth_state(shadow_bias),
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        Renderer {
            device,
            queue,
            width,
            height,
            scale,
            globals,
            globals_group,
            globals_layout,
            settle_map,
            settle_items,
            shadow_view,
            shadow_pipeline,
            terms_pipeline,
            terms_group,
            aod_pipeline,
            aod_group,
            aod_view,
            aod_levels,
            aod_down_groups,
            aod_down_pipeline,
            ssao_pipeline,
            ssao_group,
            blur_h_pipeline,
            blur_h_group,
            blur_v_pipeline,
            blur_v_group,
            ao_a_view,
            ao_b_view,
            resolve_pipeline,
            resolve_group,
            far_low_pipeline,
            far_low_group,
            far_low_view,
            water_pipeline,
            water_group,
            down_pipeline,
            down_group,
            base_view,
            terms_view,
            normal_view,
            depth_view,
            work_view,
            water_view,
            final_texture,
            final_view,
            solid: None,
            casters: 0,
            water: None,
            bounds: (Vec3::ZERO, Vec3::ZERO),
            fxaa,
            props_bind,
            props_textures: None,
            props_materials,
            prop_terms_pipelines,
            prop_leaf_depth_pipeline,
            prop_leaf_shade_pipeline,
            leaf_prepass: std::env::var("S34_LEAF_PREPASS").map_or(true, |v| v != "0"),
            skip: std::env::var("S34_SKIP").unwrap_or_default(),
            prop_shadow_pipeline,
            prop_shadow_leaf_pipeline,
            props: None,
            prop_chunks: Vec::new(),
            grass_pipeline,
            grass: None,
            timer: None,
        }
    }

    /// Round k5: the final picture (display values), for a blit to a surface (window.rs).
    pub fn final_view(&self) -> &wgpu::TextureView {
        &self.final_view
    }

    /// Round k5: one frame recorded into `encoder` (globals written), its last pass into `out`
    /// (a surface texture) or the final texture; the shadow map only when `shadow`.
    pub fn draw(&self, encoder: &mut wgpu::CommandEncoder, frame: &Frame, shadow: bool, out: Option<&wgpu::TextureView>) -> GrassDrawn {
        self.write_globals(frame);
        self.encode(encoder, shadow, frame.ssao, frame.ssao_blur, &frame.camera, out)
    }

    /// Round k5: a pass's GPU timestamps when the window's timer is on.
    fn ts(&self, label: &'static str) -> Option<wgpu::RenderPassTimestampWrites<'_>> {
        self.timer.as_ref().and_then(|t| t.pass(label))
    }

    /// Uploads the grass field: the clump meshes of all levels and the roots.
    pub fn set_grass(&mut self, grass: &Grass) {
        self.grass = grass_gpu(&self.device, grass);
    }

    /// Uploads the props of all islands (one contiguous range per class), their material
    /// table and textures. Props cast shadows; the shadow bounds grow to hold them.
    pub fn set_props(&mut self, library: &props::Library) {
        let total: usize = library.buckets.iter().map(|b| b.len()).sum();
        if total == 0 {
            self.props = None;
            return;
        }
        let baked = bake_props(library, total);
        let (all, ranges) = (baked.vertices, baked.ranges);
        self.prop_chunks = baked.chunks;
        self.bounds = (self.bounds.0.min(baked.bounds.0), self.bounds.1.max(baked.bounds.1));
        self.queue.write_buffer(&self.props_materials, 0, bytemuck::cast_slice(&baked.table));
        let dir = library.texture_dir.clone().expect("texture folder");
        if let Some((_, group)) = self.props_textures.as_ref().filter(|(d, _)| *d == dir) {
            let group = group.clone();
            let buffer = self.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("props"), contents: bytemuck::cast_slice(&all), usage: wgpu::BufferUsages::VERTEX });
            self.props = Some((buffer, group, ranges));
            return;
        }
        // The atlas and the detail map are data (linear); the gouache wash is colour (sRGB).
        let atlas = mip_texture(&self.device, &self.queue, "leaf atlas", &props::load_png(&dir.join("botanical_foliage_atlas.png")), wgpu::TextureFormat::Rgba8Unorm);
        let gouache = mip_texture(&self.device, &self.queue, "stone gouache", &props::load_png(&dir.join("gouache_stone_sol61.png")), wgpu::TextureFormat::Rgba8UnormSrgb);
        let detail = mip_texture(&self.device, &self.queue, "stone detail", &props::load_png(&dir.join("stone_detail_spall_v3.png")), wgpu::TextureFormat::Rgba8Unorm);
        let repeat = self.device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("repeat"),
            address_mode_u: wgpu::AddressMode::Repeat,
            address_mode_v: wgpu::AddressMode::Repeat,
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            mipmap_filter: wgpu::MipmapFilterMode::Linear,
            anisotropy_clamp: 8,
            ..Default::default()
        });
        let clamp = self.device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("atlas"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            mipmap_filter: wgpu::MipmapFilterMode::Linear,
            ..Default::default()
        });
        let group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("props"),
            layout: &self.props_bind,
            entries: &[
                view_entry(0, &atlas),
                view_entry(1, &gouache),
                view_entry(2, &detail),
                wgpu::BindGroupEntry { binding: 3, resource: wgpu::BindingResource::Sampler(&repeat) },
                wgpu::BindGroupEntry { binding: 4, resource: wgpu::BindingResource::Sampler(&clamp) },
                wgpu::BindGroupEntry { binding: 5, resource: self.props_materials.as_entire_binding() },
            ],
        });
        self.props_textures = Some((dir, group.clone()));
        let buffer = self.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("props"), contents: bytemuck::cast_slice(&all), usage: wgpu::BufferUsages::VERTEX });
        self.props = Some((buffer, group, ranges));
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

    /// Round k2: uploads an edit's settle map and the prop instances' settle records (settle.rs).
    /// The motion runs while the frame's clock (light slot SETTLE_SLOT) is between 0 and the end.
    pub fn set_settle(&mut self, map: &[crate::settle::Texel], items: &[[f32; 4]]) {
        self.settle_map = self.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("settle map"), contents: bytemuck::cast_slice(map), usage: wgpu::BufferUsages::STORAGE });
        self.settle_items = self.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("settle items"), contents: bytemuck::cast_slice(items), usage: wgpu::BufferUsages::STORAGE });
        self.rebind_globals();
    }

    /// Round k5: everything an edit uploads (scene, props, grass, settle map), made off the frame
    /// loop with only the device (a worker thread); `install` then swaps it in without copying.
    /// Prop textures are kept from the earlier upload (an edit does not change them).
    #[allow(clippy::too_many_arguments)]
    pub fn prepare(device: &wgpu::Device, casters: &[Vertex], rest: &[Vertex], water: &[WaterVertex], library: &props::Library, grass: &Grass, map: &[crate::settle::Texel], items: &[[f32; 4]]) -> Prepared {
        let init = |label: &str, contents: &[u8], usage: wgpu::BufferUsages| device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some(label), contents, usage });
        let (mut low, mut high) = (Vec3::splat(f32::MAX), Vec3::splat(f32::MIN));
        for vertex in casters {
            low = low.min(Vec3::from_array(vertex.pos));
            high = high.max(Vec3::from_array(vertex.pos));
        }
        let total: usize = library.buckets.iter().map(|b| b.len()).sum();
        let props = (total > 0).then(|| {
            let baked = bake_props(library, total);
            low = low.min(baked.bounds.0);
            high = high.max(baked.bounds.1);
            let buffer = init("props", bytemuck::cast_slice(&baked.vertices), wgpu::BufferUsages::VERTEX);
            (buffer, baked.ranges, baked.chunks, baked.table, library.texture_dir.clone().expect("texture folder"))
        });
        Prepared {
            solid: (concat_buffer(device, "solid", &[bytemuck::cast_slice(casters), bytemuck::cast_slice(rest)]), (casters.len() + rest.len()) as u32),
            casters: casters.len() as u32,
            water: (!water.is_empty()).then(|| (init("water", bytemuck::cast_slice(water), wgpu::BufferUsages::VERTEX), water.len() as u32)),
            bounds: (low, high),
            props,
            grass: grass_gpu(device, grass),
            settle: (init("settle map", bytemuck::cast_slice(map), wgpu::BufferUsages::STORAGE), init("settle items", bytemuck::cast_slice(items), wgpu::BufferUsages::STORAGE)),
        }
    }

    /// Round k5: swaps in what `prepare` made (the props' textures must already be loaded).
    pub fn install(&mut self, p: Prepared) {
        self.solid = Some(p.solid);
        self.casters = p.casters;
        self.water = p.water;
        self.bounds = p.bounds;
        match p.props {
            Some((buffer, ranges, chunks, table, dir)) => {
                let (_, group) = self.props_textures.as_ref().filter(|(d, _)| *d == dir).expect("prop textures loaded before install");
                let group = group.clone();
                self.queue.write_buffer(&self.props_materials, 0, bytemuck::cast_slice(&table));
                self.prop_chunks = chunks;
                self.props = Some((buffer, group, ranges));
            }
            None => self.props = None,
        }
        self.grass = p.grass;
        (self.settle_map, self.settle_items) = p.settle;
        self.rebind_globals();
    }

    /// No settle motion: the map is one empty texel and no instance grows.
    pub fn clear_settle(&mut self) {
        let items = vec![[0.0_f32, 0.0, 0.0, -1.0]; 1];
        self.set_settle(&[crate::settle::Texel::default()], &items);
    }

    fn rebind_globals(&mut self) {
        self.globals_group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &self.globals_layout,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: self.globals.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 1, resource: self.settle_map.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 2, resource: self.settle_items.as_entire_binding() },
            ],
        });
    }

    /// Round k2: milliseconds per frame with the camera orbiting as in `bench`, but the shadow map
    /// redrawn every frame (moving geometry); with `cycle` the settle clock runs at 60 frames a
    /// second and wraps at `cycle` seconds, so every frame is part of a motion.
    pub fn bench_settle(&self, frame: &Frame, frames: u32, cycle: Option<f32>) -> f64 {
        self.render(frame);
        self.wait();
        let start = Instant::now();
        for index in 0..frames {
            let mut moved = *frame;
            let turn = glam::Quat::from_rotation_y(index as f32 * 0.012);
            moved.camera.eye = frame.camera.target + turn * (frame.camera.eye - frame.camera.target);
            if let Some(end) = cycle {
                moved.light[SETTLE_SLOT][0] = (index as f32 / 60.0) % end;
            }
            self.write_globals(&moved);
            let mut encoder = self.device.create_command_encoder(&Default::default());
            self.encode(&mut encoder, true, frame.ssao, frame.ssao_blur, &moved.camera, None);
            self.queue.submit([encoder.finish()]);
            if index % 8 == 7 {
                self.wait();
            }
        }
        self.wait();
        start.elapsed().as_secs_f64() * 1000.0 / frames as f64
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

    fn view_proj(&self, camera: &Camera) -> Mat4 {
        let projection = Mat4::perspective_rh(camera.fov_deg.to_radians(), self.width as f32 / self.height as f32, 0.5, 4000.0);
        projection * Mat4::look_at_rh(camera.eye, camera.target, Vec3::Y)
    }

    fn write_globals(&self, frame: &Frame) {
        let (near, far) = (0.5_f32, 4000.0_f32);
        let view_proj = self.view_proj(&frame.camera);
        let mut data = [0.0_f32; GLOBAL_FLOATS];
        data[0..16].copy_from_slice(&view_proj.to_cols_array());
        data[16..32].copy_from_slice(&view_proj.inverse().to_cols_array());
        data[32..48].copy_from_slice(&self.light_matrix(frame.sun_dir).to_cols_array());
        data[48..51].copy_from_slice(&frame.sun_dir.to_array());
        data[52..55].copy_from_slice(&frame.camera.eye.to_array());
        data[56..60].copy_from_slice(&[frame.time, frame.hour, 1.0 / (self.width * self.scale) as f32, 1.0 / (self.height * self.scale) as f32]);
        data[60..64].copy_from_slice(&[near, far, -15.0, self.scale as f32]);
        data[64..68].copy_from_slice(&[if frame.ssao { 1.0 } else { 0.0 }, frame.camera.fov_deg.to_radians(), frame.debug, if self.fxaa.is_some() { 1.0 } else { 0.0 }]);
        for (index, entry) in frame.light.iter().enumerate() {
            data[68 + index * 4..72 + index * 4].copy_from_slice(entry);
        }
        self.queue.write_buffer(&self.globals, 0, bytemuck::cast_slice(&data));
    }

    /// Records one frame; returns the grass triangles drawn (each chunk at the level its
    /// distance from `camera` picks, chunks outside the view skipped).
    fn encode(&self, encoder: &mut wgpu::CommandEncoder, shadow: bool, ssao: bool, blur: bool, camera: &Camera, out: Option<&wgpu::TextureView>) -> GrassDrawn {
        let clear = |view| Some(wgpu::RenderPassColorAttachment { view, depth_slice: None, resolve_target: None, ops: wgpu::Operations { load: wgpu::LoadOp::Clear(wgpu::Color::BLACK), store: wgpu::StoreOp::Store } });
        let depth = |view| Some(wgpu::RenderPassDepthStencilAttachment { view, depth_ops: Some(wgpu::Operations { load: wgpu::LoadOp::Clear(1.0), store: wgpu::StoreOp::Store }), stencil_ops: None });
        let Some((solid, count)) = &self.solid else { return GrassDrawn::default() };
        let mut drawn = GrassDrawn::default();
        if shadow {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("shadow"), color_attachments: &[], depth_stencil_attachment: depth(&self.shadow_view), timestamp_writes: self.ts("shadow"), occlusion_query_set: None, multiview_mask: None });
            pass.set_pipeline(&self.shadow_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_vertex_buffer(0, solid.slice(..));
            pass.draw(0..self.casters, 0..1);
            if let Some((buffer, group, ranges)) = &self.props {
                pass.set_vertex_buffer(0, buffer.slice(..));
                pass.set_pipeline(&self.prop_shadow_pipeline);
                pass.draw(ranges[0].start..ranges[1].end, 0..1);
                pass.set_pipeline(&self.prop_shadow_leaf_pipeline);
                pass.set_bind_group(2, group, &[]);
                pass.draw(ranges[2].clone(), 0..1);
            }
        }
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("terms"),
                color_attachments: &[clear(&self.base_view), clear(&self.terms_view), clear(&self.normal_view)],
                depth_stencil_attachment: depth(&self.depth_view),
                timestamp_writes: self.ts("terms"),
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, &self.terms_group, &[]);
            let visible: Vec<(usize, f32, std::ops::Range<u32>)> = {
                let view_proj = self.view_proj(camera);
                let mut list: Vec<(usize, f32, std::ops::Range<u32>)> = self
                    .prop_chunks
                    .iter()
                    .filter(|(_, _, lo, hi)| !outside(&view_proj, *lo, *hi))
                    .map(|(class, range, lo, hi)| (*class, (camera.eye.clamp(*lo, *hi) - camera.eye).length(), range.clone()))
                    .collect();
                list.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.partial_cmp(&b.1).unwrap()));
                list
            };
            const LEAF: usize = 2;
            let prepass = self.leaf_prepass && self.props.is_some() && !self.skip.contains("leaf");
            // Round r9 (F4): the leaf cards' depth first (nearest chunks first).
            if prepass {
                let (buffer, group, _) = self.props.as_ref().unwrap();
                pass.set_bind_group(2, group, &[]);
                pass.set_vertex_buffer(0, buffer.slice(..));
                pass.set_pipeline(&self.prop_leaf_depth_pipeline);
                for (class, _, range) in &visible {
                    if *class == LEAF {
                        pass.draw(range.clone(), 0..1);
                    }
                }
            }
            pass.set_pipeline(&self.terms_pipeline);
            pass.set_vertex_buffer(0, solid.slice(..));
            pass.draw(0..*count, 0..1);
            // Props before the grass, so the depth test rejects the leaves they hide.
            if let Some((buffer, group, _)) = &self.props {
                pass.set_bind_group(2, group, &[]);
                pass.set_vertex_buffer(0, buffer.slice(..));
                let mut current = usize::MAX;
                for (class, _, range) in visible.into_iter().filter(|v| !(v.0 == LEAF && self.skip.contains("leaf"))) {
                    if class != current {
                        pass.set_pipeline(if class == LEAF && prepass { &self.prop_leaf_shade_pipeline } else { &self.prop_terms_pipelines[class] });
                        current = class;
                    }
                    pass.draw(range, 0..1);
                }
            }
            if let Some(gpu) = self.grass.as_ref().filter(|_| !self.skip.contains("grass")) {
                let view_proj = self.view_proj(camera);
                // Leaf detail per chunk from how wide a leaf is on screen at the chunk's nearest point.
                let focal = self.height as f32 * 0.5 / (camera.fov_deg.to_radians() * 0.5).tan();
                let mut visible: Vec<(f32, usize, u32, u32)> = Vec::new();
                for (lo, hi, first, counts, plo, phi) in &gpu.chunks {
                    if outside(&view_proj, *lo, *hi) {
                        continue;
                    }
                    let distance = (camera.eye.clamp(*lo, *hi) - camera.eye).length().max(0.01);
                    // The level of detail follows the 8 m chunk the part belongs to.
                    let px = grass::LEAF_WIDTH * focal / (camera.eye.clamp(*plo, *phi) - camera.eye).length().max(0.01);
                    let level = grass::LEVEL_PX.iter().filter(|&&t| px < t).count();
                    let n = match level {
                        0 | 1 => counts[0],
                        2 => counts[1],
                        _ => counts[2],
                    };
                    if n > 0 {
                        visible.push((distance, level, *first, n));
                    }
                }
                // Near chunks first, so nearer leaves hide farther ones before they are shaded.
                visible.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
                pass.set_pipeline(&self.grass_pipeline);
                pass.set_vertex_buffer(0, gpu.mesh.slice(..));
                pass.set_vertex_buffer(1, gpu.clumps.slice(..));
                pass.set_index_buffer(gpu.index.slice(..), wgpu::IndexFormat::Uint32);
                for (_, level, first, n) in visible {
                    let (base, range) = gpu.levels[level].clone();
                    drawn.triangles += ((range.end - range.start) / 3) as u64 * n as u64;
                    drawn.chunks[level] += 1;
                    pass.draw_indexed(range, base as i32, first..first + n);
                }
            }
        }
        if ssao {
            let mut steps = vec![("ao depth", &self.aod_pipeline, &self.aod_group, &self.aod_levels[0])];
            if self.scale == 1 {
                // The pyramid is read only in the moving mode (see fs_ssao).
                for k in 1..AOD_MIPS as usize {
                    steps.push(("ao depth down", &self.aod_down_pipeline, &self.aod_down_groups[k - 1], &self.aod_levels[k]));
                }
            }
            steps.push(("ssao", &self.ssao_pipeline, &self.ssao_group, &self.ao_a_view));
            if blur {
                steps.push(("blur h", &self.blur_h_pipeline, &self.blur_h_group, &self.ao_b_view));
                steps.push(("blur v", &self.blur_v_pipeline, &self.blur_v_group, &self.ao_a_view));
            }
            for (label, pipeline, group, view) in steps {
                let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some(label), color_attachments: &[clear(view)], depth_stencil_attachment: None, timestamp_writes: self.ts(label), occlusion_query_set: None, multiview_mask: None });
                pass.set_pipeline(pipeline);
                pass.set_bind_group(0, &self.globals_group, &[]);
                pass.set_bind_group(1, group, &[]);
                pass.draw(0..3, 0..1);
            }
        }
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("far low"), color_attachments: &[clear(&self.far_low_view)], depth_stencil_attachment: None, timestamp_writes: self.ts("far low"), occlusion_query_set: None, multiview_mask: None });
            pass.set_pipeline(&self.far_low_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, &self.far_low_group, &[]);
            pass.draw(0..3, 0..1);
        }
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("resolve"), color_attachments: &[clear(&self.work_view)], depth_stencil_attachment: None, timestamp_writes: self.ts("resolve"), occlusion_query_set: None, multiview_mask: None });
            pass.set_pipeline(&self.resolve_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, &self.resolve_group, &[]);
            pass.draw(0..3, 0..1);
        }
        if let Some((water, count)) = &self.water {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("water"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment { view: &self.water_view, depth_slice: None, resolve_target: None, ops: wgpu::Operations { load: wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT), store: wgpu::StoreOp::Store } })],
                depth_stencil_attachment: None,
                timestamp_writes: self.ts("water"),
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
            let target = out.unwrap_or(&self.final_view);
            let into = self.fxaa.as_ref().map_or(target, |(ldr, _, _)| ldr);
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("down"), color_attachments: &[clear(into)], depth_stencil_attachment: None, timestamp_writes: self.ts("down"), occlusion_query_set: None, multiview_mask: None });
            pass.set_pipeline(&self.down_pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, &self.down_group, &[]);
            pass.draw(0..3, 0..1);
        }
        if let Some((_, pipeline, group)) = &self.fxaa {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor { label: Some("fxaa"), color_attachments: &[clear(out.unwrap_or(&self.final_view))], depth_stencil_attachment: None, timestamp_writes: self.ts("fxaa"), occlusion_query_set: None, multiview_mask: None });
            pass.set_pipeline(pipeline);
            pass.set_bind_group(0, &self.globals_group, &[]);
            pass.set_bind_group(1, group, &[]);
            pass.draw(0..3, 0..1);
        }
        drawn
    }

    pub fn wait(&self) {
        self.device.poll(wgpu::PollType::wait_indefinitely()).expect("poll");
    }

    /// Renders one frame, shadow map included; returns the grass triangles drawn.
    pub fn render(&self, frame: &Frame) -> GrassDrawn {
        self.write_globals(frame);
        let mut encoder = self.device.create_command_encoder(&Default::default());
        let drawn = self.encode(&mut encoder, true, frame.ssao, frame.ssao_blur, &frame.camera, None);
        self.queue.submit([encoder.finish()]);
        drawn
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
            self.encode(&mut encoder, false, frame.ssao, frame.ssao_blur, &moved.camera, None);
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

fn view_entry(binding: u32, view: &wgpu::TextureView) -> wgpu::BindGroupEntry<'_> {
    wgpu::BindGroupEntry { binding, resource: wgpu::BindingResource::TextureView(view) }
}
