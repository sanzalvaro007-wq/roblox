--!strict
-- Catálogo de formas de la Anomalía. Las mismas definiciones se usan para
-- amueblar la mansión (señuelos) y para el disfraz, así son idénticos.
-- Coordenadas: origen en el centro del suelo del objeto, el frente mira a -Z.
-- Si en ReplicatedStorage hay una carpeta "PropModels" con los modelos importados de
-- Blender (tools/blender/mimic_props.py), se usan esos; si falta alguno, ese mueble se
-- construye con bloques. Así el juego funciona igual antes y después de importarlos.

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
	-- Formas cosméticas (gacha): siempre aparecen como señuelos en la mansión para que no
	-- sean un "tell", pero solo quien las tiene puede transformarse en ellas.
	cosmetic: boolean?,
	killCam: string?, -- texto propio de la kill cam
	killColor: Color3?,
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
	{
		id = "CuckooClock",
		name = "Reloj de cuco",
		footprint = Vector3.new(2.4, 7.5, 1.4),
		againstWall = true,
		cosmetic = true,
		killCam = "El cuco ha dado tu hora",
		killColor = Color3.fromRGB(230, 170, 60),
		parts = {
			part("Post", Vector3.new(0.5, 4.5, 0.5), Vector3.new(0, 2.25, 0.2), DARK_WOOD),
			part("House", Vector3.new(2.4, 2.4, 1.4), Vector3.new(0, 5.7, 0), WOOD),
			part("Roof", Vector3.new(2.8, 0.4, 1.6), Vector3.new(0, 7.1, 0), DARK_WOOD),
			part("Dial", Vector3.new(1.2, 1.2, 0.1), Vector3.new(0, 5.6, -0.72), PORCELAIN, Enum.Material.SmoothPlastic),
			part("Door", Vector3.new(0.5, 0.5, 0.1), Vector3.new(0, 6.6, -0.72), Color3.fromRGB(30, 20, 15)),
		},
	},
	{
		id = "CursedMirror",
		name = "Espejo maldito",
		footprint = Vector3.new(3, 7, 0.8),
		againstWall = true,
		cosmetic = true,
		killCam = "Tu reflejo te ha sustituido",
		killColor = Color3.fromRGB(150, 200, 255),
		parts = {
			part("Frame", Vector3.new(3, 7, 0.5), Vector3.new(0, 3.5, 0.1), BRASS, Enum.Material.Metal),
			part("Glass", Vector3.new(2.5, 6.4, 0.1), Vector3.new(0, 3.5, -0.2), Color3.fromRGB(170, 185, 195), Enum.Material.Glass),
			part("Foot", Vector3.new(2, 0.3, 0.8), Vector3.new(0, 0.15, 0), DARK_WOOD),
		},
	},
	{
		id = "BloodyStatue",
		name = "Estatua sangrienta",
		footprint = Vector3.new(2.2, 7, 2.2),
		againstWall = false,
		cosmetic = true,
		killCam = "La estatua ha llorado sangre",
		killColor = Color3.fromRGB(200, 20, 20),
		parts = {
			part("Base", Vector3.new(2.2, 1, 2.2), Vector3.new(0, 0.5, 0), STONE, Enum.Material.Marble),
			part("Robe", Vector3.new(1.6, 4, 1.2), Vector3.new(0, 3, 0), STONE, Enum.Material.Marble),
			part("Head", Vector3.new(1, 1, 1), Vector3.new(0, 5.6, 0), STONE, Enum.Material.Marble, "Ball"),
			part("Tears", Vector3.new(0.5, 0.6, 0.05), Vector3.new(0, 5.4, -0.5), Color3.fromRGB(120, 0, 0), Enum.Material.SmoothPlastic),
		},
	},
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PropCatalog = {}

-- Acabados de las mallas de Blender: cada malla se llama "<Id>_<Acabado>".
local FINISHES: { [string]: { color: Color3, material: Enum.Material } } = {
	Wood = { color = WOOD, material = Enum.Material.Wood },
	DarkWood = { color = DARK_WOOD, material = Enum.Material.Wood },
	Brass = { color = BRASS, material = Enum.Material.Metal },
	Cloth = { color = CLOTH, material = Enum.Material.Fabric },
	Porcelain = { color = PORCELAIN, material = Enum.Material.SmoothPlastic },
	Stone = { color = STONE, material = Enum.Material.Marble },
	Glass = { color = Color3.fromRGB(30, 30, 30), material = Enum.Material.Glass },
	Mirror = { color = Color3.fromRGB(170, 185, 195), material = Enum.Material.Glass },
	Shade = { color = Color3.fromRGB(196, 170, 120), material = Enum.Material.Fabric },
	BookRed = { color = Color3.fromRGB(90, 30, 30), material = Enum.Material.Fabric },
	BookGreen = { color = Color3.fromRGB(30, 60, 40), material = Enum.Material.Fabric },
	BookBlue = { color = Color3.fromRGB(40, 40, 80), material = Enum.Material.Fabric },
	Blood = { color = Color3.fromRGB(120, 0, 0), material = Enum.Material.SmoothPlastic },
	Black = { color = Color3.fromRGB(15, 12, 12), material = Enum.Material.SmoothPlastic },
}

PropCatalog.List = list
PropCatalog.ById = {} :: { [string]: PropDef }
for _, def in list do
	PropCatalog.ById[def.id] = def
end

function PropCatalog.Get(id: string): PropDef?
	return PropCatalog.ById[id]
end

-- Modelo importado normalizado (escala y pivote) por id; false = no hay modelo importado.
local prototypes: { [string]: Model | false } = {}

local function importedParts(id: string): { BasePart }
	local folder = ReplicatedStorage:FindFirstChild("PropModels")
	if not folder then
		return {}
	end
	-- El importador puede dejar el mueble como un Model con su id o aplanar las mallas
	-- ("Wardrobe_Wood"...): aceptamos las dos cosas.
	local found = folder:FindFirstChild(id, true)
	local candidates = if found then { found :: Instance, table.unpack(found:GetDescendants()) } else folder:GetDescendants()
	local parts: { BasePart } = {}
	for _, d in candidates do
		if d:IsA("BasePart") and (found ~= nil or string.sub(d.Name, 1, #id + 1) == id .. "_") then
			table.insert(parts, d)
		end
	end
	return parts
end

-- Las 24 rotaciones que dejan los ejes alineados (permutaciones con signo, determinante +1).
local AXIS_ROTATIONS: { CFrame } = {}
do
	local axes = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }
	for _, right in axes do
		for _, up in axes do
			if math.abs(right:Dot(up)) < 0.5 then
				-- fromMatrix calcula el tercer eje como right × up, así que siempre es una rotación.
				table.insert(AXIS_ROTATIONS, CFrame.fromMatrix(Vector3.zero, right, up))
			end
		end
	end
end

local function absVector(v: Vector3): Vector3
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

export type ImportSample = {
	size: Vector3, -- caja del modelo importado en ejes del mundo
	footprint: Vector3, -- caja esperada (PropDef.footprint)
	up: Vector3?, -- vector que debería apuntar hacia arriba (+Y)
	front: Vector3?, -- vector que debería apuntar hacia delante (-Z)
}

-- Elige la rotación que deja los modelos importados de pie y mirando al frente. Según la
-- versión de Studio, un glTF puede entrar con Z hacia arriba o girado; en vez de suponer
-- nada, comparamos las proporciones con las del catálogo y usamos piezas de referencia
-- (la pantalla de la lámpara va arriba, las puertas del armario delante) para el signo.
function PropCatalog.ChooseImportRotation(samples: { ImportSample }): CFrame
	local best, bestScore = CFrame.identity, math.huge
	for _, rotation in AXIS_ROTATIONS do
		local score = 0
		for _, sample in samples do
			local size = absVector(rotation:VectorToWorldSpace(sample.size))
			local d = {
				math.log(math.max(size.X, 1e-3) / sample.footprint.X),
				math.log(math.max(size.Y, 1e-3) / sample.footprint.Y),
				math.log(math.max(size.Z, 1e-3) / sample.footprint.Z),
			}
			local mean = (d[1] + d[2] + d[3]) / 3
			for _, v in d do
				score += (v - mean) ^ 2
			end
			if sample.up and rotation:VectorToWorldSpace(sample.up).Y <= 0 then
				score += 10
			end
			if sample.front and rotation:VectorToWorldSpace(sample.front).Z >= 0 then
				score += 10
			end
		end
		-- A igualdad, preferimos no girar.
		if score < bestScore - 1e-6 then
			best, bestScore = rotation, score
		end
	end
	return best
end

local function finishCenter(parts: { BasePart }, finish: string): Vector3?
	local sum, count = Vector3.zero, 0
	for _, p in parts do
		if string.match(p.Name, "_(%w+)$") == finish then
			sum += p.Position
			count += 1
		end
	end
	return if count > 0 then sum / count else nil
end

local function boundsOf(parts: { BasePart }): (Vector3, Vector3)
	local lo = Vector3.one * math.huge
	local hi = -lo
	for _, p in parts do
		local half = absVector(p.CFrame:VectorToWorldSpace(Vector3.new(p.Size.X, 0, 0)))
			+ absVector(p.CFrame:VectorToWorldSpace(Vector3.new(0, p.Size.Y, 0)))
			+ absVector(p.CFrame:VectorToWorldSpace(Vector3.new(0, 0, p.Size.Z)))
		lo = lo:Min(p.Position - half / 2)
		hi = hi:Max(p.Position + half / 2)
	end
	return (lo + hi) / 2, hi - lo
end

local importRotation: CFrame? = nil
local function getImportRotation(): CFrame
	if importRotation then
		return importRotation
	end
	local samples: { ImportSample } = {}
	for _, def in list do
		local parts = importedParts(def.id)
		if #parts > 0 then
			local _, size = boundsOf(parts)
			local sample: ImportSample = { size = size, footprint = def.footprint }
			if def.id == "FloorLamp" then
				local shade, base = finishCenter(parts, "Shade"), finishCenter(parts, "Brass")
				if shade and base then
					sample.up = shade - base
				end
			elseif def.id == "Wardrobe" then
				local doors, body = finishCenter(parts, "Wood"), finishCenter(parts, "DarkWood")
				if doors and body then
					sample.front = doors - body
				end
			end
			table.insert(samples, sample)
		end
	end
	local rotation = PropCatalog.ChooseImportRotation(samples)
	importRotation = rotation
	return rotation
end

local function prototype(def: PropDef): Model?
	local cached = prototypes[def.id]
	if cached ~= nil then
		return if cached then cached :: Model else nil
	end
	local sources = importedParts(def.id)
	if #sources == 0 then
		prototypes[def.id] = false
		return nil
	end
	local rotation = getImportRotation()
	local model = Instance.new("Model")
	model.Name = "Prop"
	local biggest: BasePart? = nil
	for _, source in sources do
		local p = source:Clone()
		for _, child in p:GetChildren() do
			if not child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = true
		p.CastShadow = true
		local finish = FINISHES[string.match(p.Name, "_(%w+)$") or p.Name]
		if finish then
			p.Color = finish.color
			p.Material = finish.material
		end
		p.CFrame = rotation * p.CFrame
		p.Parent = model
		if not biggest or p.Size.Magnitude > (biggest :: BasePart).Size.Magnitude then
			biggest = p
		end
	end
	-- Caja en ejes del mundo (no en los de la primera malla, que puede venir girada).
	local parts: { BasePart } = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local center, size = boundsOf(parts)
	model.PrimaryPart = biggest
	model.WorldPivot = CFrame.new(center - Vector3.new(0, size.Y / 2, 0))
	-- Misma altura que el placeholder, sea cual sea la escala con la que se importó.
	if size.Y > 0 then
		model:ScaleTo(def.footprint.Y / size.Y)
	end
	model:PivotTo(CFrame.new())
	prototypes[def.id] = model
	return model
end

-- Construye el modelo del objeto con el pivote en el centro del suelo.
-- Las partes salen ancladas; quien lo use decide si las suelda o las deja fijas.
function PropCatalog.Build(id: string): Model?
	local def = PropCatalog.ById[id]
	if not def then
		return nil
	end
	local imported = prototype(def)
	if imported then
		local copy = imported:Clone()
		copy:SetAttribute("PropId", id)
		return copy
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
