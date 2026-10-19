--!strict
-- Catálogo de formas de la Anomalía. Las mismas definiciones se usan para
-- amueblar la mansión (señuelos) y para el disfraz, así son idénticos.
-- Coordenadas: origen en el centro del suelo del objeto, el frente mira a -Z.
-- Placeholders grises/madera hasta tener los modelos de Blender.

export type PropPart = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: string?, -- "Block" (por defecto), "Cylinder" (vertical), "Ball"
}

export type PropDef = {
	id: string,
	name: string,
	footprint: Vector3, -- caja aproximada para colocarlo en las salas
	againstWall: boolean, -- los señuelos de este tipo se colocan pegados a la pared
	parts: { PropPart },
}

local WOOD = Color3.fromRGB(92, 64, 46)
local DARK_WOOD = Color3.fromRGB(58, 40, 30)
local BRASS = Color3.fromRGB(176, 141, 87)
local STONE = Color3.fromRGB(150, 150, 145)
local CLOTH = Color3.fromRGB(110, 34, 40)
local PORCELAIN = Color3.fromRGB(205, 210, 215)

local function part(
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: string?
): PropPart
	return {
		name = name,
		size = size,
		offset = CFrame.new(pos),
		color = color,
		material = material or Enum.Material.Wood,
		shape = shape,
	}
end

local list: { PropDef } = {
	{
		id = "Wardrobe",
		name = "Armario",
		footprint = Vector3.new(5, 9, 2.6),
		againstWall = true,
		parts = {
			part("Body", Vector3.new(5, 9, 2.4), Vector3.new(0, 4.5, 0), DARK_WOOD),
			part("DoorL", Vector3.new(2.3, 8.2, 0.2), Vector3.new(-1.22, 4.6, -1.25), WOOD),
			part("DoorR", Vector3.new(2.3, 8.2, 0.2), Vector3.new(1.22, 4.6, -1.25), WOOD),
			part("KnobL", Vector3.new(0.2, 0.5, 0.2), Vector3.new(-0.3, 4.6, -1.4), BRASS, Enum.Material.Metal),
			part("KnobR", Vector3.new(0.2, 0.5, 0.2), Vector3.new(0.3, 4.6, -1.4), BRASS, Enum.Material.Metal),
		},
	},
	{
		id = "Chair",
		name = "Silla",
		footprint = Vector3.new(2.4, 5.4, 2.4),
		againstWall = false,
		parts = {
			part("Seat", Vector3.new(2.4, 0.4, 2.4), Vector3.new(0, 2, 0), WOOD),
			part("Back", Vector3.new(2.4, 3.2, 0.3), Vector3.new(0, 3.8, 1.05), WOOD),
			part("Cushion", Vector3.new(2.1, 0.25, 2.1), Vector3.new(0, 2.32, 0), CLOTH, Enum.Material.Fabric),
			part("Leg1", Vector3.new(0.3, 1.8, 0.3), Vector3.new(-1, 0.9, -1), DARK_WOOD),
			part("Leg2", Vector3.new(0.3, 1.8, 0.3), Vector3.new(1, 0.9, -1), DARK_WOOD),
			part("Leg3", Vector3.new(0.3, 1.8, 0.3), Vector3.new(-1, 0.9, 1), DARK_WOOD),
			part("Leg4", Vector3.new(0.3, 1.8, 0.3), Vector3.new(1, 0.9, 1), DARK_WOOD),
		},
	},
	{
		id = "Table",
		name = "Mesa",
		footprint = Vector3.new(6, 3.2, 3.5),
		againstWall = false,
		parts = {
			part("Top", Vector3.new(6, 0.4, 3.5), Vector3.new(0, 3, 0), WOOD),
			part("Leg1", Vector3.new(0.4, 2.8, 0.4), Vector3.new(-2.6, 1.4, -1.4), DARK_WOOD),
			part("Leg2", Vector3.new(0.4, 2.8, 0.4), Vector3.new(2.6, 1.4, -1.4), DARK_WOOD),
			part("Leg3", Vector3.new(0.4, 2.8, 0.4), Vector3.new(-2.6, 1.4, 1.4), DARK_WOOD),
			part("Leg4", Vector3.new(0.4, 2.8, 0.4), Vector3.new(2.6, 1.4, 1.4), DARK_WOOD),
		},
	},
	{
		id = "GrandfatherClock",
		name = "Reloj de pie",
		footprint = Vector3.new(2.2, 8, 1.6),
		againstWall = true,
		parts = {
			part("Body", Vector3.new(2.2, 8, 1.6), Vector3.new(0, 4, 0), DARK_WOOD),
			part("Face", Vector3.new(1.6, 1.6, 0.1), Vector3.new(0, 6.6, -0.82), PORCELAIN, Enum.Material.SmoothPlastic),
			part("Window", Vector3.new(1.2, 3, 0.1), Vector3.new(0, 3.4, -0.82), Color3.fromRGB(30, 30, 30), Enum.Material.Glass),
			part("Pendulum", Vector3.new(0.5, 0.5, 0.1), Vector3.new(0, 2.4, -0.86), BRASS, Enum.Material.Metal),
		},
	},
	{
		id = "Dresser",
		name = "Cómoda",
		footprint = Vector3.new(4.5, 3.6, 2),
		againstWall = true,
		parts = {
			part("Body", Vector3.new(4.5, 3.5, 2), Vector3.new(0, 1.75, 0), WOOD),
			part("Drawer1", Vector3.new(4.1, 0.9, 0.1), Vector3.new(0, 0.7, -1.02), DARK_WOOD),
			part("Drawer2", Vector3.new(4.1, 0.9, 0.1), Vector3.new(0, 1.75, -1.02), DARK_WOOD),
			part("Drawer3", Vector3.new(4.1, 0.9, 0.1), Vector3.new(0, 2.8, -1.02), DARK_WOOD),
		},
	},
	{
		id = "Chest",
		name = "Baúl",
		footprint = Vector3.new(3.5, 2.4, 2),
		againstWall = false,
		parts = {
			part("Body", Vector3.new(3.5, 1.8, 2), Vector3.new(0, 0.9, 0), WOOD),
			part("Lid", Vector3.new(3.6, 0.5, 2.1), Vector3.new(0, 2.05, 0), DARK_WOOD),
			part("Lock", Vector3.new(0.4, 0.5, 0.15), Vector3.new(0, 1.7, -1.05), BRASS, Enum.Material.Metal),
		},
	},
	{
		id = "FloorLamp",
		name = "Lámpara de pie",
		footprint = Vector3.new(2, 6.5, 2),
		againstWall = false,
		parts = {
			part("Base", Vector3.new(0.3, 1.6, 1.6), Vector3.new(0, 0.15, 0), BRASS, Enum.Material.Metal, "Cylinder"),
			part("Pole", Vector3.new(5, 0.3, 0.3), Vector3.new(0, 2.8, 0), BRASS, Enum.Material.Metal, "Cylinder"),
			part("Shade", Vector3.new(1.5, 2, 2), Vector3.new(0, 5.7, 0), Color3.fromRGB(196, 170, 120), Enum.Material.Fabric, "Cylinder"),
		},
	},
	{
		id = "Bust",
		name = "Busto",
		footprint = Vector3.new(2, 5, 2),
		againstWall = true,
		parts = {
			part("Pedestal", Vector3.new(1.8, 3.2, 1.8), Vector3.new(0, 1.6, 0), STONE, Enum.Material.Marble),
			part("Chest", Vector3.new(1.4, 0.9, 0.9), Vector3.new(0, 3.65, 0), STONE, Enum.Material.Marble),
			part("Head", Vector3.new(1, 1, 1), Vector3.new(0, 4.5, 0), STONE, Enum.Material.Marble, "Ball"),
		},
	},
	{
		id = "Vase",
		name = "Jarrón",
		footprint = Vector3.new(1.6, 2.8, 1.6),
		againstWall = false,
		parts = {
			part("Body", Vector3.new(2, 1.6, 1.6), Vector3.new(0, 1, 0), PORCELAIN, Enum.Material.SmoothPlastic, "Cylinder"),
			part("Neck", Vector3.new(0.8, 0.9, 0.9), Vector3.new(0, 2.4, 0), PORCELAIN, Enum.Material.SmoothPlastic, "Cylinder"),
		},
	},
	{
		id = "Bookshelf",
		name = "Estantería",
		footprint = Vector3.new(5, 8, 1.6),
		againstWall = true,
		parts = {
			part("Frame", Vector3.new(5, 8, 1.4), Vector3.new(0, 4, 0.1), DARK_WOOD),
			part("Books1", Vector3.new(4.4, 1.4, 0.2), Vector3.new(0, 1.3, -0.65), Color3.fromRGB(90, 30, 30), Enum.Material.Fabric),
			part("Books2", Vector3.new(4.4, 1.4, 0.2), Vector3.new(0, 3.3, -0.65), Color3.fromRGB(30, 60, 40), Enum.Material.Fabric),
			part("Books3", Vector3.new(4.4, 1.4, 0.2), Vector3.new(0, 5.3, -0.65), Color3.fromRGB(40, 40, 80), Enum.Material.Fabric),
		},
	},
}

local PropCatalog = {}

PropCatalog.List = list
PropCatalog.ById = {} :: { [string]: PropDef }
for _, def in list do
	PropCatalog.ById[def.id] = def
end

function PropCatalog.Get(id: string): PropDef?
	return PropCatalog.ById[id]
end

-- Construye el modelo del objeto con el pivote en el centro del suelo.
-- Las partes salen ancladas; quien lo use decide si las suelda o las deja fijas.
function PropCatalog.Build(id: string): Model?
	local def = PropCatalog.ById[id]
	if not def then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Prop"
	local primary: BasePart? = nil
	for _, p in def.parts do
		local inst = Instance.new("Part")
		inst.Name = p.name
		inst.Anchored = true
		inst.Color = p.color
		inst.Material = p.material
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
		if p.shape == "Cylinder" then
			-- Los cilindros de Roblox van a lo largo de X: los giramos para que queden verticales.
			inst.Shape = Enum.PartType.Cylinder
			inst.Size = p.size
			inst.CFrame = p.offset * CFrame.Angles(0, 0, math.pi / 2)
		elseif p.shape == "Ball" then
			inst.Shape = Enum.PartType.Ball
			inst.Size = p.size
			inst.CFrame = p.offset
		else
			inst.Size = p.size
			inst.CFrame = p.offset
		end
		inst.Parent = model
		if not primary then
			primary = inst
		end
	end
	model.PrimaryPart = primary
	model.WorldPivot = CFrame.new()
	model:SetAttribute("PropId", id)
	return model
end

return PropCatalog
