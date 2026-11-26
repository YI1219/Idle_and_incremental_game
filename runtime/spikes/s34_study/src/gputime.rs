//! Round k5: GPU timestamps per render pass for the window mode (window.rs). Each pass writes a
//! timestamp at its start and its end (wgpu `RenderPassTimestampWrites`; on Metal these are
//! sampled at stage boundaries: start of the vertex stage, end of the fragment stage).
//!
//! The queries of frame N are resolved in the command encoder of frame N + `DELAY`, not in their
//! own: on Metal the resolve (a blit) has no resource dependency on the frame's last pass, which
//! writes only the drawable, so a resolve in the same command buffer can run before that pass ends
//! and read a stale end time (seen: the FXAA pass "ending" 66 ms before it began, eight frames
//! back). Results are read back a few frames later without waiting, so timing never stalls the
//! frame loop. A frame whose ring slot is still busy is simply not timed.
use std::cell::{Cell, RefCell};
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::Arc;

/// Queries per frame (two per pass; a frame has at most about 16 passes).
const PER_FRAME: u32 = 64;
const SLOTS: usize = 16;
/// Frames between writing a frame's queries and resolving them.
const DELAY: u64 = 2;
const FREE: u8 = 0;
const WRITTEN: u8 = 1;
const PENDING: u8 = 2;
const READY: u8 = 3;

struct Slot {
    readback: wgpu::Buffer,
    state: Arc<AtomicU8>,
    frame: u64,
    count: u32,
    labels: Vec<&'static str>,
}

/// One timed frame: its id and (pass, start, end) in nanoseconds on the GPU's clock.
pub struct Timed {
    pub frame: u64,
    pub passes: Vec<(&'static str, f64, f64)>,
}

pub struct GpuTimer {
    set: wgpu::QuerySet,
    resolve: wgpu::Buffer,
    slots: RefCell<Vec<Slot>>,
    period_ns: f64,
    /// The slot this frame writes into, if any, and the frame's number.
    current: Cell<Option<usize>>,
    frame: Cell<u64>,
    next: Cell<usize>,
    labels: RefCell<Vec<&'static str>>,
    /// Slots resolved in this frame's encoder, to be mapped after its submit.
    resolving: RefCell<Vec<usize>>,
}

impl GpuTimer {
    /// None when the device was not given TIMESTAMP_QUERY.
    pub fn new(device: &wgpu::Device, queue: &wgpu::Queue) -> Option<GpuTimer> {
        if !device.features().contains(wgpu::Features::TIMESTAMP_QUERY) {
            return None;
        }
        let total = PER_FRAME * SLOTS as u32;
        let set = device.create_query_set(&wgpu::QuerySetDescriptor { label: Some("pass times"), ty: wgpu::QueryType::Timestamp, count: total });
        let resolve = device.create_buffer(&wgpu::BufferDescriptor { label: Some("pass times resolve"), size: total as u64 * 8, usage: wgpu::BufferUsages::QUERY_RESOLVE | wgpu::BufferUsages::COPY_SRC, mapped_at_creation: false });
        let slots = (0..SLOTS)
            .map(|_| Slot {
                readback: device.create_buffer(&wgpu::BufferDescriptor { label: Some("pass times readback"), size: PER_FRAME as u64 * 8, usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST, mapped_at_creation: false }),
                state: Arc::new(AtomicU8::new(FREE)),
                frame: 0,
                count: 0,
                labels: Vec::new(),
            })
            .collect();
        Some(GpuTimer {
            set,
            resolve,
            slots: RefCell::new(slots),
            period_ns: queue.get_timestamp_period() as f64,
            current: Cell::new(None),
            frame: Cell::new(0),
            next: Cell::new(0),
            labels: RefCell::new(Vec::new()),
            resolving: RefCell::new(Vec::new()),
        })
    }

    /// Starts timing frame `frame` in its ring slot (busy: the frame is not timed).
    pub fn begin_frame(&self, frame: u64) {
        let index = (frame as usize) % SLOTS;
        let free = self.slots.borrow()[index].state.load(Ordering::Acquire) == FREE;
        self.current.set(free.then_some(index));
        self.frame.set(frame);
        self.next.set(0);
        self.labels.borrow_mut().clear();
    }

    /// The timestamp writes for one pass of the current frame.
    pub fn pass(&self, label: &'static str) -> Option<wgpu::RenderPassTimestampWrites<'_>> {
        let slot = self.current.get()?;
        let n = self.next.get();
        if (n as u32 + 2) > PER_FRAME {
            return None;
        }
        self.next.set(n + 2);
        self.labels.borrow_mut().push(label);
        let base = slot as u32 * PER_FRAME + n as u32;
        Some(wgpu::RenderPassTimestampWrites { query_set: &self.set, beginning_of_pass_write_index: Some(base), end_of_pass_write_index: Some(base + 1) })
    }

    fn resolve_slot(&self, encoder: &mut wgpu::CommandEncoder, slots: &[Slot], index: usize) {
        let base = index as u32 * PER_FRAME;
        let n = slots[index].count;
        encoder.resolve_query_set(&self.set, base..base + n, &self.resolve, base as u64 * 8);
        encoder.copy_buffer_to_buffer(&self.resolve, base as u64 * 8, &slots[index].readback, 0, n as u64 * 8);
        self.resolving.borrow_mut().push(index);
    }

    /// Ends the current frame's queries and resolves those written `DELAY` or more frames ago.
    pub fn end_frame(&self, encoder: &mut wgpu::CommandEncoder) {
        let mut slots = self.slots.borrow_mut();
        if let Some(index) = self.current.take() {
            let n = self.next.get() as u32;
            if n > 0 {
                let s = &mut slots[index];
                s.frame = self.frame.get();
                s.count = n;
                s.labels = self.labels.borrow().clone();
                s.state.store(WRITTEN, Ordering::Release);
            }
        }
        let now = self.frame.get();
        for index in 0..SLOTS {
            if slots[index].state.load(Ordering::Acquire) == WRITTEN && slots[index].frame + DELAY <= now {
                self.resolve_slot(encoder, &slots, index);
            }
        }
    }

    /// Resolves every written slot (end of a run; the caller submits and waits).
    pub fn flush(&self, encoder: &mut wgpu::CommandEncoder) {
        let slots = self.slots.borrow();
        for index in 0..SLOTS {
            if slots[index].state.load(Ordering::Acquire) == WRITTEN {
                self.resolve_slot(encoder, &slots, index);
            }
        }
    }

    /// After the submit that carried the resolves: asks for their read-back.
    pub fn after_submit(&self) {
        let slots = self.slots.borrow();
        for index in self.resolving.borrow_mut().drain(..) {
            let s = &slots[index];
            s.state.store(PENDING, Ordering::Release);
            let state = s.state.clone();
            s.readback.slice(..s.count as u64 * 8).map_async(wgpu::MapMode::Read, move |result| {
                state.store(if result.is_ok() { READY } else { FREE }, Ordering::Release);
            });
        }
    }

    /// The frames whose times have arrived (call after a non-blocking device poll).
    pub fn collect(&self) -> Vec<Timed> {
        let mut out = Vec::new();
        let mut slots = self.slots.borrow_mut();
        for s in slots.iter_mut() {
            if s.state.load(Ordering::Acquire) != READY {
                continue;
            }
            {
                let data = s.readback.slice(..s.count as u64 * 8).get_mapped_range().expect("mapped times");
                let ticks: Vec<u64> = data.chunks_exact(8).map(|c| u64::from_le_bytes(c.try_into().unwrap())).collect();
                let passes = s.labels.iter().enumerate().map(|(i, label)| (*label, ticks[i * 2] as f64 * self.period_ns, ticks[i * 2 + 1] as f64 * self.period_ns)).collect();
                out.push(Timed { frame: s.frame, passes });
            }
            s.readback.unmap();
            s.state.store(FREE, Ordering::Release);
        }
        out
    }
}
