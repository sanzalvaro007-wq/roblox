--!strict
-- Controles del Investigador (PC, mando y móvil). Solo envía peticiones;
-- el servidor valida batería, carrete, cooldowns y si la foto acierta.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

local InvestigatorController = {}

local bound = false
local sneaking = false
local localLightPart: Part? = nil

local function active(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	return player:GetAttribute("Role") == Enums.Role.Investigator
		and player:GetAttribute("Alive") == true
		and player:GetAttribute("Escaped") ~= true
		and (state == Enums.RoundState.Playing or state == Enums.RoundState.Preparing)
end

local function equip(tool: string)
	local current = player:GetAttribute("EquippedTool")
	Remotes.Event("EquipTool"):FireServer(if current == tool then Enums.Tool.None else tool)
end

local function playSound(id: string, volume: number)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = workspace.CurrentCamera
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		sound:Destroy()
	end)
end

local function takePhoto()
	if player:GetAttribute("EquippedTool") ~= Enums.Tool.Camera then
		return
	end
	local film = player:GetAttribute("Film")
	if typeof(film) ~= "number" or film <= 0 then
		UIController.Toast("No te queda carrete", "warn")
		return
	end
	local camera = workspace.CurrentCamera
	Remotes.Event("TakePhoto"):FireServer(camera.CFrame.LookVector)
	UIController.Flash(Color3.new(1, 1, 1), 0.35, 0.1)
	playSound(Config.Sounds.Shutter, 0.6)
end

local function handle(actionName: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if not active() then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "MM_Sprint" then
		if inputState == Enum.UserInputState.Begin then
			Remotes.Event("RequestSprint"):FireServer(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			Remotes.Event("RequestSprint"):FireServer(false)
		end
		return Enum.ContextActionResult.Pass
	end
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "MM_Sneak" then
		sneaking = not sneaking
		Remotes.Event("RequestSneak"):FireServer(sneaking)
		UIController.Toast(if sneaking then "Sigilo: andas en silencio" else "Sigilo desactivado", "info")
	elseif actionName == "MM_EmoteHelp" then
		Remotes.Event("RequestEmote"):FireServer("Help")
	elseif actionName == "MM_EmoteHere" then
		Remotes.Event("RequestEmote"):FireServer("Here")
	elseif actionName == "MM_EmoteRun" then
		Remotes.Event("RequestEmote"):FireServer("Run")
	elseif actionName == "MM_Flashlight" then
		Remotes.Event("ToggleFlashlight"):FireServer(player:GetAttribute("Flashlight") ~= true)
	elseif actionName == "MM_Camera" then
		equip(Enums.Tool.Camera)
	elseif actionName == "MM_EMF" then
		equip(Enums.Tool.EMF)
	elseif actionName == "MM_CycleTool" then
		local current = player:GetAttribute("EquippedTool")
		local nextTool = if current == Enums.Tool.Camera
			then Enums.Tool.EMF
			elseif current == Enums.Tool.EMF then Enums.Tool.None
			else Enums.Tool.Camera
		Remotes.Event("EquipTool"):FireServer(nextTool)
	elseif actionName == "MM_Use" then
		if player:GetAttribute("EquippedTool") == Enums.Tool.Camera then
			takePhoto()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

local function bind()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindAction("MM_Flashlight", handle, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("MM_Flashlight", "Luz")
	ContextActionService:SetPosition("MM_Flashlight", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindAction("MM_Camera", handle, false, Enum.KeyCode.One, Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("MM_EMF", handle, false, Enum.KeyCode.Two, Enum.KeyCode.DPadRight)
	ContextActionService:BindAction("MM_CycleTool", handle, true, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("MM_CycleTool", "Útil")
	ContextActionService:SetPosition("MM_CycleTool", UDim2.new(1, -230, 1, -90))
	ContextActionService:BindAction("MM_Use", handle, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("MM_Use", "Foto")
	ContextActionService:SetPosition("MM_Use", UDim2.new(1, -110, 1, -150))
	ContextActionService:BindAction("MM_Sprint", handle, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("MM_Sprint", "Correr")
	ContextActionService:SetPosition("MM_Sprint", UDim2.new(1, -170, 1, -210))
	ContextActionService:BindAction("MM_Sneak", handle, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("MM_Sneak", "Sigilo")
	ContextActionService:SetPosition("MM_Sneak", UDim2.new(1, -230, 1, -210))
	-- Gritos: la alternativa a la voz. Avisan a los tuyos pero hacen mucho ruido.
	ContextActionService:BindAction("MM_EmoteHelp", handle, true, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle("MM_EmoteHelp", "Grito")
	ContextActionService:SetPosition("MM_EmoteHelp", UDim2.new(1, -110, 1, -210))
	ContextActionService:BindAction("MM_EmoteHere", handle, false, Enum.KeyCode.H)
	ContextActionService:BindAction("MM_EmoteRun", handle, false, Enum.KeyCode.J, Enum.KeyCode.DPadDown)
end

local function unbind()
	if not bound then
		return
	end
	bound = false
	for _, name in {
		"MM_Flashlight",
		"MM_Camera",
		"MM_EMF",
		"MM_CycleTool",
		"MM_Use",
		"MM_Sprint",
		"MM_Sneak",
		"MM_EmoteHelp",
		"MM_EmoteHere",
		"MM_EmoteRun",
	} do
		ContextActionService:UnbindAction(name)
	end
	sneaking = false
end

local function refresh()
	if active() then
		bind()
	else
		unbind()
	end
end

-- Linterna local que sigue a la cámara (con inclinación). La del servidor,
-- pegada a la cabeza, es la que ven los demás; localmente la apagamos para no duplicar.
local function updateLocalFlashlight()
	local on = active() and player:GetAttribute("Flashlight") == true
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	local serverLight = if head then head:FindFirstChild("Flashlight") else nil
	if serverLight and serverLight:IsA("SpotLight") then
		serverLight.Brightness = if on then 0 else 2.2
	end
	if on then
		if not localLightPart then
			local part = Instance.new("Part")
			part.Name = "LocalFlashlight"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
			part.Size = Vector3.new(0.2, 0.2, 0.2)
			local light = Instance.new("SpotLight")
			light.Angle = 55
			light.Range = 45
			light.Brightness = 2.2
			light.Color = Color3.fromRGB(255, 240, 210)
			light.Shadows = true
			light.Face = Enum.NormalId.Front
			light.Parent = part
			part.Parent = workspace.CurrentCamera
			localLightPart = part
		end
		local part = localLightPart :: Part
		part.CFrame = workspace.CurrentCamera.CFrame * CFrame.new(0.6, -0.5, 0)
	elseif localLightPart then
		localLightPart:Destroy()
		localLightPart = nil
	end
end

function InvestigatorController.Start()
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)
	for _, attr in { "Role", "Alive", "Escaped" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()

	Remotes.Event("PhotoResult").OnClientEvent:Connect(function(hit)
		if hit then
			UIController.Toast("¡Anomalía capturada en la foto!", "success")
		else
			UIController.Toast("Nada fuera de lo normal...", "info")
		end
	end)

	RunService.RenderStepped:Connect(updateLocalFlashlight)
end

return InvestigatorController
