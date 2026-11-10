class_name Icons
extends RefCounted
## The game's icons, as small SVG drawings on a 24×24 grid in the palette of
## docs/art/style-brief.md: soft fills with a brown ink outline. Icons.rect()
## gives a TextureRect for layouts; Icons.texture() gives a texture for a
## Button's icon.

const _S := ' stroke="#3D332A" stroke-width="1.3" stroke-linejoin="round" stroke-linecap="round"'

const BODIES := {
	# Resources
	"stones": '<path d="M7 4h10l4 5-9 12L3 9z" fill="#7FB8B0"' + _S + '/><path d="M7 4h10l4 5H3z" fill="#B4DAD2"' + _S + '/><path d="M7 4l5 5 5-5M12 9v12" fill="none"' + _S + '/>',
	"food": '<path d="M5 11.5c0-4 3-6.5 7-6.5s7 2.5 7 6.5z" fill="#FDF9EF"' + _S + '/><path d="M2.5 11.5h19a9.5 8 0 0 1-19 0z" fill="#C8634A"' + _S + '/><path d="M14 2.5l6 6M16.5 2l4.5 4.5" stroke="#8B5A3C" stroke-width="1.5" stroke-linecap="round"/>',
	"herbs": '<path d="M12 21.5V8.5" stroke="#4E7A45" stroke-width="1.7" stroke-linecap="round"/><path d="M12 14c-5 0-7.5-3-7.5-7.5 4.5 0 7.5 2.5 7.5 7.5z" fill="#7DB26B"' + _S + '/><path d="M12 10.5c4.5 0 6.5-2.5 6.5-7-4.5 0-6.5 2.5-6.5 7z" fill="#A6CF94"' + _S + '/><path d="M12 18.5c3.5 0 5.5-1.7 5.5-4.5-3.5 0-5.5 1.7-5.5 4.5z" fill="#7DB26B"' + _S + '/>',
	"reputation": '<path d="M12 2.5l2.9 6 6.6.8-4.9 4.5 1.3 6.5L12 17l-5.9 3.3 1.3-6.5-4.9-4.5 6.6-.8z" fill="#E8C35A"' + _S + '/>',
	"energy": '<path d="M12 22c-4 0-7-3-7-7 0-4.5 4-6 4-11.5 3 2 4.5 4.5 4.5 6.5 1-1 1.5-2.5 1.5-4 3 2.5 4 6.5 4 9 0 4-3 7-7 7z" fill="#A7BCEB"' + _S + '/><path d="M12 19.5c-2 0-3.2-1.5-3.2-3.2 0-2 2-3 2.2-5 2 1.5 4.2 3 4.2 5.1 0 1.6-1.2 3.1-3.2 3.1z" fill="#E8EFFC"/>',
	# Pills
	"foundation_pill": '<circle cx="12" cy="12.5" r="7.5" fill="#C9955B"' + _S + '/><circle cx="9.5" cy="10" r="2.2" fill="#F1D9B5"/>',
	"healing_pill": '<circle cx="12" cy="12.5" r="7.5" fill="#79B472"' + _S + '/><circle cx="9.5" cy="10" r="2.2" fill="#D3EBCB"/><path d="M12 9.5v6M9 12.5h6" stroke="#FDF9EF" stroke-width="1.6" stroke-linecap="round"/>',
	"golden_pill": '<circle cx="12" cy="12.5" r="7.5" fill="#E8C35A"' + _S + '/><circle cx="9.5" cy="10" r="2.2" fill="#FFF3C4"/><path d="M19 2.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z" fill="#E8C35A"/>',
	# People and feelings
	"loyalty": '<path d="M12 20.5s-8-4.8-8-10.4A4.3 4.3 0 0 1 12 7.6a4.3 4.3 0 0 1 8 2.5c0 5.6-8 10.4-8 10.4z" fill="#E58A86"' + _S + '/>',
	"mood_happy": '<circle cx="12" cy="12" r="9" fill="#F5D77A"' + _S + '/><circle cx="9" cy="10" r="1.1" fill="#3D332A"/><circle cx="15" cy="10" r="1.1" fill="#3D332A"/><path d="M8 13.5c2 2.6 6 2.6 8 0" fill="none"' + _S + '/>',
	"mood_ok": '<circle cx="12" cy="12" r="9" fill="#F5D77A"' + _S + '/><circle cx="9" cy="10" r="1.1" fill="#3D332A"/><circle cx="15" cy="10" r="1.1" fill="#3D332A"/><path d="M9 15h6" fill="none"' + _S + '/>',
	"mood_sad": '<circle cx="12" cy="12" r="9" fill="#C9D3E3"' + _S + '/><circle cx="9" cy="10" r="1.1" fill="#3D332A"/><circle cx="15" cy="10" r="1.1" fill="#3D332A"/><path d="M8.5 16c2-2.3 5-2.3 7 0" fill="none"' + _S + '/>',
	"disciples": '<circle cx="16" cy="8.5" r="2.8" fill="#FCE6CC"' + _S + '/><path d="M11.5 19c0-3.5 2-5.5 4.5-5.5s4.5 2 4.5 5.5z" fill="#D9734C"' + _S + '/><circle cx="9" cy="8" r="3.3" fill="#FCE6CC"' + _S + '/><path d="M3 20.5c0-4.2 2.6-6.6 6-6.6s6 2.4 6 6.6z" fill="#6F9A8D"' + _S + '/>',
	"chat": '<path d="M4.5 4.5h15a2 2 0 0 1 2 2v8.5a2 2 0 0 1-2 2H11l-5 4v-4H4.5a2 2 0 0 1-2-2V6.5a2 2 0 0 1 2-2z" fill="#FDF9EF"' + _S + '/><circle cx="8" cy="11" r="1.1" fill="#6F9A8D"/><circle cx="12" cy="11" r="1.1" fill="#6F9A8D"/><circle cx="16" cy="11" r="1.1" fill="#6F9A8D"/>',
	"elder": '<circle cx="12" cy="9" r="4.5" fill="#FCE6CC"' + _S + '/><path d="M8.5 11.5c0 5 3.5 8.5 3.5 8.5s3.5-3.5 3.5-8.5z" fill="#F2F2ED"' + _S + '/><circle cx="12" cy="3.8" r="1.8" fill="#F2F2ED"' + _S + '/>',
	# Tabs and the day
	"today": '<g stroke="#D9A93A" stroke-width="1.7" stroke-linecap="round"><path d="M12 1.5v3M12 19.5v3M1.5 12h3M19.5 12h3M4.6 4.6l2.1 2.1M17.3 17.3l2.1 2.1M4.6 19.4l2.1-2.1M17.3 6.7l2.1-2.1"/></g><circle cx="12" cy="12" r="5.2" fill="#E8C35A"' + _S + '/>',
	"mountain": '<path d="M1.5 20.5l7.5-13 4 6.5 3-4.5 6.5 11z" fill="#6F9A8D"' + _S + '/><path d="M9 7.5l-2.2 3.8 2.2-1.1 2.1 1.4zM16 9.5l-1.6 2.6 1.6-.7 1.5 1z" fill="#FDF9EF"/>',
	"event": '<path d="M6.5 4h12v14a3 3 0 0 1-3 3h-9z" fill="#F4ECD8"' + _S + '/><path d="M6.5 4a2.3 2.3 0 0 0 0 4.6H9V4z" fill="#E2D3B0"' + _S + '/><path d="M11 9h5M11 12h5M11 15h3" fill="none"' + _S + '/>',
	# The world (M6)
	"world": '<path d="M2.5 5.5l6.5-2.5 6 2.5 6.5-2.5v15.5l-6.5 2.5-6-2.5-6.5 2.5z" fill="#F4ECD8"' + _S + '/><path d="M9 3v15.5M15 5.5V21" fill="none"' + _S + '/><path d="M4 15l2.4-3.6 1.8 2.4 2.1-2.6 2.8 3.4" fill="none" stroke="#6F9A8D" stroke-width="1.4" stroke-linejoin="round" stroke-linecap="round"/><circle cx="18" cy="10" r="1.6" fill="#C8634A"/>',
	"iron_frog": '<ellipse cx="12" cy="14.5" rx="9" ry="6.5" fill="#7DB26B"' + _S + '/><circle cx="7.3" cy="8" r="3.3" fill="#7DB26B"' + _S + '/><circle cx="16.7" cy="8" r="3.3" fill="#7DB26B"' + _S + '/><circle cx="7.3" cy="8" r="1.3" fill="#3D332A"/><circle cx="16.7" cy="8" r="1.3" fill="#3D332A"/><path d="M7 15.5c3 2.6 7 2.6 10 0" fill="none"' + _S + '/>',
	"moonlit_tea": '<path d="M3.5 10h13v3.2a6.5 6.5 0 0 1-13 0z" fill="#FDF9EF"' + _S + '/><path d="M16.5 11.5h1.5a2.5 2.5 0 0 1 0 5h-2.2" fill="none"' + _S + '/><path d="M2.5 21h15" fill="none"' + _S + '/><path d="M15.5 2a3.8 3.8 0 1 0 4.2 4.9 3.2 3.2 0 0 1-4.2-4.9z" fill="#E8C35A"' + _S + '/>',
	"perfect_hair": '<path d="M3 8.5h18v4.5H3z" fill="#C9955B"' + _S + '/><path d="M5.5 13v6.5M8.5 13v6.5M11.5 13v6.5M14.5 13v6.5M17.5 13v6.5" fill="none"' + _S + '/><path d="M18.5 2l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z" fill="#E8C35A"/>',
	"medal": '<path d="M7.5 2h3.5l1.5 6.5-3 1.3zM16.5 2H13l-1.5 6.5 3 1.3z" fill="#C8634A"' + _S + '/><circle cx="12" cy="15.5" r="6" fill="#E8C35A"' + _S + '/><path d="M12 12.3l1 2.1 2.3.3-1.7 1.6.4 2.3-2-1.1-2 1.1.4-2.3-1.7-1.6 2.3-.3z" fill="#FFF3C4"/>',
	"letter": '<path d="M2.5 6h19v12.5h-19z" fill="#FDF9EF"' + _S + '/><path d="M2.5 6l9.5 7.5L21.5 6" fill="none"' + _S + '/><circle cx="12" cy="13.5" r="1.8" fill="#C8634A"' + _S + '/>',
	"banner": '<path d="M5.5 2.5v19" stroke="#8B5A3C" stroke-width="2" stroke-linecap="round"/><path d="M6 3.5h13l-3.2 4.3 3.2 4.3H6z" fill="#C8634A"' + _S + '/>',
	"hill": '<path d="M1.5 20c2.8-6.2 6.4-9.2 10.5-9.2s7.7 3 10.5 9.2z" fill="#7DB26B"' + _S + '/><path d="M12 10.8V4" stroke="#8B5A3C" stroke-width="1.4" stroke-linecap="round"/><path d="M12.5 4.2l4 1.6-4 1.6z" fill="#E8C35A"' + _S + '/>',
	"gate": '<path d="M2.5 7h19M4 4.5h16" fill="none" stroke="#B3473A" stroke-width="2" stroke-linecap="round"/><path d="M6 7v14M18 7v14" stroke="#B3473A" stroke-width="2" stroke-linecap="round"/><path d="M6 11h12" stroke="#B3473A" stroke-width="1.4"/>',
	# Tasks
	"train": '<path d="M19 3l2 2L9.5 16.5l-2-2z" fill="#D9DEE3"' + _S + '/><path d="M5.5 13l5.5 5.5" stroke="#8B5A3C" stroke-width="2" stroke-linecap="round"/><path d="M7.5 16.5L3.5 20.5" stroke="#8B5A3C" stroke-width="2.4" stroke-linecap="round"/>',
	"work": '<path d="M4.5 20.5L16.5 7" stroke="#8B5A3C" stroke-width="2" stroke-linecap="round"/><path d="M13.5 4.5l7 1.8-3.8 4.6z" fill="#AEB7BD"' + _S + '/>',
	"rest": '<path d="M14.5 3a8.6 8.6 0 1 0 6.5 13.8A7.2 7.2 0 0 1 14.5 3z" fill="#F1D37E"' + _S + '/><path d="M18.5 4.5l.5 1.3 1.3.5-1.3.5-.5 1.3-.5-1.3-1.3-.5 1.3-.5z" fill="#E8C35A"/>',
	"study": '<path d="M2.5 6c3.2-1.6 6.3-1.6 9.5 1v12.5c-3.2-2.6-6.3-2.6-9.5-1z" fill="#FDF9EF"' + _S + '/><path d="M21.5 6c-3.2-1.6-6.3-1.6-9.5 1v12.5c3.2-2.6 6.3-2.6 9.5-1z" fill="#E9DFC6"' + _S + '/>',
	"breakthrough": '<path d="M13.5 1.5L4.5 13.5h6.5l-1.5 9 9-12.5H12z" fill="#E8C35A"' + _S + '/>',
	"heal": '<path d="M12 21s-8-4.8-8-10.4A4.3 4.3 0 0 1 12 8.1a4.3 4.3 0 0 1 8 2.5C20 16.2 12 21 12 21z" fill="#79B472"' + _S + '/><path d="M12 10.5v6M9 13.5h6" stroke="#FDF9EF" stroke-width="1.6" stroke-linecap="round"/>',
	# Missions
	"gather_herbs": '<path d="M5 10h14l-1.5 10.5h-11z" fill="#C9955B"' + _S + '/><path d="M5 10c1-4 4-6.5 7-6.5S18 6 19 10" fill="none"' + _S + '/><path d="M9 10c0-3 1.5-4.5 3-5 .5 2-.5 4-3 5zM13 10c1-2.5 3-3.5 4.5-3.5-.5 2-2 3.5-4.5 3.5z" fill="#7DB26B"' + _S + '/>',
	"hunt_monster": '<ellipse cx="12" cy="16" rx="5" ry="4.3" fill="#997A57"' + _S + '/><circle cx="5.3" cy="10.5" r="2" fill="#997A57"' + _S + '/><circle cx="9.3" cy="6.8" r="2.1" fill="#997A57"' + _S + '/><circle cx="14.7" cy="6.8" r="2.1" fill="#997A57"' + _S + '/><circle cx="18.7" cy="10.5" r="2" fill="#997A57"' + _S + '/>',
	"escort_merchant": '<path d="M3 8.5h13v8H3z" fill="#C9955B"' + _S + '/><path d="M3 8.5c2-3 11-3 13 0" fill="#E2D3B0"' + _S + '/><path d="M16 12h3.5l2 2.5v2H16z" fill="#C8634A"' + _S + '/><circle cx="7" cy="18" r="2" fill="#8B5A3C"' + _S + '/><circle cx="17" cy="18" r="2" fill="#8B5A3C"' + _S + '/>',
	"explore_secret_realm": '<circle cx="12" cy="12" r="9" fill="#8C739E"' + _S + '/><path d="M12 6.5a5.5 5.5 0 1 1-5.5 5.5 3.6 3.6 0 0 1 3.6-3.6 2.2 2.2 0 0 1 2.2 2.2" fill="none" stroke="#EDE4F5" stroke-width="1.7" stroke-linecap="round"/>',
	# Little things
	"sparkle": '<path d="M12 2l2.2 7.8L22 12l-7.8 2.2L12 22l-2.2-7.8L2 12l7.8-2.2z" fill="#FFFFFF"/>',
	"lock": '<rect x="5" y="10.5" width="14" height="10" rx="2" fill="#D1C4AB"' + _S + '/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" fill="none"' + _S + '/>',
	"brew": '<path d="M4 9.5h16l-1.5 9a3 3 0 0 1-3 2.5h-7a3 3 0 0 1-3-2.5z" fill="#5E6B73"' + _S + '/><path d="M3 9.5h18" stroke="#3D332A" stroke-width="1.6" stroke-linecap="round"/><circle cx="9.5" cy="5.5" r="1.6" fill="#B9E0D2"/><circle cx="13.5" cy="3.8" r="1.2" fill="#B9E0D2"/><circle cx="15" cy="6.8" r="1.4" fill="#B9E0D2"/>',
}


static func has(kind: String) -> bool:
	return BODIES.has(kind)


## The SVG of [param kind] (on a 24×24 grid).
static func svg(kind: String) -> String:
	return Art.svg(24, 24, BODIES.get(kind, BODIES["sparkle"]))


## The icon as a texture, [param pixels] wide.
static func texture(kind: String, pixels: int = 48) -> Texture2D:
	return Art.texture(svg(kind), pixels)


## The icon in a box of [param size] canvas units, sharp at any stretch.
static func rect(kind: String, size: float = 20.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(kind, int(ceil(size * 4.0)))
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The mood icon for a Mood value.
static func mood_kind(mood: int) -> String:
	if mood >= 3:
		return "mood_happy"
	if mood <= -3:
		return "mood_sad"
	return "mood_ok"


## The icon for a home task or a mission.
static func task_kind(choice: String) -> String:
	return choice if BODIES.has(choice) else "event"
