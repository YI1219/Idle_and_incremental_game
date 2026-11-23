//! The frozen Godot scene's props (trees, bushes, rocks, path stones, bench, scholar's rock,
//! lantern, flowers, reeds, lilies) as exported by tools/export/export_scene_props.gd, refitted
//! to this tool's ground and baked into static world-space vertices. Colour is made on the GPU
//! by ports of the three Godot shaders (see shader.wgsl, "props").
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use glam::{Mat3, Vec2, Vec3};

use crate::field::{Cells, Field};

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct PropVertex {
    pub pos: [f32; 3],
    pub normal: [f32; 3],
    pub uv: [f32; 2],
    /// Stone and decor: the instance origin (world). Leaf cards: the unit direction out of the crown.
    pub anchor: [f32; 3],
    /// Raw Godot vertex colour (times the instance colour where there is one).
    pub colour: [u8; 4],
    /// x class (0 stone, 1 decor, 2 leaf), y material index, z, w spare.
    pub mat: [u8; 4],
}

pub const CLASS_STONE: u8 = 0;
pub const CLASS_DECOR: u8 = 1;
pub const CLASS_LEAF: u8 = 2;
/// Material table rows: four vec4 per material.
pub const MATERIAL_ROWS: usize = 4;
pub const MAX_MATERIALS: usize = 96;

/// Everything the renderer needs for the props of all islands.
#[derive(Default)]
pub struct Library {
    /// One bucket per class so each class is one contiguous draw.
    pub buckets: [Vec<PropVertex>; 3],
    pub materials: Vec<[[f32; 4]; MATERIAL_ROWS]>,
    /// The scene folder the textures are read from (the first one loaded).
    pub texture_dir: Option<PathBuf>,
    /// Lamp centres of the stone lanterns (world), for their glow at dusk and night.
    pub lanterns: Vec<Vec3>,
}

pub struct Image {
    pub width: u32,
    pub height: u32,
    pub rgba: Vec<u8>,
}

pub fn load_png(path: &Path) -> Image {
    let file = std::fs::File::open(path).unwrap_or_else(|e| panic!("cannot read {}: {e}", path.display()));
    let mut decoder = png::Decoder::new(std::io::BufReader::new(file));
    decoder.set_transformations(png::Transformations::normalize_to_color8());
    let mut reader = decoder.read_info().expect("png info");
    let mut buffer = vec![0; reader.output_buffer_size().expect("png size")];
    let info = reader.next_frame(&mut buffer).expect("png frame");
    let pixels = (info.width * info.height) as usize;
    let rgba = match info.color_type {
        png::ColorType::Rgba => buffer[..pixels * 4].to_vec(),
        png::ColorType::Rgb => buffer[..pixels * 3].chunks(3).flat_map(|c| [c[0], c[1], c[2], 255]).collect(),
        png::ColorType::GrayscaleAlpha => buffer[..pixels * 2].chunks(2).flat_map(|c| [c[0], c[0], c[0], c[1]]).collect(),
        png::ColorType::Grayscale => buffer[..pixels].iter().flat_map(|&c| [c, c, c, 255]).collect(),
        other => panic!("{}: unsupported colour type {other:?}", path.display()),
    };
    Image { width: info.width, height: info.height, rgba }
}

/// Default props folder for a layout file: `.../layout_7301_0.json` -> `.../scene_7301_0`.
pub fn default_dir(layout: &str) -> Option<PathBuf> {
    let path = Path::new(layout);
    let stem = path.file_stem()?.to_str()?;
    let mut suffix = stem.strip_prefix("layout_")?.to_string();
    // Round r9: an edited layout (`layout_7301_0_ramps.json`) takes the scene of the layout it was
    // made from: drop trailing `_name` parts until a scene folder exists.
    loop {
        let dir = path.parent()?.join(format!("scene_{suffix}"));
        if dir.join("scene.json").exists() {
            return Some(dir);
        }
        match suffix.rfind('_') {
            Some(i) => suffix.truncate(i),
            None => return Some(path.parent()?.join(format!("scene_{}", stem.strip_prefix("layout_")?))),
        }
    }
}

fn lin(v: f32) -> f32 {
    if v <= 0.04045 {
        v / 12.92
    } else {
        ((v + 0.055) / 1.055).powf(2.4)
    }
}

/// A colour-hinted Godot parameter (exported as written, sRGB) as linear rgb.
fn param_colour(params: &serde_json::Value, key: &str, fallback: [f32; 3]) -> [f32; 3] {
    match params[key].as_array() {
        Some(a) => [0, 1, 2].map(|i| lin(a[i].as_f64().unwrap_or(0.0) as f32)),
        None => fallback.map(lin),
    }
}

fn param_f(params: &serde_json::Value, key: &str, fallback: f32) -> f32 {
    params[key].as_f64().map(|v| v as f32).or_else(|| params[key].as_bool().map(|b| if b { 1.0 } else { 0.0 })).unwrap_or(fallback)
}

fn row(c: [f32; 3], w: f32) -> [f32; 4] {
    [c[0], c[1], c[2], w]
}

/// The class and the table rows of one exported material.
fn material_rows(material: &serde_json::Value) -> Option<(u8, [[f32; 4]; MATERIAL_ROWS])> {
    let shader = material["shader"].as_str().unwrap_or("");
    let p = &material["params"];
    if shader.ends_with("foliage_cards.gdshader") {
        Some((
            CLASS_LEAF,
            [
                row(param_colour(p, "leaf_shadow", [0.07, 0.15, 0.11]), param_f(p, "rim_strength", 1.0)),
                row(param_colour(p, "leaf_mid", [0.20, 0.31, 0.19]), 0.0),
                row(param_colour(p, "leaf_lit", [0.43, 0.53, 0.34]), 0.0),
                [0.0; 4],
            ],
        ))
    } else if shader.ends_with("decor_vertex_color.gdshader") {
        Some((
            CLASS_DECOR,
            [
                row(param_colour(p, "lantern_glow_color", [1.0, 0.76, 0.40]), param_f(p, "lantern_glow_strength", 0.22)),
                row(param_colour(p, "decor_sky_shadow", [0.86, 0.92, 0.96]), param_f(p, "linear_vertex_color", 0.0)),
                row(param_colour(p, "decor_sky_lit", [1.04, 1.02, 0.96]), 0.0),
                [0.0; 4],
            ],
        ))
    } else if shader.ends_with("cliff_rock.gdshader") {
        Some((
            CLASS_STONE,
            [
                row(param_colour(p, "stone_shadow_color", [0.24, 0.31, 0.43]), param_f(p, "prop_kind", 0.0)),
                row(param_colour(p, "stone_mid_color", [0.50, 0.48, 0.46]), param_f(p, "bank_stone", 0.0)),
                row(param_colour(p, "stone_lit_color", [0.80, 0.73, 0.62]), 0.0),
                row(param_colour(p, "stone_mist_color", [0.89, 0.89, 0.86]), 0.0),
            ],
        ))
    } else {
        None
    }
}

/// What a load reports.
pub struct Report {
    pub objects: usize,
    pub instances: usize,
    pub triangles: usize,
    pub dropped: usize,
    pub dropped_by_kind: BTreeMap<String, usize>,
    pub skipped_materials: usize,
    /// Moved (up to 1 m) because their footprint touched a terrace wall or a fall's notch.
    pub moved: usize,
    /// Round r9 (F2): stones over a pond lowered onto its bed, or moved to the shore.
    pub bedded: usize,
    pub shored: usize,
    /// Placed by `scatter` rather than loaded where the scene had them.
    pub scattered: bool,
    /// Circles (island coordinates, x z, radius) the grass keeps out of.
    pub clear: Vec<(Vec2, f32)>,
}

/// Grass clearing radius per prop kind at unit scale: the frozen project's GRASS_CLEAR
/// (trunks tight, rocks and path stones wider) plus its prop entries.
fn clear_radius(kind: &str) -> Option<f32> {
    Some(match kind {
        "tree" | "tree_b" => 0.12,
        "surface_rock" => 0.75,
        "cliff_rock" => 0.80,
        "shore_rock" => 0.45,
        "shore_boulder" => 0.55,
        "shore_pebble" => 0.30,
        "bush" => 0.50,
        "path" => 0.46,
        "reeds" => 0.30,
        "bench" => 0.75,
        "scholar_rock" => 0.60,
        "lantern" => 0.30,
        "bamboo" => 0.45,
        _ => return None,
    })
}

impl Report {
    pub fn line(&self, dir: &Path) -> String {
        let kinds: Vec<String> = self.dropped_by_kind.iter().map(|(k, n)| format!("{k} {n}")).collect();
        format!(
            "PROPS {} {} objects, {} instances, {} triangles, {} {}{}{} from {}{}",
            if self.scattered { "scattered" } else { "loaded" },
            self.objects,
            self.instances,
            self.triangles,
            self.dropped,
            if self.scattered { "short of the source density" } else { "dropped" },
            if kinds.is_empty() { String::new() } else { format!(" ({})", kinds.join(", ")) },
            if self.moved > 0 { format!(", {} moved off walls", self.moved) } else { String::new() } + &if self.bedded + self.shored > 0 { format!(", {} stones set on a pond bed, {} moved to the shore", self.bedded, self.shored) } else { String::new() },
            dir.file_name().and_then(|n| n.to_str()).unwrap_or("?"),
            if self.skipped_materials > 0 { format!(", {} meshes with an unknown shader skipped", self.skipped_materials) } else { String::new() }
        )
    }
}

fn floats(bin: &[u8], offset: i64, count: usize) -> Vec<f32> {
    let start = offset as usize;
    bin[start..start + count * 4].chunks_exact(4).map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]])).collect()
}

fn q(v: f32) -> u8 {
    (v.clamp(0.0, 1.0) * 255.0 + 0.5) as u8
}

struct MeshData {
    pos: Vec<Vec3>,
    normal: Vec<Vec3>,
    uv: Vec<Vec2>,
    colour: Vec<[f32; 4]>,
    /// Triangle list, already in this renderer's winding (counter-clockwise front).
    tris: Vec<[u32; 3]>,
    material: usize,
}


/// A scene folder opened: its objects, meshes and the material slots it added to the library.
struct Scene {
    json: serde_json::Value,
    bin: Vec<u8>,
    meshes: Vec<MeshData>,
    material_slot: Vec<Option<(u8, u8)>>,
}

fn open(dir: &Path, library: &mut Library) -> Scene {
    let json_path = dir.join("scene.json");
    let text = std::fs::read_to_string(&json_path).unwrap_or_else(|e| panic!("cannot read {}: {e}", json_path.display()));
    let json: serde_json::Value = serde_json::from_str(&text).expect("scene json");
    let bin = std::fs::read(dir.join("scene.bin")).expect("scene.bin");
    if library.texture_dir.is_none() {
        library.texture_dir = Some(dir.join("textures"));
    }
    // Materials: class and table index (offset into the shared table).
    let mut material_slot: Vec<Option<(u8, u8)>> = Vec::new();
    for material in json["materials"].as_array().expect("materials") {
        match material_rows(material) {
            Some((class, rows)) => {
                assert!(library.materials.len() < MAX_MATERIALS, "too many prop materials");
                material_slot.push(Some((class, library.materials.len() as u8)));
                library.materials.push(rows);
            }
            None => material_slot.push(None),
        }
    }
    let meshes: Vec<MeshData> = json["meshes"]
        .as_array()
        .expect("meshes")
        .iter()
        .map(|m| {
            let count = m["vertices"].as_u64().unwrap() as usize;
            let off = |key: &str| m[key].as_i64().unwrap_or(-1);
            let pos: Vec<Vec3> = floats(&bin, off("pos"), count * 3).chunks(3).map(|c| Vec3::new(c[0], c[1], c[2])).collect();
            let normal: Vec<Vec3> = if off("normal") >= 0 { floats(&bin, off("normal"), count * 3).chunks(3).map(|c| Vec3::new(c[0], c[1], c[2])).collect() } else { vec![Vec3::Y; count] };
            let uv: Vec<Vec2> = if off("uv") >= 0 { floats(&bin, off("uv"), count * 2).chunks(2).map(|c| Vec2::new(c[0], c[1])).collect() } else { vec![Vec2::ZERO; count] };
            let colour: Vec<[f32; 4]> = if off("color") >= 0 { floats(&bin, off("color"), count * 4).chunks(4).map(|c| [c[0], c[1], c[2], c[3]]).collect() } else { vec![[1.0; 4]; count] };
            let indices: Vec<u32> = if off("index") >= 0 {
                let n = m["indices"].as_u64().unwrap() as usize;
                let start = off("index") as usize;
                bin[start..start + n * 4].chunks_exact(4).map(|b| u32::from_le_bytes([b[0], b[1], b[2], b[3]])).collect()
            } else {
                (0..count as u32).collect()
            };
            // Godot's front faces wind clockwise (closed meshes have negative counter-clockwise volume).
            let tris = indices.chunks_exact(3).map(|t| [t[0], t[2], t[1]]).collect();
            MeshData { pos, normal, uv, colour, tris, material: m["material"].as_u64().unwrap() as usize }
        })
        .collect();
    Scene { json, bin, meshes, material_slot }
}

fn transform(v: &[f32]) -> (Mat3, Vec3) {
    (Mat3::from_cols(Vec3::new(v[0], v[1], v[2]), Vec3::new(v[3], v[4], v[5]), Vec3::new(v[6], v[7], v[8])), Vec3::new(v[9], v[10], v[11]))
}

/// An object's world transforms and colours (one per instance, or the node's own).
fn instances_of(object: &serde_json::Value, bin: &[u8]) -> Vec<((Mat3, Vec3), [f32; 4])> {
    let node: Vec<f32> = object["transform"].as_array().unwrap().iter().map(|v| v.as_f64().unwrap() as f32).collect();
    let mut instances = Vec::new();
    match object.get("instances") {
        Some(list) if list.is_object() => {
            let count = list["count"].as_u64().unwrap() as usize;
            let all = floats(bin, list["transform"].as_i64().unwrap(), count * 12);
            let colours = list["color"].as_i64().filter(|&o| o >= 0).map(|o| floats(bin, o, count * 4));
            for i in 0..count {
                let tint = colours.as_ref().map_or([1.0; 4], |c| [c[i * 4], c[i * 4 + 1], c[i * 4 + 2], c[i * 4 + 3]]);
                instances.push((transform(&all[i * 12..i * 12 + 12]), tint));
            }
        }
        _ => instances.push((transform(&node), [1.0; 4])),
    }
    instances
}

fn mesh_list(object: &serde_json::Value) -> Vec<usize> {
    object["meshes"].as_array().unwrap().iter().map(|v| v.as_u64().unwrap() as usize).collect()
}

/// Bakes one instance (meshes, basis, world origin `at`, tint) into the library.
fn bake(library: &mut Library, scene: &Scene, meshes: &[usize], kind: &str, basis: Mat3, at: Vec3, tint: [f32; 4], report: &mut Report) {
    let normal_matrix = basis.inverse().transpose();
    let mirrored = basis.determinant() < 0.0;
    report.instances += 1;
    if kind == "lantern" {
        // decor_vertex_color.gdshader glows round (12.3, 0.56, -2.45) for a lantern placed
        // at (12.4, -2.35) on ground at 0: the lamp sits 0.56 m up, 0.1 m off its origin.
        // (Its constant height predates this layout's 1.5 m ground, so in the reference
        // the core never lit; here the centre follows the lantern.)
        library.lanterns.push(at + Vec3::new(-0.1, 0.56, -0.1));
    }
    if let Some(radius) = clear_radius(kind) {
        let size = basis.x_axis.length().max(basis.z_axis.length());
        report.clear.push((Vec2::new(at.x, at.z), radius * size));
    }
    for &mesh_index in meshes {
        let mesh = &scene.meshes[mesh_index];
        let Some((class, slot)) = scene.material_slot.get(mesh.material).copied().flatten() else {
            report.skipped_materials += 1;
            continue;
        };
        let world: Vec<Vec3> = mesh.pos.iter().map(|&v| basis * v + at).collect();
        // Leaf cards: the direction out of the crown, from the crown's bounding ellipsoid.
        let (centre, half) = if class == CLASS_LEAF {
            let (lo, hi) = world.iter().fold((Vec3::splat(f32::MAX), Vec3::splat(f32::MIN)), |(a, b), &p| (a.min(p), b.max(p)));
            ((lo + hi) * 0.5, ((hi - lo) * 0.5).max(Vec3::splat(0.05)))
        } else {
            (Vec3::ZERO, Vec3::ONE)
        };
        let bucket = &mut library.buckets[class as usize];
        for tri in &mesh.tris {
            let order = if mirrored { [tri[0], tri[2], tri[1]] } else { *tri };
            for &index in &order {
                let i = index as usize;
                let c = mesh.colour[i];
                let anchor = if class == CLASS_LEAF {
                    let d = (world[i] - centre) / half;
                    if d.length() < 1e-4 { Vec3::Y } else { d.normalize() }
                } else {
                    at
                };
                bucket.push(PropVertex {
                    pos: world[i].to_array(),
                    normal: (normal_matrix * mesh.normal[i]).normalize_or_zero().to_array(),
                    uv: mesh.uv[i].to_array(),
                    anchor: anchor.to_array(),
                    colour: [q(c[0] * tint[0]), q(c[1] * tint[1]), q(c[2] * tint[2]), q(c[3] * tint[3])],
                    mat: [class, slot, 0, 0],
                });
            }
        }
        report.triangles += mesh.tris.len();
    }
}

fn empty_report() -> Report {
    Report { objects: 0, instances: 0, triangles: 0, dropped: 0, dropped_by_kind: BTreeMap::new(), skipped_materials: 0, moved: 0, bedded: 0, shored: 0, clear: Vec::new(), scattered: false }
}

/// Loads one scene's props onto an island built from `cells` and `field`, moved by `origin`,
/// appending to `library`.
pub fn load(dir: &Path, cells: &Cells, field: &Field, origin: Vec3, library: &mut Library) -> Report {
    let scene = open(dir, library);
    let mut report = empty_report();
    let source = source_layout(dir).unwrap_or_else(|| cells.clone());
    let mut radius_at: BTreeMap<(i64, i64), f32> = BTreeMap::new();
    for object in scene.json["objects"].as_array().expect("objects") {
        if object["category"].as_str() != Some("on_top") {
            continue;
        }
        let meshes = mesh_list(object);
        for ((basis, at), _) in instances_of(object, &scene.bin) {
            let r = footprint(&scene, &meshes, basis);
            let slot = radius_at.entry(place_key(at)).or_insert(0.0);
            *slot = slot.max(r);
        }
    }
    for object in scene.json["objects"].as_array().expect("objects") {
        if object["category"].as_str() != Some("on_top") {
            continue;
        }
        let kind = object["kind"].as_str().unwrap_or("?").to_string();
        report.objects += 1;
        let on_water_kind = kind == "lily" || kind == "reeds";
        let meshes = mesh_list(object);
        for ((basis, at), tint) in instances_of(object, &scene.bin) {
            // Refit: keep the height above Godot's ground (the cell), stand on this tool's ground.
            let mut p = Vec2::new(at.x, at.z);
            let cell = cells.get(&(p.x.floor() as i32, p.y.floor() as i32)).copied();
            // The relaxed walls and the falls' notches do not follow the cell edges, so a prop that
            // stood clear in Godot can touch a wall face here: move it to the nearest clear lawn or
            // shore point within 1 m, or drop it.
            if !on_water_kind && cell.is_some_and(|c| c.water.is_none()) && field.inside(p) {
                // One decision per place: a tree's trunk and crown are two objects at one origin.
                let radius = radius_at[&place_key(at)];
                if touches_wall(field, p, radius) {
                    match nearest_clear(field, cells, p, radius) {
                        Some(q) => {
                            p = q;
                            report.moved += 1;
                        }
                        None => {
                            report.dropped += 1;
                            *report.dropped_by_kind.entry(format!("{kind} at a wall")).or_default() += 1;
                            continue;
                        }
                    }
                }
            }
            // Round r9: the height above Godot's own cell (from the scene's layout, so an edited
            // layout does not change it).
            let godot_h = source.get(&(at.x.floor() as i32, at.z.floor() as i32)).map(|c| c.h);
            let mut basis = basis;
            let new_y = match cell {
                Some(cell) if field.inside(p) => match cell.water {
                    Some(level) if on_water_kind => Some(level - crate::water::SINK + (at.y - level)),
                    _ => {
                        let lift = at.y - godot_h.unwrap_or(cell.h);
                        let radius = radius_at.get(&place_key(at)).copied().unwrap_or(0.3);
                        let ring: Vec<Vec2> = (0..8).map(|k| p + Vec2::from_angle(k as f32 * std::f32::consts::FRAC_PI_4) * radius * 0.8).collect();
                        let wet_ring = ring.iter().filter(|q| field.water_at(**q).is_some()).count();
                        let floating = |kind: &str| -> Option<(f32, f32, f32, f32)> {
                            if !is_stone(kind) || !(field.water_at(p).is_some() || wet_ring >= 5) {
                                return None;
                            }
                            let (low, high) = extent_y(&scene, &meshes, basis);
                            let size = (high - low).max(0.05);
                            let wet: Vec<Vec2> = std::iter::once(p).chain(ring.iter().copied()).filter(|q| field.water_at(*q).is_some()).collect();
                            let bed = wet.iter().map(|q| field.height_at(*q)).sum::<f32>() / wet.len().max(1) as f32;
                            let level = wet.iter().filter_map(|q| field.water_at(*q)).fold(f32::MIN, f32::max) - crate::water::SINK;
                            // Only a stone whose underside stands clear of the bed (it floats in the clear water).
                            let bottom = field.height_at(p) + lift + low;
                            (bottom - bed > 0.05 + 0.1 * size).then_some((low, size, bed, level))
                        };
                        if let Some((low, size, bed, level)) = floating(&kind) {
                            if level - bed > 0.6 * size {
                                match nearest_shore(field, cells, p, radius) {
                                    Some(q) => {
                                        p = q;
                                        report.shored += 1;
                                        Some(field.height_at(q) + lift.min(0.0))
                                    }
                                    None => None,
                                }
                            } else {
                                report.bedded += 1;
                                Some(bed - low - 0.04 * size)
                            }
                        } else if ring.iter().chain(std::iter::once(&p)).any(|q| field.slope_at(*q) != Vec2::ZERO) {
                            // Round r9: on a slope a tree (or anything upright) stays upright and sinks
                            // its base to the lowest ground under its footprint; stones, flowers and
                            // tufts tilt with the ground.
                            if is_upright(&kind) {
                                Some(ring.iter().chain(std::iter::once(&p)).map(|q| field.height_at(*q)).fold(f32::MAX, f32::min) + lift)
                            } else {
                                let n = field.ground_normal(p);
                                basis = Mat3::from_quat(glam::Quat::from_rotation_arc(Vec3::Y, n)) * basis;
                                Some(field.height_at(p) + lift)
                            }
                        } else {
                            Some(field.height_at(p) + lift)
                        }
                    }
                },
                _ => None,
            };
            let Some(new_y) = new_y else {
                report.dropped += 1;
                *report.dropped_by_kind.entry(kind.clone()).or_default() += 1;
                continue;
            };
            let world = Vec3::new(p.x, new_y, p.y) + origin;
            bake(library, &scene, &meshes, &kind, basis, world, tint, &mut report);
        }
    }
    // Clearings are in island coordinates.
    for c in report.clear.iter_mut() {
        c.0 -= Vec2::new(origin.x, origin.z);
    }
    report
}

/// The layout a scene was exported with (`scene_7301_0` -> `layout_7301_0.json`).
fn source_layout(dir: &Path) -> Option<Cells> {
    let name = dir.file_name()?.to_str()?.strip_prefix("scene_")?;
    let path = dir.parent()?.join(format!("layout_{name}.json"));
    path.exists().then(|| crate::field::load_layout(path.to_str().unwrap()))
}

/// Kinds that are stones: they tilt with a slope and rest on a pond's bed.
fn is_stone(kind: &str) -> bool {
    matches!(kind, "surface_rock" | "cliff_rock" | "shore_rock" | "shore_boulder" | "shore_pebble" | "path")
}

/// Kinds that stand upright whatever the ground does (they sink their base on a slope).
fn is_upright(kind: &str) -> bool {
    matches!(kind, "tree" | "tree_b" | "bamboo" | "bush" | "bench" | "lantern" | "scholar_rock")
}

/// The lowest and highest point of an instance's meshes above its origin.
fn extent_y(scene: &Scene, meshes: &[usize], basis: Mat3) -> (f32, f32) {
    let (mut low, mut high) = (f32::MAX, f32::MIN);
    for &index in meshes {
        for &v in &scene.meshes[index].pos {
            let y = (basis * v).y;
            low = low.min(y);
            high = high.max(y);
        }
    }
    if low > high {
        (0.0, 0.0)
    } else {
        (low, high)
    }
}

/// The nearest dry shore point within 2.5 m for a stone of `radius` (rings 0.1 m apart).
fn nearest_shore(field: &Field, cells: &Cells, p: Vec2, radius: f32) -> Option<Vec2> {
    for ring in 1..=25 {
        let r = ring as f32 * 0.1;
        for k in 0..32 {
            let q = p + Vec2::from_angle(k as f32 / 32.0 * std::f32::consts::TAU) * r;
            if field.water_at(q).is_none() && (0..8).all(|m| field.water_at(q + Vec2::from_angle(m as f32 * 0.785) * radius * 0.6).is_none()) && clear_spot(field, cells, q, radius) {
                return Some(q);
            }
        }
    }
    None
}

fn place_key(at: Vec3) -> (i64, i64) {
    ((at.x * 1000.0).round() as i64, (at.z * 1000.0).round() as i64)
}

/// The radius of what stands on the ground: the farthest vertex (from the origin, in plan) of the
/// part within 0.4 m of the base, so a tree counts its trunk and not its crown.
fn footprint(scene: &Scene, meshes: &[usize], basis: Mat3) -> f32 {
    let mut radius: f32 = 0.05;
    for &index in meshes {
        for &v in &scene.meshes[index].pos {
            let w = basis * v;
            if w.y < 0.4 {
                radius = radius.max(Vec2::new(w.x, w.z).length());
            }
        }
    }
    radius.min(1.2)
}

/// A footprint of `radius` at p touches a terrace wall (within 5 cm) or a fall's notch.
fn touches_wall(field: &Field, p: Vec2, radius: f32) -> bool {
    if field.nearest_wall(p, radius + 0.05).is_some() {
        return true;
    }
    (0..9).any(|k| {
        let q = if k == 8 { p } else {
            let angle = k as f32 * std::f32::consts::FRAC_PI_4;
            p + Vec2::new(angle.cos(), angle.sin()) * (radius + 0.05)
        };
        field.notch(q) > 0.01
    })
}

/// A lawn or shore point for a footprint of `radius`: off the walls and notches with 3 cm more to
/// spare, its centre on a dry cell inside the rim, on ground flat enough to stand on.
fn clear_spot(field: &Field, cells: &Cells, q: Vec2, radius: f32) -> bool {
    !touches_wall(field, q, radius + 0.03)
        && cells.get(&(q.x.floor() as i32, q.y.floor() as i32)).is_some_and(|c| c.water.is_none())
        && field.sample(&field.land1, q) > 0.85
        && field.ground_normal(q).y > 0.8
}

/// The nearest clear spot within 1 m of p (rings 0.1 m apart, 24 directions).
fn nearest_clear(field: &Field, cells: &Cells, p: Vec2, radius: f32) -> Option<Vec2> {
    for ring in 1..=10 {
        let r = ring as f32 * 0.1;
        for k in 0..24 {
            let angle = k as f32 / 24.0 * std::f32::consts::TAU;
            let q = p + Vec2::new(angle.cos(), angle.sin()) * r;
            if clear_spot(field, cells, q, radius) {
                return Some(q);
            }
        }
    }
    None
}

/// Where a new cluster of stones starts, as on the authored layouts: mostly on a pond's bank, at the
/// foot of a terrace wall or beside a tree group, now and then on open lawn.
fn rock_anchor(rng: &mut crate::mesh::Rng, bank: &[(i32, i32)], feet: &[Vec2], trees: &[Vec2], dry: &[(i32, i32)]) -> Vec2 {
    let pick = |rng: &mut crate::mesh::Rng, n: usize| (rng.next() * n as f32) as usize % n.max(1);
    let in_cell = |rng: &mut crate::mesh::Rng, k: (i32, i32)| Vec2::new(k.0 as f32 + rng.next(), k.1 as f32 + rng.next());
    let weights = [if bank.is_empty() { 0.0 } else { 0.35 }, if feet.is_empty() { 0.0 } else { 0.30 }, if trees.is_empty() { 0.0 } else { 0.25 }, 0.10];
    let mut roll = rng.next() * weights.iter().sum::<f32>();
    let mut choice = 3;
    for (i, w) in weights.iter().enumerate() {
        if roll < *w {
            choice = i;
            break;
        }
        roll -= w;
    }
    match choice {
        0 => {
            let k = bank[pick(rng, bank.len())];
            in_cell(rng, k)
        }
        1 => {
            let f = feet[pick(rng, feet.len())];
            f + Vec2::new(rng.range(-0.3, 0.3), rng.range(-0.3, 0.3))
        }
        2 => {
            let t = trees[pick(rng, trees.len())];
            let angle = rng.range(0.0, std::f32::consts::TAU);
            t + Vec2::new(angle.cos(), angle.sin()) * rng.range(1.2, 2.4)
        }
        _ => {
            let k = dry[pick(rng, dry.len())];
            in_cell(rng, k)
        }
    }
}

/// One placed example of a kind in the source scene: its meshes, basis, tint, and how high its
/// origin stood above its ground (the cell, or the water level for lilies and reeds).
#[derive(Clone)]
struct Example {
    meshes: Vec<usize>,
    basis: Mat3,
    tint: [f32; 4],
    lift: f32,
}

/// Kinds a scatter places, with where they go. The scene's unique pieces (the scholar's rock,
/// bench, lantern) and the authored stepping-stone path are not scattered.
#[derive(Clone, Copy, PartialEq)]
enum Ground {
    Lawn,
    Shore,
    Reed,
    Pond,
}

fn scatter_kind(kind: &str) -> Option<Ground> {
    Some(match kind {
        "tree" | "tree_b" | "bush" | "bamboo" | "surface_rock" | "cliff_rock" | "flower" | "grass_clump" => Ground::Lawn,
        "shore_rock" | "shore_boulder" | "shore_pebble" => Ground::Shore,
        "reeds" => Ground::Reed,
        "lily" => Ground::Pond,
        _ => return None,
    })
}

/// The exported Godot props of `dir` scattered over an island of any size (the synthetic
/// islands): every scatterable kind at the source layout's count per square metre of dry land (or
/// of water, for the shore and pond kinds), deterministic by seed. Trees keep off water, walls and
/// the rim and stand in loose groups with bushes round them; shore stones line the ponds; lilies
/// and reeds sit on the water. Each instance is one of the source's own (meshes, scale, tint), turned.
pub fn scatter(dir: &Path, cells: &Cells, field: &Field, origin: Vec3, seed: u32, library: &mut Library) -> Report {
    let scene = open(dir, library);
    let mut report = empty_report();
    report.scattered = true;
    // The source layout, for its areas and the examples' heights above their ground.
    let layout_path = dir.parent().unwrap().join(format!("layout_{}.json", dir.file_name().unwrap().to_str().unwrap().trim_start_matches("scene_")));
    let source = crate::field::load_layout(layout_path.to_str().unwrap());
    let source_dry = source.values().filter(|c| c.water.is_none()).count().max(1) as f32;
    let source_wet = source.values().filter(|c| c.water.is_some()).count().max(1) as f32;
    let mut examples: BTreeMap<String, Vec<Example>> = BTreeMap::new();
    let mut counts: BTreeMap<String, usize> = BTreeMap::new();
    // A tree is two objects (trunk and crown) with the same instance transforms: instances of one
    // kind at the same place are one example with all their meshes.
    let mut by_place: BTreeMap<(String, i64, i64, i64), (Example, Vec3)> = BTreeMap::new();
    for object in scene.json["objects"].as_array().expect("objects") {
        let kind = object["kind"].as_str().unwrap_or("?").to_string();
        if object["category"].as_str() != Some("on_top") || scatter_kind(&kind).is_none() {
            continue;
        }
        report.objects += 1;
        let meshes = mesh_list(object);
        for ((basis, at), tint) in instances_of(object, &scene.bin) {
            let key = (kind.clone(), (at.x * 1000.0).round() as i64, (at.y * 1000.0).round() as i64, (at.z * 1000.0).round() as i64);
            by_place
                .entry(key)
                .and_modify(|(e, _)| e.meshes.extend(meshes.iter().copied()))
                .or_insert((Example { meshes: meshes.clone(), basis, tint, lift: 0.0 }, at));
        }
    }
    for ((kind, ..), (mut example, at)) in by_place {
        *counts.entry(kind.clone()).or_default() += 1;
        let Some(cell) = source.get(&(at.x.floor() as i32, at.z.floor() as i32)) else { continue };
        example.lift = match (scatter_kind(&kind), cell.water) {
            (Some(Ground::Reed | Ground::Pond), Some(level)) => at.y - level,
            (Some(Ground::Reed | Ground::Pond), None) => continue,
            _ => at.y - cell.h,
        }
        .clamp(-0.3, 0.3);
        examples.entry(kind).or_default().push(example);
    }

    let mut keys: Vec<(i32, i32)> = cells.keys().copied().collect();
    keys.sort();
    let dry: Vec<(i32, i32)> = keys.iter().copied().filter(|k| cells[k].water.is_none()).collect();
    let wet: Vec<(i32, i32)> = keys.iter().copied().filter(|k| cells[k].water.is_some()).collect();
    // Dry cells beside water, and water cells beside land, for the shore kinds.
    let near = |k: &(i32, i32), want_water: bool| (-1..=1).any(|dz| (-1..=1).any(|dx| cells.get(&(k.0 + dx, k.1 + dz)).is_some_and(|c| c.water.is_some() == want_water)));
    let bank: Vec<(i32, i32)> = dry.iter().copied().filter(|k| near(k, true)).collect();
    let edge: Vec<(i32, i32)> = wet.iter().copied().filter(|k| near(k, false)).collect();
    let open_water: Vec<(i32, i32)> = wet.iter().copied().filter(|k| (-1..=1).all(|dz| (-1..=1).all(|dx| cells.get(&(k.0 + dx, k.1 + dz)).is_some_and(|c| c.water.is_some())))).collect();

    let mut placed: Vec<(Vec2, f32, usize)> = Vec::new();
    let mut trees: Vec<Vec2> = Vec::new();
    let kinds = ["tree", "tree_b", "bamboo", "bush", "surface_rock", "cliff_rock", "grass_clump", "flower", "shore_boulder", "shore_rock", "shore_pebble", "reeds", "lily"];
    let rock_kinds = [4usize, 5];
    // The feet of the terrace walls: 0.75 m out from the middle of each dry wall piece, on its low side.
    let wall_feet: Vec<Vec2> = field.steps.iter().filter(|s| s.wall() && !s.pond_wall() && s.low_water.is_none()).map(|s| (s.a + s.b) * 0.5 + (s.na + s.nb).normalize_or_zero() * 0.75).collect();
    for (index, kind) in kinds.iter().enumerate() {
        let Some(list) = examples.get(*kind) else { continue };
        if list.is_empty() {
            continue;
        }
        let ground = scatter_kind(kind).unwrap();
        let source_count = counts[*kind] as f32;
        let want = match ground {
            Ground::Lawn => source_count * dry.len() as f32 / source_dry,
            _ => source_count * wet.len() as f32 / source_wet,
        }
        .round() as usize;
        let pool: &Vec<(i32, i32)> = match ground {
            Ground::Lawn => &dry,
            Ground::Shore => &bank,
            Ground::Reed => &edge,
            Ground::Pond => &open_water,
        };
        if pool.is_empty() {
            continue;
        }
        // Spacing from what is already placed, and from walls and the rim.
        let (spacing, wall_clear): (f32, f32) = match *kind {
            "tree" | "tree_b" => (3.2, 1.6),
            "bamboo" => (2.4, 1.2),
            "bush" => (0.9, 0.6),
            "surface_rock" | "cliff_rock" => (1.2, 0.6),
            "shore_boulder" | "shore_rock" => (0.7, 0.3),
            "lily" => (0.5, 0.0),
            _ => (0.35, 0.3),
        };
        let mut rng = crate::mesh::Rng::new(seed, 900 + index as u32);
        let mut made = 0;
        let mut tries = 0;
        let rock = *kind == "surface_rock" || *kind == "cliff_rock";
        // Stones come in small clusters of mixed sizes (round r7): the current cluster's lead stone,
        // how many more it takes, and how many tries in a row have failed round it.
        let mut cluster: Option<(Vec2, usize, usize)> = None;
        while made < want && tries < want * 60 + 50 {
            tries += 1;
            let mut size = rng.range(0.9, 1.1);
            let p = if rock {
                match cluster {
                    Some((lead, left, _)) if left > 0 => {
                        let angle = rng.range(0.0, std::f32::consts::TAU);
                        size = rng.range(0.5, 0.85);
                        lead + Vec2::new(angle.cos(), angle.sin()) * rng.range(0.45, 1.1)
                    }
                    _ => {
                        cluster = None;
                        size = rng.range(1.0, 1.3);
                        rock_anchor(&mut rng, &bank, &wall_feet, &trees, &dry)
                    }
                }
            } else if (*kind == "bush" && rng.next() < 0.5 || (*kind == "tree" || *kind == "tree_b") && rng.next() < 0.6) && !trees.is_empty() {
                let t = trees[(rng.next() * trees.len() as f32) as usize % trees.len()];
                let angle = rng.range(0.0, std::f32::consts::TAU);
                let r = if *kind == "bush" { rng.range(1.0, 2.6) } else { rng.range(3.2, 5.0) };
                t + Vec2::new(angle.cos(), angle.sin()) * r
            } else {
                let k = pool[(rng.next() * pool.len() as f32) as usize % pool.len()];
                Vec2::new(k.0 as f32 + rng.next(), k.1 as f32 + rng.next())
            };
            let example = &list[(rng.next() * list.len() as f32) as usize % list.len()];
            let turn = Mat3::from_rotation_y(rng.range(0.0, std::f32::consts::TAU));
            let basis = turn * example.basis * size;
            let fail = |cluster: &mut Option<(Vec2, usize, usize)>| {
                if let Some(c) = cluster.as_mut() {
                    c.2 += 1;
                    if c.2 >= 8 {
                        *cluster = None;
                    }
                }
            };
            let Some(cell) = cells.get(&(p.x.floor() as i32, p.y.floor() as i32)).copied() else {
                fail(&mut cluster);
                continue;
            };
            let wet_k = field.sample(&field.wet, p);
            let ok = match ground {
                // Stones may sit on a pond's bank; their footprint keeps off walls and notches.
                Ground::Lawn if rock => {
                    cell.water.is_none() && wet_k < 0.45 && field.sample(&field.land1, p) > 0.9 && field.ground_normal(p).y > 0.8 && !touches_wall(field, p, footprint(&scene, &example.meshes, basis) + 0.08)
                }
                Ground::Lawn => cell.water.is_none() && wet_k < 0.05 && field.sample(&field.land1, p) > 0.93 && field.ground_normal(p).y > 0.85,
                // On the bank right at the waterline.
                Ground::Shore => cell.water.is_none() && wet_k > 0.12 && wet_k < 0.55 && field.sample(&field.land1, p) > 0.85,
                Ground::Reed => cell.water.is_some() && wet_k < 0.92 && wet_k > 0.55,
                Ground::Pond => cell.water.is_some() && wet_k > 0.98,
            };
            if !ok || (!rock && wall_clear > 0.0 && field.nearest_wall(p, wall_clear).is_some()) {
                fail(&mut cluster);
                continue;
            }
            // Round r9: no trees on a slope cell (or with a slope cell under their crown's foot).
            if matches!(&*kind.to_string(), "tree" | "tree_b") && (0..9).any(|k| field.slope_at(p + if k == 8 { Vec2::ZERO } else { Vec2::from_angle(k as f32 * 0.785) * 1.2 }) != Vec2::ZERO) {
                fail(&mut cluster);
                continue;
            }
            // Stones keep 0.5 m from one another (any stone kind) and a new cluster 3 m from the others.
            let starting = rock && cluster.is_none();
            let crowded = placed.iter().any(|&(q, r, k)| {
                let d = (q - p).length();
                if rock && rock_kinds.contains(&k) {
                    d < if starting { 3.0 } else { 0.5 }
                } else if k == index {
                    d < spacing.max(r)
                } else {
                    d < (spacing + r) * 0.25
                }
            });
            if crowded {
                fail(&mut cluster);
                continue;
            }
            let y = match ground {
                Ground::Reed | Ground::Pond => cell.water.unwrap() - crate::water::SINK + example.lift,
                _ => field.height_at(p) + if rock { example.lift * size } else { example.lift },
            };
            bake(library, &scene, &example.meshes, kind, basis, Vec3::new(p.x, y, p.y) + origin, example.tint, &mut report);
            placed.push((p, spacing, index));
            if rock {
                cluster = match cluster {
                    None => Some((p, 1 + (rng.next() * 4.0) as usize, 0)),
                    Some((lead, left, _)) => Some((lead, left.saturating_sub(1), 0)),
                };
            }
            if *kind == "tree" || *kind == "tree_b" || *kind == "bamboo" {
                trees.push(p);
            }
            made += 1;
        }
        if made < want {
            report.dropped += want - made;
            *report.dropped_by_kind.entry(kind.to_string()).or_default() += want - made;
        }
    }
    // Clearings are in island coordinates.
    for c in report.clear.iter_mut() {
        c.0 -= Vec2::new(origin.x, origin.z);
    }
    report
}
