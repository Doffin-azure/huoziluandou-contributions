# 青铜绘卷运行素材

2026-10-16 接入说明：本目录的运行素材从本地 `feat/study-battle-ui` 分支（`05579cc`）原样恢复到标题场景分支，未重新生成或处理敌人。以下历史记录中的 `source/`、原始概念图与离线处理脚本仍保存在该原分支；本工作区仅打包实际运行所需素材，未重复复制归档。当前入口、规则兼容与实机验证见 `docs/art-concepts/2026-10-16/battle-integration/README.md`。

本目录使用内置 imagegen 基于用户确认的概念图制作，日期 2026-10-15。对应参考图位于 docs/art-concepts/2026-10-15/nine-sols-battle-ui.png。

第一只墨灵保留已确认的原版素材，本轮未重绘或重新处理。其他八只按用户确认的纸卫同屏稿继续校准：先在实际战斗画面中统一画法，再拆分透明角色，最后做轻度、非生成式保边降噪。原稿保存在 `source/`，该目录带 `.gdignore`，Godot 不导入其中的备份素材。

- ritual_courtyard.png：不含 UI、文字或怪物的环境底图。
- bronze_frame.png：中央与外围透明的机关框；桌面按原比例绘制完整机关，手机使用八个边角区适配，中心仍是实时字块。
- ink_guardian.png：根据定稿单独提取的墨灵护法透明插画，替代图集中的墨灵。
- parchment_panel.png：按定稿制作的暖色纸面、青铜压角和淡墨山水；右侧纸面在运行时让出场景。
- enemies/*.png：另外八只敌人的独立透明素材；TaopunkArt 按各自实际边界取区，InkSpirit 保持完整形体、底部对齐。详见 [敌人素材说明](enemies/README.md)。
- enemy_portraits.png：旧九宫图集，保留作历史参考，当前战斗不再读取。
- source/ink_guardian.png、source/enemy_portraits.png、source/enemies/*.png：降噪前的原图，便于重新处理与回退。

本轮八只敌人的完整内置 imagegen 提示词与同屏校准稿位于 [style-calibration/PROMPTS.md](../../docs/art-concepts/2026-10-15/style-calibration/PROMPTS.md)。该目录是生成式画法参考；[enemy-gallery.png](../../docs/art-concepts/2026-10-15/implemented/enemy-gallery.png) 才是最终 Godot 原生运行截图。

墨灵已增加使用原图的 2D 骨骼蒙皮样板，包含待机、攻击与添加污染字动作。该动画没有重绘或改写本目录的图片；实现、边界与实机动图见 [墨灵动画样板](../../docs/墨灵动画样板.md)。

其余八只敌人的攻击使用 `attacks/` 中新绘的关键姿势图集，原 `enemies/` PNG 保留用于待机。不是复制墨灵的局部晃动；每只按其形体设计不同的发力和回收。实现、素材索引、提示词和实机合辑见 [敌人攻击动画](../../docs/敌人攻击动画.md)。

手绘位图不包含血条、意图数值、字体和按钮；这些均由 Godot 实时绘制。字块仍使用独立 3D 表现和投影命中，颜色采用平涂材质。书房和旧版宣纸共享投影方案保留，新战斗风格不渲染隐藏的书房视口。

字盘字体由 Ink.board_font 独立管理。设置中可选择 TTF / OTF 等字体文件并恢复默认；缺字回退至内置字体，不改变说明和数字，不重建战斗。运行时字体加载依据 Godot 官方说明：https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html

## 非生成式图像增强

处理脚本：`tools/enhance_enemy_art.py`。依赖 numpy、Pillow、opencv-python-headless，仅在离线处理素材时需要；运行游戏不需要 Python 或 OpenCV。

```sh
python tools/enhance_enemy_art.py
```

实际验证环境：OpenCV 5.0.0、NumPy 2.3.5。处理从 `source/` 读取，输出到本目录，禁止输入输出为同一个目录，避免对已经降噪的图反复处理。默认使用非局部均值降噪（亮度/色度强度 10，模板 7，搜索窗口 21）和保边双边滤波（直径 7，颜色阈值 28，空间阈值 3.5）。

原图的实色区域大多带 252/253 的 alpha，因此按 alpha≥240 识别色面，再向内腐蚀 3 像素保护轮廓；所有 alpha 值逐像素保持一致，低透明度边缘的 RGB 也保持不变。输出仍为原尺寸 RGBA PNG。新八只采用强度 6，命令与取区说明见 enemies/README.md；默认强度 10 的命令用于之前的墨灵及旧图集处理，不必反复执行。

脚本同时输出局部对照和数据校验报告。已保存的对照位于 `docs/art-concepts/2026-10-15/implemented/enemy-detail-comparison.png`，左边原图，右边增强结果。对照按相同坐标裁切、最近邻放大，不对对照图另做美化。

## 初始素材的生成提示词（新八只的重绘记录见上方链接）

### 还原修订：独立墨灵（内置 imagegen，透明背景）

```text
Use case: background-extraction. Asset type: transparent 2D game enemy sprite. Input image 1 is the approved game UI, extract ONLY the large guardian from its lower right. Preserve exactly the same front three-quarter pose, golden feline horned mechanical mask with red third-eye, the ornate bronze circular halo, layered broad dark jade cape and long red ribbons, ink outlines and muted cel shaded color blocks. Remove ALL UI, paper, landscape, text, numbers, ground and other objects; actual transparent background. Show the broad shoulders and torso extending to the bottom of the canvas, with a deliberate cropped waist at bottom edge, ribbons flowing to the sides. Preserve illustrated engraving line work, no photorealism, no simplified icons, no redesign. Wide approximately 5:4 composition with guardian filling the canvas and halo complete; tight bounds, small transparent margin. This will be composited over a teal landscape with UI ABOVE it, so no baked background or glow.
```

### 还原修订：纸面（内置 imagegen，透明背景）

```text
Use case: precise-object-edit. Asset type: blank 2D game UI parchment panel. Input image 1 is the approved game UI. Create ONLY the blank LEFT parchment panel from that image, keeping its same warm aged ochre ivory paper tone, mostly straight gently chipped edges, subtle small fibers, crisp thin dark ink outline and chunky dark teal and antique bronze mechanical corner clamps matching the reference exactly. Panel is almost square, portrait ratio about 0.95:1. Blank upper 65% for dynamic live UI text. In lower 30%, delicate very low contrast sepia ink landscape of distant Chinese mountains and temple roofs, just as the left panel in the reference. Surface is fairly uniform warm beige NOT white watercolor clouds. Keep corners substantial painted metal fittings. No text, no glyphs, no numbers, no buttons, no surrounding scene, no other UI. Actual transparent background outside the panel, panel fills canvas with narrow 2% safe margin. Flat handdrawn cel shading and aged print grain.
```

### 环境

```text
Use case: precise-object-edit / game environment asset extraction. The supplied approved UI concept is the visual reference. Produce a standalone wide 20:9 illustrated GAME BATTLE BACKGROUND at approximately 2560x1152. Remove ALL UI: no character tiles, no board, no buttons, no panels, no lettering, no numbers, no hearts or resource symbols. Remove the large foreground guardian character. Reconstruct the scene behind those objects as a cohesive hand-drawn tao-punk ritual workshop courtyard: midnight and oxidized teal architectural silhouettes, dark ink contour lines, restrained red-leaf trees framing the far left and right edges, an ochre moon behind distant tiered temple roofs, aged bronze fittings and hanging ribbon details. Low contrast and open in the central 80% so live UI can be placed on top; richly drawn near the outer edges. Very dark jade low platform/rail along the bottom 8% and a few small bronze fixtures at the corners. Match the approved concept's flat cel-shaded shapes, irregular black ink contours, graphic color masses, parchment-like grain and controlled antique-gold accents; not photoreal, not 3D rendered, no neon glow, no gradients that wash out black outlines. This is only the environment layer. No border enclosing the entire image, no watermark. Opaque background.
```

### 字盘边框

```text
Use case: precise-object-edit / game UI frame asset. Use the approved concept's central teal-bronze character tray as the visual reference. Generate ONE standalone SQUARE mechanical ritual-board FRAME, orthographic front view, centered, on a genuinely TRANSPARENT background. The central 82% of the square must be an EMPTY fully transparent square aperture, with no paper, no tiles, no characters, no grid and no fill. The frame lives only in the outer 9% on each side: layered dark oxidized jade metal bands, black hand-inked outlines, worn restrained ochre-bronze corner clamps, fine non-luminous engraved channels and a small round bronze lock at the TOP CENTER built entirely into the narrow frame band. Visually match the reference's hand-drawn tao-punk cel shading and crisp graphic forms. Keep all four borders straight, symmetric in thickness, fully visible and within the canvas. No perspective, no background shadow plane, no props outside the frame, no text, no title, no mockup. Intended to overlay a live 4x4 board; the aperture must remain open and unobstructed. 1536x1536 or larger square. Transparent outer canvas AND inner aperture.
```

### 敌人图集

```text
Use case: game production sprite atlas / character asset design. Based on the approved battle concept's original gold-mask guardian, create a coherent ENEMY PORTRAIT ATLAS: a square image containing EXACTLY 3 rows by 3 columns of distinct upper-body enemies, nine evenly sized square cells, on a genuinely TRANSPARENT background. No visible grid lines or dividers and absolutely NO text, numbers, names, HUD, UI, decorative framing panels or opaque backgrounds. Each enemy must be completely contained in its own square, with at least 8% transparent padding on all cell edges, including halos, ribbons and armor; neighboring silhouettes must never touch. Center every bust at the same scale, chest/waist-up, front or slight 3/4 view, facing toward screen-left, with full head and upper torso visible. Match the reference exactly in craft: confident irregular black ink outlines, broad cel-color planes, dark jade robes and armor, ochre-bronze ritual hardware, disciplined cinnabar accents, minimal shadow colors and subtle paper grain; mature illustrated game enemies, not chibi, not realistic, not generic fantasy CGI. Maintain clear silhouette differences.
EXACT CELL ORDER:
Top row left: ink-spirit guardian, the approved narrow feline/oni GOLD MASK with tall pointed ears/horns, small red third-eye aperture, round ancient bronze mechanism behind its head, dark jade cloak and a few red silk ribbons.
Top row middle: bronze-seal sentinel, broad square stamped bronze faceplate and heavy jade shoulder armor, a ring-shaped seal apparatus, stern geometric silhouette.
Top row right: iron-stroke duelist, slender angular dark iron birdlike mask, brush-blade crest, narrow teal armor and an upright sharp silhouette.
Middle row left: paper guard, layered folded ivory talisman-paper armor and a pale angular paper mask, dark jade under-robe, restrained red bindings, no writing on talismans.
Middle row middle: rust scribe, aged red-ochre hooded scholar automaton, long bronze beak-like mask, brush-like ornamental whiskers, jade ink vessel collar.
Middle row right: ember imp, small fierce vermilion-and-charcoal fire spirit with a jagged dark bronze mask, contained flame-shaped mane, compact lively silhouette.
Bottom row left: lead-plate boss, massive charcoal and oxidized bronze ceremonial press armor with stacked rectangular head plates and a small red slit eye.
Bottom row middle: word demon boss, elegant menacing horned ivory mask, long dark jade robe, broad coiling vermilion ribbon silhouette and thin bronze ritual halo.
Bottom row right: chaos-press boss, colossal asymmetric ritual machine demon, ink-black bronze face with multiple small red apertures and a large toothed jade halo.
Each is an original enemy in the same world, no existing named game character or copied logo. Full atlas 3072x3072 if possible, otherwise a square high-resolution image. Strictly equal nine-cell placement; transparent backgrounds are essential.
```
