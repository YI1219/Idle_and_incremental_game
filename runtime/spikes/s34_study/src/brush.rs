//! Round k5: the terrain and item tools as the runtime's edit commands (plan 2.3: TerrainStroke
//! expand | contract | raise | lower, RampStroke, Place, Remove; and the water and dry brushes of
//! the frozen editor, since the spring model of plan 3.8 is not built yet).
//!
//! A stroke is what an interactive tool hands over when the button is released: the pointer's path
//! over the island (points in island coordinates, as the picking layer would deliver them), the
//! brush radius and the tool's own settings. The rules follow the frozen Godot editor's
//! `terrain_data.gd` `apply_brush`: a round brush (cells whose centre lies within the radius of a
//! brush position), applied at steps along the path, each cell changed at most once per stroke;
//! raise and lower by 0.5 m (heights -4 to 12 m); expand adds cells at the stroke's build height (the
//! ground under its first point, in 0.5 m steps); contract removes cells; water sets a level on the
//! cells under it that lie lower; dry clears water. Ramp, place and remove are the plan's commands.
//! This is the one path every edit takes, whether it comes from a mouse or from a replayed script.

use std::collections::HashSet;

use glam::Vec2;

use crate::field::{self, Cell, Cells};
use crate::props::{Items, Library, Placement};

/// The most cells an island may have (plan 2.3).
pub const MAX_CELLS: usize = 4096;

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Tool {
    Raise,
    Lower,
    Expand,
    Contract,
    Water,
    Dry,
    Ramp,
    Place,
    Remove,
}

impl Tool {
    pub fn parse(name: &str) -> Option<Tool> {
        Some(match name {
            "raise" => Tool::Raise,
            "lower" => Tool::Lower,
            "expand" => Tool::Expand,
            "contract" => Tool::Contract,
            "water" => Tool::Water,
            "dry" => Tool::Dry,
            "ramp" => Tool::Ramp,
            "place" => Tool::Place,
            "remove" => Tool::Remove,
            _ => return None,
        })
    }

    pub fn name(self) -> &'static str {
        match self {
            Tool::Raise => "raise",
            Tool::Lower => "lower",
            Tool::Expand => "expand",
            Tool::Contract => "contract (erase)",
            Tool::Water => "water",
            Tool::Dry => "dry",
            Tool::Ramp => "ramp",
            Tool::Place => "place",
            Tool::Remove => "remove item",
        }
    }
}

/// One stroke.
#[derive(Clone)]
pub struct Stroke {
    pub tool: Tool,
    /// The pointer's path, island coordinates (x, z).
    pub path: Vec<Vec2>,
    /// Brush radius (terrain tools, remove), metres.
    pub radius: f32,
    /// Water: the level to fill to (absolute height).
    pub level: f32,
    /// Ramp: the strip's width.
    pub width: f32,
    /// Place: the item put at each point of the path (its `at` is replaced by the point).
    pub item: Option<Placement>,
}

/// What a stroke did.
pub struct Outcome {
    /// Cells changed (terrain), items placed or removed.
    pub changed: usize,
    /// The rectangle it touched (island coordinates), for the settle map.
    pub lo: Vec2,
    pub hi: Vec2,
    /// Where the stroke was (the ripple's centre).
    pub centre: Vec2,
    /// Items it placed (they grow in).
    pub placed: Vec<Placement>,
    /// Why it did nothing, if it did nothing.
    pub refused: Option<String>,
}

/// Brush positions along a path: every point, with steps between them a third of the radius apart
/// (the frozen editor spaces its brush applications the same way while dragging).
fn dabs(path: &[Vec2], radius: f32) -> Vec<Vec2> {
    let mut out = Vec::new();
    let spacing = (radius / 3.0).max(0.25);
    for (i, &p) in path.iter().enumerate() {
        if i == 0 {
            out.push(p);
            continue;
        }
        let start = path[i - 1];
        let steps = ((p - start).length() / spacing).ceil().max(1.0) as usize;
        for s in 1..=steps {
            out.push(start.lerp(p, s as f32 / steps as f32));
        }
    }
    out
}

/// The cell under a point.
fn cell_of(p: Vec2) -> (i32, i32) {
    (p.x.floor() as i32, p.y.floor() as i32)
}

/// The stroke's build height for expand: the ground under its first point, or under the nearest
/// cell when it starts off the island, in 0.5 m steps.
fn build_height(cells: &Cells, p: Vec2) -> f32 {
    let h = match cells.get(&cell_of(p)) {
        Some(c) => c.h,
        None => cells
            .iter()
            .min_by(|a, b| {
                let da = (Vec2::new(a.0 .0 as f32 + 0.5, a.0 .1 as f32 + 0.5) - p).length_squared();
                let db = (Vec2::new(b.0 .0 as f32 + 0.5, b.0 .1 as f32 + 0.5) - p).length_squared();
                da.partial_cmp(&db).unwrap()
            })
            .map_or(0.0, |(_, c)| c.h),
    };
    ((h * 2.0).round() * 0.5).clamp(-4.0, 12.0)
}

fn nothing(why: &str, centre: Vec2) -> Outcome {
    Outcome { changed: 0, lo: centre, hi: centre, centre, placed: Vec::new(), refused: Some(why.to_string()) }
}

/// Applies one stroke to the island's cells and items. `library` is the island as built before the
/// stroke (remove picks the items standing under the brush from it).
pub fn apply(cells: &mut Cells, items: &mut Items, library: &Library, stroke: &Stroke) -> Outcome {
    let Some(&first) = stroke.path.first() else { return nothing("empty path", Vec2::ZERO) };
    let last = *stroke.path.last().unwrap();
    let centre = stroke.path.iter().copied().sum::<Vec2>() / stroke.path.len() as f32;
    let radius = stroke.radius.clamp(0.1, 16.0);
    match stroke.tool {
        Tool::Raise | Tool::Lower | Tool::Expand | Tool::Contract | Tool::Water | Tool::Dry => {
            let height = build_height(cells, first);
            let mut visited: HashSet<(i32, i32)> = HashSet::new();
            let mut changed = 0;
            let (mut lo, mut hi) = (Vec2::splat(f32::MAX), Vec2::splat(f32::MIN));
            for dab in dabs(&stroke.path, radius) {
                for z in (dab.y - radius).floor() as i32..(dab.y + radius).ceil() as i32 {
                    for x in (dab.x - radius).floor() as i32..(dab.x + radius).ceil() as i32 {
                        let key = (x, z);
                        if (Vec2::new(x as f32 + 0.5, z as f32 + 0.5) - dab).length() > radius || visited.contains(&key) {
                            continue;
                        }
                        visited.insert(key);
                        let old = cells.get(&key).copied();
                        let next: Option<Cell> = match stroke.tool {
                            Tool::Expand => match old {
                                None if cells.len() < MAX_CELLS => Some(Cell::flat(height, None)),
                                other => other,
                            },
                            Tool::Contract => None,
                            Tool::Raise | Tool::Lower => old.map(|mut c| {
                                c.h = (c.h + if stroke.tool == Tool::Raise { 0.5 } else { -0.5 }).clamp(-4.0, 12.0);
                                if c.water.is_some_and(|w| c.h >= w) {
                                    c.water = None;
                                }
                                c
                            }),
                            Tool::Water => old.map(|mut c| {
                                if !c.sloped() && c.h < stroke.level {
                                    c.water = Some(stroke.level);
                                }
                                c
                            }),
                            Tool::Dry => old.map(|mut c| {
                                c.water = None;
                                c
                            }),
                            _ => old,
                        };
                        let same = match (old, next) {
                            (None, None) => true,
                            (Some(a), Some(b)) => a.h == b.h && a.water == b.water && a.slope == b.slope,
                            _ => false,
                        };
                        if same {
                            continue;
                        }
                        match next {
                            Some(c) => {
                                cells.insert(key, c);
                            }
                            None => {
                                cells.remove(&key);
                            }
                        }
                        changed += 1;
                        let p = Vec2::new(x as f32, z as f32);
                        lo = lo.min(p);
                        hi = hi.max(p + Vec2::ONE);
                    }
                }
            }
            if changed == 0 {
                return nothing("no cell changed", centre);
            }
            Outcome { changed, lo, hi, centre, placed: Vec::new(), refused: None }
        }
        Tool::Ramp => match field::ramp(cells, first, last, stroke.width) {
            Ok(done) => {
                let (lo, hi) = (done.a.min(done.b) - Vec2::splat(stroke.width), done.a.max(done.b) + Vec2::splat(stroke.width));
                Outcome { changed: done.cells, lo, hi, centre: (done.a + done.b) * 0.5, placed: Vec::new(), refused: None }
            }
            Err(e) => nothing(&e.to_string(), centre),
        },
        Tool::Place => {
            let Some(template) = stroke.item else { return nothing("no item", centre) };
            let mut placed = Vec::new();
            for &p in &stroke.path {
                match cells.get(&cell_of(p)) {
                    Some(c) if c.water.is_none() => {
                        let item = Placement { at: p, ..template };
                        items.placed.push(item);
                        placed.push(item);
                    }
                    _ => {}
                }
            }
            if placed.is_empty() {
                return nothing("no dry land under the points", centre);
            }
            let lo = placed.iter().fold(Vec2::splat(f32::MAX), |m, e| m.min(e.at)) - Vec2::splat(1.0);
            let hi = placed.iter().fold(Vec2::splat(f32::MIN), |m, e| m.max(e.at)) + Vec2::splat(1.0);
            Outcome { changed: placed.len(), lo, hi, centre, placed, refused: None }
        }
        Tool::Remove => {
            let mut changed = 0;
            let (mut lo, mut hi) = (Vec2::splat(f32::MAX), Vec2::splat(f32::MIN));
            for inst in &library.instances {
                let p = Vec2::new(inst.origin.x, inst.origin.z);
                if stroke.path.iter().any(|q| (*q - p).length() <= radius) && !items.removed.iter().any(|r| (*r - inst.source).length() < 0.02) {
                    items.removed.push(inst.source);
                    changed += 1;
                    lo = lo.min(p - Vec2::splat(1.5));
                    hi = hi.max(p + Vec2::splat(1.5));
                }
            }
            if changed == 0 {
                return nothing("no item under the brush", centre);
            }
            Outcome { changed, lo, hi, centre, placed: Vec::new(), refused: None }
        }
    }
}
