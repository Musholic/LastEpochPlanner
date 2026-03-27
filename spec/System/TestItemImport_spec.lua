describe("Offline Item Import", function()
    before_each(function()
        newBuild()
    end)

    it("should process the first blessing correctly", function()
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
            ["base"] = {
                ["affixEffectModifier"] = 0,
                ["baseTypeID"] = 34,
                ["implicits"] = {
                    [1] = '(16-22)% Increased Unique Drop Rate',
                },
                ["req"] = {
                    ["level"] = 0 },
                ["subTypeID"] = 112,
                ["type"] = 'Blessing'
            },
            ["baseName"] = 'Grand Winds of Fortune',
            ["explicitMods"] = {},
            ["implicitMods"] = {
                [1] = '{range: 255}(16-22)% Increased Unique Drop Rate',
            },
            ["name"] = 'Grand Winds of Fortune',
            ["prefixes"] = {},
            ["rarity"] = 'RARE',
            ["rarityType"] = 'BASIC',
            ["slotName"] = 'Blessing 1',
            ["suffixes"] = {}
        }
        assert.are.same(expected, item)
    end)

    it("should process the seventh blessing correctly", function()
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

    it("should process the last blessing correctly", function()
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

    it("should process last idol slot correctly", function()
        local itemDataJson = [[
        {
          "itemData": null,
          "data": [
            5, 51, 219, 26, 1, 2, 9, 255, 255, 255, 0, 2, 3, 75, 255, 3, 86, 255, 0
          ],
          "inventoryPosition": { "x": 3, "y": 4 },
          "quantity": 1,
          "containerID": 29,
          "formatVersion": 2
        }
        ]]
        local item = build.importTab:processItemData(processJson(itemDataJson))

        local expected = {
            ["base"] = {
                ["affixEffectModifier"] = -0.83,
                ["baseTypeID"] = 26,
                ["implicits"] = { },
                ["req"] = {
                  ["level"] = 0 },
                ["subTypeID"] = 1,
                ["type"] = 'Minor Idol' },
              ["baseName"] = 'Minor Weaver Idol',
              ["explicitMods"] = { },
              ["implicitMods"] = { },
              ["name"] = 'Minor Weaver Idol',
              ["prefixes"] = {
                [1] = {
                    ["modId"] = '854_0',
                    ["range"] = 255
                }
              },
              ["rarity"] = 'IDOL',
              ["rarityType"] = 'IDOL',
              ["slotName"] = 'Idol 20',
              ["suffixes"] = {
                [1] = {
                    ["modId"] = '843_0',
                    ["range"] = 255
                }
              }
        }
        assert.are.same(expected, item)
    end)

    it("should process idol altar slot correctly", function()
        local itemDataJson = [[
        {
        "itemData": null,
        "data": [
            5,
            70,
            46,
            41,
            5,
            2,
            16,
            60,
            44,
            63,
            0,
            67,
            36,
            81,
            10,
            36,
            73,
            191,
            4,
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
          ["base"] = {
            ["affixEffectModifier"] = 0,
            ["baseTypeID"] = 41,
            ["implicits"] = {
              [1] = '{rounding:Integer}+(6-10) Health per Equipped Omen Idol'
            },
            ["req"] = {
              ["level"] = 0
            },
            ["subTypeID"] = 5,
            ["type"] = 'Idol Altar'
          },
          ["baseName"] = 'Visage Altar',
          ["explicitMods"] = { },
          ["implicitMods"] = {
            [1] = '{range: 60}{rounding:Integer}+(6-10) Health per Equipped Omen Idol'
          },
          ["name"] = 'Visage Altar',
          ["prefixes"] = {
            [1] = {
              ["modId"] = '1097_2',
              ["range"] = 191
            }
          },
          ["rarity"] = 'RARE',
          ["rarityType"] = 'BASIC',
          ["slotName"] = 'Idol Altar',
          ["suffixes"] = {
            [1] = {
              ["modId"] = '1105_2',
              ["range"] = 10
            },
            [2] = {
              ["modId"] = '1094_0',
              ["range"] = 51
            }
          }
        }
        assert.are.same(expected, item)
    end)

    it("should process armor with corrupted affix", function()
        local itemDataJson = [[
        {
          "itemData": null,
          "data": [
            5,
            12,
            166,
            1,
            59,
            4,
            16,
            60,
            134,
            122,
            0,
            69,
            19,
            251,
            33,
            0,
            45,
            176,
            0,
            19,
            205,
            33,
            75,
            177,
            1,
            249,
            57,
            0
          ],
          "inventoryPosition": {
            "x": 0,
            "y": 0
          },
          "quantity": 1,
          "containerID": 3,
          "formatVersion": 2
        }
        ]]
        local itemData = build.importTab:processItemData(processJson(itemDataJson))
        local item = build.importTab:BuildItem(itemData)
        local rawItem = item:BuildRaw()
        local expected = [[Rarity: RARE
Worn Plate
Worn Plate
Crafted: true
Prefix: {range:176}45_0
Prefix: {range:205}19_0
Prefix: None
Suffix: {range:33}1019_1
Suffix: {range:177}331_2
Suffix: {range:57}505_0
LevelReq: 4
Implicits: 1
+75 Armor
{range:176}{scalar:1.5}+(5-9)% Physical Resistance
{range:205}{scalar:1.5}+(5-9)% Poison Resistance
{scalar:1.5}7% increased Health
{scalar:1.5}2% of Health Regen also applies to Ward
{scalar:1.5}6% increased Mana
{scalar:1.5}+1 Vitality]]

        assert.are.same(expected, rawItem)

        -- Also check if the mod list is computed correctly for increased life
        local itemModList = item.modList
        assert.equal(10, itemModList:Sum("INC", nil, "Life"))

    end)
end)
