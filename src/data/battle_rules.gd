@tool
extends Resource
class_name BattleRules
## 战斗规则参数。数值都可以在 Inspector 调整，方便平衡。

@export_group("盘面")
@export var board_size: int = 4
@export var opening_draw: int = 10      ## 开局落盘字数
@export var turn_draw: int = 3          ## 每回合补字数
@export_group("玩家")
@export var player_max_hp: int = 60
@export var starting_gold: int = 6
@export var plays_per_turn: int = 1     ## 每回合可出词/弃字次数（0 = 无限）
@export_group("节奏")
@export var hand_size_hint: int = 6     ## 仅用于 UI 提示（GDD 中的 6 个空格）
@export_group("V0.2 新规则")
@export var heat_capacity: int = 10       ## 初始热容
@export var allow_zero_effect_words: bool = true  ## P0 待决：合法零效词是否允许出掉
@export var gold_cap_per_battle: int = 0          ## 战内金币收入上限；0 = 不限制（原型阶段开放）


static func default_rules() -> BattleRules:
	return BattleRules.new()
