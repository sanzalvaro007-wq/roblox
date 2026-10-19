--!strict
-- Números de juego para tunear. Todo lo que afecta al equilibrio vive aquí.

local Config = {}

Config.Round = {
	MinPlayers = 2,
	MaxInvestigators = 7,
	IntermissionTime = 15,
	PrepTime = 15, -- la Anomalía se esconde; los Investigadores esperan a oscuras
	RoundTime = 600, -- 10 minutos
	ResultsTime = 10,
	EscapesToWin = 1, -- con que escape 1 Investigador, ganan los Investigadores
}

-- En Studio se puede probar en solitario con este rol.
Config.Debug = {
	AllowSoloInStudio = true,
	SoloRole = "Investigator", -- "Investigator" o "Anomaly"
}

Config.Anomaly = {
	WalkSpeed = 17,
	MorphedWalkSpeed = 9,
	MorphCooldown = 3,
	AttackRange = 8,
	AttackCooldown = 2.5,
	AttackDamage = 45,
	AmbushMinMorphTime = 2, -- segundos transformada para que el ataque sea emboscada
	AmbushDamage = 100,
	PhotoStunTime = 2.5,
	PhotoStunTimeUnmorphed = 1.25,
	PhotoRevealTime = 4,
	PhotoImmunityTime = 6, -- tras un flash no se la puede volver a aturdir enseguida
}

Config.Investigator = {
	WalkSpeed = 13,
	SprintSpeed = 20,
	StaminaMax = 100,
	StaminaDrain = 22, -- por segundo corriendo
	StaminaRegen = 12,
	StaminaMinToSprint = 15,
	BatteryMax = 100,
	BatteryDrain = 1.25, -- por segundo con la linterna encendida (80 s)
	BatteryPickupAmount = 50,
	Film = 6,
	PhotoCooldown = 3,
	PhotoRange = 40,
	PhotoConeDegrees = 32,
	EmfRange = 45,
	EmfInterval = 0.4,
	-- Umbrales de distancia para cada nivel del EMF (5 = muy cerca).
	EmfLevels = { 8, 15, 25, 35, 45 },
}

Config.Sanity = {
	Max = 100,
	TickInterval = 0.5,
	DarkDrain = 0.9, -- por segundo sin luz cerca
	AloneDrain = 0.6, -- por segundo sin compañeros cerca
	AloneRadius = 20,
	NearAnomalyRadius = 16,
	NearAnomalyDrain = 1.5,
	GroupRegen = 1.2,
	LightRegen = 0.6,
	WitnessKillRadius = 35,
	WitnessKillLoss = 25,
	AttackedLoss = 15,
	-- Umbrales para alucinaciones en el cliente.
	Mild = 60,
	Strong = 35,
	Severe = 15,
}

Config.Objectives = {
	FusesBase = 3,
	FusesPerInvestigators = 3, -- +1 fusible por cada 3 Investigadores
	FusesMax = 6,
	FuseInsertHold = 1.5,
	EscapeHold = 2,
	BatteryPickups = 5,
	LampRadiusPowerOff = 8,
	LampRadiusPowerOn = 18,
}

Config.Mansion = {
	Origin = Vector3.new(0, 100, 0), -- elevada para no chocar con la Baseplate de la plantilla
	GridWidth = 6,
	GridHeight = 5,
	CellSize = 36,
	WallHeight = 14,
	WallThickness = 1,
	DoorWidth = 7,
	DoorHeight = 9,
	MinCells = 11,
	MaxCells = 16,
	MinRooms = 8,
	MergeChance = 0.3, -- probabilidad de fusionar dos celdas en una sala grande
	ExtraDoors = 3, -- puertas extra sobre el árbol para crear bucles
	MaxAttempts = 10,
	PropsPerCell = { 2, 4 },
}

Config.Lobby = {
	Position = Vector3.new(0, 100, -400),
	Size = Vector3.new(80, 1, 80),
}

-- Sonidos de prueba que vienen con el cliente de Roblox. Sustituir por assets propios.
Config.Sounds = {
	Footstep = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Scream = "rbxasset://sounds/uuhhh.mp3",
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Shutter = "rbxasset://sounds/electronicpingshort.wav",
}

return Config
