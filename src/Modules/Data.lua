-- Last Epoch Planner
--
-- Module: Data
-- Contains static data used by other modules.
--

LoadModule("Data/Global")

local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local t_insert = table.insert
local t_concat = table.concat

local function makeSkillMod(modName, modType, modVal, flags, keywordFlags, ...)
	return {
		name = modName,
		type = modType,
		value = modVal,
		flags = flags or 0,
		keywordFlags = keywordFlags or 0,
		...
	}
end
local function makeFlagMod(modName, ...)
	return makeSkillMod(modName, "FLAG", true, 0, 0, ...)
end
local function makeSkillDataMod(dataKey, dataValue, ...)
	return makeSkillMod("SkillData", "LIST", { key = dataKey, value = dataValue }, 0, 0, ...)
end

-----------------
-- Common Data --
-----------------

-- These are semi-structured
----------------------------------------
-- Everything not in a later category
-- Item mods & jewel data
-- Boss data, skills and minions
-- Remaining Item Data and uniques
----------------------------------------

data = { }

data.powerStatList = {
	{ stat = nil, label = "Offence/Defence", combinedOffDef = true, ignoreForItems = true },
	{ stat = nil, label = "Name", itemField = "Name", ignoreForNodes = true, reverseSort = true, transform = function(value)
		return value:gsub("^The ", "")
	end },
	{ stat = "FullDPS", label = "Full DPS" },
	{ stat = "CombinedDPS", label = "Combined DPS" },
	{ stat = "TotalDPS", label = "Hit DPS" },
	{ stat = "AverageDamage", label = "Average Hit" },
	{ stat = "Speed", label = "Attack/Cast Speed" },
	{ stat = "TotalDot", label = "DoT DPS" },
	{ stat = "Life", label = "Health" },
	{ stat = "LifeRegen", label = "Health regen" },
	{ stat = "LifeLeechRate", label = "Health leech" },
	{ stat = "Armour", label = "Armor" },
	{ stat = "Evasion", label = "Evasion" },
	{ stat = "Mana", label = "Mana" },
	{ stat = "ManaRegen", label = "Mana regen" },
	{ stat = "ManaLeechRate", label = "Mana leech" },
	{ stat = "Ward", label = "Ward" }
}

for i, attribute in ipairs(Attributes) do
	t_insert(data.powerStatList, { stat=attribute, label=AttributesColored[i] })
end

tableInsertAll(data.powerStatList, {
	{ stat = "TotalAttr", label = "Total Attributes" },
	{ stat = "TotalEHP", label = "Effective Hit Pool" },
	{ stat = "SecondMinimalMaximumHitTaken", label = "Eff. Maximum Hit Taken" }
})

for i, damageType in ipairs(DamageTypes) do
	t_insert(data.powerStatList, { stat=damageType .. "TakenHit", label=DamageTypeColors[i] .. "Taken " .. damageType .. " dmg", transform=function(value) return -value end })
end

tableInsertAll(data.powerStatList,{
	{ stat="CritChance", label="Crit Chance" },
	{ stat="CritMultiplier", label="Crit Multiplier" },
	{ stat="EffectiveMovementSpeedMod", label="Move speed" },
	{ stat="BlockChance", label="Block Chance" },
})

data.misc = { -- magic numbers
	AccuracyPerDexBase = 2,
	LowPoolThreshold = 0.5,
	TemporalChainsEffectCap = 75,
	BuffExpirationSlowCap = 0.25,
	DamageReductionCap = 90,
	ResistFloor = -200,
	MaxResistCap = 90,
	EvadeChanceCap = 95,
	DodgeChanceCap = 75,
	SuppressionChanceCap = 100,
	SuppressionEffect = 50,
	AvoidChanceCap = 75,
	EnergyShieldRechargeBase = 0.33,
	EnergyShieldRechargeDelay = 2,
	WardRechargeDelay = 4,
	Transfiguration = 0.3,
	EnemyMaxResist = 75,
	LeechRateBase = 0.02,
	DotDpsCap = 35791394, -- (2 ^ 31 - 1) / 60 (int max / 60 seconds)
	BleedPercentBase = 70,
	BleedDurationBase = 5,
	PoisonPercentBase = 0.30,
	PoisonDurationBase = 2,
	IgnitePercentBase = 0.9,
	IgniteDurationBase = 4,
	ImpaleStoredDamageBase = 0.1,
	TrapTriggerRadiusBase = 10,
	MineDetonationRadiusBase = 60,
	MineAuraRadiusBase = 35,
	BrandAttachmentRangeBase = 30,
	ProjectileDistanceCap = 150,
	MinStunChanceNeeded = 20,
	StunBaseMult = 200,
	StunBaseDuration = 0.35,
	StunNotMeleeDamageMult = 0.75,
	MaxEnemyLevel = 100,
	maxExperiencePenaltyFreeAreaLevel = 70,
	experiencePenaltyMultiplier = 0.06,
	-- Expected values to calculate EHP
	stdBossDPSMult = 4 / 4.40,
	pinnacleBossDPSMult = 8 / 4.40,
	pinnacleBossPen = 15 / 5,
	uberBossDPSMult = 10 / 4.25,
	uberBossPen = 40 / 5,
	-- ehp helper function magic numbers
	ehpCalcSpeedUp = 8,
	-- max damage can be increased for more accuracy
	ehpCalcMaxDamage = 100000000,
	-- max iterations can be increased for more accuracy this should be perfectly accurate unless it runs out of iterations and so high eHP values will be underestimated.
	ehpCalcMaxIterationsToCalc = 50,
	-- maximum increase for stat weights, only used in trader for now.
	maxStatIncrease = 2, -- 100% increased
	-- PvP scaling used for hogm
	PvpElemental1 = 0.55,
	PvpElemental2 = 150,
	PvpNonElemental1 = 0.57,
	PvpNonElemental2 = 90,
}

data.skillColorMap = { colorCodes.STRENGTH, colorCodes.DEXTERITY, colorCodes.INTELLIGENCE, colorCodes.NORMAL }

-- TODO
data.ailmentTypeList = { "Ignite" }
data.elementalAilmentTypeList = { "Ignite" }
data.nonDamagingAilmentTypeList = {}
data.nonElementalAilmentTypeList = {}

data.nonDamagingAilment = {
	["Chill"] = { associatedType = "Cold", alt = false, default = 10, min = 5, max = 30, precision = 0, duration = 2 },
	["Freeze"] = { associatedType = "Cold", alt = false, default = nil, min = 0.3, max = 3, precision = 2, duration = nil },
	["Shock"] = { associatedType = "Lightning", alt = false, default = 15, min = 5, max = 50, precision = 0, duration = 2 },
	["Scorch"] = { associatedType = "Fire", alt = true, default = 10, min = 0, max = 30, precision = 0, duration = 4 },
	["Brittle"] = { associatedType = "Cold", alt = true, default = 2, min = 0, max = 6, precision = 2, duration = 4 },
	["Sap"] = { associatedType = "Lightning", alt = true, default = 6, min = 0, max = 20, precision = 0, duration = 4 },
}

-- Used in ModStoreClass:ScaleAddMod(...) to identify high precision modifiers
data.defaultHighPrecision = 1
data.highPrecisionMods = {
	["CritChance"] = {
		["BASE"] = 2,
	},
	["SelfCritChance"] = {
		["BASE"] = 2,
	},
	["LifeRegenPercent"] = {
		["BASE"] = 2,
	},
	["ManaRegenPercent"] = {
		["BASE"] = 2,
	},
	["EnergyShieldRegenPercent"] = {
		["BASE"] = 2,
	},
	["LifeRegen"] = {
		["BASE"] = 1,
	},
	["ManaRegen"] = {
		["BASE"] = 1,
	},
	["EnergyShieldRegen"] = {
		["BASE"] = 1,
	},
	["LifeDegenPercent"] = {
		["BASE"] = 2,
	},
	["ManaDegenPercent"] = {
		["BASE"] = 2,
	},
	["EnergyShieldDegenPercent"] = {
		["BASE"] = 2,
	},
	["LifeDegen"] = {
		["BASE"] = 1,
	},
	["ManaDegen"] = {
		["BASE"] = 1,
	},
	["EnergyShieldDegen"] = {
		["BASE"] = 1,
	},
	["DamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["PhysicalDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["ElementalDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["FireDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["ColdDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["LightningDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["ChaosDamageLifeLeech"] = {
		["BASE"] = 2,
	},
	["DamageManaLeech"] = {
		["BASE"] = 2,
	},
	["PhysicalDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["ElementalDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["FireDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["ColdDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["LightningDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["ChaosDamageManaLeech"] = {
		["BASE"] = 2,
	},
	["DamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["PhysicalDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["ElementalDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["FireDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["ColdDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["LightningDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["ChaosDamageEnergyShieldLeech"] = {
		["BASE"] = 2,
	},
	["SupportManaMultiplier"] = {
		["MORE"] = 4,
	}
}

data.weaponTypeInfo = {
	["None"] = { oneHand = true, melee = true, flag = "Unarmed" },
	["Bow"] = { oneHand = false, melee = false, flag = "Bow" },
	["Dagger"] = { oneHand = true, melee = true, flag = "Dagger" },
	["Two-Handed Staff"] = { oneHand = false, melee = true, flag = "Staff" },
	["Wand"] = { oneHand = true, melee = false, flag = "Wand" },
	["One-Handed Axe"] = { oneHand = true, melee = true, flag = "Axe" },
	["One-Handed Mace"] = { oneHand = true, melee = true, flag = "Mace" },
	["One-Handed Sword"] = { oneHand = true, melee = true, flag = "Sword" },
	["Sceptre"] = { oneHand = true, melee = true, flag = "Mace", label = "Sceptre" },
	["Two-Handed Axe"] = { oneHand = false, melee = true, flag = "Axe" },
	["Two-Handed Mace"] = { oneHand = false, melee = true, flag = "Mace" },
	["Two-Handed Sword"] = { oneHand = false, melee = true, flag = "Sword" },
	["Two-Handed Spear"] = { oneHand = false, melee = true, flag = "Spear" },
}
data.unarmedWeaponData = {
	[0] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 6 }, -- Scion
	[1] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 8 }, -- Marauder
	[2] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 5 }, -- Ranger
	[3] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 5 }, -- Witch
	[4] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 6 }, -- Duelist
	[5] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 6 }, -- Templar
	[6] = { type = "None", AttackRate = 1.2, CritChance = 0, PhysicalMin = 2, PhysicalMax = 5 }, -- Shadow
}


data.enchantmentSource = {
	{ name = "ENKINDLING", label = "Enkindling Orb" },
	{ name = "INSTILLING", label = "Instilling Orb" },
	{ name = "HEIST", label = "Heist" },
	{ name = "HARVEST", label = "Harvest" },
	{ name = "DEDICATION", label = "Dedication to the Goddess" },
	{ name = "ENDGAME", label = "Eternal Labyrinth" },
	{ name = "MERCILESS", label = "Merciless Labyrinth" },
	{ name = "CRUEL", label = "Cruel Labyrinth" },
	{ name = "NORMAL", label = "Normal Labyrinth" },
}

-- Misc data tables
LoadModule("Data/Misc", data)

-- Stat descriptions
data.describeStats = LoadModule("Modules/StatDescriber")

-- Load item modifiers
data.itemMods = {
	Item = readJsonFile("Data/ModItem.json"),
}

for _,mod in pairs(data.itemMods.Item) do
	if not mod.affix then
		mod.affix = ""
	end
end

data.costs = LoadModule("Data/Costs")
do
	local map = { }
	for i, value in ipairs(data.costs) do
		map[value.Resource] = i
	end
	setmetatable(data.costs, { __index = function(t, k) return t[map[k]] end })
end

-- Manually seeded modifier tag against item slot table for Mastery Item Condition based modifiers
-- Data is informed by getTagBasedModifiers() located in Item.lua
data.itemTagSpecial = {
	["life"] = {
		["body armour"] = {
			-- Keystone
			"Blood Magic",
			"Eternal Youth",
			"Ghost Reaver",
			"Mind Over Matter",
			"The Agnostic",
			"Vaal Pact",
			"Zealot's Oath",
			-- Special Cases
			"^Cannot Leech$",
		},
	},
	["evasion"] = {
		["ring"] = {
			-- Delve
			"chance to Evade",
			-- Unique
			"Cannot Evade",
		},
	},
}
data.itemTagSpecialExclusionPattern = {
	["life"] = {
		["body armour"] = {
			"increased Damage while Leeching Life",
			"Life as Physical Damage",
			"Life as Extra Maximum Energy Shield",
			"maximum Life as Fire Damage",
			"when on Full Life",
			"Enemy's life",
			"Life From You",
			"^Socketed Gems are Supported by Level"
		},
		["boots"] = {
			"Enemy's Life", -- Legacy of Fury
		},
		["belt"] = {
			"Life as Extra Maximum Energy Shield", -- Soul Tether
		},
		["helmet"] = {
			"Recouped as Life", -- Flame Exarch
			"Life when you Suppress", -- Elevore
		},
	},
	["evasion"] = {
		["ring"] = {
		},
	},
}

-- Load bosses
do 
	data.bosses = { }
	LoadModule("Data/Bosses", data.bosses)
	
	local count, uberCount = 0, 0
	local armourTotal, evasionTotal = 0, 0
	local uberArmourTotal, uberEvasionTotal = 0, 0

	for _, boss in pairs(data.bosses) do
		if boss.isUber then
			uberCount = uberCount + 1
			uberArmourTotal = uberArmourTotal + boss.armourMult
			uberEvasionTotal = uberEvasionTotal + boss.evasionMult
		end
		count = count + 1
		armourTotal = armourTotal + boss.armourMult
		evasionTotal = evasionTotal + boss.evasionMult
	end

	data.bossStats = {
		PinnacleArmourMean = 100 + armourTotal / count,
		PinnacleEvasionMean = 100 + evasionTotal / count,
		UberArmourMean = 100 + uberArmourTotal / uberCount,
		UberEvasionMean = 100 + uberEvasionTotal / uberCount
	}

	data.bossSkills, data.bossSkillsList = LoadModule("Data/BossSkills")

	data.enemyIsBossTooltip = [[Bosses' damage is monster damage scaled to an average damage of their attacks
This is divided by 4.40 to represent 4 damage types + some (40% as much) ^xD02090chaos
^7Fill in the exact damage numbers if more precision is needed

Bosses' armour and evasion multiplier are calculated using the average of the boss type

Standard Boss adds the following modifiers:
	+40% to enemy Elemental Resistances
	+25% to enemy ^xD02090Chaos Resistance
	^7]]..tostring(m_floor(data.misc.stdBossDPSMult * 100))..[[% of monster Damage of each type
	]]..tostring(m_floor(data.misc.stdBossDPSMult * 4.4 * 100))..[[% of monster Damage total

Guardian / Pinnacle Boss adds the following modifiers:
	+50% to enemy Elemental Resistances
	+30% to enemy ^xD02090Chaos Resistance
	^7]]..tostring(m_floor(data.bossStats.PinnacleArmourMean))..[[% of monster Armour
	]]..tostring(m_floor(data.bossStats.PinnacleEvasionMean))..[[% of monster ^x33FF77Evasion
	^7]]..tostring(m_floor(data.misc.pinnacleBossDPSMult * 100))..[[% of monster Damage of each type
	]]..tostring(m_floor(data.misc.pinnacleBossDPSMult * 4.4 * 100))..[[% of monster Damage total
	]]..tostring(data.misc.pinnacleBossPen)..[[% penetration

Uber Pinnacle Boss adds the following modifiers:
	+50% to enemy Elemental Resistances
	+30% to enemy ^xD02090Chaos Resistance
	^7]]..tostring(m_floor(data.bossStats.UberArmourMean))..[[% of monster Armour
	]]..tostring(m_floor(data.bossStats.UberEvasionMean))..[[% of monster ^x33FF77Evasion
	^770% less to enemy Damage taken
	]]..tostring(m_floor(data.misc.uberBossDPSMult * 100))..[[% of monster Damage of each type
	]]..tostring(m_floor(data.misc.uberBossDPSMult * 4.25 * 100))..[[% of monster Damage total
	]]..tostring(data.misc.uberBossPen)..[[% penetration]]
end

-- Load skills
data.skills = readJsonFile("Data/skills.json")
data.skillStatMap = LoadModule("Data/SkillStatMap", makeSkillMod, makeFlagMod, makeSkillDataMod)

-- Add a default skill
data.skills["Default"] = {
	name = "Default",
	skillTypeTags = 0,
	baseFlags = {},
	stats = {}
}

-- Load minions
data.minions = readJsonFile("Data/minions.json")

-- Item bases
data.itemBases = readJsonFile("Data/Bases/bases.json")
data.LETools_itemBases = readJsonFile("Data/LEToolsImport/bases.json")
data.LETools_affixes = readJsonFile("Data/LEToolsImport/affixes.json")

-- Build lists of item bases, separated by type
data.itemBaseLists = { }
for name, base in pairs(data.itemBases) do
	if not base.hidden then
		local type = base.type
		if base.subType then
			type = type .. ": " .. base.subType
		end
		data.itemBaseLists[type] = data.itemBaseLists[type] or { }
		table.insert(data.itemBaseLists[type], { label = name:gsub(" %(.+%)",""), name = name, base = base })
	end
end
data.itemBaseTypeList = { }
for type, list in pairs(data.itemBaseLists) do
	table.insert(data.itemBaseTypeList, type)
	table.sort(list, function(a, b)
		if a.base.req and b.base.req then
			if a.base.req.level == b.base.req.level then
				return a.name < b.name
			else
				return (a.base.req.level or 1) > (b.base.req.level or 1)
			end
		elseif a.base.req and not b.base.req then
			return true
		elseif b.base.req and not a.base.req then
			return false
		else
			return a.name < b.name
		end
	end)
end
table.sort(data.itemBaseTypeList)

-- Rare templates
data.rares = {}

-- Uniques (loaded after version-specific data because reasons)
data.uniques = readJsonFile("Data/Uniques/uniques.json")
data.uniqueMods = { }
