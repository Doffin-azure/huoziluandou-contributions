# 事件美术批量包

日期：2026-10-19。状态：33 张首批图已由本机 ComfyUI 生成并接入；等待美术审图和微调。

## 当前范围

- 事件总数：37
- 已有图：4
  - `ink_pool`
  - `broken_stele`
  - `old_bookshop`
  - `lantern_riddle`
- 首批生成：33 个未配图事件（已完成，待审）
- 本文不直接改动事件目录；图片生成后由 `EventArt` 从 manifest 自动发现。

## 文件

- `assets/events/prompts_batch_2026-10-19.json`
  - 33 条事件场景、种子、目标路径和统一风格/负向词。
- `assets/events/art_manifest.json`
  - 全部 37 个事件的图片路径、风格和状态。
  - 33 个新图当前为 `status: generated`，等待美术替换。
- `src/core/event_art.gd`
  - 读取 manifest；只有目标文件真实存在时才返回路径。
- `tools/event_art_batch.py`
  - 读取 prompt 包，向本机 ComfyUI 提交单张任务。
  - `--dry-run` 已验证，不会启动生成。

## 画风基准

以 `lantern_riddle_v1.png` 为当前唯一样板：

- 深蓝绿/炭黑园林环境；
- 朱砂作为主焦点；
- 旧金器件；
- 纸白暖光；
- 黑色手绘勾线、平涂色块、两到三层阴影；
- 少量旧印刷颗粒；
- 不写实、不 3D、不大面积水墨洗染。

所有新图：

- 1024×1024，透明背景；
- 主体占 70%～85%，四边留暗部；
- 不画人物、脸、手；
- 不画可读汉字、伪书法、UI、标题、边框；
- 书页、碑面、木活字、骰子表面保持空白；
- 露天火焰使用少量冷色鬼火。

## 批量生成（已完成首批）

本机 ComfyUI 工作流：

```text
docs/art-concepts/2026-10-19-event-art-sample/lantern_riddle_complete.api.json
```

先干跑：

```bash
python tools/event_art_batch.py --dry-run
python tools/event_art_batch.py --dry-run --limit 3
```

生成单张：

```bash
python tools/event_art_batch.py --only shefu
```

生成一批：

```bash
python tools/event_art_batch.py --start 0 --limit 5
```

首批 33 张已写入 `assets/events/<event_id>_v1.png`，并批量写入 `event_catalog.gd` 的 `illustration` 字段。美术微调时同名替换即可；`EventArt` 仍保留 manifest 兜底。

## 待办

1. 用户逐张审图，标出需要重画的场景；
2. 微调 `prompts_batch_2026-10-19.json` 中对应事件的 scene；
3. 用 `--only <event_id>` 重跑单张，同名覆盖；
4. 最后把 manifest 状态改为 final。

`event_art_test` 当前 `PASS=525 FAIL=0`，说明 37 张图都能加载、透明边缘和事件页布局没有新增回归。
