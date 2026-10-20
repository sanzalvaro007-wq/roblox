--!strict
-- Muebles propios de cada tipo de sala (baño, dormitorio, salón, garaje, cocina, comedor).
-- No son formas de la Anomalía: son decorado fijo para que cada sala se lea como lo que es.
-- Las sillas del comedor sí son del catálogo, así que la Anomalía puede esconderse entre ellas.
--
-- Cada tema devuelve un plan de piezas con los círculos que ocupan en el suelo; el
-- constructor coloca solo las que no chocan con nada reservado (spawns, objetivos, puertas).
-- Marcos: `wall` tiene el origen en la cara interior de una pared lisa, a ras de suelo, con
-- LookVector hacia dentro de la sala (local -Z = hacia dentro, local X = a lo largo de la
-- pared). `center` es el centro de la celda a ras de suelo, girado en múltiplos de 90°.

local RoomThemes = {}

export type Circle = { pos: Vector3, r: number }
export type Item = {
	circles: { Circle },
	build: ((parent: Instance) -> ())?,
	prop: string?, -- id de PropCatalog a colocar con propCf (lo hace el constructor)
	propCf: CFrame?,
}
export type Context = {
	wall: CFrame?,
	exterior: CFrame?, -- pared que da al exterior (portón del garaje)
	center: CFrame,
}

local WOOD = Color3.fromRGB(92, 64, 46)
local DARK_WOOD = Color3.fromRGB(58, 40, 30)
local BRASS = Color3.fromRGB(150, 118, 70)
local PORCELAIN = Color3.fromRGB(215, 215, 210)
local IRON = Color3.fromRGB(40, 40, 42)
local STONE = Color3.fromRGB(110, 105, 100)
local RED_CLOTH = Color3.fromRGB(95, 25, 30)

local function solid(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Cilindro vertical (los de Roblox van a lo largo de X).
local function vcyl(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material): Part
	return solid(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function at(frame: CFrame, x: number, z: number): Vector3
	return (frame * CFrame.new(x, 0, z)).Position
end

local function item(circles: { Circle }, build: (parent: Instance) -> ()): Item
	return { circles = circles, build = build }
end

-- Baño: bañera con patas, váter, lavabo con espejo y alfombrilla.
local function bathroom(ctx: Context): { Item }
	local W = ctx.wall
	if not W then
		return {}
	end
	local items: { Item } = {}
	table.insert(
		items,
		item({ { pos = at(W, 0, -2), r = 4.2 } }, function(parent)
			local m = model(parent, "Bathtub")
			solid(m, "Tub", Vector3.new(7, 2.2, 3.4), W * CFrame.new(0, 1.7, -2), PORCELAIN, Enum.Material.SmoothPlastic)
			solid(m, "Water", Vector3.new(6.2, 0.1, 2.6), W * CFrame.new(0, 2.81, -2), Color3.fromRGB(60, 70, 65), Enum.Material.Glass)
			for _, x in { -3, 3 } do
				for _, z in { -0.6, -3.4 } do
					solid(m, "Foot", Vector3.new(0.6, 0.6, 0.6), W * CFrame.new(x, 0.3, z), BRASS, Enum.Material.Metal, Enum.PartType.Ball)
				end
			end
			solid(m, "Tap", Vector3.new(0.3, 1.2, 0.5), W * CFrame.new(0, 3.2, -0.3), BRASS, Enum.Material.Metal)
		end)
	)
	table.insert(
		items,
		item({ { pos = at(W, 5.6, -1.4), r = 1.6 } }, function(parent)
			local m = model(parent, "Toilet")
			vcyl(m, "Bowl", 1.4, 1.6, W * CFrame.new(5.6, 0.7, -1.6), PORCELAIN, Enum.Material.SmoothPlastic)
			solid(m, "Seat", Vector3.new(1.7, 0.15, 1.7), W * CFrame.new(5.6, 1.45, -1.6), DARK_WOOD, Enum.Material.Wood)
			solid(m, "Tank", Vector3.new(1.8, 2, 0.8), W * CFrame.new(5.6, 2.2, -0.45), PORCELAIN, Enum.Material.SmoothPlastic)
		end)
	)
	table.insert(
		items,
		item({ { pos = at(W, -6, -1), r = 1.5 } }, function(parent)
			local m = model(parent, "Sink")
			vcyl(m, "Pedestal", 2.6, 0.7, W * CFrame.new(-6, 1.3, -1), PORCELAIN, Enum.Material.SmoothPlastic)
			solid(m, "Basin", Vector3.new(2.2, 0.6, 1.6), W * CFrame.new(-6, 2.9, -1), PORCELAIN, Enum.Material.SmoothPlastic)
			local mirror = solid(m, "Mirror", Vector3.new(2, 2.6, 0.1), W * CFrame.new(-6, 5.3, -0.06), Color3.fromRGB(150, 160, 165), Enum.Material.Glass)
			mirror.CanCollide = false
			solid(m, "MirrorFrame", Vector3.new(2.3, 2.9, 0.08), W * CFrame.new(-6, 5.3, -0.02), BRASS, Enum.Material.Metal).CanCollide = false
		end)
	)
	table.insert(
		items,
		item({}, function(parent)
			local mat = solid(parent, "BathMat", Vector3.new(3, 0.06, 1.8), W * CFrame.new(0, 0.03, -4.8), Color3.fromRGB(190, 185, 170), Enum.Material.Fabric)
			mat.CanCollide = false
		end)
	)
	return items
end

-- Dormitorio: cama de matrimonio con dosel bajo, mesillas y alfombra.
local function bedroom(ctx: Context): { Item }
	local W = ctx.wall
	if not W then
		return {}
	end
	local items: { Item } = {}
	table.insert(
		items,
		item({ { pos = at(W, 0, -2.5), r = 3.9 }, { pos = at(W, 0, -6.6), r = 3.9 } }, function(parent)
			local m = model(parent, "Bed")
			solid(m, "Frame", Vector3.new(6.2, 1.2, 8.4), W * CFrame.new(0, 0.9, -4.4), DARK_WOOD, Enum.Material.Wood)
			solid(m, "Mattress", Vector3.new(5.8, 0.8, 7.8), W * CFrame.new(0, 1.9, -4.6), Color3.fromRGB(200, 195, 185), Enum.Material.Fabric)
			solid(m, "Blanket", Vector3.new(6, 0.3, 5), W * CFrame.new(0, 2.35, -5.9), RED_CLOTH, Enum.Material.Fabric)
			for _, x in { -1.4, 1.4 } do
				solid(m, "Pillow", Vector3.new(2.2, 0.5, 1.2), W * CFrame.new(x, 2.5, -1.3), Color3.fromRGB(215, 210, 200), Enum.Material.Fabric)
			end
			solid(m, "Headboard", Vector3.new(6.6, 5, 0.4), W * CFrame.new(0, 2.5, -0.25), DARK_WOOD, Enum.Material.Wood)
			solid(m, "Footboard", Vector3.new(6.6, 2.6, 0.3), W * CFrame.new(0, 1.3, -8.6), DARK_WOOD, Enum.Material.Wood)
			for _, x in { -3.2, 3.2 } do
				vcyl(m, "Post", 6.4, 0.35, W * CFrame.new(x, 3.2, -0.3), DARK_WOOD, Enum.Material.Wood)
			end
		end)
	)
	for _, x in { -4.9, 4.9 } do
		table.insert(
			items,
			item({ { pos = at(W, x, -0.9), r = 1.1 } }, function(parent)
				local m = model(parent, "Nightstand")
				solid(m, "Body", Vector3.new(1.8, 2.2, 1.6), W * CFrame.new(x, 1.1, -0.9), WOOD, Enum.Material.Wood)
				solid(m, "Drawer", Vector3.new(1.5, 0.6, 0.08), W * CFrame.new(x, 1.5, -1.72), DARK_WOOD, Enum.Material.Wood)
				vcyl(m, "Candle", 0.6, 0.22, W * CFrame.new(x, 2.5, -0.9), Color3.fromRGB(225, 215, 190), Enum.Material.SmoothPlastic)
			end)
		)
	end
	table.insert(
		items,
		item({}, function(parent)
			local rug = solid(parent, "Rug", Vector3.new(9, 0.06, 4), W * CFrame.new(0, 0.03, -10.6), Color3.fromRGB(60, 40, 55), Enum.Material.Fabric)
			rug.CanCollide = false
		end)
	)
	return items
end

-- Salón: chimenea con brasas, sofá frente a ella, mesa baja, dos butacas y alfombra.
local function livingRoom(ctx: Context): { Item }
	local W = ctx.wall
	if not W then
		return {}
	end
	local items: { Item } = {}
	table.insert(
		items,
		item({ { pos = at(W, 0, -0.8), r = 4 } }, function(parent)
			local m = model(parent, "Fireplace")
			solid(m, "Surround", Vector3.new(7, 6, 1.4), W * CFrame.new(0, 3, -0.7), STONE, Enum.Material.Slate)
			local hole = solid(m, "Opening", Vector3.new(3.6, 3, 0.2), W * CFrame.new(0, 1.6, -1.42), Color3.fromRGB(12, 10, 10), Enum.Material.SmoothPlastic)
			hole.CanCollide = false
			solid(m, "Mantel", Vector3.new(8, 0.4, 1.8), W * CFrame.new(0, 6.15, -0.9), DARK_WOOD, Enum.Material.Wood)
			local embers = solid(m, "Embers", Vector3.new(2.6, 0.3, 0.6), W * CFrame.new(0, 0.2, -1.1), Color3.fromRGB(255, 90, 30), Enum.Material.Neon)
			embers.CanCollide = false
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 110, 40)
			glow.Brightness = 0.35
			glow.Range = 9
			glow.Parent = embers
			for _, x in { -2.6, 2.6 } do
				vcyl(m, "Candlestick", 0.9, 0.25, W * CFrame.new(x, 6.8, -0.9), BRASS, Enum.Material.Metal)
			end
		end)
	)
	table.insert(
		items,
		item({}, function(parent)
			local rug = solid(parent, "Rug", Vector3.new(10, 0.06, 7), W * CFrame.new(0, 0.03, -8), Color3.fromRGB(80, 20, 26), Enum.Material.Fabric)
			rug.CanCollide = false
		end)
	)
	table.insert(
		items,
		item({ { pos = at(W, 0, -7), r = 2 } }, function(parent)
			local m = model(parent, "CoffeeTable")
			solid(m, "Top", Vector3.new(3.6, 0.3, 2), W * CFrame.new(0, 1.4, -7), WOOD, Enum.Material.Wood)
			solid(m, "Base", Vector3.new(2.6, 1.25, 1.2), W * CFrame.new(0, 0.62, -7), DARK_WOOD, Enum.Material.Wood)
		end)
	)
	table.insert(
		items,
		item({ { pos = at(W, -2, -11.6), r = 2.2 }, { pos = at(W, 2, -11.6), r = 2.2 } }, function(parent)
			local m = model(parent, "Sofa")
			solid(m, "Seat", Vector3.new(7, 1.4, 2.8), W * CFrame.new(0, 0.9, -11.2), RED_CLOTH, Enum.Material.Fabric)
			solid(m, "Back", Vector3.new(7, 2.6, 0.8), W * CFrame.new(0, 2.2, -12.9), RED_CLOTH, Enum.Material.Fabric)
			for _, x in { -3.9, 3.9 } do
				solid(m, "Arm", Vector3.new(0.8, 2, 3.2), W * CFrame.new(x, 1.2, -11.6), RED_CLOTH, Enum.Material.Fabric)
			end
			solid(m, "Skirt", Vector3.new(8.6, 0.3, 3.4), W * CFrame.new(0, 0.15, -11.7), DARK_WOOD, Enum.Material.Wood)
		end)
	)
	for _, side in { -1, 1 } do
		local x, z = side * 6, -7
		-- Giradas hacia el centro y un poco hacia la chimenea.
		local frame = W * CFrame.new(x, 0, z) * CFrame.Angles(0, side * math.rad(110), 0)
		table.insert(
			items,
			item({ { pos = frame.Position, r = 1.8 } }, function(parent)
				local m = model(parent, "Armchair")
				-- La butaca mira hacia el centro del salón (su local -Z).
				solid(m, "Seat", Vector3.new(2.6, 1.3, 2.6), frame * CFrame.new(0, 0.85, 0), RED_CLOTH, Enum.Material.Fabric)
				solid(m, "Back", Vector3.new(2.6, 2.8, 0.6), frame * CFrame.new(0, 2, 1.1), RED_CLOTH, Enum.Material.Fabric)
				for _, ax in { -1.45, 1.45 } do
					solid(m, "Arm", Vector3.new(0.4, 1.9, 2.6), frame * CFrame.new(ax, 1.2, 0), RED_CLOTH, Enum.Material.Fabric)
				end
			end)
		)
	end
	return items
end

-- Garaje: coche antiguo, banco de trabajo con herramientas, bidones, estantería y portón.
local function garage(ctx: Context): { Item }
	local items: { Item } = {}
	local W = ctx.wall
	if W then
		table.insert(
			items,
			item({ { pos = at(W, -2, -1.3), r = 2.4 }, { pos = at(W, 2, -1.3), r = 2.4 } }, function(parent)
				local m = model(parent, "Workbench")
				solid(m, "Top", Vector3.new(8, 0.4, 2.6), W * CFrame.new(0, 3, -1.3), WOOD, Enum.Material.Wood)
				for _, x in { -3.7, 3.7 } do
					for _, z in { -0.3, -2.3 } do
						solid(m, "Leg", Vector3.new(0.3, 2.8, 0.3), W * CFrame.new(x, 1.4, z), IRON, Enum.Material.Metal)
					end
				end
				local board = solid(m, "Pegboard", Vector3.new(8, 3.6, 0.1), W * CFrame.new(0, 5.4, -0.06), Color3.fromRGB(120, 100, 75), Enum.Material.Wood)
				board.CanCollide = false
				for i, x in { -3, -1.8, -0.4, 1, 2.4, 3.3 } do
					local tool = solid(m, "Tool", Vector3.new(0.25, 1 + (i % 3) * 0.4, 0.1), W * CFrame.new(x, 5.4, -0.14), IRON, Enum.Material.Metal)
					tool.CanCollide = false
				end
				solid(m, "Vise", Vector3.new(0.8, 0.6, 0.8), W * CFrame.new(3, 3.5, -2.2), Color3.fromRGB(40, 70, 50), Enum.Material.Metal)
			end)
		)
		table.insert(
			items,
			item({ { pos = at(W, -7, -1.2), r = 2.2 } }, function(parent)
				local m = model(parent, "Barrels")
				for i, offset in { Vector3.new(-0.8, 0, 0), Vector3.new(0.9, 0, -0.4), Vector3.new(0, 0, -1.9) } do
					local color = if i == 2 then Color3.fromRGB(110, 40, 30) else Color3.fromRGB(60, 75, 60)
					vcyl(m, "Barrel", 3, 1.6, W * CFrame.new(-7 + offset.X, 1.5, -1 + offset.Z), color, Enum.Material.CorrodedMetal)
				end
			end)
		)
		table.insert(
			items,
			item({ { pos = at(W, 7.2, -1), r = 1.6 } }, function(parent)
				local m = model(parent, "Shelf")
				for _, x in { -1.4, 1.4 } do
					solid(m, "Upright", Vector3.new(0.2, 7, 0.2), W * CFrame.new(7.2 + x, 3.5, -1), IRON, Enum.Material.Metal)
				end
				for i, y in { 1, 3.2, 5.4 } do
					solid(m, "Board", Vector3.new(3, 0.2, 1.6), W * CFrame.new(7.2, y, -1), IRON, Enum.Material.Metal)
					solid(m, "Box", Vector3.new(1.2, 1, 1.1), W * CFrame.new(7.2 + (i - 2) * 0.6, y + 0.6, -1), Color3.fromRGB(150, 120, 80), Enum.Material.Cardboard)
				end
			end)
		)
	end
	local C = ctx.center
	table.insert(
		items,
		item({ { pos = at(C, 0, -3.2), r = 3.4 }, { pos = at(C, 0, 3.2), r = 3.4 } }, function(parent)
			local m = model(parent, "Car")
			local body = Color3.fromRGB(25, 45, 35)
			solid(m, "Chassis", Vector3.new(5.2, 1.6, 11), C * CFrame.new(0, 1.6, 0), body, Enum.Material.Metal)
			solid(m, "Cabin", Vector3.new(4.6, 2, 5), C * CFrame.new(0, 3.4, 0.8), body, Enum.Material.Metal)
			local glass = solid(m, "Windows", Vector3.new(4.7, 1.4, 4.4), C * CFrame.new(0, 3.5, 0.8), Color3.fromRGB(30, 35, 40), Enum.Material.Glass)
			glass.CanCollide = false
			solid(m, "Hood", Vector3.new(4.8, 0.4, 3.8), C * CFrame.new(0, 2.5, -3.6), body, Enum.Material.Metal)
			for _, x in { -2.7, 2.7 } do
				for _, z in { -3.6, 3.6 } do
					solid(m, "Wheel", Vector3.new(0.8, 2.3, 2.3), C * CFrame.new(x, 1.15, z), Color3.fromRGB(15, 15, 15), Enum.Material.Rubber, Enum.PartType.Cylinder)
				end
				local lamp = solid(m, "Headlight", Vector3.new(0.3, 0.8, 0.8), C * CFrame.new(x * 0.7, 2, -5.55) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(190, 185, 160), Enum.Material.Glass, Enum.PartType.Cylinder)
				lamp.CanCollide = false
			end
			local stain = solid(m, "OilStain", Vector3.new(4, 0.04, 3), C * CFrame.new(0.6, 0.02, -2.5), Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)
			stain.CanCollide = false
			stain.Transparency = 0.3
		end)
	)
	local E = ctx.exterior
	if E then
		table.insert(
			items,
			item({}, function(parent)
				local m = model(parent, "GarageDoor")
				solid(m, "Shutter", Vector3.new(12, 9, 0.3), E * CFrame.new(0, 4.5, -0.15), Color3.fromRGB(75, 78, 75), Enum.Material.CorrodedMetal)
				for i = 1, 8 do
					local slat = solid(m, "Slat", Vector3.new(12, 0.12, 0.08), E * CFrame.new(0, i * 1.05, -0.33), Color3.fromRGB(50, 52, 50), Enum.Material.Metal)
					slat.CanCollide = false
				end
				solid(m, "Handle", Vector3.new(1.6, 0.25, 0.25), E * CFrame.new(0, 1, -0.45), IRON, Enum.Material.Metal).CanCollide = false
			end)
		)
	end
	return items
end

-- Cocina: encimera con armarios, fogón de hierro con ollas y una mesa auxiliar.
local function kitchen(ctx: Context): { Item }
	local W = ctx.wall
	if not W then
		return {}
	end
	local items: { Item } = {}
	table.insert(
		items,
		item({ { pos = at(W, -4, -1.3), r = 2.4 }, { pos = at(W, 0, -1.3), r = 2.4 } }, function(parent)
			local m = model(parent, "Counter")
			solid(m, "Cabinets", Vector3.new(8, 3, 2.4), W * CFrame.new(-2, 1.5, -1.2), WOOD, Enum.Material.Wood)
			solid(m, "Top", Vector3.new(8.2, 0.3, 2.6), W * CFrame.new(-2, 3.15, -1.3), Color3.fromRGB(170, 165, 160), Enum.Material.Marble)
			for i = 0, 3 do
				solid(m, "Door", Vector3.new(1.8, 2.4, 0.08), W * CFrame.new(-5 + i * 2, 1.5, -2.42), DARK_WOOD, Enum.Material.Wood)
			end
		end)
	)
	table.insert(
		items,
		item({ { pos = at(W, 4.2, -1.3), r = 2 } }, function(parent)
			local m = model(parent, "Stove")
			solid(m, "Body", Vector3.new(3.2, 3.2, 2.4), W * CFrame.new(4.2, 1.6, -1.2), IRON, Enum.Material.CorrodedMetal)
			solid(m, "Pipe", Vector3.new(0.6, 9, 0.6), W * CFrame.new(4.2, 7.7, -0.4), IRON, Enum.Material.CorrodedMetal)
			vcyl(m, "Pot", 1, 1.2, W * CFrame.new(3.6, 3.7, -1.3), Color3.fromRGB(90, 70, 50), Enum.Material.Metal)
			vcyl(m, "Kettle", 0.9, 0.8, W * CFrame.new(5, 3.65, -1.1), Color3.fromRGB(120, 110, 100), Enum.Material.Metal)
		end)
	)
	table.insert(
		items,
		item({ { pos = at(W, 0, -8), r = 2.4 } }, function(parent)
			local m = model(parent, "KitchenTable")
			solid(m, "Top", Vector3.new(4, 0.3, 2.6), W * CFrame.new(0, 3, -8), WOOD, Enum.Material.Wood)
			for _, x in { -1.7, 1.7 } do
				for _, z in { -7, -9 } do
					solid(m, "Leg", Vector3.new(0.3, 2.85, 0.3), W * CFrame.new(x, 1.42, z), DARK_WOOD, Enum.Material.Wood)
				end
			end
		end)
	)
	return items
end

-- Comedor: mesa larga con candelabro y sillas del catálogo (pueden ser la Anomalía).
local function diningRoom(ctx: Context): { Item }
	local C = ctx.center
	local items: { Item } = {}
	table.insert(
		items,
		item({ { pos = at(C, -3, 0), r = 2.6 }, { pos = at(C, 3, 0), r = 2.6 } }, function(parent)
			local m = model(parent, "DiningTable")
			solid(m, "Top", Vector3.new(10, 0.4, 4), C * CFrame.new(0, 3.1, 0), DARK_WOOD, Enum.Material.Wood)
			for _, x in { -4.4, 0, 4.4 } do
				for _, z in { -1.6, 1.6 } do
					solid(m, "Leg", Vector3.new(0.4, 2.9, 0.4), C * CFrame.new(x, 1.45, z), DARK_WOOD, Enum.Material.Wood)
				end
			end
			local runner = solid(m, "Runner", Vector3.new(9, 0.04, 1.2), C * CFrame.new(0, 3.32, 0), RED_CLOTH, Enum.Material.Fabric)
			runner.CanCollide = false
			vcyl(m, "Candelabra", 1.6, 0.3, C * CFrame.new(0, 4.1, 0), BRASS, Enum.Material.Metal)
		end)
	)
	for _, x in { -3.6, -1.2, 1.2, 3.6 } do
		for _, side in { -1, 1 } do
			local pos = at(C, x, side * 3.1)
			-- La silla mira a la mesa: su frente (-Z) apunta hacia el centro.
			local cf = CFrame.lookAt(pos, at(C, x, 0))
			table.insert(items, { circles = { { pos = pos, r = 1.2 } }, prop = "Chair", propCf = cf })
		end
	end
	return items
end

local THEMES: { [string]: (Context) -> { Item } } = {
	["Baño"] = bathroom,
	["Dormitorio"] = bedroom,
	["Salón"] = livingRoom,
	["Garaje"] = garage,
	["Cocina"] = kitchen,
	["Comedor"] = diningRoom,
}

-- Temas que necesitan una pared lisa libre para su pieza principal.
RoomThemes.NeedsWall = {
	["Baño"] = true,
	["Dormitorio"] = true,
	["Salón"] = true,
	["Garaje"] = true,
	["Cocina"] = true,
} :: { [string]: boolean }

-- Temas cuya lámpara es una bombilla colgada en vez de una araña.
RoomThemes.BulbLamp = {
	["Baño"] = true,
	["Garaje"] = true,
	["Cocina"] = true,
} :: { [string]: boolean }

function RoomThemes.Plan(kind: string, ctx: Context): { Item }
	local theme = THEMES[kind]
	return if theme then theme(ctx) else {}
end

return RoomThemes
