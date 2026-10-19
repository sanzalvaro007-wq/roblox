--!strict
-- Robux: gamepass "Luz UV Pro" y DevProduct "Revive Token" (1 uso por partida).
-- Los ids viven en ShopCatalog.Monetization; con id 0 la opción está desactivada.
-- ProcessReceipt solo devuelve PurchaseGranted cuando el token está GUARDADO.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))

local Guard = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Guard"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))

local M = ShopCatalog.Monetization

local MonetizationService = {}

local revivedThisRound: { [Player]: boolean } = {}

local function checkUvPro(player: Player)
	if M.UVProGamepassId == 0 then
		player:SetAttribute("UVPro", false)
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, M.UVProGamepassId)
	end)
	player:SetAttribute("UVPro", ok and owns == true)
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.WaitFor(player, 15)
	if not data or not DataService.IsPersistent(player) then
		-- Sin guardado fiable no concedemos: Roblox reintentará más tarde.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receipt.PurchaseId)
	if DataService.HasReceipt(player, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if receipt.ProductId == M.ReviveProductId and M.ReviveProductId ~= 0 then
		data.consumables.Revive = (data.consumables.Revive or 0) + 1
	else
		warn("[Monetization] producto desconocido", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.AddReceipt(player, receiptId)
	if not DataService.SaveNow(player) then
		-- Deshacer en memoria; se reintentará.
		data.consumables.Revive -= 1
		table.remove(data.receipts, #data.receipts)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.Sync(player)
	Remotes.Event("Notify"):FireClient(player, "Revive Token añadido", "success")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function useRevive(player: Player)
	if ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
		return
	end
	if player:GetAttribute("Ghost") ~= true or revivedThisRound[player] then
		if revivedThisRound[player] then
			Remotes.Event("Notify"):FireClient(player, "Solo puedes revivir una vez por partida", "warn")
		end
		return
	end
	local data = DataService.Get(player)
	if not data or (data.consumables.Revive or 0) <= 0 then
		Remotes.Event("Notify"):FireClient(player, "No tienes Revive Tokens", "warn")
		return
	end
	if RoundService.Revive(player) then
		data.consumables.Revive -= 1
		revivedThisRound[player] = true
		DataService.Sync(player)
	end
end

function MonetizationService.ResetRound()
	revivedThisRound = {}
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerAdded:Connect(checkUvPro)
	for _, player in Players:GetPlayers() do
		task.spawn(checkUvPro, player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == M.UVProGamepassId then
			player:SetAttribute("UVPro", true)
		end
	end)
	Remotes.Event("UseRevive").OnServerEvent:Connect(function(player)
		if Guard.RateLimit(player, "Revive", 1) then
			useRevive(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		revivedThisRound[player] = nil
	end)
	RoundService.OnRoundEnded(MonetizationService.ResetRound)
end

return MonetizationService
