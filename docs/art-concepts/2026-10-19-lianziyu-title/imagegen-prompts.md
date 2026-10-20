# 字标生成记录

执行方式：内置 `image_gen.imagegen`，两次编辑均启用 `transparent_background: true`。没有使用外部去背服务或 CLI，没有修改原始参考。

参考：本目录 `reference-user.png`。最终项目资产：`assets/title/branding/lianziyu-wordmark-v1.png`。

第一轮输出：`C:/Users/Think/.codex/generated_images/01a132f5-3d05-7763-a9ac-28ad136eb1c9/exec-82740ac1-dc82-4b6f-bca0-87f210cc977a.png`。

第二轮输出（采用）：`C:/Users/Think/.codex/generated_images/01a132f5-3d05-7763-a9ac-28ad136eb1c9/exec-0d68e1d5-43a7-47ea-9058-fae7d46d79c6.png`。已复制进项目。

## 第一轮：提取字标

```text
Use case: background-extraction. Asset type: transparent Chinese video game title wordmark to overlay on an existing realtime Godot courtyard. The provided image is the EDIT TARGET. Extract ONLY the large three gold Chinese calligraphy characters 炼字狱, and the rough broken vermilion brush circle behind those characters. Preserve the source title's calligraphic silhouette, all long pointed drybrush terminals, coarse worn golden-paper texture, confident thick strokes, generous internal transparent gaps, small red pigment accents on the bottom strokes, and the large red circle opening on the right. Text must be exactly 炼字狱, simplified Chinese, three characters horizontally, and remain recognizably identical to the supplied source. Remove absolutely everything else: remove the small subtitle 以字为剑，铸词为阵, remove ALL menu words and menu ornaments, remove the small red rectangular seal on the right, remove the gold clouds, remove hanging lines, remove the courtyard, moon, leaves and background. Real transparent alpha background everywhere around and inside the dry brushwork; no opaque green/black rectangle and no checkerboard baked into image. Keep the lower edge free from any extra text. Compose tightly around the entire title plus red brush circle as one wide landscape sprite with a little safe transparent margin so no strokes are cropped. This is a faithful cutout, not a redesigned logo or a whole-screen mockup.
```

第一版浮雕和描边明显，追加以下编辑以压平质感。生成器对笔画和圆痕存在重绘，所以交付资产按“参考重建”标注。

## 第二轮：压平描边和金属感

```text
Precise refinement of Image 1, a transparent Chinese title sprite. Image 2 is the original STYLE REFERENCE. Keep the exact three readable characters 炼字狱, the same calligraphy layout, the pointed dry-brush ends and the transparent cutout. ONE REQUIRED CHANGE: flatten the lettering and circle to match Image 2. Remove all thick brown bevelled outlines, yellow glow, metallic extrusion and dark heavy drop shadows around every character. The letters must be FLAT warm pale-gold brush ink with slightly distressed paper grain and irregular transparent dry-brush gaps; only extremely subtle natural dark edge, no outline border. Change the red circle to darker vermilion/cinnabar red, thin rough energetic open brushwork concentrated behind the upper-left part of the lettering, with a broken fading lower arc, not a thick saturated solid full ring. Preserve small cinnabar accents on bottom character strokes. Clean alpha everywhere around and through strokes. No background, no subtitles, no seals, no clouds, no other text, no checkerboard pixels. All ends fully inside canvas with a small transparent margin. Asset will overlay a dark teal hand-painted Chinese courtyard; flat ink texture is essential.
```
