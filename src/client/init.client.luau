-- Punto de entrada del cliente: carga los controladores y los arranca.

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"ProfileController",
	"UIController",
	"AmbienceController",
	"DoorController",
	"InvestigatorController",
	"AnomalyController",
	"SanityController",
	"CameraController",
	"VoiceController",
	"GhostController",
	"ShopController",
	"WaypointController",
	"HelpController",
}

local loaded = {}
for _, name in ORDER do
	local module = require(Controllers:WaitForChild(name)) :: any
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

print("[Escape the Monster] cliente iniciado")
