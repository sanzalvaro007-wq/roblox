-- Punto de entrada del servidor: carga los servicios en orden y los arranca.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crea los remotes antes de que cualquier cliente los espere.
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
Remotes.Event("Notify")

local Services = script:WaitForChild("Services")

local ORDER = {
	"AtmosphereService",
	"CharacterService",
	"MansionService",
	"RoleService",
	"MorphService",
	"SanityService",
	"CombatService",
	"ToolService",
	"ObjectiveService",
	"RoundService",
}

local loaded = {}
for _, name in ORDER do
	local module = require(Services:WaitForChild(name)) :: any
	loaded[name] = module
	if type(module.Init) == "function" then
		module.Init()
	end
end
for _, name in ORDER do
	local module = loaded[name]
	if type(module.Start) == "function" then
		task.spawn(module.Start)
	end
end

print("[Mimic Manor] servidor iniciado")
