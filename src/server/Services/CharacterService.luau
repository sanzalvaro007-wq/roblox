--!strict
-- Spawns, lobby, grupos de colisión y aspecto de la Anomalía.
-- Los personajes no reaparecen solos: el servidor decide cuándo y dónde.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))

local CharacterService = {}

CharacterService.Groups = {
	Players = "Players",
	Anomaly = "Anomaly",
	Disguise = "Disguise",
	Ghost = "Ghost",
}

local lobbySpawn = CFrame.new(Config.Lobby.Position + Vector3.new(0, 4, 0))

local function setupCollisionGroups()
	local g = CharacterService.Groups
	for _, name in { g.Players, g.Anomaly, g.Disguise, g.Ghost } do
		PhysicsService:RegisterCollisionGroup(name)
	end
	-- Los fantasmas chocan con la mansión pero atraviesan a todo el mundo.
	for _, other in { g.Players, g.Anomaly, g.Disguise, g.Ghost } do
		PhysicsService:CollisionGroupSetCollidable(g.Ghost, other, false)
	end
	-- La Anomalía atraviesa a los Investigadores (no puede bloquear puertas con el cuerpo)...
	PhysicsService:CollisionGroupSetCollidable(g.Anomaly, g.Players, false)
	-- ...pero su disfraz sí es sólido para ellos, como un mueble real.
	PhysicsService:CollisionGroupSetCollidable(g.Disguise, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(g.Disguise, g.Anomaly, false)
	PhysicsService:CollisionGroupSetCollidable(g.Disguise, g.Disguise, false)
	PhysicsService:CollisionGroupSetCollidable(g.Disguise, g.Players, true)
end

local function buildLobby()
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Config.Lobby.Size
	floor.CFrame = CFrame.new(Config.Lobby.Position - Vector3.new(0, 0.5, 0))
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(70, 52, 40)
	floor.Parent = lobby
	local half = Config.Lobby.Size / 2
	for _, offset in { Vector3.new(half.X, 0, 0), Vector3.new(-half.X, 0, 0), Vector3.new(0, 0, half.Z), Vector3.new(0, 0, -half.Z) } do
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Anchored = true
		wall.Size = if offset.X ~= 0 then Vector3.new(1, 12, Config.Lobby.Size.Z) else Vector3.new(Config.Lobby.Size.X, 12, 1)
		wall.CFrame = CFrame.new(Config.Lobby.Position + offset + Vector3.new(0, 6, 0))
		wall.Material = Enum.Material.Plaster
		wall.Color = Color3.fromRGB(90, 85, 80)
		wall.Parent = lobby
	end
	local light = Instance.new("Part")
	light.Name = "Chandelier"
	light.Anchored = true
	light.CanCollide = false
	light.Material = Enum.Material.Neon
	light.Color = Color3.fromRGB(255, 210, 160)
	light.Size = Vector3.new(3, 1, 3)
	light.CFrame = CFrame.new(Config.Lobby.Position + Vector3.new(0, 11, 0))
	local point = Instance.new("PointLight")
	point.Range = 60
	point.Brightness = 1.5
	point.Color = light.Color
	point.Parent = light
	light.Parent = lobby
	lobby.Parent = workspace
end

local function groupFor(player: Player): string
	if player:GetAttribute("Ghost") == true then
		return CharacterService.Groups.Ghost
	end
	return if player:GetAttribute("Role") == Enums.Role.Anomaly
		then CharacterService.Groups.Anomaly
		else CharacterService.Groups.Players
end

local function setGroup(character: Model, group: string)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.CollisionGroup ~= CharacterService.Groups.Disguise then
			d.CollisionGroup = group
		end
	end
end

local function hideNames(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Terror: sin nombres flotantes que delaten a nadie.
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

local function onCharacterAdded(player: Player, character: Model)
	hideNames(character)
	setGroup(character, groupFor(player))
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.CollisionGroup ~= CharacterService.Groups.Disguise then
			d.CollisionGroup = groupFor(player)
		end
	end)

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			-- En el lobby se reaparece; en partida, RoundService decide.
			if player:GetAttribute("Role") == Enums.Role.Lobby or player:GetAttribute("Role") == nil then
				task.delay(3, function()
					if player.Parent and player.Character == character then
						CharacterService.SendToLobby(player)
					end
				end)
			end
		end)
	end
end

-- Carga un personaje nuevo y lo coloca en `cf`. Bloquea hasta que existe.
function CharacterService.SpawnAt(player: Player, cf: CFrame): Model?
	if not player.Parent then
		return nil
	end
	player:LoadCharacterAsync()
	local character = player.Character
	if not character then
		return nil
	end
	character:PivotTo(cf)
	return character
end

function CharacterService.SendToLobby(player: Player)
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = 14
	local jitter = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
	CharacterService.SpawnAt(player, lobbySpawn + jitter)
end

-- Mueve un personaje vivo al lobby sin matarlo (al escapar).
function CharacterService.MoveToLobby(player: Player)
	local character = player.Character
	if character then
		local jitter = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
		character:PivotTo(lobbySpawn + jitter)
	end
	player.CameraMode = Enum.CameraMode.Classic
end

-- Silueta oscura con ojos rojos. Placeholder hasta tener el modelo de Blender.
function CharacterService.ApplyAnomalyLook(character: Model)
	local function strip(d: Instance)
		if d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") then
			d:Destroy()
		elseif d:IsA("Decal") and d.Name == "face" then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.CollisionGroup ~= CharacterService.Groups.Disguise then
			d.Color = Color3.fromRGB(12, 10, 12)
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	for _, d in character:GetDescendants() do
		strip(d)
	end
	character.DescendantAdded:Connect(function(d)
		task.defer(strip, d)
	end)
	setGroup(character, CharacterService.Groups.Anomaly)

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		for _, side in { -1, 1 } do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Size = Vector3.new(0.18, 0.12, 0.05)
			eye.Material = Enum.Material.Neon
			eye.Color = Color3.fromRGB(255, 30, 30)
			eye.CanCollide = false
			eye.CanQuery = false
			eye.Massless = true
			eye.CFrame = head.CFrame * CFrame.new(0.22 * side, 0.1, -head.Size.Z / 2)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = eye
			weld.Parent = eye
			eye.Parent = character
		end
	end
end

function CharacterService.Init()
	setupCollisionGroups()
	buildLobby()
	Players.CharacterAutoLoads = false
	local function onPlayerAdded(player: Player)
		player:SetAttribute("Role", Enums.Role.Lobby)
		player:SetAttribute("Alive", false)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		CharacterService.SendToLobby(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return CharacterService
