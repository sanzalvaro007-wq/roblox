--!strict
-- Genera la mansión de cada ronda. Nunca debe dejar la ronda sin mapa:
-- layout validado -> construcción protegida -> si algo falla, layout seguro.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Mansion = script.Parent.Parent:WaitForChild("Mansion")
local MansionLayout = require(Mansion:WaitForChild("MansionLayout"))
local MansionBuilder = require(Mansion:WaitForChild("MansionBuilder"))

export type Mansion = MansionBuilder.Mansion

local MansionService = {}

local current: Mansion? = nil

local function makeRng(seed: number): MansionLayout.Rng
	local random = Random.new(seed)
	return {
		int = function(min: number, max: number): number
			return random:NextInteger(min, max)
		end,
		float = function(): number
			return random:NextNumber()
		end,
	}
end

function MansionService.Generate(seed: number?): Mansion
	MansionService.Destroy()
	local actualSeed = seed or math.floor(os.clock() * 1000) % 2147483647
	local rng = makeRng(actualSeed)
	local params = Config.Mansion :: any

	local layout, attempts = MansionLayout.GenerateSafe(params, rng)
	local ok, result = pcall(MansionBuilder.Build, layout, rng)
	if not ok then
		warn("[MansionService] fallo al construir la semilla", actualSeed, result, "- uso layout seguro")
		layout = MansionLayout.Fallback(params, rng)
		result = MansionBuilder.Build(layout, rng)
	end
	local mansion = result :: Mansion
	mansion.Model:SetAttribute("Seed", actualSeed)
	mansion.Model.Parent = workspace
	current = mansion
	print(
		string.format(
			"[MansionService] semilla %d: %d salas, %d puertas, %d intento(s)%s",
			actualSeed,
			#layout.rooms,
			#layout.doors,
			attempts,
			if layout.fallback then " (layout seguro)" else ""
		)
	)
	return mansion
end

function MansionService.Get(): Mansion?
	return current
end

function MansionService.Destroy()
	if current then
		current.Model:Destroy()
		current = nil
	end
end

return MansionService
