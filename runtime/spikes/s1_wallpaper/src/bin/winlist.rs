//! Spike S1 helper: prints, front to back, the on-screen windows at desktop-like
//! levels and every window of one process, so the test can see where the
//! wallpaper window sits relative to the Finder's icon window and the system
//! picture. Also prints the main display's mode. Window metadata needs no
//! screen-recording permission; window pictures would.
//!
//!   winlist PID
#![cfg(target_os = "macos")]
use std::ffi::{c_char, c_void, CStr};

#[repr(C)]
#[derive(Default)]
struct CGRect {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
}

#[link(name = "CoreGraphics", kind = "framework")]
extern "C" {
    fn CGWindowListCopyWindowInfo(option: u32, relative_to: u32) -> *const c_void;
    static kCGWindowOwnerPID: *const c_void;
    static kCGWindowOwnerName: *const c_void;
    static kCGWindowLayer: *const c_void;
    static kCGWindowBounds: *const c_void;
    fn CGRectMakeWithDictionaryRepresentation(dict: *const c_void, rect: *mut CGRect) -> bool;
    fn CGMainDisplayID() -> u32;
    fn CGDisplayPixelsWide(display: u32) -> usize;
    fn CGDisplayPixelsHigh(display: u32) -> usize;
    fn CGDisplayCopyDisplayMode(display: u32) -> *const c_void;
    fn CGDisplayModeGetPixelWidth(mode: *const c_void) -> usize;
    fn CGDisplayModeGetPixelHeight(mode: *const c_void) -> usize;
    fn CGDisplayModeGetRefreshRate(mode: *const c_void) -> f64;
    fn CGDisplayModeRelease(mode: *const c_void);
}

#[link(name = "CoreFoundation", kind = "framework")]
extern "C" {
    fn CFArrayGetCount(array: *const c_void) -> isize;
    fn CFArrayGetValueAtIndex(array: *const c_void, index: isize) -> *const c_void;
    fn CFDictionaryGetValue(dict: *const c_void, key: *const c_void) -> *const c_void;
    fn CFNumberGetValue(number: *const c_void, the_type: isize, out: *mut c_void) -> bool;
    fn CFStringGetCString(string: *const c_void, buffer: *mut c_char, size: isize, encoding: u32) -> bool;
    fn CFRelease(object: *const c_void);
}

const ON_SCREEN_ONLY: u32 = 1;
const CF_NUMBER_SINT64: isize = 4;
const UTF8: u32 = 0x0800_0100;

unsafe fn number(dict: *const c_void, key: *const c_void) -> i64 {
    let value = CFDictionaryGetValue(dict, key);
    let mut out: i64 = 0;
    if !value.is_null() {
        CFNumberGetValue(value, CF_NUMBER_SINT64, &mut out as *mut i64 as *mut c_void);
    }
    out
}

unsafe fn text(dict: *const c_void, key: *const c_void) -> String {
    let value = CFDictionaryGetValue(dict, key);
    let mut buffer = [0 as c_char; 256];
    if !value.is_null() && CFStringGetCString(value, buffer.as_mut_ptr(), 256, UTF8) {
        CStr::from_ptr(buffer.as_ptr()).to_string_lossy().into_owned()
    } else {
        "?".to_string()
    }
}

fn main() {
    let pid: i64 = std::env::args().nth(1).and_then(|value| value.parse().ok()).unwrap_or(0);
    unsafe {
        let display = CGMainDisplayID();
        let mode = CGDisplayCopyDisplayMode(display);
        println!(
            "display points={}x{} backing_pixels={}x{} refresh={}",
            CGDisplayPixelsWide(display),
            CGDisplayPixelsHigh(display),
            CGDisplayModeGetPixelWidth(mode),
            CGDisplayModeGetPixelHeight(mode),
            CGDisplayModeGetRefreshRate(mode)
        );
        CGDisplayModeRelease(mode);
        let list = CGWindowListCopyWindowInfo(ON_SCREEN_ONLY, 0);
        let count = CFArrayGetCount(list);
        for index in 0..count {
            let window = CFArrayGetValueAtIndex(list, index);
            let owner_pid = number(window, kCGWindowOwnerPID);
            let layer = number(window, kCGWindowLayer);
            let mine = owner_pid == pid;
            if !mine && layer > -2_000_000_000 {
                continue;
            }
            let mut rect = CGRect::default();
            let bounds = CFDictionaryGetValue(window, kCGWindowBounds);
            if !bounds.is_null() {
                CGRectMakeWithDictionaryRepresentation(bounds, &mut rect);
            }
            println!(
                "{} order={} owner={} layer={} bounds={},{} {}x{}",
                if mine { "MINE" } else { "    " },
                index + 1,
                text(window, kCGWindowOwnerName),
                layer,
                rect.x,
                rect.y,
                rect.w,
                rect.h
            );
        }
        println!("onscreen_windows={count}");
        CFRelease(list);
    }
}
