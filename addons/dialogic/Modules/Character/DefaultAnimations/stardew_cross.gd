extends DialogicAnimation
## Stardew-style portrait swap: old portrait fades fast, new one pops in
## with a small hop and a white flash that fades to normal.
const HOP := 0.0   # pixels, tune to taste
const FLASH := 3.0  # >1 = brighter than white

func animate() -> void:
	var prop := get_modulation_property()
	if is_reversed:
		var t := node.create_tween()
		t.tween_property(node, prop + ":a", 0.0, time * 0.25)
		await t.finished
		finished_once.emit()
		return
	var y: float = node.position.y
	node.set(prop, Color(FLASH, FLASH, FLASH, 1.0))
	node.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE) \
		.tween_property(node, prop, Color.WHITE, time)
	var hop := node.create_tween()
	hop.tween_property(node, "position:y", y - HOP, time * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hop.tween_property(node, "position:y", y, time * 0.65).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	await hop.finished
	finished_once.emit()


func _get_named_variations() -> Dictionary:
	return {"stardew cross": {"type": AnimationType.CROSSFADE}}
