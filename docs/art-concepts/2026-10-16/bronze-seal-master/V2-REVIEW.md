# 铜印第二轮 · 未通过

用户指出第一轮仍有明显 AI 生成感。第一轮的旧铜狮参考在构型上产生较强延续，去纹理、放大形体没有解决画法和设计问题。

本轮使用内置 ImageGen，目标为 Godot 原生隐藏敌人后的空场景，唯一画法参考为原始墨灵。撤掉旧铜印素材，尝试“伏兽印钮与方印本体成为同一生物”。

结果 `bronze-seal-master-v2-rejected.png` 未通过评审：

- 借用了墨灵长角的明显造型元素，画法参考与造型参考仍未分开。
- 兽身与方印连接生硬，不能算完整、可信的角色设计。
- 长角伸入意图区域，生成工具还改坏了攻击数值和结束回合文字。
- 局部材质虽更平静，但不能据此宣称整体达到墨灵质量。

不作为游戏运行素材或动画基准。第一轮也不再视为待确认定稿。两轮原图都保留作失败记录，没有覆盖正式敌人图。

后续需要固定明确的形体底稿：剪影、比例、关节/印体连接和主要墨线先成立，再进行受控上色；少量磨损最后处理。仅凭参考图和文字提示重复整图生成，当前不能保证稳定复现墨灵画法。

工具：内置 ImageGen。原生成文件：`exec-78d72d81-cbd9-45e2-8f57-a2cdc579a633.png`。本文件夹保留原样图片，没有做后期图像处理。原生空场景输入见 `empty-stage-runtime.png`。

## 完整提示词

```text
Use case: precise-object-edit, original game creature design. Image 1 is a REAL game screenshot with its enemy illustration intentionally hidden. Paint ONE new enemy into ONLY that empty lower-right area (below the attack intent). Preserve every UI panel, letter, number, tile and background elsewhere exactly. Image 2, the original ink guardian, is the sole ARTIST / MARK-MAKING reference. No previous copper lion image is supplied: do NOT invent a generic decorative Chinese bronze lion.
The character 铜印 is a living archaic SQUARE BRONZE SEAL whose crouching beast-shaped handle has awakened. Design the beast and seal as one coherent weight-bearing body, not an animal wearing a stamp badge. A large severe beast head grows from the upper front of a deep, massive square seal body; two compact forelimbs brace at the front corners. Strong slightly forward-leaning three-quarter posture toward the left; deliberately asymmetrical silhouette with one blunt broken horn and one longer horn. Long squared muzzle, restrained thin dark eyes, a heavy brow and one chipped lower fang give a watchful ancient personality. The muzzle and brow are the clear focal point. No mane made of spirals; no repeated curls, armor bands, tail ornament, crest, back ring, hanging chest plaque or calligraphy. The low square seal body has broad uninterrupted dark teal faces and one clear edge defining its weight; a single restrained cinnabar stain lies at the bottom printing surface. The head uses flat muted ochre bronze, not realistic metallic gradients. Body and creature should feel like a strange coherent ritual being, not a museum sculpture or toy. Use a close monumental framing with large head and shoulders like the original guardian, lower base partly occluded by the existing stage. Fit within x approximately 1280..1800, y 315..670 of the 1980x792 reference, never touching the HP or intent box.
Most critical: paint with the SAME economical hand-drawn decisions as image 2. Fine uneven ink contours, broken or omitted internal lines in shadow, large matte color masses, small structural pen accents concentrated near the face. Dark planes should remain quietly dark without texture decoration. Warm flat ochre face against near-black jade recesses, one or two deliberate shape shadows, a tiny cinnabar accent at the base. No circular beveled bands, pillowy rounded forms or uniformly thick clean outline. No gold rim around everything. No all-over wear, random cracks, gritty speckles, gradients, shiny bronze render, vector mascot, cute stylization, symmetrical stock lion face, or faceted low-poly shading. Match the original guardian's drawing maturity rather than its accessories. This is a focused character DESIGN REPLACEMENT, not cleanup of an existing lion. One full battle-scene art master, wide 2.5:1 composition, no comparison board, no notes, no extra objects or text.
```

