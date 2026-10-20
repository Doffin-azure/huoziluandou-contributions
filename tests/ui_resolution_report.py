"""Build an offline before/after gallery from the native Godot matrix archive.

Run with Python 3: python tests/ui_resolution_report.py --require-complete
Only the optional contact sheets require Pillow; the report uses the standard library.
"""
from pathlib import Path
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "docs/qa/ui-resolution-2026-10-17"
PROFILES = [
    ("phone-640x360", "Android 小屏基线", "640×360", "1280×720（2× 示例）"),
    ("iphone-se", "iPhone SE 2 / 3", "667×375", "1334×750"),
    ("iphone-x", "iPhone X / XS / 11 Pro", "812×375", "2436×1125"),
    ("iphone-13", "iPhone 12 / 13 / 14", "844×390", "2532×1170"),
    ("iphone-14-pro", "iPhone 14 Pro", "852×393", "2556×1179"),
    ("iphone-xr", "iPhone XR / 11", "896×414", "1792×828"),
    ("pixel-7", "Pixel 7 有效视口", "915×412", "2400×1080"),
    ("iphone-pro-max", "iPhone 14 / 15 Pro Max", "932×430", "2796×1290"),
    ("android-20x9", "Android 20:9 代表尺寸", "960×432", "2400×1080（2.5× 示例）"),
    ("tablet-4x3", "iPad 4:3 代表尺寸", "1024×768", "2048×1536（2× 示例）"),
    ("desktop-small", "小窗口 16:9", "1024×576", "—"),
    ("hd", "桌面 HD", "1280×720", "—"),
    ("laptop", "常见笔记本", "1366×768", "—"),
    ("desktop-900p", "桌面 900p", "1600×900", "—"),
    ("fhd", "桌面 FHD", "1920×1080", "—"),
    ("qhd", "桌面 QHD", "2560×1440", "—"),
    ("ultrawide", "超宽屏", "2560×1080", "—"),
    ("uhd", "桌面 UHD", "3840×2160", "—"),
]
LABELS = {
    "title": "主界面", "settings-top": "设置／字体", "settings-bottom": "设置／手感与音量",
    "pause": "暂停菜单", "collection-chars": "字库图鉴／实体字", "collection-words": "字库图鉴／词",
    "effect-help": "词条说明浮层", "deck": "当前字袋", "choice": "岔路与选择弹窗",
    "custom-deck": "自定义构筑", "glyph-graph": "字网图谱", "glyph-detail": "字网／节点详情",
    "map": "幕地图", "rest": "休整", "rest-picker": "休整／删字选取",
    "event-ink_pool": "事件／墨池", "event-old_bookshop": "事件／旧书肆",
    "event-all-ink_pool": "事件／墨池（确定种子）", "event-all-broken_stele": "事件／断碑",
    "event-all-old_bookshop": "事件／旧书肆（确定种子）",
    "reward-four": "战后／四选一奖励", "shop": "商店／买字", "shop-service": "商店／整备服务",
    "shop-picker": "商店／复制选字", "expedition-map": "远征／探索", "expedition-plate": "远征／字阵",
    "expedition-log": "远征／战报", "expedition-legend": "远征／图例", "expedition-rest": "远征／休息点",
    "expedition-shop": "远征／商店", "expedition-forge": "远征／许愿机", "expedition-act_end": "远征／幕间结算",
    "expedition-win": "远征／胜利", "expedition-loss": "远征／中止", "expedition-actions": "远征／整备操作",
    "expedition-loot": "远征／大赏", "expedition-seal_swap": "远征／印章替换",
    "expedition-relic_bind": "远征／遗物绑定", "expedition-mystery-0": "远征／谜事件一",
    "expedition-mystery-1": "远征／谜事件二", "expedition-mystery-2": "远征／谜事件三",
    "expedition-boss": "远征／首领迎战", "battle-status": "战斗／三敌人与玩家状态",
    "battle-log": "战斗／战报", "battle-pile": "战斗／抽牌堆", "battle-defeat": "战斗／败北",
    "battle-deck-words": "战斗／字袋词图鉴与分层遮挡",
    "expedition-seal-full": "远征／印章已满替换", "expedition-bind-full": "远征／压字石绑定",
    "expedition-late": "远征／满印章及全遗物整备", "battle-five": "战斗／5×5 字盘与四位数血量",
}


def read_phase(phase):
    records = {}
    for path in sorted((ARCHIVE / phase).glob("*.json")):
        for row in json.loads(path.read_text(encoding="utf-8")):
            records[(row["profile"], row["state"])] = row
    return records


def violations(row):
    return len(row["outside"]) + len(row.get("clipped", [])) + len(row.get("overlaps", []))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    before, after = read_phase("before"), read_phase("after")
    keys = sorted(before)
    if args.require_complete:
        assert set(before) == set(after), f"Missing pairs: {set(before) ^ set(after)}"
        assert len(before) == 18 * 51, len(before)
        assert sum(violations(row) for row in after.values()) == 0, "Unresolved geometry findings"
    pairs = []
    for key in keys:
        a, b = before[key], after.get(key)
        assert a["saved"] and (ARCHIVE / "before" / a["image"]).is_file()
        if b:
            assert b["saved"] and (ARCHIVE / "after" / b["image"]).is_file()
            assert a["pixels"] == b["pixels"], (key, a["pixels"], b["pixels"])
        pairs.append({"profile": key[0], "state": key[1], "label": LABELS.get(key[1], key[1]),
                      "before": "before/" + a["image"], "after": "after/" + b["image"] if b else "",
                      "pixels": a["pixels"], "oldOutside": len(a["outside"]),
                      "newOutside": len(b["outside"]) if b else None,
                      "newClipped": len(b.get("clipped", [])) if b else None,
                      "newOverlap": len(b.get("overlaps", [])) if b else None})
    (ARCHIVE / "comparison.json").write_text(json.dumps(pairs, ensure_ascii=False, indent=2), encoding="utf-8")
    data = json.dumps(pairs, ensure_ascii=False).replace("</", "<\\/")
    profiles = json.dumps(PROFILES, ensure_ascii=False)
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>活字战斗 · 横屏 UI 修复对照</title>
<style>body{font:16px/1.6 system-ui,sans-serif;background:#10262f;color:#e6d8b6;margin:24px}h1{font-size:26px}a{color:#e5bd74}select,input{font:inherit;padding:8px;max-width:100%;margin:4px;background:#18333b;color:inherit;border:1px solid #718272}section{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0;min-width:0}img{width:100%;height:auto;display:block;background:#07131a}figcaption{padding:8px 0}table{border-collapse:collapse;width:100%;margin-top:24px}th,td{padding:8px;text-align:left;border-bottom:1px solid #51625a}button{font:inherit;background:#8d3039;color:white;padding:6px 12px;border:0;cursor:pointer}.muted{color:#a6b5a5}tr.selected{background:#294448}@media(max-width:900px){section{grid-template-columns:1fr}body{margin:12px}}</style>
<h1>活字战斗 · 横屏 UI 修复前后对照</h1>
<p>10 个正式页面及共用浮层，18 组横屏尺寸。截图由 Godot 4.7.2 Vulkan 原生渲染生成；手机为有效横屏尺寸模拟，并非真机帧率、系统安全区或温升测试。不含竖屏与旋转提示。</p>
<p class="muted">“修复前”为本轮响应式调整前版本，已包含上一轮图层、状态、立绘与手机庭院预算修复。<a href="README.md">修复说明与测试表</a> · <a href="comparison.json">机器可读对照数据</a> · <a href="sha256.json">归档 SHA-256</a></p>
<label>分辨率 <select id="profile"></select></label><label>页面／状态 <select id="state"></select></label>
<p id="details"></p><section><figure><figcaption>修复前 · <a id="oldlink" target="_blank">打开原图</a></figcaption><img id="old" alt="修复前截图"></figure><figure><figcaption>修复后 · <a id="newlink" target="_blank">打开原图</a></figcaption><img id="new" alt="修复后截图"></figure></section>
<table><thead><tr><th>页面／状态</th><th>修复前屏外控件</th><th>修复后：屏外／横向裁切／价格与主按钮重叠</th><th>对照</th></tr></thead><tbody id="rows"></tbody></table>
<script>const data=DATA,profiles=PROFILES;
const p=document.getElementById('profile'),s=document.getElementById('state');
for(const [id,name,size] of profiles){p.add(new Option(name+' · '+size,id))}
for(const item of data.filter(x=>x.profile===profiles[0][0]))s.add(new Option(item.label,item.state));
function show(){let rows=data.filter(x=>x.profile===p.value),r=rows.find(x=>x.state===s.value)||rows[0];s.value=r.state;
for(const [img,link,path] of [['old','oldlink',r.before],['new','newlink',r.after]]){document.getElementById(img).src=path;document.getElementById(link).href=path}
document.getElementById('details').textContent=r.label+' · 原图 '+r.pixels.join(' × ')+' · 修复后几何检查：'+(r.after?'屏外 '+r.newOutside+'，横向裁切 '+r.newClipped+'，价格与主按钮重叠 '+r.newOverlap:'待生成');
const body=document.getElementById('rows');body.replaceChildren();for(const x of rows){const tr=document.createElement('tr');if(x.state===r.state)tr.className='selected';for(const value of [x.label,x.oldOutside,x.after?[x.newOutside,x.newClipped,x.newOverlap].join(' / '):'待生成']){const td=document.createElement('td');td.textContent=value;tr.append(td)}const td=document.createElement('td'),b=document.createElement('button');b.textContent='查看';b.onclick=()=>{s.value=x.state;show();window.scrollTo({top:0,behavior:'smooth'})};td.append(b);tr.append(td);body.append(tr)}history.replaceState(null,'','#'+p.value+'/'+s.value)}
p.onchange=show;s.onchange=show;const hash=location.hash.slice(1).split('/');if(profiles.some(x=>x[0]===hash[0]))p.value=hash[0];if([...s.options].some(x=>x.value===hash[1]))s.value=hash[1];else s.value='custom-deck';show();</script></html>'''
    page = page.replace("DATA", data).replace("PROFILES", profiles)
    (ARCHIVE / "index.html").write_text(page, encoding="utf-8")
    before_out = sum(len(x["outside"]) for x in before.values())
    after_out = sum(len(x["outside"]) for x in after.values())
    md = ["# 横屏 UI 修复与截图归档", "", "仅覆盖横屏，不增加竖屏或旋转提示。已同步并合并远端 `origin/main`（`2745557`，本地合并提交 `0d5a0ea`）。", "",
          "[打开交互式修复前／后图库](index.html) · [完整对照数据](comparison.json) · [截图校验清单](sha256.json)", "",
          "## 测试口径", "", "Godot 4.7.2、Windows、RTX 4060 Laptop、Vulkan Forward+。正式 `main.tscn` 和 Router 创建真实页面；使用固定种子（行旅 `20261016`、战斗 `7`，事件按脚本内固定候选种子映射），减少动效开启，逐帧等待布局后直接读取视口截图。共用浮层、三种普通事件、三种远征谜事件、整备、战报、选字与结算均归档。", "",
          "手机型号仅表示对应的有效横屏视口尺寸。测试图片按该有效尺寸渲染；下列面板像素作为型号映射参考，并未逐台连接实机。浏览器工具栏、安全区、刘海、系统字体及真实设备性能仍需实机验收。DPI 换算代码统一复用战斗现有规则；本矩阵没有模拟各型号的操作系统。", "",
          f"当前归档：修复前 {len(before)} 张，修复后 {len(after)} 张。完整矩阵为 18 组 × 51 个检查场景 = 918 对（1836 张原图）。", "",
          f"修复前屏外控件出现次数 {before_out}；修复后 {after_out}。同一缺陷在多个状态重复出现会重复计数。修复后另检查禁用横向滚动区域的横向裁切，以及奖励／商店价格与主操作按钮重叠。滚动区域内可滚达的纵向内容不计为越界。自动检查不等于所有像素级遮挡均可自动判定，另目检代表尺寸原图及全状态缩略图。", "",
          "## 修复前／后表", "", "| 界面 | 修复前 | 修复后 | 代表尺寸原图对照 |", "| --- | --- | --- | --- |"]
    fixes = [
        ("自定义构筑", "顶栏固定单行，已选数、返回和开始按钮越界", "顶栏流式换行，字块网格保留独立滚动区", "custom-deck"),
        ("字网详情", "选择节点后详情撑高侧栏，底部内容落出屏幕", "侧栏独立纵向滚动，图形区域保留高度", "glyph-detail"),
        ("幕地图", "窄屏路径节点间距不足，触区互相挤占", "路线按触控单位保留节点间距，可横向滚动", "map"),
        ("休整", "卡片最小高度可能把页尾挤出，短屏无内容滚动", "选项内容区可滚动，页眉与页尾保留", "rest"),
        ("远征探索与整备", "整张大地图作为最小宽度，右侧操作区和菜单被挤出", "地图双向滚动，行旅／字阵／战报／整备分栏切换", "expedition-actions"),
        ("设置", "长说明和固定面板宽度可能导致横向裁切", "面板按可用宽度限制，说明自动换行", "settings-top"),
        ("图鉴／选字", "大固定外边距挤占小屏内容，长副标题推挤关闭按钮", "缩小外边距，标题栏流式换行，词效字号按单位换算", "collection-words"),
        ("商店／奖励", "按钮高度与触控单位不一致，4:3 平板右侧整备印台出画", "按钮最小 48 单位，窄比例拓宽视野，短屏保留价格间距", "shop"),
        ("战斗血量", "100 / 100 等较长数值超出预留宽度，被侧栏裁切", "按实际文字宽度分配血量区，长数值适配字号", "battle-status"),
        ("战报与通用浮层", "战报固定小面板和字号，DPI 换算与战斗页不一致", "战报按视口限高、字号与触控单位缩放；暂停、词条统一换算", "battle-log"),
    ]
    for title, old, new, state in fixes:
        demo = "tablet-4x3" if title == "商店／奖励" else "phone-640x360"
        md.append(f"| {title} | {old} | {new} | [前](before/{demo}/{state}.png) / [后](after/{demo}/{state}.png) |")
    md += ["", "上一轮四项修复（图层、玩家状态、异常立绘跳变、手机庭院渲染预算）继续保留，参见[上一轮记录](../../界面修复_2026-10-17.md)。本轮修复前截图以这些修复已存在的本地版本为基线；不将其伪称为最初版本。[用户原始图层问题截图](original-layer-bug.jpg)单独保留。", "", "## 分辨率矩阵", "", "| 型号／类别 | 测试横屏尺寸 | 面板像素参考（横屏） | 前／后状态数 | 修复后几何问题 |", "| --- | --- | --- | --- | --- |"]
    for profile, title, size, panel in PROFILES:
        old = [x for k, x in before.items() if k[0] == profile]
        new = [x for k, x in after.items() if k[0] == profile]
        md.append(f"| {title} | {size} | {panel} | {len(old)} / {len(new)} | {sum(violations(x) for x in new)} |")
    md += ["", "## 页面与状态覆盖", "", "| 页面／状态 | 修复前／后截图 |", "| --- | --- |"]
    for state in sorted({k[1] for k in before}):
        md.append(f"| {LABELS.get(state, state)} | [前](before/phone-640x360/{state}.png) / [后](after/phone-640x360/{state}.png)；其他尺寸见交互图库 |")
    md += ["", "## 复现", "", "```powershell", "godot --path . res://tests/ui_resolution_matrix.tscn -- --phase=after", "godot --path . res://tests/ui_resolution_matrix.tscn -- --phase=after --stress-only", "python tests/ui_resolution_report.py --require-complete", "```", "",
           "单一尺寸可加 `--profile=iphone-13`。修复前源码为合并提交加 [baseline.patch](baseline.patch)；截图脚本见 `tests/ui_resolution_matrix.gd`。原图、视口大小、控件矩形、缺陷计数保存在每阶段 JSON 中。`before/*-extras.json` 补充了同一基线的 13 个状态，`*-stress.json` 补充满印章、绑定类遗物和 5×5 字盘的 4 个状态，未修改基线生产代码。", "",
           "`baseline-source-sha256.json` 记录基线生产源码，`source-sha256.json` 记录修复后生产源码。校验清单覆盖所有原图和矩阵 JSON。操作系统原生字体选择器和调试控制台不属于游戏正式页面，不纳入截图矩阵。", ""]
    validation = ARCHIVE / "validation.md"
    if validation.exists():
        md.append(validation.read_text(encoding="utf-8"))
    (ARCHIVE / "README.md").write_text("\n".join(md), encoding="utf-8")
    checksums = {}
    for phase in ("before", "after"):
        for path in sorted((ARCHIVE / phase).rglob("*")):
            if path.is_file():
                checksums[path.relative_to(ARCHIVE).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    (ARCHIVE / "sha256.json").write_text(json.dumps(checksums, indent=2), encoding="utf-8")
    print(f"Archived {len(before)} before / {len(after)} after; after findings={sum(violations(x) for x in after.values())}")


if __name__ == "__main__":
    main()
