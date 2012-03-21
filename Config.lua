local KeyboardHealer = LibStub("AceAddon-3.0"):GetAddon("KeyboardHealer")
local BindingButtons = KeyboardHealer:GetModule("BindingButtons")
local Config = KeyboardHealer:GetModule("Config")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

-- make things exist so they can be referenced

local options = { }
local customConfigOptions = { }
local allBindings = function() end

-- 

function Config:updateFrame()
	-- TODO: make it display raidFrame value even when it's diabled somehow
	LibStub("AceConfigRegistry-3.0"):NotifyChange("KeyboardHealer")
end

-- Setters and getters

function Config:enableProperSortModeOptions()
	-- set the db.profile values
	options.args.sorting.args.raidFrame.disabled = KeyboardHealer.db.profile.autoDetectRaidFrame
	if KeyboardHealer.db.profile.raidFrame == "other" then
		for key, value in pairs(customConfigOptions) do
			options.args.sorting.args[key] = value
		end
	else
		for key, _ in pairs(customConfigOptions) do
			options.args.sorting.args[key] = nil
		end
	end
	self:updateFrame()
end

function Config:enableProperEvents()
	-- these will enable the event if the second argument is true, disable otherwise
	KeyboardHealer:setEventTypeEnabled("addonEvent", KeyboardHealer.db.profile.autoDetectRaidFrame)
	KeyboardHealer:setEventTypeEnabled("cvarEvent", KeyboardHealer.db.profile.raidFrame == "blizzard")
	KeyboardHealer:setEventTypeEnabled("roleEvent", KeyboardHealer.db.profile.firstSort == "role"
							or KeyboardHealer.db.profile.secondSort == "role")
end

function Config:setPreference(info, val)
	KeyboardHealer.db.profile[info[#info]] = val
	if info[#info-1] == "sorting" then
		if info[#info] == "autoDetectRaidFrame" then
			if val == true then
				KeyboardHealer:addonEvent("initializeAuto")
			end
		elseif info[#info] == "raidFrame" then
			KeyboardHealer:addonEvent("setRaidFrame", val)
		elseif info[#info] == "group" then
			-- Rename the keybindings and update display
			BindingButtons:nameBindings()
			self:updateFrame()
		KeyboardHealer:sortEvent()
		end
		self:enableProperSortModeOptions()
		self:enableProperEvents()
	elseif info[#info] == "numberOfBindings" then
		options.args.keybindings.args = allBindings()
	end
end

function Config:getPreference(info)
	return KeyboardHealer.db.profile[info[#info]]
end

function Config:setKey(info, val)
	local bindingString = BindingButtons[tonumber(info[#info])]:getBindingString()
	local oldKey = GetBindingKey(bindingString)
	-- unbind old key
	if oldKey ~= nil then
		SetBinding(oldKey, nil)
	end
	-- bind new one if it's not escape, which should just clear
	if key ~= "ESCAPE" then
		SetBinding(val, bindingString)
	end
	-- save
	SaveBindings(GetCurrentBindingSet())
end

function Config:getKey(info)
	local bindingString = BindingButtons[tonumber(info[#info])]:getBindingString()
	return GetBindingKey(bindingString)
end

-- Functions that go into building options table

local textInABox = function(title, text, order) 
	return {
		type = "group",
		name = title,
		inline = true,
		order = order,
		args = {
			text = {
				type = "description",
				fontSize = "medium",
				name = text
			}
		}
	}
end

local keybindingButton = function(index)
	local button = BindingButtons[tonumber(index)]
	return {
		name = button:getName(KeyboardHealer.db.profile.group),
		type = "keybinding",
		order = 20 + index,
	}
end

allBindings = function() -- local keyword is earlier
	local args = {
		numberOfBindings = {
			order = 10,
			name = "Number of bindings to edit",
			type = "select",
			get = "getPreference",
			set = "setPreference",
			values = {
				["10"] = 10,
				["25"] = 25,
				["40"] = 40
			},
		},
		bindingText = {
			type = "description",
			fontSize = "medium",
			order = 11,
			name = "Bindings beyond the number chosen aren't lost; this just sets how many to show in the panel right now."

		}
	}
	for i = 1, KeyboardHealer.db.profile.numberOfBindings do
		args[tostring(i)] = keybindingButton(i)
	end
	return args
end

-- options table

local sortTypes = {
	name = "Name",
	id = "Raid ID",
	role = "Role",
	group = "Group"
}

customConfigOptions = { -- local keyword earlier
	group = {
		order = 10,
		name = "Grouped",
		desc = "whether groups are seperated",
		type = "toggle",
	},
	firstSort = {
		order = 11,
		name = "Sorted by",
		desc = "How players are sorted, or sorted within groups if grouped",
		type = "select",
		values = sortTypes
	},
	secondSort = {
		order = 12,
		name = "Subsorted by",
		desc = "A secondary sort if the first sorting is not strict",
		type = "select",
		values = sortTypes
	},
}

options = { -- local keyword is earlier
	type = "group",
	name = "KeyboardHealer",
	handler = Config,
	set = "setPreference",
	get = "getPreference",
	args = {
		sorting = {
			type = "group",
			name = "How your raid frames are organized",
			inline = true,
			order = 10,
			args = {	
				autoDetectRaidFrame = {
					order = 4,
					name = "Auto-detect raid frame",
					desc = "Auto-detect what raid frame you use",
					type = "toggle"
				},
				raidFrame = {
					order = 5,
					name = "Raid Frame",
					type = "select",
					desc = "What raid frame you use.  Un-check auto-detect if you want to select this manually.",
					values = { -- addon names capitalized to match actual name
						blizzard = "Blizzard's built-in",
						Grid = "Grid",
						other = "Other; set sorting manually"
					}
				},	
			},
		},
		keybindings = {
			type = "group",
			name = "keybindings",
			inline = true,
			order = 40,	
			get = "getKey",
			set = "setKey"
			-- args is nonstatic
		},
		help = textInABox(
			"Help", 
			[[In a party layout the group 1 keybindings will target the normal party targets.]],
			50
		),
		about = textInABox(
			-- this-version added in OnEnable
			"About", [[This is an early development version.

You can contact me via the KeyboardHealer page on curseforge or by emailing me at luacayenne@gmail.com.]],
			60
		)
	}
}


-- Set up

defaults = {
	profile = {
		autoDetectRaidFrame = true,
		group = true,
		firstSort = "id",
		secondSort = "id",
		numberOfBindings = "10"
	}
}

function Config:OnEnable()
	-- saved preferences; needed everywhere
	if not KeyboardHealer.db then
		KeyboardHealer.db = LibStub("AceDB-3.0"):New("KeyboardHealerDB", defaults, true)
	end
	-- main options panel 
	options.args.about.args.text.name =
		"KeyboardHealer by Cayenne, version "
		..GetAddOnMetadata("KeyboardHealer", "Version")
		.."\n\n"..options.args.about.args.text.name
	options.args.keybindings.args = allBindings()
	AceConfig:RegisterOptionsTable("KeyboardHealer", options) 
	AceConfigDialog:AddToBlizOptions("KeyboardHealer")
end
