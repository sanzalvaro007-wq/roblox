--!strict
-- Máquina de estados de la ronda:
-- Waiting -> Intermission -> Preparing (la Anomalía se esconde) -> Playing -> Results -> Waiting
-- Victoria: Investigadores si escapan al menos EscapesToWin; si no (todos eliminados o
-- tiempo agotado), gana la Anomalía.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerUtil = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("PlayerUtil"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local GhostService = require(script.Parent:WaitForChild("GhostService"))
local MansionService = require(script.Parent:WaitForChild("MansionService"))
local MorphService = require(script.Parent:WaitForChild("MorphService"))
local NoiseService = require(script.Parent:WaitForChild("NoiseService"))
local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))
local RoleService = require(script.Parent:WaitForChild("RoleService"))
local SanityService = require(script.Parent:WaitForChild("SanityService"))
local ToolService = require(script.Parent:WaitForChild("ToolService"))

local R = Config.Round

local RoundService = {}

local reviveHandler: ((Player) -> boolean)? = nil
local endedCallbacks: { () -> () } = {}

local function setState(state: string, duration: number?)
	ReplicatedStorage:SetAttribute("RoundState", state)
	ReplicatedStorage:SetAttribute("StateEndsAt", if duration then workspace:GetServerTimeNow() + duration else 0)
end

local function enoughPlayers(): boolean
	local count = #Players:GetPlayers()
	if count >= R.MinPlayers then
		return true
	end
	return count == 1 and RunService:IsStudio() and Config.Debug.AllowSoloInStudio
end

local function waitForPlayers()
	setState(Enums.RoundState.Waiting)
	while not enoughPlayers() do
		task.wait(1)
	end
end

-- Cuenta atrás; devuelve false si se cancela por falta de jugadores.
local function intermission(): boolean
	setState(Enums.RoundState.Intermission, R.IntermissionTime)
	local endsAt = os.clock() + R.IntermissionTime
	while os.clock() < endsAt do
		if not enoughPlayers() then
			return false
		end
		task.wait(0.5)
	end
	return true
end

local function spawnInvestigator(player: Player, cf: CFrame)
	player:SetAttribute("Alive", true)
	player:SetAttribute("Escaped", false)
	CharacterService.SpawnAt(player, cf)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	ToolService.Setup(player)
	SanityService.Setup(player)
end

local function spawnAnomaly(player: Player, cf: CFrame)
	player:SetAttribute("Alive", true)
	player:SetAttribute("Escaped", false)
	local character = CharacterService.SpawnAt(player, cf)
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = 14
	if character then
		CharacterService.ApplyAnomalyLook(character)
	end
	MorphService.ApplySpeed(player)
end

local function runRound()
	local participants = Players:GetPlayers()
	local mansion = MansionService.Generate()
	local assignment = RoleService.Assign(participants)
	local connections: { RBXScriptConnection } = {}

	local function onLost(player: Player)
		if player:GetAttribute("Alive") ~= true then
			return
		end
		player:SetAttribute("Alive", false)
		player.CameraMode = Enum.CameraMode.Classic
		local root = PlayerUtil.Root(player)
		ObjectiveService.DropFuse(player, if root then root.Position else nil)
		if PlayerUtil.Role(player) == Enums.Role.Investigator and player:GetAttribute("Escaped") ~= true then
			Remotes.Event("Notify"):FireAllClients(player.DisplayName .. " ha sido eliminado", "danger")
			if player.Parent and root then
				local deathCf = CFrame.new(root.Position)
				task.delay(Config.Ghost.SpawnDelay, function()
					GhostService.MakeGhost(player, deathCf)
				end)
			end
		end
	end

	local function watchDeath(player: Player)
		local humanoid = PlayerUtil.Humanoid(player)
		if humanoid then
			table.insert(connections, humanoid.Died:Connect(function()
				onLost(player)
			end))
		end
	end

	for i, player in assignment.investigators do
		spawnInvestigator(player, mansion.InvestigatorSpawns[((i - 1) % #mansion.InvestigatorSpawns) + 1])
		watchDeath(player)
	end
	if assignment.anomaly then
		spawnAnomaly(assignment.anomaly, mansion.AnomalySpawn)
		watchDeath(assignment.anomaly)
	end
	table.insert(connections, Players.PlayerRemoving:Connect(onLost))

	-- Revive Token: un fantasma vuelve al vestíbulo como Investigador.
	reviveHandler = function(player: Player): boolean
		if not table.find(assignment.investigators, player) or player:GetAttribute("Ghost") ~= true then
			return false
		end
		GhostService.Revived(player)
		spawnInvestigator(player, mansion.InvestigatorSpawns[1])
		player:SetAttribute("Sanity", Config.Sanity.Max / 2)
		watchDeath(player)
		Remotes.Event("Notify"):FireAllClients(player.DisplayName .. " ha vuelto de entre los muertos", "info")
		return true
	end

	ObjectiveService.Setup(mansion :: any, #assignment.investigators)

	-- Preparación: la Anomalía se esconde; los Investigadores esperan congelados.
	setState(Enums.RoundState.Preparing, R.PrepTime)
	task.wait(R.PrepTime)

	setState(Enums.RoundState.Playing, R.RoundTime)
	local endsAt = os.clock() + R.RoundTime
	local winner = Enums.Winner.None
	local reason = ""
	while true do
		task.wait(0.25)
		local escaped = ReplicatedStorage:GetAttribute("Escaped") or 0
		local active = #PlayerUtil.Investigators()
		local anomaly = assignment.anomaly
		if anomaly and (anomaly.Parent == nil or anomaly:GetAttribute("Alive") ~= true) then
			winner, reason = Enums.Winner.Investigators, "La Anomalía ha abandonado la mansión"
			break
		end
		if #assignment.investigators > 0 and active == 0 then
			if escaped >= R.EscapesToWin then
				winner, reason = Enums.Winner.Investigators, "Los Investigadores han escapado"
			else
				winner, reason = Enums.Winner.Anomaly, "La mansión se ha cobrado a todos"
			end
			break
		end
		if os.clock() >= endsAt then
			if escaped >= R.EscapesToWin then
				winner, reason = Enums.Winner.Investigators, "Algunos escaparon antes del amanecer"
			else
				winner, reason = Enums.Winner.Anomaly, "Nadie escapó a tiempo"
			end
			break
		end
	end

	local escapedNames, eliminatedNames = {}, {}
	for _, player in assignment.investigators do
		if player:GetAttribute("Escaped") == true then
			table.insert(escapedNames, player.DisplayName)
		elseif player:GetAttribute("Alive") ~= true then
			table.insert(eliminatedNames, player.DisplayName)
		end
	end
	reviveHandler = nil
	EconomyService.FinishRound({
		anomaly = assignment.anomaly,
		investigators = assignment.investigators,
		winner = winner,
	})
	Remotes.Event("RoundResult"):FireAllClients({
		winner = winner,
		reason = reason,
		anomaly = if assignment.anomaly then assignment.anomaly.DisplayName else nil,
		escaped = escapedNames,
		eliminated = eliminatedNames,
	})
	setState(Enums.RoundState.Results, R.ResultsTime)
	for _, c in connections do
		c:Disconnect()
	end
	task.wait(R.ResultsTime)

	-- Limpieza: todos vuelven al lobby con un personaje nuevo.
	GhostService.ResetAll()
	for _, player in participants do
		if player.Parent then
			MorphService.Reset(player)
			ToolService.Reset(player)
			NoiseService.Reset(player)
			ObjectiveService.ResetPlayer(player)
			RoleService.Clear(player)
			player:SetAttribute("Alive", false)
			player:SetAttribute("Escaped", nil)
			player:SetAttribute("Sanity", nil)
			task.spawn(CharacterService.SendToLobby, player)
		end
	end
	ObjectiveService.Cleanup()
	MansionService.Destroy()
	for _, callback in endedCallbacks do
		task.spawn(callback)
	end
end

function RoundService.Revive(player: Player): boolean
	return if reviveHandler then reviveHandler(player) else false
end

function RoundService.OnRoundEnded(callback: () -> ())
	table.insert(endedCallbacks, callback)
end

function RoundService.Init()
	setState(Enums.RoundState.Waiting)
end

function RoundService.Start()
	task.spawn(function()
		while true do
			waitForPlayers()
			if intermission() then
				local ok = xpcall(runRound, function(err)
					warn("[RoundService] error en la ronda:", err, debug.traceback())
				end)
				if not ok then
					reviveHandler = nil
					MansionService.Destroy()
					GhostService.ResetAll()
					for _, player in Players:GetPlayers() do
						MorphService.Reset(player)
						ToolService.Reset(player)
						RoleService.Clear(player)
						player:SetAttribute("Alive", false)
						task.spawn(CharacterService.SendToLobby, player)
					end
					task.wait(3)
				end
			end
		end
	end)
end

return RoundService
