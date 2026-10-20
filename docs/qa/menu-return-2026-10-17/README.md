# APK 返回主菜单卡顿：修复与性能测试

用户反馈各手机 APK 在游戏内返回主菜单卡顿 2～3 秒。本次确认 Router 每次返回都会同步新建标题、建筑／景观网格、材质和独立 3D 世界。此前的手机渲染降档只减少持续绘制成本，仍会重复执行这段 CPU 构建。

现在 Main 下保留一份标题和庭院。离开时隐藏标题、停止整棵子树处理，禁用庭院和倒影视口；返回时恢复镜头、菜单、按钮、动效偏好并取消旧入场状态。战斗和暂停菜单仍然释放；退出 Main 会释放缓存。代价是游戏期间保留一份庭院资源，需在真机同时检查内存。首次启动仍需构建庭院，本次优化针对重复返回。

## 测量口径

Godot 4.7.2，Windows，RTX 4060 Laptop，Vulkan Forward+，Debug。通过正式 Main、Router、战斗、PauseMenu 和“放弃本局（返回主界面）”按钮，连续执行 10 轮。每轮等待战斗稳定，然后按按钮，从调用前计时，记录同步路由、首个 `frame_post_draw`、其后 500 ms 内的帧间隔、节点数及内存。计时区间不截图。

`route_cpu_ms` 是按钮同步调用占用时间；`first_post_draw_ms` 是 Godot 首个绘制完成回调耗时，**不等于 GPU 完成／物理屏幕显示延迟**。`max_frame_gap_ms` 包含返回调用、渲染和旧战斗销毁；P95 按每轮短窗口分别计算，不能代表整局稳定帧率。性能不设置统一毫秒断言，以免将快电脑当作手机。

桌面配置使用 1280×720。`--mobile-budget` 在同一电脑以 960×432 启用与 APK 相同的庭院降档分支（最高 960×540、30 Hz、无反射／阴影／SSAO／额外描边）。**这只是手机画质分支测试，未模拟手机 CPU、GPU、DPI、温控或驱动，也没有取得真实手机 FPS。** APK 会自动按平台选择该分支，无需加参数。

结果见 [测量前后表](results.md)，原始数据为 [桌面修复前](before.json)、[桌面修复后](after.json)、[手机画质修复前](before-mobile-budget.json)、[手机画质修复后](after-mobile-budget.json)。`before-source/` 保存本次修改前的文本；手机画质基线只额外加入同样的 Debug 参数开关，路由仍每次重建。`source-sha256.json` 记录本次代码及证据校验值。截图只用于外观检查，不能证明不卡顿。

## 在电脑复跑

在仓库目录执行：

```powershell
godot --path . --resolution 1280x720 tests/menu_return_performance_test.tscn -- --report=user://menu-return-desktop.json
godot --path . --resolution 960x432 tests/menu_return_performance_test.tscn -- --mobile-budget --report=user://menu-return-mobile-budget.json
```

`--baseline` 只关闭“应复用标题”的断言，**不会恢复旧实现**。需要比较修复前时，应使用归档的旧源码或独立检出；不能在新实现上加该参数就当作旧结果。

## Android APK 真机测试

1. 准备低、中、高三档实际 Android 设备，记录型号、SoC、RAM、Android 版本、屏幕刷新率、分辨率、APK 版本和渲染器。统一横屏、亮度、画质与刷新率，不边充电边测；首次启动和重复返回分开统计。
2. 安装 Android SDK Platform Tools，手机开启 USB 调试。`adb devices` 确认设备在线。Godot 配好 Android SDK/JDK 与导出模板，添加 Android 导出预设。导出 Debug APK 并启用远程调试，运行正式入口，在“调试器 → 分析器／监视器”开始采样。
3. 进入战斗，打开菜单，点“返回主界面”，重复至少 20 次；地图、商店、事件、休整、远征也分别返回，另测开始入场一半取消、进入设置后返回、切后台后恢复。检查是否还有长帧、按钮锁死、错误跳页或后台绘制。Profiler 中检查 Router／标题构建是否重复出现；有 GPU 分析支持时也查看 GPU 时间。
4. 自动化同一条返回路径：在一个独立测试副本中，把 `tests/menu_return_performance_test.tscn` 临时设为主场景，导出 Debug APK 后运行；结束时日志打印 10 行 `MENU_RETURN` 和 JSON 路径 `user://menu-return-performance.json`。测试副本保留完整测试资源，正式游戏主场景仍为 `scenes/main.tscn`。测试完成恢复测试副本的入口设置。
5. 用不连接分析器的 **Release APK** 复测体感和持续表现；如需自动 JSON，也可以将上述测试场景作为独立 Release 测试包入口。自动场景固定 10 轮；实际手动测试至少 20 轮，再持续游戏 10～15 分钟后重测，观察热机降频和内存。截图／录屏另做一轮，避免影响性能数据。

以下命令的包名必须换成实际导出预设中的包名（当前工作区没有已配置的 Android 导出预设，不能虚构包名）：

```powershell
adb devices
adb logcat -v threadtime | Select-String 'MENU_RETURN|REPORT|menu_return_performance_test|godot'
adb shell dumpsys meminfo <实际包名>
adb shell dumpsys thermalservice
```

Debug 可调试包可通过 `adb shell run-as <实际包名> ls -R files` 查找报告，再用 `run-as` 读取日志里指示的相对路径；不要把本机 Windows 的 `user://` 路径当作手机路径。Release 默认不能 `run-as`，可使用设备日志中的 `MENU_RETURN` 数据或 Android Studio/Perfetto 采集。

建议验收目标：稳定 60 FPS 时帧预算 16.7 ms，30 FPS 时 33.3 ms；返回过程中重点统计超过 100 ms、500 ms 的长帧和“点击到可操作”的延迟，优先消除秒级阻塞。比较前后相同设备、APK 类型和温度下的中位数、P95、最坏值，内存应在多轮后趋于平台，避免只看平均 FPS。

## 验证与截图

- `menu_return_performance_test`：标题复用、隐藏庭院不处理也不渲染、设置／尺寸变化不会唤醒、旧战斗／菜单销毁、10 次返回节点数稳定、取消旧入场、恢复偏好、Main 退出释放。
- `title_menu_test --capture`：19 断言通过，七个入口、模态锁、焦点和桌面／短横屏外观。
- `study_flow_test --capture`：27 断言通过，开始／取消／远征、地图／战斗和返回流程。
- `mobile_presentation_fix_test --capture`：32 断言通过，含新增手机画质隐藏／恢复测试，原有状态对齐、异常立绘、弹窗层级仍通过。

本轮标题截图：[桌面](title-desktop-after.png)、[短横屏](title-landscape-after.png)、[手机画质](title-mobile-budget-after.png)。上一轮全界面 18 组分辨率 × 51 状态的 [1836 张前后截图与表格](../ui-resolution-2026-10-17/README.md) 保留其原始版本及校验值；本轮生命周期修改与性能证据单独归档。
