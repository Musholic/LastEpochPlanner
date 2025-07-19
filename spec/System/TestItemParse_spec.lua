describe("TestItemParse #itemParse", function()
    it("Creating unique", function()
        local item = new("Item", "", "UNIQUE")
        item.title = "Calamity"
        item.baseName = "Jewelled Circlet"
        item.explicitModLines = { { line = "+(10-20) Armor" } }
        item:BuildAndParseRaw()
        --print(item:BuildRaw())
        assert.are.equals("Calamity", item.name)
    end)

    it("Test idol with multiline affixes + roundings", function()
        newBuild()
        build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Stout Weaver Idol
        Stout Weaver Idol
        Unique ID: Idol 4
        Crafted: true
        Prefix: {range:205}890_0
        Prefix: None
        Prefix: None
        Suffix: {range:0}880_0
        Suffix: None
        Suffix: None
        LevelReq: 0
        Implicits: 0
        {range:205}{rounding:Integer}+(15-20) Ward per Second
        {range:205}+(8-16)% Ward Retention
        {range:0}{rounding:Integer}(9-20) Health Gain on Kill
        {range:0}{rounding:Integer}(5-6)% increased Health]])
        build.itemsTab:AddDisplayItem()

        runCallback("OnFrame")

        assert.are.equals(5, build.calcsTab.mainEnv.modDB:Sum("INC", nil, "Life"))
    end)
end)
