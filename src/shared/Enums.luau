--!strict
-- Valores compartidos entre servidor y cliente.

local Enums = {}

Enums.Role = {
	Lobby = "Lobby",
	Investigator = "Investigator",
	Anomaly = "Anomaly",
}

Enums.RoundState = {
	Waiting = "Waiting",
	Intermission = "Intermission",
	Preparing = "Preparing",
	Playing = "Playing",
	Results = "Results",
}

Enums.Tool = {
	None = "None",
	Camera = "Camera",
	EMF = "EMF",
	UV = "UV",
}

Enums.Winner = {
	Investigators = "Investigators",
	Anomaly = "Anomaly",
	None = "None",
}

-- Textos para la UI.
Enums.RoleName = {
	Lobby = "Espectador",
	Investigator = "Investigador",
	Anomaly = "Anomalía",
}

Enums.StateName = {
	Waiting = "Esperando jugadores",
	Intermission = "La mansión despierta en",
	Preparing = "La Anomalía se esconde",
	Playing = "Investigación",
	Results = "Resultados",
}

return Enums
