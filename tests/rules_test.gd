extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.demo_opponents = false
	game.random_seed = 42
	root.add_child(game)
	assert(game.cards.size() == 8)
	var checks := [
		[4, 2, 2, "burst", 5, 0, 0, 0],
		[4, 2, 0, "overheat", 0, 3, 0, 0],
		[4, 2, 4, "prepare", 0, 0, 3, 2],
		[5, 2, 2, "overheat", 0, 3, 0, 0],
		[0, 0, 4, "prepare", 0, 0, 1, 0],
		[2, 2, 3, "burst", 3, 0, 0, 0],
		[4, 2, 7, "burst", 3, 0, 0, 0],
		[4, 2, 5, "prepare", 0, 0, 4, 1],
	]
	for row in checks:
		var r := AlchemyRules.resolve(row[0], row[1], game.cards[row[2]])
		assert([r.event, r.damage, r.self_damage, r.heat, r.smoke] == row.slice(3))
	for h in range(6):
		for s in range(3):
			for card in game.cards:
				var r := AlchemyRules.resolve(h, s, card)
				assert(r.hot_heat == r.card_heat + 1)
				assert(r.heat >= 0 and r.heat < 6 and r.smoke >= 0 and r.smoke < 3)
				assert(not (r.damage > 0 and r.self_damage > 0))
	var hp: Array[int] = [12, 12, 12, 12]
	for caster in range(4):
		assert(AlchemyRules.target(hp, caster) == (caster + 1) % 4)
	hp.assign([0, 7, 20, 9])
	assert(AlchemyRules.target(hp, 2) == 3)
	assert(AlchemyRules.target(hp, 1) == 2)
	assert(AlchemyRules.next_player(hp, 3) == 1)
	hp.assign([0, 0, 20, 0])
	assert(AlchemyRules.target(hp, 2) == -1)
	await create_timer(1.7).timeout
	game.heat = 4
	game.smoke = 2
	var before: Array[int] = game.hp.duplicate()
	var preview: Dictionary = game._simulate_card(2)
	await game._resolve_reaction(preview, 2, 2)
	assert(game.hp == [before[0] - 5, before[1], before[2]])
	assert(game.heat == 0 and game.smoke == 0)
	game.heat = 5
	game.smoke = 2
	await game._resolve_reaction(game._simulate_card(2), 2, 2)
	assert(game.hp[2] == before[2] - 3)
	assert(game.heat == 0 and game.smoke == 0)
	print("RULES PASS: 144 states, clamping before heat, threshold priority, reset, damage, targeting, real resolution")
	quit()
