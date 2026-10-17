# 字肆店主

`portrait.png` 是透明 RGBA 角色插画，由内置 ImageGen 于 2026-10-16 生成，用于取代商店柜台中的低多边形占位人物。未用滤镜或后期脚本修改生成图片。

使用 `Sprite3D` 放入柜台世界，固定竖轴朝向相机、保留深度遮挡。画内明暗由插画承担，避免实时光照把人物重新变成光滑塑料；轻微整体调色使其接近柜台环境。无损导入、生成 mipmaps、修复透明边缘、alpha-to-coverage 抗锯齿。素材随项目打包，不引用用户临时目录。

## 参考来源

- `feat/study-battle-ui` 分支中的 `assets/taopunk/enemies/paper_guard.png` 和 `rust_scribe.png`：仅作既有角色画法参考，未更改或导入其他分支的玩法代码。
- 用户最终定稿战斗图 `codex-clipboard-e38eddec-4558-424b-9dc6-9c2a98170e1d.png`：整体色彩与墨线参考。
- 生成原文件：`exec-3ee758b9-51d0-45a2-a52c-7bb0b47774a6.png`，内置工具输出。项目中的 `portrait.png` 是原样复制。

## 最终提示词

Use case: stylized-concept. Asset: ONE transparent 2D game NPC portrait sprite, a type-foundry SHOPKEEPER, to replace a low-poly placeholder. Images 1 and 2 are STYLE REFERENCES for the shipped enemies: match their hand ink linework, hard-edged planes of color, outline weights, restrained aged-pigment shading and anatomical design quality. Image 3 is the approved overall art direction, especially ink-teal, parchment ivory, ochre bronze and a small cinnabar accent. Do NOT include the UI or scene. Create an original calm enigmatic NONCOMBAT shopkeeper, a tall narrow crane-like spirit wearing an ivory angular long beaked mask, narrow dark horizontal eyes without glowing pupils, a folded asymmetrical ochre headcloth/hood (NO conical hat), a large ink-teal robe with a few designed long folds, one restrained red sash and two long elegantly jointed parchment-colored hands resting in front of the waist as if on an invisible shop counter. Three-quarter front pose facing slightly toward image left, stooped dignified merchant posture, not attacking. Complete waist-up portrait, head/hood/shoulders/hands entirely inside frame, generous transparent margin around silhouette. Broad clear shapes and fine selective ink lines, no jewelry clutter, no back halo, no gears, no weapons, no cute chibi proportions, no polygonal 3D shading, no plasticky finish. Illustration must look drawn by the same artist as the reference enemies, not like a separate mascot. Large clean color interiors: NO grain, NO random speckles, NO paper noise overlays. Muted dark teal robe, warm ivory mask and hands, aged ochre headcloth, one cinnabar accent. Character is lit gently from upper left, two to three shade values with deliberate ink contour marks. Transparent background with actual alpha, no ground, no cast shadow, no backdrop, no text, no watermark. Deliver one polished production-ready portrait sprite.
