# 正式标题接入记录

已将风格化庭院接入 `src/screens/title_screen.gd`，正常启动 `scenes/main.tscn`（F5）即可使用。继续保留当前主线的七个菜单入口；开始新冒险和墨途远征会在入场镜头结束后打开既有地图。设置使用正式 SettingsOverlay，「减少动效」实时暂停场景并隐藏落花，也跳过入场推进。

- [01-title-desktop.png](01-title-desktop.png)：正式标题，1920×1080。
- [02-title-mobile.png](02-title-mobile.png)：960×432 横屏，七个入口完整显示，按钮至少 48 屏幕像素高。
- [03-entry-camera.png](03-entry-camera.png)：正式开始过程中的庭院相机。
- [04-original-map.png](04-original-map.png)：完成入场后的既有地图。
- [05-original-battle.png](05-original-battle.png)：从地图进入的既有战斗；本轮没有重做其美术或规则。

正式背景与审阅工具共用 `src/title/courtyard_view.gd`；运行代码在 `src/title/courtyard/`，素材在 `assets/title/courtyard/materials/`。正式菜单不包含 F2 灯光面板或样板返回按钮。标题显示时旧书房停止渲染，离开标题后庭院及其镜像视口被释放。

## 验证

- 正式菜单原生渲染：19 项通过、0 项失败，包含键盘焦点、七个入口、浮层阻断、ESC、偏好实时响应、自定义／图谱路由、原图谱机位、桌面／手机横屏截图及物理触控尺寸。
- 正式流程：原生 27 项通过、0 项失败；最终图谱背景机位修正后，再以 headless 执行 27 项通过、0 项失败。包括新局仅创建一次、取消不会延迟跳图、返回标题、减少动效、远征与资源释放。
- 共用背景原生检查：33 项通过、0 项失败；覆盖材质、灯光、反射、雾、花瓣、相机、牌匾文字与动态开关。
- 战斗意图界面回归：headless 49 项通过、0 项失败。

三份原生日志标准错误输出均为空。见同目录日志与 [verification.json](verification.json)。手机检查是桌面上 960×432 的窗口模拟，未声称移动设备性能通过；体积雾和屏幕法线墨线只在 Forward+ 使用。

当前分支没有存档管理器：存档／继续冒险仍在未合并的 `feat/study-battle-ui` 中。本次保留当前主线功能，没有合并旧前端分支、修改游戏状态或存档格式。

工作保留在 `feat/title-3d-sample`，未提交或推送。实现分工见 `src/title/README.md`。旧的审阅图和原始建模材质 GLB 继续保留在上级目录。
