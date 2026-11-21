// Spike S2 shaders. Three stages, matching the plan's frame paths:
//   terms   : the island drawn from its bake into time-independent shading terms
//   resolve : terms -> colour with the hour's palette, line, mist, sky and cloud sea
//   water   : live pond surfaces over the resolved picture
// The Moving path runs all three every frame; the Still path runs resolve and water only.

struct Globals {
    view_proj: mat4x4<f32>,
    inv_view_proj: mat4x4<f32>,
    light_view_proj: mat4x4<f32>,
    sun_dir: vec4<f32>,
    camera_pos: vec4<f32>,
    params: vec4<f32>,   // x time, y hour (0..1), z 1/width, w 1/height
    params2: vec4<f32>,  // x near, y far
};
@group(0) @binding(0) var<uniform> g: Globals;

struct VIn {
    @location(0) pos: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) colour: vec4<f32>,
    @location(3) terms: vec4<f32>,
};

// ---------------------------------------------------------------- shadow map

@vertex
fn vs_shadow(v: VIn) -> @builtin(position) vec4<f32> {
    return g.light_view_proj * vec4<f32>(v.pos, 1.0);
}

// ---------------------------------------------------------------- terms pass

struct VTerms {
    @builtin(position) clip: vec4<f32>,
    @location(0) world: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) colour: vec4<f32>,
    @location(3) terms: vec4<f32>,
};

@vertex
fn vs_terms(v: VIn) -> VTerms {
    var out: VTerms;
    out.clip = g.view_proj * vec4<f32>(v.pos, 1.0);
    out.world = v.pos;
    out.normal = v.normal;
    out.colour = v.colour;
    out.terms = v.terms;
    return out;
}

@group(1) @binding(0) var shadow_map: texture_depth_2d;
@group(1) @binding(1) var shadow_sampler: sampler_comparison;

fn sun_visibility(world: vec3<f32>, n: vec3<f32>) -> f32 {
    let p = g.light_view_proj * vec4<f32>(world + n * 0.10, 1.0);
    let uv = vec2<f32>(p.x * 0.5 + 0.5, 0.5 - p.y * 0.5);
    let texel = 1.0 / 4096.0;
    let z = p.z - 0.0012;
    var s = textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(-0.6, -0.6) * texel, z);
    s += textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(0.6, -0.6) * texel, z);
    s += textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(-0.6, 0.6) * texel, z);
    s += textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(0.6, 0.6) * texel, z);
    return s * 0.25;
}

struct FTerms {
    @location(0) base: vec4<f32>,
    @location(1) terms: vec4<f32>,
    @location(2) normal: vec4<f32>,
};

@fragment
fn fs_terms(v: VTerms) -> FTerms {
    let n = normalize(v.normal);
    let facing = smoothstep(-0.10, 0.45, dot(n, g.sun_dir.xyz));
    let sun = facing * sun_visibility(v.world, n);
    let sky = v.terms.r * (0.55 + 0.45 * n.y);
    var out: FTerms;
    out.base = v.colour;
    out.terms = vec4<f32>(sun, sky, v.terms.g, v.terms.b);
    out.normal = vec4<f32>(n * 0.5 + 0.5, 1.0);
    return out;
}

// ---------------------------------------------------------------- shared helpers

struct VFull {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

@vertex
fn vs_full(@builtin(vertex_index) index: u32) -> VFull {
    var out: VFull;
    let x = f32((index << 1u) & 2u);
    let y = f32(index & 2u);
    out.uv = vec2<f32>(x, y);
    out.pos = vec4<f32>(x * 2.0 - 1.0, 1.0 - y * 2.0, 0.0, 1.0);
    return out;
}

fn world_at(uv: vec2<f32>, depth: f32) -> vec3<f32> {
    let w = g.inv_view_proj * vec4<f32>(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, depth, 1.0);
    return w.xyz / w.w;
}

fn view_distance(depth: f32) -> f32 {
    let near = g.params2.x;
    let far = g.params2.y;
    return near * far / (far - depth * (far - near));
}

fn hash21(p: vec2<f32>) -> f32 {
    let q = fract(p * vec2<f32>(0.1031, 0.1030));
    let r = q + dot(q, q.yx + 33.33);
    return fract((r.x + r.y) * r.x);
}

fn vnoise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let s = f * f * (3.0 - 2.0 * f);
    let a = hash21(i);
    let b = hash21(i + vec2<f32>(1.0, 0.0));
    let c = hash21(i + vec2<f32>(0.0, 1.0));
    let d = hash21(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, s.x), mix(c, d, s.x), s.y);
}

const MIST: vec3<f32> = vec3<f32>(0.86, 0.85, 0.80);

fn sky_colour(ray: vec3<f32>) -> vec3<f32> {
    let high = vec3<f32>(0.60, 0.70, 0.76);
    var colour = mix(MIST, high, smoothstep(0.0, 0.55, ray.y));
    if (ray.y < -0.01) {
        // Cloud sea: a plane well below the islands, three octaves of drifting noise.
        let t = (-14.0 - g.camera_pos.y) / ray.y;
        let p = g.camera_pos.xz + ray.xz * t;
        let drift = vec2<f32>(g.params.x * 0.6, g.params.x * 0.25);
        var n = vnoise(p * 0.012 + drift * 0.012) * 0.55;
        n += vnoise(p * 0.031 - drift * 0.02) * 0.30;
        n += vnoise(p * 0.083 + drift * 0.03) * 0.15;
        let cloud = mix(vec3<f32>(0.74, 0.77, 0.78), vec3<f32>(0.95, 0.94, 0.90), smoothstep(0.35, 0.75, n));
        colour = mix(cloud, MIST, 1.0 - exp(-t * 0.0022));
    }
    return colour;
}

// ---------------------------------------------------------------- resolve pass

@group(1) @binding(0) var t_base: texture_2d<f32>;
@group(1) @binding(1) var t_terms: texture_2d<f32>;
@group(1) @binding(2) var t_normal: texture_2d<f32>;
@group(1) @binding(3) var t_depth: texture_depth_2d;

fn shadow_tint(family: f32) -> vec3<f32> {
    // Chosen shadow colours per material family: ground, stone, leaf, built.
    if (family < 0.17) { return vec3<f32>(0.50, 0.62, 0.64); }
    if (family < 0.50) { return vec3<f32>(0.52, 0.58, 0.72); }
    if (family < 0.83) { return vec3<f32>(0.42, 0.58, 0.56); }
    return vec3<f32>(0.55, 0.60, 0.70);
}

@fragment
fn fs_resolve(v: VFull) -> @location(0) vec4<f32> {
    let px = vec2<i32>(v.pos.xy);
    let depth = textureLoad(t_depth, px, 0);
    let ray = normalize(world_at(v.uv, 1.0) - g.camera_pos.xyz);
    var colour: vec3<f32>;
    if (depth >= 1.0) {
        colour = sky_colour(ray);
    } else {
        let base = textureLoad(t_base, px, 0);
        let terms = textureLoad(t_terms, px, 0);
        let n = textureLoad(t_normal, px, 0).xyz * 2.0 - 1.0;

        // Palette: lit and shadow colours are chosen, the terms pick between them.
        let warm = mix(vec3<f32>(1.02, 0.96, 0.90), vec3<f32>(1.10, 1.02, 0.88), g.params.y);
        let lit = base.rgb * warm;
        let shade = base.rgb * shadow_tint(base.a);
        colour = mix(shade, lit, terms.r) * (0.58 + 0.42 * terms.g) + base.rgb * terms.b * 0.06 * (1.0 - terms.r);

        // Line: depth and normal breaks against the four neighbours.
        let c = view_distance(depth);
        let dl = view_distance(textureLoad(t_depth, px + vec2<i32>(-1, 0), 0));
        let dr = view_distance(textureLoad(t_depth, px + vec2<i32>(1, 0), 0));
        let du = view_distance(textureLoad(t_depth, px + vec2<i32>(0, -1), 0));
        let dd = view_distance(textureLoad(t_depth, px + vec2<i32>(0, 1), 0));
        let depth_break = abs(dl + dr + du + dd - 4.0 * c) / c;
        let nl = textureLoad(t_normal, px + vec2<i32>(-1, 0), 0).xyz * 2.0 - 1.0;
        let nr = textureLoad(t_normal, px + vec2<i32>(1, 0), 0).xyz * 2.0 - 1.0;
        let nu = textureLoad(t_normal, px + vec2<i32>(0, -1), 0).xyz * 2.0 - 1.0;
        let nd = textureLoad(t_normal, px + vec2<i32>(0, 1), 0).xyz * 2.0 - 1.0;
        let normal_break = 1.0 - min(min(dot(n, nl), dot(n, nr)), min(dot(n, nu), dot(n, nd)));
        let line = max(smoothstep(0.006, 0.03, depth_break), smoothstep(0.25, 0.7, normal_break) * terms.a);
        let ink = vec3<f32>(0.24, 0.22, 0.20);
        colour = mix(colour, ink, line * 0.75);

        // Mist: the root dissolves by height, distance pales.
        let world = world_at(v.uv, depth);
        let by_height = smoothstep(-2.0, -9.5, world.y) * 0.92;
        let by_distance = (1.0 - exp(-c * 0.0022)) * 0.6;
        colour = mix(colour, MIST, max(by_height, by_distance));
    }
    colour += (hash21(v.pos.xy) - 0.5) / 255.0;
    return vec4<f32>(colour, 1.0);
}

// ---------------------------------------------------------------- water pass

struct VWater {
    @builtin(position) clip: vec4<f32>,
    @location(0) world: vec3<f32>,
};

@vertex
fn vs_water(@location(0) pos: vec3<f32>) -> VWater {
    var out: VWater;
    out.clip = g.view_proj * vec4<f32>(pos, 1.0);
    out.world = pos;
    return out;
}

@group(1) @binding(0) var w_depth: texture_depth_2d;

@fragment
fn fs_water(v: VWater) -> @location(0) vec4<f32> {
    let px = vec2<i32>(v.clip.xy);
    let scene = textureLoad(w_depth, px, 0);
    if (v.clip.z > scene) {
        discard;
    }
    let thickness = view_distance(scene) - view_distance(v.clip.z);
    let t = g.params.x;
    let ripple = vnoise(v.world.xz * 1.7 + vec2<f32>(t * 0.30, t * 0.11)) - vnoise(v.world.xz * 2.3 - vec2<f32>(t * 0.17, t * 0.26));
    let glint = smoothstep(0.02, 0.0, abs(ripple)) * 0.35;
    let to_eye = normalize(g.camera_pos.xyz - v.world);
    let sheen = pow(1.0 - clamp(to_eye.y, 0.0, 1.0), 3.0) * 0.5;
    let jade = mix(vec3<f32>(0.40, 0.66, 0.58), vec3<f32>(0.17, 0.38, 0.37), clamp(thickness * 0.9, 0.0, 1.0));
    let colour = mix(jade, vec3<f32>(0.80, 0.86, 0.86), sheen) + vec3<f32>(glint);
    return vec4<f32>(colour, clamp(0.45 + thickness * 0.6, 0.45, 0.92));
}
