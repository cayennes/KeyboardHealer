local KeyboardHealer = LibStub("AceAddon-3.0"):GetAddon("KeyboardHealer")
local RaidRoster = KeyboardHealer:GetModule("RaidRoster")

-- SortMethod class

SortMethod = { }
SortMethod.__index = SortMethod

function SortMethod:new(sortBy, group)
	local o = { 
		sortBy = sortBy,
		group = group
	}
	setmetatable(o, SortMethod)
	return o
end

function SortMethod:getCompareFunction()
	local roleOrder = {TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4}
	local compare = function(member1, member2)
		for _, sortBy in ipairs(self.sortBy) do
			if member1[sortBy] ~= member2[sortBy] then
				if sortBy ~= "role" then
					return member1[sortBy] < member2[sortBy]
				else
					return roleOrder[member1["role"]] < roleOrder[member2["role"]]
				end
			end
		end
		return false
	end
	return compare
end

-- RaidMember class

local RaidMember = { 
	sortMethod = { }
}
RaidMember.__index = RaidMember

function RaidMember:new(id)
	local o = {id = id}
	o.name, _, o.group =  GetRaidRosterInfo(id)
	o.role = UnitGroupRolesAssigned("RAID"..id)
	setmetatable(o, RaidMember)
	return o
end

-- module functions

function RaidRoster:setRoleByName(name, role)
	for _, rm in ipairs(self) do
		if rm.name == name then
			rm.role = role
			return
		end
	end
end

function RaidRoster:updateRaid()
	for i = 1, GetNumRaidMembers() do
		self[i] = RaidMember:new(i)
	end
	for i = GetNumRaidMembers() + 1, 40 do
		self[i] = nil
	end
end

function RaidRoster:updateSort()
	self.sortMethod = SortMethod:new(
		{ 
			KeyboardHealer.db.profile.firstSort, 
			KeyboardHealer.db.profile.secondSort
		}, 
		KeyboardHealer.db.profile.group
	)
	RaidMember.__lt = self.sortMethod:getCompareFunction()
end

function RaidRoster:getGroup(group)
	local groupMembers = {}
	group = tonumber(group)
	for i, member in ipairs(self) do
		if member.group == group then
			groupMembers[#groupMembers + 1] = member
		end
	end
	table.sort(groupMembers)
	return groupMembers
end

function RaidRoster:getAll()
	local all = {}
	for i, rm in ipairs(self) do
		all[i] = rm
	end
	table.sort(all)
	return all
end

function RaidRoster:OnInitialize()
	-- saved preferences; needed everywhere
	if not KeyboardHealer.db then
		KeyboardHealer.db = LibStub("AceDB-3.0"):New("KeyboardHealerDB", defaults, true)
	end
	RaidRoster.initialized = true
	KeyboardHealer:tryInitialize() -- in case this is the last necessary thing loaded
end
