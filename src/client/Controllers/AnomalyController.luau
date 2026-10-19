--!strict
-- Controles de la Anomalía: menú de formas (Q), deshacer (E), atacar (clic).
-- El servidor elige a quién golpea y si es emboscada; aquí solo pedimos.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local PropCatalog = require(Shared:WaitForChild("PropCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ProfileController = require(script.Parent:WaitForChild("ProfileController"))
local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

local AnomalyController = {}

local bound = false
local menu: Frame
local hint: TextLabel
local currentProp: string? = nil
local morphedAt = 0
local visionPart: Part? = nil

local function active(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	return player:GetAttribute("Role") == Enums.Role.Anomaly
		and player:GetAttribute("Alive") == true
		and (state == Enums.RoundState.Playing or state == Enums.RoundState.Preparing)
end

local function setMenu(open: boolean)
	menu.Visible = open
	if not open then
		return
	end
	-- Las formas del gacha aparecen bloqueadas si no son tuyas.
	for i, def in PropCatalog.List do
		local button = menu:FindFirstChild(def.id)
		if button and button:IsA("TextButton") then
			local locked = def.cosmetic == true and not ProfileController.Owns("Form_" .. def.id)
			button.Text = string.format("%s%s%s", if i <= 9 then i .. " · " else "", def.name, if locked then " 🔒" else "")
			button.TextTransparency = if locked then 0.5 else 0
		end
	end
end

local function buildUi()
	local gui = UIController.Gui()
	menu = UIController.Make("Frame", {
		Name = "MorphMenu",
		BackgroundColor3 = Color3.fromRGB(15, 10, 10),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0, 480, 0, 300),
		Visible = false,
		Parent = gui,
	}, {
		UIController.Make("UICorner", { CornerRadius = UDim.new(0, 8) }),
		UIController.Make("UIPadding", {
			PaddingTop = UDim.new(0, 40),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		UIController.Make("UIGridLayout", {
			CellSize = UDim2.new(0, 145, 0, 36),
			CellPadding = UDim2.new(0, 8, 0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UIController.Label({
		Text = "Elige una forma (Q para cerrar)",
		TextSize = 20,
		Position = UDim2.new(0, -12, 0, -34),
		Size = UDim2.new(1, 24, 0, 28),
		Parent = menu,
	})
	for i, def in PropCatalog.List do
		local button = UIController.Make("TextButton", {
			Name = def.id,
			Text = string.format("%d · %s", i, def.name),
			Font = Enum.Font.SpecialElite,
			TextSize = 18,
			TextColor3 = Color3.fromRGB(230, 220, 200),
			BackgroundColor3 = Color3.fromRGB(45, 30, 30),
			AutoButtonColor = true,
			LayoutOrder = i,
			Parent = menu,
		}, { UIController.Make("UICorner", { CornerRadius = UDim.new(0, 6) }) })
		button.Activated:Connect(function()
			Remotes.Event("RequestMorph"):FireServer(def.id)
			setMenu(false)
		end)
	end

	hint = UIController.Label({
		Name = "AnomalyHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(0, 700, 0, 50),
		TextSize = 20,
		TextWrapped = true,
		Visible = false,
		Parent = gui,
	})
end

local function handle(actionName: string, inputState: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or not active() then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "MM_MorphMenu" then
		setMenu(not menu.Visible)
	elseif actionName == "MM_Unmorph" then
		Remotes.Event("RequestUnmorph"):FireServer()
	elseif actionName == "MM_Attack" then
		Remotes.Event("RequestAttack"):FireServer()
	elseif actionName == "MM_QuickMorph" and menu.Visible then
		local index = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		local def = PropCatalog.List[index]
		if def then
			Remotes.Event("RequestMorph"):FireServer(def.id)
			setMenu(false)
		end
	else
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

local QUICK_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local function bind()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindAction("MM_MorphMenu", handle, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("MM_MorphMenu", "Forma")
	ContextActionService:SetPosition("MM_MorphMenu", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindAction("MM_Unmorph", handle, true, Enum.KeyCode.E, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("MM_Unmorph", "Volver")
	ContextActionService:SetPosition("MM_Unmorph", UDim2.new(1, -230, 1, -90))
	ContextActionService:BindAction("MM_Attack", handle, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("MM_Attack", "Atacar")
	ContextActionService:SetPosition("MM_Attack", UDim2.new(1, -110, 1, -150))
	ContextActionService:BindAction("MM_QuickMorph", handle, false, table.unpack(QUICK_KEYS))
	-- La Anomalía no interactúa con fusibles ni puertas: ocultamos los avisos.
	ProximityPromptService.Enabled = false
end

local function unbind()
	if not bound then
		return
	end
	bound = false
	for _, name in { "MM_MorphMenu", "MM_Unmorph", "MM_Attack", "MM_QuickMorph" } do
		ContextActionService:UnbindAction(name)
	end
	ProximityPromptService.Enabled = true
	if menu then
		setMenu(false)
	end
end

local function refresh()
	if active() then
		bind()
	else
		unbind()
		currentProp = nil
	end
end

-- Ruido de un Investigador: marca 3D en la posición aproximada y flecha en pantalla.
local function showNoise(position: any, intensity: any)
	if typeof(position) ~= "Vector3" or typeof(intensity) ~= "number" or not active() then
		return
	end
	local camera = workspace.CurrentCamera
	local strength = math.clamp(intensity, 0, 1)

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(0, 2, 0)
	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(60 + 60 * strength, 60 + 60 * strength)
	billboard.Parent = anchor
	local ring = UIController.Label({
		Text = "(( · ))",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 90, 80),
		Size = UDim2.fromScale(1, 1),
		Parent = billboard,
	})
	anchor.Parent = camera
	TweenService:Create(ring, TweenInfo.new(1.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		anchor:Destroy()
	end)

	-- Flecha alrededor del centro de la pantalla hacia el ruido.
	local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	local to = (position - camera.CFrame.Position) * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 or to.Magnitude < 0.01 then
		return
	end
	look, to = look.Unit, to.Unit
	local angle = math.atan2(look:Cross(to).Y, look:Dot(to))
	local arrow = UIController.Label({
		Text = "▲",
		TextSize = 28 + 20 * strength,
		TextColor3 = Color3.fromRGB(255, 90, 80),
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- Ángulo positivo = a la izquierda.
		Position = UDim2.new(0.5, -math.sin(angle) * 160, 0.5, -math.cos(angle) * 160),
		Rotation = -math.deg(angle),
		Size = UDim2.fromOffset(50, 50),
		Parent = UIController.Gui(),
	})
	TweenService:Create(arrow, TweenInfo.new(1.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.5, function()
		arrow:Destroy()
	end)
end

-- Visión nocturna de la Anomalía: una luz roja tenue que solo existe en su cliente.
local function updateVision()
	if active() then
		if not visionPart then
			local part = Instance.new("Part")
			part.Name = "AnomalyVision"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
			part.Size = Vector3.new(0.2, 0.2, 0.2)
			local light = Instance.new("PointLight")
			light.Range = 32
			light.Brightness = 0.7
			light.Color = Color3.fromRGB(255, 120, 120)
			light.Shadows = false
			light.Parent = part
			part.Parent = workspace.CurrentCamera
			visionPart = part
		end
		(visionPart :: Part).CFrame = workspace.CurrentCamera.CFrame
	elseif visionPart then
		visionPart:Destroy()
		visionPart = nil
	end
end

local function updateHint()
	updateVision()
	local show = active()
	hint.Visible = show
	if not show then
		return
	end
	if ReplicatedStorage:GetAttribute("RoundState") == Enums.RoundState.Preparing then
		hint.Text = "Escóndete antes de que despierten. Q: transformarte"
	elseif currentProp then
		local def = PropCatalog.Get(currentProp)
		local ready = os.clock() - morphedAt >= Config.Anomaly.AmbushMinMorphTime
		hint.Text = string.format(
			"Eres: %s · %s · E: volver",
			if def then def.name else currentProp,
			if ready then "EMBOSCADA LISTA (clic)" else "preparando emboscada..."
		)
	else
		hint.Text = "Q: transformarte · Clic: atacar"
	end
end

function AnomalyController.Start()
	buildUi()
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)
	for _, attr in { "Role", "Alive" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()

	Remotes.Event("MorphState").OnClientEvent:Connect(function(propId)
		currentProp = if typeof(propId) == "string" then propId else nil
		morphedAt = os.clock()
	end)

	Remotes.Event("NoisePing").OnClientEvent:Connect(showNoise)

	RunService.RenderStepped:Connect(updateHint)
end

return AnomalyController
