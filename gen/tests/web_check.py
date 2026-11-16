import json, sys, time
from playwright.sync_api import sync_playwright
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from paths import REPO
errs = []
with sync_playwright() as p:
    b = p.chromium.launch(executable_path="/usr/bin/google-chrome", headless=True,
        args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"])
    ctx = b.new_context(viewport={"width": 852, "height": 393}, device_scale_factor=2, is_mobile=True, has_touch=True)
    pg = ctx.new_page()
    pg.on("console", lambda m: (print("CONSOLE", m.type, m.text[:200]), errs.append(m.text) if m.type == "error" else None))
    pg.on("pageerror", lambda e: (print("PAGEERROR", str(e)[:200]), errs.append(str(e))))
    pg.goto("http://localhost:8060/index.html")
    t0 = time.time()
    tapped = False
    while time.time() - t0 < 40:
        time.sleep(5)
        try:
            crumbs = pg.evaluate("localStorage.ashes_crumbs || ''")
        except Exception as e:
            crumbs = ""
        if not tapped and time.time() - t0 > 20:
            pg.mouse.click(426, 200); tapped = True
        if "ready" in crumbs:
            break
    time.sleep(8)
    pg.screenshot(path=REPO + "_shots/web_title.png")
    pg.evaluate("localStorage.setItem('ashes_resume','1:1')")
    pg.reload()
    time.sleep(25); pg.mouse.click(426, 200)
    for k in range(4):
        time.sleep(30)
        pg.screenshot(path=REPO + "_shots/web_map_%d.png" % k)
    print("CRUMBS", (pg.evaluate("localStorage.ashes_crumbs || ''"))[-1500:])
    bad = [e for e in errs if any(k in e for k in ["compressedTexImage2D", "SCRIPT ERROR", "context lost", "CONTEXT_LOST"])]
    print("ERRORS", len(errs), "BAD", len(bad))
    b.close()
