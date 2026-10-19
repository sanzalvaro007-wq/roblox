--!strict
-- Tienda, gacha y monetización. Economía orgánica, NO pay-to-win:
-- - Las monedas solo se ganan jugando (no se venden por Robux). Por eso el gacha no es
--   un "paid random item"; aun así mostramos las probabilidades siempre.
-- - Las mejoras son pequeñas o laterales (sidegrades), nunca decisivas.
-- - Si algún día se venden monedas, activar CoinsPurchasable y el gacha se bloquea
--   automáticamente donde PolicyService diga ArePaidRandomItemsRestricted.

export type Item = {
	id: string,
	name: string,
	description: string,
	price: number,
	category: string, -- "Flashlight" | "EMF" | "Film" | "Trap" | "Form"
	slot: string?, -- equipable en este hueco
	consumable: boolean?,
}

local ShopCatalog = {}

ShopCatalog.Items = {
	{
		id = "Flashlight_Lantern",
		name = "Farol",
		description = "Haz más ancho (75°) pero más corto (35 studs).",
		price = 400,
		category = "Flashlight",
		slot = "Flashlight",
	},
	{
		id = "Flashlight_Tactical",
		name = "Linterna táctica",
		description = "Haz estrecho (38°) y largo (60 studs). Gasta un 15% más.",
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

ShopCatalog.ById = {} :: { [string]: Item }
for _, item in ShopCatalog.Items do
	ShopCatalog.ById[item.id] = item
end

-- Variantes de linterna (la de serie es "Default").
ShopCatalog.Flashlights = {
	Default = { angle = 55, range = 45, drain = 1 },
	Flashlight_Lantern = { angle = 75, range = 35, drain = 1 },
	Flashlight_Tactical = { angle = 38, range = 60, drain = 1.15 },
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
ShopCatalog.Monetization = {
	CoinsPurchasable = false,
	UVProGamepassId = 0,
	ReviveProductId = 0,
}

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
