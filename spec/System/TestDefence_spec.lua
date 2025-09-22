describe("TestDefence", function()
    before_each(function()
        newBuild()
    end)

    it("no armour max hits", function()
        for _, damageType in ipairs(DamageTypes) do
            assert.are.equals(110, round(build.calcsTab.calcsOutput[damageType .. "MaximumHitTaken"]))
        end
    end)

    it("armoured max hits", function()
        build.configTab.input.enemyLevel = 100
        build.configTab.input.customMods = [[
        +890 health
        +3100 to armour
        -2 Strength
        ]]
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(1000, build.calcsTab.calcsOutput.Life)
        assert.are.equals(1978, round(build.calcsTab.calcsOutput.PhysicalMaximumHitTaken))
        for _, damageType in ipairs(DamageTypes) do
            if damageType ~= "Physical" then
                assert.are.equals(1529, round(build.calcsTab.calcsOutput[damageType .. "MaximumHitTaken"]))
            end
        end
    end)


    it("ward regen", function()
        build.configTab.input.customMods = [[
        +10 Ward per Second
        ]]
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(10, build.calcsTab.calcsOutput.WardPerSecond)
        assert.are.equals(0, build.calcsTab.calcsOutput.WardDecayThreshold)
        assert.are.equals(0, build.calcsTab.calcsOutput.WardRetention)
        assert.are.equals(59, build.calcsTab.calcsOutput.Ward)
    end)

    it("ward regen and ward decay threshold", function()
        build.configTab.input.customMods = [[
        +10 Ward per Second
        +100 Ward Decay Threshold
        ]]
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(10, build.calcsTab.calcsOutput.WardPerSecond)
        assert.are.equals(100, build.calcsTab.calcsOutput.WardDecayThreshold)
        assert.are.equals(0, build.calcsTab.calcsOutput.WardRetention)
        assert.are.equals(159, build.calcsTab.calcsOutput.Ward)
    end)

    it("ward regen and retention", function()
        build.configTab.input.customMods = [[
        +10 Ward per Second
        +100% Ward Retention
        ]]
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(10, build.calcsTab.calcsOutput.WardPerSecond)
        assert.are.equals(0, build.calcsTab.calcsOutput.WardDecayThreshold)
        assert.are.equals(100, build.calcsTab.calcsOutput.WardRetention)
        assert.are.equals(84, build.calcsTab.calcsOutput.Ward)
    end)
end)
