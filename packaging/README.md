# 炼字狱 Android 打包

产物为 ARM64、离线、签名发布 APK。应用标识 `com.lianziyu.game`，当前版本 `0.1.0`、版本号 `1`。横屏，手机端采用 Mobile 渲染器。

## 本次产物与依赖

构建文件位于工程外相邻目录 `../outputs/lianziyu_android_20261017/`。该目录内 `toolchain/` 包含官方 Godot 4.7.2 Android release 模板、Temurin JDK 17、Android SDK platform-tools 和 build-tools 35.0.1。

Godot 模板从官方发行 ZIP 以 HTTP Range 提取 Android release APK，并校验 ZIP CRC；JDK 校验官方 SHA256，Android 工具校验官方仓库 SHA1。下载元数据保存在工具链目录。普通 APK 导出使用官方预构建模板，其实际最低 SDK 为24、目标 SDK为36；没有使用 Gradle 重编译。

本机构建前已在 Godot 编辑器设置中把 Java SDK Path 和 Android SDK Path 指向上述 JDK 和 android-sdk。新机器需要先设置相应路径，并安装匹配的官方模板和工具。

## 构建与校验

```bash
python3 packaging/build_android.py \
  --toolchain ../outputs/lianziyu_android_20261017/toolchain \
  --output ../outputs/lianziyu_android_20261017/炼字狱-v0.1.0-android.apk

python3 packaging/verify_android.py \
  --toolchain ../outputs/lianziyu_android_20261017/toolchain \
  --apk ../outputs/lianziyu_android_20261017/炼字狱-v0.1.0-android.apk
```

`android_export_presets.cfg.in` 是可复用、不含密码的导出配置；构建脚本写出本地忽略的 `export_presets.cfg`。签名密钥和密码在工程外构建目录的 `signing/` 中，权限为600；保留这两个文件，后续版本沿用同一密钥才能覆盖安装更新。不要将其上传到GitHub或发给试玩者。

普通、安卓自适应和主题单色图标均已配置；制作记录见 `assets/branding/制作记录.md`。打包排除了文档、测试、截图、原型和制作脚本，不需要额外联网权限。

## 验证范围

校验脚本检查实际 APK 的应用名、版本、包名、ARM64 ELF库、启动器入口、自适应图标、单色图标、无权限申请、ZIP CRC、APK签名与16KB对齐，生成 SHA256。并提取同一份导出资源用于宿主机资源加载冒烟测试。

原生安卓安装与帧率尚未在真机验证。宿主机的 Mobile 渲染器和手机尺寸回归用于验证资源及布局，不能替代安卓真机测试。旧版 aapt 对新版模板中的 Vulkan 特性字符串会报解析错误，应用信息使用 aapt2 读取；模板中一个未引用的 themed_icon 资源表项会触发缺文件提示，当前实际图标路径 icon.xml 及其三层引用已验证存在。

参考：[Godot Android 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)。
