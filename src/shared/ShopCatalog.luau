--!strict
-- Tienda, gacha y monetización. NO pay-to-win:
-- - Las mejoras son pequeñas o laterales (sidegrades), nunca decisivas.
-- - Los cosméticos solo cambian el aspecto (color), nunca la potencia.
-- - Las monedas se ganan jugando y también se pueden comprar con Robux. Entonces el gacha
--   cuenta como "paid random item": mostramos SIEMPRE las probabilidades y se bloquea
--   donde PolicyService diga ArePaidRandomItemsRestricted (ver CoinsPurchasable).

export type Item = {
	id: string,
	name: string,
	description: string,
	price: number,
	category: string, -- "Flashlight" | "EMF" | "Film" | "Trap" | "Cosmetic"
	slot: string?, -- equipable en este hueco
	consumable: boolean?,
	rgb: { number }?, -- cosméticos de color: {r, g, b} de 0 a 255
	exclusive: string?, -- solo con este gamepass (clave de Monetization.GamePasses)
}

local ShopCatalog = {}

ShopCatalog.Items = {
	{
		id = "Flashlight_Lantern",
		name = "Farol",
		description = "Haz más ancho (70°) pero más corto (36 studs).",
		price = 400,
		category = "Flashlight",
		slot = "Flashlight",
	},
	{
		id = "Flashlight_Tactical",
		name = "Linterna táctica",
		description = "Haz estrecho (32°) y largo (60 studs). Gasta un 15% más.",
		price = 600,
		category = "Flashlight",
		slot = "Flashlight",
	},
	{
		id = "EMF_Pro",
		name = "EMF mejorado",
		description = "Detecta un 15% más lejos y se actualiza más rápido.",
		price = 750,
		category = "EMF",
		slot = "EMF",
	},
	{
		id = "Film_Extra",
		name = "Carrete extra",
		description = "+1 foto por ronda.",
		price = 900,
		category = "Film",
	},
	{
		id = "Trap_Bell",
		name = "Campana trampa",
		description = "Consumible. Colócala con T: suena y revela a la Anomalía si pasa cerca.",
		price = 120,
		category = "Trap",
		consumable = true,
	},
} :: { Item }

-- Cosméticos: color de la linterna del Investigador y de los ojos de la Anomalía.
-- Los colores de linterna son tonos suaves para que se siga viendo igual de bien.
ShopCatalog.Cosmetics = {
	{
		id = "Light_Candle",
		name = "Linterna: Vela",
		description = "Luz anaranjada y cálida. Solo cambia el color.",
		price = 250,
		category = "Cosmetic",
		slot = "LightColor",
		rgb = { 255, 200, 140 },
	},
	{
		id = "Light_Moon",
		name = "Linterna: Luz de luna",
		description = "Luz fría y azulada. Solo cambia el color.",
		price = 350,
		category = "Cosmetic",
		slot = "LightColor",
		rgb = { 200, 220, 255 },
	},
	{
		id = "Light_Wisp",
		name = "Linterna: Fuego fatuo",
		description = "Un verde fantasmal. Solo cambia el color.",
		price = 500,
		category = "Cosmetic",
		slot = "LightColor",
		rgb = { 190, 255, 210 },
	},
	{
		id = "Light_Blood",
		name = "Linterna: Sangre",
		description = "Un rojo pálido inquietante. Solo cambia el color.",
		price = 600,
		category = "Cosmetic",
		slot = "LightColor",
		rgb = { 255, 185, 180 },
	},
	{
		id = "Light_Gold",
		name = "Linterna dorada",
		description = "Exclusiva del Pack Fundador.",
		price = 0,
		category = "Cosmetic",
		slot = "LightColor",
		rgb = { 255, 225, 140 },
		exclusive = "Founder",
	},
	{
		id = "Eyes_Violet",
		name = "Anomalía: Ojos morados",
		description = "Tus ojos brillan en violeta.",
		price = 300,
		category = "Cosmetic",
		slot = "AnomalyEyes",
		rgb = { 170, 60, 255 },
	},
	{
		id = "Eyes_Acid",
		name = "Anomalía: Ojos verde ácido",
		description = "Tus ojos brillan en verde tóxico.",
		price = 300,
		category = "Cosmetic",
		slot = "AnomalyEyes",
		rgb = { 90, 255, 60 },
	},
	{
		id = "Eyes_Ice",
		name = "Anomalía: Ojos de hielo",
		description = "Tus ojos brillan en azul helado.",
		price = 500,
		category = "Cosmetic",
		slot = "AnomalyEyes",
		rgb = { 120, 220, 255 },
	},
	{
		id = "Eyes_Gold",
		name = "Anomalía: Ojos de oro",
		description = "Exclusivos del Pack Fundador.",
		price = 0,
		category = "Cosmetic",
		slot = "AnomalyEyes",
		rgb = { 255, 200, 60 },
		exclusive = "Founder",
	},
} :: { Item }

-- Color de serie de cada hueco cosmético.
ShopCatalog.DefaultRgb = {
	LightColor = { 255, 240, 210 },
	AnomalyEyes = { 255, 30, 30 },
} :: { [string]: { number } }

-- Huecos que el jugador puede equipar.
ShopCatalog.Slots = { "Flashlight", "EMF", "LightColor", "AnomalyEyes" }

ShopCatalog.ById = {} :: { [string]: Item }
for _, list in { ShopCatalog.Items, ShopCatalog.Cosmetics } do
	for _, item in list do
		ShopCatalog.ById[item.id] = item
	end
end

-- Variantes de linterna (la de serie es "Default").
ShopCatalog.Flashlights = {
	-- Roblox limita el alcance de las luces a 60 studs.
	Default = { angle = 45, range = 48, drain = 1 },
	Flashlight_Lantern = { angle = 70, range = 36, drain = 1 },
	Flashlight_Tactical = { angle = 32, range = 60, drain = 1.15 },
}

-- Gacha "Cofre maldito": formas cosméticas de la Anomalía con kill cam propia.
ShopCatalog.Gacha = {
	id = "CursedChest",
	name = "Cofre maldito",
	price = 300,
	duplicateRefund = 120, -- si sale repetida devolvemos monedas
	pool = {
		{ form = "CuckooClock", weight = 55 },
		{ form = "CursedMirror", weight = 33 },
		{ form = "BloodyStatue", weight = 12 },
	},
}

-- Probabilidad en % de cada forma, para mostrarla antes de comprar.
function ShopCatalog.GachaOdds(): { [string]: number }
	local total = 0
	for _, entry in ShopCatalog.Gacha.pool do
		total += entry.weight
	end
	local odds = {}
	for _, entry in ShopCatalog.Gacha.pool do
		odds[entry.form] = math.floor(entry.weight / total * 1000 + 0.5) / 10
	end
	return odds
end

-- Robux. Los ids son 0 hasta crearlos en el Creator Dashboard; con 0 la opción se oculta.
-- `robux` es el precio recomendado (el de verdad se pone al crearlo en Roblox).
export type Pass = { key: string, id: number, name: string, description: string, robux: number }
export type Product = { key: string, id: number, name: string, description: string, robux: number, coins: number? }

ShopCatalog.Monetization = {
	-- Gamepasses: pago único. La clave es también el atributo del jugador (true si lo tiene).
	GamePasses = {
		{
			key = "VIP",
			id = 2044778770,
			name = "VIP",
			description = "+20% de monedas al acabar cada ronda y etiqueta [VIP] en el chat.",
			robux = 149,
		},
		{
			key = "Founder",
			id = 2044958759,
			name = "Pack Fundador",
			description = "Linterna dorada y ojos de oro exclusivos para la Anomalía.",
			robux = 199,
		},
		{
			key = "UVPro",
			id = 2045396754,
			name = "Luz UV Pro",
			description = "La UV revela huellas desde más lejos. Sigue gastando batería.",
			robux = 99,
		},
	} :: { Pass },
	-- Productos: se pueden comprar varias veces.
	Products = {
		{
			key = "Revive",
			id = 0,
			name = "Revive Token",
			description = "Siendo fantasma, R para volver al vestíbulo. Máximo 1 por partida.",
			robux = 25,
		},
		{ key = "Coins500", id = 0, name = "Bolsa de 500 monedas", description = "Para la tienda y el cofre.", robux = 49, coins = 500 },
		{ key = "Coins1500", id = 0, name = "Saco de 1.500 monedas", description = "Para la tienda y el cofre.", robux = 129, coins = 1500 },
		{ key = "Coins4000", id = 0, name = "Cofre de 4.000 monedas", description = "Para la tienda y el cofre.", robux = 299, coins = 4000 },
	} :: { Product },
	VipCoinBonus = 0.2,
}

function ShopCatalog.Pass(key: string): Pass?
	for _, pass in ShopCatalog.Monetization.GamePasses do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

function ShopCatalog.ProductById(id: number): Product?
	if id == 0 then
		return nil
	end
	for _, product in ShopCatalog.Monetization.Products do
		if product.id == id then
			return product
		end
	end
	return nil
end

-- true si alguna bolsa de monedas está a la venta: el gacha pasa a ser "paid random item".
function ShopCatalog.CoinsPurchasable(): boolean
	for _, product in ShopCatalog.Monetization.Products do
		if product.coins and product.id ~= 0 then
			return true
		end
	end
	return false
end

-- Recompensas por ronda.
ShopCatalog.Rewards = {
	Participation = 20,
	Escape = 60,
	Fuse = 10,
	PhotoHit = 15,
	AnomalyKill = 30,
	AnomalyWin = 60,
	InvestigatorWin = 25, -- para los que no escaparon pero su equipo ganó
}

return ShopCatalog
