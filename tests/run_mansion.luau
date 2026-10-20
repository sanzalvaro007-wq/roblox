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
local Instance, Vector3 = roblox.Instance, roblox.Vector3
-- CFrame.lookAt de Lune falla cuando se mira justo a lo largo de ±Z (devuelve el sentido
-- contrario); en Roblox es correcto. Lo reimplementamos para que el arnés mida bien.
local CFrame = setmetatable({
	lookAt = function(at, target, up)
		local look = (target - at).Unit
		local upv = up or Vector3.new(0, 1, 0)
		local right = look:Cross(upv)
		if right.Magnitude < 1e-6 then
			right = Vector3.new(1, 0, 0)
		end
		right = right.Unit
		return roblox.CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end,
}, { __index = roblox.CFrame })

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
			Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, ColorSequence = roblox.ColorSequence, UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2,
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
local Doors = require2(server.Mansion.Doors)

-- Caja alineada con los ejes de una pieza (aproximada para piezas giradas).
local function aabb(p)
	local cf, size = p.CFrame, p.Size
	local half = Vector3.new(0, 0, 0)
	for _, axis in { cf.RightVector * size.X, cf.UpVector * size.Y, cf.LookVector * size.Z } do
		half += Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)) / 2
	end
	return cf.Position - half, cf.Position + half
end
local function overlap(aLo, aHi, bLo, bHi, margin)
	return aLo.X < bHi.X - margin and aHi.X > bLo.X + margin
		and aLo.Y < bHi.Y - margin and aHi.Y > bLo.Y + margin
		and aLo.Z < bHi.Z - margin and aHi.Z > bLo.Z + margin
end
local SOLID_STRUCTURE = { Wall = true, Lintel = true, DoorFrame = true }
local function inside(part, point, margin)
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) < h.X + margin and math.abs(p.Y) < h.Y + margin and math.abs(p.Z) < h.Z + margin
end
-- Puntos que recorre la hoja de una puerta al abrirse hacia los dos lados.
local function sweepPoints(door)
	local closed, width = door:GetAttribute("ClosedCFrame"), door:GetAttribute("Width")
	local h = door.Size.Y
	local points = {}
	for _, sign in { 1, -1 } do
		for deg = 0, 100, 10 do
			local cf = Doors.HingeCFrame(closed, width, sign * math.rad(deg))
			for t = -0.5, 0.5001, 0.1 do
				for _, y in { -h / 2 + 0.4, 0, h / 2 - 0.4 } do
					table.insert(points, (cf * CFrame.new(t * width, y, 0)).Position)
				end
			end
		end
	end
	return points
end
-- Pieza directamente dentro de la carpeta (un mueble entero).
local function topOf(part, folder)
	local node = part
	while node.Parent ~= folder do
		node = node.Parent
	end
	return node
end

local totals = { parts = 0, props = 0, lamps = 0, fuses = 0, batteries = 0, doors = 0, furniture = 0, paintings = 0 }
local kindsSeen = {}
local clashes = { wall = 0, door = 0, fuse = 0, prop = 0, propdoor = 0, fusedoor = 0, furniture = 0, sweep = 0, openpanel = 0 }
local pieceCounts = {}
local chairsAtTable, diningTables = 0, 0
local clashExamples = {}
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
	assert(#m.Doors == #m.Layout.doors, "faltan puertas en semilla " .. seed)
	totals.doors += #m.Doors
	totals.furniture += #m.Model.Furniture:GetChildren()
	totals.paintings += #m.Model.Decor:GetChildren()
	for _, room in m.Layout.rooms do
		kindsSeen[room.kind] = (kindsSeen[room.kind] or 0) + 1
	end

	-- Choques: muebles de sala con paredes y puertas cerradas; cajas de fusible con muebles.
	local walls, doorsBoxes, furnitureBoxes, propBoxes = {}, {}, {}, {}
	for _, p in m.Model.Structure:GetChildren() do
		if SOLID_STRUCTURE[p.Name] then
			local lo, hi = aabb(p)
			table.insert(walls, { lo, hi })
		end
	end
	for _, door in m.Doors do
		local closed = door:GetAttribute("ClosedCFrame")
		local half = Vector3.new(door.Size.X / 2, door.Size.Y / 2, 3.5)
		-- Zona de barrido aproximada: la hoja cerrada más 3.5 studs a cada lado.
		local lo, hi = aabb({ CFrame = closed, Size = Vector3.new(door.Size.X, door.Size.Y, 7) })
		table.insert(doorsBoxes, { lo, hi })
	end
	for _, d in m.Model.Furniture:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			local lo, hi = aabb(d)
			table.insert(furnitureBoxes, { lo, hi, d })
		end
	end
	for _, d in m.Model.Props:GetDescendants() do
		if d:IsA("BasePart") then
			local lo, hi = aabb(d)
			table.insert(propBoxes, { lo, hi, d })
		end
	end
	local function note(kind, msg)
		clashes[kind] += 1
		if #clashExamples < 12 then
			table.insert(clashExamples, string.format("semilla %d: %s", seed, msg))
		end
	end
	for _, f in furnitureBoxes do
		for _, wl in walls do
			if overlap(f[1], f[2], wl[1], wl[2], 0.05) then
				note("wall", f[3].Parent.Name .. "/" .. f[3].Name .. " atraviesa una pared")
				break
			end
		end
		for _, db in doorsBoxes do
			if overlap(f[1], f[2], db[1], db[2], 0.05) then
				note("door", f[3].Parent.Name .. "/" .. f[3].Name .. " estorba una puerta")
				break
			end
		end
		for _, pb in propBoxes do
			if overlap(f[1], f[2], pb[1], pb[2], 0.05) then
				note("prop", f[3].Parent.Name .. "/" .. f[3].Name .. " choca con un mueble del catálogo " .. pb[3].Parent:GetAttribute("PropId"))
				break
			end
		end
	end
	for _, pb in propBoxes do
		for _, db in doorsBoxes do
			if overlap(pb[1], pb[2], db[1], db[2], 0.05) then
				note("propdoor", "mueble del catálogo " .. tostring(pb[3].Parent:GetAttribute("PropId")) .. " estorba una puerta")
				break
			end
		end
	end
	-- Lo que barre cada hoja (abriéndose hacia cualquier lado) tiene que estar libre.
	local sweeps = {}
	for _, door in m.Doors do
		local points = sweepPoints(door)
		table.insert(sweeps, points)
		local center = door:GetAttribute("ClosedCFrame").Position
		for _, list in { furnitureBoxes, propBoxes } do
			for _, f in list do
				local part = f[3]
				local flat = (part.CFrame.Position - center) * Vector3.new(1, 0, 1)
				if flat.Magnitude < door.Size.X + part.Size.Magnitude / 2 + 1 then
					for _, point in points do
						if inside(part, point, 0.15) then
							note("sweep", part.Parent.Name .. "/" .. part.Name .. " está donde gira una puerta")
							break
						end
					end
				end
			end
		end
		-- Las puertas que empiezan abiertas llevan los adornos pegados a la hoja.
		for _, child in door:GetChildren() do
			if child:IsA("BasePart") and not inside(door, child.CFrame.Position, 0.6) then
				note("openpanel", "adorno " .. child.Name .. " separado de su puerta")
			end
		end
	end
	-- Muebles de sala que se meten unos en otros.
	for i = 1, #furnitureBoxes do
		local a = furnitureBoxes[i]
		for j = i + 1, #furnitureBoxes do
			local b = furnitureBoxes[j]
			if topOf(a[3], m.Model.Furniture) ~= topOf(b[3], m.Model.Furniture) and overlap(a[1], a[2], b[1], b[2], 0.05) then
				note("furniture", topOf(a[3], m.Model.Furniture).Name .. " choca con " .. topOf(b[3], m.Model.Furniture).Name)
			end
		end
	end
	-- Cuántas veces sale cada pieza, y sillas del comedor junto a su mesa.
	local tables = {}
	for _, piece in m.Model.Furniture:GetChildren() do
		pieceCounts[piece.Name] = (pieceCounts[piece.Name] or 0) + 1
		if piece.Name == "DiningTable" then
			table.insert(tables, piece:FindFirstChild("Top").CFrame.Position)
		end
	end
	diningTables += #tables
	for _, prop in m.Model.Props:GetChildren() do
		if prop:GetAttribute("PropId") == "Chair" then
			for _, top in tables do
				local primary = prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart")
				if primary and ((primary.CFrame.Position - top) * Vector3.new(1, 0, 1)).Magnitude < 6 then
					chairsAtTable += 1
					break
				end
			end
		end
	end

	for _, pos in m.FuseSpawns do
		local lo = pos - Vector3.new(1.6, 0.4, 1.6)
		local hi = pos + Vector3.new(1.6, 2, 1.6)
		for _, points in sweeps do
			local hitSweep = false
			for _, point in points do
				if point.X > lo.X and point.X < hi.X and point.Y > lo.Y and point.Y < hi.Y and point.Z > lo.Z and point.Z < hi.Z then
					hitSweep = true
					break
				end
			end
			if hitSweep then
				note("sweep", "caja de fusible donde gira una puerta")
				break
			end
		end
		for _, db in doorsBoxes do
			if overlap(lo, hi, db[1], db[2], 0.05) then
				note("fusedoor", "caja de fusible delante de una puerta")
				break
			end
		end
		for _, f in furnitureBoxes do
			if overlap(lo, hi, f[1], f[2], 0.05) then
				note("fuse", "caja de fusible dentro de " .. f[3].Parent.Name)
				break
			end
		end
	end
end
print(string.format("puertas %d, muebles de sala %d, cuadros %d (medias)", totals.doors // N, totals.furniture // N, totals.paintings // N))
local kindList = {}
for k, v in kindsSeen do
	table.insert(kindList, k .. "=" .. v)
end
table.sort(kindList)
print("tipos de sala: " .. table.concat(kindList, ", "))
local pieceList = {}
for k, v in pieceCounts do
	table.insert(pieceList, k .. "=" .. v)
end
table.sort(pieceList)
print("piezas de sala: " .. table.concat(pieceList, ", "))
print(string.format("comedores con mesa %d, sillas junto a la mesa %d", diningTables, chairsAtTable))
print(string.format(
	"choques: muebles-paredes %d, muebles-puertas %d, muebles-catálogo %d, cajas-muebles %d, catálogo-puertas %d, cajas-puertas %d, muebles-muebles %d, barrido de puertas %d, adornos sueltos %d",
	clashes.wall, clashes.door, clashes.prop, clashes.fuse, clashes.propdoor, clashes.fusedoor, clashes.furniture, clashes.sweep, clashes.openpanel))
for _, line in clashExamples do
	print("  " .. line)
end
print(string.format("%d mansiones OK | media: %d partes, %d muebles, %d lámparas, %d puntos de fusible, %d pilas",
	N, totals.parts // N, totals.props // N, totals.lamps // N, totals.fuses // N, totals.batteries // N))
local Layout = require2(server.Mansion.MansionLayout)
local Builder = require2(server.Mansion.MansionBuilder)
local Config = require2(place:GetService("ReplicatedStorage").Shared.Config)
local rng = { int = function(a, b) return math.random(a, b) end, float = math.random }
local fb = Builder.Build(Layout.Fallback(Config.Mansion, rng), rng)
print("layout seguro construido:", #fb.Model.Props:GetChildren(), "muebles,", #fb.Lamps, "lámparas")
