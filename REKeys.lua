local _G = _G
local _, RE = ...
local LDB = LibStub("LibDataBroker-1.1")
local LOR = LibStub("LibOpenRaid-1.0")
local LDBI = LibStub("LibDBIcon-1.0")
local QTIP = LibStub("LibQTip-1.0")
local BUCKET = LibStub("AceBucket-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("REKeys")
_G.REKeys = RE

local LoadAddOn = _G.LoadAddOn
local CreateFont = _G.CreateFont
local GetServerTime = _G.GetServerTime
local SendChatMessage = _G.SendChatMessage
local GuildRoster = _G.C_GuildInfo.GuildRoster
local GetClassInfo = _G.C_CreatureInfo.GetClassInfo
local GetMapUIInfo = _G.C_ChallengeMode.GetMapUIInfo
local GetAffixInfo = _G.C_ChallengeMode.GetAffixInfo
local GetRunHistory = _G.C_MythicPlus.GetRunHistory
local GetOwnedKeystoneChallengeMapID = _G.C_MythicPlus.GetOwnedKeystoneChallengeMapID
local GetOwnedKeystoneLevel = _G.C_MythicPlus.GetOwnedKeystoneLevel
local GetCurrentAffixes = _G.C_MythicPlus.GetCurrentAffixes
local GetRewardLevelFromKeystoneLevel = _G.C_MythicPlus.GetRewardLevelFromKeystoneLevel
local GetSecondsUntilWeeklyReset = _G.C_DateAndTime.GetSecondsUntilWeeklyReset
local GetContainerNumSlots = _G.C_Container.GetContainerNumSlots
local GetContainerItemInfo = _G.C_Container.GetContainerItemInfo
local RequestMapInfo = _G.C_MythicPlus.RequestMapInfo
local RequestRewards = _G.C_MythicPlus.RequestRewards
local RequestCurrentAffixes = _G.C_MythicPlus.RequestCurrentAffixes
local IsItemKeystoneByID = _G.C_Item.IsItemKeystoneByID
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local IsPartyLFG = _G.IsPartyLFG
local After = _G.C_Timer.After
local NewTimer = _G.C_Timer.NewTimer
local NewTicker = _G.C_Timer.NewTicker
local UnitInParty = _G.UnitInParty
local UnitInRaid = _G.UnitInRaid
local UnitFactionGroup = _G.UnitFactionGroup
local ElvUI = _G.ElvUI
local RaiderIO = _G.RaiderIO

RE.Keystone = {["MapID"] = 0, ["Level"] = 0}
RE.RowFill = true
RE.KeyQueryLimit = false
RE.MPlusDataReceived = false
RE.GroupFound = false
RE.TooltipDirty = false
RE.RewardsDirty = false

RE.DefaultSettings = {["CurrentWeek"] = 0, ["ResetTimestamp"] = 0, ["ServerTimestamp"] = 0, ["PinnedCharacters"] = {}, ["Sorting"] = 1, ["FullDungeonName"] = false, ["ChatQueryGuild"] = true, ["ChatQueryGroup"] = true, ["OfflinePlayers"] = false, ["MinimapButtonSettings"] = {["hide"] = false}}
RE.AceConfig = {
	type = "group",
	args = {
		offline = {
			name = L["Display offline players"],
			type = "toggle",
			width = "full",
			order = 1,
			set = function(_, val) RE.Settings.OfflinePlayers = val end,
			get = function(_) return RE.Settings.OfflinePlayers end
		},
		minimap = {
			name = L["Display minimap button"],
			type = "toggle",
			width = "full",
			order = 2,
			set = function(_, val) RE.Settings.MinimapButtonSettings.hide = not val; if RE.Settings.MinimapButtonSettings.hide then LDBI:Hide("REKeys") else LDBI:Show("REKeys") end end,
			get = function(_) return not RE.Settings.MinimapButtonSettings.hide end
		},
		chatqueryguild = {
			name = L["Respond to !keys queries on the guild chat"],
			type = "toggle",
			width = "full",
			order = 3,
			set = function(_, val) RE.Settings.ChatQueryGuild = val end,
			get = function(_) return RE.Settings.ChatQueryGuild end
		},
		chatquerygroup = {
			name = L["Respond to !keys queries on the group/raid chat"],
			type = "toggle",
			width = "full",
			order = 4,
			set = function(_, val) RE.Settings.ChatQueryGroup = val end,
			get = function(_) return RE.Settings.ChatQueryGroup end
		},
		dungeonname = {
			name = L["Don't shorten dungeon names"],
			desc = L["When checked tooltip will display full dungeon name."],
			type = "toggle",
			width = "full",
			order = 5,
			set = function(_, val) RE.Settings.FullDungeonName = val end,
			get = function(_) return RE.Settings.FullDungeonName end
		},
		sorting = {
			name = _G.BAG_FILTER_TITLE_SORTING,
			type = "select",
			width = "double",
			order = 6,
			values = {
				[1] = _G.CALENDAR_EVENT_NAME,
				[2] = _G.RATING,
				[3] = _G.CHALLENGES
			},
			set = function(_, val) RE.Settings.Sorting = val end,
			get = function(_) return RE.Settings.Sorting end
		},
		pinned = {
			name = L["Pinned characters"],
			desc = L["Comma-separated list of character names. They will be shown at the top of the list regardless of status."],
			type = "input",
			width = "double",
			order = 7,
			set = function(_, val)
				RE.Settings.PinnedCharacters = {}
				local input = {strsplit(",", val)}
				for i = 1, #input do
					local payload = strtrim(input[i])
					if payload ~= "" then
						RE.Settings.PinnedCharacters[payload] = true
					end
				end
			end,
			get = function(_)
				local output = {}
				for k, _ in pairs(RE.Settings.PinnedCharacters) do
					table.insert(output, k)
				end
				sort(output)
				return table.concat(output, ",")
			end
		}
	}
}
RE.AffixSchedule = {
	{10, 6, 14},
	{9, 11, 12},
	{10, 8, 3},
	{9, 6, 124},
	{10, 123, 12},
	{9, 8, 13},
	{10, 7, 124},
	{9, 123, 14},
	{10, 11, 13},
	{9, 7, 3}
}
RE.DungeonNames = {
	[2] = "TJS",
	[165] = "SBG",
	[200] = "HOV",
	[210] = "COS",
	[399] = "RLP",
	[400] = "NO",
	[401] = "AV",
	[402] = "AA"
}
RE.RewardColors = {
	[1] = "FFFF0000",
	[2] = "FFFF2C00",
	[3] = "FFFE4200",
	[4] = "FFFC5300",
	[5] = "FFF86300",
	[6] = "FFF47000",
	[7] = "FFEF7E00",
	[8] = "FFE98A00",
	[9] = "FFE39600",
	[10] = "FFDBA100",
	[11] = "FFD2AC00",
	[12] = "FFC8B600",
	[13] = "FFBEC000",
	[14] = "FFB2CA00",
	[15] = "FFA4D400",
	[16] = "FF95DD00",
	[17] = "FF83E600",
	[18] = "FF6DEE00",
	[19] = "FF4EF700",
	[20] = "FF00FF00"
}
RE.Factions = {
	["Alliance"] = 1,
	["Horde"] = 2,
}

local function OrderedNext(t, n)
	local key = t[t.__next]
	if not key then return end
	t.__next = t.__next + 1
	return key, t.__source[key]
end

local function OrderedCompare(a, b)
	local gA = RE.DB[a].Group
	local gB = RE.DB[b].Group
	local pA = RE.Settings.PinnedCharacters[a]
	local pB = RE.Settings.PinnedCharacters[b]
	if pA and not pB then
		return true
	elseif not pA and pB then
		return false
	else
		if gA and not gB then
			return true
		elseif not gA and gB then
			return false
		end
	end
	if RE.Settings.Sorting == 1 then
		return a < b
	elseif RE.Settings.Sorting == 2 then
		local sA = RE.DB[a].Rating
		local sB = RE.DB[b].Rating
		return sA > sB
	elseif RE.Settings.Sorting == 3 then
		local kA = RE.DB[a].MapID
		local kB = RE.DB[b].MapID
		local lA = RE.DB[a].Level
		local lB = RE.DB[b].Level
		if kA == kB then
			return lA > lB
		else
			return kA > kB
		end
	end
end

local function OrderedPairs(t, f)
	local keys, kn = {__source = t, __next = 1}, 1
	for k in pairs(t) do
		keys[kn], kn = k, kn + 1
	end
	table.sort(keys, f)
	return OrderedNext, keys
end

-- Event functions

function RE:OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("CHAT_MSG_GUILD")
	self:RegisterEvent("CHAT_MSG_PARTY")
	self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
	self:RegisterEvent("CHAT_MSG_RAID")
	self:RegisterEvent("CHAT_MSG_RAID_LEADER")
end

function RE:OnEvent(self, event, name, ...)
	if event == "ADDON_LOADED" and name == "REKeys" then
		if not _G.REKeysDB2 then _G.REKeysDB2 = {} end
		if not _G.REKeysSettings then _G.REKeysSettings = RE.DefaultSettings end
		RE.DB = _G.REKeysDB2
		RE.Settings = _G.REKeysSettings
		for key, value in pairs(RE.DefaultSettings) do
			if RE.Settings[key] == nil then
				RE.Settings[key] = value
			end
		end
		_G.LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("REKeys", RE.AceConfig)
		RE.OptionsMenu = _G.LibStub("AceConfigDialog-3.0"):AddToBlizOptions("REKeys", "REKeys")

		RE.TooltipHeaderFont = CreateFont("REKeysTooltipHeaderFont")
		RE.TooltipHeaderFont:CopyFontObject(_G.GameTooltipHeaderText)
		RE.TooltipHeaderFont:SetFont(select(1, RE.TooltipHeaderFont:GetFont()), 15, "")

		RE.LDB = LDB:NewDataObject("REKeys", {
			type = "data source",
			text = "|cFF74D06CRE|rKeys",
			icon = "Interface\\Icons\\INV_Relics_Hourglass",
		})
		function RE.LDB:OnEnter()
			if RE.LDB.text == "|cFF74D06CRE|rKeys" or not RE.MPlusDataReceived then return end
			RE.Tooltip = QTIP:Acquire("REKeysTooltip", 5, "CENTER", "CENTER", "CENTER", "CENTER", "CENTER")
			if ElvUI then
				local red, green, blue = unpack(ElvUI[1].media.backdropfadecolor)
				RE.Tooltip:SetBackdropColor(red, green, blue, ElvUI[1].Tooltip and ElvUI[1].Tooltip.db.colorAlpha or 1)
			end
			RE.Tooltip:SetAutoHideDelay(0.1, self, function()
				if RE.TooltipTimer then
					RE.TooltipTimer:Cancel()
					RE.TooltipTimer = nil
				end
				QTIP:Release(RE.Tooltip)
				RE.Tooltip = nil
			end)
			RE.Tooltip:SetHeaderFont(RE.TooltipHeaderFont)
			RE:LORSearchStart()
			RE:FillTooltip()
			RE.Tooltip:SmartAnchorTo(self)
			RE.Tooltip:Show()
			RE.Tooltip:UpdateScrolling()
			RE.TooltipTimer = NewTicker(3, RE.RefreshTooltip)
		end
		function RE.LDB:OnClick(button)
			if button == "LeftButton" then
				LoadAddOn("Blizzard_WeeklyRewards")
				if _G.WeeklyRewardsFrame:IsVisible() then
					_G.WeeklyRewardsFrame:Hide()
				else
					_G.WeeklyRewardsFrame:Show()
				end
			elseif button == "MiddleButton" then
				local keyLink = RE:GetKeystoneLink()
				if keyLink ~= "" then
					SendChatMessage(keyLink, IsInGroup() and "PARTY" or "GUILD")
				end
			elseif button == "RightButton" then
				_G.Settings.OpenToCategory("REKeys")
			end
		end
		LDBI:Register("REKeys", RE.LDB, RE.Settings.MinimapButtonSettings)

		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_ENTERING_WORLD" then
		RE.PlayerRealm = select(2, UnitFullName("player"))
		RE.PlayerFaction = UnitFactionGroup("player")
		self:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
		RequestMapInfo()
		RequestCurrentAffixes()
		RequestRewards()
		After(10, RE.FindKeyDelay)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	elseif event == "ZONE_CHANGED_NEW_AREA" and RE.RewardsDirty then
		RE.RewardsDirty = false
		RequestMapInfo()
		RequestRewards()
	elseif event == "CHALLENGE_MODE_COMPLETED" then
		RE.RewardsDirty = true
		RequestMapInfo()
		RequestRewards()
		After(5, function() RE:FindKey(true) end)
	elseif event == "CHAT_MSG_GUILD" then
		RE:ParseChat(name, "GUILD", RE.Settings.ChatQueryGuild)
	elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
		RE:ParseChat(name, "PARTY", RE.Settings.ChatQueryGroup)
	elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
		RE:ParseChat(name, IsPartyLFG() and "INSTANCE_CHAT" or "RAID", RE.Settings.ChatQueryGroup)
	elseif event == "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE" then
		RE.MPlusDataReceived = true
	end
end

-- Main functions

function RE:FindKey(dungeonCompleted)
	local keystone = GetOwnedKeystoneChallengeMapID()
	local keystoneLevel = GetOwnedKeystoneLevel()

	if not RE.MPlusDataReceived then
		RequestCurrentAffixes()
		After(3, RE.FindKey)
		return
	end

	local resetTimestamp = GetSecondsUntilWeeklyReset()
	if resetTimestamp then
		if (resetTimestamp > RE.Settings.ResetTimestamp) or (GetServerTime() - RE.Settings.ServerTimestamp > 604800) then
			RE.Settings.ServerTimestamp = GetServerTime()
			RE.Settings.CurrentWeek = 0
			wipe(RE.DB)
		end
		RE.Settings.ResetTimestamp = resetTimestamp
	end
	if RE.Settings.CurrentWeek == 0 then
		local currentAffixes = GetCurrentAffixes()
		if currentAffixes and #currentAffixes ~= 0 then
			for i, affixes in ipairs(RE.AffixSchedule) do
				if currentAffixes[1].id == affixes[1] and currentAffixes[2].id == affixes[2] and currentAffixes[3].id == affixes[3] then
					RE.Settings.CurrentWeek = i
					break
				end
			end
		end
	end

	if not keystone then
		RE.LDB.text = "|cffe6cc80-|r"
	elseif keystone ~= RE.Keystone.MapID or keystoneLevel ~= RE.Keystone.Level then
		RE.Keystone.MapID = keystone
		RE.Keystone.Level = keystoneLevel
		if dungeonCompleted and IsInGroup() and not IsInRaid() then
			SendChatMessage("[REKeys] "..L["My new key"]..": "..RE:GetKeystoneLink(), "PARTY")
		end
		RE.LDB.text = "|cffe6cc80"..RE:GetShortMapName(RE.Keystone.MapID).." +"..RE.Keystone.Level.."|r"

		if QTIP:IsAcquired("REKeysTooltip") then
			RE:FillTooltip()
			RE.Tooltip:UpdateScrolling()
		end
	end
end

function RE:FillTooltip()
	local row
	local groupSeparator = false
	local pinSeparator = false
	local pinEmpty = next(RE.Settings.PinnedCharacters) == nil

	RE.Tooltip:Clear()
	RE.Tooltip:SetColumnLayout(5, "CENTER", "CENTER", "CENTER", "CENTER", "CENTER")
	RE.Tooltip:AddLine()
	RE.Tooltip:SetCell(1, 1, "", nil, nil, nil, nil, nil, nil, nil, 80)
	RE.Tooltip:SetCell(1, 2, "", nil, nil, nil, nil, nil, nil, 5, 5)
	RE.Tooltip:SetCell(1, 3, "", nil, nil, nil, nil, nil, nil, nil, 80)
	RE.Tooltip:SetCell(1, 4, "", nil, nil, nil, nil, nil, nil, 5, 5)
	RE.Tooltip:SetCell(1, 5, "", nil, nil, nil, nil, nil, nil, nil, 80)
	RE:GetAffixes()
	RE.Tooltip:AddLine()
	RE.Tooltip:AddSeparator()
	RE.Tooltip:AddLine()
	RE.Tooltip:SetColumnLayout(6, "LEFT", "CENTER", "LEFT", "CENTER", "LEFT")

	for name, payload in OrderedPairs(RE.DB, OrderedCompare) do
		if payload.Fresh or RE.Settings.OfflinePlayers or RE.Settings.PinnedCharacters[name] then
			if not pinEmpty and not RE.Settings.PinnedCharacters[name] and not pinSeparator then
				pinSeparator = true
				RE.Tooltip:AddLine()
				RE.Tooltip:AddSeparator()
				RE.Tooltip:AddLine()
			elseif RE.GroupFound and not payload.Group and not groupSeparator then
				groupSeparator = true
				RE.Tooltip:AddLine()
				RE.Tooltip:AddSeparator()
				RE.Tooltip:AddLine()
			end
			row = RE.Tooltip:AddLine("|c".._G.RAID_CLASS_COLORS[payload.Class].colorStr..strsplit("-", name).."|r", nil, "|cff"..(payload.Fresh and "e6cc80" or "95761d")..RE:GetShortMapName(payload.MapID).." +"..payload.Level.."|r", nil, RE:GetScore(name, payload.Rating, payload.Faction))
			RE:GetRowFill(row)
		end
	end

	RE.Tooltip:AddLine()
	if pinSeparator or groupSeparator then RE.Tooltip:AddLine() end
	RE.RowFill = true
end

function RE:LORSearchStart()
	if not RE.UpdateTimer then
		GuildRoster()
		RE.GroupFound = false
		RE:PurgeDB()
		RE.UpdateTimer = NewTimer(15, RE.LORSearchStop)
		LOR.RegisterCallback(RE, "KeystoneUpdate", "LORCallback")
		LOR.WipeKeystoneData()
		if IsInRaid() then
			LOR.RequestKeystoneDataFromRaid()
		elseif IsInGroup() then
			LOR.RequestKeystoneDataFromParty()
		end
		LOR.RequestKeystoneDataFromGuild()
	end
end

function RE:LORSearchStop()
	RE.UpdateTimer = nil
	LOR.UnregisterCallback(RE, "KeystoneUpdate", "LORCallback")
end

function RE.LORCallback(unitID, keystoneInfo, _)
	if keystoneInfo.challengeMapID > 0 then
		if not RE.DB[unitID] then
			RE.DB[unitID] = {["MapID"] = keystoneInfo.challengeMapID, ["Level"] = keystoneInfo.level, ["Rating"] = keystoneInfo.rating, ["Class"] = GetClassInfo(keystoneInfo.classID).classFile, ["Faction"] = UnitFactionGroup(unitID)}
		else
			RE.DB[unitID].MapID = keystoneInfo.challengeMapID
			RE.DB[unitID].Level = keystoneInfo.level
			RE.DB[unitID].Rating = keystoneInfo.rating
		end
		RE.DB[unitID].Group = UnitInParty(unitID) or (UnitInRaid(unitID) or false)
		RE.DB[unitID].Fresh = true
		if RE.DB[unitID].Group and not RE.Settings.PinnedCharacters[unitID] then
			RE.GroupFound = true
		end
		RE.TooltipDirty = true
	end
end

function RE:PurgeDB()
	local guildName = GetGuildInfo("player")
	local guildMembersNumber = GetNumGuildMembers()
	local guildMembers = {}

	if guildName then
		for i = 1, guildMembersNumber do
			local name = GetGuildRosterInfo(i)
			if name then
				guildMembers[name:gsub("%-"..RE.PlayerRealm, "")] = true
			end
		end
	end

	for name, _ in pairs(RE.DB) do
		RE.DB[name].Fresh = false
		if not guildMembers[name] and not RE.Settings.PinnedCharacters[name] then
			RE.DB[name] = nil
		end
	end
end

-- Support functions

function RE:RefreshTooltip()
	if QTIP:IsAcquired("REKeysTooltip") and RE.TooltipDirty then
		RE.TooltipDirty = false
		RE:FillTooltip()
		RE.Tooltip:UpdateScrolling()
	end
end

function RE:GetKeystoneLink()
	local keyLink = ""
	for bag = 0, _G.NUM_BAG_SLOTS do
		local bagSlots = GetContainerNumSlots(bag)
		for slot = 1, bagSlots do
			local info = GetContainerItemInfo(bag, slot)
			local itemID = info and info.itemID
            local hyperLink = info and info.hyperlink
			if itemID and IsItemKeystoneByID(itemID) and hyperLink then
				keyLink = hyperLink
				break
			end
		end
	end
	return keyLink
end

function RE:GetShortMapName(mapID)
	if RE.Settings.FullDungeonName then
		return GetMapUIInfo(mapID)
	else
		return RE.DungeonNames[mapID]
	end
end

function RE:GetAffixes()
	local currentAffixes = GetCurrentAffixes()
	if currentAffixes and #currentAffixes ~= 0 then
		if #currentAffixes == 4 then
			local bestRuns = RE:GetParsedBestRun()
			local leftPanel = "[|cffff0000-|r]"
			local centerPanel = "[|cffff0000-|r]"
			local rightPanel = "[|cffff0000-|r]"
			if bestRuns[1] > 0 then
				leftPanel = "[|c"..RE:GetKeystoneLevelColor(bestRuns[1]).."+"..bestRuns[1].."|r] [|c"..RE:GetKeystoneLevelColor(bestRuns[1])..GetRewardLevelFromKeystoneLevel(bestRuns[1]).."|r]"
			end
			if bestRuns[2] > 0 then
				centerPanel = "[|c"..RE:GetKeystoneLevelColor(bestRuns[2]).."+"..bestRuns[2].."|r] [|c"..RE:GetKeystoneLevelColor(bestRuns[2])..GetRewardLevelFromKeystoneLevel(bestRuns[2]).."|r]"
			end
			if bestRuns[3] > 0 then
				rightPanel = "[|c"..RE:GetKeystoneLevelColor(bestRuns[3]).."+"..bestRuns[3].."|r] [|c"..RE:GetKeystoneLevelColor(bestRuns[3])..GetRewardLevelFromKeystoneLevel(bestRuns[3]).."|r]"
			end
			RE.Tooltip:AddHeader(leftPanel, "|cffffffff|||r", centerPanel, "|cffffffff|||r", rightPanel)
			RE.Tooltip:AddLine()
			RE.Tooltip:AddSeparator()
			RE.Tooltip:AddLine()
		end
		RE.Tooltip:AddHeader("|cffffffff"..GetAffixInfo(currentAffixes[1].id).."|r", "|cffff0000|||r", "|cffffffff"..GetAffixInfo(currentAffixes[2].id).."|r", "|cffff0000|||r", "|cffffffff"..GetAffixInfo(currentAffixes[3].id).."|r")
		RE.Tooltip:AddLine()
	end
	if RE.Settings.CurrentWeek > 0 then
		local affixes = RE.AffixSchedule[RE.Settings.CurrentWeek % #RE.AffixSchedule + 1]
		RE.Tooltip:AddHeader("|cffbbbbbb"..GetAffixInfo(affixes[1]).."|r", "|cff00ff00|||r", "|cffbbbbbb"..GetAffixInfo(affixes[2]).."|r", "|cff00ff00|||r", "|cffbbbbbb"..GetAffixInfo(affixes[3]).."|r")
	else
		RE.Tooltip:AddHeader("|cffbbbbbb?|r", "|cff00ff00|||r", "|cffbbbbbb?|r", "|cff00ff00|||r", "|cffbbbbbb?|r")
	end
end

function RE:GetParsedBestRun()
	local bestRuns = {0, 0 ,0}
	local runHistory = GetRunHistory(false, true)
	if #runHistory > 0 then
		table.sort(runHistory, function(left, right) return left.level > right.level end)
		bestRuns[1] = runHistory[1].level
		if #runHistory >= 4 then
			bestRuns[2] = runHistory[4].level
		end
		if #runHistory >= 8 then
			bestRuns[3] = runHistory[8].level
		end
	end
	return bestRuns
end

function RE:GetRowFill(row)
	if RE.RowFill then
		RE.Tooltip:SetLineColor(row, 0, 0, 0, 0.35)
		RE.RowFill = false
	else
		RE.RowFill = true
	end
end

function RE:GetKeystoneLevelColor(level)
	if level > 20 then
		return RE.RewardColors[20]
	else
		return RE.RewardColors[level]
	end
end

function RE:GetScore(name, score, faction)
	if RaiderIO then
		faction = RE.Factions[faction] or RE.Factions[RE.PlayerFaction]
		local data = RaiderIO.GetProfile(name, faction)
		local r, g, b = RaiderIO.GetScoreColor(score)
		local output = "|cff"..string.format("%02x%02x%02x", r*255, g*255, b*255)..score.."|r "
		if data and data.mythicKeystoneProfile and data.mythicKeystoneProfile.mplusCurrent then
			for _, value in pairs(data.mythicKeystoneProfile.mplusCurrent.roles) do
				if value[1] == "tank" then output = output.."|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:0:19:22:41|t" end
				if value[1] == "healer" then output = output.."|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:1:20|t" end
				if value[1] == "dps" then output = output.."|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:22:41|t" end
			end
		end
		return output
	end
	return score
end

function RE:FindKeyDelay()
	if not RE.MPlusDataReceived then RequestCurrentAffixes() end
	RE:FindKey()
	_G.REKeysFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
	BUCKET:RegisterBucketEvent("BAG_UPDATE", 5, RE.FindKey)
	RE:LORSearchStart()
end

function RE:ParseChat(msg, channel, respond)
	if respond and not RE.KeyQueryLimit and msg == "!keys" then
		RE.KeyQueryLimit = true
		After(30, function() RE.KeyQueryLimit = false end)
		local keyLink = RE:GetKeystoneLink()
		if keyLink ~= "" then
			SendChatMessage(keyLink, channel)
		end
	end
end