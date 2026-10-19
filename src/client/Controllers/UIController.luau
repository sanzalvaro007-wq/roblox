--!strict
-- HUD de Mimic Manor. Lee atributos replicados (estado de ronda, cordura, batería...)
-- y muestra avisos del servidor. No decide nada: solo pinta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local FONT = Enum.Font.SpecialElite
local TEXT = Color3.fromRGB(230, 220, 200)
local DIM = Color3.fromRGB(150, 140, 125)
local PANEL = Color3.fromRGB(15, 12, 12)
local KIND_COLOR: { [string]: Color3 } = {
	info = Color3.fromRGB(230, 220, 200),
	warn = Color3.fromRGB(240, 190, 90),
	danger = Color3.fromRGB(240, 80, 70),
	success = Color3.fromRGB(120, 230, 140),
}

local UIController = {}

-- Crea una instancia con propiedades e hijos.
function UIController.Make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className) :: any
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local make = UIController.Make

function UIController.Label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = TEXT,
		TextScaled = false,
		TextSize = 20,
		TextStrokeTransparency = 0.6,
	}
	for k, v in props do
		defaults[k] = v
	end
	return make("TextLabel", defaults)
end
local label = UIController.Label

local function corner(radius: number): any
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local gui: ScreenGui
local statusLabel: TextLabel
local objectiveLabel: TextLabel
local roleLabel: TextLabel
local toastList: Frame
local vitals: Frame
local bars: { [string]: Frame } = {}
local toolbar: Frame
local slots: { [string]: Frame } = {}
local emfMeter: Frame
local emfBars: { Frame } = {}
local viewfinder: Frame
local flash: Frame
local vignette: Frame
local prepOverlay: Frame
local prepLabel: TextLabel
local results: Frame
local resultsTitle: TextLabel
local resultsBody: TextLabel
local splash: TextLabel

UIController.EmfLevel = 0

function UIController.Gui(): ScreenGui
	return gui
end

function UIController.Toast(text: string, kind: string?)
	local color = KIND_COLOR[kind or "info"] or TEXT
	local item = label({
		Text = text,
		TextColor3 = color,
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 28),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = toastList,
	})
	TweenService:Create(item, TweenInfo.new(0.25), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	task.delay(4, function()
		local fade = TweenService:Create(item, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		item:Destroy()
	end)
end

function UIController.Flash(color: Color3, duration: number, startTransparency: number?)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = startTransparency or 0
	TweenService:Create(flash, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

function UIController.Vignette(intensity: number)
	-- Tinte rojo a pantalla completa que se desvanece (susto o golpe).
	vignette.BackgroundTransparency = 1 - math.clamp(intensity, 0, 1) * 0.55
	TweenService:Create(vignette, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
end

function UIController.Splash(text: string, color: Color3?)
	splash.Text = text
	splash.TextColor3 = color or TEXT
	splash.TextTransparency = 0
	splash.TextStrokeTransparency = 0.3
	task.delay(2.5, function()
		TweenService:Create(splash, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function makeBar(name: string, text: string, color: Color3, order: number)
	local holder = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		Parent = vitals,
	})
	label({ Text = text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0, 80, 1, 0), Parent = holder })
	local back = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 35, 35),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 84, 0.5, -5),
		Size = UDim2.new(1, -84, 0, 10),
		Parent = holder,
	}, { corner(4) })
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = back,
	}, { corner(4) })
	bars[name] = holder
	holder:SetAttribute("Max", 100)
	return fill
end

local function makeSlot(name: string, key: string, text: string, order: number)
	local slot = make("Frame", {
		Name = name,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.35,
		Size = UDim2.new(0, 96, 0, 56),
		LayoutOrder = order,
		Parent = toolbar,
	}, {
		corner(6),
		make("UIStroke", { Color = DIM, Thickness = 1, Transparency = 0.5 }),
	})
	label({ Name = "Key", Text = key, TextSize = 14, TextColor3 = DIM, Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(0, 20, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = slot })
	label({ Name = "Title", Text = text, TextSize = 17, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 14), Parent = slot })
	label({ Name = "Info", Text = "", TextSize = 14, TextColor3 = DIM, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -18), Parent = slot })
	slots[name] = slot
end

local function build()
	gui = make("ScreenGui", {
		Name = "MimicHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	vignette = make("Frame", {
		Name = "Vignette",
		BackgroundColor3 = Color3.fromRGB(120, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = gui,
	})

	viewfinder = make("Frame", {
		Name = "Viewfinder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	for _, c in { { 0.25, 0.25 }, { 0.75, 0.25 }, { 0.25, 0.75 }, { 0.75, 0.75 } } do
		make("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(c[1], c[2]),
			Size = UDim2.fromOffset(40, 40),
			Parent = viewfinder,
		}, { make("UIStroke", { Color = TEXT, Thickness = 2, Transparency = 0.3 }) })
	end
	label({ Text = "REC ●", TextColor3 = Color3.fromRGB(230, 60, 60), Position = UDim2.fromScale(0.27, 0.27), Size = UDim2.fromOffset(80, 24), Parent = viewfinder })

	statusLabel = label({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.new(0, 420, 0, 30),
		TextSize = 26,
		Parent = gui,
	})
	toastList = make("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.new(0, 600, 0, 200),
		Parent = gui,
	}, { make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

	objectiveLabel = label({
		Name = "Objective",
		Position = UDim2.new(0, 16, 0, 60),
		Size = UDim2.new(0, 360, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Parent = gui,
	})
	roleLabel = label({
		Name = "Role",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 60),
		Size = UDim2.new(0, 260, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = gui,
	})

	vitals = make("Frame", {
		Name = "Vitals",
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.4,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0, 260, 0, 86),
		Visible = false,
		Parent = gui,
	}, {
		corner(6),
		make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6) }),
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	})
	makeBar("Sanity", "Cordura", Color3.fromRGB(150, 120, 220), 1)
	makeBar("Battery", "Batería", Color3.fromRGB(240, 210, 120), 2)
	makeBar("Stamina", "Aguante", Color3.fromRGB(120, 200, 140), 3)

	toolbar = make("Frame", {
		Name = "Toolbar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 320, 0, 56),
		Visible = false,
		Parent = gui,
	}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	makeSlot(Enums.Tool.Camera, "1", "Cámara", 1)
	makeSlot(Enums.Tool.EMF, "2", "EMF", 2)
	makeSlot("Flashlight", "F", "Linterna", 3)

	emfMeter = make("Frame", {
		Name = "EMF",
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.new(0, 190, 0, 34),
		Visible = false,
		Parent = gui,
	}, {
		corner(6),
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }),
	})
	local emfColors = {
		Color3.fromRGB(80, 220, 90),
		Color3.fromRGB(170, 230, 70),
		Color3.fromRGB(240, 220, 60),
		Color3.fromRGB(245, 150, 50),
		Color3.fromRGB(240, 60, 50),
	}
	for i = 1, 5 do
		local bar = make("Frame", {
			Name = "L" .. i,
			BackgroundColor3 = emfColors[i],
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 28, 0, 20),
			LayoutOrder = i,
			Parent = emfMeter,
		}, { corner(3) })
		emfBars[i] = bar
	end

	prepOverlay = make("Frame", {
		Name = "Prep",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.05,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	prepLabel = label({
		Text = "",
		TextSize = 30,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = prepOverlay,
	})

	results = make("Frame", {
		Name = "Results",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	})
	resultsTitle = label({ TextSize = 54, Position = UDim2.fromScale(0, 0.28), Size = UDim2.new(1, 0, 0, 64), ZIndex = 9, Parent = results })
	resultsBody = label({
		TextSize = 22,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.28, 80),
		Size = UDim2.new(0, 600, 0, 260),
		ZIndex = 9,
		Parent = results,
	})

	splash = label({
		Name = "Splash",
		TextSize = 48,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(1, 0, 0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 7,
		Parent = gui,
	})

	flash = make("Frame", {
		Name = "Flash",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = gui,
	})
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function setBar(name: string, value: any, max: number)
	local holder = bars[name]
	if not holder then
		return
	end
	local fill = holder:FindFirstChild("Fill", true) :: Frame?
	if fill then
		local ratio = if typeof(value) == "number" then math.clamp(value / max, 0, 1) else 0
		fill.Size = UDim2.new(ratio, 0, 1, 0)
	end
end

local function update()
	local state = ReplicatedStorage:GetAttribute("RoundState") or Enums.RoundState.Waiting
	local endsAt = ReplicatedStorage:GetAttribute("StateEndsAt") or 0
	local remaining = endsAt - workspace:GetServerTimeNow()
	local stateName = Enums.StateName[state] or state
	statusLabel.Text = if endsAt > 0 then string.format("%s · %s", stateName, formatTime(remaining)) else stateName

	local role = player:GetAttribute("Role") or Enums.Role.Lobby
	local inRound = state == Enums.RoundState.Playing or state == Enums.RoundState.Preparing
	local alive = player:GetAttribute("Alive") == true and player:GetAttribute("Escaped") ~= true
	roleLabel.Text = if role ~= Enums.Role.Lobby then (Enums.RoleName[role] or role) else ""
	roleLabel.TextColor3 = if role == Enums.Role.Anomaly then KIND_COLOR.danger else TEXT

	local inserted = ReplicatedStorage:GetAttribute("FusesInserted") or 0
	local required = ReplicatedStorage:GetAttribute("FusesRequired") or 0
	local powerOn = ReplicatedStorage:GetAttribute("PowerOn") == true
	local escaped = ReplicatedStorage:GetAttribute("Escaped") or 0
	if not inRound then
		objectiveLabel.Text = ""
	elseif role == Enums.Role.Anomaly then
		objectiveLabel.Text = string.format(
			"Que nadie escape.\nFusibles: %d/%d · Escapados: %d%s",
			inserted,
			required,
			escaped,
			if powerOn then " · ¡LA PUERTA ESTÁ ABIERTA!" else ""
		)
	elseif role == Enums.Role.Investigator then
		if player:GetAttribute("Escaped") == true then
			objectiveLabel.Text = "Has escapado. Espera al final de la ronda."
		elseif powerOn then
			objectiveLabel.Text = "¡Energía restaurada! Escapa por la puerta principal."
		else
			local carrying = if player:GetAttribute("CarryingFuse") == true then "\nLlevas un fusible: búscale la caja." else ""
			objectiveLabel.Text = string.format("Repara la caja de fusibles: %d/%d%s", inserted, required, carrying)
		end
	else
		objectiveLabel.Text = "Ronda en curso. Entrarás en la siguiente."
	end

	local investigatorHud = role == Enums.Role.Investigator and inRound and alive
	vitals.Visible = investigatorHud
	toolbar.Visible = investigatorHud
	if investigatorHud then
		setBar("Sanity", player:GetAttribute("Sanity"), Config.Sanity.Max)
		setBar("Battery", player:GetAttribute("Battery"), Config.Investigator.BatteryMax)
		setBar("Stamina", player:GetAttribute("Stamina"), Config.Investigator.StaminaMax)
		local equipped = player:GetAttribute("EquippedTool")
		for name, slot in slots do
			local stroke = slot:FindFirstChildOfClass("UIStroke")
			local active = name == equipped or (name == "Flashlight" and player:GetAttribute("Flashlight") == true)
			if stroke then
				stroke.Color = if active then TEXT else DIM
				stroke.Thickness = if active then 2 else 1
				stroke.Transparency = if active then 0 else 0.5
			end
		end
		local info = slots[Enums.Tool.Camera]:FindFirstChild("Info") :: TextLabel
		info.Text = "Carrete: " .. tostring(player:GetAttribute("Film") or 0)
		local battery = player:GetAttribute("Battery")
		local lightInfo = slots.Flashlight:FindFirstChild("Info") :: TextLabel
		lightInfo.Text = if typeof(battery) == "number" then string.format("%d%%", math.floor(battery)) else ""
		emfMeter.Visible = equipped == Enums.Tool.EMF
		viewfinder.Visible = equipped == Enums.Tool.Camera
	else
		emfMeter.Visible = false
		viewfinder.Visible = false
	end
	for i, bar in emfBars do
		bar.BackgroundTransparency = if i <= UIController.EmfLevel then 0 else 0.85
	end

	local prep = state == Enums.RoundState.Preparing and role == Enums.Role.Investigator
	prepOverlay.Visible = prep
	if prep then
		prepLabel.Text = string.format("Algo se mueve en la mansión...\n%s", formatTime(remaining))
	end
	if state ~= Enums.RoundState.Results then
		results.Visible = false
	end
end

local function showResults(result: any)
	if typeof(result) ~= "table" then
		return
	end
	local winner = result.winner
	resultsTitle.Text = if winner == Enums.Winner.Investigators
		then "Los Investigadores escapan"
		elseif winner == Enums.Winner.Anomaly then "La Anomalía gana"
		else "Fin de la ronda"
	resultsTitle.TextColor3 = if winner == Enums.Winner.Anomaly then KIND_COLOR.danger else KIND_COLOR.success
	local lines = { tostring(result.reason or "") }
	if result.anomaly then
		table.insert(lines, "La Anomalía era: " .. tostring(result.anomaly))
	end
	if typeof(result.escaped) == "table" and #result.escaped > 0 then
		table.insert(lines, "Escaparon: " .. table.concat(result.escaped, ", "))
	end
	if typeof(result.eliminated) == "table" and #result.eliminated > 0 then
		table.insert(lines, "Eliminados: " .. table.concat(result.eliminated, ", "))
	end
	resultsBody.Text = table.concat(lines, "\n")
	results.Visible = true
end

function UIController.Init()
	build()
end

function UIController.Start()
	Remotes.Event("Notify").OnClientEvent:Connect(function(text, kind)
		if typeof(text) == "string" then
			UIController.Toast(text, if typeof(kind) == "string" then kind else nil)
		end
	end)
	Remotes.Event("RoundResult").OnClientEvent:Connect(showResults)
	Remotes.Event("RoleAssigned").OnClientEvent:Connect(function(role)
		if role == Enums.Role.Anomaly then
			UIController.Splash("Eres la ANOMALÍA", KIND_COLOR.danger)
			UIController.Toast("Escóndete: Q para transformarte, clic para atacar", "info")
		elseif role == Enums.Role.Investigator then
			UIController.Splash("Eres INVESTIGADOR")
			UIController.Toast("Repara los fusibles y escapa. Fotografía lo que no encaje.", "info")
		end
	end)
	Remotes.Event("EmfReading").OnClientEvent:Connect(function(level)
		if typeof(level) == "number" then
			UIController.EmfLevel = math.clamp(math.floor(level), 0, 5)
		end
	end)
	Remotes.Event("Scare").OnClientEvent:Connect(function(intensity)
		if typeof(intensity) == "number" then
			UIController.Vignette(intensity)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return UIController
