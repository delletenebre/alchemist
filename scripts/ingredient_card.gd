class_name IngredientCard
extends Control

signal pointer_pressed(card: IngredientCard, pointer_global: Vector2, pointer_id: int)

@onready var art: TextureRect = $Art
@onready var title: Label = $Title
@onready var effect_label: CardDescription = $Effect
@onready var frame: TextureRect = $Frame
@onready var shadow: Panel = $Shadow
@onready var smoke_badge: TextureRect = $SmokeBadge
@onready var heat_badge: TextureRect = $HeatBadge
@onready var smoke_value: Label = $SmokeBadge/Value
@onready var heat_value: Label = $HeatBadge/Value
@onready var damage_badge: TextureRect = $DamageBadge
@onready var damage_value: Label = $DamageBadge/Value

var interactive := true
var card_name := ""
var dragging := false

func _ready() -> void:
	frame.material = frame.material.duplicate()

func configure(new_name: String, effect: String, texture: Texture2D, smoke: int, heat: int, accent: Color, _icon: String, _selected: bool, damage: int = 0, bonus_damage: bool = false) -> void:
	card_name = new_name
	title.text = new_name
	title.offset_left = 68.0 if smoke != 0 or damage != 0 else 38.0
	var title_font := title.get_theme_font("font")
	for font_size in [19, 18, 17]:
		title.add_theme_font_size_override("font_size", font_size)
		var measured := title_font.get_multiline_string_size(new_name, HORIZONTAL_ALIGNMENT_CENTER, title.size.x, font_size)
		if measured.y <= title_font.get_height(font_size) * 2.1:
			break
	title.offset_bottom = 79.0
	effect_label.text = effect
	art.texture = texture
	smoke_value.text = str(smoke).replace("-", "−")
	heat_value.text = str(heat).replace("-", "−")
	smoke_badge.visible = smoke != 0
	heat_badge.visible = heat != 0
	damage_badge.visible = damage != 0
	damage_value.text = ("+" if bonus_damage else "") + str(damage)
	(frame.material as ShaderMaterial).set_shader_parameter("family_tint", accent)

func set_interactive(enabled: bool) -> void:
	interactive = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func set_lifted(lifted: bool) -> void:
	shadow.modulate.a = 0.72 if lifted else 0.38

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != -1:
		pointer_pressed.emit(self, get_global_transform_with_canvas() * event.position, -1)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		pointer_pressed.emit(self, get_global_transform_with_canvas() * event.position, event.index)
		accept_event()
