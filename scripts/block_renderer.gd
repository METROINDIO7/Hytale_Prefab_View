class_name BlockRenderer
extends Node3D

const BLOCK_SIZE := 1.0

signal blocks_changed(total: int, unique_types: int)

# ── Group data ────────────────────────────────────────────────────────────────
class GroupData:
	var name    : String
	var label   : String = ""
	var blocks  : Dictionary = {}
	var node    : Node3D
	var color   : Color

const DEFAULT_GROUP := "Default"
const GROUP_COLORS : Array = [
	Color(0.30, 0.65, 1.00), Color(0.40, 0.90, 0.45),
	Color(1.00, 0.70, 0.20), Color(0.90, 0.35, 0.35),
	Color(0.75, 0.45, 1.00), Color(0.30, 0.90, 0.80),
	Color(1.00, 0.85, 0.25), Color(0.80, 0.55, 0.30),
]

# ── Instance variables ────────────────────────────────────────────────────────
var _groups      : Dictionary = {}
var _color_index : int = 0

# ── Categories for auto-color (Based on actual Hytale block names) ───────────
# Only 1x1 full cube blocks included (no stairs, roofs, half, beams, etc.)
const _CATEGORIES : Array = [
	# ── ROCK FAMILY (Rock_*) ─────────────────────────────────────────────────
	["Rock_Volcanic_Brick",      Color(0.72, 0.38, 0.28)],
	["Rock_Volcanic_Cobble",     Color(0.45, 0.42, 0.40)],
	["Rock_Volcanic_Cracked",    Color(0.55, 0.35, 0.30)],
	["Rock_Limestone_Brick",     Color(0.85, 0.82, 0.70)],
	["Rock_Limestone_Cobble",    Color(0.78, 0.75, 0.68)],
	["Rock_Granite_Brick",       Color(0.65, 0.50, 0.55)],
	["Rock_Granite_Cobble",      Color(0.58, 0.45, 0.50)],
	["Rock_Marble_Brick",        Color(0.92, 0.90, 0.88)],
	["Rock_Marble_Cobble",       Color(0.85, 0.82, 0.78)],
	["Rock_Sandstone_Brick",     Color(0.88, 0.78, 0.55)],
	["Rock_Sandstone_Cobble",    Color(0.82, 0.72, 0.50)],
	["Rock_Slate_Brick",         Color(0.45, 0.48, 0.52)],
	["Rock_Slate_Cobble",        Color(0.40, 0.43, 0.47)],
	["Rock_Shale_Brick",         Color(0.55, 0.50, 0.48)],
	["Rock_Shale_Cobble",        Color(0.50, 0.45, 0.43)],
	["Rock_Quartzite_Brick",     Color(0.95, 0.92, 0.88)],
	["Rock_Calcite_Brick",       Color(0.88, 0.85, 0.80)],
	["Rock_Chalk_Brick",         Color(0.90, 0.88, 0.85)],
	["Rock_Basalt_Brick",        Color(0.35, 0.35, 0.40)],
	["Rock_Dawnstone_Brick",     Color(0.75, 0.70, 0.65)],
	["Rock_Stone_Brick",         Color(0.55, 0.55, 0.58)],
	["Rock_Stone_Cobble",        Color(0.50, 0.50, 0.52)],
	["Rock_Rough",               Color(0.58, 0.56, 0.54)],
	["Rock_Polished",            Color(0.70, 0.70, 0.72)],
	["Rock_Smooth",              Color(0.75, 0.75, 0.77)],
	
	# ── RUBBLE (Rubble_*) ────────────────────────────────────────────────────
	["Rubble_Stone",             Color(0.52, 0.50, 0.48)],
	["Rubble_Volcanic",          Color(0.48, 0.38, 0.35)],
	["Rubble_Sandstone",         Color(0.85, 0.75, 0.52)],
	["Rubble_Marble",            Color(0.88, 0.85, 0.80)],
	["Rubble_Granite",           Color(0.62, 0.48, 0.52)],
	["Rubble_Limestone",         Color(0.82, 0.78, 0.68)],
	["Rubble_Basalt",            Color(0.38, 0.38, 0.42)],
	["Rubble_Quartzite",         Color(0.92, 0.88, 0.85)],
	["Rubble_Calcite",           Color(0.85, 0.82, 0.78)],
	["Rubble_Chalk",             Color(0.88, 0.85, 0.82)],
	["Rubble_Shale",             Color(0.52, 0.48, 0.45)],
	["Rubble_Slate",             Color(0.42, 0.45, 0.50)],
	["Rubble_Dawnstone",         Color(0.72, 0.68, 0.62)],
	["Rubble_Ice",               Color(0.75, 0.88, 0.95, 0.70)],
	["Rubble_Magma_Cooled",      Color(0.45, 0.35, 0.30)],
	["Rubble_Aqua",              Color(0.40, 0.65, 0.75, 0.75)],
	["Rubble_Lime",              Color(0.75, 0.85, 0.65)],
	
	# ── SOIL & DIRT (Soil_Dirt*, Soil_Grass*) ────────────────────────────────
	["Soil_Dirt",                Color(0.52, 0.36, 0.20)],
	["Soil_Dirt_Cold",           Color(0.48, 0.35, 0.25)],
	["Soil_Dirt_Dry",            Color(0.58, 0.42, 0.25)],
	["Soil_Dirt_Wet",            Color(0.45, 0.30, 0.18)],
	["Soil_Dirt_Lush",           Color(0.48, 0.38, 0.22)],
	["Soil_Dirt_Burnt",          Color(0.35, 0.28, 0.22)],
	["Soil_Dirt_Poisoned",       Color(0.42, 0.35, 0.28)],
	["Soil_Dirt_Crystal",        Color(0.55, 0.45, 0.35, 0.80)],
	["Soil_Dirt_Tilled",         Color(0.50, 0.35, 0.20)],
	["Soil_Grass",               Color(0.28, 0.62, 0.22)],
	["Soil_Grass_Cold",          Color(0.32, 0.58, 0.25)],
	["Soil_Grass_Dry",           Color(0.38, 0.55, 0.22)],
	["Soil_Grass_Wet",           Color(0.25, 0.55, 0.20)],
	["Soil_Grass_Burnt",         Color(0.35, 0.45, 0.25)],
	["Soil_Grass_Sunny",         Color(0.35, 0.68, 0.28)],
	["Soil_Grass_Deep",          Color(0.22, 0.52, 0.18)],
	["Soil_Grass_Full",          Color(0.30, 0.65, 0.24)],
	
	# ── SAND & GRAVEL (Soil_Sand*, Soil_Gravel*) ─────────────────────────────
	["Soil_Sand",                Color(0.90, 0.82, 0.55)],
	["Soil_Sand_Red",            Color(0.85, 0.55, 0.45)],
	["Soil_Sand_White",          Color(0.95, 0.90, 0.75)],
	["Soil_Sand_Ashen",          Color(0.75, 0.70, 0.65)],
	["Soil_Gravel",              Color(0.58, 0.56, 0.54)],
	["Soil_Gravel_Mossy",        Color(0.52, 0.58, 0.48)],
	["Soil_Gravel_Sand",         Color(0.85, 0.78, 0.58)],
	["Soil_Gravel_Sand_Red",     Color(0.80, 0.58, 0.48)],
	["Soil_Gravel_Sand_White",   Color(0.90, 0.85, 0.72)],
	["Soil_Aqua_Gravel",         Color(0.45, 0.65, 0.75)],
	["Soil_Basalt_Gravel",       Color(0.40, 0.40, 0.45)],
	["Soil_Calcite_Gravel",      Color(0.82, 0.80, 0.75)],
	["Soil_Chalk_Gravel",        Color(0.85, 0.82, 0.78)],
	["Soil_Lime_Gravel",         Color(0.75, 0.82, 0.65)],
	["Soil_Magma_Cooled_Gravel", Color(0.48, 0.38, 0.35)],
	["Soil_Marble_Gravel",       Color(0.88, 0.85, 0.80)],
	["Soil_Quartzite_Gravel",    Color(0.92, 0.88, 0.85)],
	["Soil_Shale_Gravel",        Color(0.55, 0.50, 0.48)],
	["Soil_Slate_Gravel",        Color(0.45, 0.48, 0.52)],
	["Soil_Volcanic_Gravel",     Color(0.50, 0.40, 0.38)],
	["Soil_Pebbles",             Color(0.62, 0.58, 0.55)],
	["Soil_Pebbles_Frozen",      Color(0.68, 0.72, 0.78)],
	
	# ── CLAY (Soil_Clay*) ────────────────────────────────────────────────────
	["Soil_Clay",                Color(0.75, 0.65, 0.55)],
	["Soil_Clay_Brick",          Color(0.72, 0.45, 0.35)],
	["Soil_Clay_Raw_Brick",      Color(0.68, 0.55, 0.45)],
	["Soil_Clay_Smooth",         Color(0.78, 0.68, 0.58)],
	["Soil_Clay_Ocean",          Color(0.55, 0.70, 0.75)],
	["Soil_Clay_Ocean_Brick",    Color(0.48, 0.65, 0.72)],
	["Soil_Clay_Ocean_Brick_Smooth", Color(0.52, 0.68, 0.75)],
	["Soil_Clay_Beige",          Color(0.85, 0.75, 0.60)],
	["Soil_Clay_Black",          Color(0.35, 0.35, 0.38)],
	["Soil_Clay_Blue",           Color(0.45, 0.55, 0.75)],
	["Soil_Clay_Cyan",           Color(0.40, 0.70, 0.75)],
	["Soil_Clay_Green",          Color(0.45, 0.65, 0.45)],
	["Soil_Clay_Grey",           Color(0.65, 0.65, 0.68)],
	["Soil_Clay_Lime",           Color(0.75, 0.85, 0.55)],
	["Soil_Clay_Orange",         Color(0.85, 0.60, 0.35)],
	["Soil_Clay_Pink",           Color(0.85, 0.65, 0.75)],
	["Soil_Clay_Purple",         Color(0.65, 0.50, 0.75)],
	["Soil_Clay_Red",            Color(0.75, 0.40, 0.35)],
	["Soil_Clay_White",          Color(0.90, 0.88, 0.85)],
	["Soil_Clay_Yellow",         Color(0.88, 0.80, 0.45)],
	
	# ── SNOW & ICE (Soil_Snow*) ──────────────────────────────────────────────
	["Soil_Snow",                Color(0.95, 0.97, 1.00)],
	["Soil_Snow_Brick",          Color(0.92, 0.94, 0.98)],
	["Soil_Ash",                 Color(0.55, 0.52, 0.50)],
	["Soil_Mud",                 Color(0.42, 0.32, 0.22)],
	["Soil_Mud_Dry",             Color(0.52, 0.42, 0.32)],
	["Soil_Hive",                Color(0.88, 0.75, 0.35)],
	["Soil_Hive_Brick",          Color(0.85, 0.72, 0.32)],
	["Soil_Hive_Corrupted",      Color(0.55, 0.40, 0.45)],
	["Soil_Hive_Corrupted_Brick",Color(0.52, 0.38, 0.42)],
	["Soil_Leaves",              Color(0.25, 0.45, 0.20)],
	["Soil_Needles",             Color(0.30, 0.50, 0.25)],
	["Soil_Roots_Poisoned",      Color(0.45, 0.35, 0.30)],
	["Soil_Seaweed_Block",       Color(0.25, 0.55, 0.35, 0.85)],
	["Soil_Pathway",             Color(0.65, 0.58, 0.48)],
	
	# ── WOOD PLANKS (Wood_*_Planks) ──────────────────────────────────────────
	["Wood_Oak_Planks",          Color(0.62, 0.42, 0.22)],
	["Wood_Birch_Planks",        Color(0.78, 0.68, 0.48)],
	["Wood_Pine_Planks",         Color(0.58, 0.40, 0.22)],
	["Wood_Darkwood_Planks",     Color(0.42, 0.28, 0.18)],
	["Wood_Redwood_Planks",      Color(0.68, 0.38, 0.28)],
	["Wood_Goldenwood_Planks",   Color(0.85, 0.70, 0.35)],
	["Wood_Greenwood_Planks",    Color(0.55, 0.65, 0.40)],
	["Wood_Hardwood_Planks",     Color(0.58, 0.38, 0.25)],
	["Wood_Lightwood_Planks",    Color(0.78, 0.68, 0.55)],
	["Wood_Softwood_Planks",     Color(0.72, 0.58, 0.42)],
	["Wood_Tropicalwood_Planks", Color(0.65, 0.48, 0.32)],
	["Wood_Drywood_Planks",      Color(0.68, 0.52, 0.35)],
	["Wood_Blackwood_Planks",    Color(0.38, 0.28, 0.22)],
	["Wood_Deadwood_Planks",     Color(0.55, 0.42, 0.32)],
	["Wood_Amber_Planks",        Color(0.75, 0.55, 0.25)],
	["Wood_Ash_Planks",          Color(0.65, 0.55, 0.45)],
	["Wood_Aspen_Planks",        Color(0.75, 0.65, 0.50)],
	["Wood_Azure_Planks",        Color(0.55, 0.65, 0.80)],
	["Wood_Bamboo_Planks",       Color(0.72, 0.68, 0.40)],
	["Wood_Banyan_Planks",       Color(0.58, 0.45, 0.32)],
	["Wood_Beech_Planks",        Color(0.70, 0.58, 0.42)],
	["Wood_Bottletree_Planks",   Color(0.65, 0.52, 0.38)],
	["Wood_Burnt_Planks",        Color(0.35, 0.28, 0.25)],
	["Wood_Camphor_Planks",      Color(0.62, 0.48, 0.35)],
	["Wood_Cedar_Planks",        Color(0.58, 0.42, 0.28)],
	["Wood_Crystal_Planks",      Color(0.75, 0.85, 0.95, 0.70)],
	["Wood_Fig_Blue_Planks",     Color(0.50, 0.58, 0.70)],
	["Wood_Fir_Planks",          Color(0.65, 0.52, 0.38)],
	["Wood_Fire_Planks",         Color(0.75, 0.45, 0.30)],
	["Wood_Gumboab_Planks",      Color(0.62, 0.48, 0.35)],
	["Wood_Ice_Planks",          Color(0.80, 0.90, 0.95, 0.75)],
	["Wood_Jungle_Planks",       Color(0.55, 0.45, 0.30)],
	["Wood_Maple_Planks",        Color(0.68, 0.48, 0.32)],
	["Wood_Palm_Planks",         Color(0.75, 0.62, 0.40)],
	["Wood_Palo_Planks",         Color(0.65, 0.52, 0.38)],
	["Wood_Petrified_Planks",    Color(0.58, 0.48, 0.42)],
	["Wood_Poisoned_Planks",     Color(0.48, 0.55, 0.40)],
	["Wood_Sallow_Planks",       Color(0.68, 0.58, 0.45)],
	["Wood_Spiral_Planks",       Color(0.62, 0.52, 0.42)],
	["Wood_Stormbark_Planks",    Color(0.52, 0.45, 0.40)],
	["Wood_Windwillow_Planks",   Color(0.70, 0.65, 0.50)],
	["Wood_Wisteria_Wild_Planks",Color(0.65, 0.55, 0.60)],
	
	# ── WOOD BEAMS & DECORATIVE ──────────────────────────────────────────────
	["Wood_Oak_Beam",            Color(0.58, 0.38, 0.20)],
	["Wood_Birch_Beam",          Color(0.72, 0.62, 0.42)],
	["Wood_Pine_Beam",           Color(0.52, 0.35, 0.18)],
	["Wood_Darkwood_Beam",       Color(0.38, 0.25, 0.15)],
	["Wood_Redwood_Beam",        Color(0.62, 0.35, 0.25)],
	["Wood_Goldenwood_Beam",     Color(0.80, 0.65, 0.30)],
	["Wood_Greenwood_Beam",      Color(0.50, 0.60, 0.35)],
	["Wood_Hardwood_Beam",       Color(0.52, 0.35, 0.22)],
	["Wood_Lightwood_Beam",      Color(0.72, 0.62, 0.50)],
	["Wood_Softwood_Beam",       Color(0.68, 0.52, 0.38)],
	["Wood_Tropicalwood_Beam",   Color(0.60, 0.45, 0.28)],
	["Wood_Drywood_Beam",        Color(0.62, 0.48, 0.32)],
	["Wood_Blackwood_Beam",      Color(0.35, 0.25, 0.20)],
	["Wood_Deadwood_Beam",       Color(0.50, 0.38, 0.28)],
	["Wood_Oak_Decorative",      Color(0.65, 0.45, 0.25)],
	["Wood_Darkwood_Decorative", Color(0.45, 0.32, 0.22)],
	["Wood_Redwood_Decorative",  Color(0.70, 0.42, 0.32)],
	["Wood_Goldenwood_Decorative", Color(0.85, 0.68, 0.35)],
	["Wood_Greenwood_Decorative", Color(0.58, 0.68, 0.42)],
	["Wood_Hardwood_Decorative", Color(0.55, 0.40, 0.28)],
	["Wood_Lightwood_Decorative", Color(0.75, 0.65, 0.52)],
	["Wood_Softwood_Decorative", Color(0.70, 0.55, 0.40)],
	["Wood_Tropicalwood_Decorative", Color(0.62, 0.48, 0.32)],
	["Wood_Drywood_Decorative",  Color(0.65, 0.50, 0.35)],
	["Wood_Blackwood_Decorative", Color(0.40, 0.30, 0.25)],
	["Wood_Deadwood_Decorative", Color(0.52, 0.42, 0.32)],
	["Wood_Oak_Ornate",          Color(0.68, 0.48, 0.28)],
	["Wood_Darkwood_Ornate",     Color(0.48, 0.35, 0.25)],
	["Wood_Redwood_Ornate",      Color(0.72, 0.45, 0.35)],
	["Wood_Goldenwood_Ornate",   Color(0.88, 0.72, 0.38)],
	["Wood_Greenwood_Ornate",    Color(0.60, 0.70, 0.45)],
	["Wood_Hardwood_Ornate",     Color(0.58, 0.42, 0.30)],
	["Wood_Lightwood_Ornate",    Color(0.78, 0.68, 0.55)],
	["Wood_Softwood_Ornate",     Color(0.72, 0.58, 0.42)],
	["Wood_Tropicalwood_Ornate", Color(0.65, 0.50, 0.35)],
	["Wood_Drywood_Ornate",      Color(0.68, 0.52, 0.38)],
	["Wood_Blackwood_Ornate",    Color(0.42, 0.32, 0.28)],
	["Wood_Deadwood_Ornate",     Color(0.55, 0.45, 0.35)],
	
	# ── GLASS & TRANSPARENT ──────────────────────────────────────────────────
	["Glass_Clear",              Color(0.85, 0.92, 0.98, 0.35)],
	["Glass_Stained",            Color(0.75, 0.85, 0.95, 0.45)],
	["Glass_Blue",               Color(0.45, 0.60, 0.85, 0.50)],
	["Glass_Red",                Color(0.85, 0.40, 0.40, 0.50)],
	["Glass_Green",              Color(0.40, 0.75, 0.45, 0.50)],
	["Glass_Yellow",             Color(0.90, 0.85, 0.40, 0.50)],
	["Glass_Purple",             Color(0.70, 0.45, 0.85, 0.50)],
	["Glass_Orange",             Color(0.90, 0.60, 0.35, 0.50)],
	
	# ── METAL & ORE ──────────────────────────────────────────────────────────
	["Metal_Iron",               Color(0.72, 0.74, 0.78)],
	["Metal_Gold",               Color(0.95, 0.80, 0.20)],
	["Metal_Copper",             Color(0.78, 0.52, 0.32)],
	["Metal_Bronze",             Color(0.80, 0.60, 0.35)],
	["Metal_Silver",             Color(0.85, 0.85, 0.90)],
	["Metal_Steel",              Color(0.65, 0.68, 0.72)],
	["Metal_Cobalt",             Color(0.40, 0.55, 0.75)],
	["Metal_Mithril",            Color(0.60, 0.85, 0.90)],
	["Metal_Adamantite",         Color(0.55, 0.45, 0.65)],
	["Metal_Onyxium",            Color(0.45, 0.40, 0.50)],
	["Metal_Thorium",            Color(0.55, 0.65, 0.55)],
	["Metal_Scrap",              Color(0.58, 0.55, 0.52)],
	["Ore_Iron",                 Color(0.68, 0.55, 0.48)],
	["Ore_Gold",                 Color(0.85, 0.70, 0.35)],
	["Ore_Copper",               Color(0.72, 0.48, 0.35)],
	["Ore_Cobalt",               Color(0.45, 0.55, 0.70)],
	["Ore_Mithril",              Color(0.55, 0.75, 0.85)],
	["Ore_Adamantite",           Color(0.50, 0.40, 0.60)],
	["Ore_Onyxium",              Color(0.42, 0.38, 0.48)],
	["Ore_Thorium",              Color(0.50, 0.60, 0.50)],
	
	# ── SPECIAL & DECORATIVE ─────────────────────────────────────────────────
	["Water",                    Color(0.20, 0.50, 0.90, 0.65)],
	["Lava",                     Color(0.95, 0.40, 0.10, 0.80)],
	["Fire",                     Color(0.95, 0.50, 0.15, 0.85)],
	["Ice_Solid",                Color(0.75, 0.88, 0.95, 0.70)],
	["Frost",                    Color(0.82, 0.92, 0.98, 0.75)],
	["Crystal",                  Color(0.85, 0.75, 0.95, 0.65)],
	["Gem",                      Color(0.75, 0.85, 0.95, 0.70)],
	["Lamp",                     Color(0.95, 0.88, 0.50)],
	["Lantern",                  Color(0.92, 0.82, 0.45)],
	["Torch",                    Color(0.90, 0.75, 0.35)],
	["Light",                    Color(0.98, 0.95, 0.85)],
	["Glow",                     Color(0.85, 0.95, 0.85, 0.70)],
	["Chest",                    Color(0.75, 0.60, 0.30)],
	["Barrel",                   Color(0.65, 0.45, 0.25)],
	["Crate",                    Color(0.58, 0.42, 0.22)],
	["Bookshelf",                Color(0.55, 0.38, 0.28)],
	["Fabric",                   Color(0.80, 0.50, 0.60)],
	["Cloth",                    Color(0.78, 0.48, 0.58)],
	["Carpet",                   Color(0.85, 0.55, 0.65)],
	["Wool",                     Color(0.88, 0.60, 0.70)],
	["Concrete",                 Color(0.70, 0.70, 0.75)],
	["Tile",                     Color(0.75, 0.72, 0.68)],
	["Ceramic",                  Color(0.82, 0.70, 0.60)],
	["Terracotta",               Color(0.78, 0.52, 0.38)],
	["Adobe",                    Color(0.85, 0.65, 0.48)],
	["Brick_Red",                Color(0.72, 0.38, 0.28)],
	["Brick_Dark",               Color(0.55, 0.35, 0.28)],
	["Tile_Mosaic",              Color(0.75, 0.65, 0.55)],
	
	# ── LEAVES & FOLIAGE ─────────────────────────────────────────────────────
	["Leaf_Oak",                 Color(0.22, 0.55, 0.18, 0.85)],
	["Leaf_Birch",               Color(0.28, 0.62, 0.22, 0.85)],
	["Leaf_Pine",                Color(0.18, 0.45, 0.15, 0.85)],
	["Leaf_Fir",                 Color(0.15, 0.40, 0.12, 0.85)],
	["Leaf_Maple",               Color(0.35, 0.60, 0.25, 0.85)],
	["Leaf_Jungle",              Color(0.25, 0.55, 0.20, 0.85)],
	["Leaf_Palm",                Color(0.30, 0.58, 0.25, 0.85)],
	["Leaf_Azure",               Color(0.35, 0.55, 0.65, 0.80)],
	["Leaf_Crystal",             Color(0.55, 0.75, 0.85, 0.70)],
	["Leaf_Ice",                 Color(0.65, 0.85, 0.95, 0.70)],
	["Leaf_Fire",                Color(0.75, 0.45, 0.25, 0.80)],
	["Leaf_Poisoned",            Color(0.45, 0.55, 0.35, 0.80)],
	["Leaf_Burnt",               Color(0.35, 0.30, 0.25, 0.80)],
	["Leaf_Dry",                 Color(0.55, 0.50, 0.30, 0.80)],
	["Foliage",                  Color(0.25, 0.58, 0.20, 0.80)],
	["Flower",                   Color(0.95, 0.60, 0.75)],
	["Plant",                    Color(0.30, 0.60, 0.25)],
	["Vine",                     Color(0.28, 0.55, 0.22)],
	["Crop",                     Color(0.45, 0.65, 0.25)],
	["Hay",                      Color(0.88, 0.75, 0.35)],
	["Straw",                    Color(0.85, 0.72, 0.32)],
	
	# ── VILLAGE WALLS ────────────────────────────────────────────────────────
	["Wood_Village_Wall",        Color(0.65, 0.52, 0.38)],
	["Wood_Village_Wall_Ocean",  Color(0.45, 0.65, 0.75)],
	["Wood_Village_Wall_Black",  Color(0.35, 0.35, 0.38)],
	["Wood_Village_Wall_Blue",   Color(0.45, 0.55, 0.75)],
	["Wood_Village_Wall_Cyan",   Color(0.40, 0.70, 0.75)],
	["Wood_Village_Wall_Green",  Color(0.45, 0.65, 0.45)],
	["Wood_Village_Wall_Grey",   Color(0.65, 0.65, 0.68)],
	["Wood_Village_Wall_GreyDark", Color(0.48, 0.48, 0.52)],
	["Wood_Village_Wall_Lime",   Color(0.75, 0.85, 0.55)],
	["Wood_Village_Wall_Orange", Color(0.85, 0.60, 0.35)],
	["Wood_Village_Wall_Pink",   Color(0.85, 0.65, 0.75)],
	["Wood_Village_Wall_Purple", Color(0.65, 0.50, 0.75)],
	["Wood_Village_Wall_Red",    Color(0.75, 0.40, 0.35)],
	["Wood_Village_Wall_RedDark",Color(0.65, 0.35, 0.30)],
	["Wood_Village_Wall_White",  Color(0.90, 0.88, 0.85)],
	["Wood_Village_Wall_Yellow", Color(0.88, 0.80, 0.45)],
]


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	create_group(DEFAULT_GROUP)


# ── Group management ──────────────────────────────────────────────────────────

func create_group(gname: String) -> GroupData:
	if _groups.has(gname):
		return _groups[gname]
	var gd := GroupData.new()
	gd.name = gname
	gd.color = GROUP_COLORS[_color_index % GROUP_COLORS.size()]
	_color_index += 1
	gd.node = Node3D.new()
	gd.node.name = gname
	add_child(gd.node)
	_groups[gname] = gd
	return gd


func remove_group(gname: String) -> void:
	if gname == DEFAULT_GROUP:
		push_warning("[BR] Cannot remove the Default group.")
		return
	if not _groups.has(gname):
		return

	var gd: GroupData = _groups[gname]

	# Free the Node3D (and all its MultiMeshInstance3D children) and discard
	# all block data — blocks are NOT migrated to another group.
	gd.node.queue_free()
	_groups.erase(gname)

	_emit_changed()

func set_group_visible(gname: String, visi: bool) -> void:
	if _groups.has(gname):
		(_groups[gname] as GroupData).node.visible = visi


func is_group_visible(gname: String) -> bool:
	if _groups.has(gname):
		return (_groups[gname] as GroupData).node.visible
	return true


func rename_group_label(gname: String, label: String) -> void:
	if _groups.has(gname):
		(_groups[gname] as GroupData).label = label


func get_group_names() -> Array:
	return _groups.keys()


func get_group_data(gname: String) -> GroupData:
	return _groups.get(gname, null)


func show_all_groups() -> void:
	for gn in _groups:
		(_groups[gn] as GroupData).node.visible = true


func hide_all_groups() -> void:
	for gn in _groups:
		(_groups[gn] as GroupData).node.visible = false


# ── Block CRUD ────────────────────────────────────────────────────────────────

func add_block(pos: Vector3i, bname: String, group: String = DEFAULT_GROUP) -> void:
	if not _groups.has(group):
		create_group(group)
	_groups[group].blocks[_key(pos.x, pos.y, pos.z)] = bname


func remove_block(pos: Vector3i) -> void:
	var k := _key(pos.x, pos.y, pos.z)
	for gn in _groups:
		if (_groups[gn] as GroupData).blocks.has(k):
			(_groups[gn] as GroupData).blocks.erase(k)
			return


func has_block(pos: Vector3i) -> bool:
	var k := _key(pos.x, pos.y, pos.z)
	for gn in _groups:
		if (_groups[gn] as GroupData).blocks.has(k):
			return true
	return false


func get_block_at(pos: Vector3i) -> String:
	var k := _key(pos.x, pos.y, pos.z)
	for gn in _groups:
		if (_groups[gn] as GroupData).blocks.has(k):
			return (_groups[gn] as GroupData).blocks[k]
	return ""


func get_all_blocks() -> Dictionary:
	var merged: Dictionary = {}
	for gn in _groups:
		for k in (_groups[gn] as GroupData).blocks:
			merged[k] = (_groups[gn] as GroupData).blocks[k]
	return merged


func get_block_count() -> int:
	var n := 0
	for gn in _groups:
		n += (_groups[gn] as GroupData).blocks.size()
	return n


func load_from_prefab(data: Dictionary) -> void:
	clear_all()
	if data.has("blocks"):
		for b in data["blocks"]:
			add_block(
				Vector3i(b.get("x", 0), b.get("y", 0), b.get("z", 0)),
				b.get("name", "Unknown"),
				DEFAULT_GROUP
			)
	rebuild_all()


func clear_all() -> void:
	for gn in _groups.keys():
		(_groups[gn] as GroupData).node.queue_free()
	_groups.clear()
	_color_index = 0
	create_group(DEFAULT_GROUP)


# ── Rebuild geometry ──────────────────────────────────────────────────────────

func rebuild_all() -> void:
	for gn in _groups:
		rebuild_group(gn)
	_emit_changed()


func rebuild_group(gname: String) -> void:
	if not _groups.has(gname):
		return
	var gd: GroupData = _groups[gname]
	for c in gd.node.get_children():
		c.queue_free()

	if gd.blocks.is_empty():
		return

	var batches: Dictionary = {}
	for k in gd.blocks:
		var bname: String = gd.blocks[k]
		var color := _get_color(bname)
		var ckey := "%s|%s|%s|%s" % [color.r, color.g, color.b, color.a]
		if not batches.has(ckey):
			batches[ckey] = {"color": color, "transforms": []}
		var p = k.split(",")
		var t := Transform3D()
		t.origin = Vector3(int(p[0]), int(p[1]), int(p[2])) * BLOCK_SIZE
		batches[ckey]["transforms"].append(t)

	for ckey in batches:
		var col: Color = batches[ckey]["color"]
		var tfs: Array = batches[ckey]["transforms"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.75
		mat.metallic = 0.05
		if col.a < 1.0:
			mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var box := BoxMesh.new()
		box.size = Vector3.ONE * (BLOCK_SIZE * 0.97)
		box.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		mm.instance_count = tfs.size()
		for i in tfs.size():
			mm.set_instance_transform(i, tfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		gd.node.add_child(mmi)


func _emit_changed() -> void:
	var total := 0
	var types: Dictionary = {}
	for gn in _groups:
		for k in (_groups[gn] as GroupData).blocks:
			total += 1
			types[(_groups[gn] as GroupData).blocks[k]] = true
	blocks_changed.emit(total, types.size())


func get_bounds() -> Dictionary:
	var all := get_all_blocks()
	if all.is_empty():
		return {}
	var mnx := INF
	var mny := INF
	var mnz := INF
	var mxx := -INF
	var mxy := -INF
	var mxz := -INF
	for k in all:
		var p = k.split(",")
		var x := float(p[0])
		var y := float(p[1])
		var z := float(p[2])
		if x < mnx: mnx = x
		if y < mny: mny = y
		if z < mnz: mnz = z
		if x > mxx: mxx = x
		if y > mxy: mxy = y
		if z > mxz: mxz = z
	var bmin := Vector3(mnx, mny, mnz)
	var bmax := Vector3(mxx, mxy, mxz)
	var bsize := bmax - bmin + Vector3.ONE
	return {"min": bmin, "max": bmax, "size": bsize, "center": bmin + bsize * 0.5}


func get_center() -> Vector3:
	return get_bounds().get("center", Vector3.ZERO)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]


func _get_color(bname: String) -> Color:
	var low := bname.to_lower()
	for e in _CATEGORIES:
		if low.contains(e[0].to_lower()):
			return e[1]
	var h := bname.hash()
	return Color(
		0.35 + (h & 0xFF) / 510.0,
		0.35 + ((h >> 8) & 0xFF) / 510.0,
		0.35 + ((h >> 16) & 0xFF) / 510.0
	)
