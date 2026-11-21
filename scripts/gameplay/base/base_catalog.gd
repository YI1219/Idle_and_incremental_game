extends RefCounted
## Part-one data for the Sea of Consciousness base: what exists and what it
## turns into what. Numbers are first-pass tuning values; the structure is the
## owner's design lock of 2026-11-21:
## - a spirit spring makes qi all the time;
## - raw qi cultivates poorly, planted into crops it becomes better goods;
## - every stage mixes two inputs in its own ratio ("flour and water");
## - later lines consume earlier products, nothing is rebuilt;
## - conduits carry qi, and their shape can wake a formation.

## Goods. "zh" is the in-game name.
const GOODS: Dictionary = {
	"qi": {"zh": "灵气"},
	"water": {"zh": "清水"},
	"grain": {"zh": "灵谷"},
	"herb": {"zh": "灵草"},
	"ore": {"zh": "灵矿"},
	"ration": {"zh": "灵膳"},
	"pill_heal": {"zh": "回春丹"},
	"pill_fast": {"zh": "辟谷丹"},
	"blade": {"zh": "法剑"},
}

## Recipes. "needs" is one batch of inputs, "seconds" the time one batch takes,
## "staffed" whether the cultivator has to stand there working.
const RECIPES: Dictionary = {
	# Stage one: qi and water into living things. Ratios 3:1, 2:2, 5:1.
	"grain": {"zh": "种灵谷", "needs": {"qi": 3.0, "water": 1.0}, "seconds": 60.0, "makes": {"grain": 4.0}, "staffed": false},
	"herb": {"zh": "种灵草", "needs": {"qi": 2.0, "water": 2.0}, "seconds": 80.0, "makes": {"herb": 3.0}, "staffed": false},
	"ore": {"zh": "育矿苗", "needs": {"qi": 5.0, "water": 1.0}, "seconds": 120.0, "makes": {"ore": 2.0}, "staffed": false},
	# Stage two: earlier products and qi into supplies. Ratios 2:1, 3:2, 2:3, 4:6.
	"ration": {"zh": "炊灵膳", "needs": {"grain": 2.0, "water": 1.0}, "seconds": 10.0, "makes": {"ration": 1.0}, "staffed": true},
	"pill_heal": {"zh": "炼回春丹", "needs": {"herb": 3.0, "qi": 2.0}, "seconds": 20.0, "makes": {"pill_heal": 1.0}, "staffed": true},
	"pill_fast": {"zh": "炼辟谷丹", "needs": {"herb": 2.0, "qi": 3.0}, "seconds": 20.0, "makes": {"pill_fast": 1.0}, "staffed": true},
	"blade": {"zh": "铸法剑", "needs": {"ore": 4.0, "qi": 6.0}, "seconds": 40.0, "makes": {"blade": 1.0}, "staffed": true},
}

## Facilities. "recipes": what can run there. "source": goods it yields by
## itself per second, up to "holds". "prosperity": what it adds to the base.
const FACILITIES: Dictionary = {
	"spirit_spring": {"zh": "灵泉", "source": {"qi": 0.25}, "holds": {"qi": 20.0}, "prosperity": 12, "seat": true},
	"stone_well": {"zh": "石井", "source": {"water": 0.5}, "holds": {"water": 12.0}, "prosperity": 4},
	"qi_urn": {"zh": "储灵瓮", "holds": {"qi": 40.0}, "prosperity": 3, "relay": true},
	"spirit_field": {"zh": "灵田", "recipes": ["grain", "herb"], "prosperity": 5},
	"ore_bed": {"zh": "凝矿台", "recipes": ["ore"], "prosperity": 6},
	"hearth": {"zh": "灶台", "recipes": ["ration"], "prosperity": 4},
	"alchemy_furnace": {"zh": "丹炉", "recipes": ["pill_heal", "pill_fast"], "prosperity": 10},
	"forge_hearth": {"zh": "炼器台", "recipes": ["blade"], "prosperity": 10},
	"qi_dais": {"zh": "聚灵阵台", "holds": {"qi": 10.0}, "prosperity": 8, "seat": true},
	"realm_gate": {"zh": "界门", "prosperity": 15},
	# Decorations add prosperity and a small share of working speed.
	"post_lantern": {"zh": "石灯", "prosperity": 2, "decor": 0.02},
	"rockery": {"zh": "假山", "prosperity": 3, "decor": 0.02},
	"spirit_screen": {"zh": "影壁", "prosperity": 4, "decor": 0.02},
}

## What the first exploration outing asks for.
const EXPEDITION_KIT: Dictionary = {"blade": 1.0, "pill_heal": 2.0, "ration": 3.0}

## Qi a conduit feeds into one facility per second.
const CONDUIT_RATE: float = 0.5
## A facility inside a closed ring of conduit works this much faster.
const FORMATION_SPEED: float = 1.25
## Decorations together add at most this share of working speed.
const DECOR_CAP: float = 0.10
## Input buffers hold this many batches.
const BUFFER_BATCHES: float = 2.0

## The cultivator.
const WALK_SPEED: float = 2.4 # cells per second
const CARRY: float = 4.0 # units per trip
const LOAD_SECONDS: float = 1.5 # picking up or setting down
const FOOD_SECONDS: float = 600.0 # a full belly lasts this long
const DRINK_SECONDS: float = 400.0
const MIN_EFFICIENCY: float = 0.5 # hunger and thirst never drop work below this
const RAW_QI_RATE: float = 0.5 # qi drawn per second while cultivating
const RAW_QI_YIELD: float = 0.4 # cultivation gained per unit of raw qi
const NOURISHED_SECONDS: float = 300.0 # a spirit meal speeds cultivation this long
const NOURISHED_GAIN: float = 1.5
const FASTING_SECONDS: float = 1800.0 # one fasting pill

## The mouse: one unit of work per click, this long between clicks on one thing.
const CLICK_COOLDOWN: float = 0.4
