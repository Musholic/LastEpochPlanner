describe("TestSkills #skills", function ()
	before_each(function ()
		newBuild()
	end)

	it("Test melee skill with cooldown and basic weapon", function ()
		build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        +8 Strength
        +23 Melee Damage
        100% increased Critical Strike Chance
        +10 Melee Physical Damage]])
		build.itemsTab:AddDisplayItem()

		-- Use melee skill Lunge
		build.skillsTab:SelSkill(1, "Lunge")
		runCallback("OnFrame")

		local castSpeed = 1 / build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.stats.cooldown
		assert.are.equals(10, build.calcsTab.mainOutput.Str)
		assert.are.equals((2 + 10 + 23) * (1 + 0.04 * 10) * 1.1 * castSpeed, build.calcsTab.mainOutput.TotalDPS)
	end)

	it("Test spell skill with basic weapon", function ()
		build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        100% increased Fire Damage
        100% more Fire Damage
        +30 Spell Damage
        +10 Spell Fire Damage]])
		build.itemsTab:AddDisplayItem()

		-- Use fire skill Fireball with 25 base fire damage
		build.skillsTab:SelSkill(1, "Fireball")

		runCallback("OnFrame")

		local castSpeed = 1 / build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.castTime
		assert.are.equals((25 + (10 + 30) * 1.25) * 4 * 1.05 * castSpeed, build.calcsTab.mainOutput.TotalDPS)
	end)

	it("Test dot spell skill with basic weapon", function ()
		build.itemsTab:CreateDisplayItemFromRaw([[Rarity: RARE
        Brass Sceptre
        Brass Sceptre
        +10 Spell Damage
        20% increased Spell Damage
        20% increased Damage Over Time]])
		build.itemsTab:AddDisplayItem()

		-- Use skill Wandering Spirits
		build.skillsTab:SelSkill(1, "WanderingSpirits")

		runCallback("OnFrame")

		assert.are.equals(31.02, round(build.calcsTab.mainOutput.TotalDPS, 2))
	end)

	it("Test melee skill with weapon attack speed", function ()
		build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        +8 Strength
        +48 Melee Damage]])
		build.itemsTab:AddDisplayItem()

		-- Use melee skill Rive
		build.skillsTab:SelSkill(1, "Rive1")
		runCallback("OnFrame")

		local castSpeed = 1 / build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.castTime
		assert.are.equals(round((2 + 48 * 1.25) * (1 + 0.04 * 10) * 1.05 * 0.92 * castSpeed, 4),
			round(build.calcsTab.mainOutput.TotalDPS, 4))
	end)

	it("Test removal of triggered skill should not affect DPS", function ()
		-- Use skill Smite and includes it in full DPS
		build.skillsTab:SelSkill(1, "Smite")
		build.skillsTab.socketGroupList[1].includeInFullDPS = true
		runCallback("OnFrame")
		-- The original Full DPS
		assert.are.equals(48.048, round(build.calcsTab.mainOutput.FullDPS, 4))

		-- Add a mod that triggers the Axe Throw skill then remove it
		build.configTab.input.customMods = "8% Chance To Cast Axe Throw On Hit"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.configTab.input.customMods = "8% Chance To Cast Axe Throw On Hit\n10% chance to Ignite on Hit"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		build.configTab.input.customMods = ""
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- The Full DPS value should not be affected by the removed mod
		assert.are.equals(48.048, round(build.calcsTab.mainOutput.FullDPS, 4))
	end)

	it("Test skill damage conversion", function ()
		-- Use skill Harvest and includes it in full DPS
		build.spec:SelectClass(3)
		build.skillsTab:SelSkill(1, "Harvest")
		build.spec:BuildAllDependsAndPaths()
		-- Add a bit of dexterity to test added damage of harvest skill
		build.configTab.input.customMods = "+10 Dexterity"
		build.configTab:BuildModList()
		build.skillsTab.socketGroupList[1].includeInFullDPS = true
		runCallback("OnFrame")
		-- The original Full DPS
		assert.are.equals(43.91, round(build.calcsTab.mainOutput.FullDPS, 2))

		-- Select the skill node that convert Necrotic damage to Cold
		local node = build.spec.nodes["ha84-29"]
		build.spec:AllocNode(node)
		build.buildFlag = true
		runCallback("OnFrame")

		assert.are.equals(0, round(build.calcsTab.mainOutput.NecroticDamageBase, 2))
		assert.are.equals(22, round(build.calcsTab.mainOutput.ColdDamageBase, 2))
		assert.are.equals(54.01, round(build.calcsTab.mainOutput.FullDPS, 2))
	end)
end)

-- Check that at least all skills can load without crash
expose("test all skills #allSkills", function ()
	newBuild()
	runCallback("OnFrame")
	for classId, class in pairs(build.latestTree.classes) do
		build.spec:SelectClass(classId)
		runCallback("OnFrame")
		local className = class.name
		local skillList = build.spec.curClass.skills
		for _, skill in ipairs(skillList) do
			it(skill.label .. " for class " .. className .. " #" .. skill.name, function ()
				build.skillsTab:SelSkill(1, skill.name)
				runCallback("OnFrame")
			end)
		end
	end
end)
