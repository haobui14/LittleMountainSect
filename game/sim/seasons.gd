class_name Seasons
extends RefCounted
## The calendar (M6): seasons of Balance.SEASON_DAYS (Spring, Summer, Autumn,
## Winter), four to a year. Each season ends with a tournament on its last
## day; at the start of each new season the sect's allies send a gift.


## 0 to 3: Spring, Summer, Autumn or Winter.
static func index(day: int) -> int:
	@warning_ignore("integer_division")
	return ((maxi(day, 1) - 1) / Balance.SEASON_DAYS) % Balance.SEASONS.size()


static func season(day: int) -> String:
	return Balance.SEASONS[index(day)]


static func year(day: int) -> int:
	@warning_ignore("integer_division")
	return (maxi(day, 1) - 1) / (Balance.SEASON_DAYS * Balance.SEASONS.size()) + 1


## Seasons since the game began, counting the current one: 1, 2, 3...
static func number(day: int) -> int:
	@warning_ignore("integer_division")
	return (maxi(day, 1) - 1) / Balance.SEASON_DAYS + 1


## 1 to Balance.SEASON_DAYS.
static func day_in_season(day: int) -> int:
	return (maxi(day, 1) - 1) % Balance.SEASON_DAYS + 1


static func is_tournament_day(day: int) -> bool:
	return day_in_season(day) == Balance.SEASON_DAYS


## 0 on tournament day.
static func days_to_tournament(day: int) -> int:
	return Balance.SEASON_DAYS - day_in_season(day)


static func is_season_start(day: int) -> bool:
	return day > 1 and day_in_season(day) == 1


## At night, on the first day of a new season: a "season" fact, and each ally
## sends Spirit Stones.
static func night(sect: Sect) -> void:
	if not is_season_start(sect.day):
		return
	sect.pending_facts.append({"type": "season", "season": season(sect.day), "year": year(sect.day)})
	for rival in RivalCatalog.ids():
		if sect.rival(rival)["ally"]:
			var stones := sect.add_resource("stones", Balance.ALLY_SEASON_STONES)
			sect.pending_facts.append({"type": "ally_gift", "rival": rival, "stones": stones})
