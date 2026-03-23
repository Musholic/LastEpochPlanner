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
              ["rarity"] = 'RARE',
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
end)
