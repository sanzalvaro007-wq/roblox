--!strict
-- Abre y cierra las puertas de la mansión. El cliente solo pide "esta puerta"; aquí se
-- comprueba que sea una puerta de verdad, que el jugador esté vivo y cerca, y se gira la
-- hoja sobre su bisagra hacia el lado contrario de quien empuja (o hacia el suyo si al
-- otro lado hay alguien). Abrir o cerrar hace algo de ruido.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Server = ServerScriptService:WaitForChild("Server")
local Doors = require(Server:WaitForChild("Mansion"):WaitForChild("Doors"))
local Util = script.Parent.Parent:WaitForChild("Util")
local Guard = require(Util:WaitForChild("Guard"))
local PlayerUtil = require(Util:WaitForChild("PlayerUtil"))
local NoiseService = require(script.Parent:WaitForChild("NoiseService"))

-- Desde la raíz del jugador hasta la hoja tal como está ahora. El cliente solo ofrece la
-- puerta a 9 studs, así que aquí sobra margen para el retraso de red.
local REACH = 11
local SWING_TIME = 0.45
local DOOR_NOISE = 0.45
local DOOR_NOISE_TIME = 0.8
-- Hueco que se deja al buscar cuerpos dentro de la hoja: quien solo se apoya en ella no cuenta.
local SHRINK = Vector3.new(0.4, 0.4, 0.2)

local DoorService = {}

local busy: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local pending: { [BasePart]: {} } = setmetatable({}, { __mode = "k" }) :: any

-- Cuerpos de los jugadores (los fantasmas atraviesan las puertas).
local function bodies(): { Instance }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character and p:GetAttribute("Ghost") ~= true then
			table.insert(list, p.Character)
		end
	end
	return list
end

-- ¿Hay alguien donde está (o quedaría) la hoja?
local function occupied(cf: CFrame, size: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = bodies()
	return #workspace:GetPartBoundsInBox(cf, size - SHRINK, params) > 0
end

-- Vuelve a ser sólida en cuanto no queda nadie dentro; si se activara encima de alguien,
-- el motor físico lo lanzaría por los aires.
local function solidify(door: BasePart)
	local token = {}
	pending[door] = token
	task.spawn(function()
		while door.Parent and occupied(door.CFrame, door.Size) do
			task.wait(0.2)
			if pending[door] ~= token then
				return
			end
		end
		if pending[door] == token then
			pending[door] = nil
			door.CanCollide = true
		end
	end)
end

function DoorService.Toggle(player: Player, door: BasePart): boolean
	if busy[door] or not CollectionService:HasTag(door, Doors.Tag) or not door:IsDescendantOf(workspace) then
		return false
	end
	local closed = door:GetAttribute("ClosedCFrame")
	local width = door:GetAttribute("Width")
	if typeof(closed) ~= "CFrame" or typeof(width) ~= "number" then
		return false
	end
	local root = PlayerUtil.Root(player)
	if not root or Doors.DistanceTo(door, root.Position) > REACH then
		return false
	end
	local angle = door:GetAttribute("Angle")
	local from = if typeof(angle) == "number" then angle else 0
	local to = 0
	if door:GetAttribute("Open") ~= true then
		-- Se abre alejándose de quien empuja, salvo que al otro lado haya alguien.
		local side = closed:PointToObjectSpace(root.Position).Z
		to = Doors.OpenAngleFor(if side > 0 then 1 else -1)
		if occupied(Doors.HingeCFrame(closed, width, to), door.Size) and not occupied(Doors.HingeCFrame(closed, width, -to), door.Size) then
			to = -to
		end
	end
	busy[door] = true
	pending[door] = nil
	door:SetAttribute("Open", to ~= 0)
	door:SetAttribute("Swinging", true)
	-- Mientras gira no empuja a nadie. Se interpola el ángulo (no el CFrame) para que la
	-- hoja describa el arco sobre la bisagra en vez de deslizarse en línea recta.
	door.CanCollide = false
	local alpha = Instance.new("NumberValue")
	alpha.Changed:Connect(function(a: number)
		door.CFrame = Doors.HingeCFrame(closed, width, from + (to - from) * a)
	end)
	local tween = TweenService:Create(alpha, TweenInfo.new(SWING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	tween.Completed:Once(function()
		alpha:Destroy()
		door.CFrame = Doors.HingeCFrame(closed, width, to)
		door:SetAttribute("Angle", to)
		door:SetAttribute("Swinging", false)
		busy[door] = nil
		solidify(door)
	end)
	tween:Play()
	if PlayerUtil.Role(player) == Enums.Role.Investigator then
		NoiseService.Bump(player, DOOR_NOISE, DOOR_NOISE_TIME)
	end
	return true
end

local function canUseDoors(player: Player): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	if state ~= Enums.RoundState.Playing and state ~= Enums.RoundState.Preparing then
		return false
	end
	if player:GetAttribute("Ghost") == true then
		return false
	end
	return PlayerUtil.IsInvestigator(player) or PlayerUtil.IsAnomaly(player)
end

function DoorService.Init()
	Remotes.Event("ToggleDoor").OnServerEvent:Connect(function(player, door)
		if not Guard.RateLimit(player, "Door", 0.25) then
			return
		end
		if typeof(door) ~= "Instance" or not (door :: Instance):IsA("BasePart") then
			return
		end
		if canUseDoors(player) then
			DoorService.Toggle(player, door :: BasePart)
		end
	end)
end

return DoorService
