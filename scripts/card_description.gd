@tool
class_name CardDescription
extends Control

@export_multiline var text := "−2 жара. Не кипятись.":
	set(value):
		text = value
		if is_node_ready():
			_reflow()

@onready var upper: Label = $Body

func _ready() -> void:
	_reflow()

func _reflow() -> void:
	var words: PackedStringArray = text.split(" ", false)
	var lines: Array[String] = []
	while not words.is_empty():
		lines.append(_take_line(words, upper.size.x, upper))
	upper.text = "\n".join(lines)

func _take_line(words: PackedStringArray, width: float, label: Label) -> String:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var line := ""
	while not words.is_empty():
		var candidate := words[0] if line.is_empty() else line + " " + words[0]
		if not line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			break
		line = candidate
		words.remove_at(0)
	return line
