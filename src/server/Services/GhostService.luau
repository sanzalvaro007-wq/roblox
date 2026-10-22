--!strict
-- Espectador vengativo. Al morir, el Investigador vuelve como fantasma:
--   - invisible e inaudible para los vivos (se oculta en cada cliente; su voz solo la oyen fantasmas)
--   - atraviesa a todos, pero no las paredes
--   - puede encender/apagar una lámpara cercana y dejar un "susurro" (niebla fría) como pista
-- Ambas cosas tienen cooldown largo y las ve todo el mundo, la Anomalía incluida.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Guard = require(Util:WaitForChild("Guard"))
local PlayerUtil = require(Util:WaitForChild("PlayerUtil"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local MansionService = require(script.Parent:WaitForChild("MansionService"))

local G = Config.Ghost

local GhostService = {}

local lastLight: { [Player]: number } = {}
local lastWhisper: { [Player]: number } = {}

local function isGhost(player: Player): boolean
	return player:GetAttribute("Ghost") == true and player.Character ~= nil
end

local function playing(): boolean
	return ReplicatedStorage:GetAttribute("RoundState") == Enums.RoundState.Playing
end

-- La voz de los fantasmas solo la oyen otros fantasmas; los vivos se oyen con normalidad.
local function updateVoiceAccess()
	local ghosts: { number } = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Ghost") == true then
			table.insert(ghosts, p.UserId)
		end
	end
	for _, p in Players:GetPlayers() do
		local input = p:FindFirstChildOfClass("AudioDeviceInput")
		if input then
			pcall(function()
				if p:GetAttribute("Ghost") == true then
					input.AccessType = Enum.AccessModifierType.Allow
					input:SetUserIdAccessList(ghosts)
				else
					input.AccessType = Enum.AccessModifierType.Deny
					input:SetUserIdAccessList({})
				end
			end)
		end
	end
end

function GhostService.MakeGhost(player: Player, cf: CFrame)
	if not player.Parent or not playing() then
		return
	end
	player:SetAttribute("Ghost", true)
	local character = CharacterService.SpawnAt(player, cf + Vector3.new(0, 2, 0))
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = 12
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = G.WalkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		-- Un fantasma no puede morir otra vez.
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
	end
	updateVoiceAccess()
	Remotes.Event("Notify"):FireClient(player, "Eres un fantasma. Z: lámpara · X: susurro (pista)", "info")
end

local function nearestLamp(position: Vector3): BasePart?
	local mansion = MansionService.Get()
	if not mansion then
		return nil
	end
	local best: BasePart? = nil
	local bestDist = G.LightRange
	for _, lamp in mansion.Lamps do
		local flat = (lamp.Position - position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= bestDist then
			best, bestDist = lamp, flat.Magnitude
		end
	end
	return best
end

local function toggleLight(player: Player)
	local now = os.clock()
	if lastLight[player] and now - lastLight[player] < G.LightCooldown then
		Remotes.Event("Notify"):FireClient(player, "Aún no tienes fuerza para eso", "warn")
		return
	end
	local root = PlayerUtil.Root(player)
	local lamp = if root then nearestLamp(root.Position) else nil
	if not lamp then
		Remotes.Event("Notify"):FireClient(player, "No hay ninguna lámpara cerca", "warn")
		return
	end
	lastLight[player] = now
	-- El cliente invierte la lámpara mientras GhostUntil esté en el futuro.
	lamp:SetAttribute("GhostUntil", workspace:GetServerTimeNow() + G.LightDuration)
end

local function whisper(player: Player)
	local now = os.clock()
	if lastWhisper[player] and now - lastWhisper[player] < G.WhisperCooldown then
		Remotes.Event("Notify"):FireClient(player, "Aún no tienes fuerza para eso", "warn")
		return
	end
	local root = PlayerUtil.Root(player)
	local mansion = MansionService.Get()
	if not root or not mansion then
		return
	end
	lastWhisper[player] = now
	local offset = Vector3.new(math.random(-G.WhisperJitter, G.WhisperJitter), 0, math.random(-G.WhisperJitter, G.WhisperJitter))
	local mist = Instance.new("Part")
	mist.Name = "Whisper"
	mist.Anchored = true
	mist.CanCollide = false
	mist.CanQuery = false
	mist.CanTouch = false
	mist.Transparency = 1
	mist.Size = Vector3.new(2, 2, 2)
	mist.Position = root.Position + offset
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(170, 210, 255))
	particles.LightEmission = 0.4
	particles.Transparency = NumberSequence.new(0.6, 1)
	particles.Size = NumberSequence.new(1.5, 3)
	particles.Lifetime = NumberRange.new(1.5, 2.5)
	particles.Rate = 18
	particles.Speed = NumberRange.new(0.5, 1.5)
	particles.SpreadAngle = Vector2.new(180, 30)
	particles.Parent = mist
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 190, 255)
	glow.Range = 10
	glow.Brightness = 0.8
	glow.Parent = mist
	CollectionService:AddTag(mist, "GhostWhisper")
	mist.Parent = mansion.Model
	task.delay(G.WhisperDuration, function()
		mist:Destroy()
	end)
end

function GhostService.Reset(player: Player)
	player:SetAttribute("Ghost", nil)
	lastLight[player] = nil
	lastWhisper[player] = nil
end

-- Un fantasma revive (Revive Token): vuelve a oír y ser oído por los vivos.
function GhostService.Revived(player: Player)
	GhostService.Reset(player)
	updateVoiceAccess()
end

function GhostService.ResetAll()
	for _, p in Players:GetPlayers() do
		GhostService.Reset(p)
	end
	updateVoiceAccess()
end

function GhostService.Init()
	Remotes.Event("GhostAction").OnServerEvent:Connect(function(player, kind)
		if typeof(kind) ~= "string" or not Guard.RateLimit(player, "Ghost", 0.5) then
			return
		end
		if not playing() or not isGhost(player) then
			return
		end
		if kind == "Light" then
			toggleLight(player)
		elseif kind == "Whisper" then
			whisper(player)
		end
	end)
	Players.PlayerAdded:Connect(function()
		task.delay(5, updateVoiceAccess)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastLight[player] = nil
		lastWhisper[player] = nil
		task.defer(updateVoiceAccess)
	end)
end

return GhostService
