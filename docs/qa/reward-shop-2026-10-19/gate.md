# 奖励与商店接入范围

授权：用户明确要求一轮选字、跳过16金币、精英掉落、首领回血与遗物三选一、远端商店、半透明牌堆窗口。
A0 receipt: code-quality-workflow / ST-A0 / snapshot 2026-08-16。
决策：Local Fix；按奖励、商店、牌堆三个阶段接入已批准功能，不重构其他模块。
生产范围：reward_screen、shop_screen、expedition、expedition_map_screen、object_hud、object_stage、battle_pile_overlay、relic_reward_flow。
边界：不合并音乐、甲流、事件遗物、其他经济或怪物更新；保留本地样式、动画、存档；不调试手机、不更新APK。
本次功能预算：8个生产文件，新增/修改约450行；测试与QA单独记录。超过时重新核对授权范围。
存档契约：候选与刷新结果持久化；首领回血仅执行一次；遗物绑定未完成不保存中间状态。
基线：已有牌堆测试在headless下点击失败并访问空overlay，发生在编辑之前。后续等待入场解锁并用桌面渲染器验证投射点击。
验证：规则/刷新测试、真实存档恢复、既有存档/物件界面/牌堆测试、横屏截图。
回滚：只恢复本次备份文件，新增文件按scope列表处理，不重置其他工作区修改。
备份：C:\Users\Lenovo\AppData\Local\Temp\huozi-reward-integration-ioxymgi6

截图补充门禁：640×360首领第三选项被裁切；只为遗物选择启用compact留白与说明换行，新增choice_overlay一个生产文件。修订预算9个生产文件、450行；其他选择弹窗保持原布局。
