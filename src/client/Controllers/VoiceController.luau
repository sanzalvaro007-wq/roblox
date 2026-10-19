--!strict
-- Voz posicional (extra opcional). Roblox ya hace la voz espacial con la Audio API
-- (activada en default.project.json). Aquí solo medimos el volumen del PROPIO micro y
-- se lo enviamos al servidor, que lo convierte en "ruido" que la Anomalía percibe.
-- Sin voz (menores, sin verificar o micro apagado) no se envía nada y el juego es igual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoiceChatService = game:GetService("VoiceChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local VoiceController = {}

VoiceController.Available = false
VoiceController.Level = 0

local function findInput(): AudioDeviceInput?
	local existing = player:FindFirstChildOfClass("AudioDeviceInput")
	if existing then
		return existing
	end
	local found: AudioDeviceInput? = nil
	local conn = player.ChildAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			found = child
		end
	end)
	local deadline = os.clock() + 20
	while not found and os.clock() < deadline do
		task.wait(0.5)
	end
	conn:Disconnect()
	return found
end

local function inRound(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	return player:GetAttribute("Role") == Enums.Role.Investigator
		and player:GetAttribute("Alive") == true
		and state == Enums.RoundState.Playing
end

function VoiceController.Start()
	task.spawn(function()
		local ok, enabled = pcall(function()
			return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
		end)
		if not ok or not enabled then
			return
		end
		local input = findInput()
		if not input then
			return
		end
		local analyzer = Instance.new("AudioAnalyzer")
		analyzer.Name = "MicLevel"
		analyzer.Parent = input
		local wire = Instance.new("Wire")
		wire.SourceInstance = input
		wire.TargetInstance = analyzer
		wire.Parent = analyzer
		VoiceController.Available = true

		local remote = Remotes.Unreliable("VoiceLevel")
		local lastSent = 0
		local lastSentAt = 0
		while true do
			task.wait(0.2)
			local level = if input.Muted then 0 else analyzer.RmsLevel
			VoiceController.Level = level
			if inRound() then
				-- Solo se envía si cambia o, mientras hablas, como latido cada segundo.
				local changed = math.abs(level - lastSent) > 0.03
				local speaking = level > 0.02 and os.clock() - lastSentAt > 1
				if changed or speaking then
					remote:FireServer(level)
					lastSent = level
					lastSentAt = os.clock()
				end
			end
		end
	end)
end

return VoiceController
