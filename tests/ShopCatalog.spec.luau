-- Tests de la tienda y del gacha (sin APIs de Roblox):
--   luau tests/ShopCatalog.spec.luau

local ShopCatalog = require("../src/shared/ShopCatalog")

local failures = 0
local function check(cond: boolean, msg: string)
	if not cond then
		failures += 1
		print("FALLO: " .. msg)
	end
end

-- Las probabilidades publicadas suman 100% (con redondeo a una décima).
local odds = ShopCatalog.GachaOdds()
local sum = 0
for _, p in odds do
	sum += p
end
check(math.abs(sum - 100) < 0.2, "las probabilidades suman " .. sum)

-- Simulación: la frecuencia real coincide con la publicada (±1.5 puntos).
local counts: { [string]: number } = {}
local total = 0
for _, entry in ShopCatalog.Gacha.pool do
	total += entry.weight
end
local N = 200000
for _ = 1, N do
	local pick = math.random() * total
	local form = ShopCatalog.Gacha.pool[#ShopCatalog.Gacha.pool].form
	for _, entry in ShopCatalog.Gacha.pool do
		pick -= entry.weight
		if pick <= 0 then
			form = entry.form
			break
		end
	end
	counts[form] = (counts[form] or 0) + 1
end
for form, p in odds do
	local real = (counts[form] or 0) / N * 100
	check(math.abs(real - p) < 1.5, string.format("%s: publicado %.1f%%, real %.1f%%", form, p, real))
end

-- Artículos con id único, precio positivo y hueco coherente.
local seen = {}
for _, item in ShopCatalog.Items do
	check(not seen[item.id], "id repetido " .. item.id)
	seen[item.id] = true
	check(item.price > 0, "precio inválido " .. item.id)
	if item.category == "Flashlight" then
		check(ShopCatalog.Flashlights[item.id] ~= nil, "linterna sin variante " .. item.id)
	end
end

-- Las monedas no se venden: el gacha no es un "paid random item".
check(ShopCatalog.Monetization.CoinsPurchasable == false, "si se venden monedas, revisar políticas del gacha")

if failures > 0 then
	error(failures .. " tests fallidos")
end
print("OK: tests de ShopCatalog pasan")
