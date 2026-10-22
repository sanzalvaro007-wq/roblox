-- Config compartida entre servidor y cliente: precios, fórmulas y formato de números.
local Config = {}

Config.DATASTORE_NAME = "SellThePoop_v1"
Config.MAX_CLICKS_PER_SECOND = 15
Config.OFFLINE_MAX_SECONDS = 24 * 60 * 60 -- se gana el 100% offline, hasta 24 h
Config.AUTOSAVE_SECONDS = 60

Config.BASE_POOP_VALUE = 1 -- $ por caca

-- Mejoras con niveles. cost = base * growth ^ nivel
Config.Upgrades = {
	{ id = "Click", name = "💪 Intestino Fuerte", desc = "+1 caca por click", base = 10, growth = 1.5 },
	{ id = "Value", name = "✨ Caca Premium", desc = "+25% precio de venta", base = 25, growth = 1.6 },
	{ id = "Auto", name = "🚽 Váter Automático", desc = "+2 cacas por segundo", base = 50, growth = 1.45 },
}

-- Mejoras de un solo uso
Config.OneTime = {
	{ id = "Truck", name = "🚚 Camión de Caca", desc = "Vende automáticamente cada segundo", cost = 5000 },
}

-- Rebirth ("Laxante Cósmico"): reinicia dinero, caca y mejoras a cambio de un multiplicador permanente
Config.REBIRTH_BASE_COST = 100000
Config.REBIRTH_COST_GROWTH = 4

-- Tratos del comprador misterioso
Config.DEAL_MIN_INTERVAL = 60
Config.DEAL_MAX_INTERVAL = 120
Config.DEAL_ACCEPT_WINDOW = 15 -- segundos para aceptar
Config.DEAL_DURATION = 30 -- segundos que dura el bonus
Config.DEAL_MIN_MULT = 2
Config.DEAL_MAX_MULT = 5

function Config.newData()
	return {
		Cash = 0,
		Poop = 0,
		Rebirths = 0,
		Levels = { Click = 0, Value = 0, Auto = 0 },
		Owned = {},
		LastOnline = 0,
	}
end

function Config.getUpgrade(id)
	for _, u in Config.Upgrades do
		if u.id == id then
			return u
		end
	end
	return nil
end

function Config.getOneTime(id)
	for _, u in Config.OneTime do
		if u.id == id then
			return u
		end
	end
	return nil
end

function Config.upgradeCost(id, level)
	local u = Config.getUpgrade(id)
	return math.floor(u.base * u.growth ^ level)
end

function Config.rebirthMult(data)
	return 1 + data.Rebirths
end

function Config.rebirthCost(data)
	return Config.REBIRTH_BASE_COST * Config.REBIRTH_COST_GROWTH ^ data.Rebirths
end

function Config.poopPerClick(data)
	return (1 + data.Levels.Click) * Config.rebirthMult(data)
end

function Config.poopPerSecond(data)
	return data.Levels.Auto * 2 * Config.rebirthMult(data)
end

function Config.poopValue(data)
	return Config.BASE_POOP_VALUE * (1 + 0.25 * data.Levels.Value) * Config.rebirthMult(data)
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Config.format(n)
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	return string.format("%.2f%s", n, SUFFIXES[i])
end

return Config
