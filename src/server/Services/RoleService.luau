--!strict
-- Reparto de roles: 1 Anomalía y el resto Investigadores (máx. 7).
-- Sorteo ponderado: quien lleva más rondas sin ser Anomalía tiene más probabilidad.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local RoleService = {}

local roundsSinceAnomaly: { [number]: number } = {}

export type Assignment = {
	anomaly: Player?,
	investigators: { Player },
}

function RoleService.Assign(candidates: { Player }): Assignment
	local result: Assignment = { anomaly = nil, investigators = {} }
	if #candidates == 0 then
		return result
	end

	if #candidates == 1 and RunService:IsStudio() and Config.Debug.AllowSoloInStudio then
		local solo = candidates[1]
		if Config.Debug.SoloRole == Enums.Role.Anomaly then
			result.anomaly = solo
		else
			table.insert(result.investigators, solo)
		end
	else
		local total = 0
		local weights: { number } = {}
		for i, player in candidates do
			local w = 1 + (roundsSinceAnomaly[player.UserId] or 0)
			weights[i] = w
			total += w
		end
		local roll = math.random() * total
		local chosen = candidates[#candidates]
		for i, player in candidates do
			roll -= weights[i]
			if roll <= 0 then
				chosen = player
				break
			end
		end
		result.anomaly = chosen
		for _, player in candidates do
			if player ~= chosen and #result.investigators < Config.Round.MaxInvestigators then
				table.insert(result.investigators, player)
			end
		end
	end

	for _, player in candidates do
		if player == result.anomaly then
			roundsSinceAnomaly[player.UserId] = 0
		else
			roundsSinceAnomaly[player.UserId] = (roundsSinceAnomaly[player.UserId] or 0) + 1
		end
	end

	if result.anomaly then
		result.anomaly:SetAttribute("Role", Enums.Role.Anomaly)
		Remotes.Event("RoleAssigned"):FireClient(result.anomaly, Enums.Role.Anomaly)
	end
	for _, player in result.investigators do
		player:SetAttribute("Role", Enums.Role.Investigator)
		Remotes.Event("RoleAssigned"):FireClient(player, Enums.Role.Investigator)
	end
	return result
end

function RoleService.Clear(player: Player)
	player:SetAttribute("Role", Enums.Role.Lobby)
end

function RoleService.Init()
	Players.PlayerRemoving:Connect(function(player)
		roundsSinceAnomaly[player.UserId] = nil
	end)
end

return RoleService
