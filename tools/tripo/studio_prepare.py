#!/usr/bin/env python3
"""Prepare a Tripo Studio single-image or multiview job from a local manifest. Never clicks Generate."""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, Mapping, Optional

STUDIO_URL = "https://studio.tripo3d.com/workspace/generate"
DEFAULT_PROFILE = Path.home() / ".tripo-studio-profile"
VIEW_ORDER = ("front", "left", "right", "back")
VIEW_LABELS = {
    "front": "前",
    "left": "左侧",
    "right": "右侧",
    "back": "后",
}
GENERATE_NAME = re.compile(r"生成\s*模型")


class PrepareError(RuntimeError):
    pass


def load_manifest(path: Path) -> Dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise PrepareError(f"manifest must be a JSON object: {path}")
    return data


def settings_block(manifest: Mapping[str, Any]) -> Dict[str, Any]:
    for key in ("studio", "suggested_settings", "tripo_suggested_settings", "recommended_parameters"):
        block = manifest.get(key)
        if isinstance(block, dict):
            return dict(block)
    return {}


def image_mode(manifest: Mapping[str, Any]) -> str:
    mode = manifest.get("submission_mode", "multiview")
    if mode not in ("single_image", "multiview"):
        raise PrepareError(f"unsupported submission_mode: {mode!r}")
    return mode


def resolve_inputs(manifest: Mapping[str, Any], manifest_dir: Path) -> Dict[str, Path]:
    if image_mode(manifest) == "multiview":
        return resolve_views(manifest, manifest_dir)
    entry = manifest.get("input")
    if not isinstance(entry, dict) or not entry.get("file"):
        raise PrepareError("single_image requires manifest.input.file")
    path = (manifest_dir / str(entry["file"])).resolve()
    if not path.is_file():
        raise PrepareError(f"missing single image: {path}")
    if entry.get("sha256"):
        import hashlib
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise PrepareError("selected input image SHA256 does not match manifest")
    return {"single": path}


def resolve_views(manifest: Mapping[str, Any], manifest_dir: Path) -> Dict[str, Path]:
    views = manifest.get("views")
    if not isinstance(views, dict):
        raise PrepareError("manifest.views is required")
    resolved: Dict[str, Path] = {}
    for name in VIEW_ORDER:
        entry = views.get(name)
        if not isinstance(entry, dict) or not entry.get("file"):
            raise PrepareError(f"manifest.views.{name}.file is required")
        path = (manifest_dir / str(entry["file"])).resolve()
        if not path.is_file():
            raise PrepareError(f"missing view image: {path}")
        resolved[name] = path
    return resolved


def normalize_route(settings: Mapping[str, Any]) -> str:
    raw = str(settings.get("route") or settings.get("model") or "smart_mesh").lower()
    if any(token in raw for token in ("p2", "smart", "智能")):
        return "smart_mesh"
    if any(token in raw for token in ("v3", "high", "高精度", "最高")):
        return "high_quality"
    return "smart_mesh"


def normalize_topology(settings: Mapping[str, Any]) -> Optional[str]:
    raw = settings.get("topology")
    if raw is None:
        return None
    text = str(raw).lower()
    if "quad" in text or "四边" in text:
        return "quads"
    if "tri" in text or "三角" in text:
        return "triangles"
    return None


def face_limit(settings: Mapping[str, Any]) -> Optional[int]:
    for key in ("target_faces", "face_limit", "faces", "target_triangles"):
        value = settings.get(key)
        if value is None:
            continue
        try:
            return int(value)
        except (TypeError, ValueError) as exc:
            raise PrepareError(f"invalid {key}: {value!r}") from exc
    return None


def want_texture(settings: Mapping[str, Any]) -> bool:
    if "texture" in settings:
        return bool(settings.get("texture"))
    stage = str(settings.get("texture_stage") or "").lower()
    if "after" in stage or "only after" in stage or "先" in stage:
        return False
    return False


def assert_not_generate_label(label: str) -> None:
    if "生成模型" in label.replace(" ", ""):
        raise PrepareError("refusing to interact with Generate control")


async def wait_for_workbench(page, timeout_ms: int) -> None:
    await page.goto(STUDIO_URL, wait_until="domcontentloaded")
    deadline = time.time() + timeout_ms / 1000.0
    reminded = False
    while time.time() < deadline:
        high = page.get_by_role("button", name=re.compile(r"高精度"))
        smart = page.get_by_role("button", name=re.compile(r"智能网格"))
        if await high.count() and await smart.count():
            return
        body = ""
        try:
            body = (await page.locator("body").inner_text(timeout=1000)).strip()
        except Exception:
            pass
        if (not reminded) and (
            "登录" in body[:1200]
            or "Sign in" in body[:1200]
            or "Cloudflare" in body[:600]
            or "Just a moment" in body[:600]
        ):
            print(
                "Browser needs manual login / Cloudflare clearance.\n"
                "Complete login in the opened window; waiting…",
                flush=True,
            )
            reminded = True
        await page.wait_for_timeout(1000)
    raise PrepareError("timed out waiting for Studio generate workbench (login may be required)")


async def click_text_button(page, text: str) -> None:
    assert_not_generate_label(text)
    button = page.get_by_role("button", name=text, exact=True)
    if await button.count() == 0:
        button = page.get_by_role("button", name=text)
    if await button.count() == 0:
        button = page.locator(f'button:has-text("{text}")')
    await button.first.click()


async def select_route(page, route: str) -> None:
    if route == "smart_mesh":
        await click_text_button(page, "智能网格")
    else:
        await click_text_button(page, "高精度模型")
    await page.wait_for_timeout(400)


async def select_multiview(page) -> None:
    icon = page.locator(".i-tripo\\:multi-view").first
    if await icon.count() == 0:
        icon = page.locator('[class*="multi-view"]').first
    if await icon.count() == 0:
        raise PrepareError("multiview mode icon not found")
    button = icon.locator("xpath=ancestor::button[1]")
    target = button if await button.count() else icon
    await target.click()
    await page.wait_for_timeout(500)


async def upload_single(page, image: Path) -> None:
    # Same top upload-mode strip as multi-view; explicitly select the image tab.
    icon = page.locator('.i-tripo\\:add-image').first
    if not await icon.count():
        raise PrepareError("single-image mode icon not found")
    button = icon.locator("xpath=ancestor::button[1]")
    await (button if await button.count() else icon).click()
    await page.wait_for_timeout(500)
    inputs = page.locator('input[type="file"][accept*="image"]')
    count = await inputs.count()
    if count != 1:
        raise PrepareError(f"single-image mode requires exactly one upload input, found {count}")
    await inputs.first.set_input_files(str(image))
    await page.wait_for_timeout(1500)


async def image_file_inputs(page):
    inputs = page.locator('input[type="file"][accept*="image"]')
    count = await inputs.count()
    if count < 4:
        raise PrepareError(f"expected 4 image file inputs after multiview, found {count}")
    return inputs


async def upload_views(page, views: Mapping[str, Path]) -> None:
    inputs = await image_file_inputs(page)
    for index, name in enumerate(VIEW_ORDER):
        path = views[name]
        print(f"  upload [{VIEW_LABELS[name]}] <- {path.name}", flush=True)
        await inputs.nth(index).set_input_files(str(path))
        await page.wait_for_timeout(300)


async def open_topology_or_geometry(page, route: str) -> None:
    if route == "smart_mesh":
        row = page.locator("div.group\\/advanced, div.cursor-pointer").filter(has_text="拓扑").first
        if await row.count():
            await row.click()
            await page.wait_for_timeout(300)
            return
    row = page.locator("div.group\\/advanced, div.cursor-pointer").filter(has_text="几何与贴图").first
    if await row.count():
        await row.click()
        await page.wait_for_timeout(300)


async def apply_topology(page, topology: Optional[str]) -> None:
    if not topology:
        return
    label = "三角面" if topology == "triangles" else "四边面"
    button = page.get_by_role("button", name=label)
    if await button.count() == 0:
        button = page.locator(f'button:has-text("{label}")')
    if await button.count() == 0:
        print(f"  warn: topology control not found ({label})", flush=True)
        return
    await button.first.click()
    print(f"  topology -> {label}", flush=True)


async def apply_face_limit(page, faces: Optional[int]) -> None:
    if faces is None:
        return
    section = page.locator("body").filter(has_text="面数控制")
    candidates = section.locator('input, [role="textbox"]')
    count = await candidates.count()
    target = None
    for i in range(count):
        el = candidates.nth(i)
        try:
            value = await el.input_value()
        except Exception:
            continue
        box = await el.bounding_box()
        if not box or box["x"] >= 800:
            continue
        if value.isdigit() and 100 <= int(value) <= 2_000_000:
            target = el
            break
        if target is None and (value.isdigit() or value == ""):
            target = el
    if target is None:
        print(f"  warn: face-limit control not found (wanted {faces})", flush=True)
        return
    await target.click()
    await target.fill(str(faces))
    await target.press("Enter")
    print(f"  face_limit -> {faces}", flush=True)


async def apply_high_quality_texture_prefs(page, texture: bool) -> None:
    """Best-effort: leave texture-related toggles off for geometry-first runs."""
    if texture:
        return
    # Do not hard-fail; Studio defaults vary.
    for label in ("贴图生成", "PBR", "8K 贴图", "8K"):
        switch = page.get_by_role("switch").locator("xpath=..").filter(has_text=label)
        # Skip if structure differs.
        _ = switch
    print("  texture -> prefer off / geometry-first (manual check in UI)", flush=True)


async def guard_generate_button(page) -> None:
    """Ensure Generate exists but we never click it."""
    gen = page.get_by_role("button", name=GENERATE_NAME)
    if await gen.count() == 0:
        gen = page.locator('button:has-text("生成模型")')
    if await gen.count() == 0:
        print("  warn: Generate button not visible yet", flush=True)
        return
    label = (await gen.first.inner_text()).replace("\n", " ").strip()
    # Observed only — never clicked.
    print(f"  stopped before click: [{label}]", flush=True)


async def prepare(
    page,
    views: Mapping[str, Path],
    settings: Mapping[str, Any],
    timeout_ms: int,
) -> None:
    route = normalize_route(settings)
    topology = normalize_topology(settings)
    faces = face_limit(settings)
    texture = want_texture(settings)

    print(f"route={route} topology={topology} faces={faces} texture={texture}", flush=True)
    await wait_for_workbench(page, timeout_ms=timeout_ms)
    await select_route(page, route)
    if "single" in views:
        await upload_single(page, views["single"])
    else:
        await select_multiview(page)
        await upload_views(page, views)
    await open_topology_or_geometry(page, route)
    await apply_topology(page, topology)
    await apply_face_limit(page, faces)
    if route == "high_quality":
        await apply_high_quality_texture_prefs(page, texture)
    await guard_generate_button(page)


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Fill Tripo Studio multiview from a manifest; never clicks Generate."
    )
    p.add_argument("manifest", type=Path, help="Path to task manifest.json")
    p.add_argument(
        "--profile",
        type=Path,
        default=DEFAULT_PROFILE,
        help=f"Persistent Chromium profile (default: {DEFAULT_PROFILE})",
    )
    p.add_argument("--headed", action="store_true", default=True, help="Show browser (default)")
    p.add_argument("--headless", action="store_true", help="Run headless (often blocked)")
    p.add_argument("--timeout-ms", type=int, default=120000, help="Default timeout in ms")
    p.add_argument(
        "--no-pause",
        action="store_true",
        help="Exit immediately after prepare (browser closes)",
    )
    return p


async def async_main(args: argparse.Namespace) -> int:
    try:
        from playwright.async_api import async_playwright
    except ImportError as exc:
        raise PrepareError(
            "playwright is not installed. Run:\n"
            "  python3 -m pip install -r tools/tripo/requirements.txt\n"
            "  python3 -m playwright install chromium"
        ) from exc

    manifest_path = args.manifest.expanduser().resolve()
    if not manifest_path.is_file():
        raise PrepareError(f"manifest not found: {manifest_path}")

    manifest = load_manifest(manifest_path)
    views = resolve_inputs(manifest, manifest_path.parent)
    settings = settings_block(manifest)

    print("views:", flush=True)
    for name, path in views.items():
        print(f"  {name}: {path}", flush=True)

    headed = not args.headless
    args.profile.mkdir(parents=True, exist_ok=True)

    async with async_playwright() as playwright:
        context = await playwright.chromium.launch_persistent_context(
            user_data_dir=str(args.profile),
            headless=not headed,
            viewport={"width": 1440, "height": 960},
            accept_downloads=True,
            locale="zh-CN",
        )
        context.set_default_timeout(args.timeout_ms)
        page = context.pages[0] if context.pages else await context.new_page()
        try:
            await prepare(page, views, settings, timeout_ms=args.timeout_ms)
            print(
                "\nPrepare finished. Review the Studio UI, then click Generate yourself if correct.\n"
                "This script will not click 生成模型.",
                flush=True,
            )
            if not args.no_pause and headed:
                print("Press Enter here to close the browser…", flush=True)
                await asyncio_to_thread_input()
        finally:
            await context.close()
    return 0


async def asyncio_to_thread_input() -> None:
    # Python 3.9-compatible stdin wait without blocking the event loop hard-fail.
    import asyncio

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, sys.stdin.readline)


def main(argv: Optional[list] = None) -> int:
    args = build_arg_parser().parse_args(argv)
    try:
        import asyncio

        return asyncio.run(async_main(args))
    except PrepareError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\ninterrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
