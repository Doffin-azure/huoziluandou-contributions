extends RefCounted
class_name RecentLog
## Small, platform-independent history budget; oldest entries leave first.
const MAX_ENTRIES := 32
const MAX_LINE_CHARS := 160
const MAX_TOTAL_CHARS := 4096


static func line(text: String) -> String:
	var result := text.replace("\r", " ").replace("\n", " ").strip_edges()
	if result.length() > MAX_LINE_CHARS:
		result = result.left(MAX_LINE_CHARS - 1) + "…"
	return result


static func bounded(entries: Array, newest_first := false) -> Array[String]:
	var result: Array[String] = []
	var total := 0
	for i in mini(entries.size(), MAX_ENTRIES):
		var index := i if newest_first else entries.size() - 1 - i
		var text := line(str(entries[index]))
		if text.is_empty(): continue
		if total + text.length() > MAX_TOTAL_CHARS: break
		total += text.length()
		result.append(text)
	if not newest_first: result.reverse()
	return result


static func append(entries: Array, text: String, newest_first := false) -> void:
	var clean := line(text)
	if clean.is_empty(): return
	if newest_first: entries.push_front(clean)
	else: entries.append(clean)
	while entries.size() > MAX_ENTRIES:
		if newest_first: entries.pop_back()
		else: entries.pop_front()
	var total := 0
	for entry in entries: total += entry.length()
	while total > MAX_TOTAL_CHARS:
		var removed: String = entries.pop_back() if newest_first else entries.pop_front()
		total -= removed.length()


static func display_text(entries: Array) -> String:
	# Consecutive identical messages need only one line on the small screen.
	var rows: PackedStringArray = []
	var previous := ""
	var count := 0
	for text in entries:
		if text == previous:
			count += 1
			rows[rows.size() - 1] = "%s ×%d" % [text, count]
		else:
			previous = text
			count = 1
			rows.append(text)
	return "\n".join(rows)
