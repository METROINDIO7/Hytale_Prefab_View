class_name BlockyAnimData
extends RefCounted

## Stub for animation data (animations not used in prefab viewer).

const ANIM_FPS := 30

var anim_name: String = ""
var node_animations: Dictionary = {}
var duration: int = 0
var hold_last_keyframe: bool = false

static func from_dict(d: Dictionary) -> BlockyAnimData:
	return null

func to_dict() -> Dictionary:
	return {}

static func from_animation_player(_ap: AnimationPlayer, _anim_name: String) -> BlockyAnimData:
	return null
