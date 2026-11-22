//! Baked vertex format and small mesh-building helpers shared by the studies.
use glam::Vec3;

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct Vertex {
    pub pos: [f32; 3],
    pub normal: [f32; 3],
    /// rgb wash colour, a = material family / 3.
    pub colour: [u8; 4],
    /// r = baked sky occlusion, g = bounce, b = line importance, a = paint weight (strokes).
    pub terms: [u8; 4],
    /// r = surface id for line breaks, g = vertical gradient coordinate, b = sway weight, a spare.
    pub extra: [u8; 4],
}

#[derive(Clone, Copy, PartialEq)]
pub enum Family {
    Ground = 0,
    Stone = 85,
    Leaf = 170,
    Wood = 255,
}

pub fn q(v: f32) -> u8 {
    (v.clamp(0.0, 1.0) * 255.0 + 0.5) as u8
}

/// What a surface carries besides its place and colour.
#[derive(Clone, Copy)]
pub struct Paint {
    pub family: Family,
    pub sky: f32,
    pub bounce: f32,
    pub line: f32,
    pub strokes: f32,
    pub id: u8,
    pub grad: f32,
}

impl Paint {
    pub fn new(family: Family) -> Paint {
        // grad 0.5 is neutral; hanging rock runs 0 at its top to 1 at its foot.
        Paint { family, sky: 1.0, bounce: 0.3, line: 1.0, strokes: 0.0, id: 0, grad: 0.5 }
    }
    pub fn sky(mut self, v: f32) -> Paint {
        self.sky = v;
        self
    }
    pub fn line(mut self, v: f32) -> Paint {
        self.line = v;
        self
    }
    pub fn strokes(mut self, v: f32) -> Paint {
        self.strokes = v;
        self
    }
    pub fn id(mut self, v: u8) -> Paint {
        self.id = v;
        self
    }
    pub fn grad(mut self, v: f32) -> Paint {
        self.grad = v;
        self
    }
}

#[derive(Default)]
pub struct Mesh {
    pub vertices: Vec<Vertex>,
}

impl Mesh {
    pub fn vertex(&mut self, p: Vec3, n: Vec3, colour: Vec3, paint: Paint) {
        self.vertices.push(Vertex {
            pos: p.to_array(),
            normal: n.to_array(),
            colour: [q(colour.x), q(colour.y), q(colour.z), paint.family as u8],
            terms: [q(paint.sky), q(paint.bounce), q(paint.line), q(paint.strokes)],
            extra: [paint.id, q(paint.grad), 0, 0],
        });
    }

    /// Flat triangle; the normal comes from the winding (counter-clockwise seen from outside).
    pub fn tri(&mut self, a: Vec3, b: Vec3, c: Vec3, colour: Vec3, paint: Paint) {
        let mut n = (b - a).cross(c - a).normalize_or_zero();
        if n == Vec3::ZERO {
            n = Vec3::Y;
        }
        for p in [a, b, c] {
            self.vertex(p, n, colour, paint);
        }
    }

    pub fn quad(&mut self, a: Vec3, b: Vec3, c: Vec3, d: Vec3, colour: Vec3, paint: Paint) {
        self.tri(a, b, c, colour, paint);
        self.tri(a, c, d, colour, paint);
    }

    /// Triangle with its own normals, colours and paints per corner.
    pub fn tri_full(&mut self, p: [Vec3; 3], n: [Vec3; 3], colour: [Vec3; 3], paint: [Paint; 3]) {
        for i in 0..3 {
            self.vertex(p[i], n[i], colour[i], paint[i]);
        }
    }

    pub fn append(&mut self, other: &Mesh) {
        self.vertices.extend_from_slice(&other.vertices);
    }

    pub fn offset(&mut self, by: Vec3) {
        for vertex in &mut self.vertices {
            vertex.pos = (Vec3::from_array(vertex.pos) + by).to_array();
        }
    }

    pub fn triangles(&self) -> usize {
        self.vertices.len() / 3
    }
}

pub fn hash2(x: i32, z: i32, seed: u32) -> f32 {
    let mut h = (x as u32).wrapping_mul(0x9E37_79B1) ^ (z as u32).wrapping_mul(0x85EB_CA77) ^ seed.wrapping_mul(0xC2B2_AE3D);
    h ^= h >> 15;
    h = h.wrapping_mul(0x2C1B_3C6D);
    h ^= h >> 12;
    h = h.wrapping_mul(0x297A_2D39);
    h ^= h >> 15;
    (h & 0x00FF_FFFF) as f32 / 16_777_216.0
}

pub fn vnoise(x: f32, z: f32, seed: u32) -> f32 {
    let (x0, z0) = (x.floor(), z.floor());
    let (fx, fz) = (x - x0, z - z0);
    let (sx, sz) = (fx * fx * (3.0 - 2.0 * fx), fz * fz * (3.0 - 2.0 * fz));
    let (ix, iz) = (x0 as i32, z0 as i32);
    let a = hash2(ix, iz, seed);
    let b = hash2(ix + 1, iz, seed);
    let c = hash2(ix, iz + 1, seed);
    let d = hash2(ix + 1, iz + 1, seed);
    a + (b - a) * sx + (c - a) * sz + (a - b - c + d) * sx * sz
}

pub struct Rng(pub u64);
impl Rng {
    pub fn new(seed: u32, salt: u32) -> Rng {
        Rng((0x9E37_79B9_7F4A_7C15u64 ^ ((seed as u64) << 32) ^ ((salt as u64) << 8)) | 1)
    }
    pub fn next(&mut self) -> f32 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        ((self.0 >> 40) as f32) / 16_777_216.0
    }
    pub fn range(&mut self, low: f32, high: f32) -> f32 {
        low + (high - low) * self.next()
    }
}

pub fn smoothstep(a: f32, b: f32, x: f32) -> f32 {
    let t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// Unit icosphere triangles (level 1: 80, level 2: 320).
pub fn icosphere(level: u32) -> Vec<[Vec3; 3]> {
    let t = (1.0 + 5.0_f32.sqrt()) / 2.0;
    let v: Vec<Vec3> = [
        (-1.0, t, 0.0), (1.0, t, 0.0), (-1.0, -t, 0.0), (1.0, -t, 0.0), (0.0, -1.0, t), (0.0, 1.0, t),
        (0.0, -1.0, -t), (0.0, 1.0, -t), (t, 0.0, -1.0), (t, 0.0, 1.0), (-t, 0.0, -1.0), (-t, 0.0, 1.0),
    ]
    .iter()
    .map(|&(x, y, z)| Vec3::new(x, y, z).normalize())
    .collect();
    let faces = [
        [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
        [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
    ];
    let mut tris: Vec<[Vec3; 3]> = faces.iter().map(|f| [v[f[0]], v[f[1]], v[f[2]]]).collect();
    for _ in 0..level {
        let mut next = Vec::with_capacity(tris.len() * 4);
        for [a, b, c] in tris {
            let ab = ((a + b) * 0.5).normalize();
            let bc = ((b + c) * 0.5).normalize();
            let ca = ((c + a) * 0.5).normalize();
            next.extend([[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]);
        }
        tris = next;
    }
    tris
}
