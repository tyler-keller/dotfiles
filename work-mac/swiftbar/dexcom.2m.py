#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# <bitbar.title>Dexcom Glucose</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>Tyler Keller</bitbar.author>
# <bitbar.desc>Shows current Dexcom CGM reading via pydexcom.</bitbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>false</swiftbar.hideDisablePlugin>

import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
VENV_PY = HERE / ".venv" / "bin" / "python3"

if VENV_PY.exists() and sys.executable != str(VENV_PY):
    os.execv(str(VENV_PY), [str(VENV_PY), __file__, *sys.argv[1:]])

import base64
import io
from datetime import datetime, timezone
from dotenv import load_dotenv
from pydexcom import Dexcom, Region
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

load_dotenv(HERE / ".env")

TREND_ARROWS = {
    0: "?",
    1: "↑↑",
    2: "↑",
    3: "↗",
    4: "→",
    5: "↘",
    6: "↓",
    7: "↓↓",
    8: "-",
}

def fail(msg):
    print(f"CGM ⚠️")
    print("---")
    print(msg)
    sys.exit(0)

def main():
    user = os.getenv("DEXCOM_USERNAME")
    pw = os.getenv("DEXCOM_PASSWORD")
    region_str = (os.getenv("DEXCOM_REGION") or "us").lower()
    unit = (os.getenv("DEXCOM_UNIT") or "mg/dL").strip()

    if not user or not pw:
        fail("Missing DEXCOM_USERNAME / DEXCOM_PASSWORD in .env")

    region_map = {"us": Region.US, "ous": Region.OUS, "jp": Region.JP}
    region = region_map.get(region_str, Region.US)

    try:
        dex = Dexcom(username=user, password=pw, region=region)
        readings = dex.get_glucose_readings(minutes=180, max_count=36) or []
    except Exception as e:
        fail(f"Dexcom error: {e}")

    if not readings:
        fail("No recent reading")

    gr = readings[0]
    history = list(reversed(readings))

    if unit.lower() == "mmol/l":
        value = f"{gr.mmol_l:.1f}"
    else:
        value = f"{gr.mg_dl}"

    arrow = TREND_ARROWS.get(gr.trend, gr.trend_arrow or "")
    age_min = int((datetime.now(timezone.utc) - gr.datetime.astimezone(timezone.utc)).total_seconds() // 60)

    color = "white"
    ansi_color = "\033[0m"
    try:
        mgdl = gr.mg_dl
        if mgdl < 70 or mgdl > 250:
            color = "red"
            ansi_color = "\033[31m"
        elif mgdl < 80 or mgdl > 180:
            color = "orange"
            ansi_color = "\033[33m"
        else:
            color = "green"
            ansi_color = "\033[32m"
    except Exception:
        pass

    now_utc = datetime.now(timezone.utc)
    pts = []
    for r in history:
        if not r or r.mg_dl is None:
            continue
        mins_ago = (now_utc - r.datetime.astimezone(timezone.utc)).total_seconds() / 60.0
        pts.append((-mins_ago, r.mg_dl))

    def point_color(v):
        if v < 70 or v > 250:
            return "#ff3b30"
        if v < 80 or v > 180:
            return "#ff9500"
        return "#34c759"

    def render_chart(width_px, height_px, with_axes):
        dpi = 100
        fig = plt.figure(figsize=(width_px / dpi, height_px / dpi), dpi=dpi)
        ax = fig.add_axes([0, 0, 1, 1] if not with_axes else [0.12, 0.18, 0.86, 0.78])
        ax.set_xlim(-180, 0)
        ax.set_ylim(0, 400)
        if pts:
            xs, ys = zip(*pts)
            ax.scatter(xs, ys, c=[point_color(v) for v in ys], s=18 if with_axes else 10, edgecolors="none")
        ax.axhspan(0, 80, color="#ff3b30", alpha=0.12)
        ax.axhspan(80, 180, color="#34c759", alpha=0.10)
        ax.axhspan(180, 400, color="#ff9500", alpha=0.12)
        if with_axes:
            ax.set_xticks([-180, -120, -60, 0])
            ax.set_xticklabels(["-3h", "-2h", "-1h", "now"], fontsize=8)
            ax.set_yticks([0, 70, 180, 250, 400])
            ax.tick_params(axis="y", labelsize=8)
            for s in ("top", "right"):
                ax.spines[s].set_visible(False)
        else:
            ax.set_xticks([])
            ax.set_yticks([])
            for s in ax.spines.values():
                s.set_visible(False)
        buf = io.BytesIO()
        fig.savefig(buf, format="png", transparent=True, dpi=dpi)
        plt.close(fig)
        return base64.b64encode(buf.getvalue()).decode("ascii")

    title_img = render_chart(120, 44, with_axes=False)
    drop_img = render_chart(360, 180, with_axes=True)

    reset = "\033[0m"
    print(f"│ {ansi_color}{value} {arrow}{reset} | color=white ansi=true image={title_img}")
    print("---")
    print(f"Value: {value} {unit}")
    print(f"Trend: {gr.trend_description} {arrow}")
    print(f"Age: {age_min} min ago")
    print(f"Time: {gr.datetime.astimezone().strftime('%Y-%m-%d %H:%M:%S')}")
    print("---")
    print(f"| image={drop_img}")
    print("---")
    print("Refresh | refresh=true")

if __name__ == "__main__":
    main()
