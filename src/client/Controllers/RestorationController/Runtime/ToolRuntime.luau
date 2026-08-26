local Displayedtool = require(script.Parent.DisplayedTool)

local Toolruntime = {}
Toolruntime.__index = Toolruntime

function Toolruntime.new(Tools, Interface)
	return setmetatable({
		Tools = Tools,
		Interface = Interface,
		Display = Displayedtool.new(),
		SelectedName = "Transform",
		Cleaning = false,
	}, Toolruntime)
end

function Toolruntime:SetObject(Object: (Model | BasePart)?)
	self.Object = Object
end

function Toolruntime:Context()
	return {
		Object = self.Object,
		Display = self.Display,
		IsUsing = self.Cleaning,
		SetUsing = function(Value) self.Cleaning = Value end,
	}
end

function Toolruntime:Select(Name: string)
	local Definition = self.Tools[Name]
	if not Definition or not self.Interface.Buttons[Name] then return end
	local Previous = self.Tools[self.SelectedName]
	if Previous and Previous.OnDeselected then Previous.OnDeselected(self:Context()) end
	self.Cleaning = false
	self.SelectedName = Name
	self.Interface:Select(Name, Definition)
	self.Display:Select(Definition)
	if Definition.OnSelected then Definition.OnSelected(self:Context()) end
end

function Toolruntime:InputBegan()
	local Definition = self.Tools[self.SelectedName]
	if Definition.OnInputBegan then Definition.OnInputBegan(self:Context()) end
end

function Toolruntime:InputEnded()
	local Definition = self.Tools[self.SelectedName]
	if Definition.OnInputEnded then Definition.OnInputEnded(self:Context()) end
	self.Cleaning = false
end

function Toolruntime:Update(Deltatime: number)
	if not self.Object then return end
	local Definition = self.Tools[self.SelectedName]
	local Context = self:Context()
	local Lockedpivot = Definition.GetLockedPivot and Definition.GetLockedPivot(Context) or nil
	self.Display:Update(
		Deltatime,
		self.Object,
		self.Cleaning,
		Lockedpivot
	)
	if Definition.OnUpdate then Definition.OnUpdate(Context) end
end

function Toolruntime:Destroy()
	local Definition = self.Tools[self.SelectedName]
	if Definition and Definition.OnDeselected then Definition.OnDeselected(self:Context()) end
	self.Cleaning = false
	self.Display:Destroy()
	self.SelectedName = "Transform"
end

return Toolruntime
