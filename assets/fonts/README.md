# 随游戏发布的字体

| 字体 | 用途 | 许可 |
|---|---|---|
| Noto Serif SC / 思源宋体 | 正文、默认字盘，以及标准 / 细体 / 粗体三个字重 | NotoSerifSC-OFL.txt |
| LXGW WenKai / 霞鹜文楷 v1.530 | 楷体字盘，笔画舒展，保持识字清晰度 | LXGWWenKai-OFL.txt |
| Long Cang / 龙藏体 | 草书字盘，笔势更自由；默认不用于正文 | LongCang-OFL.txt |

三款字体均按 SIL Open Font License 1.1 随游戏分发，不单独售卖字体。新增字体未经裁剪或改名，下载来源、文件大小和 SHA-256 见 sources.json。导出时须包含全部 *-OFL.txt；Android 一键测试脚本已配置。

游戏只接受 BoardTypography.STYLES 中的字体 ID，字体文件路径由代码固定。设置页不提供文件上传、系统字体选择或外部字体加载；旧配置中的路径会清除。全部字体禁止系统字体回退；书法字体缺字时显式回退到包内思源宋体。
