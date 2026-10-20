--!strict
-- Ataques de la Anomalía. El cliente solo dice "ataco"; el servidor elige el objetivo
-- (el Investigador más cercano delante, a rango y con línea de visión).
-- Atacar transformada durante >= AmbushMinMorphTime es una emboscada: muerte instantánea.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Guard = require(Util:WaitForChild("Guard"))
local PlayerUtil = require(Util:WaitForChild("PlayerUtil"))
local MorphService = require(script.Parent:WaitForChild("MorphService"))
local SanityService = require(script.Parent:WaitForChild("SanityService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))

local A = Config.Anomaly

local CombatService = {}

local lastAttack: { [Player]: number } = {}

local function hasLineOfSight(from: Vector3, to: Vector3, ignore: { Instance }, target: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(from, to - from, params)
	return result == nil or result.Instance:IsDescendantOf(target)
end

local function findTarget(attacker: Player, aim: Vector3?): Player?
	local root = PlayerUtil.Root(attacker)
	if not root or not attacker.Character then
		return nil
	end
	-- Apunta hacia donde mira su cámara (si la manda) y si no, hacia donde mira el cuerpo.
	local forward = (aim or root.CFrame.LookVector) * Vector3.new(1, 0, 1)
	forward = if forward.Magnitude > 0 then forward.Unit else Vector3.new(0, 0, -1)
	-- Transformada, el mueble puede ser ancho: margen extra de alcance y de ángulo.
	local morphed = MorphService.IsMorphed(attacker)
	local range = A.AttackRange + (if morphed then 2 else 0)
	local minDot = if morphed then -0.2 else 0.35

	local best: Player? = nil
	local bestDist = math.huge
	for _, victim in PlayerUtil.Investigators() do
		local vRoot = PlayerUtil.Root(victim)
		local vChar = victim.Character
		if vRoot and vChar then
			local offset = vRoot.Position - root.Position
			local dist = offset.Magnitude
			local flat = offset * Vector3.new(1, 0, 1)
			local dot = if flat.Magnitude > 0 then forward:Dot(flat.Unit) else 1
			if dist <= range and dot >= minDot and dist < bestDist then
				if hasLineOfSight(root.Position, vRoot.Position, { attacker.Character }, vChar) then
					best, bestDist = victim, dist
				end
			end
		end
	end
	return best
end

function CombatService.Kill(victim: Player, killer: Player?, propId: string?)
	local humanoid = PlayerUtil.Humanoid(victim)
	local root = PlayerUtil.Root(victim)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local position = if root then root.Position else Vector3.zero
	Remotes.Event("KillCam"):FireClient(victim, if killer then killer.Character else nil, propId)
	humanoid.Health = 0
	SanityService.WitnessKill(position, victim)
	if killer then
		EconomyService.Award(killer, ShopCatalog.Rewards.AnomalyKill, "Eliminaciones")
		DataService.AddStat(killer, "kills", 1)
	end
end

local function onAttack(player: Player, aim: Vector3?)
	if ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
		return
	end
	if not PlayerUtil.IsAnomaly(player) or MorphService.IsStunned(player) then
		return
	end
	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < A.AttackCooldown then
		return
	end
	lastAttack[player] = now

	local propId = MorphService.PropId(player)
	local ambush = propId ~= nil and MorphService.MorphedFor(player) >= A.AmbushMinMorphTime
	local victim = findTarget(player, aim)
	-- Atacar siempre revela: el mueble "cobra vida".
	if propId then
		MorphService.Unmorph(player)
	end
	if not victim then
		return
	end
	local humanoid = PlayerUtil.Humanoid(victim)
	if not humanoid then
		return
	end
	local damage = if ambush then A.AmbushDamage else A.AttackDamage
	if damage >= humanoid.Health then
		CombatService.Kill(victim, player, if ambush then propId else nil)
	else
		humanoid:TakeDamage(damage)
		SanityService.Change(victim, -Config.Sanity.AttackedLoss)
		Remotes.Event("Scare"):FireClient(victim, 0.7)
	end
end

function CombatService.Init()
	Remotes.Event("RequestAttack").OnServerEvent:Connect(function(player, aim)
		if not Guard.RateLimit(player, "Attack", 0.2) then
			return
		end
		local dir: Vector3? = nil
		if Guard.IsFiniteVector(aim) and (aim :: Vector3).Magnitude > 0.01 then
			dir = (aim :: Vector3).Unit
		end
		onAttack(player, dir)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
end

return CombatService
