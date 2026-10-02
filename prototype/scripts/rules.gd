extends RefCounted

const TOTAL_SHOTS = 5
const MAX_GROUPS = 4
const ROUND_SECONDS = 60.0
const SCORE_TARGET = 1800
const HOLD_SECONDS = 0.35
const AMMO_NAMES = {"normal": "普通", "spring": "弹簧"}

# Reads evidence only. No damage, physics, inventory or growth mutations here.
static func evaluate(records: Array, equipment: Array = []) -> Dictionary:
	var c = 0
	var m = 1.0
	var run = 0
	var longest = 0
	var precise = 0
	var aerial = 0
	var relay = false
	var multi = false
	var kills = 0
	var performances: Array = []
	var steps: Array = []
	for shot in records:
		c += shot.get("base", 0)
		if shot.get("valid", false):
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
		if shot.get("destroyed", false):
			kills += 1
			precise += int(shot.get("weak", false))
			aerial += int(shot.get("air", false))
		relay = relay or shot.get("relay", false)
		multi = multi or shot.get("direct_kills", 0) >= 2
	steps.append({"label": "实际命中与弱点", "c": c, "m": m})
	if longest >= 2:
		var add_c = 25 if longest >= 5 else (15 if longest >= 3 else 10)
		var add_m = 2 if longest >= 5 else 1
		c += add_c
		m += add_m
		performances.append("连中 %d 枪" % longest)
	if precise > 0:
		c += 40 if precise >= 3 else 15
		m += 2 if precise >= 3 else 1
		performances.append("精准 %d 次" % precise)
	if aerial > 0:
		c += 35 if aerial >= 2 else 20
		m += 2 if aerial >= 2 else 1
		performances.append("空中特技 %d 次" % aerial)
	if multi:
		c += 25
		m += 1
		performances.append("一枪多响")
	if relay:
		c += 25
		m += 1
		performances.append("准备接力")
	steps.append({"label": "本组成立的表演", "c": c, "m": m})
	for item in equipment:
		match item:
			"paper": c += kills * 8
			"metronome":
				if records.size() == TOTAL_SHOTS and longest == TOTAL_SHOTS:
					m += 4
			"smile":
				if records.size() == TOTAL_SHOTS and records[4].get("destroyed", false) and records[4].get("weak", false):
					m *= 1.5
		steps.append({"label": {"paper": "靶纸卷", "metronome": "节拍器", "smile": "笑脸弹簧"}.get(item, item), "c": c, "m": m})
	return {"c": c, "m": m, "score": int(floor(c * m)), "performances": performances, "steps": steps}

static func growth_gain(records: Array, reason: String) -> int:
	if reason != "early" or records.is_empty() or records.size() >= TOTAL_SHOTS:
		return 0
	for shot in records:
		if shot.get("valid", false):
			return TOTAL_SHOTS - records.size()
	return 0

static func duck_level(energy: int) -> int:
	return mini(3, energy / 3)
