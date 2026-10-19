-- Tests del generador de mansión. Ejecutar con el CLI de Luau:
--   luau tests/MansionLayout.spec.luau
-- No usa APIs de Roblox, así que corre fuera de Studio.

local MansionLayout = require("../src/server/Mansion/MansionLayout")

local params = {
	GridWidth = 6,
	GridHeight = 5,
	MinCells = 11,
	MaxCells = 16,
	MinRooms = 8,
	MergeChance = 0.3,
	ExtraDoors = 3,
	MaxAttempts = 10,
}

-- Generador congruencial lineal para tener semillas reproducibles.
local function makeRng(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function nextFloat(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
	return {
		float = nextFloat,
		int = function(min: number, max: number): number
			return min + math.floor(nextFloat() * (max - min + 1))
		end,
	}
end

local failures = 0
local function check(cond: boolean, msg: string)
	if not cond then
		failures += 1
		print("FALLO: " .. msg)
	end
end

-- 1. El layout de respaldo siempre es válido.
do
	local layout = MansionLayout.Fallback(params, makeRng(1))
	local ok, err = MansionLayout.Validate(layout, params)
	check(ok, "fallback inválido: " .. tostring(err))
end

-- 2. Muchas semillas: GenerateSafe siempre devuelve algo válido y casi nunca usa el respaldo.
local fallbacks, totalAttempts, totalRooms, bigRooms = 0, 0, 0, 0
local SEEDS = 2000
for seed = 1, SEEDS do
	local layout, attempts = MansionLayout.GenerateSafe(params, makeRng(seed))
	totalAttempts += attempts
	totalRooms += #layout.rooms
	for _, room in layout.rooms do
		if #room.cells == 2 then
			bigRooms += 1
		end
	end
	if layout.fallback then
		fallbacks += 1
	end
	local ok, err = MansionLayout.Validate(layout, params)
	check(ok, "semilla " .. seed .. " inválida: " .. tostring(err))
end
check(fallbacks / SEEDS < 0.02, "demasiados respaldos: " .. fallbacks)

-- 3. La validación detecta una sala desconectada.
do
	local layout = MansionLayout.Generate(params, makeRng(42))
	local ok = MansionLayout.Validate(layout, params)
	if ok then
		local broken = table.clone(layout)
		broken.doors = {}
		check(not MansionLayout.Validate(broken, params), "no detecta salas desconectadas")
	end
end

-- 4. Semillas distintas dan mansiones distintas.
do
	local a = MansionLayout.GenerateSafe(params, makeRng(7))
	local b = MansionLayout.GenerateSafe(params, makeRng(8))
	local same = #a.rooms == #b.rooms and #a.doors == #b.doors
	if same then
		for i, room in a.rooms do
			local other = b.rooms[i]
			if room.cells[1].x ~= other.cells[1].x or room.cells[1].y ~= other.cells[1].y then
				same = false
				break
			end
		end
	end
	check(not same, "dos semillas generaron la misma mansión")
end

print(string.format(
	"%d semillas | respaldos: %d | intentos medios: %.2f | salas medias: %.1f | salas grandes: %d",
	SEEDS,
	fallbacks,
	totalAttempts / SEEDS,
	totalRooms / SEEDS,
	bigRooms
))
if failures > 0 then
	error(failures .. " tests fallidos")
end
print("OK: todos los tests de MansionLayout pasan")
