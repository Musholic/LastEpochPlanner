local function fetchBuilds(path, buildList)
    buildList = buildList or {}
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..'/'..file
            local attr = lfs.attributes (f)
            assert(type(attr) == "table")
            if attr.mode == "directory" then
                fetchBuilds(f, buildList)
            else
                if file:match("^.+(%..+)$") == ".json" then
                    local fileHnd, errMsg = io.open(f, "r")
                    if not fileHnd then
                        return nil, errMsg
                    end
                    local fileText = fileHnd:read("*a")
                    fileHnd:close()
                    buildList[f] = fileText
                end
            end
        end
    end
    return buildList
end

local function formatXmlFile(filepath)
    local command = "xmllint --c14n " .. filepath

    -- Open the command process for reading ('r')
    local handle = io.popen(command, 'r')
    if not handle then
        return nil, "Failed to run xmllint. Is it installed and in your PATH?"
    end

    -- Read the entire output from the command
    local result = handle:read("*a")
    handle:close()

    local fileHnd, errMsg = io.open(filepath:gsub("-unformatted", ""), "w")
    fileHnd:write(result)
    fileHnd:close()
end

function buildTable(tableName, values, string)
    string = string or ""
    string = string .. tableName .. " = {"
    -- Sort by keys
    local keys = {}
    for k in pairs(values) do table.insert(keys, k) end
    table.sort(keys)
    for _, key in pairs(keys) do
        local value = values[key]
        if type(value) == "table" then
            buildTable(key, value, string)
        elseif type(value) == "boolean" then
            string = string .. "[\"" .. key .. "\"] = " .. (value and "true" or "false") .. ",\n"
        elseif type(value) == "string" then
            string = string .. "[\"" .. key .. "\"] = \"" .. value .. "\",\n"
        else
            string = string .. "[\"" .. key .. "\"] = " .. round(value, 4) .. ",\n"
        end
    end
    string = string .. "}\n"
    return string
end

local buildList = fetchBuilds("../spec/TestBuilds")
for filename, importCode in pairs(buildList) do
    print("Loading build " .. filename)
    loadBuildFromXML(importCode, filename)
    local fileHnd, errMsg = io.open(filename:gsub("^(.+)%..+$", "%1.lua"), "w+")
    fileHnd:write("return {\n    ")
    fileHnd:write(buildTable("output", build.calcsTab.mainOutput) .. "\n}")
    fileHnd:close()
    build.dbFileName = filename:gsub("^(.+)%..+$", "%1-unformatted.xml")
    build:SaveDBFile()
    -- Format/order the XML file to easily see differences with previous generations
    formatXmlFile(build.dbFileName)
end
