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

local function buildTable(tableName, values, output, indentLevel)
    output = output or {}
    indentLevel = indentLevel or 1
    local indent = string.rep("  ", indentLevel)
    local nextIndent = string.rep("  ", indentLevel + 1)
    local keyText
    if type(tableName) == "number" then
        keyText = "[" .. tableName .. "]"
    else
        keyText = "[\"" .. tableName .. "\"]"
    end
    table.insert(output, indent .. keyText .. " = {")

    for key, value in pairsSortByKey(values) do
        if type(key) == "number" then
            keyText = "[" .. key .. "]"
        else
            keyText = "[\"" .. key .. "\"]"
        end
        local linePrefix = nextIndent .. keyText .. " = "
        if type(value) == "table" then
            buildTable(key, value, output, indentLevel + 1)
        elseif type(value) == "boolean" then
            table.insert(output, linePrefix .. (value and "true" or "false") .. ",")
        elseif type(value) == "string" then
            table.insert(output, linePrefix .. "\"" .. value .. "\",")
        else
            table.insert(output, linePrefix .. round(value, 4) .. ",")
        end
    end

    table.insert(output, indent .. "},")
    return table.concat(output, "\n")
end

local buildList = fetchBuilds("../spec/TestBuilds")
for filename, importCode in pairs(buildList) do
    print("Loading build " .. filename)
    -- If the import code starts with EPOCH, then it's an offline build
    if importCode:sub(1, 5) == "EPOCH" then
        loadBuildFromJSON(importCode:sub(6))
    else
        loadBuildFromXML(importCode, filename)
    end
    local fileHnd, errMsg = io.open(filename:gsub("^(.+)%..+$", "%1.lua"), "w+")
    fileHnd:write("return {\n")
    fileHnd:write(buildTable("output", build.calcsTab.mainOutput) .. "\n}")
    fileHnd:close()
    build.dbFileName = filename:gsub("^(.+)%..+$", "%1-unformatted.xml")
    build:SaveDBFile()
    -- Format/order the XML file to easily see differences with previous generations
    formatXmlFile(build.dbFileName)
end
