// Studies S3 and S4. Stages:
//   terms   : baked geometry -> time-independent shading terms (internal resolution)
//   resolve : terms -> colour: chosen lit and shadow washes, line, mist, backdrop
//   water   : ponds and falls, live, over the resolved picture
//   down    : internal resolution -> output, with paper grain
// The look is steered by `look` (line, flat wash, strokes, grain) and a 16-entry palette per hour.

struct Globals {
    view_proj: mat4x4<f32>,
    inv_view_proj: mat4x4<f32>,
    light_view_proj: mat4x4<f32>,
    sun_dir: vec4<f32>,
    camera_pos: vec4<f32>,
    params: vec4<f32>,   // x time, y hour, z 1/width, w 1/height (internal)
    params2: vec4<f32>,  // x near, y far, z cloud level, w internal pixels per output pixel
    look: vec4<f32>,     // x line, y flat wash, z strokes, w grain
    pal: array<vec4<f32>, 16>,
};
@group(0) @binding(0) var<uniform> g: Globals;

// Palette slots.
const P_SUN: i32 = 0;        // rgb lit tint, a ambient floor
const P_SH_GROUND: i32 = 1;
const P_SH_STONE: i32 = 2;
const P_SH_LEAF: i32 = 3;
const P_SH_WOOD: i32 = 4;
const P_MIST: i32 = 5;       // rgb, a strength of height mist
const P_SKY_TOP: i32 = 6;
const P_SKY_LOW: i32 = 7;
const P_INK: i32 = 8;        // rgb, a opacity
const P_WATER_A: i32 = 9;
const P_WATER_B: i32 = 10;
const P_MOSS: i32 = 11;      // rgb, a amount
const P_CLOUD_A: i32 = 12;
const P_CLOUD_B: i32 = 13;
const P_FAR: i32 = 14;       // rgb distance tint, a density
const P_MISC: i32 = 15;      // x mist start height, y mist full height, z gain

struct VIn {
    @location(0) pos: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) colour: vec4<f32>,
    @location(3) terms: vec4<f32>,
    @location(4) extra: vec4<f32>,
};

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
    @location(4) extra: vec4<f32>,
};

@vertex
fn vs_terms(v: VIn) -> VTerms {
    var out: VTerms;
    out.clip = g.view_proj * vec4<f32>(v.pos, 1.0);
    out.world = v.pos;
    out.normal = v.normal;
    out.colour = v.colour;
    out.terms = v.terms;
    out.extra = v.extra;
    return out;
}

@group(1) @binding(0) var shadow_map: texture_depth_2d;
@group(1) @binding(1) var shadow_sampler: sampler_comparison;

fn sun_visibility(world: vec3<f32>, n: vec3<f32>) -> f32 {
    let p = g.light_view_proj * vec4<f32>(world + n * 0.06, 1.0);
    let uv = vec2<f32>(p.x * 0.5 + 0.5, 0.5 - p.y * 0.5);
    if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0 || p.z >= 1.0) {
        return 1.0;
    }
    let texel = 1.0 / 4096.0;
    let z = p.z - 0.0010;
    var s = 0.0;
    s += textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(-0.75, -0.25) * texel, z);
    s += textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(0.25, -0.75) * texel, z);
    s += textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(0.75, 0.25) * texel, z);
    s += textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(-0.25, 0.75) * texel, z);
    return s * 0.25;
}

// Brushwork (look C): strokes that follow each surface's own structure.
fn brushed(base: vec3<f32>, world: vec3<f32>, n: vec3<f32>, family: f32, weight: f32) -> vec3<f32> {
    var colour = base;
    if (family > 0.17 && family < 0.5) {
        // Stone: broad wash planes and a few long dry strokes down the face.
        var along = cross(n, vec3<f32>(0.0, 1.0, 0.0));
        if (dot(along, along) < 0.02) {
            along = vec3<f32>(1.0, 0.0, 0.0);
        }
        along = normalize(along);
        let u = dot(world, along);
        let plane = vnoise(vec2<f32>(u * 0.33, world.y * 0.22));
        let dry = smoothstep(0.60, 0.72, vnoise(vec2<f32>(u * 3.4, world.y * 0.42))) * vnoise(vec2<f32>(u * 13.0, world.y * 1.7));
        colour = colour * (0.93 + 0.12 * plane) * (1.0 - 0.26 * dry * weight);
    } else if (family >= 0.5 && family < 0.83) {
        // Leaf: dabs.
        let dab = vnoise(world.xz * 5.5 + vec2<f32>(world.y * 3.1, world.y * 1.7));
        colour = colour * (0.90 + 0.22 * smoothstep(0.35, 0.65, dab) * weight);
    } else if (family <= 0.17) {
        // Ground: short soft strokes across the lawn.
        let stroke = vnoise(vec2<f32>(world.x * 2.2 + world.z * 0.9, world.z * 6.5 - world.x * 1.4));
        colour = colour * (0.955 + 0.09 * stroke * weight);
    } else {
        let grain = vnoise(vec2<f32>(world.x * 9.0 + world.z * 7.0, world.y * 1.8));
        colour = colour * (0.90 + 0.18 * grain * weight);
    }
    return colour;
}

struct FTerms {
    @location(0) base: vec4<f32>,
    @location(1) terms: vec4<f32>,
    @location(2) normal: vec4<f32>,
};

@fragment
fn fs_terms(v: VTerms) -> FTerms {
    let n = normalize(v.normal);
    let facing = smoothstep(-0.05, 0.40, dot(n, g.sun_dir.xyz));
    let sun = facing * sun_visibility(v.world, n);
    // Baked occlusion only; how a face in shade turns is decided at resolve time from its normal.
    let sky = v.terms.r;
    var base = v.colour.rgb;
    if (g.look.z > 0.0) {
        base = brushed(base, v.world, n, v.colour.a, v.terms.a * g.look.z);
    }
    var out: FTerms;
    out.base = vec4<f32>(base, v.colour.a);
    out.terms = vec4<f32>(sun, sky, v.terms.b, v.extra.g);
    out.normal = vec4<f32>(n * 0.5 + 0.5, v.extra.r);
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

// Mist and distance, shared by every surface: the root dissolves by height, far things pale.
fn atmosphere(colour: vec3<f32>, world: vec3<f32>, distance: f32) -> vec3<f32> {
    let far = (1.0 - exp(-distance * g.pal[P_FAR].a)) * 0.9;
    var result = mix(colour, g.pal[P_FAR].rgb, far);
    let low = smoothstep(g.pal[P_MISC].x, g.pal[P_MISC].y, world.y) * g.pal[P_MIST].a;
    result = mix(result, g.pal[P_MIST].rgb, low);
    return result;
}

fn backdrop(ray: vec3<f32>) -> vec3<f32> {
    var colour = mix(g.pal[P_SKY_LOW].rgb, g.pal[P_SKY_TOP].rgb, smoothstep(0.0, 0.5, ray.y));
    if (ray.y < -0.004) {
        // The cloud sea: reserved paper with soft, slow billows.
        let t = (g.params2.z - g.camera_pos.y) / ray.y;
        let p = g.camera_pos.xz + ray.xz * t;
        let drift = vec2<f32>(g.params.x * 0.5, g.params.x * 0.2);
        // Long soft banks, stretched along one direction like drawn cloud bands.
        let q = vec2<f32>(p.x * 0.8 + p.y * 0.6, (p.y * 0.8 - p.x * 0.6) * 2.4);
        var n = vnoise(q * 0.014 + drift * 0.01) * 0.45;
        n += vnoise(q * 0.034 - drift * 0.016) * 0.33;
        n += vnoise(q * 0.085 + drift * 0.02) * 0.22;
        let billow = smoothstep(0.34, 0.60, n);
        let rim = smoothstep(0.44, 0.50, n) * (1.0 - smoothstep(0.50, 0.60, n));
        var cloud = mix(g.pal[P_CLOUD_B].rgb, g.pal[P_CLOUD_A].rgb, billow);
        cloud = mix(cloud, g.pal[P_CLOUD_A].rgb * 1.03, rim * 0.5);
        colour = mix(cloud, g.pal[P_SKY_LOW].rgb, 1.0 - exp(-t * 0.0009));
    }
    return colour;
}

// ---------------------------------------------------------------- resolve pass

@group(1) @binding(0) var t_base: texture_2d<f32>;
@group(1) @binding(1) var t_terms: texture_2d<f32>;
@group(1) @binding(2) var t_normal: texture_2d<f32>;
@group(1) @binding(3) var t_depth: texture_depth_2d;

fn shadow_wash(family: f32) -> vec3<f32> {
    if (family < 0.17) { return g.pal[P_SH_GROUND].rgb; }
    if (family < 0.50) { return g.pal[P_SH_STONE].rgb; }
    if (family < 0.83) { return g.pal[P_SH_LEAF].rgb; }
    return g.pal[P_SH_WOOD].rgb;
}

// Breaks in depth, normal and surface id against four neighbours at `reach` pixels.
fn line_at(px: vec2<i32>, reach: i32, c: f32, n: vec3<f32>, id: f32, importance: f32) -> f32 {
    var offsets = array<vec2<i32>, 4>(vec2<i32>(-reach, 0), vec2<i32>(reach, 0), vec2<i32>(0, -reach), vec2<i32>(0, reach));
    var depth_sum = 0.0;
    var normal_min = 1.0;
    var id_break = 0.0;
    for (var i = 0; i < 4; i++) {
        let q = px + offsets[i];
        depth_sum += view_distance(textureLoad(t_depth, q, 0));
        let other = textureLoad(t_normal, q, 0);
        normal_min = min(normal_min, dot(n, other.xyz * 2.0 - 1.0));
        id_break = max(id_break, step(0.5 / 255.0, abs(other.a - id)));
    }
    let depth_break = smoothstep(0.004, 0.02, abs(depth_sum - 4.0 * c) / c);
    // Folds of about fifteen degrees already draw a faint line; sharp arrises a full one.
    let normal_break = smoothstep(0.035, 0.30, 1.0 - normal_min);
    return max(depth_break, max(normal_break, id_break * 0.85) * importance);
}

@fragment
fn fs_resolve(v: VFull) -> @location(0) vec4<f32> {
    let px = vec2<i32>(v.pos.xy);
    let depth = textureLoad(t_depth, px, 0);
    let ray = normalize(world_at(v.uv, 1.0) - g.camera_pos.xyz);
    var colour: vec3<f32>;
    if (depth >= 1.0) {
        colour = backdrop(ray);
    } else {
        let base = textureLoad(t_base, px, 0);
        let terms = textureLoad(t_terms, px, 0);
        let packed = textureLoad(t_normal, px, 0);
        let n = packed.xyz * 2.0 - 1.0;
        let family = base.a;
        let c = view_distance(depth);
        let world = world_at(v.uv, depth);

        // Flat washes: the sun term is gathered into two tones (three on foliage) with soft edges.
        var banded = smoothstep(0.28, 0.50, terms.r);
        if (family >= 0.5 && family < 0.83) {
            banded = 0.5 * smoothstep(0.16, 0.30, terms.r) + 0.5 * smoothstep(0.56, 0.70, terms.r);
        }
        let sun = mix(terms.r, banded, g.look.y);

        var albedo = base.rgb;
        if (family > 0.17 && family < 0.5) {
            // Moss creeps over the top of a rock face.
            let moss = g.pal[P_MOSS].a * (1.0 - smoothstep(0.0, 0.20, terms.a)) * step(terms.a, 0.4);
            albedo = mix(albedo, g.pal[P_MOSS].rgb, moss);
        }
        let lit = albedo * g.pal[P_SUN].rgb;
        // In shade a face is one of two washes: a half-light where it turns to the open sky or to
        // the fill from across the sun, a core shadow where it turns away from both.
        let fill_dir = normalize(vec3<f32>(-g.sun_dir.x, 0.50, -g.sun_dir.z));
        let turn = 0.40 * (0.5 + 0.5 * n.y) + 0.60 * max(dot(n, fill_dir), 0.0);
        let half_light = mix(smoothstep(0.10, 0.70, turn), smoothstep(0.30, 0.44, turn), g.look.y);
        let wash = shadow_wash(family);
        let shade = albedo * mix(wash * 0.80, mix(wash, vec3<f32>(1.0), 0.30), half_light);
        colour = mix(shade, lit, sun) * mix(g.pal[P_SUN].a, 1.0, terms.g) * g.pal[P_MISC].z;

        // Line: heavier on silhouettes, lighter on inner creases, fading with distance.
        if (g.look.x > 0.0) {
            let scale = i32(g.params2.w);
            let fine = line_at(px, scale, c, n, packed.a, terms.b);
            let wide = line_at(px, scale * 2, c, n, packed.a, terms.b);
            let line = clamp(0.80 * fine + 0.50 * wide, 0.0, 1.0);
            let fade = exp(-c * g.pal[P_FAR].a * 1.4);
            // Ink takes the hue of what it draws: green on grass and leaves, warm grey on stone and wood.
            var ink = g.pal[P_INK].rgb;
            if (family < 0.17) {
                ink = mix(ink, shade * 0.55, 0.75);
            } else if (family >= 0.5 && family < 0.83) {
                ink = mix(ink, shade * 0.50, 0.55);
            }
            colour = mix(colour, ink, line * g.pal[P_INK].a * g.look.x * fade);
        }
        colour = atmosphere(colour, world, c);
    }
    return vec4<f32>(colour, 1.0);
}

// ---------------------------------------------------------------- water pass

struct VWater {
    @builtin(position) clip: vec4<f32>,
    @location(0) world: vec3<f32>,
    @location(1) data: vec3<f32>,
};

@vertex
fn vs_water(@location(0) pos: vec3<f32>, @location(1) data: vec3<f32>) -> VWater {
    var out: VWater;
    out.clip = g.view_proj * vec4<f32>(pos, 1.0);
    out.world = pos;
    out.data = data;
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
    let t = g.params.x;
    let distance = view_distance(v.clip.z);
    var colour: vec3<f32>;
    var alpha: f32;
    if (v.data.x < 0.5) {
        let thickness = view_distance(scene) - distance;
        let deep = clamp(thickness * 0.75, 0.0, 1.0);
        colour = mix(g.pal[P_WATER_A].rgb, g.pal[P_WATER_B].rgb, deep);
        // Fine drawn ripples: level lines of two slow fields.
        let field = vnoise(v.world.xz * 0.9 + vec2<f32>(t * 0.05, t * 0.02)) + 0.5 * vnoise(v.world.xz * 2.1 - vec2<f32>(t * 0.04, t * 0.06));
        let lines = 1.0 - smoothstep(0.0, 0.06, abs(fract(field * 5.0) - 0.5));
        colour = mix(colour, g.pal[P_CLOUD_A].rgb, lines * 0.22 * g.look.x + lines * 0.08);
        let to_eye = normalize(g.camera_pos.xyz - v.world);
        colour = mix(colour, g.pal[P_SKY_LOW].rgb, pow(1.0 - clamp(to_eye.y, 0.0, 1.0), 3.0) * 0.45);
        // A pale edge where the water thins at the bank.
        let edge = 1.0 - smoothstep(0.0, 0.10, thickness);
        colour = mix(colour, g.pal[P_CLOUD_A].rgb, edge * 0.7);
        alpha = clamp(0.62 + thickness * 0.9, 0.62, 0.94);
    } else {
        let drop = v.data.z;
        let streak = vnoise(vec2<f32>(v.data.y * 7.0, sqrt(drop + 0.05) * 3.2 - t * 1.6)) * 0.6 + vnoise(vec2<f32>(v.data.y * 19.0, sqrt(drop + 0.05) * 6.0 - t * 2.6)) * 0.4;
        let white = smoothstep(0.34, 0.70, streak + clamp(drop * 0.05, 0.0, 0.25));
        let glass = 1.0 - smoothstep(0.0, 0.5, drop);
        colour = mix(mix(g.pal[P_WATER_A].rgb, g.pal[P_CLOUD_A].rgb, 0.45), vec3<f32>(0.97, 0.98, 0.97) * g.pal[P_CLOUD_A].rgb / max(g.pal[P_CLOUD_A].r, 0.01), white);
        colour = mix(colour, g.pal[P_WATER_A].rgb, glass * 0.6);
        alpha = mix(0.50, 0.95, white);
    }
    colour = atmosphere(colour, v.world, distance);
    // Falls vanish into the cloud sea rather than ending on a line.
    let sink = smoothstep(g.pal[P_MISC].x - 1.0, g.pal[P_MISC].y, v.world.y);
    return vec4<f32>(colour, alpha * (1.0 - sink * 0.95));
}

// ---------------------------------------------------------------- downsample and paper

@group(1) @binding(0) var t_full: texture_2d<f32>;

@fragment
fn fs_down(v: VFull) -> @location(0) vec4<f32> {
    let scale = i32(g.params2.w);
    let px = vec2<i32>(v.pos.xy) * scale;
    var sum = vec3<f32>(0.0);
    for (var y = 0; y < scale; y++) {
        for (var x = 0; x < scale; x++) {
            sum += textureLoad(t_full, px + vec2<i32>(x, y), 0).rgb;
        }
    }
    var colour = sum / f32(scale * scale);
    // Paper: a faint fibre and a fine tooth, multiplied so it never lifts the darks.
    let fibre = vnoise(v.pos.xy * vec2<f32>(0.09, 0.55)) - 0.5;
    let tooth = hash21(v.pos.xy) - 0.5;
    colour = colour * (1.0 + (fibre * 0.030 + tooth * 0.018) * g.look.w);
    return vec4<f32>(colour, 1.0);
}
