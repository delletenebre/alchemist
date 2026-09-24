extends Node2D

func fly(origin: Vector2, destination: Vector2) -> void:
	position = origin
	scale = Vector2.ONE * 0.35
	modulate.a = 1.0
	rotation = -0.12
	visible = true
	var lift := create_tween().set_parallel(true)
	lift.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(self, "position", origin + Vector2(0, -18), 0.18)
	await lift.finished
	$Trail.emitting = true
	var start := position
	var control := (start + destination) * 0.5 + Vector2(0, -60)
	var flight := create_tween()
	flight.tween_method(func(t: float) -> void:
		position = start.lerp(control, t).lerp(control.lerp(destination, t), t)
		rotation = sin(t * PI) * -0.20
		scale = Vector2.ONE * lerpf(1.0, 0.72, t)
	, 0.0, 1.0, 0.64).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await flight.finished
	$Trail.emitting = false
	visible = false
