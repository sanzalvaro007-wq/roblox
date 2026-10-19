--!strict
-- Tienda y gacha. Todo se valida aquí: precio, saldo, propiedad y hueco de equipo.
-- El gacha usa probabilidades públicas (ShopCatalog.GachaOdds) que la UI muestra siempre
-- antes de tirar, y devuelve monedas si sale una forma repetida.

local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropCatalog = require(Shared:WaitForChild("PropCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))

local Guard = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Guard"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local ShopService = {}

local function reply(player: Player, ok: boolean, message: string)
	Remotes.Event("ShopResult"):FireClient(player, ok, message)
end

-- Solo hace falta si las monedas se pudieran comprar con Robux (hoy no).
local function randomItemsBlocked(player: Player): boolean
	if not ShopCatalog.Monetization.CoinsPurchasable then
		return false
	end
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	-- Ante la duda (error), bloqueamos.
	return not ok or (info :: any).ArePaidRandomItemsRestricted == true
end

local function purchase(player: Player, itemId: string)
	local item = ShopCatalog.ById[itemId]
	local data = DataService.Get(player)
	if not item or not data then
		return
	end
	if not item.consumable and data.owned[itemId] then
		reply(player, false, "Ya lo tienes")
		return
	end
	if not DataService.Spend(player, item.price) then
		reply(player, false, "No tienes monedas suficientes")
		return
	end
	if item.consumable then
		data.consumables[itemId] = (data.consumables[itemId] or 0) + 1
	else
		data.owned[itemId] = true
		if item.slot then
			data.equipped[item.slot] = itemId
		end
	end
	DataService.Sync(player)
	reply(player, true, "Has comprado: " .. item.name)
end

local function equip(player: Player, slot: string, itemId: string)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if slot ~= "Flashlight" and slot ~= "EMF" then
		return
	end
	if itemId ~= "Default" then
		local item = ShopCatalog.ById[itemId]
		if not item or item.slot ~= slot or not data.owned[itemId] then
			return
		end
	end
	data.equipped[slot] = itemId
	DataService.Sync(player)
	reply(player, true, "Equipado")
end

local function roll(player: Player)
	local gacha = ShopCatalog.Gacha
	local data = DataService.Get(player)
	if not data then
		return
	end
	if randomItemsBlocked(player) then
		reply(player, false, "El cofre no está disponible en tu región")
		return
	end
	if not DataService.Spend(player, gacha.price) then
		reply(player, false, "No tienes monedas suficientes")
		return
	end
	local total = 0
	for _, entry in gacha.pool do
		total += entry.weight
	end
	local pick = math.random() * total
	local form = gacha.pool[#gacha.pool].form
	for _, entry in gacha.pool do
		pick -= entry.weight
		if pick <= 0 then
			form = entry.form
			break
		end
	end
	local key = "Form_" .. form
	local duplicate = data.owned[key] == true
	if duplicate then
		data.coins += gacha.duplicateRefund
	else
		data.owned[key] = true
	end
	DataService.Sync(player)
	Remotes.Event("GachaResult"):FireClient(player, form, duplicate, if duplicate then gacha.duplicateRefund else 0)
end

-- Formas cosméticas: libres las normales; las del gacha, solo si se poseen.
function ShopService.CanUseForm(player: Player, propId: string): boolean
	local def = PropCatalog.Get(propId)
	if not def then
		return false
	end
	if not def.cosmetic then
		return true
	end
	return DataService.Owns(player, "Form_" .. propId)
end

function ShopService.Init()
	Remotes.Event("ShopPurchase").OnServerEvent:Connect(function(player, itemId)
		if typeof(itemId) == "string" and Guard.RateLimit(player, "Shop", 0.5) then
			purchase(player, itemId)
		end
	end)
	Remotes.Event("ShopEquip").OnServerEvent:Connect(function(player, slot, itemId)
		if typeof(slot) == "string" and typeof(itemId) == "string" and Guard.RateLimit(player, "ShopEquip", 0.3) then
			equip(player, slot, itemId)
		end
	end)
	Remotes.Event("GachaRoll").OnServerEvent:Connect(function(player)
		if Guard.RateLimit(player, "Gacha", 1) then
			roll(player)
		end
	end)
end

return ShopService
