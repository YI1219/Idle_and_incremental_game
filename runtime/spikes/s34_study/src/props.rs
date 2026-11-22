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
    let suffix = stem.strip_prefix("layout_")?;
    Some(path.parent()?.join(format!("scene_{suffix}")))
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
            "PROPS loaded {} objects, {} instances, {} triangles, {} dropped{} from {}{}",
            self.objects,
            self.instances,
            self.triangles,
            self.dropped,
            if kinds.is_empty() { String::new() } else { format!(" ({})", kinds.join(", ")) },
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

/// Loads one scene's props onto an island built from `cells` and `field`, moved by `origin`,
/// appending to `library`.
pub fn load(dir: &Path, cells: &Cells, field: &Field, origin: Vec3, library: &mut Library) -> Report {
    let json_path = dir.join("scene.json");
    let text = std::fs::read_to_string(&json_path).unwrap_or_else(|e| panic!("cannot read {}: {e}", json_path.display()));
    let scene: serde_json::Value = serde_json::from_str(&text).expect("scene json");
    let bin = std::fs::read(dir.join("scene.bin")).expect("scene.bin");
    if library.texture_dir.is_none() {
        library.texture_dir = Some(dir.join("textures"));
    }

    // Materials: class and table index (offset into the shared table).
    let mut material_slot: Vec<Option<(u8, u8)>> = Vec::new();
    for material in scene["materials"].as_array().expect("materials") {
        match material_rows(material) {
            Some((class, rows)) => {
                assert!(library.materials.len() < MAX_MATERIALS, "too many prop materials");
                material_slot.push(Some((class, library.materials.len() as u8)));
                library.materials.push(rows);
            }
            None => material_slot.push(None),
        }
    }

    let meshes: Vec<MeshData> = scene["meshes"]
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

    let mut report = Report { objects: 0, instances: 0, triangles: 0, dropped: 0, dropped_by_kind: BTreeMap::new(), skipped_materials: 0, clear: Vec::new() };
    let transform = |v: &[f32]| -> (Mat3, Vec3) { (Mat3::from_cols(Vec3::new(v[0], v[1], v[2]), Vec3::new(v[3], v[4], v[5]), Vec3::new(v[6], v[7], v[8])), Vec3::new(v[9], v[10], v[11])) };
    for object in scene["objects"].as_array().expect("objects") {
        if object["category"].as_str() != Some("on_top") {
            continue;
        }
        let kind = object["kind"].as_str().unwrap_or("?").to_string();
        let node: Vec<f32> = object["transform"].as_array().unwrap().iter().map(|v| v.as_f64().unwrap() as f32).collect();
        // Per-instance world transforms and colours.
        let mut instances: Vec<((Mat3, Vec3), [f32; 4])> = Vec::new();
        match object.get("instances") {
            Some(list) if list.is_object() => {
                let count = list["count"].as_u64().unwrap() as usize;
                let all = floats(&bin, list["transform"].as_i64().unwrap(), count * 12);
                let colours = list["color"].as_i64().filter(|&o| o >= 0).map(|o| floats(&bin, o, count * 4));
                for i in 0..count {
                    let tint = colours.as_ref().map_or([1.0; 4], |c| [c[i * 4], c[i * 4 + 1], c[i * 4 + 2], c[i * 4 + 3]]);
                    instances.push((transform(&all[i * 12..i * 12 + 12]), tint));
                }
            }
            _ => instances.push((transform(&node), [1.0; 4])),
        }
        report.objects += 1;
        let on_water_kind = kind == "lily" || kind == "reeds";
        for ((basis, at), tint) in instances {
            // Refit: keep the height above Godot's ground (the cell), stand on this tool's ground.
            let p = Vec2::new(at.x, at.z);
            let cell = cells.get(&(p.x.floor() as i32, p.y.floor() as i32));
            let new_y = match cell {
                Some(cell) if field.inside(p) => match cell.water {
                    Some(level) if on_water_kind => Some(level - crate::water::SINK + (at.y - level)),
                    _ => Some(field.height_at(p) + (at.y - cell.h)),
                },
                _ => None,
            };
            let Some(new_y) = new_y else {
                report.dropped += 1;
                *report.dropped_by_kind.entry(kind.clone()).or_default() += 1;
                continue;
            };
            let shift = Vec3::new(0.0, new_y - at.y, 0.0) + origin;
            let normal_matrix = basis.inverse().transpose();
            let mirrored = basis.determinant() < 0.0;
            report.instances += 1;
            if let Some(radius) = clear_radius(&kind) {
                let size = basis.x_axis.length().max(basis.z_axis.length());
                report.clear.push((p, radius * size));
            }
            for &mesh_index in object["meshes"].as_array().unwrap().iter().map(|v| v.as_u64().unwrap() as usize).collect::<Vec<_>>().iter() {
                let mesh = &meshes[mesh_index];
                let Some((class, slot)) = material_slot.get(mesh.material).copied().flatten() else {
                    report.skipped_materials += 1;
                    continue;
                };
                let world: Vec<Vec3> = mesh.pos.iter().map(|&v| basis * v + at + shift).collect();
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
                            at + shift
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
    }
    report
}
