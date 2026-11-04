extends Node
## Global signal bus. Systems emit and listen here instead of holding
## references to each other.

## Emitted after the game's language changes. [param locale] is "en" or "vi".
@warning_ignore("unused_signal")
signal language_changed(locale: String)

## Emitted when anything about the game in play changes (a plan, an upgrade,
## a new day, a load). Screens refresh on it.
@warning_ignore("unused_signal")
signal state_changed

## Emitted after a day is resolved, with what happened.
@warning_ignore("unused_signal")
signal day_resolved(report: DayReport)
