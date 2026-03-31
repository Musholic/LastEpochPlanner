-- Last Epoch Planner
--
-- Class: Item
-- Equippable item class
--
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_floor = math.floor

local dmgTypeList = DamageTypes

local ItemClass = newClass("Item", function(self, raw, rarity, highQuality)
	if raw then
		self:ParseRaw(sanitiseText(raw), rarity, highQuality)
	end
end)

local lineFlags = {
	["custom"] = true, ["unique"] = true, ["corrupted"] = true, ["sealed"] = true, ["prefix"] = true, ["suffix"] = true
}

local function specToNumber(s)
	local n = s:match("^([%+%-]?[%d%.]+)")
	return n and tonumber(n)
end

-- Parse raw item data and extract item name, base type, quality, and modifiers
function ItemClass:ParseRaw(raw, rarity, highQuality)
	self.raw = raw
	self.name = "?"
	self.namePrefix = ""
	self.nameSuffix = ""
	self.base = nil
	self.rarity = rarity or "UNIQUE"
	self.rarityType = nil
	self.rawLines = { }
	self.corrupted = false
	-- Find non-blank lines and trim whitespace
	for line in raw:gmatch("%s*([^\n]*%S)") do
	 	t_insert(self.rawLines, line)
	end
	local mode = rarity and "GAME" or "WIKI"
	local l = 1
	local itemClass
	if self.rawLines[l] then
		if self.rawLines[l]:match("^Item Class:") then
			itemClass = self.rawLines[l]:gsub("^Item Class: %s+", "%1")
			l = l + 1 -- Item class is already determined by the base type
		end
		local rarity = self.rawLines[l]:match("^Rarity: (%a+)")
		if rarity then
			mode = "GAME"
			rarity = rarity:upper()
			-- Map raw rarity to rarityType (BASIC/UNIQUE/SET/IDOL)
			if rarity == "BASIC" or rarity == "NORMAL" or rarity == "MAGIC" or rarity == "RARE" or rarity == "EXALTED" then
				self.rarityType = "BASIC"
				self.rarity = rarity -- keep raw value for name parsing; UpdateDisplayRarity recomputes later
			elseif rarity == "SET" then
				self.rarityType = "SET"
				self.rarity = "SET"
			elseif rarity == "IDOL" then
				self.rarityType = "IDOL"
				self.rarity = "IDOL"
			elseif rarity == "LEGENDARY" then
				self.rarityType = "UNIQUE"
				self.rarity = "LEGENDARY"
			-- A unique idol serializes as Rarity: UNIQUE; rarityType is fixed later by idol auto-detection
			else
				self.rarityType = "UNIQUE"
				self.rarity = "UNIQUE"
			end
			l = l + 1
		end
	end
	-- Default rarityType if not set from raw text
	if not self.rarityType then
		local r = self.rarity
		if r == "NORMAL" or r == "MAGIC" or r == "RARE" or r == "EXALTED" or r == "BASIC" then
			self.rarityType = "BASIC"
		elseif r == "SET" then
			self.rarityType = "SET"
		elseif r == "IDOL" then
			self.rarityType = "IDOL"
		elseif r == "LEGENDARY" then
			self.rarityType = "UNIQUE"
		else
			self.rarityType = "UNIQUE"
		end
	end
	if self.rawLines[l] then
		self.name = self.rawLines[l]
		-- Determine if "Unidentified" item
		local unidentified = false
		for _, line in ipairs(self.rawLines) do
			if line == "Unidentified" then
				unidentified = true
				break
			end
		end

		-- Found the name for a rare or unique, but let's parse it if it's a magic or normal or Unidentified item to get the base
		if not (self.rarity == "NORMAL" or self.rarity == "MAGIC" or unidentified) then
			l = l + 1
		end
	end
	self.checkSection = false
	self.implicitModLines = { }
	self.explicitModLines = { }
	local implicitLines = 0
	self.variantList = nil
	self.affixes = { }
	for i = 1,6 do
		self.affixes[i] = { }
	end
	self.requirements = { }
	self.baseLines = { }
	local importedLevelReq
	local gameModeStage = "FINDIMPLICIT"
	local foundExplicit, foundImplicit

	while self.rawLines[l] do
		local line = self.rawLines[l]
		if line == "--------" then
			self.checkSection = true
		else
			if self.checkSection then
				if gameModeStage == "IMPLICIT" then
					if foundImplicit then
						-- There were definitely implicits, so any following modifiers must be explicits
						gameModeStage = "EXPLICIT"
						foundExplicit = true
					else
						gameModeStage = "FINDEXPLICIT"
					end
				elseif gameModeStage == "EXPLICIT" then
					gameModeStage = "DONE"
				elseif gameModeStage == "FINDIMPLICIT" and self.itemLevel and not line:match(" %(implicit%)") then
					gameModeStage = "EXPLICIT"
					foundExplicit = true
				end
				self.checkSection = false
			end
			local specName, specVal = line:match("^([%a ]+:?): (.+)$")
			if specName then
				if specName == "Class:" then
					specName = "Requires Class"
				end
			else
				specName, specVal = line:match("^(Requires %a+) (.+)$")
			end
			local function parseAffix(specVal, attribute)
    			local range, affix = specVal:match("{range:([%d.]+)}(.+)")
    			range = range or main.defaultItemAffixQuality
                local parsedAffix = {
    				modId = affix or specVal,
    				range = tonumber(range),
                }
                parsedAffix[attribute] = true
                return parsedAffix
			end
			if specName then
				if specName == "Unique ID" then
					self.uniqueID = specVal
				elseif specName == "LevelReq" then
					self.requirements.level = specToNumber(specVal)
				elseif specName == "Implicit" then
					self.implicit = true
				elseif specName == "Prefix" then
					if not self.affixes[1].modId then
						self.affixes[1] = parseAffix(specVal, "prefix")
					else
						self.affixes[2] = parseAffix(specVal, "prefix")
					end
				elseif specName == "Suffix" then
					if not self.affixes[3].modId then
						self.affixes[3] = parseAffix(specVal, "suffix")
					else
						self.affixes[4] = parseAffix(specVal, "suffix")
					end
				elseif specName == "Sealed" then
					self.affixes[5] = parseAffix(specVal, "sealed")
				elseif specName == "Corrupted" then
					self.affixes[6] = parseAffix(specVal, "corrupted")
					self.corrupted = true
				elseif specName == "Implicits" then
					implicitLines = specToNumber(specVal) or 0
					gameModeStage = "EXPLICIT"
				elseif specName == "Source" then
					self.source = specVal
				elseif specName == "Note" then
					self.note = specVal
				elseif not (self.name:match(specName) and self.name:match(specVal)) then
					foundExplicit = true
					gameModeStage = "EXPLICIT"
				end
			end
			if not specName or foundExplicit or foundImplicit then
				local modLine = { modTags = {} }
				line = line:gsub("{(%a*):?([^}]*)}", function(k,val)
					if k == "range" then
						modLine.range = tonumber(val)
					elseif k == "scalar" then
						modLine.valueScalar = tonumber(val)
					elseif k == "rounding" then
						modLine.rounding = val
					elseif lineFlags[k] then
						modLine[k] = true
					end

					return ""
				end)

				line = line:gsub(" %((%l+)%)", function(k)
					if lineFlags[k] then
						modLine[k] = true
					end
					return ""
				end)

				local baseName
				if not self.base and (self.rarity == "NORMAL" or self.rarity == "MAGIC") then
					-- Exact match (affix-less magic and normal items)
					if data.itemBases[self.name] then
						baseName = self.name
					else
						local bestMatch = {length = -1}
						-- Partial match (magic items with affixes)
						for itemBaseName, baseData in pairs(data.itemBases) do
							local s, e = self.name:find(itemBaseName, 1, true)
							if s and e and (e-s > bestMatch.length) then
								bestMatch.match = itemBaseName
								bestMatch.length = e-s
								bestMatch.e = e
								bestMatch.s = s
							end
						end
						if bestMatch.match then
							self.namePrefix = self.name:sub(1, bestMatch.s - 1)
							self.nameSuffix = self.name:sub(bestMatch.e + 1)
							baseName = bestMatch.match
						end
					end
					self.name = self.name:gsub(" %(.+%)","")
				end
				if not baseName then
					baseName = line
				end
				local base = data.itemBases[baseName]
				if base then
					-- Items with variants can have multiple bases
					self.baseLines[baseName] = { line = baseName, variantList = modLine.variantList }
					-- Set the actual base if variant matches or doesn't have variants
					self.baseName = baseName
					self.title = self.name
					self.type = base.type
					self.base = base
					self.compatibleAffixes = (self.base.subType and data.itemMods[self.base.type..self.base.subType])
							or data.itemMods[self.base.type]
							or data.itemMods.Item
					-- Base lines don't need mod parsing, skip it
					goto continue
				end
				if modLine.implicit then
					foundImplicit = true
					gameModeStage = "IMPLICIT"
				end
				modLine.implicit = modLine.implicit or (not modLine.unique and #self.implicitModLines < implicitLines)
				modLine.range = modLine.range or main.defaultItemAffixQuality
				local rangedLine = itemLib.applyRange(line, modLine.range, modLine.valueScalar, modLine.rounding)
				local modList, extra = modLib.parseMod(rangedLine)

				local modLines

				if modLine.implicit or (not modLine.unique and #self.implicitModLines < implicitLines) then
					modLines = self.implicitModLines
				else
					modLines = self.explicitModLines
				end

				modLine.line = line
				if modList then
					modLine.modList = modList
					modLine.extra = extra
					t_insert(modLines, modLine)
					if mode == "GAME" then
						if gameModeStage == "FINDIMPLICIT" then
							gameModeStage = "IMPLICIT"
						elseif gameModeStage == "FINDEXPLICIT" then
							foundExplicit = true
							gameModeStage = "EXPLICIT"
						elseif gameModeStage == "EXPLICIT" then
							foundExplicit = true
						end
					else
						foundExplicit = true
					end
				elseif mode == "GAME" then
					if gameModeStage == "IMPLICIT" or gameModeStage == "EXPLICIT" or (gameModeStage == "FINDIMPLICIT" and (not data.itemBases[line]) and not (self.name == line) and not (self.base and (line == self.base.type or self.base.subType and line == self.base.subType .. " " .. self.base.type))) then
						modLine.modList = { }
						modLine.extra = line
						t_insert(modLines, modLine)
					elseif gameModeStage == "FINDEXPLICIT" then
						gameModeStage = "DONE"
					end
				elseif foundExplicit then
					modLine.modList = { }
					modLine.extra = line
					t_insert(modLines, modLine)
				end
			end
		end
		::continue::
		l = l + 1
	end
	if self.baseName and self.title then
		self.name = self.title
	end
	if self.base and not self.requirements.level then
		self.requirements.level = self.base.req.level
	end
	-- Idol bases are always rarityType IDOL; display rarity stays UNIQUE for unique idols
	if self.type and self.type:match("Idol$") then
		self.rarityType = "IDOL"
		if self.rarity ~= "UNIQUE" then
			self.rarity = "IDOL"
		end
		-- Only one prefix and suffix allowed for idols
		self.affixLimit = 2
	else
		self.affixLimit = 4
	end
	self:UpdateDisplayRarity()
	self:BuildModList()
end

-- Compute display rarity based on affix count and tiers
function ItemClass:UpdateDisplayRarity()
	if self.rarityType == "BASIC" then
		local affixCount = 0
		local hasExaltedTier = false
		for _, affix in ipairs(self.affixes) do
			if affix.modId then
				affixCount = affixCount + 1
				local tierIndex = tonumber(affix.modId:match("_(%d+)$"))
				if tierIndex and tierIndex >= 5 then
					hasExaltedTier = true
				end
			end
		end
		if hasExaltedTier then
			self.rarity = "EXALTED"
		elseif affixCount >= 3 then
			self.rarity = "RARE"
		elseif affixCount >= 1 then
			self.rarity = "MAGIC"
		else
			self.rarity = "NORMAL"
		end
	elseif self.rarityType == "UNIQUE" then
		-- Unique with crafted affixes becomes Legendary
		local hasAffix = false
		for _, affix in ipairs(self.affixes) do
			if affix.modId then
				hasAffix = true
				break
			end
		end
		self.rarity = hasAffix and "LEGENDARY" or "UNIQUE"
	end
end

function ItemClass:BuildRaw()
	local rawLines = { }
	t_insert(rawLines, "Rarity: " .. (self.rarity or "BASIC"))
	if self.title then
		t_insert(rawLines, self.title)
		t_insert(rawLines, self.baseName)
	else
		t_insert(rawLines, (self.namePrefix or "") .. self.baseName .. (self.nameSuffix or ""))
	end
	if self.uniqueID then
		t_insert(rawLines, "Unique ID: " .. self.uniqueID)
	end
	for i, affix in ipairs(self.affixes or { }) do
		if affix.modId then
			local line = ""
			if affix.prefix then
				line = "Prefix: "
			elseif affix.suffix then
				line = "Suffix: "
			elseif affix.sealed then
				line = "Sealed: "
			elseif affix.corrupted then
				line = "Corrupted: "
			end
			if affix.range then
				line = line .. "{range:" .. round(affix.range,3) .. "}"
			end
			line = line .. affix.modId
			t_insert(rawLines, line)
		end
	end
	local function writeModLine(modLine)
		local line = modLine.line
		if modLine.rounding and itemLib.hasRange(line) then
			line = "{rounding:" .. modLine.rounding .. "}" .. line
		end
		if modLine.valueScalar and modLine.valueScalar ~= 1 then
			line = "{scalar:" .. round(modLine.valueScalar, 3) .. "}" .. line
		end
		if modLine.range ~= nil and itemLib.hasRange(line) then
			line = "{range:" .. round(modLine.range, 3) .. "}" .. line
		end
		if modLine.unique then
			line = "{unique}" .. line
		end
		if modLine.custom then
			line = "{custom}" .. line
		end
		if modLine.corrupted then
			line = "{corrupted}" .. line
		end
		if modLine.sealed then
			line = "{sealed}" .. line
		end
		if modLine.variantList then
			local varSpec
			for varId in pairs(modLine.variantList) do
				varSpec = (varSpec and varSpec .. "," or "") .. varId
			end
			line = "{variant:" .. varSpec .. "}" .. line
		end
		if modLine.modTags and #modLine.modTags > 0 then
			line = "{tags:" .. table.concat(modLine.modTags, ",") .. "}" .. line
		end
		t_insert(rawLines, line)
	end
	if self.requirements and self.requirements.level then
		t_insert(rawLines, "LevelReq: " .. self.requirements.level)
	end
	if self.classRestriction then
		t_insert(rawLines, "Requires Class " .. self.classRestriction)
	end
	t_insert(rawLines, "Implicits: " .. #self.implicitModLines)
	for _, modLine in ipairs(self.implicitModLines) do
		writeModLine(modLine)
	end
	for _, modLine in ipairs(self.explicitModLines) do
		writeModLine(modLine)
	end
	return table.concat(rawLines, "\n")
end

function ItemClass:BuildAndParseRaw()
	local raw = self:BuildRaw()
	self:ParseRaw(raw)
end

-- Rebuild explicit modifiers using the item's affixes
function ItemClass:Craft()
	-- Save off any custom or unique mods so they can be re-added at the end
	local savedMods = {}
	for _, mod in ipairs(self.explicitModLines) do
		if mod.custom or mod.unique then
			t_insert(savedMods, mod)
		end
	end

	wipeTable(self.explicitModLines)
	self.namePrefix = ""
	self.nameSuffix = ""
	self.requirements.level = self.base.req.level
	local function writeModLine(affix)
		local mod = data.itemMods.Item[affix.modId]
		if mod then
			for _, line in ipairs(mod) do
				local modScalar = 1 + self.base.affixEffectModifier
				if mod.standardAffixEffectModifier then
					modScalar = modScalar - mod.standardAffixEffectModifier
				end
				local modLine = { line = line, range = affix.range, valueScalar = modScalar }
				if affix.prefix then
					modLine.prefix = true
				elseif affix.suffix then
					modLine.suffix = true
				elseif affix.sealed then
					modLine.sealed = true
				elseif affix.corrupted then
					modLine.corrupted = true
				end
				t_insert(self.explicitModLines, modLine)
			end
		end
	end
	for _, affix in ipairs(self.affixes) do
		writeModLine(affix)
	end

	-- Restore the custom and unique mods
	for _, mod in ipairs(savedMods) do
		t_insert(self.explicitModLines, mod)
	end

	self:BuildAndParseRaw()
end

-- Return the name of the slot this item is equipped in
function ItemClass:GetPrimarySlot()
	if self.base.weapon then
		return "Weapon 1"
	elseif self.type == "Quiver" or self.type == "Shield" or self.type == "Off-Hand Catalyst" then
		return "Weapon 2"
	elseif self.type == "Ring" then
		return "Ring 1"
	else
		return self.type
	end
end

-- Calculate local modifiers, and removes them from the modifier list
-- To be considered local, a modifier must be an exact flag match, and cannot have any tags (e.g. conditions, multipliers)
-- Only the InSlot tag is allowed (for Adds x to x X Damage in X Hand modifiers)
local function calcLocal(modList, name, type, flags)
	local result
	if type == "FLAG" then
		result = false
	elseif type == "MORE" then
		result = 1
	else
		result = 0
	end
	local i = 1
	while modList[i] do
		local mod = modList[i]
		if mod.name == name and mod.type == type and mod.flags == flags and mod.keywordFlags == 0 and (not mod[1] or mod[1].type == "InSlot") then
			if type == "FLAG" then
				result = result or mod.value
			-- convert MORE to times multiplier, e.g. 50% more = 1.5x, result = 1.5
			elseif type == "MORE" then
				result = result * ((100 + mod.value) / 100)
			else
				result = result + mod.value
			end
			t_remove(modList, i)
		else
			i = i + 1
		end
	end
	return result
end

-- Build list of modifiers in a given slot number (1 or 2) while applying local modifiers and adding quality
function ItemClass:BuildModListForSlotNum(baseList, slotNum)
	local slotName = self:GetPrimarySlot()
	if slotNum == 2 then
		slotName = slotName:gsub("1", "2")
	end
	local modList = new("ModList")
	for _, baseMod in ipairs(baseList) do
		local mod = copyTable(baseMod)
		local add = true
		for _, tag in ipairs(mod) do
			if tag.type == "SlotNumber" or tag.type == "InSlot" then
				if tag.num ~= slotNum then
					add = false
					break
				end
			end
			for k, v in pairs(tag) do
				if type(v) == "string" then
					tag[k] = v:gsub("{SlotName}", slotName)
							  :gsub("{Hand}", (slotNum == 1) and "MainHand" or "OffHand")
							  :gsub("{OtherSlotNum}", slotNum == 1 and "2" or "1")
				end
			end
		end
		if add then
			mod.sourceSlot = slotName
			modList:AddMod(mod)
		end
	end
	if #self.sockets > 0 then
		local multiName = {
			R = "Multiplier:RedSocketIn"..slotName,
			G = "Multiplier:GreenSocketIn"..slotName,
			B = "Multiplier:BlueSocketIn"..slotName,
			W = "Multiplier:WhiteSocketIn"..slotName,
		}
		for _, socket in ipairs(self.sockets) do
			if multiName[socket.color] then
				modList:NewMod(multiName[socket.color], "BASE", 1, "Item Sockets")
			end
		end
	end
	if self.base.weapon then
		local weaponData = { }
		self.weaponData[slotNum] = weaponData
		weaponData.type = self.base.type
		weaponData.name = self.name
		weaponData.AttackSpeedInc = calcLocal(modList, "Speed", "INC", ModFlag.Attack)
		weaponData.AttackRate = round(self.base.weapon.AttackRateBase * (1 + weaponData.AttackSpeedInc / 100), 2)
		weaponData.rangeBonus = calcLocal(modList, "WeaponRange", "BASE", 0) + 10 * calcLocal(modList, "WeaponRangeMetre", "BASE", 0) + m_floor(self.quality / 10 * calcLocal(modList, "AlternateQualityLocalWeaponRangePer10Quality", "BASE", 0))
		weaponData.range = self.base.weapon.Range + weaponData.rangeBonus
	end
	return { unpack(modList) }
end

-- Build lists of modifiers for each slot the item can occupy
function ItemClass:BuildModList()
	if not self.base then
		return
	end
	local baseList = new("ModList")
	if self.base.weapon then
		self.weaponData = { }
	end
	self.baseModList = baseList
	self.rangeLineList = { }
	self.modSource = "Item:"..(self.id or -1)..":"..self.name
	local function processModLine(modLine)
		if modLine.range ~= nil and itemLib.hasRange(modLine.line) then
			t_insert(self.rangeLineList, modLine)
		end
		if not modLine.extra then
			for _, mod in ipairs(modLine.modList) do
				mod = modLib.setSource(mod, self.modSource)
				baseList:AddMod(mod)
			end
		end
	end
	for _, modLine in ipairs(self.implicitModLines) do
		processModLine(modLine)
	end
	for _, modLine in ipairs(self.explicitModLines) do
		processModLine(modLine)
	end
	self.grantedSkills = { }
	for _, skill in ipairs(baseList:List(nil, "ExtraSkill")) do
		if skill.name ~= "Unknown" then
			t_insert(self.grantedSkills, {
				skillId = skill.skillId,
				level = skill.level,
				noSupports = skill.noSupports,
				source = self.modSource,
				triggered = skill.triggered,
				triggerChance = skill.triggerChance,
			})
		end
	end
	self.modList = baseList
end
