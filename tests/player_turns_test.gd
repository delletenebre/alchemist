extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(1))
	for count in [2,3,4]:
		var game = load("res://scenes/main.tscn").instantiate()
		game.player_count = count
		game.random_seed = 42
		root.add_child(game)
		await create_timer(1.7).timeout
		assert(game.actors.size() == count)
		assert(game.self_panel.scale.x > 0.7)
		assert(game.mira.target_ring.visible)
		var seen: Array[int] = []
		game._play_selected()
		while game.animating:
			await process_frame
			if game.opponent_card.visible and not seen.has(game.active_player):
				seen.append(game.active_player)
				var actor: ActorPanel = game.actors[game.active_player]
				assert(actor.active_turn and actor.scale.x > 0.7)
				var target: int = game._target_index()
				assert(target != game.active_player and game.actors[target].scale.x > 0.7)
				var center: Vector2 = game.opponent_card.get_global_transform() * (game.opponent_card.size * 0.5)
				# The reveal has advanced one frame; compare in design units at any viewport scale.
				assert(center.distance_to(actor.card_origin()) < 12 * game.composition.scale.x)
		assert(seen.size() == count - 1)
		assert(game.active_player == count - 1 and not game.hand.locked)
		var counts: Array[int] = []
		counts.resize(8)
		for held in game.player_hands:
			assert(held.size() == 6)
			for id in held: counts[id] += 1
		for id in game.deck: counts[id] += 1
		for id in game.discard: counts[id] += 1
		assert(counts == [4,4,4,4,4,4,4,4])
		game.queue_free()
		await process_frame
	print("TURNS PASS: 2–4 player cycles, real hands, deck conservation, duel focus, portrait origins")
	quit()
