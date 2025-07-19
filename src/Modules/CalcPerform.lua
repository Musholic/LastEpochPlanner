-- Path of Building
--
-- Module: Calc Perform
-- Manages the offence/defence calculations.
--
local calcs = ...

local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_ceil = math.ceil
local m_floor = math.floor
local m_modf = math.modf
local s_format = string.format
local m_huge = math.huge
local bor = bit.bor
local band = bit.band

-- Merge an instance of a buff, taking the highest value of each modifier
local function mergeBuff(src, destTable, destKey)
	if not destTable[destKey] then
		destTable[destKey] = new("ModList")
	end
	local dest = destTable[destKey]
	for _, mod in ipairs(src) do
		local match = false
		if mod.type ~= "LIST" then
			for index, destMod in ipairs(dest) do
				if modLib.compareModParams(mod, destMod) then
					if type(destMod.value) == "number" and mod.value > destMod.value then
						dest[index] = mod
					end
					match = true
					break
				end
			end
		end
		if not match then
			t_insert(dest, mod)
		end
	end
end

local function doActorLifeMana(actor)
	local modDB = actor.modDB
	local output = actor.output
	local breakdown = actor.breakdown
	local condList = modDB.conditions

	local lowLifePerc = modDB:Sum("BASE", nil, "LowLifePercentage")
	output.LowLifePercentage = 100.0 * (lowLifePerc > 0 and lowLifePerc or data.misc.LowPoolThreshold)
	local fullLifePerc = modDB:Sum("BASE", nil, "FullLifePercentage")
	output.FullLifePercentage = 100.0 * (fullLifePerc > 0 and fullLifePerc or 1.0)

	local base = modDB:Sum("BASE", nil, "Life")
	local inc = modDB:Sum("INC", nil, "Life")
	local more = modDB:More(nil, "Life")
	local conv = modDB:Sum("BASE", nil, "LifeConvertToEnergyShield")
	output.Life = m_max(round(base * (1 + inc/100) * more * (1 - conv/100)), 1)
	if breakdown then
		if inc ~= 0 or more ~= 1 or conv ~= 0 then
			breakdown.Life = { }
			breakdown.Life[1] = s_format("%g ^8(base)", base)
			if inc ~= 0 then
				t_insert(breakdown.Life, s_format("x %.2f ^8(increased/reduced)", 1 + inc/100))
			end
			if more ~= 1 then
				t_insert(breakdown.Life, s_format("x %.2f ^8(more/less)", more))
			end
			if conv ~= 0 then
				t_insert(breakdown.Life, s_format("x %.2f ^8(converted to Energy Shield)", 1 - conv/100))
			end
			t_insert(breakdown.Life, s_format("= %g", output.Life))
		end
	end
	output.Mana = round(calcLib.val(modDB, "Mana"))
	local base = modDB:Sum("BASE", nil, "Mana")
	local inc = modDB:Sum("INC", nil, "Mana")
	local more = modDB:More(nil, "Mana")
	if breakdown then
		if inc ~= 0 or more ~= 1 or manaConv ~= 0 then
			breakdown.Mana = { }
			breakdown.Mana[1] = s_format("%g ^8(base)", base)
			if inc ~= 0 then
				t_insert(breakdown.Mana, s_format("x %.2f ^8(increased/reduced)", 1 + inc/100))
			end
			if more ~= 1 then
				t_insert(breakdown.Mana, s_format("x %.2f ^8(more/less)", more))
			end
			t_insert(breakdown.Mana, s_format("= %g", output.Mana))
		end
	end
	output.LowestOfMaximumLifeAndMaximumMana = m_min(output.Life, output.Mana)
end

-- Calculate attributes, and set conditions
---@param env table
---@param actor table
local function doActorAttribsConditions(env, actor)
	local modDB = actor.modDB
	local output = actor.output
	local breakdown = actor.breakdown
	local condList = modDB.conditions

	-- Set conditions
	if (actor.itemList["Weapon 2"] and actor.itemList["Weapon 2"].type == "Shield") or (actor == env.player and env.aegisModList) then
		condList["UsingShield"] = true
	end
	if not actor.itemList["Weapon 2"] then
		condList["OffHandIsEmpty"] = true
	end
	if actor.weaponData1.type == "None" then
		condList["Unarmed"] = true
		if not actor.itemList["Weapon 2"] and not actor.itemList["Gloves"] then
			condList["Unencumbered"] = true
		end
	else
		local info = env.data.weaponTypeInfo[actor.weaponData1.type]
		condList["Using"..info.flag] = true
		if info.melee then
			condList["UsingMeleeWeapon"] = true
		end
		if info.oneHand then
			condList["UsingOneHandedWeapon"] = true
		else
			condList["UsingTwoHandedWeapon"] = true
		end
	end
	local armourSlots = { "Helmet", "Body Armor", "Gloves", "Boots" }
	for _, slotName in ipairs(armourSlots) do
		if actor.itemList[slotName] then
			condList["Using"..slotName] = true
		end
	end
	if actor.weaponData2.type then
		local info = env.data.weaponTypeInfo[actor.weaponData2.type]
		condList["Using"..info.flag] = true
		if info.melee then
			condList["UsingMeleeWeapon"] = true
		end
		if info.oneHand then
			condList["UsingOneHandedWeapon"] = true
		else
			condList["UsingTwoHandedWeapon"] = true
		end
	end
	if actor.weaponData1.type and actor.weaponData2.type then
		condList["DualWielding"] = true
		if (env.data.weaponTypeInfo[actor.weaponData1.type].label or actor.weaponData1.type) ~= (env.data.weaponTypeInfo[actor.weaponData2.type].label or actor.weaponData2.type) then
			local info1 = env.data.weaponTypeInfo[actor.weaponData1.type]
			local info2 = env.data.weaponTypeInfo[actor.weaponData2.type]
			if info1.oneHand and info2.oneHand then
				condList["WieldingDifferentWeaponTypes"] = true
			end
		end
	end
	if env.mode_combat then
		if not modDB:Flag(env.player.mainSkill.skillCfg, "NeverCrit") then
			condList["CritInPast8Sec"] = true
		end
		if not actor.mainSkill.skillData.triggered and not actor.mainSkill.skillFlags.trap and not actor.mainSkill.skillFlags.mine and not actor.mainSkill.skillFlags.totem then
			if actor.mainSkill.skillFlags.attack then
				condList["AttackedRecently"] = true
			elseif actor.mainSkill.skillFlags.spell then
				condList["CastSpellRecently"] = true
			end
			if actor.mainSkill.skillTypes[SkillType.Movement] then
				condList["UsedMovementSkillRecently"] = true
			end
			if actor.mainSkill.skillFlags.minion and not actor.mainSkill.skillFlags.permanentMinion then
				condList["UsedMinionSkillRecently"] = true
			end
			if actor.mainSkill.skillTypes[SkillType.Vaal] then
				condList["UsedVaalSkillRecently"] = true
			end
			if actor.mainSkill.skillTypes[SkillType.Channel] then
				condList["Channelling"] = true
			end
		end
		if actor.mainSkill.skillFlags.hit and not actor.mainSkill.skillFlags.trap and not actor.mainSkill.skillFlags.mine and not actor.mainSkill.skillFlags.totem then
			condList["HitRecently"] = true
			if actor.mainSkill.skillFlags.spell then
				condList["HitSpellRecently"] = true
			end
		end
		if actor.mainSkill.skillFlags.totem then
			condList["HaveTotem"] = true
			condList["SummonedTotemRecently"] = true
			if actor.mainSkill.skillFlags.hit then
				condList["TotemsHitRecently"] = true
				if actor.mainSkill.skillFlags.spell then
					condList["TotemsSpellHitRecently"] = true
				end
			end
		end
		if actor.mainSkill.skillFlags.mine then
			condList["DetonatedMinesRecently"] = true
		end
		if actor.mainSkill.skillFlags.trap then
			condList["TriggeredTrapsRecently"] = true
		end
	end

	output.TotalAttr = 0
	for _, stat in pairs(Attributes) do
		output[stat] = round(calcLib.val(modDB, stat))
		if breakdown then
			breakdown[stat] = breakdown.simple(nil, nil, output[stat], stat)
		end
		output.TotalAttr = output.TotalAttr + output[stat]
	end


	doActorLifeMana(actor)
end

-- Process enemy modifiers and other buffs
local function doActorMisc(env, actor)
	local modDB = actor.modDB
	local enemyDB = actor.enemy.modDB
	local output = actor.output
	local condList = modDB.conditions

	-- Process enemy modifiers
	for _, value in ipairs(modDB:Tabulate(nil, nil, "EnemyModifier")) do
		enemyDB:AddMod(modLib.setSource(value.value.mod, value.value.mod.source or value.mod.source))
	end

	-- Add misc buffs/debuffs
	if env.mode_combat then
		if modDB:Flag(nil, "CanLeechLifeOnFullLife") then
			condList["Leeching"] = true
			condList["LeechingLife"] = true
		end
	end
end

function calcs.actionSpeedMod(actor)
	local modDB = actor.modDB
	local minimumActionSpeed = modDB:Max(nil, "MinimumActionSpeed") or 0
	local maximumActionSpeedReduction = modDB:Max(nil, "MaximumActionSpeedReduction")
	local actionSpeedMod = 1 + (m_max(-data.misc.TemporalChainsEffectCap, modDB:Sum("INC", nil, "TemporalChainsActionSpeed")) + modDB:Sum("INC", nil, "ActionSpeed")) / 100
	actionSpeedMod = m_max(minimumActionSpeed / 100, actionSpeedMod)
	if maximumActionSpeedReduction then
		actionSpeedMod = m_min((100 - maximumActionSpeedReduction) / 100, actionSpeedMod)
	end
	return actionSpeedMod
end

-- Finalises the environment and performs the stat calculations:
-- 1. Merges keystone modifiers
-- 2. Initialises minion skills
-- 3. Initialises the main skill's minion, if present
-- 4. Merges flask effects
-- 5. Sets conditions and calculates attributes (doActorAttribsConditions)
-- 6. Calculates life and mana (doActorLifeMana)
-- 6. Calculates reservations
-- 7. Sets life/mana reservation (doActorLifeManaReservation)
-- 8. Processes buffs and debuffs
-- 9. Processes charges and misc buffs (doActorCharges, doActorMisc)
-- 10. Calculates defence and offence stats (calcs.defence, calcs.offence)
function calcs.perform(env, fullDPSSkipEHP)
	local modDB = env.modDB
	local enemyDB = env.enemyDB

	local fullDPSSkipEHP = fullDPSSkipEHP or false

	-- Process ailment debuffs stack count
	if env.mode ~= "CACHE" then
		for _, activeSkill in ipairs(env.player.activeSkillList) do
			if activeSkill.skillFlags.ailment and activeSkill.skillFlags.buffs then
				local uuid = cacheSkillUUID(activeSkill, env)
				local cache = GlobalCache.cachedData["CACHE"][uuid]
				if not GlobalCache.cachedData["CACHE"][uuid] then
					calcs.buildActiveSkill(env, "CACHE", activeSkill)
				end
				cache = GlobalCache.cachedData["CACHE"][uuid]
				local skillId = activeSkill.activeEffect.grantedEffect.id
				if cache.Env.player.output.MaxStacks > 0 then
					modDB:NewMod("Multiplier:" .. skillId .. "Stack", "BASE", cache.Env.player.output.MaxStacks)
				end
			end
		end
	end

	-- Build minion skills
	for _, activeSkill in ipairs(env.player.activeSkillList) do
		activeSkill.skillModList = new("ModList", activeSkill.baseSkillModList)
		if activeSkill.minion then
			activeSkill.minion.modDB = new("ModDB")
			activeSkill.minion.modDB.actor = activeSkill.minion
			calcs.createMinionSkills(env, activeSkill)
			activeSkill.skillPartName = activeSkill.minion.mainSkill.activeEffect.grantedEffect.name
		end
	end

	env.player.output = { }
	env.enemy.output = { }
	local output = env.player.output

	env.partyMembers = env.build.partyTab.actor
	env.player.partyMembers = env.partyMembers
	local partyTabEnableExportBuffs = env.build.partyTab.enableExportBuffs

	env.minion = env.player.mainSkill.minion
	if env.minion then
		-- Initialise minion modifier database
		output.Minion = { }
		env.minion.output = output.Minion
		env.minion.modDB.multipliers["Level"] = env.minion.level
		calcs.initModDB(env, env.minion.modDB)
		env.minion.modDB:NewMod("Life", "BASE", m_floor(env.minion.lifeTable[env.minion.level] * env.minion.minionData.life), "Base")
		--Armour formula is math.floor((10 + 2 * level) * 1.067 ^ level)
		env.minion.modDB:NewMod("Armour", "BASE", 0, "Base")
		--Evasion formula is math.floor((50 + 16 * level + 16 * level * (MonsterType.Evasion / 100)) * (1.0212 ^ level)
		env.minion.modDB:NewMod("Evasion", "BASE", 0, "Base")
		if modDB:Flag(nil, "MinionAccuracyEqualsAccuracy") then
			env.minion.modDB:NewMod("Accuracy", "BASE", calcLib.val(modDB, "Accuracy") + calcLib.val(modDB, "Dex") * (modDB:Override(nil, "DexAccBonusOverride") or data.misc.AccuracyPerDexBase), "Player")
		else
			env.minion.modDB:NewMod("Accuracy", "BASE", round(env.data.monsterAccuracyTable[env.minion.level] * (env.minion.minionData.accuracy or 1)), "Base")
		end
		env.minion.modDB:NewMod("CritMultiplier", "BASE", 30, "Base")
		env.minion.modDB:NewMod("CritDegenMultiplier", "BASE", 30, "Base")
		env.minion.modDB:NewMod("ProjectileCount", "BASE", 1, "Base")
		for _, mod in ipairs(env.minion.minionData.modList) do
			env.minion.modDB:AddMod(mod)
		end
		for _, mod in ipairs(env.player.mainSkill.extraSkillModList) do
			env.minion.modDB:AddMod(mod)
		end
	end

	for _, activeSkill in ipairs(env.player.activeSkillList) do
		if activeSkill.skillData.triggeredOnDeath and not activeSkill.skillFlags.minion then
			activeSkill.skillData.triggered = true
			for _, value in ipairs(activeSkill.skillModList:Tabulate("INC", env.player.mainSkill.skillCfg, "TriggeredDamage")) do
				activeSkill.skillModList:NewMod("Damage", "INC", value.mod.value, value.mod.source, value.mod.flags, value.mod.keywordFlags, unpack(value.mod))
			end
			for _, value in ipairs(activeSkill.skillModList:Tabulate("MORE", env.player.mainSkill.skillCfg, "TriggeredDamage")) do
				activeSkill.skillModList:NewMod("Damage", "MORE", value.mod.value, value.mod.source, value.mod.flags, value.mod.keywordFlags, unpack(value.mod))
			end
			-- Set trigger time to 1 min in ms ( == 6000 ). Technically any large value would do.
			activeSkill.skillData.triggerTime = 60 * 1000
		end
	end

	local breakdown = nil
	if env.mode == "CALCS" then
		-- Initialise breakdown module
		breakdown = LoadModule(calcs.breakdownModule, modDB, output, env.player)
		env.player.breakdown = breakdown
		if env.minion then
			env.minion.breakdown = LoadModule(calcs.breakdownModule, env.minion.modDB, env.minion.output, env.minion)
		end
	end

	-- Calculate attributes and life/mana pools
	doActorAttribsConditions(env, env.player)
	doActorLifeMana(env.player)
	if env.minion then
		for _, value in ipairs(env.player.mainSkill.skillModList:List(env.player.mainSkill.skillCfg, "MinionModifier")) do
			if not value.type or env.minion.type == value.type then
				env.minion.modDB:AddMod(value.mod)
			end
		end
		for _, name in ipairs(env.minion.modDB:List(nil, "Keystone")) do
			if env.spec.tree.keystoneMap[name] then
				env.minion.modDB:AddList(env.spec.tree.keystoneMap[name].modList)
			end
		end
		doActorAttribsConditions(env, env.minion)
	end

	-- Process attribute requirements
	do
		local reqMult = calcLib.mod(modDB, nil, "GlobalAttributeRequirements")
		for _, attr in ipairs(Attributes) do
			local breakdownAttr = attr
			if breakdown then
				breakdown["Req"..attr] = {
					rowList = { },
					colList = {
						{ label = attr, key = "req" },
						{ label = "Source", key = "source" },
						{ label = "Source Name", key = "sourceName" },
					}
				}
			end
			local out = 0
			for _, reqSource in ipairs(env.requirementsTable) do
				if reqSource[attr] and reqSource[attr] > 0 then
					local req = m_floor(reqSource[attr] * reqMult)
					out = m_max(out, req)
					if breakdown then
						local row = {
							req = req > output[breakdownAttr] and colorCodes.NEGATIVE..req or req,
							reqNum = req,
							source = reqSource.source,
						}
						if reqSource.source == "Item" then
							local item = reqSource.sourceItem
							row.sourceName = colorCodes[item.rarity]..item.name
							row.sourceNameTooltip = function(tooltip)
								env.build.itemsTab:AddItemTooltip(tooltip, item, reqSource.sourceSlot)
							end
						end
						t_insert(breakdown["Req"..breakdownAttr].rowList, row)
					end
				end
			end
			if modDB:Flag(nil, "IgnoreAttributeRequirements") then
				out = 0
			end
			output["Req"..attr.."String"] = 0
			if out > (output["Req"..breakdownAttr] or 0) then
				output["Req"..breakdownAttr.."String"] = out
				output["Req"..breakdownAttr] = out
				if breakdown then
					output["Req"..breakdownAttr.."String"] = out > (output[breakdownAttr] or 0) and colorCodes.NEGATIVE..out or out
				end
			end
		end
	end

	-- Calculate number of active auras affecting self
	if env.mode_buffs then
		local auraList = { }
		for _, activeSkill in ipairs(env.player.activeSkillList) do
			if activeSkill.skillTypes[SkillType.Aura] and not activeSkill.skillTypes[SkillType.AuraAffectsEnemies] and not activeSkill.skillData.auraCannotAffectSelf and not auraList[activeSkill.skillCfg.skillName] then
				auraList[activeSkill.skillCfg.skillName] = true
				modDB.multipliers["AuraAffectingSelf"] = (modDB.multipliers["AuraAffectingSelf"] or 0) + 1
			end
		end
	end

	-- Combine buffs/debuffs
	local buffs = { }
	env.buffs = buffs
	local guards = { }
	local minionBuffs = { }
	env.minionBuffs = minionBuffs
	local debuffs = { }
	env.debuffs = debuffs
	local curses = { }
	local minionCurses = {
		limit = 1,
	}
	local allyBuffs = env.partyMembers["Aura"]
	local buffExports = { Aura = {}, Curse = {}, Link = {}, EnemyMods = {}, EnemyConditions = {}, PlayerMods = {} }
	for _, activeSkill in ipairs(env.player.activeSkillList) do
		local skillModList = activeSkill.skillModList
		local skillCfg = activeSkill.skillCfg
		for _, buff in ipairs(activeSkill.buffList) do
			if buff.cond and not skillModList:GetCondition(buff.cond, skillCfg) then
				-- Nothing!
			elseif buff.enemyCond and not enemyDB:GetCondition(buff.enemyCond) then
				-- Also nothing :/
			elseif buff.type == "Buff" then
				if env.mode_buffs and (not activeSkill.skillFlags.totem or buff.allowTotemBuff) then
					local skillCfg = buff.activeSkillBuff and skillCfg
					local modStore = buff.activeSkillBuff and skillModList or modDB
				 	if not buff.applyNotPlayer then
						activeSkill.buffSkill = true
						modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
						local srcList = new("ModList")
						local inc = modStore:Sum("INC", skillCfg, "BuffEffect", "BuffEffectOnSelf", "BuffEffectOnPlayer") + skillModList:Sum("INC", skillCfg, buff.name:gsub(" ", "").."Effect")
						local more = modStore:More(skillCfg, "BuffEffect", "BuffEffectOnSelf")
						srcList:ScaleAddList(buff.modList, (1 + inc / 100) * more)
						mergeBuff(srcList, buffs, buff.name)
						if activeSkill.skillData.thisIsNotABuff then
							buffs[buff.name].notBuff = true
						end
					end
					if env.minion and (buff.applyMinions or buff.applyAllies or skillModList:Flag(nil, "BuffAppliesToAllies")) then
						activeSkill.minionBuffSkill = true
						env.minion.modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
						local srcList = new("ModList")
						local inc = modStore:Sum("INC", skillCfg, "BuffEffect") + env.minion.modDB:Sum("INC", nil, "BuffEffectOnSelf")
						local more = modStore:More(skillCfg, "BuffEffect") * env.minion.modDB:More(nil, "BuffEffectOnSelf")
						srcList:ScaleAddList(buff.modList, (1 + inc / 100) * more)
						mergeBuff(srcList, minionBuffs, buff.name)
					end
					if partyTabEnableExportBuffs and (buff.applyAllies or skillModList:Flag(nil, "BuffAppliesToAllies") or skillModList:Flag(nil, "BuffAppliesToPartyMembers")) then
						local inc = modStore:Sum("INC", skillCfg, "BuffEffect") + skillModList:Sum("INC", skillCfg, buff.name:gsub(" ", "").."Effect")
						local more = modStore:More(skillCfg, "BuffEffect")
						buffExports["Aura"]["otherEffects"] = buffExports["Aura"]["otherEffects"] or { }
						buffExports["Aura"]["otherEffects"][buff.name] =  { effectMult = (1 + inc / 100) * more, modList = buff.modList }
					end
				end
			elseif buff.type == "Guard" then
				if env.mode_buffs and (not activeSkill.skillFlags.totem or buff.allowTotemBuff) then
					local skillCfg = buff.activeSkillBuff and skillCfg
					local modStore = buff.activeSkillBuff and skillModList or modDB
				 	if not buff.applyNotPlayer then
						activeSkill.buffSkill = true
						local srcList = new("ModList")
						local inc = modStore:Sum("INC", skillCfg, "BuffEffect", "BuffEffectOnSelf", "BuffEffectOnPlayer")
						local more = modStore:More(skillCfg, "BuffEffect", "BuffEffectOnSelf")
						srcList:ScaleAddList(buff.modList, (1 + inc / 100) * more)
						mergeBuff(srcList, guards, buff.name)
					end
				end
			elseif buff.type == "Aura" then
				if env.mode_buffs then
					-- Check for extra modifiers to apply to aura skills
					local extraAuraModList = { }
					for _, value in ipairs(modDB:List(skillCfg, "ExtraAuraEffect")) do
						local add = true
						for _, mod in ipairs(extraAuraModList) do
							if modLib.compareModParams(mod, value.mod) then
								mod.value = mod.value + value.mod.value
								add = false
								break
							end
						end
						if add then
							t_insert(extraAuraModList, copyTable(value.mod, true))
						end
					end
					if not activeSkill.skillData.auraCannotAffectSelf then
						local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect", "BuffEffectOnSelf", "AuraEffectOnSelf", "AuraBuffEffect", "SkillAuraEffectOnSelf")
						local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect", "BuffEffectOnSelf", "AuraEffectOnSelf", "AuraBuffEffect", "SkillAuraEffectOnSelf")
						local mult = (1 + inc / 100) * more
						if modDB:Flag(nil, "AlliesAurasCannotAffectSelf") or not allyBuffs["Aura"] or not allyBuffs["Aura"][buff.name] or allyBuffs["Aura"][buff.name].effectMult / 100 <= mult then
							activeSkill.buffSkill = true
							modDB.conditions["AffectedByAura"] = true
							if buff.name:sub(1,4) == "Vaal" then
								modDB.conditions["AffectedBy"..buff.name:sub(6):gsub(" ","")] = true
							end
							modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
							local srcList = new("ModList")
							srcList:ScaleAddList(buff.modList, mult)
							srcList:ScaleAddList(extraAuraModList, mult)
							mergeBuff(srcList, buffs, buff.name)
						end
					end
					if not (modDB:Flag(nil, "SelfAurasCannotAffectAllies") or modDB:Flag(nil, "SelfAurasOnlyAffectYou") or modDB:Flag(nil, "SelfAuraSkillsCannotAffectAllies")) then
						if env.minion then
							local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect") + env.minion.modDB:Sum("INC", skillCfg, "BuffEffectOnSelf", "AuraEffectOnSelf")
							local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect") * env.minion.modDB:More(skillCfg, "BuffEffectOnSelf", "AuraEffectOnSelf")
							local mult = (1 + inc / 100) * more
							if not allyBuffs["Aura"] or  not allyBuffs["Aura"][buff.name] or allyBuffs["Aura"][buff.name].effectMult / 100 <= mult then
								activeSkill.minionBuffSkill = true
								env.minion.modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
								env.minion.modDB.conditions["AffectedByAura"] = true
								local srcList = new("ModList")
								srcList:ScaleAddList(buff.modList, mult)
								srcList:ScaleAddList(extraAuraModList, mult)
								mergeBuff(srcList, minionBuffs, buff.name)
							end
						end
						local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect")
						local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect")
						local mult = (1 + inc / 100) * more
						local newModList = new("ModList")
						newModList:AddList(buff.modList)
						newModList:AddList(extraAuraModList)
						if buffExports["Aura"][buff.name] then
							buffExports["Aura"][buff.name.."_Debuff"] = buffExports["Aura"][buff.name]
						end
						buffExports["Aura"][buff.name] = { effectMult = mult, modList = newModList }
					end
					if env.player.mainSkill.skillFlags.totem and not (modDB:Flag(nil, "SelfAurasCannotAffectAllies") or modDB:Flag(nil, "SelfAuraSkillsCannotAffectAllies")) then
						activeSkill.totemBuffSkill = true
						env.player.mainSkill.skillModList.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
						env.player.mainSkill.skillModList.conditions["AffectedByAura"] = true

						local srcList = new("ModList")
						local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect", "AuraBuffEffect")
						local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect", "AuraBuffEffect")
						local lists = {extraAuraModList, buff.modList}
						local scale = (1 + inc / 100) * more
						scale = m_max(scale, 0)

						for _, modList in ipairs(lists) do
							for _, mod in ipairs(modList) do
								if mod.name == "Armour" or mod.name == "Evasion" or mod.name:match("Resist?M?a?x?$") then
									local totemMod = copyTable(mod)
									totemMod.name = "Totem"..totemMod.name
									if scale ~= 1 then
										if type(totemMod.value) == "number" then
											totemMod.value = (m_floor(totemMod.value) == totemMod.value) and m_modf(round(totemMod.value * scale, 2)) or totemMod.value * scale
										elseif type(totemMod.value) == "table" and totemMod.value.mod then
											totemMod.value.mod.value = (m_floor(totemMod.value.mod.value) == totemMod.value.mod.value) and m_modf(round(totemMod.value.mod.value * scale, 2)) or totemMod.value.mod.value * scale
										end
									end
									srcList:AddMod(totemMod)
								end
							end
						end
						mergeBuff(srcList, buffs, "Totem "..buff.name)
					end
				end
			elseif buff.type == "Debuff" or buff.type == "AuraDebuff" then
				local stackCount
				if buff.stackVar then
					stackCount = skillModList:Sum("BASE", skillCfg, "Multiplier:"..buff.stackVar)
					if buff.stackLimit then
						stackCount = m_min(stackCount, buff.stackLimit)
					elseif buff.stackLimitVar then
						stackCount = m_min(stackCount, skillModList:Sum("BASE", skillCfg, "Multiplier:"..buff.stackLimitVar))
					end
				else
					stackCount = activeSkill.skillData.stackCount or 1
				end
				if env.mode_effective and stackCount > 0 then
					activeSkill.debuffSkill = true
					enemyDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
					modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
					local srcList = new("ModList")
					local mult = 1
					if buff.type == "AuraDebuff" then
						mult = 0
						if not modDB:Flag(nil, "SelfAurasOnlyAffectYou") then
							local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect", "DebuffEffect")
							local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect", "DebuffEffect")
							mult = (1 + inc / 100) * more
							buffExports["Aura"][buff.name..(buffExports["Aura"][buff.name] and "_Debuff" or "")] = { effectMult = mult, modList = buff.modList }
							if allyBuffs["AuraDebuff"] and allyBuffs["AuraDebuff"][buff.name] and allyBuffs["AuraDebuff"][buff.name].effectMult / 100 > mult then
								mult = 0
							end
						end
					end
					if buff.type == "Debuff" then
						local inc = skillModList:Sum("INC", skillCfg, "DebuffEffect")
						local more = skillModList:More(skillCfg, "DebuffEffect")
						mult = (1 + inc / 100) * more
					end
					srcList:ScaleAddList(buff.modList, mult * stackCount)
					if activeSkill.skillData.stackCount or buff.stackVar then
						srcList:NewMod("Multiplier:"..buff.name.."Stack", "BASE", stackCount, buff.name)
					end
					mergeBuff(srcList, debuffs, buff.name)
				end
			elseif buff.type == "Curse" or buff.type == "CurseBuff" then
				local mark = activeSkill.skillTypes[SkillType.Mark]
				modDB.conditions["SelfCast"..buff.name:gsub(" ","")] = not (activeSkill.skillTypes[SkillType.Triggered] or activeSkill.skillTypes[SkillType.Aura])
				if env.mode_effective and (not enemyDB:Flag(nil, "Hexproof") or modDB:Flag(nil, "CursesIgnoreHexproof") or activeSkill.skillData.ignoreHexLimit or activeSkill.skillData.ignoreHexproof) or mark then
					local curse = {
						name = buff.name,
						fromPlayer = true,
						isMark = mark,
						ignoreHexLimit = (modDB:Flag(activeSkill.skillCfg, "CursesIgnoreHexLimit") or activeSkill.skillData.ignoreHexLimit) and not mark or false,
						socketedCursesHexLimit = modDB:Flag(activeSkill.skillCfg, "SocketedCursesAdditionalLimit")
					}
					local inc = skillModList:Sum("INC", skillCfg, "CurseEffect") + enemyDB:Sum("INC", nil, "CurseEffectOnSelf")
					if activeSkill.skillTypes[SkillType.Aura] then
						inc = inc + skillModList:Sum("INC", skillCfg, "AuraEffect")
					end
					local more = skillModList:More(skillCfg, "CurseEffect")
					local moreMark = more
					-- This is non-ideal, but the only More for enemy is the boss effect
					if not curse.isMark then
						more = more * enemyDB:More(nil, "CurseEffectOnSelf")
					end
					local mult = 0
					if not (modDB:Flag(nil, "SelfAurasOnlyAffectYou") and activeSkill.skillTypes[SkillType.Aura]) then --If your aura only effect you blasphemy does nothing
						mult = (1 + inc / 100) * more
					end
					if buff.type == "Curse" then
						curse.modList = new("ModList")
						curse.modList:ScaleAddList(buff.modList, mult)
						if partyTabEnableExportBuffs then
							buffExports["Curse"][buff.name] = { isMark = curse.isMark, effectMult = curse.isMark and mult or (1 + inc / 100) * moreMark, modList = buff.modList }
						end
					else
						-- Curse applies a buff; scale by curse effect, then buff effect
						local temp = new("ModList")
						temp:ScaleAddList(buff.modList, mult)
						curse.buffModList = new("ModList")
						local buffInc = modDB:Sum("INC", skillCfg, "BuffEffectOnSelf")
						local buffMore = modDB:More(skillCfg, "BuffEffectOnSelf")
						curse.buffModList:ScaleAddList(temp, (1 + buffInc / 100) * buffMore)
						if env.minion then
							curse.minionBuffModList = new("ModList")
							local buffInc = env.minion.modDB:Sum("INC", nil, "BuffEffectOnSelf")
							local buffMore = env.minion.modDB:More(nil, "BuffEffectOnSelf")
							curse.minionBuffModList:ScaleAddList(temp, (1 + buffInc / 100) * buffMore)
						end
					end
					t_insert(curses, curse)
				end
			end
		end
		if activeSkill.minion and activeSkill.minion.activeSkillList then
			local castingMinion = activeSkill.minion
			for _, activeMinionSkill in ipairs(activeSkill.minion.activeSkillList) do
				local skillModList = activeMinionSkill.skillModList
				local skillCfg = activeMinionSkill.skillCfg
				for _, buff in ipairs(activeMinionSkill.buffList) do
					if buff.type == "Buff" then
						if env.mode_buffs and activeMinionSkill.skillData.enable then
							local skillCfg = buff.activeSkillBuff and skillCfg
							local modStore = buff.activeSkillBuff and skillModList or castingMinion.modDB
							if buff.applyAllies then
								activeMinionSkill.buffSkill = true
								modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
								local srcList = new("ModList")
								local inc = modStore:Sum("INC", skillCfg, "BuffEffect", "BuffEffectOnPlayer") + modDB:Sum("INC", nil, "BuffEffectOnSelf")
								local more = modStore:More(skillCfg, "BuffEffect", "BuffEffectOnPlayer") * modDB:More(nil, "BuffEffectOnSelf")
								srcList:ScaleAddList(buff.modList, (1 + inc / 100) * more)
								mergeBuff(srcList, buffs, buff.name)
								mergeBuff(buff.modList, buffs, buff.name)
								if activeMinionSkill.skillData.thisIsNotABuff then
									buffs[buff.name].notBuff = true
								end
								if partyTabEnableExportBuffs then
									local inc = modStore:Sum("INC", skillCfg, "BuffEffect")
									local more = modStore:More(skillCfg, "BuffEffect")
									buffExports["Aura"]["otherEffects"] = buffExports["Aura"]["otherEffects"] or { }
									buffExports["Aura"]["otherEffects"][buff.name] =  { effectMult = (1 + inc / 100) * more, modList = buff.modList }
								end
							end
							local envMinionCheck = (env.minion and (env.minion == castingMinion or buff.applyAllies))
							if buff.applyMinions or envMinionCheck then
								activeMinionSkill.minionBuffSkill = true
								if envMinionCheck then
									env.minion.modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
								else
									activeSkill.minion.modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
								end
								local srcList = new("ModList")
								local inc = modStore:Sum("INC", skillCfg, "BuffEffect", (env.minion == castingMinion) and "BuffEffectOnSelf" or nil)
								local more = modStore:More(skillCfg, "BuffEffect", (env.minion == castingMinion) and "BuffEffectOnSelf" or nil)
								srcList:ScaleAddList(buff.modList, (1 + inc / 100) * more)
								mergeBuff(srcList, minionBuffs, buff.name)
								mergeBuff(buff.modList, minionBuffs, buff.name)
								if activeMinionSkill.skillData.thisIsNotABuff then
									buffs[buff.name].notBuff = true
								end
							end
						end
					elseif buff.type == "Aura" then
						if env.mode_buffs and activeMinionSkill.skillData.enable then
							-- Check for extra modifiers to apply to aura skills
							local extraAuraModList = { }
							for _, value in ipairs(activeSkill.minion.modDB:List(skillCfg, "ExtraAuraEffect")) do
								local add = true
								for _, mod in ipairs(extraAuraModList) do
									if modLib.compareModParams(mod, value.mod) then
										mod.value = mod.value + value.mod.value
										add = false
										break
									end
								end
								if add then
									t_insert(extraAuraModList, copyTable(value.mod, true))
								end
							end
							if not (activeSkill.minion.modDB:Flag(nil, "SelfAurasCannotAffectAllies") or activeSkill.minion.modDB:Flag(nil, "SelfAurasOnlyAffectYou") or activeSkill.minion.modDB:Flag(nil, "SelfAuraSkillsCannotAffectAllies")) then
								if not modDB:Flag(nil, "AlliesAurasCannotAffectSelf") and not modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] then
									local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect", "BuffEffectOnPlayer", "AuraBuffEffect") + modDB:Sum("INC", skillCfg, "BuffEffectOnSelf", "AuraEffectOnSelf")
									local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect", "AuraBuffEffect") * modDB:More(skillCfg, "BuffEffectOnSelf", "AuraEffectOnSelf")
									local mult = (1 + inc / 100) * more
									if not allyBuffs["Aura"] or not allyBuffs["Aura"][buff.name] or allyBuffs["Aura"][buff.name].effectMult / 100 <= mult then
										activeMinionSkill.buffSkill = true
										modDB.conditions["AffectedByAura"] = true
										if buff.name:sub(1,4) == "Vaal" then
											modDB.conditions["AffectedBy"..buff.name:sub(6):gsub(" ","")] = true
										end
										modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
										local srcList = new("ModList")
										srcList:ScaleAddList(buff.modList, mult)
										srcList:ScaleAddList(extraAuraModList, mult)
										mergeBuff(srcList, buffs, buff.name)
									end
								end
								if env.minion and not env.minion.modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] and (env.minion ~= activeSkill.minion or not activeSkill.skillData.auraCannotAffectSelf)  then
									local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect") + env.minion.modDB:Sum("INC", skillCfg, "BuffEffectOnSelf", "AuraEffectOnSelf")
									local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect") * env.minion.modDB:More(skillCfg, "BuffEffectOnSelf", "AuraEffectOnSelf")
									local mult = (1 + inc / 100) * more
									if not allyBuffs["Aura"] or  not allyBuffs["Aura"][buff.name] or allyBuffs["Aura"][buff.name].effectMult / 100 <= mult then
										activeMinionSkill.minionBuffSkill = true
										env.minion.modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
										env.minion.modDB.conditions["AffectedByAura"] = true
										local srcList = new("ModList")
										srcList:ScaleAddList(buff.modList, mult)
										srcList:ScaleAddList(extraAuraModList, mult)
										mergeBuff(srcList, minionBuffs, buff.name)
									end
								end
								local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect")
								local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect")
								local mult = (1 + inc / 100) * more
								local newModList = new("ModList")
								newModList:AddList(buff.modList)
								newModList:AddList(extraAuraModList)
								if buffExports["Aura"][buff.name] then
									buffExports["Aura"][buff.name.."_Debuff"] = buffExports["Aura"][buff.name]
								end
								buffExports["Aura"][buff.name] = { effectMult = mult, modList = newModList }
								if env.player.mainSkill.skillFlags.totem and not env.player.mainSkill.skillModList.conditions["AffectedBy"..buff.name:gsub(" ","")] then
									activeMinionSkill.totemBuffSkill = true
									env.player.mainSkill.skillModList.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
									env.player.mainSkill.skillModList.conditions["AffectedByAura"] = true

									local srcList = new("ModList")
									local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect", "AuraBuffEffect")
									local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect", "AuraBuffEffect")
									local lists = {extraAuraModList, buff.modList}
									local scale = (1 + inc / 100) * more
									scale = m_max(scale, 0)

									for _, modList in ipairs(lists) do
										for _, mod in ipairs(modList) do
											if mod.name == "Armour" or mod.name == "Evasion" or mod.name:match("Resist?M?a?x?$") then
												local totemMod = copyTable(mod)
												totemMod.name = "Totem"..totemMod.name
												if scale ~= 1 then
													if type(totemMod.value) == "number" then
														totemMod.value = (m_floor(totemMod.value) == totemMod.value) and m_modf(round(totemMod.value * scale, 2)) or totemMod.value * scale
													elseif type(totemMod.value) == "table" and totemMod.value.mod then
														totemMod.value.mod.value = (m_floor(totemMod.value.mod.value) == totemMod.value.mod.value) and m_modf(round(totemMod.value.mod.value * scale, 2)) or totemMod.value.mod.value * scale
													end
												end
												srcList:AddMod(totemMod)
											end
										end
									end
									mergeBuff(srcList, buffs, "Totem "..buff.name)
								end
							end
						end
					elseif buff.type == "Curse" then
						if env.mode_effective and activeMinionSkill.skillData.enable and (not enemyDB:Flag(nil, "Hexproof") or activeMinionSkill.skillTypes[SkillType.Mark]) then
							local curse = {
								name = buff.name,
							}
							local inc = skillModList:Sum("INC", skillCfg, "CurseEffect") + enemyDB:Sum("INC", nil, "CurseEffectOnSelf")
							local more = skillModList:More(skillCfg, "CurseEffect") * enemyDB:More(nil, "CurseEffectOnSelf")
							curse.modList = new("ModList")
							curse.modList:ScaleAddList(buff.modList, (1 + inc / 100) * more)
							t_insert(minionCurses, curse)
						end
					elseif buff.type == "Debuff" or buff.type == "AuraDebuff" then
						local stackCount
						if buff.stackVar then
							stackCount = skillModList:Sum("BASE", skillCfg, "Multiplier:"..buff.stackVar)
							if buff.stackLimit then
								stackCount = m_min(stackCount, buff.stackLimit)
							elseif buff.stackLimitVar then
								stackCount = m_min(stackCount, skillModList:Sum("BASE", skillCfg, "Multiplier:"..buff.stackLimitVar))
							end
						else
							stackCount = activeMinionSkill.skillData.stackCount or 1
						end
						if env.mode_effective and stackCount > 0 then
							activeMinionSkill.debuffSkill = true
							local srcList = new("ModList")
							local mult = 1
							if buff.type == "AuraDebuff" then
								mult = 0
								if not skillModList:Flag(nil, "SelfAurasOnlyAffectYou") then
									local inc = skillModList:Sum("INC", skillCfg, "AuraEffect", "BuffEffect", "DebuffEffect")
									local more = skillModList:More(skillCfg, "AuraEffect", "BuffEffect", "DebuffEffect")
									mult = (1 + inc / 100) * more
									if not enemyDB.conditions["AffectedBy"..buff.name:gsub(" ","")] then
										buffExports["Aura"][buff.name..(buffExports["Aura"][buff.name] and "_Debuff" or "")] = { effectMult = mult, modList = buff.modList }
										if allyBuffs["AuraDebuff"] and allyBuffs["AuraDebuff"][buff.name] and allyBuffs["AuraDebuff"][buff.name].effectMult / 100 > mult then
											mult = 0
										end
									else
										mult = 0
									end
								end
							end
							enemyDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
							if env.minion and env.minion == activeSkill.minion then
								env.minion.modDB.conditions["AffectedBy"..buff.name:gsub(" ","")] = true
							end
							if buff.type == "Debuff" then
								local inc = skillModList:Sum("INC", skillCfg, "DebuffEffect")
								local more = skillModList:More(skillCfg, "DebuffEffect")
								mult = (1 + inc / 100) * more
							end
							srcList:ScaleAddList(buff.modList, mult * stackCount)
							if activeMinionSkill.skillData.stackCount or buff.stackVar then
								srcList:NewMod("Multiplier:"..buff.name.."Stack", "BASE", activeMinionSkill.skillData.stackCount, buff.name)
							end
							mergeBuff(srcList, debuffs, buff.name)
						end
					end
				end
			end
		end
	end
	if allyBuffs["otherEffects"] then
		for buffName, buff in pairs(allyBuffs["otherEffects"]) do
			modDB.conditions["AffectedBy"..buffName:gsub(" ","")] = true
			local inc = modDB:Sum("INC", nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
			local more = modDB:More(nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
			local srcList = new("ModList")
			srcList:ScaleAddList(buff.modList, (buff.effectMult + inc) / 100 * more)
			mergeBuff(srcList, buffs, buffName)
			if env.minion then
				env.minion.modDB.conditions["AffectedBy"..buffName:gsub(" ","")] = true
				local inc = env.minion.modDB:Sum("INC", nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
				local more = env.minion.modDB:More(nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
				local srcList = new("ModList")
				srcList:ScaleAddList(buff.modList, (buff.effectMult + inc) / 100 * more)
				mergeBuff(srcList, minionBuffs, buffName)
			end
		end
	end
	if allyBuffs["Aura"] then
		for auraName, aura in pairs(allyBuffs["Aura"]) do
			if auraName ~= "Vaal" then
				local auraNameCompressed = auraName:gsub(" ","")
				if not modDB:Flag(nil, "AlliesAurasCannotAffectSelf") and not modDB.conditions["AffectedBy"..auraNameCompressed] then
					modDB.conditions["AffectedByAura"] = true
					modDB.conditions["AffectedBy"..auraNameCompressed] = true
					local srcList = new("ModList")
					srcList:ScaleAddList(aura.modList, aura.effectMult / 100)
					mergeBuff(srcList, buffs, auraName)
				end
				if env.minion and not env.minion.modDB.conditions["AffectedBy"..auraNameCompressed] then
					env.minion.modDB.conditions["AffectedByAura"] = true
					env.minion.modDB.conditions["AffectedBy"..auraNameCompressed] = true
					local srcList = new("ModList")
					srcList:ScaleAddList(aura.modList, aura.effectMult / 100)
					mergeBuff(srcList, minionBuffs, auraName)
				end
			end
		end
	end
	if allyBuffs["AuraDebuff"] and env.mode_effective then
		for auraName, aura in pairs(allyBuffs["AuraDebuff"]) do
			if auraName ~= "Vaal" then
				local auraNameCompressed = auraName:gsub(" ","")
				if not enemyDB.conditions["AffectedBy"..auraNameCompressed] then
					enemyDB.conditions["AffectedBy"..auraNameCompressed] = true
					modDB.conditions["AffectedBy"..auraNameCompressed] = true
					local srcList = new("ModList")
					srcList:ScaleAddList(aura.modList, aura.effectMult / 100)
					mergeBuff(srcList, debuffs, auraName)
				end
			end
		end
	end

	-- Check for extra curses
	for dest, modDB in pairs({[curses] = modDB, [minionCurses] = env.minion and env.minion.modDB}) do
		for _, value in ipairs(modDB:List(nil, "ExtraCurse")) do
			local gemModList = new("ModList")
			local grantedEffect = env.data.skills[value.skillId]
			if grantedEffect then
				calcs.mergeSkillInstanceMods(env, gemModList, {
					grantedEffect = grantedEffect,
					level = value.level,
					quality = 0,
				})
				local curseModList = { }
				for _, mod in ipairs(gemModList) do
					for _, tag in ipairs(mod) do
						if tag.type == "GlobalEffect" and tag.effectType == "Curse" then
							t_insert(curseModList, mod)
							break
						end
					end
				end
				if value.applyToPlayer then
					-- Sources for curses on the player don't usually respect any kind of limit, so there's little point bothering with slots
					if modDB:Sum("BASE", nil, "AvoidCurse") < 100 then
						modDB.conditions["Cursed"] = true
						modDB.multipliers["CurseOnSelf"] = (modDB.multipliers["CurseOnSelf"] or 0) + 1
						modDB.conditions["AffectedBy"..grantedEffect.name:gsub(" ","")] = true
						local cfg = { skillName = grantedEffect.name }
						local inc = modDB:Sum("INC", cfg, "CurseEffectOnSelf") + gemModList:Sum("INC", nil, "CurseEffectAgainstPlayer")
						local more = modDB:More(cfg, "CurseEffectOnSelf") * gemModList:More(nil, "CurseEffectAgainstPlayer")
						modDB:ScaleAddList(curseModList, (1 + inc / 100) * more)
					end
				elseif not enemyDB:Flag(nil, "Hexproof") or modDB:Flag(nil, "CursesIgnoreHexproof") then
					local curse = {
						name = grantedEffect.name,
						fromPlayer = (dest == curses),
					}
					curse.modList = new("ModList")
					curse.modList:ScaleAddList(curseModList, (1 + enemyDB:Sum("INC", nil, "CurseEffectOnSelf") / 100) * enemyDB:More(nil, "CurseEffectOnSelf"))
					t_insert(dest, curse)
				end
			end
		end
	end
	local allyCurses = {}
	local allyPartyCurses = env.partyMembers["Curse"]
	if allyPartyCurses["Curse"] then
		allyCurses.limit = allyPartyCurses.limit
	else
		allyPartyCurses = { Curse = {} }
	end
	for curseName, curse in pairs(allyPartyCurses["Curse"]) do
		local newCurse = {
			name = curseName,
			priority = 0,
			modList = new("ModList")
		}
		local mult = curse.effectMult / 100
		if curse.isMark then
			newCurse.isMark = true
		else
			mult = mult * enemyDB:More(nil, "CurseEffectOnSelf")
		end
		newCurse.modList:ScaleAddList(curse.modList, mult)
		t_insert(allyCurses, newCurse)
	end


	-- Assign curses to slots
	local curseSlots = tableConcat(curses, minionCurses)
	env.curseSlots = curseSlots

	-- Apply buff/debuff modifiers
	for _, modList in pairs(buffs) do
		modDB:AddList(modList)
		if not modList.notBuff then
			modDB.multipliers["BuffOnSelf"] = (modDB.multipliers["BuffOnSelf"] or 0) + 1
		end
		if env.minion then
			for _, value in ipairs(modList:List(env.player.mainSkill.skillCfg, "MinionModifier")) do
				if not value.type or env.minion.type == value.type then
					env.minion.modDB:AddMod(value.mod)
				end
			end
		end
	end
	if env.minion then
		for _, modList in pairs(minionBuffs) do
			env.minion.modDB:AddList(modList)
		end
	end
	for _, modList in pairs(debuffs) do
		enemyDB:AddList(modList)
	end
	modDB.multipliers["CurseOnEnemy"] = #curseSlots
	for _, slot in ipairs(curseSlots) do
		enemyDB.conditions["Cursed"] = true
		if slot.modList then
			enemyDB:AddList(slot.modList)
		end
		if slot.buffModList then
			modDB:AddList(slot.buffModList)
		end
		if slot.minionBuffModList then
			env.minion.modDB:AddList(slot.minionBuffModList)
		end
	end

	-- Check for extra auras
	buffExports["Aura"]["extraAura"] = { effectMult = 1, modList = new("ModList") }
	for _, value in ipairs(modDB:List(nil, "ExtraAura")) do
		local modList = { value.mod }
		if not value.onlyAllies then
			local inc = modDB:Sum("INC", nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
			local more = modDB:More(nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
			modDB:ScaleAddList(modList, (1 + inc / 100) * more)
			if not value.notBuff then
				modDB.multipliers["BuffOnSelf"] = (modDB.multipliers["BuffOnSelf"] or 0) + 1
			end
		end
		if not modDB:Flag(nil, "SelfAurasCannotAffectAllies") then
			if env.minion then
				local inc = env.minion.modDB:Sum("INC", nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
				local more = env.minion.modDB:More(nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
				env.minion.modDB:ScaleAddList(modList, (1 + inc / 100) * more)
			end
			buffExports["Aura"]["extraAura"].modList:AddMod(value.mod)
			local totemModBlacklist = value.mod.name and (value.mod.name == "Speed" or value.mod.name == "CritMultiplier" or value.mod.name == "CritChance")
			if env.player.mainSkill.skillFlags.totem and not totemModBlacklist then
				local totemMod = copyTable(value.mod)
				local totemModName, matches = totemMod.name:gsub("Condition:", "Condition:Totem")
				if matches < 1 then
					totemModName = "Totem" .. totemMod.name
				end
				totemMod.name = totemModName
				modDB:AddMod(totemMod)
			end
		end
	end
	if allyBuffs["extraAura"] then
		for _, buff in pairs(allyBuffs["extraAura"]) do
			local modList = buff.modList
			local inc = modDB:Sum("INC", nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
			local more = modDB:More(nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
			modDB:ScaleAddList(modList, (1 + inc / 100) * more)
			if env.minion then
				local inc = env.minion.modDB:Sum("INC", nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
				local more = env.minion.modDB:More(nil, "BuffEffectOnSelf", "AuraEffectOnSelf")
				env.minion.modDB:ScaleAddList(modList, (1 + inc / 100) * more)
			end
		end
	end

	-- Check for modifiers to apply to actors affected by player auras or curses
	for _, value in ipairs(modDB:List(nil, "AffectedByAuraMod")) do
		for actor in pairs(affectedByAura) do
			actor.modDB:AddMod(value.mod)
		end
	end

	-- Special handling for Dancing Dervish
	if modDB:Flag(nil, "DisableWeapons") then
		env.player.weaponData1 = copyTable(env.data.unarmedWeaponData[env.classId])
		modDB.conditions["Unarmed"] = true
		if not env.player.Gloves or env.player.Gloves == None then
			modDB.conditions["Unencumbered"] = true
		end
	elseif env.weaponModList1 then
		modDB:AddList(env.weaponModList1)
	end

	-- Process misc buffs/modifiers
	doActorMisc(env, env.player)
	if env.minion then
		doActorMisc(env, env.minion)
	end

	doActorMisc(env, env.enemy)

	for _, activeSkill in ipairs(env.player.activeSkillList) do
		if activeSkill.skillFlags.totem then
			local limit = env.player.mainSkill.skillModList:Sum("BASE", env.player.mainSkill.skillCfg, "ActiveTotemLimit", "ActiveBallistaLimit" )
			output.ActiveTotemLimit = m_max(limit, output.ActiveTotemLimit or 0)
			output.TotemsSummoned = modDB:Override(nil, "TotemsSummoned") or output.ActiveTotemLimit
			enemyDB.multipliers["TotemsSummoned"] = m_max(output.TotemsSummoned or 0, enemyDB.multipliers["TotemsSummoned"] or 0)
		end
	end

	-- Defence/offence calculations
	for _, stat in ipairs({"WardRetention", "Endurance", "EnduranceThreshold", "WardPerSecond", "WardDecayThreshold"}) do
		output[stat] = round(calcLib.val(modDB, stat))
		if breakdown then
			breakdown[stat] = breakdown.simple(nil, nil, output[stat], stat)
		end
	end
	calcs.defence(env, env.player)
	if not fullDPSSkipEHP then
		calcs.buildDefenceEstimations(env, env.player)
	end

	calcs.triggers(env, env.player)
	if not calcs.mirages(env) then
		calcs.offence(env, env.player, env.player.mainSkill)
	end

	if env.minion then
		doActorLifeMana(env.minion)

		calcs.defence(env, env.minion)
		if not fullDPSSkipEHP then -- main.build.calcsTab.input.showMinion and -- should be disabled unless "calcsTab.input.showMinion" is true
			calcs.buildDefenceEstimations(env, env.minion)
		end
		calcs.triggers(env, env.minion)
		calcs.offence(env, env.minion, env.minion.mainSkill)
	end

	 -- Export modifiers to enemy conditions and stats for party tab
	if partyTabEnableExportBuffs then
        for k, mod in pairs(enemyDB.mods) do
            if k:find("Condition") and not k:find("Party") then
                buffExports["EnemyConditions"][k] = true
            elseif (k:find("Resist") and not k:find("Totem") and not k:find("Max")) or k:find("Damage") or k:find("ActionSpeed") or k:find("SelfCrit") or (k:find("Multiplier") and not k:find("Max") and not k:find("Impale")) then
                for _, v in ipairs(mod) do
                    if not v.party and v.value ~= 0 and v.source ~= "EnemyConfig" and v.source ~= "Base" and not v.source:find("Delirious") and not v.source:find("^Party") then
						local skipValue = false
						for _, tag in ipairs(v) do
							if tag.effectType == "Curse" or tag.effectType == "AuraDebuff" then
								skipValue = true
								break
							end
						end
                        if not skipValue and (not v[1] or (
								(v[1].type ~= "Condition" or (v[1].var and (enemyDB.mods["Condition:"..v[1].var] and enemyDB.mods["Condition:"..v[1].var][1].value) or v[1].varList and (enemyDB.mods["Condition:"..v[1].varList[1]] and enemyDB.mods["Condition:"..v[1].varList[1]][1].value)))
								and (v[1].type ~= "Multiplier" or (enemyDB.mods["Multiplier:"..v[1].var] and enemyDB.mods["Multiplier:"..v[1].var][1].value)))) then
                            if buffExports["EnemyMods"][k] then
								if not buffExports["EnemyMods"][k].MultiStat then
									buffExports["EnemyMods"][k] = { MultiStat = true, buffExports["EnemyMods"][k] }
								end
								t_insert(buffExports["EnemyMods"][k], v)
							else
								buffExports["EnemyMods"][k] = v
							end
                        end
                    end
                end
            end
        end

		for _, damageType in ipairs(DamageTypes) do
			if env.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") and output[damageType.."Resist"] then
				buffExports.PlayerMods["Enemy"..damageType.."ResistEqualToYours"] = true
				buffExports.PlayerMods[damageType.."Resist="..tostring(output[damageType.."Resist"])] = true
			end
		end

		buffExports.PlayerMods["MovementSpeedMod|percent|max="..tostring(output["MovementSpeedMod"] * 100)] = true

		env.build.partyTab:setBuffExports(buffExports)
	end

	cacheData(cacheSkillUUID(env.player.mainSkill, env), env)
end
