# 远端同步与遗物图标保留 · 2026-10-19

已将 `origin/main` 的 `7e82dec`（PR #15，第二批遗物）合入当前 `refactor/frontend-legacy-cleanup` 分支；合并提交为 `c44ab7a`。最新远端是当前 HEAD 的祖先，Git 未解决冲突数为 0。后续接口适配和原有本地编辑保留在工作区，未推送远端。

## 保留的美术

原有 15 张去底盘的 1024×1024 遗物 PNG 全部保留。逐文件 SHA-256 与同步前完全相同，记录见 `preserved-icons.json`。3D 模型、材质、奖励、购买确认和详情接入保留，并适配新版横向路线的商店、宝藏收据和遗物详情。

远端共有 38 件遗物，其名称、效果、第二批拾取选择与事件专属池采用新版规则。新增加的 23 件尚无专属图片，使用名称标识，未套用不相符的旧图标。

五卡货架、三件未持有遗物随机库存、按稀有度定价、3D 刷新控件和 5/10/15… 刷新费用已接到新版路线控制器。刷新进度和新遗物的复活次数可随路线存档恢复；经典模式仍保留原有存档。新版路线使用远端自己的存档，避免两个存档器同时记录同一局。

## 验证

Godot 4.7.2，相关检查 **458 项通过，0 项失败**。未运行整个项目测试套件。

| 场景 | 通过 | 记录 |
| --- | ---: | --- |
| relic_batch2_test | 60 | relic-batch2.log |
| relic_art_test | 85 | relic-art.log |
| room_reward_test | 22 | room-reward.log |
| node_route_test | 186 | node-route.log |
| node_route_runtime | 21 | node-runtime.log |
| remote_sync_test | 24 | integration.log |
| classic_relic_test | 60 | classic-relic.log |

另已完成编辑器导入和主场景原生渲染启动检查，无脚本错误。`remote_sync_test` 验证十个主要界面可编译，以及新版路线的实体货架、指定遗物购买、两次刷新、存档恢复和复活次数恢复。横向路线实机测试覆盖地图缓存、战斗、奖励、事件、商店、休息和宝藏拾取；宝藏测试已支持第二批遗物可能要求的多次选字与许愿。

## 同步前备份

- 完整本地文件与删除清单：`E:/gamejam10/.sync-backups/20261019-224253/local-changes.zip`、同目录 `manifest.json`。
- Git 快照：`refs/codex-backups/pre-sync-20261019-224253`，也保留为本次创建的 stash。
- `merge-repair.json` 记录了合并文本处理脚本出错后的重建；最终文件已从原始 Git 快照重建并通过上述检查。
