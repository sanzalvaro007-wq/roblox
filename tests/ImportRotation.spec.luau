-- Comprueba que PropCatalog.ChooseImportRotation endereza los modelos importados venga
-- como venga el glTF (Z arriba, girados, del revés...).
--   lune run tests/ImportRotation.spec.luau build/MimicManor.rbxlx
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local place = roblox.deserializePlace(fs.readFile(process.args[1] or "build/MimicManor.rbxlx"))
local shared = place:GetService("ReplicatedStorage"):FindFirstChild("Shared")

local function load(module, env)
	local fn = luau.load(module.Source, { debugName = module.Name, environment = env })
	return fn()
end
local env = setmetatable({
	game = { GetService = function(_, name) return place:GetService(name) end },
	Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, Instance = roblox.Instance,
}, { __index = _G })
local PropCatalog = load(shared:FindFirstChild("PropCatalog"), env)
local fixtures = load({ Source = fs.readFile("tests/fixtures_import.luau"), Name = "fixtures" }, env)

local function abs(v) return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) end

local axes = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
local checked = 0
for _, right in axes do
	for _, up in axes do
		if math.abs(right:Dot(up)) < 0.5 then
			-- "importer" gira los modelos correctos con esta rotación y escala 0.3 (metros, etc.).
			local importer = CFrame.fromMatrix(Vector3.new(0, 0, 0), right, up)
			local samples = {}
			for id, f in fixtures do
				local def = PropCatalog.Get(id)
				table.insert(samples, {
					size = abs(importer:VectorToWorldSpace(f.size)) * 0.3,
					footprint = def.footprint,
					up = f.up and importer:VectorToWorldSpace(f.up),
					front = f.front and importer:VectorToWorldSpace(f.front),
				})
			end
			local fix = PropCatalog.ChooseImportRotation(samples)
			local total = fix * importer
			-- Tiene que quedar la identidad: Y arriba y -Z delante.
			assert(total.UpVector:Dot(Vector3.new(0, 1, 0)) > 0.99, "no queda de pie")
			assert(total.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.99, "no mira al frente")
			checked += 1
		end
	end
end
print(string.format("%d orientaciones de importación corregidas", checked))
