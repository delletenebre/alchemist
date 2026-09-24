extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(1))
	var game = load('res://scenes/main.tscn').instantiate()
	game.demo_opponents = false
	game.random_seed = 42
	root.add_child(game)
	await create_timer(1.8).timeout
	game.animating = true
	var heat: AlchemyMeter = game.heat_meter
	var smoke: AlchemyMeter = game.smoke_meter
	var launches: Array[int] = [0,0]
	heat.blast_released.connect(func(_overheat: bool) -> void: launches[0] += 1)
	smoke.blast_released.connect(func(_overheat: bool) -> void: launches[1] += 1)
	assert(smoke.expression == &"sad")
	# A cooling card at zero must react to its negative intent, despite clamping.
	game._resolve_reaction(AlchemyRules.resolve(0,0,game.cards[4]),4,game.active_player)
	await create_timer(.1).timeout
	assert(heat.previous_value == 0 and heat.expression == &"angry" and heat.fist.visible)
	var remaining := heat.offended_time
	heat.configure('ЖАР',0)
	assert(heat.offended_time == remaining, 'UI refresh must not restart gestures')
	await create_timer(2.0).timeout
	assert(heat.previous_value == 1 and not heat.fist.visible)
	game.heat = 5
	game.smoke = 2
	game._show_brew_values(5,2)
	await create_timer(.05).timeout
	assert(heat.expression == &"furious" and heat.fist.visible)
	assert(smoke.expression == &"happy")
	smoke.ingredient_delta(-1,game.self_panel.card_origin())
	await create_timer(.05).timeout
	assert(smoke.expression == &"sad")
	await create_timer(1.9).timeout
	assert(smoke.expression == &"happy")
	# Real overheat and burst paths must drive both rigs exactly once.
	var before: Array[int] = game.hp.duplicate()
	await game._resolve_reaction(AlchemyRules.resolve(5,2,game.cards[2]),2,game.active_player)
	assert(game.hp[game.active_player] == before[game.active_player] - 3)
	assert(launches == [1,1])
	assert(heat.previous_value == 0 and heat.offended_time == 0 and smoke.expression == &"sad")
	game.heat = 3
	game.smoke = 2
	game._show_brew_values(3,2)
	var target: int = game._target_index()
	var target_hp: int = game.hp[target]
	await game._resolve_reaction(AlchemyRules.resolve(3,2,game.cards[2]),2,game.active_player)
	assert(game.hp[target] == target_hp - 4)
	assert(launches == [2,2])
	assert(heat.blast_state == &"" and smoke.blast_state == &"" and heat.offended_time == 0)
	print('SPIRITS PASS: cooling zero, no repeat on refresh, smoke recovery, heat five, both blast paths and reset')
	quit()
