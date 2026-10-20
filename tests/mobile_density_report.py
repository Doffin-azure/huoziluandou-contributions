"""Generate the October 18 density-aware archive. Run after native captures."""
from pathlib import Path
import csv
import hashlib
import html
import importlib.util
import json
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "docs/qa/mobile-layout-2026-10-18"
spec = importlib.util.spec_from_file_location("old_report", ROOT / "tests/ui_resolution_report.py")
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
LABELS = old.LABELS | {"map-guide": "幕地图／路线说明", "expedition-guide": "远征／触屏玩法说明", "expedition-loadout-detail": "远征／印章与遗物详情"}


def records(phase):
    result = {}
    for path in sorted((ARCHIVE / phase).glob("*.json")):
        for row in json.loads(path.read_text(encoding="utf-8")):
            result[row["profile"], row["state"]] = row
    return result


def geometry(row):
    return sum(len(row.get(key, [])) for key in ["outside", "clipped", "overlaps"])


def map_fraction(row):
    scroll = next(c for c in row["controls"] if c["type"] == "ScrollContainer")
    return scroll["rect"][3] / row["viewport"][1]


def main():
    before, after = records("before"), records("after")
    assert before.keys() <= after.keys(), before.keys() - after.keys()
    assert len(before) == 8 * 47, len(before)
    assert len({k[0] for k in before}) == 8
    assert not any(geometry(r) for r in after.values()), "Review unresolved geometry findings"
    pairs = []
    for key, b in sorted(after.items()):
        a = before.get(key)
        for phase, row in [("before", a), ("after", b)]:
            if row is None:
                continue
            image = ARCHIVE / phase / row["image"]
            assert row["saved"] and image.is_file()
            with Image.open(image) as im:
                assert list(im.size) == row["pixels"]
        if a:
            assert a["pixels"] == b["pixels"] and a["dpi"] == b["dpi"]
        pairs.append({"profile": key[0], "state": key[1], "label": LABELS.get(key[1], key[1]),
                      "pixels": b["pixels"], "dpi": b["dpi"],
                      "before": "before/" + a["image"] if a else "",
                      "after": "after/" + b["image"],
                      "before_findings": geometry(a) if a else "—", "after_findings": geometry(b)})
    (ARCHIVE / "comparison.json").write_text(json.dumps(pairs, ensure_ascii=False, indent=2), encoding="utf-8")
    with (ARCHIVE / "comparison.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(pairs[0]))
        writer.writeheader()
        writer.writerows(pairs)

    lines = ["# 手机横屏布局修复与截图对照（2026-10-18）", "",
             "用户 APK 原图保存在 user/。本次在 Godot 原生桌面渲染器中同时改变窗口像素与 Android DPI，进行布局模拟；未连接手机，不属于真机兼容性或性能实测。用户截图的真实 DPI 未提供，2436×1120 使用 480 DPI 作为复现参数。仅横屏，无旋转提示。", "",
             f"覆盖 8 组参数、{len(before)} 对同条件前后截图，另有 {len(after)-len(before)} 张新增说明及压力场景截图。每组覆盖主界面、设置、暂停、图鉴、字袋、选择弹窗、自定义构筑、字网、幕地图、休整、全部事件、商店、奖励、远征各页及战斗。", "",
             "| 参数组 | 实际截图像素 | 模拟 DPI | 幕地图可用高度：修复前 → 后 | 远征地图可用高度：修复前 → 后 |", "|---|---|---|---|---|"]
    for profile in sorted({k[0] for k in before}):
        a, b = before[profile, "map"], after[profile, "map"]
        ea, eb = before[profile, "expedition-map"], after[profile, "expedition-map"]
        lines.append(f"| {profile} | {'×'.join(map(str,b['pixels']))} | {b['dpi']:g} | {map_fraction(a):.1%} → {map_fraction(b):.1%} | {map_fraction(ea):.1%} → {map_fraction(eb):.1%} |")
    lines += ["", "DPI=0 表示桌面默认密度。720p、1080p、1440p 组合用于覆盖常见 Android 屏幕档位；平板和桌面用于回归，不代表这些型号的真机测试。", "",
              "| 界面 | 修复前 | 修复后 |", "|---|---|---|",
              "| 幕地图 | 标题、说明、状态上下堆叠；底栏继续挤占路线；终点可能需拖动才能看到 | 紧凑顶栏，移除冗余底栏；节点字号与触控区域按密度统一；自动对准当前节点，路线说明可点击查看 |",
              "| 远征 | 顶栏展示整份印章与遗物清单；地图、说明各占一半；当前格贴近下边缘 | 地图优先分配宽度，视野围绕玩家；顶栏直接显示菜单；清单移入整备，完整描述可点击查看 |",
              "| 远征行旅页 | 长教程占满事件区域，套了两层滚动容器 | 显示短引导，完整玩法与图例由按钮打开；行旅和战报各保留一层滚动 |",
              "| 休整 | 堆叠页眉、固定高度卡片使选择按钮落在裁切区域 | 横向紧凑标题，卡片依据内容分配高度，三项操作完整可见 |",
              "| 自定义构筑 | 字块过大，手机无法用右键移除字 | 调整移动端字块尺寸；加入加字／减字模式，触屏可完成增减 |",
              "| 字网图谱 | 页眉信息拥挤，侧栏挤占图谱 | 移动端页眉压紧，统计放侧栏，扩大图谱可视区域 |", "",
              "通用几何检查在修复前后均未报告越界，因此本次增加了地图占屏、节点可见范围、休整按钮实际可见高度、遗物摘要行高，以及触屏减字、切页不改变步数/RNG等回归检查；零越界本身不代表布局合理。", "",
              "[打开全部截图的前后对照表](index.html) · [逐项 CSV](comparison.csv) · [逐项 JSON](comparison.json)", "",
              "## 逐项截图", "", "| 参数组 | 界面 | 修复前 | 修复后 |", "|---|---|---|---|"]
    for row in pairs:
        old_link = f"[截图]({row['before']})" if row['before'] else "新增覆盖"
        lines.append(f"| {row['profile']} | {row['label']} | {old_link} | [截图]({row['after']}) |")
    (ARCHIVE / "修复前后对照.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    data = json.dumps(pairs, ensure_ascii=False).replace("</", "<\\/")
    template = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>手机横屏 UI 修复前后对照</title>
<style>body{margin:24px;background:#10262f;color:#e6d8b6;font:16px system-ui}h1{font-size:25px}p{max-width:1000px;line-height:1.6}select,input{padding:10px;margin:8px;background:#e6d8b6;color:#10262f}table{border-collapse:collapse;width:100%}td,th{border:1px solid #51625a;padding:10px;text-align:left}img{width:100%;display:block}td:nth-child(n+3){width:39%}small{color:#a6b5a5}a{color:#c6aa70}</style>
<h1>手机横屏 UI 修复前后对照 · 2026-10-18</h1><p>8 组分辨率与 DPI 的 Godot 原生渲染布局模拟。未连接真机；用户截图 DPI 未知，2436×1120 按 480 DPI 复现。点击截图打开原尺寸。新增玩法、遗物说明和压力截图没有对应旧截图。</p>
<p><a href="修复前后对照.md">修复说明</a> · <a href="comparison.csv">下载 CSV</a> · <a href="user/expedition-apk.jpg">用户远征原图</a> · <a href="user/map-apk.jpg">用户幕地图原图</a></p>
<label>参数组 <select id="profile"><option value="">全部</option></select></label><label>筛选界面 <input id="search" placeholder="如：远征、休整、战斗"></label><p id="count"></p>
<table><thead><tr><th>参数组</th><th>界面</th><th>修复前</th><th>修复后</th></tr></thead><tbody id="rows"></tbody></table>
<script>const data=__DATA__;const p=document.querySelector('#profile'),q=document.querySelector('#search');for(const name of [...new Set(data.map(r=>r.profile))]){let o=document.createElement('option');o.value=o.textContent=name;p.append(o)}function image(path){if(!path)return '新增覆盖';let a=document.createElement('a');a.href=path;a.target='_blank';let im=document.createElement('img');im.src=path;im.loading='lazy';a.append(im);return a}function draw(){let rows=data.filter(r=>(!p.value||r.profile===p.value)&&(!q.value||(r.label+' '+r.state).includes(q.value)));document.querySelector('#count').textContent=rows.length+' 项';let t=document.querySelector('#rows');t.replaceChildren();for(let r of rows){let tr=document.createElement('tr');for(let value of [r.profile+' · '+r.pixels.join('×')+' · DPI '+r.dpi,r.label,image(r.before),image(r.after)]){let td=document.createElement('td');if(typeof value==='string')td.textContent=value;else td.append(value);tr.append(td)}t.append(tr)}}p.onchange=q.oninput=draw;draw();</script></html>'''
    (ARCHIVE / "index.html").write_text(template.replace("__DATA__", data), encoding="utf-8")

    for profile in sorted({k[0] for k in before}):
        states = ["map", "expedition-map", "rest", "custom-deck", "glyph-graph", "expedition-actions"]
        contact = Image.new("RGB", (1200, len(states) * 302), "#e6d8b6")
        draw = ImageDraw.Draw(contact)
        for y, state in enumerate(states):
            for x, phase in enumerate(["before", "after"]):
                row = (before if phase == "before" else after)[profile, state]
                with Image.open(ARCHIVE / phase / row["image"]) as source:
                    source.thumbnail((600, 276))
                    contact.paste(source, (x * 600, y * 302 + 25))
                draw.text((x * 600 + 5, y * 302 + 4), phase + " / " + state, fill="#10262f")
        contact.save(ARCHIVE / (profile + "-comparison.jpg"), quality=90)

    logs = ARCHIVE / "logs"
    logs.mkdir(exist_ok=True)
    for path in list((ROOT / "shots").glob("density-regression-*.log")) + [ROOT / "shots" / name for name in ["mobile-layout-before.log", "mobile-layout-after.log", "mobile-layout-after-focused.log", "mobile-layout-after-info.log"]]:
        shutil.copy2(path, logs / path.name)
    sources = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
               for folder in ["src", "tests"] for p in (ROOT / folder).rglob("*.gd")}
    manifest = {"date": "2026-10-18", "paired_screenshots": len(before), "after_screenshots": len(after),
                "profiles": 8, "device_testing": False, "renderer": "Godot 4.7.2 / desktop GL Compatibility",
                "density_override": "Debug builds only; release uses Android screen_get_dpi()",
                "source_sha256": sources}
    (ARCHIVE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Verified {len(before)} pairs + {len(after)-len(before)} supplemental captures; geometry findings: 0")


if __name__ == "__main__":
    main()
