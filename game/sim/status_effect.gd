class_name StatusEffect
extends RefCounted
## A timed condition on a disciple: "injured" (the disciple can only rest,
## and heals by resting), or one of the funny side effects of a failed
## breakthrough in Balance.SIDE_EFFECTS, which wear off a day at a time.
## (Lost cultivation is an instant loss of progress, not an effect.)

var kind: String
var days_left: int


static func valid(effect_kind: String) -> bool:
	return effect_kind == "injured" or effect_kind in Balance.SIDE_EFFECTS


func _init(effect_kind: String = "injured", days: int = 1) -> void:
	assert(valid(effect_kind), "Unknown status effect: %s" % effect_kind)
	kind = effect_kind
	days_left = days


func is_side_effect() -> bool:
	return kind != "injured"


func to_dict() -> Dictionary:
	return {"kind": kind, "days_left": days_left}


static func from_dict(data: Dictionary) -> StatusEffect:
	return StatusEffect.new(String(data["kind"]), int(data["days_left"]))
