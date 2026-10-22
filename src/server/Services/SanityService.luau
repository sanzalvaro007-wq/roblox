--!strict
-- Cordura de los Investigadores (autoritativa en el servidor, atributo "Sanity").
-- Baja con oscuridad, soledad y la Anomalía cerca; sube en grupo y con luz.
-- Las alucinaciones las genera SOLO el cliente de cada jugador leyendo su atributo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerUtil = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("PlayerUtil"))
local MansionService = require(script.Parent:WaitForChild("MansionService"))

local S = Config.Sanity

local SanityService = {}

function SanityService.Setup(player: Player)
	player:SetAttribute("Sanity", S.Max)
end

function SanityService.Change(player: Player, amount: number)
	local current = player:GetAttribute("Sanity")
	if typeof(current) ~= "number" then
		return
	end
	player:SetAttribute("Sanity", math.clamp(current + amount, 0, S.Max))
end

local function nearLight(position: Vector3): boolean
	local mansion = MansionService.Get()
	if not mansion then
		return false
	end
	local radius = if ReplicatedStorage:GetAttribute("PowerOn") == true
		then Config.Objectives.LampRadiusPowerOn
		else Config.Objectives.LampRadiusPowerOff
	for _, lamp in mansion.Lamps do
		local flat = (lamp.Position - position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= radius then
			return true
		end
	end
	return false
end

local function tick(dt: number)
	local investigators = PlayerUtil.Investigators()
	local anomaly = PlayerUtil.Anomaly()
	local anomalyRoot = if anomaly then PlayerUtil.Root(anomaly) else nil

	for _, player in investigators do
		local root = PlayerUtil.Root(player)
		if not root then
			continue
		end
		local pos = root.Position
		local lit = player:GetAttribute("Flashlight") == true or nearLight(pos)

		local companions = 0
		for _, other in investigators do
			if other ~= player then
				local otherRoot = PlayerUtil.Root(other)
				if otherRoot and (otherRoot.Position - pos).Magnitude <= S.AloneRadius then
					companions += 1
				end
			end
		end

		local delta = 0
		delta += if lit then S.LightRegen else -S.DarkDrain
		delta += if companions > 0 then S.GroupRegen else -S.AloneDrain
		if anomalyRoot and (anomalyRoot.Position - pos).Magnitude <= S.NearAnomalyRadius then
			delta -= S.NearAnomalyDrain
		end
		SanityService.Change(player, delta * dt)
	end
end

-- Un Investigador ha muerto en `position`: susto a los que estaban cerca.
function SanityService.WitnessKill(position: Vector3, victim: Player)
	for _, player in PlayerUtil.Investigators() do
		if player ~= victim then
			local root = PlayerUtil.Root(player)
			if root and (root.Position - position).Magnitude <= S.WitnessKillRadius then
				SanityService.Change(player, -S.WitnessKillLoss)
				Remotes.Event("Scare"):FireClient(player, 1)
			end
		end
	end
end

function SanityService.Init()
	task.spawn(function()
		while true do
			task.wait(S.TickInterval)
			if ReplicatedStorage:GetAttribute("RoundState") == Enums.RoundState.Playing then
				tick(S.TickInterval)
			end
		end
	end)
end

return SanityService
