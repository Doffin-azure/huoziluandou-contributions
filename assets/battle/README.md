# 战斗表现素材

- `ink_spirit.png`：2026-10-12 使用内置 ImageGen 生成的透明墨团，参考已选定的宣纸活字战斗样稿；不含字形。
- `ink_spirit_character.png`：2026-10-13 使用内置 ImageGen 以 `docs/ui-concepts/2026-10-12/battle-desktop-art-pass.png` 为角色/风格参考生成的独立透明墨灵插画，含双眼、纸巾和朱砂印。墨灵使用该插画，其他敌人仍在原墨团上动态绘制各自字形。
- 新素材保留原始透明通道，通过 Godot 导入并生成 mipmaps；未把预览图整张作为游戏界面。
- 受击、蓄势、击败由 Godot Tween 驱动，不写入战斗随机数。
- `type_faces_atlas.png`：2026-10-13 使用内置 ImageGen 生成的四种空白活字表面，2×2 排列，不含文字。3D 字盘按实体 UID 选择象限；字形仍由游戏动态绘制。

旧宣纸主题的空白纸张及旧木材纹理已随主题删除，当前装饰资源位于 `assets/taopunk/`。
