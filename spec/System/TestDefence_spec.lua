describe("TestDefence", function()
    before_each(function()
        newBuild()
    end)

    it("no armour max hits #wip", function()
        for _, damageType in ipairs(DamageTypes) do
            assert.are.equals(110, round(build.calcsTab.calcsOutput[damageType .. "MaximumHitTaken"]))
        end
    end)

    it("armoured max hits #wip", function()
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
end)
