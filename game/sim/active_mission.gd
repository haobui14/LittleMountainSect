class_name ActiveMission
extends RefCounted
## A team away on a mission. The result tier is rolled when the team leaves,
## from the team as it was then; rewards and setbacks are rolled on return.
## Mission definitions live in Balance.MISSIONS.

var mission: String
var team: Array[String] = []
var departed_day: int
## The day whose evening the team comes home.
var return_day: int
var tier: String


func to_dict() -> Dictionary:
	return {
		"mission": mission,
		"team": team.duplicate(),
		"departed_day": departed_day,
		"return_day": return_day,
		"tier": tier,
	}


static func from_dict(data: Dictionary) -> ActiveMission:
	var m := ActiveMission.new()
	m.mission = String(data["mission"])
	m.team.assign(Array(data["team"]).map(func(id: Variant) -> String: return String(id)))
	m.departed_day = int(data["departed_day"])
	m.return_day = int(data["return_day"])
	m.tier = String(data["tier"])
	return m
