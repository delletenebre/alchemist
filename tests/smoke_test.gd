extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(25).timeout.connect(func() -> void: quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.demo_opponents = false
	game.random_seed = 42
	root.add_child(game)
	await create_timer(1.7).timeout
	assert(game.hp == [12, 12, 12])
	assert(game.heat == 0 and game.smoke == 0)
	assert(game.hand_ids.size() == 6 and game.cards.size() == 8)
	assert(game.cauldron.fire.z_index > game.cauldron.body.z_index)
	assert(not game.has_node("Composition/Queue"))
	assert(game.hand_ids.slice(0,3) == [0,2,4])
	assert(game._target_index() == 0)
	var counts: Array[int] = []
	counts.resize(8)
	for held in game.player_hands:
		for id in held: counts[id] += 1
	for id in game.deck: counts[id] += 1
	assert(counts == [4,4,4,4,4,4,4,4])
	await game._play_selected()
	assert(game.heat == 3 and game.smoke == 0)
	assert(game.hp == [12, 12, 12])
	assert(game.hand_ids.size() == 6)
	assert(game.hand.cards[5] == game.get_node("Composition/Hand/Card0"))
	assert(not game.animating and not game.hand.locked)
	print("SMOKE PASS: equal HP, eight ingredients, deck conservation, consume and draw, automatic heating")
	quit()
