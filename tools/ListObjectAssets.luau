local Objects = game:GetService("ReplicatedStorage"):WaitForChild("Asset"):WaitForChild("Object")
local Shared = {
	["116108341313813"] = true,
	["136173134841464"] = true,
	["136254375804004"] = true,
	["87402903792010"] = true,
	["79361514123085"] = true,
	["136943980377010"] = true,
	["136672328215757"] = true,
	["83560616974311"] = true,
	["125503304178483"] = true,
	["133481586301479"] = true,
	["118963385146541"] = true,
	["91657620068126"] = true,
	["95412805630635"] = true,
}

local Found = { Images = {}, Meshes = {} }

local function Add(Kind: string, Content: string, Object: Instance)
	local Id = string.match(Content, "%d+")
	if not Id or Shared[Id] then
		return
	end
	local Entry = Found[Kind][Id]
	if not Entry then
		Entry = { Objects = {} }
		Found[Kind][Id] = Entry
	end
	Entry.Objects[Object.Name] = true
end

for _, Object in ipairs(Objects:GetChildren()) do
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("MeshPart") then
			Add("Meshes", Descendant.MeshId, Object)
		elseif Descendant:IsA("Decal") then
			Add("Images", Descendant.Texture, Object)
		elseif Descendant:IsA("ImageLabel") and Descendant:FindFirstAncestorWhichIsA("SurfaceGui") then
			Add("Images", Descendant.Image, Object)
		end
	end
end

for _, Kind in ipairs({ "Images", "Meshes" }) do
	local Ids = {}
	for Id in pairs(Found[Kind]) do
		table.insert(Ids, Id)
	end
	table.sort(Ids)
	print(string.format("===== %s to share: %d =====", Kind, #Ids))
	for _, Id in ipairs(Ids) do
		local Names = {}
		for Name in pairs(Found[Kind][Id].Objects) do
			table.insert(Names, Name)
		end
		table.sort(Names)
		print(Id .. "  (" .. table.concat(Names, ", ") .. ")")
	end
end
