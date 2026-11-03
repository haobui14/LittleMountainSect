extends Node
## Global signal bus. Systems emit and listen here instead of holding
## references to each other.

## Emitted after the game's language changes. [param locale] is "en" or "vi".
@warning_ignore("unused_signal")
signal language_changed(locale: String)
