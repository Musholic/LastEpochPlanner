describe("Offline Item Import", function ()
	before_each(function ()
		newBuild()
	end)

	it("should process the first blessing correctly", function ()
		local itemDataJson = [[
        {
          "itemData": null,
          "data": [5, 92, 13, 34, 112, 0, 0, 255, 255, 255, 0, 0, 0],
          "inventoryPosition": { "x": 0, "y": 0 },
          "quantity": 1,
          "containerID": 33,
          "formatVersion": 2
        }
        ]]
		local item = build.importTab:processItemData(processJson(itemDataJson))

		local expected = {
			["affixes"] = {},
			["base"] = {
				["affixEffectModifier"] = 0,
				["baseTypeID"] = 34,
				["implicits"] = { [1] = '(16-22)% Increased Unique Drop Rate', },
				["req"] = { ["level"] = 0 },
				["subTypeID"] = 112,
				["type"] = 'Blessing'
			},
			["baseName"] = 'Grand Winds of Fortune',
			["explicitMods"] = {},
			["implicitMods"] = { [1] = '{range: 255}(16-22)% Increased Unique Drop Rate', },
			["name"] = 'Grand Winds of Fortune',
			["rarity"] = 'RARE',
			["rarityType"] = 'BASIC',
			["slotName"] = 'Blessing 1'
		}
		assert.are.same(expected, item)
	end)

	it("should process the seventh blessing correctly", function ()
		local itemDataJson = [[
        {
          "itemData": null,
          "data": [5, 85, 66, 34, 149, 0, 0, 255, 255, 255, 0, 0, 0],
          "inventoryPosition": { "x": 0, "y": 0 },
          "quantity": 1,
          "containerID": 39,
          "formatVersion": 2
        }
        ]]
		local item = build.importTab:processItemData(processJson(itemDataJson))

		assert.are.equals("Grand Resolve of Humanity", item.name)
		assert.are.equals("Blessing 7", item.slotName)
	end)

	it("should process the last blessing correctly", function ()
		local itemDataJson = [[
        {
          "itemData": null,
          "data": [5, 81, 74, 34, 209, 0, 0, 255, 255, 255, 0, 0, 0],
          "inventoryPosition": { "x": 0, "y": 0 },
          "quantity": 1,
          "containerID": 45,
          "formatVersion": 2
        }
        ]]
		local item = build.importTab:processItemData(processJson(itemDataJson))

		assert.are.equals("Grand Embers of Immortality", item.name)
		assert.are.equals("Blessing 10", item.slotName)
	end)

	it("should process last idol slot correctly", function ()
		local itemDataJson = [[
        {
          "itemData": null,
          "data": [
            5,
            51,
            219,
            26, -- 4: baseType
            1, -- 5: subType
            2, -- 6: rarity
            9,
            255,
            255,
            255,
            0,
            2,
            3,
            75,
            255,
            3,
            86,
            255,
            0
          ],
          "inventoryPosition": { "x": 3, "y": 4 },
          "quantity": 1,
          "containerID": 29,
          "formatVersion": 2
        }
        ]]
		local item = build.importTab:processItemData(processJson(itemDataJson))

		local expected = {
			["affixes"] = {
				[1] = { ["modId"] = '843_0', ["range"] = 255, ["suffix"] = true },
				[2] = { ["modId"] = '854_0', ["prefix"] = true, ["range"] = 255 }
			},
			["base"] = {
				["affixEffectModifier"] = -0.83,
				["baseTypeID"] = 26,
				["height"] = 1,
				["implicits"] = {},
				["req"] = { ["level"] = 0 },
				["subTypeID"] = 1,
				["type"] = 'Minor Idol',
				["width"] = 1
			},
			["baseName"] = 'Minor Weaver Idol',
			["explicitMods"] = {},
			["implicitMods"] = {},
			["name"] = 'Minor Weaver Idol',
			["rarity"] = 'IDOL',
			["rarityType"] = 'IDOL',
			["slotName"] = 'Idol 4,5'
		}
		assert.are.same(expected, item)
	end)

	it("should process idol altar slot correctly", function ()
		local itemDataJson = [[
        {
        "itemData": null,
        "data": [
            5,
            70,
            46,
            41,
            5,
            2, -- 6: rarity
            16,
            60, -- range1
            44,
            63,
            0,
            67, -- 12: nbAffixes
            36, -- affix1
            81,
            10,
            36, -- affix2
            73,
            191,
            4, -- affix3
            70,
            51,
            0
        ],
        "inventoryPosition": {
            "x": 0,
            "y": 0
        },
        "quantity": 1,
        "containerID": 123,
        "formatVersion": 2
        }
        ]]
		local item = build.importTab:processItemData(processJson(itemDataJson))

		local expected = {
			["affixes"] = {
				[1] = { ["modId"] = '1105_2', ["range"] = 10, ["sealed"] = true },
				[2] = { ["modId"] = '1097_2', ["prefix"] = true, ["range"] = 191 },
				[3] = { ["modId"] = '1094_0', ["range"] = 51, ["suffix"] = true }
			},
			["base"] = {
				["affixEffectModifier"] = 0,
				["baseTypeID"] = 41,
				["blockedCells"] = {
					[1] = { [1] = 0, [2] = 0 },
					[2] = { [1] = 0, [2] = 4 },
					[3] = { [1] = 1, [2] = 2 },
					[4] = { [1] = 3, [2] = 2 },
					[5] = { [1] = 4, [2] = 0 },
					[6] = { [1] = 4, [2] = 4 }
				},
				["implicits"] = { [1] = '{rounding:Integer}+(6-10) Health per Equipped Omen Idol' },
				["req"] = { ["level"] = 0 },
				["subTypeID"] = 5,
				["type"] = 'Idol Altar'
			},
			["baseName"] = 'Visage Altar',
			["explicitMods"] = {},
			["implicitMods"] = { [1] = '{range: 60}{rounding:Integer}+(6-10) Health per Equipped Omen Idol' },
			["name"] = 'Visage Altar',
			["rarity"] = 'RARE',
			["rarityType"] = 'BASIC',
			["slotName"] = 'Idol Altar'
		}
		assert.are.same(expected, item)
	end)

	it("should process shield with corrupted and sealed affixes", function ()
		local itemDataJson = [[
        {
			"itemData": null,
			"data": [
				5,
				68,
				184,
				18, -- 4: baseType
				4, -- 5: subType
				4, -- 6: rarity
				16,
				17, -- 8: range1
				131, -- 9: range2
				236,
				0,
				198, -- 12: nbAffixes
				64, -- 13: affixTier*16-affixId
				7, -- 14: affixId
				243, -- 15: affixRange
				68, -- 16: affix2
				57,
				180,
				16, -- affix3
				19,
				225,
				0, -- affix4
				45,
				193,
				48, -- affix5
				81,
				198,
				0, -- affix6
				89,
				31,
				0
			],
			"inventoryPosition": { "x": 0, "y": 0 },
			"quantity": 1,
			"containerID": 5,
			"formatVersion": 2
		}
        ]]
		local itemData = build.importTab:processItemData(processJson(itemDataJson))
		local item = build.importTab:BuildItem(itemData)
		local rawItem = item:BuildRaw()
		local expected = [[Rarity: RARE
Cavalier Shield
Cavalier Shield
Prefix: {range:225}19_1
Prefix: {range:193}45_0
Suffix: {range:198}81_3
Suffix: {range:31}89_0
Sealed: {range:243}7_4
Corrupted: {range:180}1081_4
LevelReq: 24
Implicits: 2
+22% Block Chance
{range:131}{rounding:Integer}+(350-500) Block Effectiveness
{range:225}{scalar:1.17}+(10-14)% Poison Resistance
{range:193}{scalar:1.17}+(5-9)% Physical Resistance
{range:198}{rounding:Integer}+(241-350) Block Effectiveness
{range:31}{scalar:0.42}{rounding:Integer}(10-19)% increased Melee Damage
{sealed}{range:243}{scalar:1.17}+(30-45)% Void Resistance
{corrupted}{range:180}(54-58)% chance to gain Haste for 5 seconds after you Block
{corrupted}11% increased Effect of Haste on You]]

		assert.are.same(expected, rawItem)
	end)

	it("should process axe with a missing affix but with corrupted and sealed affix", function ()
		local itemDataJson = [[
        {
			"itemData": null,
			"data": [
				5,
				80,
				119,
				5, -- 4: baseType
				3, -- 5: subType
				3, -- 6: rarity
				16,
				33, --8: range1
				91, -- 9: range2
				86,
				0,
				197,
				32,
				61, -- 14: affix (sealed)
				53,
				64,
				77, -- 17: affix2 (corrupted)
				166,
				0,
				63, -- 20: affix3
				51,
				32,
				91, -- 23: affix4
				60,
				16,
				76, -- 26: affix5
				171,
				0
			],
			"inventoryPosition": { "x": 0, "y": 0 },
			"quantity": 1,
			"containerID": 4,
			"formatVersion": 2
		}
        ]]
		local itemData = build.importTab:processItemData(processJson(itemDataJson))
		local item = build.importTab:BuildItem(itemData)
		local rawItem = item:BuildRaw()
		local expected = [[Rarity: RARE
Battle Axe
Battle Axe
Prefix: {range:60}91_2
Suffix: {range:51}63_0
Suffix: {range:171}76_1
Sealed: {range:53}61_2
Corrupted: {range:166}77_4
LevelReq: 24
Implicits: 2
+28 Melee Damage
{range:91}+(20-28)% Chance to inflict Bleed on Hit
{range:60}(76-95)% Increased Melee Stun Chance
{range:51}{rounding:Integer}+(3-6) Melee Physical Damage
{range:171}{rounding:Integer}+(7-10) Melee Void Damage
{sealed}{range:53}{scalar:1.75}{rounding:Integer}(22-30)% increased Poison Damage
{corrupted}{range:166}{rounding:Integer}+(21-26) Melee Fire Damage]]

		assert.are.same(expected, rawItem)
	end)
end)
