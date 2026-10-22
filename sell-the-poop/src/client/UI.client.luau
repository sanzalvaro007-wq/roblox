-- Interfaz de Sell the Poop, construida por código (no hace falta diseñar nada en Studio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local data = Config.newData()
local extra = { dealMult = 1, dealEnds = 0 }

local BROWN = Color3.fromRGB(110, 65, 30)
local DARK = Color3.fromRGB(35, 25, 20)
local GOLD = Color3.fromRGB(255, 200, 60)
local GREEN = Color3.fromRGB(70, 190, 90)

-- Helpers ----------------------------------------------------------------------
local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, parent)
end

local function label(parent, props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}, parent)
	for k, v in props do
		l[k] = v
	end
	return l
end

local function button(parent, props)
	local b = make("TextButton", {
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
	}, parent)
	for k, v in props do
		b[k] = v
	end
	corner(b)
	make("UIStroke", { Thickness = 2, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end

-- Pantalla -------------------------------------------------------------------
local gui = make("ScreenGui", { Name = "PoopGui", ResetOnSpawn = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

-- Barra superior: dinero, caca y producción
local top = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 50),
	Size = UDim2.fromOffset(460, 90),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.2,
}, gui)
corner(top)
local cashLabel = label(top, { Size = UDim2.new(1, -20, 0.45, 0), Position = UDim2.fromOffset(10, 4), TextColor3 = GREEN })
local poopLabel = label(top, { Size = UDim2.new(1, -20, 0.3, 0), Position = UDim2.new(0, 10, 0.45, 0) })
local rateLabel = label(top, { Size = UDim2.new(1, -20, 0.2, 0), Position = UDim2.new(0, 10, 0.77, 0), TextColor3 = GOLD })

-- Botones principales (abajo al centro)
local poopButton = button(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, -110, 1, -30),
	Size = UDim2.fromOffset(200, 90),
	BackgroundColor3 = BROWN,
	Text = "💩 HACER CACA",
})
local sellButton = button(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 110, 1, -30),
	Size = UDim2.fromOffset(200, 90),
	BackgroundColor3 = GREEN,
	Text = "💵 VENDER",
})

poopButton.Activated:Connect(function()
	Remotes.Poop:FireServer()
	poopButton.Size = UDim2.fromOffset(190, 84)
	TweenService:Create(poopButton, TweenInfo.new(0.12), { Size = UDim2.fromOffset(200, 90) }):Play()
end)
sellButton.Activated:Connect(function()
	Remotes.Sell:FireServer()
end)

-- Tienda (lado derecho)
local shop = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(300, 420),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.2,
}, gui)
corner(shop)
make("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
}, shop)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, shop)
label(shop, { Size = UDim2.new(1, 0, 0, 30), Text = "🛒 TIENDA", LayoutOrder = 0 })

local upgradeButtons = {}
for i, u in Config.Upgrades do
	local b = button(shop, {
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = BROWN,
		LayoutOrder = i,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
	})
	b.Activated:Connect(function()
		Remotes.BuyUpgrade:FireServer(u.id)
	end)
	upgradeButtons[u.id] = b
end

local oneTimeButtons = {}
for i, u in Config.OneTime do
	local b = button(shop, {
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = Color3.fromRGB(60, 110, 180),
		LayoutOrder = 10 + i,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
	})
	b.Activated:Connect(function()
		Remotes.BuyOneTime:FireServer(u.id)
	end)
	oneTimeButtons[u.id] = b
end

local rebirthButton = button(shop, {
	Size = UDim2.new(1, 0, 0, 70),
	BackgroundColor3 = Color3.fromRGB(130, 60, 190),
	LayoutOrder = 100,
	TextScaled = false,
	TextSize = 16,
	TextWrapped = true,
})
rebirthButton.Activated:Connect(function()
	Remotes.Rebirth:FireServer()
end)

-- Notificaciones -----------------------------------------------------------------
local toast = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	Size = UDim2.fromOffset(500, 36),
	TextStrokeTransparency = 0,
	Text = "",
	Visible = false,
})
local toastId = 0
Remotes.Notify.OnClientEvent:Connect(function(text)
	toastId += 1
	local myId = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(3, function()
		if toastId == myId then
			toast.Visible = false
		end
	end)
end)

-- Tratos del comprador misterioso --------------------------------------------------
local dealFrame = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(280, 160),
	BackgroundColor3 = Color3.fromRGB(40, 40, 70),
	Visible = false,
}, gui)
corner(dealFrame)
local dealText = label(dealFrame, { Size = UDim2.new(1, -20, 0, 80), Position = UDim2.fromOffset(10, 8), TextWrapped = true })
local acceptButton = button(dealFrame, {
	Size = UDim2.new(1, -20, 0, 50),
	Position = UDim2.new(0, 10, 1, -60),
	BackgroundColor3 = GREEN,
	Text = "🤝 ACEPTAR",
})
acceptButton.Activated:Connect(function()
	Remotes.AcceptDeal:FireServer()
	dealFrame.Visible = false
end)

local dealToken = 0
Remotes.DealOffer.OnClientEvent:Connect(function(mult, seconds)
	dealToken += 1
	local myToken = dealToken
	dealText.Text = "👽 Un comprador misterioso quiere tu caca. ¡Paga x" .. mult .. " durante " .. Config.DEAL_DURATION .. "s!"
	dealFrame.Visible = true
	task.delay(seconds, function()
		if dealToken == myToken then
			dealFrame.Visible = false
		end
	end)
end)

-- Refrescar UI -----------------------------------------------------------------
local function refresh()
	cashLabel.Text = "💵 $" .. Config.format(data.Cash)
	poopLabel.Text = "💩 " .. Config.format(data.Poop) .. " cacas  (vale $" .. Config.format(Config.poopValue(data)) .. " c/u)"
	local rate = Config.poopPerSecond(data) .. "/s · " .. Config.poopPerClick(data) .. "/click"
	local remaining = extra.dealEnds - workspace:GetServerTimeNow()
	if remaining > 0 then
		rate ..= "  · 🤝 x" .. extra.dealMult .. " (" .. math.ceil(remaining) .. "s)"
	end
	rateLabel.Text = rate

	for _, u in Config.Upgrades do
		local level = data.Levels[u.id]
		local cost = Config.upgradeCost(u.id, level)
		local b = upgradeButtons[u.id]
		b.Text = u.name .. " (Nv " .. level .. ")\n" .. u.desc .. " · $" .. Config.format(cost)
		b.BackgroundTransparency = data.Cash >= cost and 0 or 0.5
	end
	for _, u in Config.OneTime do
		local b = oneTimeButtons[u.id]
		if data.Owned[u.id] then
			b.Text = u.name .. "\n✅ Comprado"
			b.BackgroundTransparency = 0.5
		else
			b.Text = u.name .. "\n" .. u.desc .. " · $" .. Config.format(u.cost)
			b.BackgroundTransparency = data.Cash >= u.cost and 0 or 0.5
		end
	end
	rebirthButton.Text = "🌌 Laxante Cósmico (x" .. Config.rebirthMult(data) + 1 .. " a todo)\nReinicia todo · $"
		.. Config.format(Config.rebirthCost(data))
end

Remotes.State.OnClientEvent:Connect(function(newData, newExtra)
	data = newData
	-- El servidor usa os.clock(); lo convertimos a tiempo restante aproximado
	extra.dealMult = newExtra.dealMult
	extra.dealEnds = workspace:GetServerTimeNow() + math.max(0, newExtra.dealEndsIn or 0)
	refresh()
end)

refresh()
