class_name StatusEffect
extends RefCounted
## A timed condition on a disciple. M3 has one kind, "injured": the disciple
## can only rest until it wears off. (Lost cultivation is an instant loss of
## progress, not an effect.)

const KINDS: Array[String] = ["injured"]

var kind: String
var days_left: int


func _init(effect_kind: String = "injured", days: int = 1) -> void:
	assert(effect_kind in KINDS, "Unknown status effect: %s" % effect_kind)
	kind = effect_kind
	days_left = days


func to_dict() -> Dictionary:
	return {"kind": kind, "days_left": days_left}


static func from_dict(data: Dictionary) -> StatusEffect:
	return StatusEffect.new(String(data["kind"]), int(data["days_left"]))
