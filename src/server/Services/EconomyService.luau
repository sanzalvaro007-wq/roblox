--!strict
-- Monedas de Investigación: se ganan jugando (nunca con Robux). Cada premio se apunta
-- en el resumen de la ronda que ve el jugador al final.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local R = ShopCatalog.Rewards

type Line = { reason: string, amount: number }

local EconomyService = {}

local earnings: { [Player]: { Line } } = {}

function EconomyService.Award(player: Player, amount: number, reason: string)
	if amount <= 0 then
		return
	end
	DataService.AddCoins(player, amount)
	local lines = earnings[player]
	if not lines then
		lines = {}
		earnings[player] = lines
	end
	for _, line in lines do
		if line.reason == reason then
			line.amount += amount
			return
		end
	end
	table.insert(lines, { reason = reason, amount = amount })
end

export type RoundSummary = {
	anomaly: Player?,
	investigators: { Player },
	winner: string,
}

function EconomyService.FinishRound(summary: RoundSummary)
	local everyone = table.clone(summary.investigators)
	if summary.anomaly then
		table.insert(everyone, summary.anomaly)
	end
	for _, player in everyone do
		if player.Parent then
			EconomyService.Award(player, R.Participation, "Participación")
			DataService.AddStat(player, "rounds", 1)
		end
	end
	if summary.anomaly and summary.anomaly.Parent and summary.winner == Enums.Winner.Anomaly then
		EconomyService.Award(summary.anomaly, R.AnomalyWin, "Victoria de la Anomalía")
		DataService.AddStat(summary.anomaly, "wins", 1)
	end
	if summary.winner == Enums.Winner.Investigators then
		for _, player in summary.investigators do
			if player.Parent then
				DataService.AddStat(player, "wins", 1)
				if player:GetAttribute("Escaped") ~= true then
					EconomyService.Award(player, R.InvestigatorWin, "Victoria del equipo")
				end
			end
		end
	end
	for _, player in everyone do
		if player.Parent then
			local lines = earnings[player] or {}
			Remotes.Event("RoundEarnings"):FireClient(player, lines)
		end
		earnings[player] = nil
	end
end

function EconomyService.Init()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		earnings[player] = nil
	end)
end

return EconomyService
