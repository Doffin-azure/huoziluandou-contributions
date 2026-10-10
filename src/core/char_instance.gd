extends RefCounted
class_name CharInstance
## 盘面/字袋/弃字堆里的一枚“实体字”运行时实例。
## 按 V0.2：id 唯一，owner/pollutions/modifiers/temporary_uses/location 独立于字形。

enum Owner { PLAYER, ENEMY, SELF_GENERATED }

static var _next_uid: int = 1

var uid: int = 0
var data: CharacterData
var owner: int = Owner.PLAYER
var pollutions: Array[String] = []      ## PollutionData.id 列表
var modifiers: Array[String] = []
var temporary_uses: int = 0             ## 非实体复制层：原格上还能多用几次
## 临时牌：打出即消耗，不进抽字袋/弃字堆，战后消失
var temporary: bool = false
## 融合（化合）：本格除主字形外附带的其他字形，作为一个不可拆的单位在牌堆中移动
var fusion: Array[String] = []
## 镀金（精金）：永久；参与有效多字词时 +1 金币
var gilded: bool = false
var statuses: Dictionary = {}
var upgrade_level: int = 0


func _init(p_data: CharacterData = null) -> void:
	uid = _next_uid
	_next_uid += 1
	data = p_data


func glyph() -> String:
	if data == null:
		return "？"
	return data.glyph


## 该实体在盘面/词中贡献的字形序列（融合牌为多个）
func glyph_list() -> Array:
	var out: Array = [glyph()]
	for g in fusion:
		out.append(g)
	return out


func is_fused() -> bool:
	return not fusion.is_empty()


func id() -> String:
	if data == null:
		return ""
	return data.id


func is_player_owned() -> bool:
	return owner == Owner.PLAYER


func is_enemy_owned() -> bool:
	return owner == Owner.ENEMY


func has_pollution(pid: String) -> bool:
	return pollutions.has(pid)


func add_pollution(pid: String) -> void:
	if not pid.is_empty() and not pollutions.has(pid):
		pollutions.append(pid)


func remove_pollution(pid: String) -> void:
	pollutions.erase(pid)


func clear_pollutions() -> void:
	pollutions.clear()


func clone() -> CharInstance:
	var c := CharInstance.new(data)
	c.owner = owner
	c.pollutions = pollutions.duplicate()
	c.modifiers = modifiers.duplicate()
	c.temporary_uses = temporary_uses
	c.temporary = temporary
	c.fusion = fusion.duplicate()
	c.gilded = gilded
	c.statuses = statuses.duplicate(true)
	c.upgrade_level = upgrade_level
	return c
