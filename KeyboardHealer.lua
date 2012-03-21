local KeyboardHealer = LibStub("AceAddon-3.0"):NewAddon("KeyboardHealer", "AceEvent-3.0", "AceHook-3.0")
local RaidRoster = KeyboardHealer:NewModule("RaidRoster")
local BindingButtons = KeyboardHealer:NewModule("BindingButtons")
local Config = KeyboardHealer:NewModule("Config")

local warnedThisCombat = false

-- Debug utility function

function KeyboardHealer:debugMessage(...)
	local messages = {...}
	for i, thing in ipairs(messages) do
		if type(thing) == "table" then
			messages[i] = table.concat(thing, ", ")
		else
			messages[i] = tostring(thing)
		end
	end
	messages = table.concat(messages, ", ") 
	print("<KeyboardHealer Debug> "..messages)
end

-- Addon functions

function KeyboardHealer:queueUpdateBindings()
	if KeyboardHealer.db.profile.group then
		local nextUnusedRaidID = GetNumRaidMembers() + 1
		for group = 1, 8 do
			groupMembers = RaidRoster:getGroup(group)
			for partyIndex = 1, 5 do
				if groupMembers[partyIndex] then
					BindingButtons:buttonInGroup(group, partyIndex).queuedTargetID = groupMembers[partyIndex].id
				else
					BindingButtons:buttonInGroup(group, partyIndex).queuedTargetID = nextUnusedRaidID
					nextUnusedRaidID = nextUnusedRaidID + 1
				end
			end
		
		end
	else
		raidMembers = RaidRoster:getAll()
		for i, rm in ipairs(raidMembers) do
			BindingButtons[i].queuedTargetID = rm.id
		end
		for i = #raidMembers + 1, 40 do
			BindingButtons[i].queuedTargetID = i
		end
	end
	if BindingButtons:hasUpdates() then
		if not UnitAffectingCombat("PLAYER") then -- if out of combat, set macro text now
			self:updateBindings()
		else  -- otherwise register event for leaving combat
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "updateBindings") -- yes this is what the leaving combat event is called
			if not warnedThisCombat then
				print([[<KeyboardHealer> Warning! Raid organization has been changed!  Keybindings will be wrong until you leave combat!]])
				warnedThisCombat = true
			end
		end
	end
end

function KeyboardHealer:updateBindings(event)	
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	BindingButtons:updateAll()
	-- name keybindings
	if warnedThisCombat then
		print([[<KeyboardHealer> Leaving combat; keybindings now fixed]])
		warnedThisCombat = false
	end
end

-- Events that could change the sorting

function KeyboardHealer:rosterEvent(event, ...)
	RaidRoster:updateRaid()
	self:queueUpdateBindings()
end

function KeyboardHealer:sortEvent() -- only ever used as a quasi-event
	RaidRoster:updateSort()
	self:queueUpdateBindings()
end

function KeyboardHealer:roleEvent(event, changedChar, _, _, newRole)
	RaidRoster:setRoleByName(changedChar, newRole)
	RaidRoster:updateSort()
	self:queueUpdateBindings()
end

local function setBlizzardRaidFrameSettings(grouped, sort)
	if grouped == nil then
		grouped = GetCVar("raidOptionKeepGroupsTogether")
	end
	if sort == nil then
		sort = GetCVar("raidOptionSortMode")
	end
	KeyboardHealer.db.profile.group = (grouped == "1")
	if grouped == "1" then
		sort = "group"
	end
	if sort == "alphabetical" then
		sort = "name"
	end
	KeyboardHealer.db.profile.grouped = group
	KeyboardHealer.db.profile.firstSort = sort
	if sort == "group" then
		KeyboardHealer.db.profile.secondSort = "id"
	else
		KeyboardHealer.db.profile.secondSort = "name"
	end
end

function KeyboardHealer:addonEvent(event, addon)
	-- real event "ADDON_LOADED" and quasi-event "setRaidFrame" are both covered automatically
	local raidFrameAddons = {Grid = true}
	if event == "initializeAuto" then -- called by KeyboardHealer somewhere, not a real event; need to find addon
		addon = "blizzard" -- if we don't find another one
		for a, _ in pairs(raidFrameAddons) do
			if IsAddOnLoaded(a) then
				addon = a
			end
		end
		-- clear old so it gets initialized
		KeyboardHealer.db.profile.raidFrame = nil
	end
	if addon == "blizzard" then
		setBlizzardRaidFrameSettings()
	end
 	-- update if the raid frame addon has been changed
	if addon ~= KeyboardHealer.db.profile.raidFrame then
		-- set appropriate settings
		if addon == "Grid" then
			KeyboardHealer.db.profile.group = true
			KeyboardHealer.db.profile.firstSort = "name"
			KeyboardHealer.db.profile.secondSort = "name"
		end
		-- update stuff
		KeyboardHealer.db.profile.raidFrame = addon
		Config:updateFrame()
		RaidRoster:updateSort()
		self:queueUpdateBindings()
	end
end

function KeyboardHealer:cvarEvent(cvar, value) -- not really an event; a hook of "SetCVar"
	if cvar == "raidOptionKeepGroupsTogether" then
		setBlizzardRaidFrameSettings(value, nil)
		RaidRoster:updateSort()
		self:queueUpdateBindings()
	elseif cvar == "raidOptionSortMode" then
		setBlizzardRaidFrameSettings(nil, value)
		RaidRoster:updateSort()
		self:queueUpdateBindings()
	end
end

function KeyboardHealer:setEventTypeEnabled(eventType, enable)
	local events = {
		rosterEvent = {"RAID_ROSTER_UPDATE", "PARTY_CONVERTED_TO_RAID", "PLAYER_ENTERING_BATTLEGROUND"},
		roleEvent = {"ROLE_CHANGED_INFORM"},
		addonEvent = {"ADDON_LOADED"}, -- possible to load but not unload addons without a complete reload
	}
	local hooks = {
		cvarEvent = {"SetCVar"}
	}
	if enable then
		if events[eventType] then
			for _, event in pairs(events[eventType]) do
				self:RegisterEvent(event, eventType)
			end
		end
		if hooks[eventType] then
			for _, hook in pairs(hooks[eventType]) do
				if not self:IsHooked(hook) then
					self:SecureHook(hook, eventType)
				end
			end
		end
	else	
		if events[eventType] then
			for _, event in pairs(events[eventType]) do
				self:UnregisterEvent(event, eventType)
			end
		end
		if hooks[eventType] then
			for _, hook in pairs(hooks[eventType]) do
				self:Unhook(hook)
			end
		end
	end
end


-- Initialization

function KeyboardHealer:tryInitialize()
	-- called by the OnEnable of this, RaidRoster, and BindingButtons
	local initialized
	if initialized then 
		return 
	end
	if RaidRoster.initialized and BindingButtons.initialized then
		if KeyboardHealer.db.profile.autoDetectRaidFrame then
			self:addonEvent("initializeAuto")
		elseif KeyboardHealer.db.profile.raidFrame == "blizzard" then
			setBlizzardRaidFrameSettings()
		end
		Config:enableProperSortModeOptions()
		self:setEventTypeEnabled("rosterEvent", true)
		Config:enableProperEvents()
		RaidRoster:updateRaid()
		RaidRoster:updateSort()
		self:queueUpdateBindings()
		initialized = true
	end
end

function KeyboardHealer:OnInitialize()
	-- Slash command
	SLASH_KEYBOARDHEALER1 = "/keyboardhealer"
	SlashCmdList["KEYBOARDHEALER"] = function() InterfaceOptionsFrame_OpenToCategory("KeyboardHealer") end
end

function KeyboardHealer:OnEnable()
	-- initialize bindings
	self:tryInitialize()
	-- register events that mean that raid arrangement could have changed
	print([[<KeyboardHealer> addon loaded: type "/keyboardhealer" for options and more information]])
	-- TODO: this should mention what frames the buttons are set for.
end
