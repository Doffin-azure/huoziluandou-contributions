# 新增 23 件遗物模型与战后奖励

38 件遗物现在均有独立的程序化实体模型与 1024×1024 RGBA 透明图标。新增部分由 `src/ui/object_stage/relic_expansion.gd` 建模，复用倒角、旋转体、立体轮廓、绳结、刻字和表面材质。无通用展示底盘；部件按材质合并，每件不超过 12 个网格节点。原有 15 张 PNG 的 SHA-256 与远端同步前记录一致。

商店直接使用完整模型；精英和 Boss 奖励通过独立 SubViewport 展示相同实体，允许点击模型或名称领取、悬停及焦点转动。预览仅在尺寸或交互变化时渲染。长说明在各自列内滚动。界面支持鼠标、键盘、触屏，以及打开后改变窗口尺寸。

沿用既有掉落规则：庭院路线精英 1 件候选、Boss 2 选 1；经典路线精英 1 件候选、Boss 3 选 1。最后一幕保留原来的结局处理。全部 35 件普通遗物参与原有随机池，已拥有的排除；黑水瓶、命灯、寿契仍为事件专属。领取后只发放选中的一件，再完成绑定、贴金、复制或许愿等拾取步骤，最后开放选字奖励。

预览文件：

- `new-23-relics.png`：本次新增 23 件模型，名称、稀有度。
- `all-relics.png`：全部 38 件模型。
- `elite-1280.png`、`elite-640.png`：真实庭院精英奖励。
- `boss-1280.png`、`boss-640.png`：真实庭院首领奖励，使用固定的普通遗物候选以便重复核对。
- `classic-choice-640.png`：三选一及九连环长说明的小屏检查。

验证场景：

```powershell
godot --path . --rendering-method gl_compatibility res://tests/relic_expansion_test.tscn -- --capture
godot --path . --rendering-method gl_compatibility res://tests/relic_art_test.tscn
godot --path . --rendering-method gl_compatibility res://tests/classic_relic_test.tscn
godot --path . --rendering-method gl_compatibility res://tests/shop_actions_test.tscn
godot --path . --rendering-method gl_compatibility res://tests/remote_sync_test.tscn
godot --headless --path . res://tests/relic_batch2_test.tscn
godot --headless --path . res://tests/room_reward_test.tscn
```

`relic_expansion_test` 覆盖原图保留、真实模型、领取前后存档恢复、重复结算拒绝、领取前禁用选字/跳过、鼠标点模型、触屏点名称、键盘确认、拾取后的贴金/许愿/绑定、动态缩放与长说明滚动。其余场景覆盖 38 张图标和模型、五档横屏尺寸、商店实体与扣费、遗物效果、已有选字结算。最终结果与日志保存在此目录的 `verification.json` 和 `*-test.log`。
