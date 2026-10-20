--!strict
-- Puertas de madera entre salas que se abren y cierran con un clic.
-- La hoja gira sobre una bisagra en su borde izquierdo (local -X) y se abre hacia el lado
-- contrario de quien la empuja (salvo que ahí haya alguien). El servidor guarda en atributos el estado y el
-- CFrame cerrado; DoorService las mueve y el cliente solo pide abrir o cerrar.

local CollectionService = game:GetService("CollectionService")

local Doors = {}

Doors.Tag = "MansionDoor"
Doors.CollisionGroup = "Door"
Doors.OpenAngle = math.rad(100)

local DOOR_WOOD = Color3.fromRGB(70, 46, 32)
local DOOR_PANEL = Color3.fromRGB(52, 34, 24)
local BRASS = Color3.fromRGB(176, 141, 87)

-- CFrame de la hoja girada `angle` radianes sobre la bisagra (0 = cerrada). Los ángulos
-- positivos la abren hacia el lado local -Z y los negativos hacia +Z.
function Doors.HingeCFrame(closed: CFrame, width: number, angle: number): CFrame
	local hinge = closed * CFrame.new(-width / 2, 0, 0)
	return hinge * CFrame.Angles(0, angle, 0) * CFrame.new(width / 2, 0, 0)
end

-- Ángulo de la hoja abierta del todo hacia un lado (sign > 0: hacia local -Z).
function Doors.OpenAngleFor(sign: number): number
	return if sign >= 0 then Doors.OpenAngle else -Doors.OpenAngle
end

-- Distancia de un punto a la hoja tal como está ahora (no al hueco cerrado).
function Doors.DistanceTo(panel: BasePart, point: Vector3): number
	local half = panel.Size / 2
	local p = panel.CFrame:PointToObjectSpace(point)
	local clamped = Vector3.new(math.clamp(p.X, -half.X, half.X), math.clamp(p.Y, -half.Y, half.Y), math.clamp(p.Z, -half.Z, half.Z))
	return (p - clamped).Magnitude
end

local function attach(panel: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = panel.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = panel
	weld.Part1 = p
	weld.Parent = p
	p.Parent = panel
end

-- Crea la puerta en `closed` (centro de la hoja cerrada; local X a lo largo del hueco),
-- girada ya `angle` radianes si empieza abierta. Se coloca antes de soldar los adornos:
-- fuera de Workspace mover la hoja no arrastra las piezas soldadas.
-- Devuelve la hoja, que lleva la etiqueta y los atributos.
function Doors.Build(parent: Instance, closed: CFrame, width: number, height: number, angle: number?): Part
	local startAngle = angle or 0
	local panel = Instance.new("Part")
	panel.Name = "Door"
	panel.Anchored = true
	panel.Size = Vector3.new(width, height, 0.35)
	panel.CFrame = Doors.HingeCFrame(closed, width, startAngle)
	panel.Color = DOOR_WOOD
	panel.Material = Enum.Material.Wood
	panel.TopSurface = Enum.SurfaceType.Smooth
	panel.BottomSurface = Enum.SurfaceType.Smooth
	panel.CollisionGroup = Doors.CollisionGroup
	panel:SetAttribute("ClosedCFrame", closed)
	panel:SetAttribute("Width", width)
	panel:SetAttribute("Angle", startAngle)
	panel:SetAttribute("Open", startAngle ~= 0)
	CollectionService:AddTag(panel, Doors.Tag)
	panel.Parent = parent
	-- Cuarterones y pomos por las dos caras (soldados: se mueven con la hoja).
	for _, z in { -0.2, 0.2 } do
		for _, y in { height * 0.22, -height * 0.18 } do
			attach(panel, "Inset", Vector3.new(width - 1.6, height * 0.32, 0.06), CFrame.new(0, y, z), DOOR_PANEL, Enum.Material.Wood)
		end
		attach(panel, "Knob", Vector3.new(0.35, 0.35, 0.35), CFrame.new(width / 2 - 0.6, -0.4, z * 1.6), BRASS, Enum.Material.Metal, Enum.PartType.Ball)
	end
	return panel
end

return Doors
