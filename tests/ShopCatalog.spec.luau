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
		local variant = ShopCatalog.Flashlights[item.id]
		check(variant ~= nil, "linterna sin variante " .. item.id)
		-- El texto de la tienda tiene que decir el ángulo y el alcance de verdad.
		if variant then
			local angle = tonumber(string.match(item.description, "%((%d+)°%)"))
			local range = tonumber(string.match(item.description, "%((%d+) studs%)"))
			check(angle == variant.angle and range == variant.range, "la descripción no cuadra con la variante " .. item.id)
			check(variant.range <= 60, "Roblox no deja luces de más de 60 studs: " .. item.id)
		end
	end
end

-- Cosméticos: ids únicos, hueco válido, color válido y gamepass exclusivo existente.
for _, item in ShopCatalog.Cosmetics do
	check(not seen[item.id], "id repetido " .. item.id)
	seen[item.id] = true
	check(ShopCatalog.ById[item.id] == item, "cosmético sin índice " .. item.id)
	check(item.slot ~= nil and ShopCatalog.DefaultRgb[item.slot :: string] ~= nil, "hueco cosmético inválido " .. item.id)
	check(item.slot ~= nil and table.find(ShopCatalog.Slots, item.slot) ~= nil, "hueco no equipable " .. item.id)
	local rgb = item.rgb
	check(rgb ~= nil and #rgb == 3, "color inválido " .. item.id)
	for _, c in rgb or {} do
		check(c >= 0 and c <= 255, "componente de color fuera de rango " .. item.id)
	end
	if item.exclusive then
		check(item.price == 0, "un exclusivo no se vende con monedas " .. item.id)
		check(ShopCatalog.Pass(item.exclusive) ~= nil, "exclusivo de un gamepass que no existe " .. item.id)
	else
		check(item.price > 0, "precio inválido " .. item.id)
	end
end

-- Robux: claves únicas, precios recomendados y bolsas con monedas.
local keys = {}
for _, pass in ShopCatalog.Monetization.GamePasses do
	check(not keys[pass.key], "clave repetida " .. pass.key)
	keys[pass.key] = true
	check(pass.robux > 0, "precio en Robux inválido " .. pass.key)
end
for _, product in ShopCatalog.Monetization.Products do
	check(not keys[product.key], "clave repetida " .. product.key)
	keys[product.key] = true
	check(product.robux > 0, "precio en Robux inválido " .. product.key)
	check(product.key == "Revive" or (product.coins or 0) > 0, "producto sin efecto " .. product.key)
end
check(ShopCatalog.ProductById(0) == nil, "el id 0 no puede ser un producto")


if failures > 0 then
	error(failures .. " tests fallidos")
end
print("OK: tests de ShopCatalog pasan")
