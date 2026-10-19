--!strict
-- Fantasmas en el cliente: los vivos no los ven ni oyen sus pasos; los fantasmas se ven
-- entre sí translúcidos. Controles del fantasma: Z lámpara, X susurro.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

local GhostController = {}

local bound = false
local tint: ColorCorrectionEffect
local hint: TextLabel

local function localIsGhost(): boolean
	return player:GetAttribute("Ghost") == true
		and ReplicatedStorage:GetAttribute("RoundState") == Enums.RoundState.Playing
end

local function handle(actionName: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or not localIsGhost() then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "MM_GhostRevive" then
		Remotes.Event("UseRevive"):FireServer()
	else
		Remotes.Event("GhostAction"):FireServer(if actionName == "MM_GhostLight" then "Light" else "Whisper")
	end
	return Enum.ContextActionResult.Sink
end

local function refresh()
	if localIsGhost() and not bound then
		bound = true
		ContextActionService:BindAction("MM_GhostLight", handle, true, Enum.KeyCode.Z, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle("MM_GhostLight", "Luz")
		ContextActionService:SetPosition("MM_GhostLight", UDim2.new(1, -170, 1, -150))
		ContextActionService:BindAction("MM_GhostWhisper", handle, true, Enum.KeyCode.X, Enum.KeyCode.ButtonY)
		ContextActionService:SetTitle("MM_GhostWhisper", "Susurro")
		ContextActionService:SetPosition("MM_GhostWhisper", UDim2.new(1, -110, 1, -150))
		ContextActionService:BindAction("MM_GhostRevive", handle, false, Enum.KeyCode.R)
		ProximityPromptService.Enabled = false
	elseif not localIsGhost() and bound then
		bound = false
		ContextActionService:UnbindAction("MM_GhostLight")
		ContextActionService:UnbindAction("MM_GhostWhisper")
		ContextActionService:UnbindAction("MM_GhostRevive")
		ProximityPromptService.Enabled = true
	end
end

local function step()
	local meGhost = localIsGhost()
	tint.Enabled = meGhost
	hint.Visible = meGhost
	for _, p in Players:GetPlayers() do
		local character = p.Character
		if not character then
			continue
		end
		local ghost = p:GetAttribute("Ghost") == true
		local modifier = 0
		if ghost then
			modifier = if meGhost then 0.55 else 1
		end
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = math.max(d.LocalTransparencyModifier, modifier)
			elseif ghost and not meGhost and d:IsA("Sound") then
				d.Volume = 0
			end
		end
	end
end

function GhostController.Start()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "GhostTint"
	tint.TintColor = Color3.fromRGB(190, 210, 255)
	tint.Saturation = -0.6
	tint.Brightness = 0.05
	tint.Enabled = false
	tint.Parent = Lighting
	hint = UIController.Label({
		Name = "GhostHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 700, 0, 30),
		TextSize = 20,
		Text = "Eres un fantasma · Z: lámpara · X: susurro (pista) · R: Revive Token",
		Visible = false,
		Parent = UIController.Gui(),
	})
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)
	player:GetAttributeChangedSignal("Ghost"):Connect(refresh)
	refresh()
	-- Después de la cámara para que nuestro modificador de transparencia gane.
	RunService:BindToRenderStep("MimicGhosts", Enum.RenderPriority.Camera.Value + 1, step)
end

return GhostController
