class_name FreeTime
extends RefCounted
## Free time, between the day plan and the results. Talking to a disciple
## gives a small Mood bonus, once per disciple per day, so chat matters but
## can't be repeated for easy gains (GDD: Disciples).


static func can_talk(d: Disciple) -> bool:
	return not d.talked_today


## Applies the chat bonus. Returns the Mood gained (0 when already talked).
static func talk(d: Disciple) -> int:
	if not can_talk(d):
		return 0
	d.talked_today = true
	var before := d.mood
	d.mood += Balance.TALK_MOOD
	d.clamp_values()
	return d.mood - before
