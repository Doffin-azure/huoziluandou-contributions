# Suno BGM 生成提示词

这些提示词对应 `assets/audio/bgm/` 的文件名。建议在 Suno 选择 **Instrumental**，关闭人声和歌词；每首先生成 2-4 个版本，只保留循环点自然、没有明显爆音和人声残留的一版。

## 统一风格约束

可附加到每一首提示词末尾：

```text
instrumental video game soundtrack, no vocals, no spoken words, no lyrics, no choir, no pop song structure, Chinese fantasy ink-and-bronze roguelike, organic acoustic instruments, clear loop ending, controlled dynamics, leave space for gameplay sound effects, polished game-ready mix
```

## `title_menu.ogg` 主菜单

```text
Instrumental title-screen theme for a Chinese character-combination roguelike game. Quiet scholarly courtyard at dusk, warm guqin plucks, xiao flute, soft yangqin, distant temple bell, delicate paper and wood percussion, restrained bronze chimes. Elegant, curious, slightly mysterious, welcoming rather than sad. 78 BPM, D minor with a hopeful suspended ending, sparse opening, memorable 8-bar motif, 90 seconds, seamless loop, no dramatic climax. instrumental video game soundtrack, no vocals, no spoken words, no lyrics, no choir.
```

## `exploration.ogg` 地图、事件与教程

```text
Instrumental exploration music for a hand-painted Chinese ink fantasy journey. Flowing guqin ostinato, bamboo flute phrases, muted pipa, light frame drum and wooden clacks, airy room ambience, subtle paper-and-brush texture. The feeling is thoughtful travel, discovery, and choosing a path; gentle forward motion without demanding attention. 96 BPM, pentatonic color with minor inflections, medium-low intensity, 2-minute seamless loop, no large ending, no vocals, no lyrics, no choir.
```

## `combat.ogg` 普通战斗

```text
Instrumental combat loop for a tactical Chinese ink-and-bronze word battle. Tense low guzheng and cello pulse, plucked pipa accents, dry wooden strikes, restrained taiko, metallic bronze percussion, short rising motifs that suggest arranging characters into a word. Energetic and precise, dangerous but readable, with clear rhythmic space for hit and block sound effects. 118 BPM, D minor, 16-bar structure that can loop seamlessly, 2 minutes, no vocals, no lyrics, no choir, no cinematic trailer risers.
```

## `boss.ogg` 精英或首领战

```text
Instrumental boss battle music for a Chinese mythic ink roguelike. Heavy low drums, dark cello ostinato, aggressive pipa tremolo, breathy xiao, bronze gongs and distorted guqin harmonics. Ancient guardian pressure, intelligent menace, controlled power rather than chaos. Build tension in layers, leave rhythmic gaps for gameplay feedback, 132 BPM, minor pentatonic with chromatic threat notes, seamless 2-minute loop, no vocals, no lyrics, no choir.
```

## `victory.ogg` 胜利与奖励过渡

```text
Instrumental short victory and reward theme for a Chinese ink fantasy word game. Bright guqin and yangqin, warm bamboo flute, small bronze bells, soft hand percussion, a graceful rising five-note motif. Satisfying and dignified, a sense of ink settling onto paper and a path opening ahead. 100 BPM, major pentatonic with one gentle minor turn, 25-35 seconds, clean ending that can also loop twice, no vocals, no lyrics, no choir.
```

## `defeat.ogg` 失败过渡

```text
Instrumental short defeat theme for a Chinese ink-and-bronze roguelike. Sparse low guqin harmonics, bowed cello, one distant temple bell, soft paper-brush percussion, unresolved but calm. Reflective and respectful, never melodramatic, leaving room for the retry or return-to-title UI. 62 BPM, minor pentatonic, 20-30 seconds, clean final tail, no vocals, no lyrics, no choir.
```

## 导出与验收

1. 导出为 OGG Vorbis，44.1 kHz，立体声；把文件名改成上面的固定名称。
2. 复制到 `assets/audio/bgm/`。游戏启动后会按路由自动加载，不访问 Suno，也不需要联网。
3. 在设置中调节“音乐音量”；音乐默认音量低于音效，切换场景使用约 0.8 秒交叉淡化。
4. 用耳机检查循环首尾、低频是否盖住选字／受击音效，以及手机扬声器下是否出现刺耳高频。
