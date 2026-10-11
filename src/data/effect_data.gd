@tool
extends Resource
class_name EffectData
## 一条可复用的效果数据。
## 两种驱动方式：
##   1) handler 非空 -> 由 EffectHandlers 按名字分发（V0.2 推荐，适合有特殊规则的词）
##   2) handler 为空 -> 走 kind 的通用分支（简单数值效果）
## 词/字的特效表现与数值都在这里，改卡只需改资源。

enum Kind {
	DAMAGE,
	DAMAGE_ALL,
	BLOCK,          ## 临时格挡
	HEAL,
	DRAW_CHARS,
	GAIN_GOLD,
	APPLY_STATUS,
	ADD_CHAR_TO_BAG,
	GRAVITY,
	SWAP_TILES,
	DISCARD_TILE,
	SCRY,
	# --- V0.2 新增 ---
	PERSISTENT_BLOCK,   ## 持久盾（跨回合）
	ENERGY,             ## 储能
	HEAT,               ## 热度
	TEMP_FUNDS,         ## 临时资金
	EQUITY,             ## 股权
	REMOVE_BLOCK,       ## 移除敌方护盾
	CLEANSE,            ## 净化污染
	REVEAL_PLACE,       ## 揭示并指定落点
	CAPTURE_GLYPH,      ## 收编敌方字
	RECOVER_CONSUMED,   ## 回收本回合消耗字
	ROTATE_2X2,         ## 旋转 2×2
	DESTROY_2X2,        ## 摧毁 2×2
	REPLAY_ATTACK,      ## 重演上一攻击
	SHIELD_SMASH,       ## 消耗持久盾输出
	COUNTER,            ## 延迟反击
	PERMANENT,          ## 跨战永久能力
	ABILITY,            ## 本战持续能力
	SPECIAL,
}

## 需要玩家指定目标时才弹选择器
enum Target {
	NONE,
	ENEMY,
	ALL_ENEMIES,
	SELF,
	BOARD,
	BOARD_TILE,      ## 指定盘面一格
	BOARD_2X2,       ## 指定 2×2 左上角
	EMPTY_TILE,      ## 指定空格
	DISCARD_GLYPH,   ## 指定弃字堆中的实体字
	ENEMY_GLYPH,     ## 指定盘面敌方字
	RANDOM_TILE,
	BOARD_ROW,       ## 指定一整行（循环位移用）
	BOARD_3X3,       ## 指定 3×3 左上角（旋转用）
}

@export var kind: Kind = Kind.DAMAGE
## 非空时由 EffectHandlers 分发（见 src/core/effect_handlers.gd）
@export var handler: String = ""
@export var amount: int = 0
@export var amount_per_extra_glyph: int = 0
@export var hits: int = 1
@export var target: Target = Target.ENEMY
@export var status_id: String = ""
@export var character_id: String = ""
## immediate / delayed / next_word / persistent
@export var timing: String = "immediate"
## true = 在消耗路径之前结算（如爆破：先摧毁 2×2 再消耗，自己的字也计入摧毁）
@export var pre_consume: bool = false
@export var args: Dictionary = {}
@export_multiline var note: String = ""


func describe() -> String:
	if not note.is_empty():
		return note
	match kind:
		Kind.DAMAGE:
			return "造成 %d 点伤害" % amount
		Kind.DAMAGE_ALL:
			return "对所有敌人造成 %d 点伤害" % amount
		Kind.BLOCK:
			return "获得 %d 点临时格挡" % amount
		Kind.PERSISTENT_BLOCK:
			return "获得 %d 点持久盾" % amount
		Kind.HEAL:
			return "回复 %d 点生命" % amount
		Kind.DRAW_CHARS:
			return "随机补 %d 个字" % amount
		Kind.GAIN_GOLD:
			return "获得 %d 金币" % amount
		Kind.ENERGY:
			return "获得 %d 储能" % amount
		Kind.HEAT:
			return "热度 %+d" % amount
		Kind.TEMP_FUNDS:
			return "获得 %d 临时资金" % amount
		Kind.EQUITY:
			return "获得 %d 股权" % amount
		Kind.GRAVITY:
			return "全盘向下重力"
		Kind.REMOVE_BLOCK:
			return "移除敌方全部护盾"
		Kind.CLEANSE:
			return "净化污染"
		Kind.APPLY_STATUS:
			return "附加状态【%s】" % status_id
		Kind.ADD_CHAR_TO_BAG:
			return "把【%s】加入字袋" % character_id
		_:
			return "特殊效果"
