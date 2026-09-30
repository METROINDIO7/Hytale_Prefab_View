class_name BlockySettings
extends RefCounted

## Shared conversion settings.
##
## Blocky units ("pixels") vs scene units (1 scene unit = 1 block in-game):
##   scene = blocky / block_size
##   blocky = scene * block_size

const BLOCK_SIZE_PROP := 32
const BLOCK_SIZE_CHARACTER := 64

var block_size: float = BLOCK_SIZE_PROP
var atlas_size := Vector2i(64, 64)
var atlas_texture: Texture2D = null
var keep_empty_leaves := false

static var current := BlockySettings.new()
