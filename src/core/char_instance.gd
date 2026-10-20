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
var refined: bool = false              ## 精炼：本场重新入盘时恢复两次额外使用；复制不继承
## 临时牌：打出即消耗，不进抽字袋/弃字堆，战后消失
var temporary: bool = false
## 分生成的复制仅供组词；单独打出只弃掉，不触发单字效果。
var word_only: bool = false
## 融合（化合）：本格除主字形外附带的其他字形，作为一个不可拆的单位在牌堆中移动
var fusion: Array[String] = []
## 镀金（精金）：永久；每次有效单字或组词打出时 +1 金币；按实体计一次
var gilded: bool = false
## 精铸（固定）：本场原格保留，每回合可使用一次；不可移动/换字
var pinned: bool = false
var pinned_exhausted: bool = false
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
	c.word_only = word_only
	c.fusion = fusion.duplicate()
	c.gilded = gilded
	c.pinned = pinned
	c.statuses = statuses.duplicate(true)
	c.upgrade_level = upgrade_level
	return c


## 实体的实际单字效果与修饰说明；只读取参数，不创建实体或执行效果。
func describe() -> String:
	if data == null: return ""
	var lines: Array[String] = [BattleText.character(data)]
	if gilded: lines.append("镀金：" + str(EffectGlossary.entry("term:gilded").text))
	if refined: lines.append("精炼：" + str(EffectGlossary.entry("term:refined").text))
	if pinned: lines.append("固定：" + str(EffectGlossary.entry("term:pinned").text))
	if temporary: lines.append("临时字：用后消失，不进入字袋或弃字堆。")
	if word_only: lines.append("仅供组词：单打只弃字，不发动单字效果。")
	if temporary_uses > 0: lines.append("额外使用：剩余%d次，用后仍留在盘面。" % temporary_uses)
	if upgrade_level > 0: lines.append("已强化%d次；上方单字效果已计入强化后的数值。" % upgrade_level)
	if not fusion.is_empty(): lines.append("融合：" + "、".join(glyph_list()) + "，共同移动和使用。")
	for pid in pollutions:
		var pollution := Database.get_pollution(pid)
		if pollution != null: lines.append(pollution.name + "污染：" + pollution.description)
	for modifier in modifiers: lines.append("修饰：" + modifier)
	return "\n".join(lines)


func display_data() -> CharacterData:
	if data == null: return null
	var display: CharacterData = data.duplicate()
	display.glyph = "·".join(glyph_list())
	display.description = describe()
	return display
