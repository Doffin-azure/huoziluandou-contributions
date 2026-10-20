# 新手教程交互验收

日期：2026-10-18。入口：主菜单 → 新手教程。仅覆盖横屏。

## 新增交互

| 环节 | 原行为 | 新行为 |
|---|---|---|
| 入门 | 首场战斗名为“初试”，没有逐步操作引导 | 主菜单新增独立、可重复进入的练习 |
| 单字 | 玩家自行理解选字与确认 | 高亮左上角“击”，选中预览，确认后实际造成 4 点伤害 |
| 组词 | 玩家自行摸索路径与字序 | 点选或滑动连接“击 → 破”，实际造成 8 点伤害；错误选择不会消耗字 |
| 防御 | 自行理解意图与格挡 | 观察木人攻击 6 的意图，打出“防御”获得 10 点临时格挡 |
| 回合 | 自行探索结束回合 | 实际结算敌方攻击、格挡清除和新回合补字；生命保持 30 |
| 重试与退出 | 无独立练习 | 清空选择、暂停、重练、随时退出；完成后可返回主菜单或再练 |
| 冒险进度 | 无练习隔离机制 | 全新局部战斗对象，不启动新冒险、不复制永久字牌、不继承遗物，不覆盖冒险存档 |

教程暂不强制首次启动进入，也不保存练习中的步骤。教程中的显式确认只作用于该字盘，保留玩家原有的“松手立即出字”设置。鼠标、原生触屏和键盘确认复用正式 BoardView；结束回合也支持原有快捷键。

## 分辨率截图

以下为 Godot 原生窗口实际渲染，并按 Android 密度计算触控尺寸；不是对应品牌真机测试。截图包含独立教程的新增画面，修改前没有该画面，因此没有伪造“修复前”截图。

| 分辨率 / 注入密度 | 选字 | 组词预览 | 防御后 | 完成 |
|---|---|---|---|---|
| 1280×720 / 桌面 | [截图](1280x720-0dpi-01-select.png) | [截图](1280x720-0dpi-02-word.png) | [截图](1280x720-0dpi-03-defense.png) | [截图](1280x720-0dpi-04-complete.png) |
| 960×432 / 160 dpi | [截图](960x432-160dpi-01-select.png) | [截图](960x432-160dpi-02-word.png) | [截图](960x432-160dpi-03-defense.png) | [截图](960x432-160dpi-04-complete.png) |
| 1280×720 / 320 dpi | [截图](1280x720-320dpi-01-select.png) | [截图](1280x720-320dpi-02-word.png) | [截图](1280x720-320dpi-03-defense.png) | [截图](1280x720-320dpi-04-complete.png) |
| 2400×1080 / 440 dpi | [截图](2400x1080-440dpi-01-select.png) | [截图](2400x1080-440dpi-02-word.png) | [截图](2400x1080-440dpi-03-defense.png) | [截图](2400x1080-440dpi-04-complete.png) |
| 2532×1170 / 460 dpi | [截图](2532x1170-460dpi-01-select.png) | [截图](2532x1170-460dpi-02-word.png) | [截图](2532x1170-460dpi-03-defense.png) | [截图](2532x1170-460dpi-04-complete.png) |

标题入口：[桌面](title-desktop.png)、[960×432 横屏](title-960x432.png)。高密度紧凑布局经过截图修正：缩短每步文案、前移效果预览、收紧留白、调整状态字号，保证选词时预览及双方状态能同时看到；长错误提示可纵向滚动，操作按钮固定在底部。

## 回归结果

| 测试 | 结果 | 覆盖 |
|---|---|---|
| tutorial_interaction_test，原生渲染与截图 | 172 通过 / 0 失败 | 五种尺寸/密度完整触屏流程、逐字点按与滑动、取消手势、误选恢复、显式确认、真实伤害与防御、结束回合补字、重练、四阶段中途退出、暂停锁定、Android 系统返回通知及存档隔离 |
| title_menu_test，含截图 | 19 通过 / 0 失败 | 主菜单全部入口、紧凑横屏 48 像素点击区域、缓存标题与返回行为 |
| autosave_test | 44 通过 / 0 失败 | 战斗及各冒险界面的自动保存、恢复与存档生命周期 |
| touch_access_audit_test | 102 通过 / 0 失败 | 正式界面原生触屏点击、滑动保护、卡片与详情浮层，确保字盘默认手感未回退 |

合计 337 项检查通过。教程存档隔离断言比较保存文件的完整字节、全部持久字段和 RNG 编码，以及原永久字牌对象身份；完成、重练和每个阶段退出后均不变，随后仍能恢复原冒险。教程内 Android 系统返回先清空选字，否则打开练习暂停；再次返回关闭暂停。离开教程恢复此前的系统返回策略。

运行命令：

```powershell
godot --path . --rendering-method gl_compatibility res://tests/tutorial_interaction_test.tscn -- --capture
godot --path . --rendering-method gl_compatibility res://tests/title_menu_test.tscn -- --capture
godot --headless --path . res://tests/autosave_test.tscn
godot --headless --path . res://tests/touch_access_audit_test.tscn
```

日志位于本目录的 `test-*.txt`。桌面渲染测试窗口超过物理显示器尺寸时居中，避免系统鼠标模拟在显示器边缘裁切输入坐标。

## Android APK

版本：`2026.10.18-tutorial`，versionCode `2026101805`。手机包：`build/android/20261018-tutorial/huoziluandou-tutorial-arm64.apk`。

SHA-256：`f13eb6db35167181ec06375642c303f08e4790c9b827d3cab37b5ed512616c16`。

Android Studio 的 API 35 / x86_64 模拟器以 2400×1080、440 dpi 实际安装运行同版本测试包，使用 `adb install -r` 保留现有应用数据。通过原生点击与滑动完成单字、组词、10 点格挡、结束回合，生命保持 30；同时验证暂停与返回。手机 ARM64 包已导出；未声称在实体手机上完成测试。

模拟器截图：[标题入口](android-title.png)、[单字步骤](android-01-select.png)、[组词预览](android-02-word.png)、[防御提示](android-03-defense-select.png)、[格挡与结束回合](android-04-defense.png)、[完成](android-05-complete.png)、[系统返回暂停](android-06-pause.png)。运行日志：[android-logcat.txt](android-logcat.txt)。

后续代码迭代可继续使用已有 Android Studio 模拟器和 `python -X utf8 tools/android/dev.py --rebuild --profile phone-1080` 自动覆盖安装，无需卸载或清除数据。
