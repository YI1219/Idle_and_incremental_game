#!/usr/bin/env python3
"""Prepare a Tripo Studio single-image or multiview job from a manifest, click 生成模型 ONCE, wait, download the GLB.

Builds on studio_prepare.py helpers and retains fixes for two issues
seen in the live UI on 2026-10-02:
  * multiview upload slots disappear after each upload, so index-based upload put left.png into 右侧;
    here every upload re-finds its slot by its label (前/左侧/右侧/后).
  * the face-count input lives in a popover at x>800, so studio_prepare's x<800 filter misses it.

Geometry only: P2.0 smart mesh produces an untextured mesh. This script never opens 贴图生成 / PBR.

Usage (run from repo root, headed; use the python whose playwright matches the installed browser):
  /usr/bin/python3 tools/tripo/studio_generate.py art/source/pine/2026-10-02/manifest.json --dry-run
  /usr/bin/python3 tools/tripo/studio_generate.py art/source/pine/2026-10-02/manifest.json --yes
  /usr/bin/python3 tools/tripo/studio_generate.py MANIFEST --download-only   # re-download latest asset, no credits
"""
from __future__ import annotations

import argparse
import asyncio
import json
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import studio_prepare as sp  # noqa: E402

PROGRESS_RE = re.compile(r"(\d{1,3})\s*%|生成中|排队|队列|Generating|Queued")


class Run:
    def __init__(self, manifest_path: Path, args: argparse.Namespace):
        self.manifest_path = manifest_path
        self.manifest = sp.load_manifest(manifest_path)
        self.settings = sp.settings_block(self.manifest)
        self.image_mode = sp.image_mode(self.manifest)
        self.views = sp.resolve_inputs(self.manifest, manifest_path.parent)
        self.args = args
        self.out = manifest_path.parent / str(self.manifest.get("download_directory") or "tripo/")
        self.out.mkdir(parents=True, exist_ok=True)
        self.destination = ((manifest_path.parent / self.manifest["output_original"]).resolve()
                            if self.manifest.get("output_original") else
                            self.out / str(self.manifest.get("suggested_filename") or "raw_v01.glb"))
        self.attempt_path = self.out / f"{self.destination.stem}.generation_attempt.json"
        self.stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        self.shots = self.out / f"studio_{self.stamp}"
        self.shots.mkdir(exist_ok=True)
        self.log: Dict[str, Any] = {
            "manifest": str(manifest_path),
            "started_local": datetime.now().isoformat(timespec="seconds"),
            "mode": "dry_run" if args.dry_run else ("download_only" if args.download_only else "generate"),
            "requested": {
                "image_mode": self.image_mode,
                "route": sp.normalize_route(self.settings),
                "topology": sp.normalize_topology(self.settings),
                "target_faces": sp.face_limit(self.settings),
                "texture": sp.want_texture(self.settings),
            },
            "events": [],
        }
        self.t0 = time.time()

    def reserve_generation(self) -> None:
        """Persist before clicking; an ambiguous browser outcome must not trigger a retry."""
        try:
            with self.attempt_path.open("x", encoding="utf-8") as f:
                json.dump({"state": "click_reserved", "manifest": str(self.manifest_path),
                           "requested": self.log["requested"], "run": self.stamp}, f, indent=2)
        except FileExistsError as exc:
            raise sp.PrepareError(f"generation already attempted; inspect existing task, do not resubmit: {self.attempt_path}") from exc

    def ev(self, msg: str, **kw: Any) -> None:
        item = {"t": round(time.time() - self.t0, 1), "msg": msg, **kw}
        self.log["events"].append(item)
        print(f"[{item['t']:7.1f}s] {msg} {kw if kw else ''}", flush=True)

    async def shot(self, page, name: str, **kw) -> str:
        path = self.shots / f"{name}.png"
        await page.screenshot(path=str(path), **kw)
        return str(path)

    def save_log(self) -> Path:
        self.log["finished_local"] = datetime.now().isoformat(timespec="seconds")
        self.log["elapsed_s"] = round(time.time() - self.t0, 1)
        p = self.out / f"studio_run_{self.stamp}.json"
        p.write_text(json.dumps(self.log, ensure_ascii=False, indent=2), encoding="utf-8")
        return p


async def body_text(page) -> str:
    try:
        return await page.locator("body").inner_text(timeout=3000)
    except Exception:
        return ""


async def balance(page) -> Optional[int]:
    # header credit counter sits next to the 升级 button
    try:
        txt = await page.evaluate(
            """() => { const up=[...document.querySelectorAll('button,a,div')].find(e=>(e.innerText||'').trim()==='升级');
                       let n=up; for(let k=0;k<4&&n;k++){ n=n.parentElement; const m=(n.innerText||'').match(/(\\d{2,7})\\s*\\n?\\s*升级/); if(m) return m[1]; }
                       return null; }"""
        )
        return int(txt) if txt else None
    except Exception:
        return None


async def wait_workbench(page, run: Run, timeout_s: int = 120) -> None:
    await page.goto(sp.STUDIO_URL, wait_until="domcontentloaded")
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if await page.locator('button:has-text("智能网格")').count() and await page.locator('button:has-text("高精度模型")').count():
            await page.wait_for_timeout(1500)
            await page.keyboard.press("Escape")  # onboarding popover makes the rest aria-hidden
            await page.wait_for_timeout(500)
            return
        txt = (await body_text(page))[:1500]
        if any(k in txt for k in ("Just a moment", "Cloudflare", "验证您是真人")) or ("登录" in txt and "生成模型" not in txt):
            await run.shot(page, "blocked_login_or_cloudflare")
            raise sp.PrepareError("Studio shows login / Cloudflare; complete it manually in the window and rerun")
        await page.wait_for_timeout(1000)
    await run.shot(page, "timeout_workbench")
    raise sp.PrepareError("timed out waiting for the Studio workbench")


async def upload_by_label(page, run: Run) -> None:
    js = """e => { let n=e; for (let k=0;k<6&&n;k++){ n=n.parentElement; const t=(n.innerText||'').trim(); if(t) return t.split('\\n')[0].trim(); } return ''; }"""
    for name in sp.VIEW_ORDER:
        label = sp.VIEW_LABELS[name]
        inputs = page.locator('input[type="file"][accept*="image"]')
        target = None
        for i in range(await inputs.count()):
            if (await inputs.nth(i).evaluate(js)) == label:
                target = inputs.nth(i)
                break
        if target is None:
            raise sp.PrepareError(f"multiview slot {label} not found")
        await target.set_input_files(str(run.views[name]))
        run.ev("uploaded", slot=label, file=run.views[name].name)
        await page.wait_for_timeout(1500)
    # every slot filled -> no image file input with a slot label should remain
    left = []
    inputs = page.locator('input[type="file"][accept*="image"]')
    for i in range(await inputs.count()):
        t = await inputs.nth(i).evaluate(js)
        if t in sp.VIEW_LABELS.values():
            left.append(t)
    if left:
        raise sp.PrepareError(f"slots still empty after upload: {left}")


async def upload_single_image(page, run: Run) -> None:
    await sp.upload_single(page, run.views["single"])
    run.ev("uploaded", slot="single", file=run.views["single"].name)


async def set_topology(page, run: Run, topology: Optional[str], faces: Optional[int]) -> Dict[str, Any]:
    row = page.locator("div.cursor-pointer").filter(has_text=re.compile(r"^\s*拓扑")).first
    if not await row.count():
        row = page.locator("div.cursor-pointer").filter(has_text="拓扑").first
    await row.click()
    await page.wait_for_timeout(800)
    pop = page.locator("div").filter(has_text="面数控制").filter(has=page.locator('input[type="text"]')).last
    got: Dict[str, Any] = {}
    if topology:
        label = "三角面" if topology == "triangles" else "四边面"
        btn = pop.locator(f'button:has-text("{label}")')
        if not await btn.count():
            btn = page.locator(f'button:has-text("{label}")')
        await btn.first.click()
        await page.wait_for_timeout(300)
        got["topology_clicked"] = label
    if faces is not None:
        box = pop.locator('input[type="text"]').first
        await box.click()
        await box.fill(str(faces))
        await box.press("Enter")
        await page.wait_for_timeout(400)
        got["faces_input_value"] = await box.input_value()
    # read back which topology button looks active
    got["topology_buttons"] = await page.evaluate(
        """() => [...document.querySelectorAll('button')].filter(b=>/三角面|四边面/.test(b.innerText||''))
                 .map(b=>({t:b.innerText.trim().split('\\n')[0], state:b.getAttribute('data-state')||b.getAttribute('aria-pressed')||b.getAttribute('aria-checked')}))"""
    )
    got["panel_screenshot"] = await run.shot(page, "02_topology_panel")
    await page.keyboard.press("Escape")
    await page.wait_for_timeout(500)
    # reopen to verify the values survived closing the popover
    await row.click()
    await page.wait_for_timeout(800)
    box = page.locator("div").filter(has_text="面数控制").locator('input[type="text"]').last
    got["faces_after_reopen"] = await box.input_value() if await box.count() else None
    got["topology_after_reopen"] = await page.evaluate(
        """() => [...document.querySelectorAll('button')].filter(b=>/三角面|四边面/.test(b.innerText||''))
                 .map(b=>({t:b.innerText.trim().split('\\n')[0], state:b.getAttribute('data-state')}))"""
    )
    await run.shot(page, "02b_topology_reopened")
    await page.keyboard.press("Escape")
    await page.wait_for_timeout(300)
    return got


async def generate_button(page):
    btn = page.locator("button").filter(has_text=re.compile(r"生成\s*模型")).last
    return btn


async def asset_signature(page) -> list:
    # time labels of asset cards in the right panel, e.g. "09-20 13:38"
    txt = await body_text(page)
    return re.findall(r"\b\d{2}-\d{2} \d{2}:\d{2}\b", txt)


async def dismiss_tips(page) -> None:
    """Close the first-time '查看你的模型' controls card, which intercepts clicks on the toolbar."""
    for _ in range(2):
        ok = page.locator('button:has-text("确定")')
        clicked = False
        for i in range(await ok.count()):
            if await ok.nth(i).is_visible():
                await ok.nth(i).click()
                clicked = True
                await page.wait_for_timeout(600)
                break
        if not clicked:
            return


async def select_newest_asset(page, run: Run) -> None:
    """Click the newest asset card (top-left card after the upload tile in the right panel)."""
    imgs = page.locator("img")
    best = None
    for i in range(await imgs.count()):
        bb = await imgs.nth(i).bounding_box()
        if bb and bb["x"] > 1150 and bb["y"] > 140 and bb["width"] > 60:
            key = (round(bb["y"] / 20), bb["x"])
            if best is None or key < best[0]:
                best = (key, i)
    if best is None:
        raise sp.PrepareError("no asset card found in the right panel")
    await imgs.nth(best[1]).click()
    run.ev("selected newest asset card", index=best[1])
    await page.wait_for_timeout(6000)


async def try_download(page, run: Run, dest: Path) -> bool:
    """Toolbar 导出 -> export panel (文件名 / 格式 GLB / 底部中心轴点) -> panel 导出 -> browser download."""
    try:
        await dismiss_tips(page)
        tool = page.locator('button:has(.i-tripo\\:download)').filter(has_text="导出").first
        await tool.click()
        await page.wait_for_timeout(1500)
        panel = page.locator("div").filter(has_text="文件名").filter(has_text="格式").filter(
            has=page.locator('button:has-text("导出")')).last
        ptxt = await panel.inner_text()
        run.log["export_panel_text"] = ptxt
        run.log["export_panel_screenshot"] = await run.shot(page, "05_export_panel")
        if "GLB" not in ptxt:
            raise sp.PrepareError(f"export format is not GLB: {ptxt!r}")
        confirm = panel.locator('button:has-text("导出")').last
        async with page.expect_download(timeout=60000) as dl_info:
            await confirm.click()
        dl = await dl_info.value
        suggested = dl.suggested_filename
        await dl.save_as(str(dest))
        run.ev("downloaded", file=str(dest), suggested=suggested, bytes=dest.stat().st_size)
        run.log["download"] = {"file": str(dest), "suggested_filename": suggested, "bytes": dest.stat().st_size}
        return True
    except Exception as exc:
        run.ev("download failed", error=repr(exc)[:300])
        await run.shot(page, "05_download_failed")
        return False


async def main_async(args: argparse.Namespace) -> int:
    from playwright.async_api import async_playwright

    manifest_path = args.manifest.expanduser().resolve()
    run = Run(manifest_path, args)
    req = run.log["requested"]
    if req["texture"]:
        raise sp.PrepareError("manifest asks for texture; this helper is geometry-only")
    dest = run.destination
    if dest.exists() and not args.dry_run:
        raise sp.PrepareError(f"{dest} exists; refusing to generate again over it")

    async with async_playwright() as pw:
        ctx = await pw.chromium.launch_persistent_context(
            user_data_dir=str(args.profile), headless=args.headless,
            channel=args.channel,
            viewport={"width": 1440, "height": 960}, accept_downloads=True, locale="zh-CN",
        )
        ctx.set_default_timeout(30000)
        page = ctx.pages[0] if ctx.pages else await ctx.new_page()
        try:
            await wait_workbench(page, run)
            run.log["balance_before"] = await balance(page)
            run.ev("workbench ready", balance=run.log["balance_before"])
            if args.download_only:
                await run.shot(page, "00_download_only_start")
                await select_newest_asset(page, run)
                await dismiss_tips(page)
                run.log["result_screenshot"] = await run.shot(page, "04_result")
                ok = await try_download(page, run, dest)
                return 0 if ok else 3

            if req["route"] == "smart_mesh":
                await sp.click_text_button(page, "智能网格")
            else:
                await sp.click_text_button(page, "高精度模型")
            await page.wait_for_timeout(600)
            if run.image_mode == "single_image":
                await upload_single_image(page, run)
            else:
                await sp.select_multiview(page)
                run.ev("multiview selected")
                await upload_by_label(page, run)
            await page.wait_for_timeout(2500)
            # Studio persists batch size across sessions; always request one model.
            quantity_group = page.get_by_text("生成数量", exact=True).locator("..").locator("..")
            await quantity_group.locator('button[value="1"]').click()
            await page.wait_for_timeout(500)
            run.log["actual_ui"] = await set_topology(page, run, req["topology"], req["target_faces"])
            run.log["actual_ui"]["requested_quantity"] = 1
            selected_quantity = await quantity_group.locator('button[aria-pressed="true"]').evaluate_all("buttons => buttons.map(b => b.value)")
            run.log["actual_ui"]["selected_quantity"] = selected_quantity
            if selected_quantity != ["1"]:
                raise sp.PrepareError(f"single-model quantity was not retained: {selected_quantity}")
            if req["target_faces"] is not None and run.log["actual_ui"]["faces_after_reopen"] != str(req["target_faces"]):
                raise sp.PrepareError("target face count was not retained")
            # read back model + cost
            model_txt = await page.evaluate(
                """() => { const h=[...document.querySelectorAll('*')].find(e=>e.childElementCount===0&&(e.innerText||'').trim()==='AI 模型');
                           let n=h; for(let k=0;k<4&&n;k++){ n=n.parentElement; } return n? n.innerText.trim(): null; }"""
            )
            gen = await generate_button(page)
            gen_txt = (await gen.inner_text()).replace("\n", " ").strip()
            nums = [int(x) for x in re.findall(r"\d+", gen_txt)]
            cost = nums[-1] if nums else None
            run.log["actual_ui"].update({"ai_model_block": model_txt, "generate_button_text": gen_txt, "cost_shown": cost})
            run.log["actual_ui"]["left_panel_screenshot"] = await run.shot(
                page, "03_parameter_panel", clip={"x": 60, "y": 60, "width": 260, "height": 900})
            await run.shot(page, "03_full_before_generate")
            run.ev("ready to generate", button=gen_txt, cost=cost)
            if args.dry_run:
                run.ev("dry-run: stop before 生成模型")
                return 0
            if not args.yes:
                raise sp.PrepareError("pass --yes to actually click 生成模型 (costs credits)")
            if cost is None or cost > args.max_credits:
                raise sp.PrepareError(f"shown cost {cost} exceeds --max-credits {args.max_credits}")

            before = await asset_signature(page)
            run.reserve_generation()
            run.save_log()
            await gen.click()  # the single paid click
            run.log["generate_clicked_local"] = datetime.now().isoformat(timespec="seconds")
            run.ev("clicked 生成模型 once")
            await page.wait_for_timeout(4000)
            await run.shot(page, "04_after_click")

            deadline = time.time() + args.wait_s
            last_progress, seen_progress, k = None, False, 0
            while time.time() < deadline:
                await page.wait_for_timeout(5000)
                k += 1
                txt = await body_text(page)
                m = PROGRESS_RE.findall(txt)
                prog = re.search(r"(\d{1,3})\s*%", txt)
                state = prog.group(0) if prog else ("busy" if m else None)
                if state != last_progress:
                    run.ev("progress", state=state)
                    last_progress = state
                if state:
                    seen_progress = True
                if k % 12 == 0:
                    await run.shot(page, f"04_wait_{k:03d}")
                after = await asset_signature(page)
                if seen_progress and not state and len(after) > len(before):
                    run.ev("generation finished (progress gone, new asset card)")
                    break
                if not seen_progress and k > 24 and len(after) > len(before):
                    run.ev("new asset card without progress text; assuming finished")
                    break
            else:
                await run.shot(page, "04_wait_timeout")
                raise sp.PrepareError("timed out waiting for generation; check the Studio window / assets panel")
            await page.wait_for_timeout(4000)
            await dismiss_tips(page)
            run.log["result_screenshot"] = await run.shot(page, "04_result")
            run.log["balance_after"] = await balance(page)
            run.ev("balance after", balance=run.log["balance_after"])
            ok = await try_download(page, run, dest)
            return 0 if ok else 3
        except Exception as exc:
            run.ev("error", error=repr(exc)[:500])
            try:
                await run.shot(page, "99_error")
            except Exception:
                pass
            raise
        finally:
            if args.keep_open_s:
                await page.wait_for_timeout(args.keep_open_s * 1000)
            print("log:", run.save_log(), flush=True)
            await ctx.close()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("manifest", type=Path)
    p.add_argument("--profile", type=Path, default=sp.DEFAULT_PROFILE)
    p.add_argument("--headless", action="store_true")
    p.add_argument("--channel", choices=["chrome", "msedge"], help="use an installed browser instead of the bundled Chromium")
    p.add_argument("--dry-run", action="store_true", help="fill everything, screenshot, do not click")
    p.add_argument("--yes", action="store_true", help="actually click 生成模型 once")
    p.add_argument("--download-only", action="store_true", help="no generation; download newest asset")
    p.add_argument("--max-credits", type=int, default=100)
    p.add_argument("--wait-s", type=int, default=900)
    p.add_argument("--keep-open-s", type=int, default=0)
    args = p.parse_args()
    try:
        return asyncio.run(main_async(args))
    except sp.PrepareError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
