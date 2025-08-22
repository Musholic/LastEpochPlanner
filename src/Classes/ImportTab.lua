-- Last Epoch Planner
--
-- Module: Import Tab
-- Import/Export tab for the current build.
--
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local b_rshift = bit.rshift
local band = bit.band

local influenceInfo = itemLib.influenceInfo

local ImportTabClass = newClass("ImportTab", "ControlHost", "Control", function(self, build)
    self.ControlHost()
    self.Control()

    self.build = build

    self.isOnlineMode = false
    self.charImportMode = "GETACCOUNTNAME"
    self.charImportStatus = "Idle"
    self.controls.sectionCharImport = new("SectionControl", { "TOPLEFT", self, "TOPLEFT" }, 10, 18, 750, 260, "Character Import")
    self.controls.charImportStatusLabel = new("LabelControl", { "TOPLEFT", self.controls.sectionCharImport, "TOPLEFT" }, 6, 14, 200, 16, function()
        return "^7Character import status: " .. self.charImportStatus
    end)

    -- Stage: input account name
    self.controls.accountNameHeaderOffline = new("LabelControl", { "TOPLEFT", self.controls.sectionCharImport, "TOPLEFT" }, 6, 40, 200, 16, "^7To start importing an **offline** character, click Start Offline:")
    self.controls.accountNameHeaderOffline.shown = function()
        return self.charImportMode == "GETACCOUNTNAME"
    end
    self.controls.accountNameGoOffline = new("ButtonControl", { "TOPLEFT", self.controls.accountNameHeaderOffline, "BOTTOMLEFT" }, 0, 4, 100, 20, "Start Offline", function()
        self.isOnlineMode = false
        self:DownloadCharacterList()
    end)
    -- Stage: input account name (Online)
    self.controls.accountNameHeader = new("LabelControl", { "TOPLEFT", self.controls.accountNameGoOffline, "BOTTOMLEFT" }, 0, 4, 200, 16, "^7To start importing an Online character, click Start Online:")
    self.controls.accountNameHeader.shown = function()
        return self.charImportMode == "GETACCOUNTNAME"
    end
    self.controls.accountName = new("EditControl", { "TOPLEFT", self.controls.accountNameHeader, "BOTTOMLEFT" }, 0, 4, 200, 20, main.lastAccountName or "", nil, "%c", nil, nil, nil, nil, true)
    self.controls.accountName.pasteFilter = function(text)
        return text:gsub("[\128-\255]", function(c)
            return codePointToUTF8(c:byte(1)):gsub(".", function(c)
                return string.format("%%%X", c:byte(1))
            end)
        end)
    end
    -- accountHistory Control
    if not historyList then
        historyList = { }
        for accountName, account in pairs(main.gameAccounts) do
            t_insert(historyList, accountName)
            historyList[accountName] = true
        end
        table.sort(historyList, function(a, b)
            return a:lower() < b:lower()
        end)
    end -- don't load the list many times
    self.controls.accountNameGo = new("ButtonControl", { "LEFT", self.controls.accountName, "RIGHT" }, 8, 0, 100, 20, "Start Online", function()
        self.isOnlineMode = true
        self:DownloadCharacterListOnline()
    end)
    self.controls.accountNameGo.enabled = function()
        return self.controls.accountName.buf:match("%S")
    end

    self.controls.accountHistory = new("DropDownControl", { "LEFT", self.controls.accountNameGo, "RIGHT" }, 8, 0, 200, 20, historyList, function()
        self.controls.accountName.buf = self.controls.accountHistory.list[self.controls.accountHistory.selIndex]
    end)
    self.controls.accountHistory:SelByValue(main.lastAccountName)
    self.controls.accountHistory:CheckDroppedWidth(true)

    self.controls.removeAccount = new("ButtonControl", { "LEFT", self.controls.accountHistory, "RIGHT" }, 8, 0, 20, 20, "X", function()
        local accountName = self.controls.accountHistory.list[self.controls.accountHistory.selIndex]
        if (accountName ~= nil) then
            t_remove(self.controls.accountHistory.list, self.controls.accountHistory.selIndex)
            self.controls.accountHistory.list[accountName] = nil
            main.gameAccounts[accountName] = nil
        end
    end)

    self.controls.removeAccount.tooltipFunc = function(tooltip)
        tooltip:Clear()
        tooltip:AddLine(16, "^7Removes account from the dropdown list")
    end

    -- Stage: select character and import data
    self.controls.source = new("ButtonControl", { "TOPLEFT", self.controls.sectionCharImport, "TOPLEFT" }, 6, 50, 438, 18, "^7Source: ^x4040FFhttps://lastepochtools.com")
    self.controls.source.shown = function()
        if self.charImportMode == "SELECTCHAR" then
            return self.isOnlineMode
        end
        return false
    end
    self.controls.charSelectHeader = new("LabelControl", { "TOPLEFT", self.controls.sectionCharImport, "TOPLEFT" }, 6, 70, 200, 16, "^7Choose character to import data from:")
    self.controls.charSelectHeader.shown = function()
        return self.charImportMode == "SELECTCHAR" or self.charImportMode == "IMPORTING"
    end
    self.controls.charSelectLeagueLabel = new("LabelControl", { "TOPLEFT", self.controls.charSelectHeader, "BOTTOMLEFT" }, 0, 6, 0, 14, "^7League:")
    self.controls.charSelectLeague = new("DropDownControl", { "LEFT", self.controls.charSelectLeagueLabel, "RIGHT" }, 4, 0, 150, 18, nil, function(index, value)
        self:BuildCharacterList(value.league)
    end)
    self.controls.charSelect = new("DropDownControl", { "TOPLEFT", self.controls.charSelectHeader, "BOTTOMLEFT" }, 0, 24, 400, 18)
    self.controls.charSelect.enabled = function()
        return self.charImportMode == "SELECTCHAR"
    end
    self.controls.charDownload = new("ButtonControl", { "TOPLEFT", self.controls.charSelect, "BOTTOMLEFT" }, 0, 8, 100, 20, "Download", function()
        self:DownloadFromLETools()
    end)
    self.controls.charDownload.shown = function()
        local charSelect = self.controls.charSelect
        return self.isOnlineMode and #charSelect.list > 0
    end
    self.controls.charImportHeader = new("LabelControl", { "TOPLEFT", self.controls.charSelect, "BOTTOMLEFT" }, 0, 40, 200, 16, "Import:")
    self.controls.charImportHeader.shown = function()
        local charSelect = self.controls.charSelect
        if #charSelect.list > 0 then
            local charData = charSelect.list[charSelect.selIndex].char
            return charData.hashes
        end
        return false
    end
    self.controls.charImportTree = new("ButtonControl", { "LEFT", self.controls.charImportHeader, "RIGHT" }, 8, 0, 170, 20, "Passive Tree and Skills", function()
        if self.build.spec:CountAllocNodes() > 0 then
            main:OpenConfirmPopup("Character Import", "Importing the passive tree will overwrite your current tree.", "Import", function()
                self:DownloadPassiveTree()
            end)
        else
            self:DownloadPassiveTree()
        end
    end)
    self.controls.charImportTree.enabled = function()
        return self.charImportMode == "SELECTCHAR"
    end
    self.controls.charImportItems = new("ButtonControl", { "LEFT", self.controls.charImportTree, "LEFT" }, 0, 36, 110, 20, "Items", function()
        self:DownloadItems()
    end)
    self.controls.charImportItems.enabled = function()
        return self.charImportMode == "SELECTCHAR"
    end
    self.controls.charImportItemsClearItems = new("CheckBoxControl", { "LEFT", self.controls.charImportItems, "RIGHT" }, 120, 0, 18, "Delete equipment:", nil, "Delete all equipped items when importing.", true)
    self.controls.charImportUnusedItemsClearItems = new("CheckBoxControl", { "LEFT", self.controls.charImportItems, "RIGHT" }, 280, 0, 18, "Delete unused items:", nil, "Delete all unused items when importing.", false)

    self.controls.charClose = new("ButtonControl", { "TOPLEFT", self.controls.charSelect, "BOTTOMLEFT" }, 0, 106, 60, 20, "Close", function()
        self.charImportMode = "GETACCOUNTNAME"
        self.charImportStatus = "Idle"
    end)

    -- Build import/export
    self.controls.sectionBuild = new("SectionControl", { "TOPLEFT", self.controls.sectionCharImport, "BOTTOMLEFT" }, 0, 18, 650, 182 + 16, "Build Sharing")
    self.controls.generateCodeLabel = new("LabelControl", { "TOPLEFT", self.controls.sectionBuild, "TOPLEFT" }, 6, 14, 0, 16, "^7Generate a code to share this build with other Last Epoch Planner users:")
    self.controls.generateCode = new("ButtonControl", { "LEFT", self.controls.generateCodeLabel, "RIGHT" }, 4, 0, 80, 20, "Generate", function()
        self.controls.generateCodeOut:SetText(common.base64.encode(Deflate(self.build:SaveDB("code"))):gsub("+", "-"):gsub("/", "_"))
    end)
    self.controls.enablePartyExportBuffs = new("CheckBoxControl", { "LEFT", self.controls.generateCode, "RIGHT" }, 100, 0, 18, "Export Support", function(state)
        self.build.partyTab.enableExportBuffs = state
        self.build.buildFlag = true
    end, "This is for party play, to export support character, it enables the exporting of auras, curses and modifiers to the enemy", false)
    self.controls.generateCodeOut = new("EditControl", { "TOPLEFT", self.controls.generateCodeLabel, "BOTTOMLEFT" }, 0, 8, 250, 20, "", "Code", "%Z")
    self.controls.generateCodeOut.enabled = function()
        return #self.controls.generateCodeOut.buf > 0
    end
    self.controls.generateCodeCopy = new("ButtonControl", { "LEFT", self.controls.generateCodeOut, "RIGHT" }, 8, 0, 60, 20, "Copy", function()
        Copy(self.controls.generateCodeOut.buf)
        self.controls.generateCodeOut:SetText("")
    end)
    self.controls.generateCodeCopy.enabled = function()
        return #self.controls.generateCodeOut.buf > 0
    end

    local getExportSitesFromImportList = function()
        local exportWebsites = { }
        for k, v in pairs(buildSites.websiteList) do
            -- if entry has fields needed for Export
            if buildSites.websiteList[k].postUrl and buildSites.websiteList[k].postFields and buildSites.websiteList[k].codeOut then
                table.insert(exportWebsites, v)
            end
        end
        return exportWebsites
    end
    local exportWebsitesList = getExportSitesFromImportList()

    self.controls.exportFrom = new("DropDownControl", { "LEFT", self.controls.generateCodeCopy, "RIGHT" }, 8, 0, 120, 20, exportWebsitesList, function(_, selectedWebsite)
        main.lastExportWebsite = selectedWebsite.id
        self.exportWebsiteSelected = selectedWebsite.id
    end)
    self.controls.exportFrom:SelByValue(self.exportWebsiteSelected or main.lastExportWebsite or "Pastebin", "id")
    self.controls.generateCodeByLink = new("ButtonControl", { "LEFT", self.controls.exportFrom, "RIGHT" }, 8, 0, 100, 20, "Share", function()
        local exportWebsite = exportWebsitesList[self.controls.exportFrom.selIndex]
        local response = buildSites.UploadBuild(self.controls.generateCodeOut.buf, exportWebsite)
        if response then
            self.controls.generateCodeOut:SetText("")
            self.controls.generateCodeByLink.label = "Creating link..."
            launch:RegisterSubScript(response, function(pasteLink, errMsg)
                self.controls.generateCodeByLink.label = "Share"
                if errMsg then
                    main:OpenMessagePopup(exportWebsite.id, "Error creating link:\n" .. errMsg)
                else
                    self.controls.generateCodeOut:SetText(exportWebsite.codeOut .. pasteLink)
                end
            end)
        end
    end)
    self.controls.generateCodeByLink.enabled = function()
        for _, exportSite in ipairs(exportWebsitesList) do
            if #self.controls.generateCodeOut.buf > 0 and self.controls.generateCodeOut.buf:match(exportSite.matchURL) then
                return false
            end
        end
        return #self.controls.generateCodeOut.buf > 0
    end
    self.controls.exportFrom.enabled = function()
        for _, exportSite in ipairs(exportWebsitesList) do
            if #self.controls.generateCodeOut.buf > 0 and self.controls.generateCodeOut.buf:match(exportSite.matchURL) then
                return false
            end
        end
        return #self.controls.generateCodeOut.buf > 0
    end
    self.controls.generateCodeNote = new("LabelControl", { "TOPLEFT", self.controls.generateCodeOut, "BOTTOMLEFT" }, 0, 4, 0, 14, "^7Note: this code can be very long; you can use 'Share' to shrink it. (Not yet supported)")
    self.controls.importCodeHeader = new("LabelControl", { "TOPLEFT", self.controls.generateCodeNote, "BOTTOMLEFT" }, 0, 26, 0, 16, "^7To import a build, enter URL or code here:\nNote that you can import from LETools")

    local importCodeHandle = function(buf)
        self.importCodeSite = nil
        self.importCodeDetail = ""
        self.importCodeXML = nil
        self.importCodeValid = false

        if #buf == 0 then
            return
        end

        if not self.build.dbFileName then
            self.controls.importCodeMode.selIndex = 2
        end

        self.importCodeDetail = colorCodes.NEGATIVE .. "Invalid input"
        local urlText = buf:gsub("^[%s?]+", ""):gsub("[%s?]+$", "") -- Quick Trim
        if urlText:match("youtube%.com/redirect%?") or urlText:match("google%.com/url%?") then
            local nested_url = urlText:gsub(".*[?&]q=([^&]+).*", "%1")
            urlText = UrlDecode(nested_url)
        end

        for j = 1, #buildSites.websiteList do
            if urlText:match(buildSites.websiteList[j].matchURL) then
                self.controls.importCodeIn.text = urlText
                self.importCodeValid = true
                self.importCodeDetail = colorCodes.POSITIVE .. "URL is valid (" .. buildSites.websiteList[j].label .. ")"
                self.importCodeSite = j
                if buf ~= urlText then
                    self.controls.importCodeIn:SetText(urlText, false)
                end
                if buildSites.websiteList[j].id == "lastepochtools" then
                    self.importCodeXML = buf:match("window%[\"buildInfo\"%] = (%b{})")
                end
                return
            end
        end

        local xmlText = Inflate(common.base64.decode(buf:gsub("-", "+"):gsub("_", "/")))
        if not xmlText then
            return
        end
        if launch.devMode and IsKeyDown("SHIFT") then
            Copy(xmlText)
        end
        self.importCodeValid = true
        self.importCodeDetail = colorCodes.POSITIVE .. "Code is valid"
        self.importCodeXML = xmlText
    end

    local importSelectedBuild = function()
        if not self.importCodeValid or self.importCodeFetching then
            return
        end

        if self.controls.importCodeMode.selIndex == 1 then
            main:OpenConfirmPopup("Build Import", colorCodes.WARNING .. "Warning:^7 Importing to the current build will erase ALL existing data for this build.", "Import", function()
                self.build:Shutdown()
                self.build:Init(self.build.dbFileName, self.build.buildName, self.importCodeXML)
                self.build.viewMode = "TREE"
            end)
        else
            self.build:Shutdown()
            self.build:Init(false, "Imported build", self.importCodeXML)
            self.build.viewMode = "TREE"
        end
    end

    self.controls.importCodeIn = new("EditControl", { "TOPLEFT", self.controls.importCodeHeader, "BOTTOMLEFT" }, 0, 4 + 16, 328, 20, "", nil, nil, nil, importCodeHandle, nil, nil, true)
    self.controls.importCodeIn.enterFunc = function()
        if self.importCodeValid then
            self.controls.importCodeGo.onClick()
        end
    end
    self.controls.importCodeState = new("LabelControl", { "LEFT", self.controls.importCodeIn, "RIGHT" }, 8, 0, 0, 16)
    self.controls.importCodeState.label = function()
        return self.importCodeDetail or ""
    end
    self.controls.importCodeMode = new("DropDownControl", { "TOPLEFT", self.controls.importCodeIn, "BOTTOMLEFT" }, 0, 4, 160, 20, { "Import to this build", "Import to a new build" })
    self.controls.importCodeMode.enabled = function()
        return self.build.dbFileName and self.importCodeValid
    end
    self.controls.importCodeGo = new("ButtonControl", { "LEFT", self.controls.importCodeMode, "RIGHT" }, 8, 0, 160, 20, "Import", function()
        if self.importCodeSite and not self.importCodeXML then
            self.importCodeFetching = true
            local selectedWebsite = buildSites.websiteList[self.importCodeSite]
            buildSites.DownloadBuild(self.controls.importCodeIn.buf, selectedWebsite, function(isSuccess, data)
                self.importCodeFetching = false
                if not isSuccess then
                    self.importCodeDetail = colorCodes.NEGATIVE .. data
                    self.importCodeValid = false
                else
                    importCodeHandle(data)
                    importSelectedBuild()
                end
            end)
            return
        end

        importSelectedBuild()
    end)
    self.controls.importCodeGo.label = function()
        return self.importCodeFetching and "Retrieving paste.." or "Import"
    end
    self.controls.importCodeGo.enabled = function()
        return self.importCodeValid and not self.importCodeFetching
    end
    self.controls.importCodeGo.enterFunc = function()
        if self.importCodeValid then
            self.controls.importCodeGo.onClick()
        end
    end
end)

function ImportTabClass:Load(xml, fileName)
    self.lastRealm = xml.attrib.lastRealm
    self.lastAccountHash = xml.attrib.lastAccountHash
    self.controls.enablePartyExportBuffs.state = xml.attrib.exportParty == "true"
    self.build.partyTab.enableExportBuffs = self.controls.enablePartyExportBuffs.state
    if self.lastAccountHash then
        for accountName in pairs(main.gameAccounts) do
            if common.sha1(accountName) == self.lastAccountHash then
                self.controls.accountName:SetText(accountName)
            end
        end
    end
    self.lastCharacterHash = xml.attrib.lastCharacterHash
end

function ImportTabClass:Save(xml)
    xml.attrib = {
        lastRealm = self.lastRealm,
        lastAccountHash = self.lastAccountHash,
        lastCharacterHash = self.lastCharacterHash,
        exportParty = tostring(self.controls.enablePartyExportBuffs.state),
    }
end

function ImportTabClass:Draw(viewPort, inputEvents)
    self.x = viewPort.x
    self.y = viewPort.y
    self.width = viewPort.width
    self.height = viewPort.height

    self:ProcessControlsInput(inputEvents, viewPort)

    main:DrawBackground(viewPort)

    self:DrawControls(viewPort)
end

function ImportTabClass:DownloadCharacterListOnline()
    self.charImportMode = "DOWNLOADCHARLIST"
    self.charImportStatus = "Retrieving character list..."
    -- Trim Trailing/Leading spaces
    local accountName = self.controls.accountName.buf:gsub('%s+', '')
    launch:DownloadPage("https://www.lastepochtools.com/profile/" .. accountName, function(response, errMsg)
        if errMsg == "Response code: 401" then
            self.charImportStatus = colorCodes.NEGATIVE .. "Sign-in is required."
            self.charImportMode = "GETSESSIONID"
            return
        elseif errMsg == "Response code: 403" then
            self.charImportStatus = colorCodes.NEGATIVE .. "Account profile is private."
            self.charImportMode = "GETSESSIONID"
            return
        elseif errMsg == "Response code: 404" then
            self.charImportStatus = colorCodes.NEGATIVE .. "Account name is incorrect."
            self.charImportMode = "GETACCOUNTNAME"
            return
        elseif errMsg then
            self.charImportStatus = colorCodes.NEGATIVE .. "Error retrieving character list, try again (" .. errMsg:gsub("\n", " ") .. ")"
            self.charImportMode = "GETACCOUNTNAME"
            return
        end
        local jsonChars = response.body:match("let accountCharacters = (%b[])")
        if not jsonChars then
            self.charImportStatus = colorCodes.NEGATIVE .. "Error processing character list, try again later"
            self.charImportMode = "GETACCOUNTNAME"
            return
        end
        local charList, errMsg = processJson(jsonChars)
        if errMsg then
            self.charImportStatus = colorCodes.NEGATIVE .. "Error processing character list, try again later"
            self.charImportMode = "GETACCOUNTNAME"
            return
        end
        local jsonAccountInfo = response.body:match("let accountInfo = (%b{})")
        if not jsonAccountInfo then
            self.charImportStatus = colorCodes.NEGATIVE .. "Failed to retrieve account info, try again."
            return
        end
        local accountInfo, errMsg = processJson(jsonAccountInfo)
        if errMsg then
            self.charImportStatus = colorCodes.NEGATIVE .. "Failed to retrieve account info, try again."
            return
        end
        local lastFetched = "";
        if accountInfo.lastFetched then
            lastFetched = " Last update was on " .. os.date("%c",accountInfo.lastFetched / 1000)
        else
            lastFetched = " Never fetched"
        end
        --ConPrintTable(charList)
        if #charList == 0 then
            self.charImportStatus = colorCodes.NEGATIVE .. "The account has no characters to import."
        else
            self.charImportStatus = "Character list successfully retrieved."
        end
        self.charImportStatus = self.charImportStatus .. colorCodes.NORMAL .. lastFetched .. colorCodes.NEGATIVE .. "\n\tManually click on source link to trigger an update"
        self.charImportMode = "SELECTCHAR"
        self.controls.source.label = "^7Source: ^x4040FFhttps://www.lastepochtools.com/profile/" .. accountName
        self.controls.source.onClick = function()
            OpenURL("https://www.lastepochtools.com/profile/" .. accountName)
        end
        self.lastAccountHash = common.sha1(accountName)
        main.lastAccountName = accountName
        main.gameAccounts[accountName] = main.gameAccounts[accountName] or { }
        local leagueList = { }
        for i, char in ipairs(charList) do
            char.league = char.cycle == 6 and "Cycle" or "Legacy"
            char.ascendancy = char.mastery
            char.ascendancyName = self.build.latestTree.classes[char.class].ascendancies[char.ascendancy].name
            char.name = char.characterName
            char.class = self.build.latestTree.classes[char.class].name
            if not isValueInArray(leagueList, char.league) then
                t_insert(leagueList, char.league)
            end
        end
        table.sort(leagueList)
        wipeTable(self.controls.charSelectLeague.list)
        for _, league in ipairs(leagueList) do
            t_insert(self.controls.charSelectLeague.list, {
                label = league,
                league = league,
            })
        end
        t_insert(self.controls.charSelectLeague.list, {
            label = "All",
        })
        if self.controls.charSelectLeague.selIndex > #self.controls.charSelectLeague.list then
            self.controls.charSelectLeague.selIndex = 1
        end
        self.lastCharList = charList
        self:BuildCharacterList(self.controls.charSelectLeague:GetSelValue("league"))

        -- We only get here if the accountname was correct, found, and not private, so add it to the account history.
        self:SaveAccountHistory()
    end)
end

function ImportTabClass:DownloadCharacterList()
    self.charImportMode = "DOWNLOADCHARLIST"
    self.charImportStatus = "Retrieving character list..."

    local saveFolderSuffix = "\\AppData\\LocalLow\\Eleventh Hour Games\\Last Epoch\\Saves\\"
    local localSaveFolders = {}
    if os.getenv("UserProfile") then
        -- For Windows
        t_insert(localSaveFolders, os.getenv('UserProfile') .. saveFolderSuffix)
    end
    if os.getenv("USER") then
        -- For Linux
        t_insert(localSaveFolders, "/home/" .. os.getenv("USER")
            .. "/.local/share/Steam/steamapps/compatdata/899770/pfx/drive_c/users/steamuser/"
            .. saveFolderSuffix)
    end
    local saves = {}
    for _, localSaveFolder in ipairs(localSaveFolders) do
        local handle = NewFileSearch(localSaveFolder .. "1CHARACTERSLOT_BETA_*")
        while handle do
            local fileName = handle:GetFileName()

            if fileName:sub(-4) ~= ".bak" then
                table.insert(saves, localSaveFolder .. "\\" .. fileName)
            end

            if not handle:NextFile() then
                break
            end
        end
    end

    local charList = {}
    for _, save in ipairs(saves) do
        local saveFile = io.open(save, "r")
        local saveFileContent = saveFile:read("*a")
        saveFile:close()
        local char = self:ReadJsonSaveData(saveFileContent:sub(6))
        table.insert(charList, char)
    end

    self.charImportStatus = "Character list successfully retrieved."
    self.charImportMode = "SELECTCHAR"
    local leagueList = { }
    for i, char in ipairs(charList) do
        if not isValueInArray(leagueList, char.league) then
            t_insert(leagueList, char.league)
        end
    end
    table.sort(leagueList)
    wipeTable(self.controls.charSelectLeague.list)
    for _, league in ipairs(leagueList) do
        t_insert(self.controls.charSelectLeague.list, {
            label = league,
            league = league,
        })
    end
    t_insert(self.controls.charSelectLeague.list, {
        label = "All",
    })
    if self.controls.charSelectLeague.selIndex > #self.controls.charSelectLeague.list then
        self.controls.charSelectLeague.selIndex = 1
    end
    self.lastCharList = charList
    self:BuildCharacterList(self.controls.charSelectLeague:GetSelValue("league"))
end

function ImportTabClass:BuildCharacterList(league)
    wipeTable(self.controls.charSelect.list)
    for i, char in ipairs(self.lastCharList) do
        if not league or char.league == league then
            local class = char.ascendancy > 0 and char.ascendancyName or char.class or "?"
            t_insert(self.controls.charSelect.list, {
                label = string.format("%s: Level %d %s in %s", char.name or "?", char.level or 0, class, char.league or "?"),
                char = char,
            })
        end
    end
    table.sort(self.controls.charSelect.list, function(a, b)
        return a.char.name:lower() < b.char.name:lower()
    end)
    self.controls.charSelect.selIndex = 1
    if self.lastCharacterHash then
        for i, char in ipairs(self.controls.charSelect.list) do
            if common.sha1(char.char.name) == self.lastCharacterHash then
                self.controls.charSelect.selIndex = i
                break
            end
        end
    end
end

function ImportTabClass:SaveAccountHistory()
    if not historyList[self.controls.accountName.buf] then
        t_insert(historyList, self.controls.accountName.buf)
        historyList[self.controls.accountName.buf] = true
        self.controls.accountHistory:SelByValue(self.controls.accountName.buf)
        table.sort(historyList, function(a, b)
            return a:lower() < b:lower()
        end)
        self.controls.accountHistory:CheckDroppedWidth(true)
    end
end

function ImportTabClass:DownloadFromLETools()
    self.charImportStatus = "Downloading build info from Last Epoch Tools..."
    local charSelect = self.controls.charSelect
    local charData = charSelect.list[charSelect.selIndex].char
    local accountName = self.controls.accountName.buf
    launch:DownloadPage("https://www.lastepochtools.com/profile/" .. accountName .. "/character/" .. charData.name, function(response, errMsg)
        self.charImportMode = "SELECTCHAR"
        if errMsg then
            self.charImportStatus = colorCodes.NEGATIVE .. "Error importing character data, try again (" .. errMsg:gsub("\n", " ") .. ")"
            return
        elseif response.body == "false" then
            self.charImportStatus = colorCodes.NEGATIVE .. "Failed to retrieve character data, try again."
            return
        end
        local jsonBuild = response.body:match("let buildInfo = (%b{})")
        if not jsonBuild then
            self.charImportStatus = colorCodes.NEGATIVE .. "Failed to retrieve character data, try again."
            return
        end
        local buildInfo, errMsg = processJson(jsonBuild)
        if errMsg then
            self.charImportStatus = colorCodes.NEGATIVE .. "Failed to retrieve character data, try again."
            return
        end
        local jsonCharInfo = response.body:match("let charInfo = (%b{})")
        if not jsonCharInfo then
            self.charImportStatus = colorCodes.NEGATIVE .. "Failed to retrieve character info, try again."
            return
        end
        local charInfo, errMsg = processJson(jsonCharInfo)
        if errMsg then
            self.charImportStatus = colorCodes.NEGATIVE .. "Failed to retrieve character info, try again."
            return
        end
        local lastFetched = os.date("%c",charInfo.lastFetched / 1000)
        charSelect.list[charSelect.selIndex].char = self.build:ReadLeToolsSave(buildInfo.data)
        charSelect.list[charSelect.selIndex].char.name = charData.name
        self.charImportStatus = colorCodes.POSITIVE .. "Build info successfully downloaded. ".. colorCodes.NORMAL .. "Last update was on " .. lastFetched .. colorCodes.NEGATIVE .. "\n\tManually click on source link to trigger an update"
    end, sessionID and { header = "Cookie: POESESSID=" .. sessionID })
end

function ImportTabClass:DownloadPassiveTree()
    self.charImportStatus = "Retrieving character passive tree..."
    local charSelect = self.controls.charSelect
    local charData = charSelect.list[charSelect.selIndex].char
    self:ImportPassiveTreeAndJewels(charData)
end

function ImportTabClass:ReadJsonSaveData(saveFileContent)
    local saveContent = processJson(saveFileContent)
    local classId = saveContent["characterClass"]
    local className = self.build.latestTree.classes[classId].name
    local char = {
        ["name"] = saveContent["characterName"],
        ["level"] = saveContent["level"],
        ["class"] = className,
        ["ascendancy"] = saveContent['chosenMastery'],
        ["ascendancyName"] = self.build.latestTree.classes[classId].ascendancies[saveContent['chosenMastery']].name,
        ["classId"] = classId,
        ["abilities"] = {},
        ["items"] = {},
        ["hashes"] = { }
    }
    char.league = saveContent["cycle"] == 6 and "Cycle" or "Legacy"
    for passiveIdx, passive in pairs(saveContent["savedCharacterTree"]["nodeIDs"]) do
        local nbPoints = saveContent["savedCharacterTree"]["nodePoints"][passiveIdx]
        table.insert(char["hashes"], className .. "-" .. passive .. "#" .. nbPoints)
    end
    for _, skillTree in pairs(saveContent["savedSkillTrees"]) do
        table.insert(char["hashes"], skillTree['treeID'] .. "-" .. 0 .. "#1")
        table.insert(char["abilities"], skillTree['treeID'])
        for skillIdx, skill in pairs(skillTree["nodeIDs"]) do
            local nbPoints = skillTree["nodePoints"][skillIdx]
            table.insert(char["hashes"], skillTree['treeID'] .. "-" .. skill .. "#" .. nbPoints)
        end
    end
    for _, itemData in pairsSortByKey(saveContent["savedItems"]) do
        if itemData["containerID"] <= 12 or
                itemData["containerID"] >= 29 and itemData["containerID"] <= 36 or
                itemData["containerID"] >= 40 and  itemData["containerID"] <= 43  then
            local item = {
                ["inventoryId"] = itemData["containerID"],
            }
            local baseTypeID = itemData["data"][4]
            local subTypeID = itemData["data"][5]
            if itemData["containerID"] == 29 then
                local posX = itemData["inventoryPosition"]["x"]
                local posY = itemData["inventoryPosition"]["y"]
                local idolPosition = posX + posY * 5
                if posY > 0 then
                    idolPosition = idolPosition - 1
                end
                if posY == 4 then
                    idolPosition = idolPosition - 1
                end
                item["inventoryId"] = "Idol " .. idolPosition
            end
            for itemBaseName, itemBase in pairs(self.build.data.itemBases) do
                if itemBase.baseTypeID == baseTypeID and itemBase.subTypeID == subTypeID then
                    item.baseName = itemBaseName
                    item.base = itemBase
                    item.implicitMods = {}
                    for i, implicit in ipairs(itemBase.implicits) do
                        local range = itemData["data"][7 + i]
                        table.insert(item.implicitMods, "{range: " .. range .. "}" .. implicit)
                    end
                    local rarity = itemData["data"][6]
                    item["explicitMods"] = {}
                    item["prefixes"] = {}
                    item["suffixes"] = {}
                    if rarity >= 7 and rarity <= 9 then
                        item["rarity"] = "UNIQUE"
                        local uniqueIDIndex = 8 + 3 -- 3 is the maximum amount of implicits
                        local uniqueID = itemData["data"][uniqueIDIndex] * 256 + itemData["data"][uniqueIDIndex + 1]
                        local uniqueBase = self.build.data.uniques[uniqueID]
                        item["name"] = uniqueBase.name
                        for i, modLine in ipairs(uniqueBase.mods) do
                            if itemLib.hasRange(modLine) then
                                local rollId = uniqueBase.rollIds[i]
                                local range = itemData["data"][uniqueIDIndex + 2 +  rollId]
                                -- TODO: avoid using crafted
                                table.insert(item.explicitMods, "{crafted}{range: " .. range .. "}".. modLine)
                                else
                                table.insert(item.explicitMods, "{crafted}".. modLine)
                            end
                        end
                        if rarity == 9 then
                            local nbAffixesIndex = uniqueIDIndex + 2 + 8 -- 8 is the maximum amount of unique mods
                            local nbMods = itemData["data"][nbAffixesIndex]
                            for i = 0, nbMods - 1 do
                                local dataId = nbAffixesIndex + 1 + 3 * i
                                local affixId = itemData["data"][dataId + 1] + (itemData["data"][dataId] % 4) * 256
                                local affixTier = math.floor(itemData["data"][dataId] / 16)
                                local modId = affixId .. "_" .. affixTier
                                local modData = data.itemMods.Item[modId]
                                local range = itemData["data"][dataId + 2]
                                if modData then
                                    if modData.type == "Prefix" then
                                        table.insert(item.prefixes, { ["range"] = range, ["modId"] = modId })
                                    else
                                        table.insert(item.suffixes, { ["range"] = range, ["modId"] = modId })
                                    end
                                end
                            end
                        end
                    else
                        item["name"] = itemBaseName
                        item["rarity"] = "RARE"
                        for i = 0, 4 do
                            local dataId = 14 + i * 3
                            if #itemData["data"] > dataId then
                                local affixId = itemData["data"][dataId] + (itemData["data"][dataId - 1] % 4) * 256
                                if affixId then
                                    local affixTier = math.floor(itemData["data"][dataId - 1] / 16)
                                    local modId = affixId .. "_" .. affixTier
                                    local modData = data.itemMods.Item[modId]
                                    local range = itemData["data"][dataId + 1]

                                    if modData then
                                        if modData.type == "Prefix" then
                                            table.insert(item.prefixes, { ["range"] = range, ["modId"] = modId })
                                        else
                                            table.insert(item.suffixes, { ["range"] = range, ["modId"] = modId })
                                        end
                                    end
                                end
                            end
                        end
                    end
                    table.insert(char["items"], item)
                end
            end
        end
    end

    return char
end

function ImportTabClass:DownloadItems()
    self.charImportStatus = "Retrieving character items..."
    local charSelect = self.controls.charSelect
    local charData = charSelect.list[charSelect.selIndex].char
    self:ImportItemsAndSkills(charData)
end

function ImportTabClass:ImportPassiveTreeAndJewels(charData)
    self.build.spec:ImportFromNodeList(charData.classId, charData.ascendancy, charData.abilities, charData.hashes, charData.skill_overrides, latestTreeVersion)
    self.build.spec:AddUndoState()
    self.build.characterLevel = charData.level
    self.build.characterLevelAutoMode = false
    self.build.configTab:UpdateLevel()
    self.build.controls.characterLevel:SetText(charData.level)
    self.build:EstimatePlayerProgress()
    self.build.configTab.input["campaignBonuses"] = true
    self.build.configTab:BuildModList()
    self.build.configTab:UpdateControls()
    self.build.buildFlag = true

    local mainSocketGroup = self:GuessMainSocketGroup()
    if mainSocketGroup then
        self.build.calcsTab.input.skill_number = mainSocketGroup
        self.build.mainSocketGroup = mainSocketGroup
        self.build.skillsTab.socketGroupList[mainSocketGroup].includeInFullDPS = true
    end

    main:SetWindowTitleSubtext(string.format("%s (%s, %s, %s)", self.build.buildName, charData.name, charData.class, charData.league))

    self.charImportStatus = colorCodes.POSITIVE .. "Passive tree successfully imported."
end

function ImportTabClass:ImportItemsAndSkills(charData)
    if self.controls.charImportItemsClearItems.state then
        for _, slot in pairs(self.build.itemsTab.slots) do
            if slot.selItemId ~= 0 and not slot.nodeId then
                self.build.itemsTab:DeleteItem(self.build.itemsTab.items[slot.selItemId])
            end
        end
    end
    if self.controls.charImportUnusedItemsClearItems.state then
        self.build.itemsTab:DeleteUnused()
    end

    --ConPrintTable(charItemData)
    for _, itemData in pairsSortByKey(charData.items) do
        self:ImportItem(itemData)
    end
    self.build.itemsTab:PopulateSlots()
    self.build.itemsTab:AddUndoState()
    self.build.characterLevel = charData.level
    self.build.configTab:UpdateLevel()
    self.build.controls.characterLevel:SetText(charData.level)
    self.build.buildFlag = true

    self.charImportStatus = colorCodes.POSITIVE .. "Items and skills successfully imported."
    return charData -- For the wrapper
end

local slotMap = { [4] = "Weapon 1", [5] = "Weapon 2", [2] = "Helmet", [3] = "Body Armor", [6] = "Gloves", [8] = "Boots", [11] = "Amulet", [9] = "Ring 1", [10] = "Ring 2", [7] = "Belt", [12] = "Relic" }

for i = 1, 20 do
    slotMap["Idol " .. i] = "Idol " .. i
end

for i = 1, 7 do
    slotMap[32 + i] = "Blessing " .. i
end
for i = 1, 3 do
    slotMap[42 + i] = "Blessing " .. (7 + i)
end


function ImportTabClass:ImportItem(itemData, slotName)
    if not slotName then
        slotName = slotMap[itemData.inventoryId]
    end

    local item = self:BuildItem(itemData)

    -- Add and equip the new item
    --ConPrintf("%s", item.raw)
    if item.base then
        local repIndex, repItem
        for index, item in pairs(self.build.itemsTab.items) do
            if item.uniqueID == itemData.id then
                repIndex = index
                repItem = item
                break
            end
        end
        if repIndex then
            -- Item already exists in the build, overwrite it
            item.id = repItem.id
            self.build.itemsTab.items[item.id] = item
            item:BuildModList()
        else
            self.build.itemsTab:AddItem(item, true)
        end
        if slotName then
            self.build.itemsTab.slots[slotName]:SetSelItemId(item.id)
        end
    end
end

function ImportTabClass:BuildItem(itemData)
    local item = new("Item")

    -- Determine rarity, display name and base type of the item
    item.rarity = itemData.rarity
    if #itemData.name > 0 then
        item.title = itemData.name
        item.baseName = itemData.baseName
        item.base = itemData.base
        if item.base then
            item.type = item.base.type
        else
            ConPrintf("Unrecognised base in imported item: %s", item.baseName)
        end
    end
    if not item.base or not item.rarity then
        return
    end

    -- Import item data
    item.uniqueID = itemData.inventoryId
    itemData.ilvl = 0
    if itemData.ilvl > 0 then
        item.itemLevel = itemData.ilvl
    end
    if item.base.weapon or item.base.armour or item.base.flask then
        item.quality = 0
    end
    if itemData.properties then
        for _, property in pairs(itemData.properties) do
            if property.name == "Quality" then
                item.quality = tonumber(property.values[1][1]:match("%d+"))
            elseif property.name == "Limited to" then
                item.limit = tonumber(property.values[1][1])
            elseif property.name == "Evasion Rating" then
                if item.baseName == "Two-Toned Boots (Armour/Energy Shield)" then
                    -- Another hack for Two-Toned Boots
                    item.baseName = "Two-Toned Boots (Armour/Evasion)"
                    item.base = self.build.data.itemBases[item.baseName]
                end
            elseif property.name == "Energy Shield" then
                if item.baseName == "Two-Toned Boots (Armour/Evasion)" then
                    -- Yet another hack for Two-Toned Boots
                    item.baseName = "Two-Toned Boots (Evasion/Energy Shield)"
                    item.base = self.build.data.itemBases[item.baseName]
                end
            end
            if property.name == "Energy Shield" or property.name == "Ward" or property.name == "Armour" or property.name == "Evasion Rating" then
                item.armourData = item.armourData or { }
                for _, value in ipairs(property.values) do
                    item.armourData[property.name:gsub(" Rating", ""):gsub(" ", "")] = (item.armourData[property.name:gsub(" Rating", ""):gsub(" ", "")] or 0) + tonumber(value[1])
                end
            end
        end
    end
    item.split = itemData.split
    item.mirrored = itemData.mirrored
    item.corrupted = itemData.corrupted
    item.fractured = itemData.fractured
    item.synthesised = itemData.synthesised
    if itemData.requirements and (not itemData.socketedItems or not itemData.socketedItems[1]) then
        -- Requirements cannot be trusted if there are socketed gems, as they may override the item's natural requirements
        item.requirements = { }
        for _, req in ipairs(itemData.requirements) do
            if req.name == "Level" then
                item.requirements.level = req.values[1][1]
            elseif req.name == "Class:" then
                item.classRestriction = req.values[1][1]
            end
        end
    end
    item.enchantModLines = { }
    item.classRequirementModLines = { }
    item.implicitModLines = { }
    item.explicitModLines = { }
    if itemData.implicitMods then
        for _, line in ipairs(itemData.implicitMods) do
            for line in line:gmatch("[^\n]+") do
                t_insert(item.implicitModLines, { line = line})
            end
        end
    end
    if itemData.explicitMods then
        for _, line in ipairs(itemData.explicitMods) do
            for line in line:gmatch("[^\n]+") do
                t_insert(item.explicitModLines, { line = line })
            end
        end
    end
    item.prefixes = itemData.prefixes;
    item.suffixes = itemData.suffixes;
    item.crafted = true

    item:BuildAndParseRaw()
    -- Craft the item since we only added the prefixes and suffixes and not their mod lines
    item:Craft()

    return item
end

-- Return the index of the group with the most gems
function ImportTabClass:GuessMainSocketGroup()
    local bestDps = 0
    local bestSocketGroup = nil
    for i, socketGroup in pairs(self.build.skillsTab.socketGroupList) do
        self.build.mainSocketGroup = i
        socketGroup.includeInFullDPS = true
        local mainOutput = self.build.calcsTab.calcs.buildOutput(self.build, "MAIN").player.output
        socketGroup.includeInFullDPS = false
        local dps = mainOutput.FullDPS
        if dps > bestDps then
            bestDps = dps
            bestSocketGroup = i
        end
    end
    return bestSocketGroup
end

function HexToChar(x)
    return string.char(tonumber(x, 16))
end

function UrlDecode(url)
    if url == nil then
        return
    end
    url = url:gsub("+", " ")
    url = url:gsub("%%(%x%x)", HexToChar)
    return url
end
