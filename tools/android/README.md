# Android 一键测试

在仓库根目录双击 `安卓测试.cmd`，或在终端执行：

```powershell
.\安卓测试.cmd
```

脚本自动启动 `Huozi_API_35` 模拟器（也可使用已连接、已授权 USB 调试的手机），检查源文件变化、构建对应架构的 APK、通过 ADB 覆盖部署并启动。无需传包、确认安装或手动卸载。源文件与安装包均未变化时，直接启动已安装的游戏。

`adb install -r` 保留应用数据；脚本不调用卸载或清除数据。不会关闭用户已有的模拟器。多个设备在线时，用 `--serial emulator-5554` 或手机的 ADB 序列号选择目标。

## 不重新打包的布局检查

```powershell
.\安卓测试.cmd --profile phone-720
.\安卓测试.cmd --profile phone-1080
.\安卓测试.cmd --profile phone-1440
.\安卓测试.cmd --profile user-screenshot
.\安卓测试.cmd --profile compact
.\安卓测试.cmd --profile tablet
.\安卓测试.cmd --capture
```

切换参数仅改变模拟器的分辨率和 DPI，然后重启当前游戏，使依赖屏幕尺寸的页面重新布局。截图保存到 `shots/android/时间戳/`，同时记录实际屏幕尺寸和密度。`--capture` 只截图，不重启；`--reset-display` 恢复模拟器原始参数。脚本拒绝修改实体手机的屏幕参数。

| 参数 | 横屏像素 | DPI |
|---|---|---|
| phone-720 | 1600×720 | 320 |
| phone-1080 | 2400×1080 | 440 |
| phone-1440 | 3200×1440 | 560 |
| user-screenshot | 2436×1120 | 480（用户设备真实 DPI 未知） |
| compact | 1280×720 | 320 |
| tablet | 1920×1200 | 240 |

还可使用 `vivo-y33`、`redmi-7a`、`vivo-y3`、`iqoo-u1x`、`huawei-70s`、`redmi-9a`、`iqoo-10`、`reference-2664`、`reference-large-ui`、`low-854`。这些档位和桌面布局测试共用 `tests/fixtures/mobile_screen_profiles.json`；分辨率来自厂商参数，DPI 和安全区为压力测试设定，不代表对应手机的实测值。例如 `安卓测试.cmd --profile redmi-7a`。旧手机名称仅用于屏幕布局采样，不代表支持它的旧系统或处理器。

## 手机卡顿采样

手机连接后，同样可以自动覆盖部署。运行中的游戏可直接采集日志：

```powershell
.\安卓测试.cmd --serial 手机序列号 --logs
.\安卓测试.cmd --serial 手机序列号 --perf
```

`--perf` 录制 15 秒日志、CPU 和 gfxinfo 信息，这段时间操作“返回主菜单”。Godot 的 SurfaceView/Vulkan 帧耗时不一定完整出现在 gfxinfo；要定位原生渲染或线程卡顿，可在 Android Studio Profiler 中采集 System Trace。模拟器的 FPS 和耗时不代表手机性能。

## 构建与环境

使用系统 Python 3、Godot、Android SDK/JDK 和 Godot 的 Android release 导出模板，不需要将 Godot 游戏改成 Android Studio 的 Gradle 项目。`Apply Changes` 不会热更新 Godot 的 GDScript，脚本自动完成必要的构建和覆盖部署。

可用 `--sdk`、`--godot`、`--java` 指定路径，或设置 `ANDROID_SDK_ROOT`、`GODOT_EXE`、`JAVA_HOME`。当前机器的 JDK 路径已写入忽略提交的 `tools/android/local.json`，不会将个人安装路径带入仓库。

构建临时增加独立导出预设，并在结束后还原本地 `export_presets.cfg`；使用已有 Godot 测试签名。产物位于 `build/android/dev/架构/huozi-dev.apk`，不会覆盖交付的手机 release APK。为兼容模拟器，x86_64 测试包使用 GL Compatibility；手机包保留引擎默认渲染方式。

首次准备需要在 Android Studio SDK Manager 安装 Android Emulator、Command-line Tools 和 Android 35 x86_64 系统镜像，并在 Device Manager 中创建 `Huozi_API_35`。本机已由当前任务准备这些组件；详细验证记录见 `docs/qa/android-emulator-2026-10-18/`。
