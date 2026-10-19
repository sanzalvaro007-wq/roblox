--!strict
-- Registro único de remotes. El servidor los crea; el cliente los espera.
-- Regla: el cliente solo PIDE cosas. El servidor valida todo (rol, vivo, cooldown, distancia).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- Cliente -> Servidor
	"RequestMorph", -- (propId: string)
	"RequestUnmorph", -- ()
	"RequestAttack", -- ()
	"ToggleFlashlight", -- (on: boolean)
	"EquipTool", -- (tool: string)
	"TakePhoto", -- (lookVector: Vector3)
	"RequestSprint", -- (on: boolean)
	"RequestSneak", -- (on: boolean)
	"RequestEmote", -- (kind: string) gritos para quien juega sin voz
	"GhostAction", -- (kind: "Light" | "Whisper")

	-- Servidor -> Cliente
	"Notify", -- (text: string, kind: string?)
	"MorphState", -- (propId: string?) solo a la Anomalía
	"PhotoResult", -- (hit: boolean)
	"EmfReading", -- (level: number) solo al dueño del EMF
	"KillCam", -- (killerCharacter: Model?, propId: string?)
	"Scare", -- (intensity: number)
	"RoundResult", -- (result: table)
	"RoleAssigned", -- (role: string)
	"NoisePing", -- (approxPosition: Vector3, intensity: number) solo a la Anomalía
}

-- Mensajes frecuentes donde perder alguno no importa.
local UNRELIABLE = {
	"VoiceLevel", -- (level: number) cliente -> servidor, volumen del propio micro
}

local Remotes = {}

local folder: Folder? = nil
local known: { [string]: boolean } = {}
for _, name in EVENTS do
	known[name] = true
end
for _, name in UNRELIABLE do
	known[name] = true
end

local function getFolder(): Folder
	if folder then
		return folder
	end
	local f: Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing and existing:IsA("Folder") then
			f = existing
		else
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		end
		for _, name in EVENTS do
			if not f:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = f
			end
		end
		for _, name in UNRELIABLE do
			if not f:FindFirstChild(name) then
				local remote = Instance.new("UnreliableRemoteEvent")
				remote.Name = name
				remote.Parent = f
			end
		end
	else
		f = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	folder = f
	return f
end

function Remotes.Event(name: string): RemoteEvent
	assert(known[name], "Remote desconocido: " .. name)
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

function Remotes.Unreliable(name: string): UnreliableRemoteEvent
	assert(known[name], "Remote desconocido: " .. name)
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: UnreliableRemoteEvent
	end
	return f:WaitForChild(name) :: UnreliableRemoteEvent
end

return Remotes
