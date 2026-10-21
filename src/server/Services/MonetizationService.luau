--!strict
-- Robux: gamepasses (VIP, Pack Fundador, Luz UV Pro) y DevProducts (Revive Token y bolsas
-- de monedas). Los ids viven en ShopCatalog.Monetization; con id 0 la opción está desactivada.
-- Cada gamepass se refleja en un atributo del jugador con su clave (p. ej. "VIP" = true).
-- ProcessReceipt solo devuelve PurchaseGranted cuando la compra está GUARDADA.

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

local function checkPasses(player: Player)
	for _, pass in M.GamePasses do
		if pass.id == 0 then
			player:SetAttribute(pass.key, false)
			continue
		end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		player:SetAttribute(pass.key, ok and owns == true)
	end
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
	local product = ShopCatalog.ProductById(receipt.ProductId)
	if not product then
		warn("[Monetization] producto desconocido", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local coins = product.coins or 0
	if product.key == "Revive" then
		data.consumables.Revive = (data.consumables.Revive or 0) + 1
	else
		data.coins += coins
	end
	DataService.AddReceipt(player, receiptId)
	if not DataService.SaveNow(player) then
		-- Deshacer en memoria; se reintentará.
		if product.key == "Revive" then
			data.consumables.Revive -= 1
		else
			data.coins -= coins
		end
		table.remove(data.receipts, #data.receipts)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.Sync(player)
	local message = if product.key == "Revive" then "Revive Token añadido" else string.format("+%d monedas", coins)
	Remotes.Event("Notify"):FireClient(player, message, "success")
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
	Players.PlayerAdded:Connect(checkPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPasses, player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased or passId == 0 then
			return
		end
		for _, pass in M.GamePasses do
			if pass.id == passId then
				player:SetAttribute(pass.key, true)
				Remotes.Event("Notify"):FireClient(player, "¡Gracias! Ya tienes " .. pass.name, "success")
			end
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
