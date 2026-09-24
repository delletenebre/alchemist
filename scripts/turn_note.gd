extends Node2D

signal opened
signal landed
var running := false
@onready var paper: Node2D = $Paper
@onready var edge: Line2D = $Paper/Edge
@onready var sheet: Polygon2D = $Paper/Sheet
var flat_points := PackedVector2Array()
var flat_colors := PackedColorArray()

func _ready() -> void:
	flat_points = sheet.polygon
	flat_colors = sheet.vertex_colors

func _crumple(amount: float) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(flat_points.size()):
		var point := flat_points[i]
		var folded := point * Vector2(0.14, 0.40) + Vector2(sin(i * 1.7) * 5, cos(i * 2.3) * 6)
		points.append(point.lerp(folded, amount))
		var shade := lerpf(1.0, 0.72 + sin(i * 1.3) * 0.13, amount)
		colors.append(flat_colors[i] * Color(shade, shade, shade, 1))
	var contour := PackedVector2Array()
	for index in [0,1,2,3,4,5,6,7,8,9,10,21,32,43,54,53,52,51,50,49,48,47,46,45,44,33,22,11]:
		contour.append(points[index])
	edge.points = contour
	sheet.polygon = points
	sheet.vertex_colors = colors
@onready var title: Label = $Paper/Title
@onready var ball: Sprite2D = $Ball

func announce(caption: String, origin: Vector2, resting: Vector2, fire_position: Callable) -> void:
	if running: return
	running = true
	visible = true
	title.text = caption
	title.modulate.a = 0.0
	paper.visible = false
	ball.visible = true
	ball.modulate = Color.WHITE
	ball.scale = Vector2.ONE
	position = origin
	scale = Vector2.ONE * 0.35
	rotation = -0.3
	var arrival := create_tween().set_parallel(true)
	arrival.tween_property(self, "position", resting, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	arrival.tween_property(self, "scale", Vector2.ONE, 0.32)
	arrival.tween_property(self, "rotation", 0.12, 0.32)
	await arrival.finished
	# The entire sheet shares one texture: folds deform it without panel seams.
	paper.visible = true
	paper.scale = Vector2.ONE
	_crumple(1.0)
	var unfold := create_tween().set_parallel(true)
	unfold.tween_property(ball, "scale", Vector2(0.68, 0.52), 0.15)
	unfold.tween_property(ball, "modulate:a", 0.0, 0.12).set_delay(0.05)
	unfold.tween_method(_crumple, 1.0, 0.0, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	unfold.tween_property(self, "rotation", -0.025, 0.48)
	unfold.tween_property(title, "modulate:a", 1.0, 0.14).set_delay(0.37)
	await unfold.finished
	ball.visible = false
	opened.emit()
	await get_tree().create_timer(2.0).timeout
	var fold := create_tween().set_parallel(true)
	fold.tween_property(title, "modulate:a", 0.0, 0.10)
	fold.tween_method(_crumple, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fold.tween_property(self, "rotation", 0.16, 0.40)
	await fold.finished
	paper.visible = false
	ball.visible = true
	ball.modulate = Color.WHITE
	ball.scale = Vector2(0.68, 0.52)
	var crumple := create_tween()
	crumple.tween_property(ball, "scale", Vector2(0.56, 0.72), 0.08)
	crumple.tween_property(ball, "scale", Vector2.ONE * 0.62, 0.10)
	await crumple.finished
	var start := position
	var flight := create_tween()
	flight.tween_method(func(t: float) -> void:
		# Resolve the destination each frame so resizing cannot detach the landing.
		var end: Vector2 = fire_position.call()
		var bend := start.lerp(end, 0.45) + Vector2(65, -40)
		position = start.lerp(bend, t).lerp(bend.lerp(end, t), t)
		rotation = 0.16 + t * TAU * 1.2
		scale = Vector2.ONE * lerpf(1.0, 0.18, t * t)
	, 0.0, 1.0, 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await flight.finished
	ball.visible = false
	scale = Vector2.ONE
	rotation = 0.0
	$Ash.restart()
	$Ash.emitting = true
	landed.emit()
	await get_tree().create_timer(0.45).timeout
	visible = false
	running = false
