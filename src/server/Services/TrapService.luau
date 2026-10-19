--!strict
-- Campana trampa (consumible de la tienda). Un Investigador puede colocar una por ronda;
-- si la Anomalía pasa cerca, suena, la revela un instante y avisa al equipo.
-- La campana se ve, así que una Anomalía atenta puede rodearla.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Guard = require(Util:WaitForChild("Guard"))
local PlayerUtil = require(Util:WaitForChild("PlayerUtil"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MansionService = require(script.Parent:WaitForChild("MansionService"))
local MorphService = require(script.Parent:WaitForChild("MorphService"))

local TRIGGER_RADIUS = 5
local REVEAL_TIME = 2

local TrapService = {}

type Trap = { part: BasePart, owner: Player }

local traps: { Trap } = {}
local placedThisRound: { [Player]: boolean } = {}

local function place(player: Player)
	if ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
		return
	end
	if not PlayerUtil.IsInvestigator(player) then
		return
	end
	if placedThisRound[player] then
		Remotes.Event("Notify"):FireClient(player, "Ya has colocado tu campana esta ronda", "warn")
		return
	end
	local data = DataService.Get(player)
	local mansion = MansionService.Get()
	local root = PlayerUtil.Root(player)
	if not data or not mansion or not root then
		return
	end
	if (data.consumables.Trap_Bell or 0) <= 0 then
		Remotes.Event("Notify"):FireClient(player, "No tienes campanas (cómpralas en la tienda)", "warn")
		return
	end
	data.consumables.Trap_Bell -= 1
	placedThisRound[player] = true
	DataService.Sync(player)

	local bell = Instance.new("Part")
	bell.Name = "BellTrap"
	bell.Shape = Enum.PartType.Ball
	bell.Anchored = true
	bell.CanCollide = false
	bell.CanQuery = false
	bell.Size = Vector3.new(0.8, 0.8, 0.8)
	bell.Material = Enum.Material.Metal
	bell.Color = Color3.fromRGB(190, 160, 80)
	bell.Position = root.Position - Vector3.new(0, 2.6, 0)
	bell.Parent = mansion.Model
	table.insert(traps, { part = bell :: BasePart, owner = player })
	Remotes.Event("Notify"):FireClient(player, "Campana colocada", "info")
end

local function trigger(trap: Trap, anomaly: Player)
	local bell = trap.part
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 2
	sound.RollOffMaxDistance = 150
	sound.Parent = bell
	sound:Play()
	MorphService.Reveal(anomaly, REVEAL_TIME)
	for _, player in PlayerUtil.Investigators() do
		Remotes.Event("Notify"):FireClient(player, "¡Una campana ha sonado! Algo ha pasado por ahí", "danger")
	end
	task.delay(2, function()
		bell:Destroy()
	end)
end

function TrapService.Init()
	Remotes.Event("PlaceTrap").OnServerEvent:Connect(function(player)
		if Guard.RateLimit(player, "Trap", 0.5) then
			place(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
				if #traps > 0 or next(placedThisRound) then
					traps = {}
					placedThisRound = {}
				end
				continue
			end
			local anomaly = PlayerUtil.Anomaly()
			local root = if anomaly then PlayerUtil.Root(anomaly) else nil
			for i = #traps, 1, -1 do
				local trap = traps[i]
				if trap.part.Parent == nil then
					table.remove(traps, i)
				elseif anomaly and root and (root.Position - trap.part.Position).Magnitude <= TRIGGER_RADIUS then
					table.remove(traps, i)
					trigger(trap, anomaly)
				end
			end
		end
	end)
end

return TrapService
