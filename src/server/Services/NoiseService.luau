--!strict
-- Ruido de los Investigadores: pasos (servidor), gritos/emotes (sin voz) y volumen del
-- micro (con voz). La Anomalía recibe "pings" con una posición APROXIMADA, nunca exacta.
-- Jugar sin voz no es desventaja: el sigilo (andar despacio) es casi silencioso y los
-- gritos sirven para coordinarse a costa de hacer mucho ruido.
--
-- Nota anti-exploit: el volumen del micro lo informa el propio cliente. Mentir (decir 0)
-- solo equivale a silenciar el micro, así que no da ventaja real sobre jugar sin voz.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Guard = require(Util:WaitForChild("Guard"))
local PlayerUtil = require(Util:WaitForChild("PlayerUtil"))
local ToolService = require(script.Parent:WaitForChild("ToolService"))

local N = Config.Noise

local NoiseService = {}

type VoiceSample = { level: number, at: number }

local voice: { [Player]: VoiceSample } = {}
local emoteUntil: { [Player]: number } = {}
local lastEmote: { [Player]: number } = {}
local lastPing: { [Player]: number } = {}

function NoiseService.NoiseOf(player: Player): number
	local now = os.clock()
	local level = ToolService.MovementNoise(player)
	local sample = voice[player]
	if sample and now - sample.at <= N.VoiceHold then
		level = math.max(level, math.min(1, sample.level * N.VoiceGain))
	end
	if (emoteUntil[player] or 0) > now then
		level = math.max(level, N.EmoteNoise)
	end
	return level
end

local function showShout(player: Player, text: string)
	local head = PlayerUtil.Head(player)
	if not head then
		return
	end
	local existing = head:FindFirstChild("Shout")
	if existing then
		existing:Destroy()
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Shout"
	billboard.Size = UDim2.fromOffset(220, 50)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = N.EmoteHearRange
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.SpecialElite
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 200)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard
	billboard.Parent = head
	task.delay(N.EmoteDuration + 0.5, function()
		billboard:Destroy()
	end)
end

local function onEmote(player: Player, kind: any)
	if typeof(kind) ~= "string" or not Guard.RateLimit(player, "Emote", 0.3) then
		return
	end
	local text = (Config.Emotes :: { [string]: string })[kind]
	if not text or not PlayerUtil.IsInvestigator(player) then
		return
	end
	local state = ReplicatedStorage:GetAttribute("RoundState")
	if state ~= Enums.RoundState.Playing and state ~= Enums.RoundState.Preparing then
		return
	end
	local now = os.clock()
	if lastEmote[player] and now - lastEmote[player] < N.EmoteCooldown then
		return
	end
	lastEmote[player] = now
	emoteUntil[player] = now + N.EmoteDuration
	showShout(player, text)
	lastPing[player] = nil -- un grito siempre se oye
end

local function tick()
	if ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
		return
	end
	local anomaly = PlayerUtil.Anomaly()
	local anomalyRoot = if anomaly then PlayerUtil.Root(anomaly) else nil
	local now = os.clock()
	for _, player in PlayerUtil.Investigators() do
		local noise = NoiseService.NoiseOf(player)
		-- Redondeado para no replicar cada pequeña variación.
		player:SetAttribute("Noise", math.floor(noise * 20 + 0.5) / 20)
		local root = PlayerUtil.Root(player)
		if anomaly and anomalyRoot and root and noise >= N.MinToPing then
			local dist = (root.Position - anomalyRoot.Position).Magnitude
			local ready = lastPing[player] == nil or now - lastPing[player] >= N.PingCooldown
			if dist <= noise * N.MaxRange and ready then
				lastPing[player] = now
				local jitter = N.JitterBase + dist * N.JitterPerStud
				local angle = math.random() * math.pi * 2
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (math.random() * jitter)
				Remotes.Event("NoisePing"):FireClient(anomaly, root.Position + offset, noise)
			end
		end
	end
end

function NoiseService.Reset(player: Player)
	voice[player] = nil
	emoteUntil[player] = nil
	lastEmote[player] = nil
	lastPing[player] = nil
	player:SetAttribute("Noise", nil)
end

function NoiseService.Init()
	Remotes.Unreliable("VoiceLevel").OnServerEvent:Connect(function(player, level)
		if typeof(level) ~= "number" or level ~= level or not Guard.RateLimit(player, "Voice", 0.1) then
			return
		end
		voice[player] = { level = math.clamp(level, 0, 1), at = os.clock() }
	end)
	Remotes.Event("RequestEmote").OnServerEvent:Connect(onEmote)
	Players.PlayerRemoving:Connect(NoiseService.Reset)
	task.spawn(function()
		while true do
			task.wait(N.TickInterval)
			tick()
		end
	end)
end

return NoiseService
