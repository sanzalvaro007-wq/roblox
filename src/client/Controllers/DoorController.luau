--!strict
-- Puertas: clic (o gatillo del mando, o tocar en móvil) sobre una puerta cercana para
-- abrirla o cerrarla. Lo comprueba y la mueve el servidor (DoorService); aquí solo se
-- mira a qué puerta apuntas y se enseña el aviso junto a la cruz.
-- Investigator/AnomalyController llaman a TryClick antes de usar el clic para su acción, y
-- con Defer pueden quedarse el clic cuando su acción alcanzaría a alguien (foto o ataque).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

local DOOR_TAG = "MansionDoor"
local REACH = 9 -- desde la cámara y desde el cuerpo; el servidor deja 11 desde el cuerpo

local DoorController = {}

local hint: TextLabel? = nil
local deferrals: { () -> boolean } = {}

-- `actionFirst` devuelve true cuando el clic debe ser para la acción del rol y no para la puerta.
function DoorController.Defer(actionFirst: () -> boolean)
	table.insert(deferrals, actionFirst)
end

-- Distancia de un punto a la hoja tal como está (igual que Doors.DistanceTo en el servidor).
local function distanceTo(panel: BasePart, point: Vector3): number
	local half = panel.Size / 2
	local p = panel.CFrame:PointToObjectSpace(point)
	local clamped = Vector3.new(math.clamp(p.X, -half.X, half.X), math.clamp(p.Y, -half.Y, half.Y), math.clamp(p.Z, -half.Z, half.Z))
	return (p - clamped).Magnitude
end

local function canUse(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	local role = player:GetAttribute("Role")
	return (state == Enums.RoundState.Playing or state == Enums.RoundState.Preparing)
		and (role == Enums.Role.Investigator or role == Enums.Role.Anomaly)
		and player:GetAttribute("Alive") == true
		and player:GetAttribute("Escaped") ~= true
		and player:GetAttribute("Ghost") ~= true
end

local function deferred(): boolean
	for _, actionFirst in deferrals do
		if actionFirst() then
			return true
		end
	end
	return false
end

local function doorAlong(origin: Vector3, direction: Vector3): BasePart?
	-- Se ignoran el propio cuerpo y los fantasmas (invisibles, pero los rayos los tocan).
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character and (p == player or p:GetAttribute("Ghost") == true) then
			table.insert(ignore, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, direction.Unit * REACH, params)
	if not hit or not CollectionService:HasTag(hit.Instance, DOOR_TAG) then
		return nil
	end
	local door = hit.Instance :: BasePart
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	-- Mientras gira no se puede tocar, y el cuerpo tiene que estar cerca de la hoja.
	if door:GetAttribute("Swinging") == true or not root or not root:IsA("BasePart") or distanceTo(door, root.Position) > REACH then
		return nil
	end
	return if deferred() then nil else door
end

-- Puerta que hay justo en el centro de la pantalla (donde está la cruz).
local function aimedDoor(): BasePart?
	if not canUse() then
		return nil
	end
	local camera = workspace.CurrentCamera
	return doorAlong(camera.CFrame.Position, camera.CFrame.LookVector)
end

function DoorController.TryClick(): boolean
	local door = aimedDoor()
	if door then
		Remotes.Event("ToggleDoor"):FireServer(door)
		return true
	end
	return false
end

-- En móvil: tocar la puerta en la pantalla.
local function tryAt(screenPos: Vector2): boolean
	if not canUse() then
		return false
	end
	local ray = workspace.CurrentCamera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local door = doorAlong(ray.Origin, ray.Direction)
	if door then
		Remotes.Event("ToggleDoor"):FireServer(door)
		return true
	end
	return false
end

local function updateHint()
	local label = hint
	if not label then
		return
	end
	local door = aimedDoor()
	label.Visible = door ~= nil
	if door then
		local verb = if door:GetAttribute("Open") == true then "cerrar" else "abrir"
		label.Text = (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Toca la puerta: " else "Clic: ") .. verb
	end
end

function DoorController.Start()
	hint = UIController.Label({
		Name = "DoorHint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 24),
		Size = UDim2.fromOffset(260, 26),
		TextSize = 18,
		Visible = false,
		Parent = UIController.Gui(),
	})
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			tryAt(position)
		end
	end)
	RunService.RenderStepped:Connect(updateHint)
end

return DoorController
