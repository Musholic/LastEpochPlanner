-- Last Epoch Planner
--
-- Class: Passive Spec
-- Passive tree spec class.
-- Manages node allocation and pathing for a given passive spec
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local b_lshift = bit.lshift
local b_rshift = bit.rshift
local band = bit.band
local bor = bit.bor

local PassiveSpecClass = newClass("PassiveSpec", "UndoHandler", function(self, build, treeVersion, convert)
	self.UndoHandler()

	self.build = build

	-- Initialise and build all tables
	self:Init(treeVersion, convert)

	self:SelectClass(0)
end)

function PassiveSpecClass:Init(treeVersion, convert)
	self.treeVersion = treeVersion
	self.tree = main:LoadTree(treeVersion)
	self.ignoredNodes = { }
	self.ignoreAllocatingSubgraph = false
	local previousTreeNodes = { }
	if convert then
		previousTreeNodes = self.build.spec.nodes
	end

	-- Make a local copy of the passive tree that we can modify
	self.nodes = { }
	for _, treeNode in pairs(self.tree.nodes) do
		-- Exclude proxy or groupless nodes
		if not treeNode.isProxy then
			self.nodes[treeNode.id] = setmetatable({
				linked = { },
				power = { }
			}, treeNode)
		end
	end
	for id, node in pairs(self.nodes) do
		-- if the node is allocated and between the old and new tree has the same ID but does not share the same name, add to list of nodes to be ignored
		if convert and previousTreeNodes[id] and self.build.spec.allocNodes[id] and node.name ~= previousTreeNodes[id].name then
			self.ignoredNodes[id] = previousTreeNodes[id]
		end
		for _, otherId in ipairs(node.linkedId) do
			t_insert(node.linked, self.nodes[otherId])
		end
	end

	-- List of currently allocated nodes
	-- Keys are node IDs, values are nodes
	self.allocNodes = { }

	-- Keys are node IDs, values are the replacement node
	self.hashOverrides = { }
end

function PassiveSpecClass:Load(xml, dbFileName)
	self.title = xml.attrib.title
	local url
	for _, node in pairs(xml) do
		if type(node) == "table" then
			if node.elem == "URL" then
				-- Legacy format
				if type(node[1]) ~= "string" then
					launch:ShowErrMsg("^1Error parsing '%s': 'URL' element missing content", dbFileName)
					return true
				end
				url = node[1]
			end
		end
	end
	if xml.attrib.nodes then
		-- New format
		if not xml.attrib.classId then
			launch:ShowErrMsg("^1Error parsing '%s': 'Spec' element missing 'classId' attribute", dbFileName)
			return true
		end
		if not xml.attrib.ascendClassId then
			launch:ShowErrMsg("^1Error parsing '%s': 'Spec' element missing 'ascendClassId' attribute", dbFileName)
			return true
		end
		local hashList = { }
		for hash in xml.attrib.nodes:gmatch("[^,]+") do
			t_insert(hashList, hash)
		end
		local masteryEffects = { }
		if xml.attrib.masteryEffects then
			for mastery, effect in xml.attrib.masteryEffects:gmatch("{(%d+),(%d+)}") do
				masteryEffects[tonumber(mastery)] = tonumber(effect)
			end
		end
		for _, node in pairs(xml) do
			if type(node) == "table" then
				if node.elem == "Overrides" then
					for _, child in ipairs(node) do
						if not child.attrib.nodeId then
							launch:ShowErrMsg("^1Error parsing '%s': 'Override' element missing 'nodeId' attribute", dbFileName)
							return true
						end
						
						local nodeId = child.attrib.nodeId
						self.hashOverrides[nodeId] = {}
						for _,stats in ipairs(child) do
							for line in stats:gmatch("([^\n]*)\n?") do
								local strippedLine = StripEscapes(line):gsub("^[%s?]+", ""):gsub("[%s?]+$", "")
								if strippedLine ~= "" then
									t_insert(self.hashOverrides[nodeId], strippedLine)
								end
							end
						end
					end
				end
			end
		end
		self:ImportFromNodeList(tonumber(xml.attrib.classId), tonumber(xml.attrib.ascendClassId), nil, hashList, self.hashOverrides)
	elseif url then
		self:DecodeURL(url)
	end
	self:ResetUndo()
end

function PassiveSpecClass:Save(xml)
	local allocNodeIdList = { }
	for nodeId in pairsSortByKey(self.allocNodes) do
		t_insert(allocNodeIdList, nodeId .. "#" .. self.nodes[nodeId].alloc)
	end
	xml.attrib = {
		title = self.title,
		treeVersion = self.treeVersion,
		-- New format
		classId = tostring(self.curClassId),
		ascendClassId = tostring(self.curAscendClassId),
		nodes = table.concat(allocNodeIdList, ","),
	}

	local overrides = {
		elem = "Overrides"
	}
	if self.hashOverrides then
		for nodeId, node in pairs(self.hashOverrides) do
			local override = { elem = "Override", attrib = { nodeId = tostring(nodeId) } }
			for _, stat in ipairs(node) do
				t_insert(override, stat)
			end
			t_insert(overrides, override)
		end
	end
	t_insert(xml, overrides)

end

function PassiveSpecClass:PostLoad()
end

-- Import passive spec from the provided class IDs and node hash list
function PassiveSpecClass:ImportFromNodeList(classId, ascendClassId, abilities, hashList, hashOverrides, treeVersion)
  if hashOverrides == nil then hashOverrides = {} end
	if treeVersion and treeVersion ~= self.treeVersion then
		self:Init(treeVersion)
		self.build.treeTab.showConvert = self.treeVersion ~= latestTreeVersion
	end
	self:ResetNodes()
	self:SelectClass(classId)
	self:SelectAscendClass(ascendClassId)
	for _, id in pairs(hashList) do
		local nbPoint = tonumber(id:match("#(%d*)$")) or 0
		id = id:match("^(.*)#")
		local node = self.nodes[id]
		if node then
			node.alloc = nbPoint
			self.tree:ProcessStats(node)
			self.allocNodes[id] = node
		end
	end

	if abilities then
		-- First wipe existing ability selections
		for index, _ in pairs(self.build.skillsTab.socketGroupList) do
			self.build.skillsTab.socketGroupList[index] = nil
		end
		for index, skillId in ipairs(abilities) do
			self.build.skillsTab:SelSkill(index, skillId)
		end
	end

	-- Rebuild all the node paths and dependencies
	self:BuildAllDependsAndPaths()
end

function PassiveSpecClass:AllocateDecodedNodes(nodes, isCluster, endian)
	for i = 1, #nodes - 1, 2 do
		local id
		if endian == "big" then
			id = nodes:byte(i) * 256 + nodes:byte(i + 1)
		else
			id = nodes:byte(i) + nodes:byte(i + 1) * 256
		end
		if isCluster then
			id = id + 65536
		end
		local node = self.nodes[id]
		if node then
			node.alloc = 1
			self.allocNodes[id] = node
		end
	end
end

-- Decode the given poeplanner passive tree URL
function PassiveSpecClass:DecodePoePlannerURL(url, return_tree_version_only)
	-- poeplanner uses little endian numbers (GGG using BIG).
	-- If return_tree_version_only is True, then the return value will either be an error message or the tree version.
	   -- both error messages begin with 'Invalid'
	local function byteToInt(bytes, start)
		-- get a little endian number from two bytes
		return bytes:byte(start) + bytes:byte(start + 1) * 256
	end

	local function translatePoepToGggTreeVersion(minor)
		-- Translates internal tree version to GGG version.
		-- Limit poeplanner tree imports to recent versions.
		tree_versions = { -- poeplanner ID: GGG version
			[27] = 22, [26] = 21, [25] = 20, [24] = 19, [23] = 18,
			}
		if tree_versions[minor] then
			return tree_versions[minor]
		else
			return -1
		end
	end

	local b = common.base64.decode(url:gsub("^.+/",""):gsub("-","+"):gsub("_","/"))
	if not b or #b < 15 then
		return "Invalid tree link (unrecognised format)."
	end
	-- Quick debug for when we change tree versions. Print the first 20 or so bytes
	-- s = ""
	-- for i = 1, 20 do
		-- s = s..i..":"..string.format('%02X ', b:byte(i))
	-- end
	-- print(s)

	-- 4-7 is tree version.version
	major_version = byteToInt(b,4)
	minor_version = translatePoepToGggTreeVersion(byteToInt(b,6))
	-- If we only want the tree version, exit now
	if minor_version < 0 then
		return "Invalid tree version found in link."
	end
	if return_tree_version_only then
		return major_version.."_"..minor_version
	end

	-- 8 is Class, 9 is Ascendancy
	local classId = b:byte(8)
	local ascendClassId = b:byte(9)
	-- print("classId, ascendClassId", classId, ascendClassId)

	-- 9 is Bandit
	-- bandit = b[9]
	-- print("bandit", bandit, bandit_list[bandit])

	self:ResetNodes()
	self:SelectClass(classId)
	self:SelectAscendClass(ascendClassId)

	-- 11 is node count
	idx = 11
	local nodesCount = byteToInt(b, idx)
	local nodesEnd = idx + 2 + (nodesCount * 2)
	local nodes = b:sub(idx  + 2, nodesEnd - 1)
	-- print("idx + 2 , nodesEnd, nodesCount, len(nodes)", idx + 2, nodesEnd, nodesCount, #nodes)
	self:AllocateDecodedNodes(nodes, false, "little")

	idx = nodesEnd
	local clusterCount = byteToInt(b, idx)
	local clusterEnd = idx + 2 + (clusterCount * 2)
	local clusterNodes = b:sub(idx  + 2, clusterEnd - 1)
	-- print("idx + 2 , clusterEnd, clusterCount, len(clusterNodes)", idx + 2, clusterEnd, clusterCount, #clusterNodes)
	self:AllocateDecodedNodes(clusterNodes, true, "little")

	-- poeplanner has Ascendancy nodes in a separate array
	idx = clusterEnd
	local ascendancyCount = byteToInt(b, idx)
	local ascendancyEnd = idx + 2 + (ascendancyCount * 2)
	local ascendancyNodes = b:sub(idx  + 2, ascendancyEnd - 1)
	-- print("idx + 2 , ascendancyEnd, ascendancyCount, len(ascendancyNodes)", idx + 2, ascendancyEnd, ascendancyCount, #ascendancyNodes)
	self:AllocateDecodedNodes(ascendancyNodes, false, "little")

	idx = ascendancyEnd
	local masteryCount = byteToInt(b, idx)
	local masteryEnd = idx + 2 + (masteryCount * 4)
	local masteryEffects = b:sub(idx  + 2, masteryEnd - 1)
	-- print("idx + 2 , masteryEnd, masteryCount, len(masteryEffects)", idx + 2, masteryEnd, masteryCount, #masteryEffects)
	self:AllocateMasteryEffects(masteryEffects, "little")
end

-- Decode the given GGG passive tree URL
function PassiveSpecClass:DecodeURL(url)
	local b = common.base64.decode(url:gsub("^.+/",""):gsub("-","+"):gsub("_","/"))
	if not b or #b < 6 then
		return "Invalid tree link (unrecognised format)"
	end
	local ver = b:byte(1) * 16777216 + b:byte(2) * 65536 + b:byte(3) * 256 + b:byte(4)
	if ver > 6 then
		return "Invalid tree link (unknown version number '"..ver.."')"
	end
	local classId = b:byte(5)
	local ascendancyIds = (ver >= 4) and b:byte(6) or 0
	local ascendClassId = band(ascendancyIds, 3)
	if not self.tree.classes[classId] then
		return "Invalid tree link (bad class ID '"..classId.."')"
	end
	self:ResetNodes()
	self:SelectClass(classId)
	self:SelectAscendClass(ascendClassId)

	local nodesStart = ver >= 4 and 8 or 7
	local nodesEnd = ver >= 5 and 7 + (b:byte(7) * 2) or -1
	local nodes = b:sub(nodesStart, nodesEnd)
	self:AllocateDecodedNodes(nodes, false, "big")

	if ver < 5 then
		return
	end

	local clusterStart = nodesEnd + 1
	local clusterEnd = clusterStart + (b:byte(clusterStart) * 2)
	local clusterNodes = b:sub(clusterStart + 1, clusterEnd)
	self:AllocateDecodedNodes(clusterNodes, true, "big")

	if ver < 6 then
		return
	end

	local masteryStart = clusterEnd + 1
	local masteryEnd = masteryStart + (b:byte(masteryStart) * 4)
	local masteryEffects = b:sub(masteryStart + 1, masteryEnd)
	self:AllocateMasteryEffects(masteryEffects, "big")
end

-- Change the current class, preserving currently allocated nodes if they connect to the new class's starting node
function PassiveSpecClass:SelectClass(classId)
	if self.curClassId then
		-- Deallocate the current class's starting node
		local oldStartNodeId = self.curClass.startNodeId
		self.nodes[oldStartNodeId].alloc = 0
		self.allocNodes[oldStartNodeId] = nil
	end

	self:ResetAscendClass()

	self.curClassId = classId
	local class = self.tree.classes[classId]
	self.curClass = class
	self.curClassName = class.name

	-- Allocate the new class's starting node
	local startNode = self.nodes[class.startNodeId]
	startNode.alloc = 1
	self.allocNodes[startNode.id] = startNode

	-- Reset the ascendancy class
	-- This will also rebuild the node paths and dependencies
	self:SelectAscendClass(0)
end

function PassiveSpecClass:ResetAscendClass()
	if self.curAscendClassId then
		-- Deallocate the current ascendancy class's start node
		local ascendClass = self.curClass.classes[self.curAscendClassId] or self.curClass.classes[0]
		local oldStartNodeId = ascendClass.startNodeId
		if oldStartNodeId then
			self.nodes[oldStartNodeId].alloc = 0
			self.allocNodes[oldStartNodeId] = nil
		end
	end
end

function PassiveSpecClass:ResetSkill(index)
	if self.build.skillsTab.socketGroupList[index] then
		-- Deallocate the skillId start node
		local skillId = self.build.skillsTab.socketGroupList[index].skillId
		local oldStartNodeId = skillId .. "-0"
		if oldStartNodeId and self.nodes[oldStartNodeId] then
			self.nodes[oldStartNodeId].alloc = 0
			self.allocNodes[oldStartNodeId] = nil
		end
	end
end

function PassiveSpecClass:SelectAscendClass(ascendClassId)
	self:ResetAscendClass()

	self.curAscendClassId = ascendClassId
	local ascendClass = self.curClass.classes[ascendClassId] or self.curClass.classes[0]
	self.curAscendClass = ascendClass
	self.curAscendClassName = ascendClass.name

	if ascendClass.startNodeId then
		-- Allocate the new ascendancy class's start node
		local startNode = self.nodes[ascendClass.startNodeId]
		startNode.alloc = 1
		self.allocNodes[startNode.id] = startNode
	end

	-- Rebuild all the node paths and dependencies
	self:BuildAllDependsAndPaths()
end

-- Determines if the given class's start node is connected to the current class's start node
-- Attempts to find a path between the nodes which doesn't pass through any ascendancy nodes (i.e. Ascendant)
function PassiveSpecClass:IsClassConnected(classId)
	for _, other in ipairs(self.nodes[self.tree.classes[classId].startNodeId].linked) do
		-- For each of the nodes to which the given class's start node connects...
		if other.alloc > 0 then
			-- If the node is allocated, try to find a path back to the current class's starting node
			other.visited = true
			local visited = { }
			local found = self:FindStartFromNode(other, visited, true)
			for i, n in ipairs(visited) do
				n.visited = false
			end
			other.visited = false
			if found then
				-- Found a path, so the given class's start node is definitely connected to the current class's start node
				-- There might still be nodes which are connected to the current tree by an entirely different path though
				-- E.g. via Ascendant or by connecting to another "first passive node"
				return true
			end
		end
	end
	return false
end

-- Clear the allocated status of all non-class-start nodes
function PassiveSpecClass:ResetNodes()
	for id, node in pairs(self.nodes) do
		if node.type ~= "ClassStart" and node.type ~= "AscendClassStart" then
			node.alloc = 0
			self.allocNodes[id] = nil
		end
	end
	wipeTable(self.masterySelections)
end

-- Allocate the given node, if possible, and all nodes along the path to the node
-- An alternate path to the node may be provided, otherwise the default path will be used
-- The path must always contain the given node, as will be the case for the default path
function PassiveSpecClass:AllocNode(node, altPath)
	if not node.path then
		-- Node cannot be connected to the tree as there is no possible path
		return
	end

	-- Allocate all nodes along the path
	for _, pathNode in ipairs(altPath or node.path) do
		pathNode.alloc = 1
		self.allocNodes[pathNode.id] = pathNode
	end

	if node.isMultipleChoiceOption then
		-- For multiple choice passives, make sure no other choices are allocated
		local parent = node.linked[1]
		for _, optNode in ipairs(parent.linked) do
			if optNode.isMultipleChoiceOption and optNode.alloc > 0 and optNode ~= node then
				optNode.alloc = 0
				self.allocNodes[optNode.id] = nil
			end
		end
	end

	-- Rebuild all dependencies and paths for all allocated nodes
	self:BuildAllDependsAndPaths()
end

function PassiveSpecClass:DeallocSingleNode(node)
	node.alloc = 0
	self.allocNodes[node.id] = nil
end

-- Deallocate the given node, and all nodes which depend on it (i.e. which are only connected to the tree through this node)
function PassiveSpecClass:DeallocNode(node)
	for _, depNode in ipairs(node.depends) do
		self:DeallocSingleNode(depNode)
	end

	-- Rebuild all paths and dependencies for all allocated nodes
	self:BuildAllDependsAndPaths()
end

-- Count the number of allocated nodes and allocated ascendancy nodes
function PassiveSpecClass:CountAllocNodes()
	local used = 0
	for nodeId, node in pairs(self.allocNodes) do
		if node.type ~= "ClassStart" and nodeId:match("^" .. self.curClassName) then
			used = used + node.alloc or 0
		end
	end
	return used
end

-- Attempt to find a class start node starting from the given node
-- Unless noAscent == true it will also look for an ascendancy class start node
function PassiveSpecClass:FindStartFromNode(node, visited, noAscend)
	-- Mark the current node as visited so we don't go around in circles
	node.visited = true
	t_insert(visited, node)
	-- For each node which is connected to this one, check if...
	for _, other in ipairs(node.linked) do
		-- Either:
		--  - the other node is a start node, or
		--  - there is a path to a start node through the other node which didn't pass through any nodes which have already been visited
		local startIndex = #visited + 1
		if other.alloc > 0 and
		  (other.type == "ClassStart" or other.type == "AscendClassStart" or
		    (not other.visited and node.type ~= "Mastery" and self:FindStartFromNode(other, visited, noAscend))
		  ) then
			if node.ascendancyName and not other.ascendancyName then
				-- Pathing out of Ascendant, un-visit the outside nodes
				for i = startIndex, #visited do
					visited[i].visited = false
					visited[i] = nil
				end
			elseif not noAscend or other.type ~= "AscendClassStart" then
				return true
			end
		end
	end
end

-- Perform a breadth-first search of the tree, starting from this node, and determine if it is the closest node to any other nodes
function PassiveSpecClass:BuildPathFromNode(root)
	root.pathDist = 0
	root.path = { }
	local queue = { root }
	local o, i = 1, 2 -- Out, in
	while o < i do
		-- Nodes are processed in a queue, until there are no nodes left
		-- All nodes that are 1 node away from the root will be processed first, then all nodes that are 2 nodes away, etc
		local node = queue[o]
		o = o + 1
		local curDist = node.pathDist + 1
		-- Iterate through all nodes that are connected to this one
		for _, other in ipairs(node.linked) do
			-- Paths must obey these rules:
			-- 1. They must not pass through class or ascendancy class start nodes (but they can start from such nodes)
			-- 2. They cannot pass between different ascendancy classes or between an ascendancy class and the main tree
			--    The one exception to that rule is that a path may start from an ascendancy node and pass into the main tree
			--    This permits pathing from the Ascendant 'Path of the X' nodes into the respective class start areas
			-- 3. They must not pass away from mastery nodes
			if not other.pathDist then
				ConPrintTable(other, true)
			elseif node.type ~= "Mastery" and other.type ~= "ClassStart" and other.type ~= "AscendClassStart" and other.pathDist > curDist and (node.ascendancyName == other.ascendancyName or (curDist == 1 and not other.ascendancyName)) then
				-- The shortest path to the other node is through the current node
				other.pathDist = curDist
				other.path = wipeTable(other.path)
				other.path[1] = other
				for i, n in ipairs(node.path) do
					other.path[i+1] = n
				end
				-- Add the other node to the end of the queue
				queue[i] = other
				i = i + 1
			end
		end
	end
end

-- Determine this node's distance from the class' start
-- Only allocated nodes can be traversed
function PassiveSpecClass:SetNodeDistanceToClassStart(root)
	root.distanceToClassStart = 0
	if root.alloc == 0 or root.dependsOnIntuitiveLeapLike then
		return
	end

	-- Stop once the current class' starting node is reached
	local targetNodeId = self.curClass.startNodeId

	local nodeDistanceToRoot = { }
	nodeDistanceToRoot[root.id] = 0

	local queue = { root }
	local o, i = 1, 2 -- Out, in
	while o < i do
		-- Nodes are processed in a queue, until there are no nodes left or the starting node is reached
		-- All nodes that are 1 node away from the root will be processed first, then all nodes that are 2 nodes away, etc
		-- Only allocated nodes are queued
		local node = queue[o]
		o = o + 1
		local curDist = nodeDistanceToRoot[node.id] + 1
		-- Iterate through all nodes that are connected to this one
		for _, other in ipairs(node.linked) do
			-- If this connected node is the correct class start node, then record the distance to the node and return
			if other.id == targetNodeId then
				root.distanceToClassStart = curDist - 1
				return
			end

			-- Otherwise, record the distance to this node if it hasn't already been visited
			if other.alloc > 0 and node.type ~= "Mastery" and other.type ~= "ClassStart" and other.type ~= "AscendClassStart" and not nodeDistanceToRoot[other.id] then
				nodeDistanceToRoot[other.id] = curDist;

				-- Add the other node to the end of the queue
				queue[i] = other
				i = i + 1
			end
		end
	end
end

function PassiveSpecClass:AddMasteryEffectOptionsToNode(node)
	node.sd = {}
	if node.masteryEffects ~= nil and #node.masteryEffects > 0 then
		for _, effect in ipairs(node.masteryEffects) do
			effect = self.tree.masteryEffects[effect.effect]
			local startIndex = #node.sd + 1
			for _, sd in ipairs(effect.sd) do
				t_insert(node.sd, sd)
			end
			self.tree:ProcessStats(node, startIndex)
		end
	else
		self.tree:ProcessStats(node)
	end
	node.allMasteryOptions = true
end

-- Rebuilds dependencies and paths for all nodes
function PassiveSpecClass:BuildAllDependsAndPaths()
	-- This table will keep track of which nodes have been visited during each path-finding attempt
	local visited = { }
	self.visibleNodes = {}
	for nodeId, node in pairs(self.nodes) do
		if nodeId:match("^" .. self.curClassName) then
			self.visibleNodes[nodeId] = node
		end
		for _, ascendancy in ipairs(self.curClass.classes) do
			if nodeId == ascendancy.name then
				self.visibleNodes[nodeId] = node
			end
		end
		for _,ability in pairs(self.build.skillsTab.socketGroupList) do
			if ability.skillId and nodeId:match("^" .. ability.skillId) then
				self.visibleNodes[nodeId] = node
			end
		end
	end
	-- Check all nodes for other nodes which depend on them (i.e. are only connected to the tree through that node)
	for id, node in pairs(self.visibleNodes) do
		node.depends = wipeTable(node.depends)
		node.dependsOnIntuitiveLeapLike = false
		node.conqueredBy = nil

		-- ignore cluster jewel nodes that don't have an id in the tree
		if self.tree.nodes[id] then
			local newNode = self.tree.nodes[id]
			if self.hashOverrides[id] then
				newNode = copyTable(newNode, true)
				newNode.stats = {}
				newNode.notScalingStats = {}
				for _, line in ipairs(self.hashOverrides[id]) do
					if line:match("^%{NotScaling%}") then
						t_insert(newNode.notScalingStats, line:sub(13))
					else
						t_insert(newNode.stats, line)
					end
				end
			end
			self:ReplaceNode(node,newNode)
		end

		if node.alloc > 0 then
			node.depends[1] = node -- All nodes depend on themselves
		end
	end

	-- Add selected mastery effect mods to mastery nodes
	self.allocatedMasteryCount = 0
	self.allocatedNotableCount = 0
	self.allocatedMasteryTypes = { }
	self.allocatedMasteryTypeCount = 0

	for id, node in pairs(self.allocNodes) do
		node.visited = true
		local anyStartFound = (node.type == "ClassStart" or node.type == "AscendClassStart")
		for _, other in ipairs(node.linked) do
			if other.alloc > 0 and not isValueInArray(node.depends, other) then
				-- The other node is allocated and isn't already dependent on this node, so try and find a path to a start node through it
				if other.type == "ClassStart" or other.type == "AscendClassStart" then
					-- Well that was easy!
					anyStartFound = true
				elseif self:FindStartFromNode(other, visited) then
					-- We found a path through the other node, therefore the other node cannot be dependent on this node
					anyStartFound = true
					for i, n in ipairs(visited) do
						n.visited = false
						visited[i] = nil
					end
				else
					-- No path was found, so all the nodes visited while trying to find the path must be dependent on this node
					-- except for mastery nodes that have linked allocated nodes that weren't visited
					local depIds = { }
					for _, n in ipairs(visited) do
						if not n.dependsOnIntuitiveLeapLike then
							depIds[n.id] = true
						end
					end
					for i, n in ipairs(visited) do
						if not n.dependsOnIntuitiveLeapLike then
							if n.type == "Mastery" then
								local otherPath = false
								local allocatedLinkCount = 0
								for _, linkedNode in ipairs(n.linked) do
									if linkedNode.alloc > 0 then
										allocatedLinkCount = allocatedLinkCount + 1
									end
								end
								if allocatedLinkCount > 1 then
									for _, linkedNode in ipairs(n.linked) do
										if linkedNode.alloc > 0 and not depIds[linkedNode.id] then
											otherPath = true
										end
									end
								end
								if not otherPath then
									t_insert(node.depends, n)
								end
							else
								t_insert(node.depends, n)
							end
						end
						n.visited = false
						visited[i] = nil
					end
				end
			end
		end
		node.visited = false
		if not anyStartFound then
			-- No start nodes were found through ANY nodes
			-- Therefore this node and all nodes depending on it are orphans and should be pruned
			for _, depNode in ipairs(node.depends) do
				self:DeallocSingleNode(depNode)
			end
		end
	end

	-- Reset and rebuild all node paths
	for id, node in pairs(self.visibleNodes) do
		node.pathDist = (node.alloc > 0) and 0 or 1000
		node.path = nil
	end
	for id, node in pairs(self.allocNodes) do
		self:BuildPathFromNode(node)
	end
end

function PassiveSpecClass:ReplaceNode(old, newNode)
	-- Edited nodes can share a name
	if old.stats == newNode.stats and old.notScalingStats == newNode.notScalingStats then
		return 1
	end
	old.dn = newNode.dn
	old.sd = newNode.sd
	old.stats = newNode.stats
	old.notScalingStats = newNode.notScalingStats
	old.mods = newNode.mods
	old.modKey = newNode.modKey
	old.modList = new("ModList")
	old.modList:AddList(newNode.modList)
	old.sprites = newNode.sprites
	old.effectSprites = newNode.effectSprites
	old.isTattoo = newNode.isTattoo
	old.keystoneMod = newNode.keystoneMod
	old.icon = newNode.icon
	old.spriteId = newNode.spriteId
	old.activeEffectImage = newNode.activeEffectImage
	old.reminderText = newNode.reminderText or { }
	self.tree:ProcessStats(old)
end

---Reconnects altered timeless jewel to class start, for Pure Talent
---@param node table @ The node to add the Condition:ConnectedTo[Class] flag to, if applicable
function PassiveSpecClass:ReconnectNodeToClassStart(node)
	for _, linkedNodeId in ipairs(node.linkedId) do
		for classId, class in pairs(self.tree.classes) do
			if linkedNodeId == class.startNodeId and node.type == "Normal" then
				node.modList:NewMod("Condition:ConnectedTo"..class.name.."Start", "FLAG", true, "Tree:"..linkedNodeId)
			end
		end
	end
end


function PassiveSpecClass:CreateUndoState()
	local allocNodeIdList = { }
	for nodeId in pairs(self.allocNodes) do
		t_insert(allocNodeIdList, nodeId)
	end
	return {
		classId = self.curClassId,
		ascendClassId = self.curAscendClassId,
		hashList = allocNodeIdList,
		hashOverrides = self.hashOverrides,
		treeVersion = self.treeVersion
	}
end

function PassiveSpecClass:RestoreUndoState(state, treeVersion)
	self:ImportFromNodeList(state.classId, state.ascendClassId, state.abilities, state.hashList, state.hashOverrides, treeVersion or state.treeVersion)
	self:SetWindowTitleWithBuildClass()
end

function PassiveSpecClass:SetWindowTitleWithBuildClass()
	main:SetWindowTitleSubtext(string.format("%s (%s)", self.build.buildName, self.curAscendClassId == 0 and self.curClassName or self.curAscendClassName))
end

--- Adds a line to or replaces a node given a line to add/replace with
--- @param node table The node to replace/add to
--- @param sd string The line being parsed and added
--- @param replacement boolean true to replace the node with the new mod, false to simply add it
function PassiveSpecClass:NodeAdditionOrReplacementFromString(node,sd,replacement)
	local addition = {}
	addition.sd = {sd}
	addition.mods = { }
	addition.modList = new("ModList")
	addition.modKey = ""
	local i = 1
	while addition.sd[i] do
		if addition.sd[i]:match("\n") then
			local line = addition.sd[i]
			local lineIdx = i
			t_remove(addition.sd, i)
			for line in line:gmatch("[^\n]+") do
				t_insert(addition.sd, lineIdx, line)
				lineIdx = lineIdx + 1
			end
		end
		local line = addition.sd[i]
		local parsedMod, unrecognizedMod = modLib.parseMod(line)
		if not parsedMod or unrecognizedMod then
			-- Try to combine it with one or more of the lines that follow this one
			local endI = i + 1
			while addition.sd[endI] do
				local comb = line
				for ci = i + 1, endI do
					comb = comb .. " " .. addition.sd[ci]
				end
				parsedMod, unrecognizedMod = modLib.parseMod(comb, true)
				if parsedMod and not unrecognizedMod then
					-- Success, add dummy mod lists to the other lines that were combined with this one
					for ci = i + 1, endI do
						addition.mods[ci] = { list = { } }
					end
					break
				end
				endI = endI + 1
			end
		end
		if not parsedMod then
			-- Parser had no idea how to read this modifier
			addition.unknown = true
		elseif unrecognizedMod then
			-- Parser recognised this as a modifier but couldn't understand all of it
			addition.extra = true
		else
			for _, mod in ipairs(parsedMod) do
				addition.modKey = addition.modKey.."["..modLib.formatMod(mod).."]"
			end
		end
		addition.mods[i] = { list = parsedMod, extra = unrecognizedMod }
		i = i + 1
		while addition.mods[i] do
			-- Skip any lines with dummy lists added by the line combining code
			i = i + 1
		end
	end

	-- Build unified list of modifiers from all recognised modifier lines
	for _, mod in pairs(addition.mods) do
		if mod.list and not mod.extra then
			for i, mod in ipairs(mod.list) do
				mod = modLib.setSource(mod, "Tree:"..node.id)
				addition.modList:AddMod(mod)
			end
		end
	end
	if replacement then
		node.sd = addition.sd
		node.mods = addition.mods
		node.modKey = addition.modKey
	else
		node.sd = tableConcat(node.sd, addition.sd)
		node.mods = tableConcat(node.mods, addition.mods)
		node.modKey = node.modKey .. addition.modKey
	end
	local modList = new("ModList")
	modList:AddList(addition.modList)
	if not replacement then
		modList:AddList(node.modList)
	end
	node.modList = modList
end

function PassiveSpecClass:NodeInKeystoneRadius(keystoneNames, nodeId, radiusIndex)
	for _, node in pairs(self.nodes) do
		if node.name and node.type == "Keystone" and keystoneNames[node.name:lower()] then
			if (node.nodesInRadius[radiusIndex][nodeId]) then
				return true
			end
		end
	end

	return false
end
