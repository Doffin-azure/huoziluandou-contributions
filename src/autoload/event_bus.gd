extends Node
## 全局事件总线。UI 之间尽量通过信号通信，避免互相硬引用。

signal gold_changed(value: int)
signal deck_changed
signal hp_changed(hp: int, max_hp: int)
signal run_started
signal run_ended(victory: bool)

signal battle_started
signal battle_ended(victory: bool)
signal word_played(word: WordData, glyph_string: String)
signal character_played(ch: CharacterData)
signal invalid_word_attempt(glyphs: Array)
signal turn_ended(turn: int)
signal log_message(text: String)
