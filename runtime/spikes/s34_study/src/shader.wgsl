// Studies S3 and S4, look N (natural light). Stages:
//   shadow  : sun depth map (cached while the camera moves); props cast too, leaf cards cut out
//   terms   : baked geometry and props -> display albedo, soft sun visibility, normal, ids (internal resolution)
//   ao depth: view distance of one internal sample per output pixel (output resolution)
//   ssao    : screen-space occlusion from depth and normal (output resolution)
//   blur    : depth-aware blur of the occlusion, horizontal then vertical (output resolution)
//   resolve : linear light (sun, sky/ground hemisphere, fill), backdrop (sky, cloud sea), haze;
//             occlusion upsampled with depth awareness (internal resolution)
//   water   : ponds, falls and mist, live, premultiplied over the resolved picture (linear)
//   down    : box filter in linear -> exposure -> filmic tone curve -> sRGB encode (once)
//   fxaa    : optional edge filter on the display values (meant for --scale=1)
// Vertex colours are authored as display values and decoded to linear here. The light set
// (`pal`) is uploaded in linear radiance; slots are named below and filled in main.rs.

struct Globals {
    view_proj: mat4x4<f32>,
    inv_view_proj: mat4x4<f32>,
    light_view_proj: mat4x4<f32>,
    sun_dir: vec4<f32>,
    camera_pos: vec4<f32>,
    params: vec4<f32>,   // x time, y hour, z 1/width, w 1/height (internal)
    params2: vec4<f32>,  // x near, y far, z cloud level, w internal pixels per output pixel
    look: vec4<f32>,     // x ssao on, y fov (radians), z, w spare
    pal: array<vec4<f32>, 20>,
};
@group(0) @binding(0) var<uniform> g: Globals;

// Light set slots (linear).
const L_SUN: i32 = 0;          // rgb sun colour x energy, a shadow opacity
const L_FILL: i32 = 1;         // rgb fill colour x energy
const L_FILL_DIR: i32 = 2;     // xyz toward the fill light
const L_SKY: i32 = 3;          // rgb sky ambient (normal up) x ambient energy
const L_GROUND: i32 = 4;       // rgb ground bounce (normal down) x ambient energy
const L_TONE: i32 = 5;         // x exposure, y white, z contrast, w saturation
const L_ZENITH: i32 = 6;       // sky radiance overhead
const L_HAZE: i32 = 7;         // sky radiance at the horizon, also the far haze
const L_GLOW: i32 = 8;         // rgb sun glow in the sky, a width exponent
const L_CLOUD_LIT: i32 = 9;
const L_CLOUD_SHADE: i32 = 10;
const L_FOG: i32 = 11;         // rgb, a density per metre
const L_MISC: i32 = 12;        // x root mist start height, y full height, z ssao intensity, w ssao power
const L_WATER_SHALLOW: i32 = 13;
const L_WATER_DEEP: i32 = 14;
const L_MOSS: i32 = 15;        // display rgb, a amount
const L_FAR: i32 = 16;         // a far-haze density per metre beyond 80 m
const L_MIST: i32 = 17;        // rgb foam and spray albedo (linear), a root mist strength
const L_FALL: i32 = 18;        // rgb waterfall body tint (linear)
const L_SSR: i32 = 19;         // x pond reflections on (1) or off (0)

const TAU: f32 = 6.2831853;

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

// Interleaved gradient noise: a per-pixel rotation that averages out over a few pixels.
fn ign(p: vec2<f32>) -> f32 {
    return fract(52.9829189 * fract(dot(p, vec2<f32>(0.06711056, 0.00583715))));
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

fn to_linear(c: vec3<f32>) -> vec3<f32> {
    let lo = c / 12.92;
    let hi = pow((c + 0.055) / 1.055, vec3<f32>(2.4));
    return select(hi, lo, c <= vec3<f32>(0.04045));
}

fn to_display(c: vec3<f32>) -> vec3<f32> {
    let lo = c * 12.92;
    let hi = 1.055 * pow(c, vec3<f32>(1.0 / 2.4)) - 0.055;
    return select(hi, lo, c <= vec3<f32>(0.0031308));
}

// Godot 4's filmic curve (exposure bias 2 folded into A and B).
fn filmic(x: vec3<f32>) -> vec3<f32> {
    let a = 0.88;
    let b = 0.60;
    let c = 0.10;
    let d = 0.20;
    let e = 0.01;
    let f = 0.30;
    return ((x * (a * x + c * b) + d * e) / (x * (a * x + b) + d * f)) - e / f;
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

// Soft sun visibility: `taps` bilinear PCF taps (16 for surfaces, 6 for grass blades, whose busy
// texture hides the extra noise) on a Vogel disc of radius 3 texels, rotated per pixel.
fn sun_visibility_taps(world: vec3<f32>, n: vec3<f32>, pixel: vec2<f32>, taps: i32) -> f32 {
    let p = g.light_view_proj * vec4<f32>(world + n * 0.06, 1.0);
    let uv = vec2<f32>(p.x * 0.5 + 0.5, 0.5 - p.y * 0.5);
    if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0 || p.z >= 1.0) {
        return 1.0;
    }
    let texel = 1.0 / 4096.0;
    let z = p.z - 0.0010;
    let spin = ign(pixel) * TAU;
    var s = 0.0;
    let count = f32(taps);
    for (var i = 0; i < taps; i++) {
        let r = sqrt((f32(i) + 0.5) / count) * 3.0;
        let a = f32(i) * 2.3999632 + spin;
        s += textureSampleCompareLevel(shadow_map, shadow_sampler, uv + vec2<f32>(cos(a), sin(a)) * r * texel, z);
    }
    return s / count;
}

fn sun_visibility(world: vec3<f32>, n: vec3<f32>, pixel: vec2<f32>) -> f32 {
    return sun_visibility_taps(world, n, pixel, 16);
}

struct FTerms {
    @location(0) base: vec4<f32>,
    @location(1) terms: vec4<f32>,
    @location(2) normal: vec4<f32>,
};

@group(1) @binding(2) var stone_wash: texture_2d<f32>;
@group(1) @binding(3) var wash_sampler: sampler;

// The gouache wash (gouache_stone_sol61, sampled in linear) projected from three sides, with
// explicit gradients so it can run inside the stone branch. 2.2 is Godot's mip bias of 1.15.
fn wash3(p: vec3<f32>, w: vec3<f32>, s: f32, o: vec2<f32>, dx: vec3<f32>, dy: vec3<f32>) -> vec3<f32> {
    let k = s * 2.2;
    return textureSampleGrad(stone_wash, wash_sampler, p.zy * s + o, dx.zy * k, dy.zy * k).rgb * w.x
        + textureSampleGrad(stone_wash, wash_sampler, p.xz * s + o, dx.xz * k, dy.xz * k).rgb * w.y
        + textureSampleGrad(stone_wash, wash_sampler, p.xy * s + o, dx.xy * k, dy.xy * k).rgb * w.z;
}

fn wash_at(uv: vec2<f32>, du: vec2<f32>, dv: vec2<f32>) -> vec3<f32> {
    return textureSampleGrad(stone_wash, wash_sampler, uv, du * 2.2, dv * 2.2).rgb;
}

// Linear statistics of the wash: channel means and their luminance (Godot's figures).
const WASH_MEAN_LUM: f32 = 0.4458;
const WASH_CHROMA: vec3<f32> = vec3<f32>(1.119, 1.016, 0.865);
const WASH_SPREAD: f32 = 0.046;

// The island stone's paint as a multiplier on its display colour: a calm triplanar wash (large
// brush planes, a few per cent of value and a quiet warm/cool drift), the wash pulled about 3:1
// along gravity on steep faces and gathered into flat values, and faint dry streaks pulled about
// 6:1. A broad "voice" field lets parts of every face rest. All world anchored (after Godot's
// stone_surface and stone_cliff_character). Mip filtering turns all of it into one soft tone
// with a hint of brushwork at a distance.
fn stone_paint(p: vec3<f32>, n: vec3<f32>, dx: vec3<f32>, dy: vec3<f32>) -> vec3<f32> {
    let w = stone_weights(n);
    let q = p * 0.82;
    let wash = mix(wash3(q, w, 0.11, vec2<f32>(0.0), dx * 0.82, dy * 0.82), wash3(q, w, 0.26, vec2<f32>(0.37, 0.61), dx * 0.82, dy * 0.82), 0.38);
    let lum = dot(wash, vec3<f32>(1.0 / 3.0));
    var f = vec3<f32>(1.0 + clamp((lum / WASH_MEAN_LUM - 1.0) * 0.6, -0.02, 0.02));
    f *= mix(vec3<f32>(1.0), clamp(wash / max(lum, 0.02) / WASH_CHROMA, vec3<f32>(0.97), vec3<f32>(1.03)), 0.4);
    let steep = 1.0 - smoothstep(0.50, 0.82, abs(n.y));
    if (steep > 0.001) {
        var h = abs(n.xz);
        h /= max(h.x + h.y, 0.001);
        let plane = wash_at(vec2<f32>(p.z * 0.085 + 0.21, p.y * 0.030), vec2<f32>(dx.z * 0.085, dx.y * 0.030), vec2<f32>(dy.z * 0.085, dy.y * 0.030)) * h.x
            + wash_at(vec2<f32>(p.x * 0.085 + 0.63, p.y * 0.030 + 0.37), vec2<f32>(dx.x * 0.085, dx.y * 0.030), vec2<f32>(dy.x * 0.085, dy.y * 0.030)) * h.y;
        let plane_lum = dot(plane, vec3<f32>(1.0 / 3.0));
        let tone = clamp((plane_lum - WASH_MEAN_LUM) / WASH_SPREAD, -1.0, 1.0);
        let value = smoothstep(-0.55, 0.55, tone) * 2.0 - 1.0;
        let voice = smoothstep(0.28, 0.64, stone_noise(p * vec3<f32>(0.10, 0.065, 0.10) + vec3<f32>(4.7, 1.3, 9.2)));
        let amount = steep * mix(0.45, 1.0, voice);
        f *= 1.0 + value * 0.025 * amount;
        let stroke = wash_at(vec2<f32>(p.z * 0.048 + 0.52, p.y * 0.0085 + 0.11), vec2<f32>(dx.z * 0.048, dx.y * 0.0085), vec2<f32>(dy.z * 0.048, dy.y * 0.0085)).g * h.x
            + wash_at(vec2<f32>(p.x * 0.048 + 0.08, p.y * 0.0085 + 0.71), vec2<f32>(dx.x * 0.048, dx.y * 0.0085), vec2<f32>(dy.x * 0.048, dy.y * 0.0085)).g * h.y;
        let dry = smoothstep(WASH_MEAN_LUM - WASH_SPREAD * 0.45, WASH_MEAN_LUM - WASH_SPREAD * 1.25, stroke);
        f *= 1.0 - dry * 0.035 * steep * mix(0.25, 1.0, voice);
    }
    return f;
}

@fragment
fn fs_terms(v: VTerms) -> FTerms {
    let n = normalize(v.normal);
    let dx = dpdx(v.world);
    let dy = dpdy(v.world);
    var vis = 1.0;
    if (dot(n, g.sun_dir.xyz) > -0.05) {
        vis = sun_visibility(v.world, n, v.clip.xy);
    }
    var display = v.colour.rgb;
    var ao = v.terms.r;
    var brow = 0.0;
    if (abs(v.colour.a - 85.0 / 255.0) < 0.05) {
        // Island stone: painted surface, mossy brow under the lawn lip, darker joins and lip band.
        display *= stone_paint(v.world, n, dx, dy);
        let steep = 1.0 - smoothstep(0.50, 0.82, abs(n.y));
        let raw = round(v.extra.b * 255.0) * 256.0 + round(v.extra.a * 255.0);
        if (raw > 0.5) {
            let depth = raw / 65535.0 * 64.0 - 32.0 - v.world.y;
            let below = step(-0.08, depth);
            let reach = mix(0.30, 0.50, stone_noise(vec3<f32>(v.world.x * 0.38, 5.3, v.world.z * 0.38)));
            brow = (1.0 - smoothstep(reach * 0.35, reach, depth)) * below * steep;
            ao *= 1.0 - 0.24 * (1.0 - smoothstep(0.0, 0.32, max(depth, 0.0))) * below * steep;
        }
        let width = v.terms.a * 16.0;
        if (width > 0.05) {
            let along = clamp(v.terms.g, 0.0, 1.0);
            ao *= mix(0.80, 1.0, smoothstep(0.05, 0.55, min(along, 1.0 - along) * width));
        }
    }
    var out: FTerms;
    out.base = vec4<f32>(display, v.colour.a);
    if (abs(v.extra.r * 255.0 - 20.0) < 0.5) {
        brow = v.extra.g; // a far mound: how far below its crest, for the resolve's fade
    }
    // r sun visibility, g baked sky occlusion, b spare, a mossy brow (stone) or crest depth (mounds)
    out.terms = vec4<f32>(vis, ao, v.terms.b, brow);
    out.normal = vec4<f32>(n * 0.5 + 0.5, v.extra.r);
    return out;
}

// ---------------------------------------------------------------- grass field

struct GIn {
    @location(0) pos: vec3<f32>,
    @location(1) normal: vec4<f32>,
    @location(2) colour: vec4<f32>,
};

struct VGrass {
    @builtin(position) clip: vec4<f32>,
    @location(0) world: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) colour: vec4<f32>,
    @location(3) across: f32,
};

@vertex
fn vs_grass(v: GIn) -> VGrass {
    var out: VGrass;
    out.clip = g.view_proj * vec4<f32>(v.pos, 1.0);
    out.world = v.pos;
    out.normal = v.normal.xyz;
    out.colour = v.colour;
    out.across = v.normal.w;
    return out;
}

// Root and tip albedo (display values). The frozen project recorded grass_base (0.238, 0.352,
// 0.214) and grass_highlight (0.442, 0.518, 0.312), but its meadow also gets ground-cover
// brightening and sky light this tool lacks; these are matched to its frames instead.
const GRASS_ROOT: vec3<f32> = vec3<f32>(0.428, 0.522, 0.258);
const GRASS_TIP: vec3<f32> = vec3<f32>(0.476, 0.581, 0.286);

@fragment
fn fs_grass(v: VGrass) -> FTerms {
    // How wide the blade is on screen: narrow blades fold into one canopy tone (Godot's
    // leaf_detail) instead of shimmering dark and light pixels.
    let width_px = 2.0 / max(fwidth(v.across), 1e-4);
    let detail = mix(0.45, 1.0, smoothstep(1.5, 5.0, width_px));
    let n = normalize(v.normal);
    let t = clamp(v.colour.a, 0.0, 1.0);
    let tint = v.colour.rgb * 2.0;
    let leaf = mix(GRASS_ROOT, GRASS_TIP, smoothstep(0.06, 0.90, t)) * tint;
    let canopy = mix(GRASS_ROOT, GRASS_TIP, 0.30 + 0.50 * smoothstep(0.0, 0.80, t)) * tint;
    var vis = 1.0;
    if (dot(n, g.sun_dir.xyz) > -0.05) {
        vis = sun_visibility_taps(v.world, n, v.clip.xy, 6);
    }
    // Baked occlusion: low at the root, open at the tip.
    let ao = mix(0.97, mix(0.90, 1.0, smoothstep(0.0, 0.80, t)), detail);
    var out: FTerms;
    out.base = vec4<f32>(clamp(mix(canopy, leaf, detail), vec3<f32>(0.0), vec3<f32>(1.0)), 0.0);
    out.terms = vec4<f32>(vis, ao, 0.0, 0.0);
    out.normal = vec4<f32>(n * 0.5 + 0.5, 1.0 / 255.0);
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

fn sky_colour(ray: vec3<f32>) -> vec3<f32> {
    let up = clamp(ray.y, 0.0, 1.0);
    var c = mix(g.pal[L_HAZE].rgb, g.pal[L_ZENITH].rgb, smoothstep(0.0, 0.6, sqrt(up)));
    let s = max(dot(ray, g.sun_dir.xyz), 0.0);
    c += g.pal[L_GLOW].rgb * pow(s, g.pal[L_GLOW].a);
    return c;
}

// Where the island's root dissolves: a cool white, between the lit cloud and its blue-grey shade.
fn cloud_mist() -> vec3<f32> {
    return mix(g.pal[L_CLOUD_SHADE].rgb, g.pal[L_CLOUD_LIT].rgb, 0.80) * vec3<f32>(0.965, 0.985, 1.03);
}

// Cloud sea relief, 0..1. Octaves finer than a few pixel footprints are replaced by their mean.
fn cloud_relief(p: vec2<f32>, foot: f32) -> f32 {
    var q = p * (1.0 / 190.0);
    var sum = 0.0;
    var amp = 0.5;
    var wavelength = 190.0;
    var norm = 0.0;
    for (var i = 0; i < 5; i++) {
        let keep = smoothstep(2.0 * foot, 6.0 * foot, wavelength);
        sum += amp * mix(0.5, vnoise(q), keep);
        norm += amp;
        q = vec2<f32>(q.x * 1.6 - q.y * 1.2, q.x * 1.2 + q.y * 1.6) + vec2<f32>(7.3, 1.9);
        amp *= 0.46;
        wavelength *= 0.5;
    }
    return smoothstep(0.22, 0.80, sum / norm);
}

fn backdrop(ray: vec3<f32>) -> vec3<f32> {
    if (ray.y >= 0.0) {
        return sky_colour(ray);
    }
    let t = (g.params2.z - g.camera_pos.y) / ray.y;
    let drift = vec2<f32>(g.params.x * 0.35, g.params.x * 0.12);
    let p = g.camera_pos.xz + ray.xz * t + drift;
    let foot = t * g.look.y * g.params.w / max(-ray.y, 0.03);
    let eps = max(foot * 1.5, 0.8);
    let h = cloud_relief(p, foot);
    let hx = cloud_relief(p + vec2<f32>(eps, 0.0), foot);
    let hz = cloud_relief(p + vec2<f32>(0.0, eps), foot);
    let relief = 110.0;
    let n = normalize(vec3<f32>(-(hx - h) / eps * relief, 1.0, -(hz - h) / eps * relief));
    // Broad soft forms, two-toned: warm cream where the forms rise into the sun, blue-grey on
    // their shadow sides and in the hollows between them, roughly half each, with soft but
    // readable boundaries. The tones come from a field of large waves only (45 to 95 m),
    // which no distance filters away; the finer relief only modulates the light within them.
    let big = vnoise(p / 95.0 + vec2<f32>(3.1, 7.7)) * 0.62 + vnoise(p / 44.0 + vec2<f32>(1.3, 2.9)) * 0.38;
    let bx = vnoise((p + vec2<f32>(6.0, 0.0)) / 95.0 + vec2<f32>(3.1, 7.7)) * 0.62 + vnoise((p + vec2<f32>(6.0, 0.0)) / 44.0 + vec2<f32>(1.3, 2.9)) * 0.38;
    let bz = vnoise((p + vec2<f32>(0.0, 6.0)) / 95.0 + vec2<f32>(3.1, 7.7)) * 0.62 + vnoise((p + vec2<f32>(0.0, 6.0)) / 44.0 + vec2<f32>(1.3, 2.9)) * 0.38;
    // Sun side of the large forms: their slope toward the sun widens the lit part.
    let toward = dot(vec2<f32>(bx - big, bz - big) / 6.0, normalize(g.sun_dir.xz)) * 95.0;
    let form = smoothstep(0.47, 0.63, big + toward * 0.05);
    let lit = smoothstep(-0.10, 0.30, dot(n, g.sun_dir.xyz));
    let shade = clamp(1.0 - form * mix(1.0, lit, 0.5), 0.0, 1.0);
    let cloud = mix(g.pal[L_CLOUD_LIT].rgb, g.pal[L_CLOUD_SHADE].rgb, shade);
    let haze = 1.0 - exp(-t * 0.0009);
    return mix(cloud, g.pal[L_HAZE].rgb, haze);
}

// Air between the eye and a surface: light fog near, pale haze far, the root sinking into cloud.
fn atmosphere(colour: vec3<f32>, world: vec3<f32>, distance: f32) -> vec3<f32> {
    var result = mix(colour, g.pal[L_FOG].rgb, 1.0 - exp(-distance * g.pal[L_FOG].a));
    result = mix(result, g.pal[L_HAZE].rgb, 1.0 - exp(-max(distance - 80.0, 0.0) * g.pal[L_FAR].a));
    let low = smoothstep(g.pal[L_MISC].x, g.pal[L_MISC].y, world.y) * g.pal[L_MIST].a;
    return mix(result, cloud_mist(), low);
}

// Light arriving at a surface with normal n (sun unshadowed), for water and spray.
fn open_light(n: vec3<f32>) -> vec3<f32> {
    let hemi = mix(g.pal[L_GROUND].rgb, g.pal[L_SKY].rgb, n.y * 0.5 + 0.5);
    return g.pal[L_SUN].rgb * max(dot(n, g.sun_dir.xyz), 0.0) + hemi + g.pal[L_FILL].rgb * max(dot(n, g.pal[L_FILL_DIR].xyz), 0.0);
}

// ---------------------------------------------------------------- ambient occlusion
// All of it runs at the output resolution. Each output pixel stands for the internal sample at
// px * scale (its "representative"); the resolve upsamples with depth awareness.

@group(1) @binding(0) var z_depth: texture_depth_2d;

// View distance of the representative, -1 for sky.
@fragment
fn fs_ao_depth(v: VFull) -> @location(0) vec4<f32> {
    let d = textureLoad(z_depth, vec2<i32>(v.pos.xy) * i32(g.params2.w), 0);
    return vec4<f32>(select(view_distance(d), -1.0, d >= 1.0), 0.0, 0.0, 1.0);
}

@group(1) @binding(0) var s_depth: texture_depth_2d;
@group(1) @binding(1) var s_normal: texture_2d<f32>;
@group(1) @binding(2) var s_aod: texture_2d<f32>;

@fragment
fn fs_ssao(v: VFull) -> @location(0) vec4<f32> {
    let px = vec2<i32>(v.pos.xy) * i32(g.params2.w);
    let depth = textureLoad(s_depth, px, 0);
    if (depth >= 1.0) {
        return vec4<f32>(1.0);
    }
    let n = normalize(textureLoad(s_normal, px, 0).xyz * 2.0 - 1.0);
    let world = world_at((vec2<f32>(px) + 0.5) / vec2<f32>(textureDimensions(s_depth)), depth);
    let size = vec2<f32>(textureDimensions(s_aod));
    let dist = view_distance(depth);
    if (dist > 250.0) {
        // The far mounds: nothing out there is near enough to anything else to occlude it.
        return vec4<f32>(1.0);
    }
    let far = g.params2.y;
    let radius = 0.65;
    var helper = vec3<f32>(0.0, 1.0, 0.0);
    if (abs(n.y) > 0.9) {
        helper = vec3<f32>(1.0, 0.0, 0.0);
    }
    let t0 = normalize(cross(helper, n));
    let b0 = cross(n, t0);
    let spin = ign(v.pos.xy) * TAU;
    let tangent = t0 * cos(spin) + b0 * sin(spin);
    let bitangent = cross(n, tangent);
    let bias = 0.015 + dist * 0.0004;
    // Twelve taps: nine within 0.65 m (feet of steps, joins, the lawn lip) and three reaching
    // 2.4 m at lower weight (the ground under a tree crown).
    var occluded = 0.0;
    for (var i = 0; i < 12; i++) {
        let fi = f32(i);
        let far_tap = i >= 9;
        var z: f32;
        var reach: f32;
        var weight: f32;
        if (far_tap) {
            let k = (fi - 8.5) / 3.0;
            z = mix(0.85, 0.45, k);
            reach = 2.4 * mix(0.5, 1.0, k);
            weight = 0.6;
        } else {
            let k = (fi + 0.5) / 9.0;
            z = 1.0 - k * 0.85;
            reach = radius * mix(0.2, 1.0, k);
            weight = 1.0;
        }
        let r = sqrt(1.0 - z * z);
        let a = fi * 2.3999632;
        let offset = (tangent * cos(a) * r + bitangent * sin(a) * r + n * z) * reach;
        let s = world + n * 0.02 + offset;
        let clip = g.view_proj * vec4<f32>(s, 1.0);
        let uv = vec2<f32>(clip.x / clip.w * 0.5 + 0.5, 0.5 - clip.y / clip.w * 0.5);
        if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
            continue;
        }
        let found = textureLoad(s_aod, vec2<i32>(uv * size), 0).r;
        let scene = select(found, far, found < 0.0);
        // Range check: an occluder more than one reach in front of this point does not darken it,
        // so nothing near draws a halo on what lies behind it.
        let range = 1.0 - smoothstep(reach, 2.0 * reach, abs(dist - scene));
        occluded += step(bias, clip.w - scene) * range * weight;
    }
    let ao = pow(clamp(1.0 - occluded / 10.8 * g.pal[L_MISC].z, 0.0, 1.0), g.pal[L_MISC].w);
    return vec4<f32>(ao, 0.0, 0.0, 1.0);
}

@group(1) @binding(0) var b_ao: texture_2d<f32>;
@group(1) @binding(1) var b_aod: texture_2d<f32>;

fn blur(px: vec2<i32>, step_dir: vec2<i32>) -> f32 {
    let c = textureLoad(b_aod, px, 0).r;
    if (c < 0.0) {
        return 1.0;
    }
    let size = vec2<i32>(textureDimensions(b_ao));
    // Seven taps two internal pixels apart (the footprint the blur had at the internal
    // resolution), at least one output pixel apart; depth decides what belongs together.
    let spacing = max(2 / i32(g.params2.w), 1);
    var sum = 0.0;
    var weights = 0.0;
    for (var i = -3; i <= 3; i++) {
        let q = clamp(px + step_dir * (i * spacing), vec2<i32>(0), size - 1);
        let d = textureLoad(b_aod, q, 0).r;
        if (d < 0.0) {
            continue;
        }
        let dz = (d - c) / (0.012 * c + 0.02);
        let w = exp(-f32(i * i) / 4.5) * exp(-dz * dz);
        sum += textureLoad(b_ao, q, 0).r * w;
        weights += w;
    }
    return sum / max(weights, 1e-4);
}

@fragment
fn fs_blur_h(v: VFull) -> @location(0) vec4<f32> {
    return vec4<f32>(blur(vec2<i32>(v.pos.xy), vec2<i32>(1, 0)), 0.0, 0.0, 1.0);
}

@fragment
fn fs_blur_v(v: VFull) -> @location(0) vec4<f32> {
    return vec4<f32>(blur(vec2<i32>(v.pos.xy), vec2<i32>(0, 1)), 0.0, 0.0, 1.0);
}

// ---------------------------------------------------------------- resolve pass

@group(1) @binding(0) var t_base: texture_2d<f32>;
@group(1) @binding(1) var t_terms: texture_2d<f32>;
@group(1) @binding(2) var t_normal: texture_2d<f32>;
@group(1) @binding(3) var t_depth: texture_depth_2d;
@group(1) @binding(4) var t_ao: texture_2d<f32>;
@group(1) @binding(5) var t_aod: texture_2d<f32>;

// Occlusion (output resolution) at an internal pixel: bilinear between the four nearest
// output texels, each weighted by how close its representative's depth is to this pixel's.
fn ao_at(px: vec2<i32>, own: f32) -> f32 {
    let scale = i32(g.params2.w);
    if (scale == 1) {
        return textureLoad(t_ao, px, 0).r;
    }
    let f = vec2<f32>(px) / f32(scale);
    let a0 = vec2<i32>(floor(f));
    let t = f - floor(f);
    let size = vec2<i32>(textureDimensions(t_ao));
    var sum = 0.0;
    var weights = 0.0;
    var best = 1.0;
    var best_dz = 1e9;
    for (var j = 0; j < 2; j++) {
        for (var i = 0; i < 2; i++) {
            let bw = select(1.0 - t.x, t.x, i == 1) * select(1.0 - t.y, t.y, j == 1);
            if (bw <= 0.0) {
                // At scale 2, three pixels in four sit on or between fewer than four texels.
                continue;
            }
            let a = clamp(a0 + vec2<i32>(i, j), vec2<i32>(0), size - 1);
            let d = textureLoad(t_aod, a, 0).r;
            let ao = textureLoad(t_ao, a, 0).r;
            var dz = 1e6;
            if (d >= 0.0) {
                dz = (d - own) / (0.012 * own + 0.02);
            }
            if (abs(dz) < best_dz) {
                best_dz = abs(dz);
                best = ao;
            }
            let w = bw * exp(-min(dz * dz, 80.0));
            sum += ao * w;
            weights += w;
        }
    }
    if (weights < 1e-4) {
        return best;
    }
    return sum / weights;
}

@fragment
fn fs_resolve(v: VFull) -> @location(0) vec4<f32> {
    let px = vec2<i32>(v.pos.xy);
    let depth = textureLoad(t_depth, px, 0);
    let ray = normalize(world_at(v.uv, 1.0) - g.camera_pos.xyz);
    if (depth >= 1.0) {
        return vec4<f32>(backdrop(ray), 1.0);
    }
    let base = textureLoad(t_base, px, 0);
    let terms = textureLoad(t_terms, px, 0);
    let n = normalize(textureLoad(t_normal, px, 0).xyz * 2.0 - 1.0);
    let family = base.a;
    let world = world_at(v.uv, depth);

    var display = base.rgb;
    if (family > 0.17 && family < 0.5) {
        // The mossy brow under the lawn lip: a soft green tint over the stone's own paint.
        display = mix(display, display * g.pal[L_MOSS].rgb, terms.a * g.pal[L_MOSS].a);
    }
    let albedo = to_linear(display);

    var ao = terms.g;
    var screen_ao = 1.0;
    if (g.look.x > 0.5) {
        screen_ao = ao_at(px, view_distance(depth));
        ao = min(ao, screen_ao);
    }
    if (g.look.z > 1.5) {
        ao = screen_ao;
    }
    if (g.look.z > 0.5) {
        // Occlusion only: 1 shows as light grey after the tone curve, 0.5 as mid grey.
        return vec4<f32>(vec3<f32>(ao * ao * 0.9), 1.0);
    }
    let shadow = mix(1.0, terms.r, g.pal[L_SUN].a);
    let nl_sun = dot(n, g.sun_dir.xyz);
    let nl_fill = dot(n, g.pal[L_FILL_DIR].xyz);
    var sun_k = max(nl_sun, 0.0);
    var fill_k = max(nl_fill, 0.0);
    if (family < 0.1) {
        // Ground and grass: Godot's meadow_diffuse, a broad rough-leaf response that wraps
        // round the terminator, so a lawn under a low sun still reads sunlit.
        sun_k = max(nl_sun, 0.0) * 0.25 + clamp((nl_sun + 0.42) / 1.42, 0.0, 1.0) * 0.90;
        fill_k = max(nl_fill, 0.0) * 0.25 + clamp((nl_fill + 0.42) / 1.42, 0.0, 1.0) * 0.90;
    }
    let sun = g.pal[L_SUN].rgb * sun_k * shadow;
    var hemi = mix(g.pal[L_GROUND].rgb, g.pal[L_SKY].rgb, n.y * 0.5 + 0.5);
    if (family > 0.17 && family < 0.5) {
        // Island stone in shade: Godot's crisp-facet light gives walls extra sky and cloud-sea
        // bounce, so shaded faces stay a light grey rather than going slate.
        hemi *= 1.32;
    }
    let fill = g.pal[L_FILL].rgb * fill_k;
    let colour = albedo * (sun + (hemi + fill) * ao);
    let distance = view_distance(depth);
    if (abs(textureLoad(t_normal, px, 0).a * 255.0 - 20.0) < 0.5) {
        // A far mound: only its upper band shows; below that it dissolves into the cloud sea seen
        // along the same ray (no line where it enters; the cloud plane would hide it otherwise),
        // and the far haze softens what shows.
        let air = mix(colour, g.pal[L_HAZE].rgb, 1.0 - exp(-max(distance - 80.0, 0.0) * g.pal[L_FAR].a * 0.7));
        // Cream at the crest, sinking into the blue-grey of the cloud shade lower down, so each
        // hill reads by its silhouette against the hollows; then the cloud sea itself.
        let shade_air = mix(g.pal[L_CLOUD_SHADE].rgb, g.pal[L_HAZE].rgb, 0.25);
        let toned = mix(air, shade_air, smoothstep(0.05, 0.30, terms.a) * 0.85);
        let emerge = 1.0 - smoothstep(0.30, 0.55, terms.a);
        if (emerge > 0.999) {
            return vec4<f32>(toned, 1.0);
        }
        return vec4<f32>(mix(backdrop(ray), toned, emerge), 1.0);
    }
    return vec4<f32>(atmosphere(colour, world, distance), 1.0);
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
@group(1) @binding(1) var w_scene: texture_2d<f32>;

fn ripple(p: vec2<f32>, t: f32) -> f32 {
    return vnoise(p * 1.3 + vec2<f32>(t * 0.11, t * 0.05)) * 0.6 + vnoise(p * 3.1 - vec2<f32>(t * 0.07, t * 0.13)) * 0.4;
}

// Output is premultiplied: rgb is what the water adds, a how much of the picture behind it hides.
@fragment
fn fs_water(v: VWater) -> @location(0) vec4<f32> {
    // How much the ripple-arc coordinate changes per pixel (taken before any discard).
    let ring_fw = fwidth(v.world.x * 1.5) + fwidth(v.world.z * 1.5);
    let px = vec2<i32>(v.clip.xy);
    let scene = textureLoad(w_depth, px, 0);
    if (v.clip.z > scene) {
        discard;
    }
    let t = g.params.x;
    let distance = view_distance(v.clip.z);
    let behind = view_distance(scene) - distance;
    let to_eye = normalize(g.camera_pos.xyz - v.world);
    var rgb: vec3<f32>;
    var alpha: f32;
    if (v.data.x < 0.5) {
        // Pond. Depth of the water column under this point, from the scene behind it.
        let depth = behind * max(to_eye.y, 0.05);
        let e = 0.15;
        let h0 = ripple(v.world.xz, t);
        let nrm = normalize(vec3<f32>(-(ripple(v.world.xz + vec2<f32>(e, 0.0), t) - h0) / e * 0.035, 1.0, -(ripple(v.world.xz + vec2<f32>(0.0, e), t) - h0) / e * 0.035));
        // The sky reflection kept weak at these pitches: the pond reads by its own jade body.
        let fresnel = (0.02 + 0.98 * pow(1.0 - clamp(dot(nrm, to_eye), 0.0, 1.0), 5.0)) * 0.5;
        let reflected = reflect(-to_eye, nrm);
        let sky = sky_colour(vec3<f32>(reflected.x, abs(reflected.y), reflected.z));
        // Darker toward the centre as the water deepens.
        let deep = smoothstep(0.0, 0.55, depth);
        let tint = mix(g.pal[L_WATER_SHALLOW].rgb, g.pal[L_WATER_DEEP].rgb, deep) * mix(1.0, 0.86, smoothstep(0.15, 0.80, depth));
        let body = tint * open_light(vec3<f32>(0.0, 1.0, 0.0));
        let absorb = mix(0.40, 0.95, smoothstep(0.0, 0.5, depth));
        let glint = g.pal[L_SUN].rgb * pow(max(dot(reflected, g.sun_dir.xyz), 0.0), 180.0) * 1.6;
        rgb = (1.0 - fresnel) * absorb * body + fresnel * sky + glint;
        alpha = 1.0 - (1.0 - fresnel) * (1.0 - absorb);
        // A few faint thin pale ripple arcs: rings round scattered centres, broken by noise.
        let cell = v.world.xz / 2.6;
        let ci = floor(cell);
        let centre = ci + vec2<f32>(hash21(ci), hash21(ci + vec2<f32>(7.1, 3.7)));
        let r = length(cell - centre) * 2.6;
        let ring = abs(fract(r * 1.5 - t * 0.12 - hash21(ci + vec2<f32>(3.3, 9.1))) - 0.5);
        let width = max(0.035, ring_fw);
        let arcs = (1.0 - smoothstep(width * 0.5, width, ring)) * (0.035 / width)
            * smoothstep(0.58, 0.82, vnoise(v.world.xz * 0.9 + vec2<f32>(11.0, 4.0)))
            * (1.0 - smoothstep(0.4, 1.25, r)) * smoothstep(0.08, 0.25, depth);
        let pale = g.pal[L_MIST].rgb * open_light(vec3<f32>(0.0, 1.0, 0.0));
        rgb = mix(rgb, pale * alpha, arcs * 0.16);
        // Screen-space reflection: march the mirrored view ray through the depth buffer (16
        // steps at most), so walls, stones and the statue are softly mirrored. Only water pays.
        if (g.pal[L_SSR].x > 0.5) {
            let size = vec2<f32>(textureDimensions(w_depth));
            let dir = normalize(reflect(-to_eye, normalize(vec3<f32>(nrm.x * 0.5, 1.0, nrm.z * 0.5))));
            var q = v.world;
            var stride = 0.22;
            var hit = 0.0;
            var mirror = vec3<f32>(0.0);
            for (var i = 0; i < 16; i++) {
                q += dir * stride;
                let c = g.view_proj * vec4<f32>(q, 1.0);
                if (c.w <= 0.0) {
                    break;
                }
                let uv = vec2<f32>(c.x / c.w * 0.5 + 0.5, 0.5 - c.y / c.w * 0.5);
                if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0) {
                    break;
                }
                let tap = vec2<i32>(uv * size);
                let d = textureLoad(w_depth, tap, 0);
                if (d < 1.0) {
                    let gap = c.w - view_distance(d);
                    if (gap > 0.0 && gap < stride * 1.6 + 0.25) {
                        let edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
                        hit = smoothstep(0.0, 0.08, edge) * (1.0 - smoothstep(8.0, 24.0, length(q - v.world)));
                        mirror = textureLoad(w_scene, tap, 0).rgb;
                        break;
                    }
                }
                stride *= 1.32;
            }
            let k = 0.35 * hit * smoothstep(0.03, 0.12, depth);
            rgb = rgb * (1.0 - k) + mirror * k;
            alpha = alpha * (1.0 - k) + k;
        }
        // A thin pale line where the water meets the bank, then the surface fades out over the first centimetres.
        let foam = smoothstep(0.004, 0.014, depth) * (1.0 - smoothstep(0.016, 0.045, depth)) * (0.55 + 0.45 * vnoise(v.world.xz * 7.0 + t * 0.2));
        rgb = mix(rgb, pale, foam * 0.55);
        alpha = mix(alpha, 1.0, foam * 0.55);
        let fade = smoothstep(0.0, 0.05, depth);
        rgb *= fade;
        alpha *= fade;
    } else if (v.data.x < 1.5) {
        // Fall: a teal-tinted body of water with white vertical streaks and a bright lip.
        let drop = v.data.z;
        let flow = sqrt(drop + 0.05);
        let streak = vnoise(vec2<f32>(v.data.y * 6.0, flow * 2.4 - t * 1.4)) * 0.6 + vnoise(vec2<f32>(v.data.y * 13.0, flow * 4.5 - t * 2.2)) * 0.4;
        let white = clamp(smoothstep(0.52, 0.90, streak) * 0.85 + (1.0 - smoothstep(0.0, 0.12, drop)) * 0.35, 0.0, 1.0);
        let face = normalize(vec3<f32>(to_eye.x, 0.25, to_eye.z));
        let light = open_light(face) * 0.85 + open_light(vec3<f32>(0.0, 1.0, 0.0)) * 0.15;
        let water_body = g.pal[L_FALL].rgb * light;
        let foam = g.pal[L_MIST].rgb * light;
        alpha = mix(0.84, 0.96, white);
        rgb = mix(water_body, foam, white) * alpha;
    } else {
        // Spray: a small soft foam at the foot of a fall.
        var shape: f32;
        if (v.data.x < 2.5) {
            let across = pow(sin(3.14159 * clamp(v.data.y, 0.0, 1.0)), 1.5);
            shape = across * smoothstep(0.0, 0.25, v.data.z) * (1.0 - smoothstep(0.30, 1.0, v.data.z));
        } else {
            let r = length(vec2<f32>(v.data.y, v.data.z) * 2.0 - 1.0);
            shape = 1.0 - smoothstep(0.15, 1.0, r);
        }
        let billow = 0.65 + 0.55 * vnoise(vec2<f32>(v.world.x + v.world.z, v.world.y) * 1.2 + vec2<f32>(t * 0.15, -t * 0.4));
        let soft = smoothstep(0.0, 0.5, behind);
        alpha = clamp(shape * billow * soft * 0.26, 0.0, 0.32);
        rgb = g.pal[L_MIST].rgb * open_light(normalize(to_eye + vec3<f32>(0.0, 1.0, 0.0))) * alpha;
    }
    // Air in front, then falls vanish into the cloud sea rather than ending on a line.
    // atmosphere() works on straight colour, so undo the premultiply around it.
    let air = atmosphere(rgb / max(alpha, 1e-4), v.world, distance) * alpha;
    let k = 1.0 - smoothstep(g.pal[L_MISC].x - 1.0, g.pal[L_MISC].y, v.world.y) * 0.95;
    return vec4<f32>(air * k, alpha * k);
}

// ---------------------------------------------------------------- downsample and display encode

@group(1) @binding(0) var t_full: texture_2d<f32>;
@group(1) @binding(1) var t_water: texture_2d<f32>;   // premultiplied ponds, falls and spray

@fragment
fn fs_down(v: VFull) -> @location(0) vec4<f32> {
    let scale = i32(g.params2.w);
    let px = vec2<i32>(v.pos.xy) * scale;
    var sum = vec3<f32>(0.0);
    for (var y = 0; y < scale; y++) {
        for (var x = 0; x < scale; x++) {
            let p = px + vec2<i32>(x, y);
            let water = textureLoad(t_water, p, 0);
            sum += textureLoad(t_full, p, 0).rgb * (1.0 - water.a) + water.rgb;
        }
    }
    let radiance = max(sum / f32(scale * scale), vec3<f32>(0.0));
    let tone = g.pal[L_TONE];
    let mapped = clamp(filmic(radiance * tone.x) / filmic(vec3<f32>(tone.y)), vec3<f32>(0.0), vec3<f32>(1.0));
    // The one and only display encode; the target is a plain 8-bit format, not an sRGB one.
    var display = to_display(mapped);
    display = mix(vec3<f32>(0.5), display, tone.z);
    display = mix(vec3<f32>(dot(display, vec3<f32>(0.2126, 0.7152, 0.0722))), display, tone.w);
    // One code value of triangular dither so slow gradients in the sky do not band.
    let dither = (hash21(v.pos.xy) + hash21(v.pos.xy + vec2<f32>(17.3, 5.1)) - 1.0) / 255.0;
    let out = clamp(display + dither, vec3<f32>(0.0), vec3<f32>(1.0));
    // With FXAA on, alpha carries the display luma the edge filter reads.
    let alpha = select(1.0, dot(out, vec3<f32>(0.299, 0.587, 0.114)), g.look.w > 0.5);
    return vec4<f32>(out, alpha);
}

// ---------------------------------------------------------------- FXAA (after the tone curve)
// FXAA 3.11 "quality" (Lottes): local contrast test, edge direction, a search along the edge
// of up to twelve steps, a blend across it, and the sub-pixel term (0.75).

@group(1) @binding(0) var f_ldr: texture_2d<f32>;
@group(1) @binding(1) var f_sampler: sampler;

fn fx_luma(uv: vec2<f32>) -> f32 {
    return textureSampleLevel(f_ldr, f_sampler, uv, 0.0).a;
}

@fragment
fn fs_fxaa(v: VFull) -> @location(0) vec4<f32> {
    let inv = 1.0 / vec2<f32>(textureDimensions(f_ldr));
    let uv = v.pos.xy * inv;
    let centre = textureSampleLevel(f_ldr, f_sampler, uv, 0.0);
    let lm = centre.a;
    let lu = fx_luma(uv + vec2<f32>(0.0, -1.0) * inv);
    let ld = fx_luma(uv + vec2<f32>(0.0, 1.0) * inv);
    let ll = fx_luma(uv + vec2<f32>(-1.0, 0.0) * inv);
    let lr = fx_luma(uv + vec2<f32>(1.0, 0.0) * inv);
    let lmin = min(lm, min(min(lu, ld), min(ll, lr)));
    let lmax = max(lm, max(max(lu, ld), max(ll, lr)));
    let range = lmax - lmin;
    if (range < max(0.0312, lmax * 0.125)) {
        return vec4<f32>(centre.rgb, 1.0);
    }
    let lul = fx_luma(uv + vec2<f32>(-1.0, -1.0) * inv);
    let lur = fx_luma(uv + vec2<f32>(1.0, -1.0) * inv);
    let ldl = fx_luma(uv + vec2<f32>(-1.0, 1.0) * inv);
    let ldr = fx_luma(uv + vec2<f32>(1.0, 1.0) * inv);
    let l_ud = lu + ld;
    let l_lr = ll + lr;
    let left_corners = lul + ldl;
    let down_corners = ldl + ldr;
    let right_corners = lur + ldr;
    let up_corners = lul + lur;
    let edge_h = abs(-2.0 * ll + left_corners) + abs(-2.0 * lm + l_ud) * 2.0 + abs(-2.0 * lr + right_corners);
    let edge_v = abs(-2.0 * lu + up_corners) + abs(-2.0 * lm + l_lr) * 2.0 + abs(-2.0 * ld + down_corners);
    let horizontal = edge_h >= edge_v;
    // The two neighbours across the edge: negative side (up or left) and positive side.
    let l_neg = select(ll, lu, horizontal);
    let l_pos = select(lr, ld, horizontal);
    let g_neg = abs(l_neg - lm);
    let g_pos = abs(l_pos - lm);
    let neg_steepest = g_neg >= g_pos;
    let g_scaled = 0.25 * max(g_neg, g_pos);
    var step_len = select(inv.x, inv.y, horizontal);
    var l_local = 0.5 * (l_pos + lm);
    if (neg_steepest) {
        step_len = -step_len;
        l_local = 0.5 * (l_neg + lm);
    }
    var cuv = uv;
    if (horizontal) {
        cuv.y += step_len * 0.5;
    } else {
        cuv.x += step_len * 0.5;
    }
    let along = select(vec2<f32>(0.0, inv.y), vec2<f32>(inv.x, 0.0), horizontal);
    var uv1 = cuv - along;
    var uv2 = cuv + along;
    var e1 = fx_luma(uv1) - l_local;
    var e2 = fx_luma(uv2) - l_local;
    var done1 = abs(e1) >= g_scaled;
    var done2 = abs(e2) >= g_scaled;
    if (!done1) {
        uv1 -= along;
    }
    if (!done2) {
        uv2 += along;
    }
    var quality = array<f32, 12>(1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 8.0);
    for (var i = 2; i < 12; i++) {
        if (done1 && done2) {
            break;
        }
        if (!done1) {
            e1 = fx_luma(uv1) - l_local;
        }
        if (!done2) {
            e2 = fx_luma(uv2) - l_local;
        }
        done1 = abs(e1) >= g_scaled;
        done2 = abs(e2) >= g_scaled;
        if (!done1) {
            uv1 -= along * quality[i];
        }
        if (!done2) {
            uv2 += along * quality[i];
        }
    }
    // Distances along the edge: x for a horizontal edge, y for a vertical one.
    let d1 = select(uv.y - uv1.y, uv.x - uv1.x, horizontal);
    let d2 = select(uv2.y - uv.y, uv2.x - uv.x, horizontal);
    let towards1 = d1 < d2;
    let d_min = min(d1, d2);
    let thickness = d1 + d2;
    let pixel_offset = -d_min / thickness + 0.5;
    let centre_smaller = lm < l_local;
    let correct = (select(e2, e1, towards1) < 0.0) != centre_smaller;
    var offset = select(0.0, pixel_offset, correct);
    // Sub-pixel aliasing: blend by how much the centre differs from its 3 x 3 neighbourhood.
    let l_avg = (1.0 / 12.0) * (2.0 * (l_ud + l_lr) + left_corners + right_corners);
    let sub1 = clamp(abs(l_avg - lm) / range, 0.0, 1.0);
    let sub2 = (-2.0 * sub1 + 3.0) * sub1 * sub1;
    offset = max(offset, sub2 * sub2 * 0.75);
    var fuv = uv;
    if (horizontal) {
        fuv.y += offset * step_len;
    } else {
        fuv.x += offset * step_len;
    }
    return vec4<f32>(textureSampleLevel(f_ldr, f_sampler, fuv, 0.0).rgb, 1.0);
}

// ---------------------------------------------------------------- props (exported Godot scene)
// Ports of the colour logic of three Godot shaders into what the terms pass writes (linear
// albedo, a lighting normal, occlusion); look N's resolve does the lighting.
//   fs_prop_stone : cliff_rock.gdshader (prop_kind 0 stones and scholar's rock, 2 path, 3 bench)
//   fs_prop_decor : decor_vertex_color.gdshader (trunks, tufts, flowers, reeds, lilies, bamboo, lantern)
//   fs_prop_leaf  : foliage_cards.gdshader (tree and bush leaf cards; atlas cut-out at 0.23)

struct PIn {
    @location(0) pos: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    @location(3) anchor: vec3<f32>,
    @location(4) colour: vec4<f32>,
    @location(5) mat: vec4<u32>,
};

struct VProp {
    @builtin(position) clip: vec4<f32>,
    @location(0) world: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    @location(3) anchor: vec3<f32>,
    @location(4) colour: vec4<f32>,
    @location(5) @interpolate(flat) mat: vec4<u32>,
};

@group(2) @binding(0) var p_atlas: texture_2d<f32>;
@group(2) @binding(1) var p_gouache: texture_2d<f32>;
@group(2) @binding(2) var p_detail: texture_2d<f32>;
@group(2) @binding(3) var p_repeat: sampler;
@group(2) @binding(4) var p_clamp: sampler;
@group(2) @binding(5) var<uniform> p_mat: array<vec4<f32>, 384>;

@vertex
fn vs_prop(v: PIn) -> VProp {
    var out: VProp;
    out.clip = g.view_proj * vec4<f32>(v.pos, 1.0);
    out.world = v.pos;
    out.normal = v.normal;
    out.uv = v.uv;
    out.anchor = v.anchor;
    out.colour = v.colour;
    out.mat = v.mat;
    return out;
}

@vertex
fn vs_prop_shadow(v: PIn) -> @builtin(position) vec4<f32> {
    return g.light_view_proj * vec4<f32>(v.pos, 1.0);
}

struct VPropShadow {
    @builtin(position) clip: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

@vertex
fn vs_prop_shadow_leaf(v: PIn) -> VPropShadow {
    var out: VPropShadow;
    out.clip = g.light_view_proj * vec4<f32>(v.pos, 1.0);
    out.uv = v.uv;
    return out;
}

@fragment
fn fs_prop_shadow_leaf(v: VPropShadow) {
    if (textureSample(p_atlas, p_clamp, v.uv).a < 0.23) {
        discard;
    }
}

// What every prop writes. Family 1.0 keeps the resolve's moss off; terms.a 0.5 is neutral.
fn prop_terms(albedo: vec3<f32>, n: vec3<f32>, ao: f32, vis: f32) -> FTerms {
    var out: FTerms;
    out.base = vec4<f32>(to_display(clamp(albedo, vec3<f32>(0.0), vec3<f32>(1.0))), 1.0);
    out.terms = vec4<f32>(vis, clamp(ao, 0.0, 1.0), 0.0, 0.5);
    out.normal = vec4<f32>(n * 0.5 + 0.5, 0.0);
    return out;
}

fn prop_visibility(world: vec3<f32>, n: vec3<f32>, pixel: vec2<f32>) -> f32 {
    if (dot(n, g.sun_dir.xyz) > -0.05) {
        return sun_visibility(world, n, pixel);
    }
    return 1.0;
}

// --- cliff_rock.gdshader (with cliff_palette and stone_surface includes)

fn rock_hash(p: vec3<f32>) -> vec3<f32> {
    var q = fract(p * vec3<f32>(0.123, 0.117, 0.139));
    q += dot(q, q.zxy + vec3<f32>(19.19));
    return fract(vec3<f32>((q.x + q.y) * q.z, (q.y + q.z) * q.x, (q.z + q.x) * q.y));
}

fn stone_noise(p: vec3<f32>) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    let a = mix(rock_hash(i).x, rock_hash(i + vec3<f32>(1.0, 0.0, 0.0)).x, f.x);
    let b = mix(rock_hash(i + vec3<f32>(0.0, 1.0, 0.0)).x, rock_hash(i + vec3<f32>(1.0, 1.0, 0.0)).x, f.x);
    let c = mix(rock_hash(i + vec3<f32>(0.0, 0.0, 1.0)).x, rock_hash(i + vec3<f32>(1.0, 0.0, 1.0)).x, f.x);
    let d = mix(rock_hash(i + vec3<f32>(0.0, 1.0, 1.0)).x, rock_hash(i + vec3<f32>(1.0, 1.0, 1.0)).x, f.x);
    return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

fn stone_weights(n: vec3<f32>) -> vec3<f32> {
    let w = pow(abs(n), vec3<f32>(3.0));
    return w / max(dot(w, vec3<f32>(1.0)), 0.001);
}

@fragment
fn fs_prop_stone(v: VProp) -> FTerms {
    let base = i32(v.mat.y) * 4;
    let shadow_c = p_mat[base].rgb;
    let kind = p_mat[base].a;
    let mid_c = p_mat[base + 1].rgb;
    let bank = p_mat[base + 1].a;
    let lit_c = p_mat[base + 2].rgb;
    let n = normalize(v.normal);
    // Godot mixes 7.5% of a detail-map normal in; that turn is under a degree and is skipped.
    let shade_n = n;
    let w = stone_weights(shade_n);
    let p = v.world;
    // Triplanar textures, all taps in uniform control flow.
    let pg = p * 1.35;
    let broad = textureSampleBias(p_gouache, p_repeat, pg.zy * 0.11, 1.15).rgb * w.x + textureSampleBias(p_gouache, p_repeat, pg.xz * 0.11, 1.15).rgb * w.y + textureSampleBias(p_gouache, p_repeat, pg.xy * 0.11, 1.15).rgb * w.z;
    let o = vec2<f32>(0.37, 0.61);
    let med = textureSampleBias(p_gouache, p_repeat, pg.zy * 0.26 + o, 1.15).rgb * w.x + textureSampleBias(p_gouache, p_repeat, pg.xz * 0.26 + o, 1.15).rgb * w.y + textureSampleBias(p_gouache, p_repeat, pg.xy * 0.26 + o, 1.15).rgb * w.z;
    let wash = mix(broad, med, 0.38);
    let pd = p * 2.40;
    let detail = textureSample(p_detail, p_repeat, pd.zy * 0.24).r * w.x + textureSample(p_detail, p_repeat, pd.xz * 0.24).r * w.y + textureSample(p_detail, p_repeat, pd.xy * 0.24).r * w.z;
    let ridge_edge = clamp(length(fwidth(n)) * 1.20, 0.0, 1.0);

    let variation = rock_hash(floor(v.anchor * 1.37) + vec3<f32>(17.0, 5.0, 29.0));
    let h_rel = p.y - v.anchor.y;
    let wet = bank * (1.0 - smoothstep(0.02, 0.15, h_rel));
    let cav = clamp(v.uv.y, 0.0, 0.80);
    let brush_tint = clamp(wash / vec3<f32>(0.46, 0.50, 0.46), vec3<f32>(0.95), vec3<f32>(1.05));
    let micro_grain = detail * 0.55 + stone_noise(p * 4.60 + variation * 3.1) * 0.45;
    // Godot's fixed sun direction for its painted terms, kept as it was.
    let sun_dir_dot = dot(shade_n, normalize(vec3<f32>(0.88, 0.43, 0.11)));
    let away_sun = smoothstep(0.14, -0.52, sun_dir_dot);
    // COLOR is the vertex colour times the instance colour (Godot multiplies them for multimeshes).
    let colour_r = v.colour.r;

    var base_col: vec3<f32>;
    var base_ao = 1.0;
    if (abs(kind - 2.0) < 0.4) {
        // Path flagstone.
        let top_face = smoothstep(0.38, 0.86, shade_n.y);
        let rim_tone = mix(mid_c, lit_c, 0.36) * vec3<f32>(0.94, 0.96, 0.98);
        let top_tone = mix(mid_c, lit_c, 0.78) * vec3<f32>(0.98, 0.97, 0.92);
        let warm_jit = mix(vec3<f32>(0.96, 0.98, 1.02), vec3<f32>(1.04, 1.01, 0.95), variation.x);
        base_col = mix(rim_tone, top_tone, top_face) * warm_jit * mix(vec3<f32>(1.0), brush_tint, 0.22);
        base_col *= clamp(colour_r / 0.52, 0.84, 1.06) * (0.974 + 0.052 * micro_grain);
        base_ao = mix(0.76, 1.0, smoothstep(-0.01, 0.07, h_rel)) * mix(0.84, 1.0, top_face);
    } else if (abs(kind - 3.0) < 0.4) {
        // Carved bench.
        let top_slab = smoothstep(0.36, 0.84, shade_n.y);
        let leg_shadow = mix(shadow_c, mid_c, 0.32) * vec3<f32>(0.96, 0.98, 1.02);
        let carved_mid = mix(mid_c, lit_c, 0.24) * vec3<f32>(1.00, 1.00, 0.98);
        let slab_lit = mix(mid_c, lit_c, 0.72) * vec3<f32>(0.98, 0.96, 0.90);
        base_col = mix(carved_mid, slab_lit, top_slab);
        base_col = mix(base_col, leg_shadow, away_sun * (1.0 - top_slab) * 0.48);
        base_col *= mix(vec3<f32>(1.0), brush_tint, 0.20) * clamp(colour_r / 0.62, 0.80, 1.06) * (0.976 + 0.048 * micro_grain);
        base_col *= mix(vec3<f32>(1.0), vec3<f32>(0.74, 0.80, 0.84), cav * 0.50);
        let foot_moss = (1.0 - smoothstep(0.0, 0.10, h_rel)) * smoothstep(0.55, -0.15, shade_n.y);
        base_col = mix(base_col, vec3<f32>(0.095, 0.140, 0.072), foot_moss * 0.30);
        base_ao = mix(0.72, 1.0, smoothstep(0.0, 0.16, h_rel)) * (1.0 - cav * 0.38) * mix(1.0, 0.82, away_sun * (1.0 - top_slab));
    } else {
        // Garden boulders, shore stones and the scholar's rock (kind 0; other kinds fall back here).
        let top_crown = smoothstep(0.42, 0.88, shade_n.y);
        let under_face = smoothstep(-0.08, -0.60, shade_n.y);
        // Paler and creamier than Godot's albedo, with brighter tops: Godot's crisp-facet light
        // adds a large top lift and sky fill on these stones that look N's plain light lacks.
        let rock_under = mix(shadow_c, mid_c, 0.62) * vec3<f32>(0.98, 0.99, 1.02);
        let rock_mid = mix(mid_c, lit_c, 0.56) * vec3<f32>(0.99, 0.99, 0.98);
        let rock_top = mix(mid_c, lit_c, 0.92) * vec3<f32>(1.13, 1.09, 0.99);
        base_col = mix(rock_mid, rock_top, top_crown) * (1.0 + 0.20 * top_crown);
        base_col = mix(base_col, rock_under, under_face * 0.48);
        let mineral_shift = mix(vec3<f32>(0.98, 0.99, 1.01), vec3<f32>(1.02, 1.00, 0.97), variation.x);
        base_col *= mineral_shift * mix(vec3<f32>(1.0), brush_tint, 0.18) * (0.980 + 0.040 * micro_grain);
        base_col *= clamp(colour_r / 0.56, 0.86, 1.04);
        base_col += base_col * ridge_edge * (0.012 + 0.020 * smoothstep(0.05, 0.70, sun_dir_dot) * top_crown);
        let moss_noise = stone_noise(p * 1.8 + vec3<f32>(4.2));
        let moss_skirt = (1.0 - bank) * (1.0 - smoothstep(0.0, 0.09 + 0.04 * moss_noise, h_rel)) * (1.0 - top_crown * 0.85);
        let moss_col = mix(vec3<f32>(0.085, 0.124, 0.062), vec3<f32>(0.132, 0.170, 0.085), moss_noise);
        base_col = mix(base_col, moss_col, clamp(moss_skirt * 0.28, 0.0, 0.24));
        base_col *= mix(vec3<f32>(1.0), vec3<f32>(0.78, 0.82, 0.86), cav * (1.0 - top_crown * 0.80) * 0.36);
        base_ao = mix(0.74, 1.0, smoothstep(-0.02, 0.15, h_rel)) * (1.0 - cav * (1.0 - top_crown * 0.80) * 0.30);
    }
    let albedo = base_col * mix(vec3<f32>(1.0), vec3<f32>(0.70, 0.75, 0.75), wet * (1.0 - smoothstep(0.45, 0.85, shade_n.y) * 0.68));
    return prop_terms(albedo, shade_n, base_ao, prop_visibility(p, shade_n, v.clip.xy));
}

// --- decor_vertex_color.gdshader

fn bark_hash(p0: vec3<f32>) -> f32 {
    var p = fract(p0 * vec3<f32>(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

fn bark_noise(p: vec3<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(bark_hash(i), bark_hash(i + vec3<f32>(1.0, 0.0, 0.0)), u.x), mix(bark_hash(i + vec3<f32>(0.0, 1.0, 0.0)), bark_hash(i + vec3<f32>(1.0, 1.0, 0.0)), u.x), u.y),
        mix(mix(bark_hash(i + vec3<f32>(0.0, 0.0, 1.0)), bark_hash(i + vec3<f32>(1.0, 0.0, 1.0)), u.x), mix(bark_hash(i + vec3<f32>(0.0, 1.0, 1.0)), bark_hash(i + vec3<f32>(1.0, 1.0, 1.0)), u.x), u.y),
        u.z
    );
}

fn bark_grain_field(lp: vec3<f32>, detail_w: f32) -> f32 {
    let s_along = lp.y * 1.25 + length(lp.xz) * 0.55;
    let p_twist = lp.xz + vec2<f32>(sin(s_along * 1.25 + lp.z * 1.1), cos(s_along * 1.05 - lp.x * 1.1)) * 0.08;
    let macro_plate = bark_noise(vec3<f32>(p_twist * 4.2, s_along * 0.82));
    let mid_plate = bark_noise(vec3<f32>(p_twist * 9.6 + vec2<f32>(4.1, 7.3), s_along * 1.75));
    let fissure = bark_noise(vec3<f32>(p_twist * 20.0 + vec2<f32>(9.2, 2.7), s_along * 3.4));
    return (macro_plate * 0.56 + mid_plate * 0.44) * 0.76 + fissure * 0.24 * detail_w;
}

@fragment
fn fs_prop_decor(v: VProp) -> FTerms {
    let base = i32(v.mat.y) * 4;
    let n = normalize(v.normal);
    var col = v.colour.rgb;
    if (p_mat[base + 1].a < 0.5) {
        col = to_linear(col);
    }
    // Godot also tints by a sky wrap (decor_sky_shadow..lit by normal.y); look N's hemisphere
    // light does that job, so albedo stays the vertex colour.
    let detail_w = 1.0 - smoothstep(0.035, 0.15, length(fwidth(v.world)));
    var ao = 1.0;
    if (v.uv.y > 0.11 && v.uv.y < 0.18) {
        // Bark: crevices, plates and ridges, lichen on the shaded side, moss at the root.
        let lp = v.world - v.anchor;
        let bark_h = bark_grain_field(lp, detail_w);
        let is_pine_bark = smoothstep(0.14, 0.155, v.uv.y);
        let crevice_mask = 1.0 - smoothstep(0.25, 0.50, bark_h);
        let ridge_mask = smoothstep(0.50, 0.79, bark_h);
        let bark_crevice = col * vec3<f32>(0.42, 0.49, 0.58);
        let bark_plate = col * vec3<f32>(0.98, 0.99, 0.97);
        let bark_ridge = col * mix(vec3<f32>(1.38, 1.35, 1.25), vec3<f32>(1.42, 1.31, 1.15), is_pine_bark);
        col = mix(bark_plate, bark_crevice, crevice_mask * 0.88);
        col = mix(col, bark_ridge, ridge_mask * 0.84);
        let lichen = smoothstep(0.18, -0.52, n.x) * smoothstep(0.54, 0.82, bark_h);
        col = mix(col, vec3<f32>(0.086, 0.122, 0.084), lichen * 0.34);
        let root_reach = 0.15 + 0.11 * crevice_mask;
        let root_moss = 1.0 - smoothstep(0.01, root_reach, v.uv.x);
        col = mix(col, mix(vec3<f32>(0.048, 0.088, 0.034), vec3<f32>(0.082, 0.128, 0.052), bark_h), root_moss * 0.64);
        ao = mix(1.0, 0.50, crevice_mask);
    }
    if (v.uv.y > 0.25 && v.uv.y < 0.90) {
        col *= mix(0.92, 1.05, smoothstep(0.0, 0.82, v.uv.x));
    }
    return prop_terms(col, n, ao, prop_visibility(v.world, n, v.clip.xy));
}

// --- foliage_cards.gdshader

@fragment
fn fs_prop_leaf(v: VProp) -> FTerms {
    let tex = textureSample(p_atlas, p_clamp, v.uv);
    if (tex.a < 0.23) {
        discard;
    }
    let base = i32(v.mat.y) * 4;
    let leaf_shadow = p_mat[base].rgb;
    let rim_strength = p_mat[base].a;
    let leaf_mid = p_mat[base + 1].rgb;
    let leaf_lit = p_mat[base + 2].rgb;
    // Both faces use the card's own normal, as Godot does (it never flips it for back faces).
    let n = normalize(v.normal);
    let up_ref = select(vec3<f32>(1.0, 0.0, 0.0), vec3<f32>(0.0, 1.0, 0.0), abs(n.y) < 0.96);
    let tang_x = normalize(cross(up_ref, n));
    let tang_y = normalize(cross(n, tang_x));
    let puff_xy = (tex.gb - vec2<f32>(128.0 / 255.0)) * 2.0;
    let puff_off = (tang_x * puff_xy.x + tang_y * puff_xy.y) * 0.52;
    let puff_n = normalize(n + puff_off);
    let card_value = v.colour.r;
    let card_height = v.colour.g;
    let card_ao = select(1.0, v.colour.b, v.colour.b > 0.01);
    // Godot's albedo: the three tints mixed by a "sky" value from the leaf-cluster dome,
    // height in the crown and occlusion, then brushwork from atlas R.
    let dome_orient = puff_n.y * 0.62 + puff_n.x * 0.38;
    let sky_t = clamp(0.06 + card_height * 0.12 + smoothstep(-0.58, 0.86, dome_orient) * 0.44 + (card_ao - 0.36) * 0.46, 0.0, 1.0) * card_value;
    var col = select(mix(leaf_mid, leaf_lit, (sky_t - 0.52) / 0.48), mix(leaf_shadow, leaf_mid, sky_t / 0.52), sky_t < 0.52);
    col *= mix(0.80, 1.20, smoothstep(0.40, 0.72, tex.r));
    let mist_bloom = smoothstep(4.0, 18.0, v.world.x) * smoothstep(0.0, 0.70, puff_n.x) * smoothstep(0.40, 0.95, card_ao);
    col = mix(col, leaf_lit * vec3<f32>(1.16, 1.10, 0.95), mist_bloom * 0.10);
    // Lighting normal: out of the crown blended with up, so a crown shades as one mass; a
    // little of the leaf-cluster dome keeps clusters from going flat.
    let out_dir = normalize(v.anchor);
    let n_light = normalize(out_dir * 0.80 + vec3<f32>(0.0, 0.60, 0.0) + puff_off * 0.35);
    let vis = prop_visibility(v.world, n_light, v.clip.xy);
    // Godot's sunlit warm rim and back-lit translucency (its light() adds them on top of the
    // diffuse); here they lift the albedo of sunlit outer cards.
    let to_eye = normalize(g.camera_pos.xyz - v.world);
    let ndl = dot(n_light, g.sun_dir.xyz);
    let view_rim = pow(1.0 - clamp(dot(n_light, to_eye), 0.0, 1.0), 1.58);
    let back_scatter = pow(clamp(dot(-g.sun_dir.xyz, to_eye), 0.0, 1.0), 2.0) * vis;
    let sun_kiss = smoothstep(0.05, 0.62, ndl) * vis;
    let warm_rim = vec3<f32>(1.56, 1.42, 0.96) * (view_rim * sun_kiss * 0.62 + back_scatter * 0.36) * smoothstep(0.36, 0.94, card_ao) * rim_strength;
    col *= vec3<f32>(1.0) + warm_rim * 0.6;
    return prop_terms(col, n_light, card_ao, vis);
}
