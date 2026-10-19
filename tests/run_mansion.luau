-- Arnés: construye 200 mansiones reales (MansionService + MansionBuilder) dentro de Lune,
-- sobre el place generado por Rojo, y comprueba que no falla ninguna.
--   rojo build -o build/MimicManor.rbxlx
--   lune run tests/run_mansion.luau build/MimicManor.rbxlx
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local process = require("@lune/process")

local place = roblox.deserializePlace(fs.readFile(process.args[1] or "build/MimicManor.rbxlx"))
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local pivots = {}
roblox.implementProperty("Model", "WorldPivot", function(m) return pivots[m] or CFrame.new() end, function(m, v) pivots[m] = v end)
roblox.implementMethod("Model", "GetPivot", function(m) return pivots[m] or CFrame.new() end)
roblox.implementMethod("Model", "PivotTo", function(m, target)
	local current = pivots[m] or CFrame.new()
	local delta = target * current:Inverse()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end
	end
	pivots[m] = target
end)
roblox.implementMethod("Instance", "WaitForChild", function(i, name) local c = i:FindFirstChild(name); assert(c, "WaitForChild falló: " .. name); return c end)

local RandomShim = {}
function RandomShim.new(seed)
	local state = (seed % 2147483646) + 1
	local function nf() state = (state * 48271) % 2147483647; return (state - 1) / 2147483646 end
	return { NextInteger = function(_, a, b) return a + math.floor(nf() * (b - a + 1)) end, NextNumber = function() return nf() end }
end

local services = {
	CollectionService = { AddTag = function(_, inst, tag) inst:AddTag(tag) end },
	RunService = { IsServer = function() return true end, IsStudio = function() return true end },
}
local game = {}
function game.GetService(_, name) return services[name] or place:GetService(name) end
local workspace = place:GetService("Workspace")

local cache = {}
local function makeRequire()
	local function req(module)
		if cache[module] ~= nil then return cache[module] end
		local env = setmetatable({
			game = game, workspace = workspace, script = module, require = nil,
			Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum,
			UDim2 = roblox.UDim2, UDim = roblox.UDim, Random = RandomShim, task = task,
		}, { __index = _G })
		env.require = req
		local fn = luau.load(module.Source, { debugName = module:GetFullName(), environment = env })
		local result = fn()
		cache[module] = result
		return result
	end
	return req
end
local require2 = makeRequire()

local server = place:GetService("ServerScriptService"):FindFirstChild("Server")
local MansionService = require2(server.Services.MansionService)

local totals = { parts = 0, props = 0, lamps = 0, fuses = 0, batteries = 0 }
local N = 200
for seed = 1, N do
	local m = MansionService.Generate(seed)
	local parts = 0
	for _, d in m.Model:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
	totals.parts += parts
	totals.props += #m.Model.Props:GetChildren()
	totals.lamps += #m.Lamps
	totals.fuses += #m.FuseSpawns
	totals.batteries += #m.BatterySpawns
	assert(#m.InvestigatorSpawns == 7, "spawns")
	assert(m.FuseBox and m.Exit and m.AnomalySpawn, "faltan puntos")
	assert(#m.FuseSpawns >= 3, "pocos puntos de fusible en semilla " .. seed)
	assert((m.AnomalySpawn.Position - m.InvestigatorSpawns[1].Position).Magnitude > 36, "la Anomalía empieza pegada al vestíbulo")
end
print(string.format("%d mansiones OK | media: %d partes, %d muebles, %d lámparas, %d puntos de fusible, %d pilas",
	N, totals.parts // N, totals.props // N, totals.lamps // N, totals.fuses // N, totals.batteries // N))
local Layout = require2(server.Mansion.MansionLayout)
local Builder = require2(server.Mansion.MansionBuilder)
local Config = require2(place:GetService("ReplicatedStorage").Shared.Config)
local rng = { int = function(a, b) return math.random(a, b) end, float = math.random }
local fb = Builder.Build(Layout.Fallback(Config.Mansion, rng), rng)
print("layout seguro construido:", #fb.Model.Props:GetChildren(), "muebles,", #fb.Lamps, "lámparas")
