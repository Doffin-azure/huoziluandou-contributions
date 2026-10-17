# 铜印同屏母稿 · 第一轮

评审状态：用户认为仍缺少墨灵的画法，AI 感明显，本稿未通过。后续尝试与失败原因见 [第二轮记录](V2-REVIEW.md)。两轮均未替换正式敌人素材。

本轮按用户“先试试铜印”的要求，先交付可评审的同屏母稿。使用内置 ImageGen；以实际铜印战斗截图为编辑目标，直接参照原始墨灵的画法。当前运行素材与攻击姿势未替换。

- `before-runtime.png`：Godot 4.7.2 原生截图，铜印生命 48/48、攻击意图 10，选中合法「击→破」。
- `bronze-seal-master-v1.png`：生成式局部画法校准稿，不是修改后实机截图。保留原图尺寸与内容，未做滤镜、裁切、重采样或二次透明提取。
- 原生成文件：`exec-b9f963cf-d312-4ef0-9606-63f7aad093bd.png`。

## 这版的改动

放大头脸与前爪，让角色接近墨灵的画面分量；去掉尾端副兽头，保留兽形与胸前方形印面；身体使用较完整的暗青色块，减少满铺斑驳和泛金亮边。保留铜印身份，不借用墨灵的面具、背环与披风。

## 评审与后续边界

重点检查画法能否与墨灵、背景共存，以及脸部与印面的主次。生成稿的界面内容仅为风格参照，实时 UI 与玩法仍以游戏为准。母稿方向确认后，用蒙版拆分固定像素并处理边缘，避免再调用生成式提取重解释角色；再分别校准待机显示、攻击留白和姿势锚点。不能直接把整张图覆盖到游戏上。

参考为 `assets/taopunk/ink_guardian.png`、当前 `assets/taopunk/enemies/bronze_seal.png` 及本轮实际战斗截图，不采用纸卫作为中间参考。

截图工具：`src/tools/bronze_seal_sample.tscn`。原生执行错误日志为空。没有修改敌人数据、伤害、资源或正式战斗素材；未提交或推送。

## 完整生成提示词

```text
Use case: precise-object-edit. Deliver ONE wide IN-SCENE ART MASTER for a Chinese character-combat game, same 2.5:1 aspect ratio as image 1. Image 1 is the EDIT TARGET: a REAL screenshot of the current bronze-seal enemy battle. Image 2 is the DIRECT AND ONLY rendering-quality benchmark: the approved original ink guardian. Image 3 is the old bronze-seal character, for identity only, NOT its shiny material style. Edit ONLY the bronze creature in the lower-right enemy area BELOW the attack-intent panel. All background architecture, red trees, paper panels, board, frame, UI positions, buttons, typography, the enemy name 铜印, 48 / 48, intent 10, and every other number/text must remain unchanged. This is a localized creature paintover inside that exact screenshot, not a UI redesign.
Redesign the bronze seal as a dignified heavy crouching ritual stamp-beast, three-quarter view facing left, rooted on the existing foreground ledge. Preserve its beast identity, two weight-bearing forepaws, low broad body, and one square chest seal. Make the broad feline-lion head the clear primary focus, with calm narrow cinnabar eyes, a powerful blunt muzzle and a few precise stylized mane contours. The chest seal is a subordinate quiet vermilion recessed square bearing ONE simple non-letter stamp groove. Remove the secondary animal head on the tail; one plain thick curling tail may sit quietly behind the torso. No human body, cloak, back halo, gears, jewelry or dangling ornaments. This must NOT become another version of the guardian, but must unmistakably belong to its illustrated world.
CRITICAL DRAWING LANGUAGE: match image 2's confident fine uneven ink contours, selected structural accents, broad opaque pigment shapes, and matte two-to-three-value cel painting. Create a few large uninterrupted ink-jade areas over the shoulders, flank and forepaws, with bronze concentrated on the forehead, muzzle planes, seal frame and selected joints. Match the original guardian's economy: detailing concentrated at the face and functional joints; dark body surfaces are restful. NO all-over mottled patina, NO grain or speckles, NO bright edge around every surface, NO glossy sculpted bronze / toy / CGI look, NO triangulated low-poly facets. Very restrained hand-painted wear at a few structural corners only. Warm upper-left face light and cool deep jade body shadow, same lighting logic as the scene. Do not use photographic shading or buttery airbrushed rendering. Linework should describe weight and anatomy rather than random cracks.
FRAMING: enlarge the head and shoulders relative to the old beast. Use nearly the full width of the enemy illustration area (approximately x=1300..1790 in the 1980px-wide reference). The creature's silhouette begins just below the intent box, and its lower body can meet/disappear behind the existing foreground ledge just like the approved guardian's waist crop. Give head and forepaws enough scale to read at gameplay size; avoid a small distant full-body specimen. Do not overlap any HP bar, enemy name, intent symbol/value or bottom buttons. Retain the scenery visible around the silhouette and preserve natural overlaps with paper and ledge. One creature, one finished frame, no before/after split, no notes, no watermark. Opaque full-scene image.
```

