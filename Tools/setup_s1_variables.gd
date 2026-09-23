@tool
extends EditorScript
# Run once: Script Editor > File > Run (Ctrl+Shift+X). Adds Season 1 variables to Dialogic without touching existing ones.

func _run() -> void:
	var wanted := {
		"exposure": 0,
		"rank": 67,
		"rank_points": 0,
		"stat_control": 2,
		"stat_sword": 6,
		"stat_shir": 0,
		"aff_leonora": 0,
		"aff_liesel": 0,
		"aff_ilia": 0,
		"aff_florentine": 0,
		"aff_enriko": 0,
		"aff_veldero": 0,
		"aff_luna": 0,
		"aff_raiz": 0,
		"veldero_tells": 0,
		"pe_marks_seen": 0,
		"luna_letter_seen": 0,
		"trial_held_back": 0,
		"sandbagged_leonora": 0,
		"stood_up_courtyard": 0,
		"liesel_pitch_honest": 0,
		"pitch_tries": 0,
		"used_montante_clearing": 0,
		"leonora_wounded": 0,
		"told_berthram_truth": 0,
		"leonora_promise": 0,
		"edric_named_early": 0,
		"han_grudge_high": 0,
		"took_duel_bait": 0,
		"told_friends_something_coming": 0,
		"voss_confronted": 0,
		"amir_accepted_early": 0,
		"leonora_told_suspected": 0,
		"ilia_deal": 0,
		"liesel_joined": 0,
		"resolve_board": 0,
		"enriko_ran": 0,
		"kliam_captured": 0
	}
	var existing: Dictionary = ProjectSettings.get_setting("dialogic/variables", {})
	var added := 0
	for k in wanted:
		if not existing.has(k):
			existing[k] = wanted[k]
			added += 1
	ProjectSettings.set_setting("dialogic/variables", existing)
	ProjectSettings.save()
	print("Ritterland S1: added %d variables (of %d)" % [added, wanted.size()])
