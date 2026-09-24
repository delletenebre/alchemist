class_name QueueTile
extends Control
signal inspect_requested(order: int)
@onready var card: IngredientCard = $Card
var slot := 0

func _ready() -> void:
	card.set_interactive(false)

func configure(texture: Texture2D, order: int, data: Dictionary, tint: Color, width: float) -> void:
	slot = order - 1
	card.configure(data.short, data.effect, texture, data.smoke, data.heat, tint, data.icon, false, data.damage, data.damage_bonus)
	# Initial heat and smoke have already been applied when entering the cauldron.
	card.heat_badge.hide()
	card.smoke_badge.hide()
	card.scale = Vector2.ONE * (width / 240.0)
	size = Vector2(width, 352.0 * width / 240.0)
	visible = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != -1:
		inspect_requested.emit(slot)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		inspect_requested.emit(slot)
		accept_event()
