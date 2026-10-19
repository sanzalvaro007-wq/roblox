--!strict
-- Accesos rápidos al estado de cada jugador. El estado público vive en atributos
-- del Player (replican a todos): Role, Alive, Escaped, Sanity, Battery, Film, Stamina...

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local PlayerUtil = {}

function PlayerUtil.Role(player: Player): string
	local role = player:GetAttribute("Role")
	return if typeof(role) == "string" then role else Enums.Role.Lobby
end

function PlayerUtil.Humanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function PlayerUtil.Root(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function PlayerUtil.Head(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- Vivo y dentro de la partida (no escapado ni eliminado).
function PlayerUtil.InPlay(player: Player): boolean
	if player:GetAttribute("Alive") ~= true or player:GetAttribute("Escaped") == true then
		return false
	end
	local humanoid = PlayerUtil.Humanoid(player)
	return humanoid ~= nil and humanoid.Health > 0
end

function PlayerUtil.IsInvestigator(player: Player): boolean
	return PlayerUtil.Role(player) == Enums.Role.Investigator and PlayerUtil.InPlay(player)
end

function PlayerUtil.IsAnomaly(player: Player): boolean
	return PlayerUtil.Role(player) == Enums.Role.Anomaly and PlayerUtil.InPlay(player)
end

function PlayerUtil.Investigators(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if PlayerUtil.IsInvestigator(p) then
			table.insert(list, p)
		end
	end
	return list
end

function PlayerUtil.Anomaly(): Player?
	for _, p in Players:GetPlayers() do
		if PlayerUtil.IsAnomaly(p) then
			return p
		end
	end
	return nil
end

return PlayerUtil
