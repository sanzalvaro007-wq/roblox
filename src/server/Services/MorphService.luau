--!strict
-- Transformación de la Anomalía en muebles. El disfraz se construye con el mismo
-- catálogo que los señuelos de la mansión, así son idénticos salvo por pequeños "tells":
-- giro libre (los señuelos van a 90 grados), lectura más alta en el EMF y el flash de la cámara.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local PropCatalog = require(Shared:WaitForChild("PropCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Guard = require(Util:WaitForChild("Guard"))
local PlayerUtil = require(Util:WaitForChild("PlayerUtil"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))

type MorphState = {
	propId: string?,
	disguise: Model?,
	morphedAt: number,
	lastMorph: number,
	stunnedUntil: number,
	immuneUntil: number,
	hidden: { [Instance]: number },
}

local MorphService = {}

local states: { [Player]: MorphState } = {}

local function getState(player: Player): MorphState
	local s = states[player]
	if not s then
		s = {
			propId = nil,
			disguise = nil,
			morphedAt = 0,
			lastMorph = -math.huge,
			stunnedUntil = 0,
			immuneUntil = 0,
			hidden = {},
		}
		states[player] = s
	end
	return s
end

local function roundActive(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	return state == Enums.RoundState.Playing or state == Enums.RoundState.Preparing
end

function MorphService.ApplySpeed(player: Player)
	local humanoid = PlayerUtil.Humanoid(player)
	if not humanoid then
		return
	end
	local s = getState(player)
	if os.clock() < s.stunnedUntil then
		humanoid.WalkSpeed = 0
	elseif s.propId then
		humanoid.WalkSpeed = Config.Anomaly.MorphedWalkSpeed
	else
		humanoid.WalkSpeed = Config.Anomaly.WalkSpeed
	end
	local canJump = s.propId == nil and os.clock() >= s.stunnedUntil
	humanoid.JumpPower = if canJump then 50 else 0
	humanoid.JumpHeight = if canJump then 7.2 else 0
end

function MorphService.IsMorphed(player: Player): boolean
	return getState(player).propId ~= nil
end

function MorphService.PropId(player: Player): string?
	return getState(player).propId
end

function MorphService.MorphedFor(player: Player): number
	local s = getState(player)
	return if s.propId then os.clock() - s.morphedAt else 0
end

function MorphService.Disguise(player: Player): Model?
	return getState(player).disguise
end

function MorphService.IsStunned(player: Player): boolean
	return os.clock() < getState(player).stunnedUntil
end

function MorphService.IsImmune(player: Player): boolean
	return os.clock() < getState(player).immuneUntil
end

function MorphService.Unmorph(player: Player)
	local s = getState(player)
	if s.disguise then
		s.disguise:Destroy()
	end
	for inst, transparency in s.hidden do
		if inst.Parent and (inst:IsA("BasePart") or inst:IsA("Decal")) then
			(inst :: any).Transparency = transparency
		end
	end
	local wasMorphed = s.propId ~= nil
	s.hidden = {}
	s.disguise = nil
	s.propId = nil
	if wasMorphed then
		s.lastMorph = os.clock()
		Remotes.Event("MorphState"):FireClient(player, nil)
	end
	MorphService.ApplySpeed(player)
end

function MorphService.Morph(player: Player, propId: string): (boolean, string?)
	local s = getState(player)
	local def = PropCatalog.Get(propId)
	if not def then
		return false, "Forma desconocida"
	end
	if not PlayerUtil.IsAnomaly(player) or not roundActive() then
		return false, nil
	end
	if os.clock() < s.stunnedUntil then
		return false, "Estás aturdida"
	end
	if os.clock() - s.lastMorph < Config.Anomaly.MorphCooldown then
		return false, "Aún no puedes transformarte"
	end
	local character = player.Character
	local root = PlayerUtil.Root(player)
	local humanoid = PlayerUtil.Humanoid(player)
	if not character or not root or not humanoid then
		return false, nil
	end

	MorphService.Unmorph(player)

	local disguise = PropCatalog.Build(propId)
	if not disguise then
		return false, nil
	end
	local heightAboveFloor = if humanoid.RigType == Enum.HumanoidRigType.R6
		then 3
		else humanoid.HipHeight + root.Size.Y / 2
	-- Solo la orientación horizontal del cuerpo, para que el mueble quede recto.
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local base = CFrame.lookAt(root.Position, root.Position + look.Unit) * CFrame.new(0, -heightAboveFloor, 0)
	disguise:PivotTo(base)
	for _, part in disguise:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = true
			part.CanTouch = false
			part.CollisionGroup = CharacterService.Groups.Disguise
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end

	-- Ocultar el cuerpo (guardando la transparencia original para restaurarla).
	local hidden: { [Instance]: number } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			hidden[d] = d.Transparency
			d.Transparency = 1
		elseif d:IsA("Decal") then
			hidden[d] = d.Transparency
			d.Transparency = 1
		end
	end
	disguise.Parent = character

	s.hidden = hidden
	s.disguise = disguise
	s.propId = propId
	s.morphedAt = os.clock()
	s.lastMorph = os.clock()
	MorphService.ApplySpeed(player)
	Remotes.Event("MorphState"):FireClient(player, propId)
	return true, nil
end

-- Aturde a la Anomalía (flash de cámara). Devuelve false si es inmune ahora mismo.
function MorphService.Stun(player: Player, duration: number): boolean
	local s = getState(player)
	if os.clock() < s.immuneUntil then
		return false
	end
	s.stunnedUntil = os.clock() + duration
	s.immuneUntil = os.clock() + Config.Anomaly.PhotoImmunityTime
	MorphService.ApplySpeed(player)
	task.delay(duration + 0.05, function()
		if player.Parent then
			MorphService.ApplySpeed(player)
		end
	end)
	return true
end

-- Silueta visible para todos durante unos segundos.
function MorphService.Reveal(player: Player, duration: number)
	local character = player.Character
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "Revealed"
	highlight.FillColor = Color3.fromRGB(200, 20, 20)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 80, 80)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	task.delay(duration, function()
		highlight:Destroy()
	end)
end

function MorphService.Reset(player: Player)
	MorphService.Unmorph(player)
	states[player] = nil
end

function MorphService.Init()
	Remotes.Event("RequestMorph").OnServerEvent:Connect(function(player, propId)
		if typeof(propId) ~= "string" or not Guard.RateLimit(player, "Morph", 0.5) then
			return
		end
		local ok, message = MorphService.Morph(player, propId)
		if not ok and message then
			Remotes.Event("Notify"):FireClient(player, message, "warn")
		end
	end)
	Remotes.Event("RequestUnmorph").OnServerEvent:Connect(function(player)
		if not Guard.RateLimit(player, "Unmorph", 0.3) then
			return
		end
		if PlayerUtil.Role(player) == Enums.Role.Anomaly and MorphService.IsMorphed(player) then
			MorphService.Unmorph(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return MorphService
