extends RefCounted

const BACKGROUND = preload("res://assets/ui/map/storybook-background.png")
const SEALS = preload("res://assets/ui/map/node-seals.png")
const BOOKMARKS = preload("res://assets/ui/map/bookmark-tabs.png")
const HOME = preload("res://assets/ui/map/home.svg")
const HERO = preload("res://assets/pieces/condensation_base.png")
const KINDS := ["battle", "shop", "rest", "event", "reward", "boss"]
const LABELS := ["战斗", "商店", "休整", "事件", "奖励", "首领"]
const INK := Color("44334b")
const GOLD := Color("caa268")
const PURPLE := Color("614873")
static var _textures: Dictionary = {}

static func node_texture(kind: String) -> Texture2D:
	if kind == "start":
		return HOME
	if not _textures.has(kind):
		var index := maxi(0, KINDS.find(kind))
		var texture := AtlasTexture.new()
		texture.atlas = SEALS
		texture.region = Rect2((index % 3) * 512 + 48, (index / 3) * 512 + 38, 440, 444)
		texture.filter_clip = true
		_textures[kind] = texture
	return _textures[kind]

static func tab_style(active: bool, hovered: bool = false) -> StyleBoxTexture:
	var texture := AtlasTexture.new()
	texture.atlas = BOOKMARKS
	texture.region = Rect2(52, 230, 814, 420) if active else Rect2(913, 230, 814, 398)
	texture.filter_clip = true
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_content_margin_all(12)
	if hovered:
		style.modulate_color = Color(1.10, 1.07, 1.01)
	return style
