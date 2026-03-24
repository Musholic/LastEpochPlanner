local function fetchBuilds(path, buildList)
    buildList = buildList or {}
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path .. '/' .. file
            local attr = lfs.attributes(f)
            assert(type(attr) == "table")
            if attr.mode == "directory" then
                fetchBuilds(f, buildList)
            elseif file:match("^.+(%..+)$") == ".lua" then
                buildList[file] = LoadModule(f)
                local fileHnd = io.open(f:gsub(".lua$", ".xml"), "r")
                local fileText = fileHnd:read("*a")
                fileHnd:close()
                buildList[file].xml = fileText
            end
        end
    end
    return buildList
end

local function roundValues(value, digits)
    digits = digits or 4
    if type(value) == "number" then
        return "" .. round(value, digits)
    elseif type(value) == "table" then
        local result = {}
        for k, v in pairs(value) do
            result[k] = roundValues(v, digits)
        end
        return result
    else
        return value
    end
end

expose("test all builds #builds", function()
    local buildList = fetchBuilds("../spec/TestBuilds")
    for buildName, testBuild in pairs(buildList) do
        loadBuildFromXML(testBuild.xml, buildName)
        testBuild.result = {}
        for key, value in pairs(testBuild.output) do
            -- Have to assign it to a temporary table here, as the tests will run later, when the 'build' isn't changing
            testBuild.result[key] = build.calcsTab.mainOutput[key]
            it("on build: " .. buildName .. ", key: " .. key, function()
                assert.are.same(roundValues(value), roundValues(testBuild.result[key]))
            end)
        end
    end
end)
