local KeyboardHealer = LibStub("AceAddon-3.0"):GetAddon("KeyboardHealer")
local BindingButtons = KeyboardHealer:GetModule("BindingButtons")

-- SecureButton class

SecureButton = { }
SecureButton.__index = SecureButton

function SecureButton:new(index)
	local o = { queuedTargetID = index, index = index }
	o.frame = CreateFrame("Button", "KeyboardHealerSB"..index, UIParent, "SecureActionButtonTemplate")
	o.frame:SetAttribute("type", "macro")
	o.frame:RegisterForClicks("AnyUp")
	if index <= 5 then
		local partyIDs = {"PLAYER", "PARTY1", "PARTY2", "PARTY3", "PARTY4"}
		o.partyTarget = partyIDs[index]
	end
	setmetatable(o, SecureButton)
	return o
end

function SecureButton:updateTarget()
	if self.queuedTargetID ~= self.currentTargetID then
		if self.partyTarget == nil then
			macroText = "/target RAID"..self.queuedTargetID
		else
			macroText = "/target [group:raid] RAID"..self.queuedTargetID.."; "..self.partyTarget
		end
		self.frame:SetAttribute("macrotext", macroText)
		self.currentTargetID = self.queuedTargetID
	end
end

function SecureButton:getName()
	if KeyboardHealer.db.profile.group then
		local group = ceil(self.index/5)
		local partyID = self.index % 5
		if partyID == 0 then
			partyID = 5
		end
		return "Target player "..partyID.." in group "..group
	else
		return "Target raid member "..self.index
	end
end

function SecureButton:getBindingString()
	return "CLICK KeyboardHealerSB"..self.index..":LeftButton"
end

-- Module functions

function BindingButtons:buttonInGroup(group, partyID)
	return self[(group-1)*5+partyID]
end

function BindingButtons:createAll()
	for i = 1, 40 do
		self[i] = SecureButton:new(i)
	end
end

function BindingButtons:hasUpdates()
	for _, b in ipairs(self) do
		if b.queuedTargetID ~= b.currentTargetID then
			return true
		end
	end
	return false
end

function BindingButtons:updateAll()
	for _, b in ipairs(self) do
		b:updateTarget()
	end
end

function BindingButtons:nameBindings()
	BINDING_HEADER_KEYBOARDHEALER = "KeyboardHealer"
	for _, b in ipairs(self) do
		_G["BINDING_NAME_"..b:getBindingString()] = b:getName()
	end
end

function BindingButtons:OnEnable()
	-- saved preferences; needed everywhere
	if not KeyboardHealer.db then
		KeyboardHealer.db = LibStub("AceDB-3.0"):New("KeyboardHealerDB", defaults, true)
	end
	-- initialization
	self:createAll()
	self:nameBindings()
	BindingButtons.initialized = true
	KeyboardHealer:tryInitialize() -- in case this is the last necessary thing initialized
end
