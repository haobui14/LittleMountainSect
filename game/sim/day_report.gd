class_name DayReport
extends RefCounted
## What happened on one day, as structured facts, never sentences. The game
## writes the facts up from tr() templates; from M4 the same facts go to the
## evening story request, so Claude tells exactly what the rules decided.
##
## Fact types and their fields:
##   trained          disciple, gain, ready (reached Balance.PROGRESS_MAX)
##   worked           disciples, food, herbs
##   rested           disciple, mood
##   healed           disciple
##   mission_departed mission, team, return_day
##   mission_returned mission, tier, team, rewards
##   injured          disciple, days, mission
##   lost_cultivation disciple, amount, mission
##   ate              food
##   hungry           disciples
##   loyalty_up       disciple
##   loyalty_down     disciple

var day: int
var facts: Array[Dictionary] = []
## Net change of each resource over the day.
var resource_changes: Dictionary = {}


func _init(report_day: int = 0) -> void:
	day = report_day


func add(type: String, fields: Dictionary = {}) -> void:
	var fact := {"type": type}
	fact.merge(fields)
	facts.append(fact)


func of_type(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(facts.filter(func(f: Dictionary) -> bool: return f["type"] == type))
	return out


func to_dict() -> Dictionary:
	return {"day": day, "facts": facts.duplicate(true), "resource_changes": resource_changes.duplicate()}


static func from_dict(data: Dictionary) -> DayReport:
	var r := DayReport.new(int(data["day"]))
	for fact: Dictionary in data["facts"]:
		r.facts.append(_whole_numbers(fact))
	for key: String in data["resource_changes"]:
		r.resource_changes[key] = int(data["resource_changes"][key])
	return r


## JSON turns every number into a float; facts only hold whole numbers, so
## turn them back into ints (recursively) after loading.
static func _whole_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value)
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				out[key] = _whole_numbers(value[key])
			return out
		TYPE_ARRAY:
			return Array(value).map(_whole_numbers)
	return value
