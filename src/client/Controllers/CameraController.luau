--!strict
-- Kill cam (el susto que se comparte en stream) y modo espectador al morir.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local PropCatalog = require(Shared:WaitForChild("PropCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

local CameraController = {}

local killCamUntil = 0
local spectating = false
local spectateIndex = 1
local spectateLabel: TextLabel

local function spectateTargets(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player
			and p:GetAttribute("Role") == Enums.Role.Investigator
			and p:GetAttribute("Alive") == true
			and p:GetAttribute("Escaped") ~= true
		then
			table.insert(list, p)
		end
	end
	return list
end

local function shouldSpectate(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	return state == Enums.RoundState.Playing
		and player:GetAttribute("Role") == Enums.Role.Investigator
		and player:GetAttribute("Alive") ~= true
		and player:GetAttribute("Ghost") ~= true
end

local function cycle(actionName: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or not spectating then
		return Enum.ContextActionResult.Pass
	end
	spectateIndex += if actionName == "MM_SpectatePrev" then -1 else 1
	return Enum.ContextActionResult.Sink
end

local function playKillCam(killer: any, propId: any)
	killCamUntil = os.clock() + 2.6
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	local from = if head and head:IsA("BasePart") then head.Position else camera.CFrame.Position
	local killerRoot = if typeof(killer) == "Instance" and killer:IsA("Model") then killer:FindFirstChild("HumanoidRootPart") else nil
	local target = if killerRoot and killerRoot:IsA("BasePart") then killerRoot.Position else from + camera.CFrame.LookVector * 5

	UIController.Flash(Color3.fromRGB(160, 0, 0), 1.2, 0)
	local def = if typeof(propId) == "string" then PropCatalog.Get(propId) else nil
	UIController.Splash(if def then ("Devorado por: " .. def.name) else "Te ha atrapado", Color3.fromRGB(240, 70, 60))

	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds.Scream
	sound.Volume = 1
	sound.Parent = camera
	sound:Play()
	task.delay(4, function()
		sound:Destroy()
	end)

	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if os.clock() >= killCamUntil then
			conn:Disconnect()
			return
		end
		-- Tirón hacia el atacante con temblor.
		local pull = math.min(1, t / 0.4) * 0.6
		local pos = from:Lerp(target, pull * 0.5)
		local shake = Vector3.new(math.noise(t * 20, 0, 0), math.noise(0, t * 20, 0), 0) * (0.5 * (1 - t / 2.6))
		camera.CFrame = CFrame.lookAt(pos + shake, target + Vector3.new(0, 1.5, 0))
	end)
end

local function update()
	if os.clock() < killCamUntil then
		spectateLabel.Visible = false
		return
	end
	local camera = workspace.CurrentCamera
	if shouldSpectate() then
		local targets = spectateTargets()
		if #targets > 0 then
			spectating = true
			spectateIndex = ((spectateIndex - 1) % #targets) + 1
			local target = targets[spectateIndex]
			local humanoid = if target.Character then target.Character:FindFirstChildOfClass("Humanoid") else nil
			camera.CameraType = Enum.CameraType.Custom
			if humanoid and camera.CameraSubject ~= humanoid then
				camera.CameraSubject = humanoid
			end
			spectateLabel.Text = string.format("Has sido eliminado · Espectando a %s  (← / →)", target.DisplayName)
			spectateLabel.Visible = true
			return
		end
	end
	if spectating or camera.CameraType == Enum.CameraType.Scriptable then
		spectating = false
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	spectateLabel.Visible = false
end

function CameraController.Start()
	spectateLabel = UIController.Label({
		Name = "Spectate",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 700, 0, 30),
		TextSize = 20,
		Visible = false,
		Parent = UIController.Gui(),
	})
	ContextActionService:BindAction("MM_SpectatePrev", cycle, false, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("MM_SpectateNext", cycle, false, Enum.KeyCode.Right, Enum.KeyCode.DPadRight)

	Remotes.Event("KillCam").OnClientEvent:Connect(playKillCam)
	player.CharacterAdded:Connect(function(character)
		killCamUntil = 0
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			camera.CameraSubject = humanoid :: Humanoid
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return CameraController
