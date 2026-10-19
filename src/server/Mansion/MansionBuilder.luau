--!strict
-- Convierte un Layout lógico en piezas de Roblox (placeholders grises).
-- Cada celda es un módulo con 4 conectores (N/S/E/O): pared, puerta o abierta (misma sala).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PropCatalog = require(Shared:WaitForChild("PropCatalog"))
local MansionLayout = require(script.Parent:WaitForChild("MansionLayout"))

type Layout = MansionLayout.Layout
type Cell = MansionLayout.Cell
type Rng = MansionLayout.Rng

export type Mansion = {
	Model: Model,
	Layout: Layout,
	InvestigatorSpawns: { CFrame },
	AnomalySpawn: CFrame,
	FuseSpawns: { Vector3 },
	BatterySpawns: { Vector3 },
	FuseBox: CFrame,
	Exit: CFrame,
	Lamps: { BasePart },
}

local M = Config.Mansion
local CS = M.CellSize
local T = M.WallThickness
local H = M.WallHeight

local ROOM_STYLE: { [string]: { floor: Enum.Material, color: Color3 } } = {
	["Vestíbulo"] = { floor = Enum.Material.Marble, color = Color3.fromRGB(120, 115, 110) },
	["Biblioteca"] = { floor = Enum.Material.WoodPlanks, color = Color3.fromRGB(70, 50, 38) },
	["Comedor"] = { floor = Enum.Material.WoodPlanks, color = Color3.fromRGB(85, 60, 45) },
	["Salón"] = { floor = Enum.Material.Carpet, color = Color3.fromRGB(80, 30, 34) },
	["Dormitorio"] = { floor = Enum.Material.Carpet, color = Color3.fromRGB(50, 45, 70) },
	["Cocina"] = { floor = Enum.Material.CeramicTiles, color = Color3.fromRGB(140, 140, 130) },
	["Estudio"] = { floor = Enum.Material.WoodPlanks, color = Color3.fromRGB(60, 45, 35) },
	["Galería"] = { floor = Enum.Material.Marble, color = Color3.fromRGB(100, 100, 100) },
	["Capilla"] = { floor = Enum.Material.Slate, color = Color3.fromRGB(70, 70, 75) },
	["Invernadero"] = { floor = Enum.Material.CeramicTiles, color = Color3.fromRGB(70, 90, 70) },
	["Sala de música"] = { floor = Enum.Material.WoodPlanks, color = Color3.fromRGB(75, 55, 40) },
}

local WALL_COLOR = Color3.fromRGB(96, 92, 88)
local CEILING_COLOR = Color3.fromRGB(40, 38, 36)

local DIRS: { Cell } = {
	{ x = 1, y = 0 },
	{ x = -1, y = 0 },
	{ x = 0, y = 1 },
	{ x = 0, y = -1 },
}

local WALL_PROPS: { string } = {}
local FREE_PROPS: { string } = {}
for _, def in PropCatalog.List do
	table.insert(if def.againstWall then WALL_PROPS else FREE_PROPS, def.id)
end

local MansionBuilder = {}

local function cellCenter(cell: Cell): Vector3
	return M.Origin + Vector3.new(cell.x * CS, 0, cell.y * CS)
end

local function dirVector(d: Cell): Vector3
	return Vector3.new(d.x, 0, d.y)
end

local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Pared de una arista de celda; con hueco de puerta si `door` es true.
local function buildWall(parent: Instance, cell: Cell, d: Cell, door: boolean)
	local center = cellCenter(cell) + dirVector(d) * (CS / 2)
	local alongX = d.y ~= 0 -- la pared se extiende a lo largo de X si la arista es N/S
	local along = if alongX then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	local function sized(length: number, height: number): Vector3
		return if alongX then Vector3.new(length, height, T) else Vector3.new(T, height, length)
	end
	if not door then
		newPart(parent, "Wall", sized(CS + T, H), CFrame.new(center + Vector3.new(0, H / 2, 0)), WALL_COLOR, Enum.Material.Plaster)
		return
	end
	local segment = (CS + T - M.DoorWidth) / 2
	local offset = M.DoorWidth / 2 + segment / 2
	for _, sign in { -1, 1 } do
		newPart(
			parent,
			"Wall",
			sized(segment, H),
			CFrame.new(center + along * (offset * sign) + Vector3.new(0, H / 2, 0)),
			WALL_COLOR,
			Enum.Material.Plaster
		)
	end
	local lintelH = H - M.DoorHeight
	newPart(
		parent,
		"Lintel",
		sized(M.DoorWidth, lintelH),
		CFrame.new(center + Vector3.new(0, M.DoorHeight + lintelH / 2, 0)),
		WALL_COLOR,
		Enum.Material.Plaster
	)
	-- Marco de la puerta para que los conectores se lean bien.
	for _, sign in { -1, 1 } do
		newPart(
			parent,
			"DoorFrame",
			sized(0.4, M.DoorHeight),
			CFrame.new(center + along * ((M.DoorWidth / 2 + 0.2) * sign) + Vector3.new(0, M.DoorHeight / 2, 0)),
			Color3.fromRGB(50, 35, 25),
			Enum.Material.Wood
		)
	end
end

local function edgeKey(a: Cell, b: Cell): string
	if a.x > b.x or (a.x == b.x and a.y > b.y) then
		a, b = b, a
	end
	return a.x .. "," .. a.y .. ">" .. b.x .. "," .. b.y
end

type Circle = { pos: Vector3, r: number }

local function overlaps(circles: { Circle }, pos: Vector3, r: number): boolean
	for _, c in circles do
		local dx, dz = c.pos.X - pos.X, c.pos.Z - pos.Z
		if math.sqrt(dx * dx + dz * dz) < c.r + r then
			return true
		end
	end
	return false
end

local function placeProp(parent: Instance, id: string, cf: CFrame)
	local model = PropCatalog.Build(id)
	if model then
		model:PivotTo(cf)
		model.Parent = parent
	end
end

function MansionBuilder.Build(layout: Layout, rng: Rng): Mansion
	local w = layout.width
	local model = Instance.new("Model")
	model.Name = "Mansion"
	local structure = Instance.new("Folder")
	structure.Name = "Structure"
	structure.Parent = model
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = model
	local lampsFolder = Instance.new("Folder")
	lampsFolder.Name = "Lamps"
	lampsFolder.Parent = model

	local doorEdges: { [string]: boolean } = {}
	for _, door in layout.doors do
		doorEdges[edgeKey(door.cellA, door.cellB)] = true
	end
	local exitOutside: Cell = { x = layout.exitCell.x + layout.exitDir.x, y = layout.exitCell.y + layout.exitDir.y }
	doorEdges[edgeKey(layout.exitCell, exitOutside)] = true

	local function roomAt(x: number, y: number): number?
		if x < 0 or y < 0 or x >= layout.width or y >= layout.height then
			return nil
		end
		return layout.cellRoom[MansionLayout.Index(w, x, y)]
	end

	local roomById: { [number]: MansionLayout.Room } = {}
	for _, room in layout.rooms do
		roomById[room.id] = room
	end

	-- Puntos ocupados por celda para que los muebles no tapen objetivos.
	local reserved: { [number]: { Circle } } = {}
	local function reserve(cell: Cell, pos: Vector3, r: number)
		local key = MansionLayout.Index(w, cell.x, cell.y)
		reserved[key] = reserved[key] or {}
		table.insert(reserved[key], { pos = pos, r = r })
	end

	-- Suelo, techo y paredes de cada celda.
	for _, room in layout.rooms do
		local style = ROOM_STYLE[room.kind] or ROOM_STYLE["Estudio"]
		for _, cell in room.cells do
			local c = cellCenter(cell)
			newPart(structure, "Floor", Vector3.new(CS + T, 1, CS + T), CFrame.new(c - Vector3.new(0, 0.5, 0)), style.color, style.floor)
			newPart(structure, "Ceiling", Vector3.new(CS + T, 1, CS + T), CFrame.new(c + Vector3.new(0, H + 0.5, 0)), CEILING_COLOR, Enum.Material.Wood)
			for _, d in DIRS do
				local nx, ny = cell.x + d.x, cell.y + d.y
				local neighbor = roomAt(nx, ny)
				local isDoor = doorEdges[edgeKey(cell, { x = nx, y = ny })] == true
				if neighbor == room.id then
					continue -- misma sala: conector abierto
				elseif neighbor ~= nil then
					if d.x == 1 or d.y == 1 then -- pared compartida: se construye una sola vez
						buildWall(structure, cell, d, isDoor)
					end
				else
					buildWall(structure, cell, d, isDoor)
				end
			end
		end
	end

	-- Lámparas: una por celda; algunas parpadean (el cliente hace el parpadeo).
	local lamps: { BasePart } = {}
	for _, room in layout.rooms do
		for _, cell in room.cells do
			local lamp = newPart(
				lampsFolder,
				"Lamp",
				Vector3.new(1.6, 0.6, 1.6),
				CFrame.new(cellCenter(cell) + Vector3.new(0, H - 0.4, 0)),
				Color3.fromRGB(255, 200, 140),
				Enum.Material.Neon
			)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 190, 130)
			light.Range = 20
			light.Brightness = 0.35
			light.Shadows = true
			light.Parent = lamp
			lamp:SetAttribute("Flicker", rng.float() < 0.35)
			CollectionService:AddTag(lamp, "MansionLamp")
			table.insert(lamps, lamp)
		end
	end

	-- Salida en el vestíbulo, mirando hacia fuera, con un porche.
	local exitWallCenter = cellCenter(layout.exitCell) + dirVector(layout.exitDir) * (CS / 2)
	local outward = dirVector(layout.exitDir)
	local exitCf = CFrame.lookAt(exitWallCenter + Vector3.new(0, M.DoorHeight / 2, 0), exitWallCenter + Vector3.new(0, M.DoorHeight / 2, 0) + outward)
	newPart(
		structure,
		"Porch",
		Vector3.new(14, 1, 10),
		CFrame.lookAt(exitWallCenter + outward * 5 - Vector3.new(0, 0.5, 0), exitWallCenter + outward * 6 - Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(60, 60, 60),
		Enum.Material.Cobblestone
	)
	reserve(layout.exitCell, exitWallCenter - outward * 3, 6)

	-- Spawns de Investigadores en el vestíbulo, mirando hacia dentro.
	local foyerCenter = cellCenter(layout.exitCell)
	local investigatorSpawns: { CFrame } = {}
	for i = 1, Config.Round.MaxInvestigators do
		local angle = (i / Config.Round.MaxInvestigators) * math.pi * 2
		local pos = foyerCenter + Vector3.new(math.cos(angle) * 5, 3, math.sin(angle) * 5)
		table.insert(investigatorSpawns, CFrame.lookAt(pos, pos - outward))
	end
	reserve(layout.exitCell, foyerCenter, 8)

	local anomalyCell = roomById[layout.anomalyRoom].cells[1]
	local anomalyPos = cellCenter(anomalyCell) + Vector3.new(0, 3, 0)
	local anomalySpawn = CFrame.new(anomalyPos)
	reserve(anomalyCell, cellCenter(anomalyCell), 3)

	-- Caja de fusibles contra una pared sólida de su sala.
	local fuseRoom = roomById[layout.fuseBoxRoom]
	local fuseBoxCf: CFrame? = nil
	for _, cell in fuseRoom.cells do
		for _, d in DIRS do
			local nx, ny = cell.x + d.x, cell.y + d.y
			if roomAt(nx, ny) ~= fuseRoom.id and not doorEdges[edgeKey(cell, { x = nx, y = ny })] then
				local pos = cellCenter(cell) + dirVector(d) * (CS / 2 - T / 2 - 0.6) + Vector3.new(0, 4, 0)
				fuseBoxCf = CFrame.lookAt(pos, pos - dirVector(d))
				reserve(cell, pos, 4)
				break
			end
		end
		if fuseBoxCf then
			break
		end
	end
	if not fuseBoxCf then
		-- Sin paredes sólidas (raro): en el centro de la sala.
		local pos = cellCenter(fuseRoom.cells[1]) + Vector3.new(0, 4, 0)
		fuseBoxCf = CFrame.new(pos)
		reserve(fuseRoom.cells[1], pos, 4)
	end

	-- Puntos para fusibles: centro de cada sala que no sea el vestíbulo.
	local fuseSpawns: { Vector3 } = {}
	for _, room in layout.rooms do
		if room.id ~= layout.foyer then
			local cell = room.cells[rng.int(1, #room.cells)]
			local pos = cellCenter(cell) + Vector3.new(rng.int(-3, 3), 0.5, rng.int(-3, 3))
			table.insert(fuseSpawns, pos)
			reserve(cell, pos, 3)
		end
	end

	-- Muebles: señuelos idénticos a las formas de la Anomalía.
	local batterySpawns: { Vector3 } = {}
	local inner = CS / 2 - T / 2
	for _, room in layout.rooms do
		for _, cell in room.cells do
			local key = MansionLayout.Index(w, cell.x, cell.y)
			local circles = reserved[key] or {}
			reserved[key] = circles
			local c = cellCenter(cell)

			-- Huecos contra la pared en aristas cerradas (con o sin puerta).
			local wallSpots: { { pos: Vector3, d: Cell } } = {}
			for _, d in DIRS do
				if roomAt(cell.x + d.x, cell.y + d.y) ~= room.id then
					local alongV = if d.y ~= 0 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
					for _, s in { -0.3, 0.3 } do
						table.insert(wallSpots, { pos = c + alongV * (CS * s), d = d })
					end
				end
			end
			for i = #wallSpots, 2, -1 do
				local j = rng.int(1, i)
				wallSpots[i], wallSpots[j] = wallSpots[j], wallSpots[i]
			end

			local wanted = rng.int(M.PropsPerCell[1], M.PropsPerCell[2])
			local placed = 0
			for _, spot in wallSpots do
				if placed >= wanted then
					break
				end
				local id = WALL_PROPS[rng.int(1, #WALL_PROPS)]
				local def = PropCatalog.Get(id)
				if def then
					local dv = dirVector(spot.d)
					local pos = spot.pos + dv * (inner - def.footprint.Z / 2 - 0.15)
					local r = math.max(def.footprint.X, def.footprint.Z) / 2
					if not overlaps(circles, pos, r) then
						placeProp(props, id, CFrame.lookAt(pos, pos - dv))
						table.insert(circles, { pos = pos, r = r })
						placed += 1
					end
				end
			end

			-- Muebles sueltos, girados en múltiplos de 90 grados.
			for _ = 1, rng.int(1, 2) do
				local id = FREE_PROPS[rng.int(1, #FREE_PROPS)]
				local def = PropCatalog.Get(id)
				if def then
					local limit = math.floor(inner - 6)
					local pos = c + Vector3.new(rng.int(-limit, limit), 0, rng.int(-limit, limit))
					local r = math.max(def.footprint.X, def.footprint.Z) / 2
					if not overlaps(circles, pos, r + 0.5) then
						placeProp(props, id, CFrame.new(pos) * CFrame.Angles(0, rng.int(0, 3) * math.pi / 2, 0))
						table.insert(circles, { pos = pos, r = r })
					end
				end
			end

			-- Posible pila en esta celda.
			local limit = math.floor(inner - 4)
			local bpos = c + Vector3.new(rng.int(-limit, limit), 0.5, rng.int(-limit, limit))
			if not overlaps(circles, bpos, 1.5) then
				table.insert(batterySpawns, bpos)
			end
		end
	end

	model:SetAttribute("Fallback", layout.fallback)
	return {
		Model = model,
		Layout = layout,
		InvestigatorSpawns = investigatorSpawns,
		AnomalySpawn = anomalySpawn,
		FuseSpawns = fuseSpawns,
		BatterySpawns = batterySpawns,
		FuseBox = fuseBoxCf :: CFrame,
		Exit = exitCf,
		Lamps = lamps,
	}
end

return MansionBuilder
