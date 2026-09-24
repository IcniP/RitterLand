# res://Scripts/core/Cutscene.gd  -- autoload "Cutscene"
# Placeholder cutscene glue: Dialogic <-> world sprites <-> CombatZone.
#  * Speaker appears as a dupe of IliaNpc.tscn (tinted, name label) (a real NPC in the scene is reused instead).
#  * [signal arg="combat:<anything>"] pauses the timeline, hides the textbox, runs the
#    scene's CombatZone, and resumes the dialogue when the fight is over.
#    Result: Dialogic.VAR.combat_won (1/0) -> use `if {combat_won}:` in the .dtl.
#  * Optional stage commands: enter:Name:x:y  move:Name:x:y[:secs]  leave:Name
extends Node

const ACTOR := preload("res://scenes/IliaNpc.tscn")   # PLACEHOLDER: swap per character later
const PLAYER_NAMES := ["Lan"]
var actors := {}      # id -> Node2D (spawned dupes only)
var playing := false

func _ready() -> void:
	Dialogic.signal_event.connect(_on_signal)
	Dialogic.timeline_started.connect(func(): playing = true; _freeze(true))
	Dialogic.timeline_ended.connect(_on_end)
	Dialogic.Text.speaker_updated.connect(_on_speaker)

func play(timeline: String, label := "") -> void:
	Dialogic.start(timeline, label)

# ---------- actors ----------
func _yort() -> Node:
	return get_tree().current_scene.get_node_or_null("Y-sort")

func get_actor(id: String) -> Node2D:
	if id in PLAYER_NAMES: return Global.player
	if actors.has(id) and is_instance_valid(actors[id]): return actors[id]
	var y := _yort()
	if y == null or not is_instance_valid(Global.player): return null
	for n in [id + "Npc", id]:              # Ilia already stands in the scene -> reuse her
		var real := y.get_node_or_null(n)
		if real: return real
	var a: Node2D = ACTOR.instantiate()
	a.dialogue_timeline = ""
	y.add_child(a)
	a.get_node("Interactable").queue_free()
	a.get_node("IliaHitbox").disabled = true
	a.modulate = Color.from_hsv(fposmod(id.hash() * 0.00013, 1.0), 0.45, 1.0)   # tint = fake palette swap
	var l := Label.new(); l.text = id; l.scale = Vector2(3, 3); l.position = Vector2(-40, -130)   # scene is scaled 0.2
	a.add_child(l)
	a.global_position = Global.player.global_position + Vector2(32 + 22 * actors.size(), -6)
	actors[id] = a
	return a

func _on_speaker(c: DialogicCharacter) -> void:
	if c: get_actor(c.get_identifier().get_file())        # just make sure they exist ("Dialog/Ilia" -> "Ilia")

# ---------- signals ----------
func _on_signal(arg: String) -> void:
	var p := arg.split(":")
	match p[0]:
		"enter":  # enter:Name:x:y
			var a := get_actor(p[1])
			if a and p.size() > 3: a.global_position = Vector2(float(p[2]), float(p[3]))
		"leave":
			if actors.has(p[1]): actors[p[1]].queue_free(); actors.erase(p[1])
		"move":   # move:Name:x:y[:secs]
			await _busy(_move.bind(get_actor(p[1]), Vector2(float(p[2]), float(p[3])), float(p[4]) if p.size() > 4 else 0.6))
		"combat": # every fight uses the scene's CombatZone for now (p[1] = fight id, ignored)
			await _busy(_combat)

func _busy(job: Callable) -> void:
	Dialogic.paused = true          # timeline stops right after this signal line
	await job.call()
	Dialogic.paused = false

func _move(a: Node2D, to: Vector2, secs: float) -> void:
	if a == null: return
	var s: AnimatedSprite2D = a.get("animated_sprite")
	var d := to - a.global_position
	var dir := ("Right" if d.x > 0 else "Left") if absf(d.x) > absf(d.y) else ("Down" if d.y > 0 else "Up")
	if s: s.play("Walk" + dir)
	await create_tween().tween_property(a, "global_position", to, secs).finished
	if s: s.play("Idle" + dir)

# ---------- combat ----------
func _zone() -> CombatZone:
	for c in get_tree().current_scene.get_children():
		if c is CombatZone: return c
	return null

func _combat() -> void:
	var zone := _zone()
	if zone == null:
		push_warning("Cutscene: no CombatZone in current scene"); return
	var layout = Dialogic.Styles.get_layout_node()
	if layout: layout.visible = false
	_freeze(false)
	for a in actors.values(): a.visible = false        # cutscene dupes sit out the fight
	var cm: Node = zone.get_node(zone.combat_manager_path)
	zone.start_training()
	var won: bool = await cm.combat_ended
	while Global.game_state != Global.GameState.EXPLORATION:   # zone tears down after the signal
		await get_tree().process_frame
	for a in actors.values(): a.visible = true
	Dialogic.VAR.combat_won = 1 if won else 0
	_freeze(true)
	if layout: layout.visible = true

# ---------- housekeeping ----------
func _freeze(on: bool) -> void:
	if is_instance_valid(Global.player):
		Global.player.set_physics_process(not on)
		if on: Global.player.velocity = Vector2.ZERO

func _on_end() -> void:
	playing = false
	_freeze(false)
	for a in actors.values():
		if is_instance_valid(a): a.queue_free()
	actors.clear()
