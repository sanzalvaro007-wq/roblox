--!strict
-- "Cómo jugar": se abre solo al recibir rol y siempre con F1 o el botón "?".

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

local TEXTS: { [string]: string } = {
	Investigator = table.concat({
		"ERES INVESTIGADOR",
		"",
		"Objetivo: escapar de la mansión. Si escapa al menos uno, ganáis.",
		"1. Los fusibles están dentro de cajas de madera: ábrelas manteniendo E (algunas están vacías o tienen pilas).",
		"2. Llévalos a la caja de fusibles del garaje (te sale un marcador) y mantén E.",
		"3. Con todos puestos se encienden las lámparas: corre a la Salida (marcador verde) y mantén E.",
		"",
		"Cuidado: uno de los muebles es la Anomalía disfrazada.",
		"· F linterna (gasta batería; hay pilas azules por la mansión)",
		"· 1 cámara: haz clic para un flash que revela y aturde a la Anomalía",
		"· 2 EMF: cuantas más barras, más cerca está",
		"· 3 luz UV: muestra sus huellas moradas",
		"· Shift correr · C sigilo (silencioso) · G/H/J gritar a tu equipo",
		"· Clic en una puerta para abrirla o cerrarla (hace algo de ruido)",
		"",
		"La oscuridad y la soledad bajan tu cordura y verás cosas que no existen.",
	}, "\n"),
	Anomaly = table.concat({
		"ERES LA ANOMALÍA",
		"",
		"Objetivo: que nadie escape antes de que acabe el tiempo.",
		"· Q: menú de formas; conviértete en un mueble y quédate quieta entre los de verdad",
		"· Atacas hacia la cruz roja del centro (alcance corto, acércate)",
		"· Clic: atacar (desde que empieza la partida). Si llevas 2 s transformada, la emboscada mata de un golpe",
		"· E: volver a tu forma · Clic en una puerta: abrirla o cerrarla",
		"",
		"Ves marcas rojas donde los Investigadores hacen ruido (hablar, correr, gritar).",
		"Su flash te revela y te aturde; su EMF y sus huellas UV te delatan.",
		"Vigila la caja de fusibles: cuando la luz vuelve, pueden escapar.",
	}, "\n"),
	Lobby = table.concat({
		"SLENDERMAN.EXE",
		"",
		"Una Anomalía que se disfraza de mueble contra Investigadores que intentan escapar.",
		"La ronda empieza sola cuando hay jugadores suficientes.",
		"",
		"· B: tienda (mejoras y Cofre maldito con formas para la Anomalía)",
		"· F1: esta ayuda",
	}, "\n"),
}

local HelpController = {}

local panel: Frame
local body: TextLabel

local function roleKey(): string
	local role = player:GetAttribute("Role")
	if role == Enums.Role.Investigator or role == Enums.Role.Anomaly then
		return role :: string
	end
	return "Lobby"
end

local function setOpen(open: boolean, role: string?)
	if open then
		body.Text = TEXTS[role or roleKey()] or TEXTS.Lobby
	end
	panel.Visible = open
end

function HelpController.Start()
	local gui = UIController.Gui()
	panel = UIController.Make("Frame", {
		Name = "Help",
		BackgroundColor3 = Color3.fromRGB(12, 9, 9),
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 430),
		Visible = false,
		ZIndex = 4,
		Parent = gui,
	}, {
		UIController.Make("UICorner", { CornerRadius = UDim.new(0, 10) }),
		UIController.Make("UISizeConstraint", { MaxSize = Vector2.new(640, 430) }),
		UIController.Make("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
	})
	body = UIController.Label({
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 1, -50),
		ZIndex = 5,
		Parent = panel,
	})
	local close = UIController.Make("TextButton", {
		Text = "Entendido (F1)",
		Font = Enum.Font.SpecialElite,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(230, 220, 200),
		BackgroundColor3 = Color3.fromRGB(60, 35, 30),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(180, 34),
		ZIndex = 5,
		Parent = panel,
	}, { UIController.Make("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local helpButton = UIController.Make("TextButton", {
		Name = "HelpButton",
		Text = "?",
		Font = Enum.Font.SpecialElite,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(230, 220, 200),
		BackgroundColor3 = Color3.fromRGB(30, 20, 20),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(36, 36),
		Parent = gui,
	}, { UIController.Make("UICorner", { CornerRadius = UDim.new(0, 18) }) })
	helpButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)

	ContextActionService:BindAction("MM_Help", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			setOpen(not panel.Visible)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F1)

	-- Al recibir rol se abre la ayuda de ese rol; se cierra sola al empezar la partida.
	Remotes.Event("RoleAssigned").OnClientEvent:Connect(function(role)
		if typeof(role) == "string" then
			setOpen(true, role)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
		if ReplicatedStorage:GetAttribute("RoundState") == Enums.RoundState.Playing then
			setOpen(false)
		end
	end)
end

return HelpController
