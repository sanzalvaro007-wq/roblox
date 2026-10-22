--!strict
-- Tienda del lobby (tecla B o botón "Tienda"): mejoras, consumibles, aspecto, gacha y Robux.
-- Las probabilidades del gacha se muestran SIEMPRE antes de tirar.

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local PropCatalog = require(Shared:WaitForChild("PropCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))

local ProfileController = require(script.Parent:WaitForChild("ProfileController"))
local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer
local make = UIController.Make
local label = UIController.Label

local TEXT = Color3.fromRGB(230, 220, 200)
local DIM = Color3.fromRGB(150, 140, 125)
local GOLD = Color3.fromRGB(240, 200, 90)

local ShopController = {}

local panel: Frame
local list: ScrollingFrame
local coinsLabel: TextLabel
local openButton: TextButton

local function inLobby(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	local role = player:GetAttribute("Role")
	local inRound = state == Enums.RoundState.Playing or state == Enums.RoundState.Preparing
	return not inRound or role == Enums.Role.Lobby or role == nil
end

local function button(text: string, color: Color3, parent: Instance, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		Text = text,
		Font = Enum.Font.SpecialElite,
		TextSize = 16,
		TextColor3 = TEXT,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Size = UDim2.new(0, 120, 0, 30),
		Parent = parent,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	b.Activated:Connect(onClick)
	return b
end

local function section(title: string, order: number)
	label({
		Text = title,
		TextSize = 22,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		Parent = list,
	})
end

local function row(order: number, title: string, description: string): Frame
	local r = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 22, 22),
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, 58),
		LayoutOrder = order,
		Parent = list,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	label({ Text = title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -150, 0, 22), Parent = r })
	label({
		Text = description,
		TextSize = 14,
		TextColor3 = DIM,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 10, 0, 26),
		Size = UDim2.new(1, -150, 0, 30),
		Parent = r,
	})
	return r
end

local function place(b: TextButton)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -10, 0.5, 0)
end

local function render()
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local data = ProfileController.Data
	coinsLabel.Text = string.format("Monedas: %d%s", data.coins, if data.persist then "" else "  (sin guardado)")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	section("Equipo de Investigador", nextOrder())
	for _, item in ShopCatalog.Items do
		local r = row(nextOrder(), string.format("%s · %d", item.name, item.price), item.description)
		local b: TextButton
		if item.consumable then
			b = button(string.format("Comprar (%d)", ProfileController.Count(item.id)), Color3.fromRGB(70, 50, 30), r, function()
				Remotes.Event("ShopPurchase"):FireServer(item.id)
			end)
		elseif not ProfileController.Owns(item.id) then
			b = button("Comprar", Color3.fromRGB(70, 50, 30), r, function()
				Remotes.Event("ShopPurchase"):FireServer(item.id)
			end)
		elseif item.slot then
			local slot = item.slot :: string
			local equipped = data.equipped[slot] == item.id
			b = button(if equipped then "Quitar" else "Equipar", Color3.fromRGB(40, 60, 45), r, function()
				Remotes.Event("ShopEquip"):FireServer(slot, if equipped then "Default" else item.id)
			end)
		else
			b = button("Tuyo", Color3.fromRGB(40, 40, 40), r, function() end)
		end
		place(b)
	end

	section("Aspecto (solo cambia el color)", nextOrder())
	for _, item in ShopCatalog.Cosmetics do
		local slot = item.slot :: string
		local owned = if item.exclusive then player:GetAttribute(item.exclusive) == true else ProfileController.Owns(item.id)
		local title = if item.exclusive then item.name else string.format("%s · %d", item.name, item.price)
		local r = row(nextOrder(), title, item.description)
		local rgb = item.rgb or { 255, 255, 255 }
		make("Frame", {
			BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -138, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			Parent = r,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local b: TextButton
		if owned then
			local equipped = data.equipped[slot] == item.id
			b = button(if equipped then "Quitar" else "Equipar", Color3.fromRGB(40, 60, 45), r, function()
				Remotes.Event("ShopEquip"):FireServer(slot, if equipped then "Default" else item.id)
			end)
		elseif item.exclusive then
			local pass = ShopCatalog.Pass(item.exclusive)
			b = button("Gamepass", Color3.fromRGB(30, 60, 90), r, function()
				if pass and pass.id ~= 0 then
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				else
					UIController.Toast("Aún no está a la venta", "info")
				end
			end)
		else
			b = button("Comprar", Color3.fromRGB(70, 50, 30), r, function()
				Remotes.Event("ShopPurchase"):FireServer(item.id)
			end)
		end
		place(b)
	end

	local gacha = ShopCatalog.Gacha
	section(string.format("%s · %d monedas", gacha.name, gacha.price), nextOrder())
	local odds = ShopCatalog.GachaOdds()
	local lines = {}
	for _, entry in gacha.pool do
		local def = PropCatalog.Get(entry.form)
		local owned = ProfileController.Owns("Form_" .. entry.form)
		table.insert(lines, string.format("%s: %.1f%%%s", if def then def.name else entry.form, odds[entry.form], if owned then " (tuya)" else ""))
	end
	local r = row(
		nextOrder(),
		"Formas cosméticas de la Anomalía con kill cam propia",
		"Probabilidades: " .. table.concat(lines, " · ") .. string.format(". Repetida: devuelve %d.", gacha.duplicateRefund)
	)
	r.Size = UDim2.new(1, 0, 0, 72)
	place(button("Abrir cofre", Color3.fromRGB(90, 30, 30), r, function()
		Remotes.Event("GachaRoll"):FireServer()
	end))

	-- Robux: solo aparece lo que ya tiene id en el Creator Dashboard.
	local M = ShopCatalog.Monetization
	local robuxRows: { () -> () } = {}
	for _, pass in M.GamePasses do
		if pass.id ~= 0 then
			table.insert(robuxRows, function()
				local r = row(nextOrder(), pass.name .. " (gamepass)", pass.description)
				if player:GetAttribute(pass.key) == true then
					place(button("Tuyo", Color3.fromRGB(40, 40, 40), r, function() end))
				else
					place(button("Comprar", Color3.fromRGB(30, 60, 90), r, function()
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end))
				end
			end)
		end
	end
	for _, product in M.Products do
		if product.id ~= 0 then
			table.insert(robuxRows, function()
				local title = product.name
				if product.key == "Revive" then
					title = string.format("%s (tienes %d)", product.name, ProfileController.Count("Revive"))
				end
				local r = row(nextOrder(), title, product.description)
				place(button("Comprar", Color3.fromRGB(30, 60, 90), r, function()
					MarketplaceService:PromptProductPurchase(player, product.id)
				end))
			end)
		end
	end
	if #robuxRows > 0 then
		section("Robux", nextOrder())
		for _, add in robuxRows do
			add()
		end
	end

	section("Estadísticas", nextOrder())
	local s = data.stats
	row(
		nextOrder(),
		string.format("Rondas %d · Victorias %d", s.rounds or 0, s.wins or 0),
		string.format("Escapes %d · Eliminaciones como Anomalía %d", s.escapes or 0, s.kills or 0)
	)
end

local function setOpen(open: boolean)
	panel.Visible = open and inLobby()
	if panel.Visible then
		render()
	end
end

local function build()
	local gui = UIController.Gui()
	panel = make("Frame", {
		Name = "Shop",
		BackgroundColor3 = Color3.fromRGB(14, 10, 10),
		BackgroundTransparency = 0.08,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 600, 0, 460),
		Visible = false,
		ZIndex = 3,
		Parent = gui,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 10) }),
		make("UIStroke", { Color = DIM, Transparency = 0.5 }),
		make("UISizeConstraint", { MaxSize = Vector2.new(600, 460) }),
	})
	panel.Size = UDim2.new(0.95, 0, 0.8, 0)
	label({ Text = "Tienda de la mansión", TextSize = 26, Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -60, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	coinsLabel = label({ Text = "", TextSize = 18, TextColor3 = GOLD, Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -60, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	local close = button("X", Color3.fromRGB(60, 30, 30), panel, function()
		setOpen(false)
	end)
	close.Size = UDim2.fromOffset(34, 34)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	list = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, 68),
		Size = UDim2.new(1, -28, 1, -80),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = panel,
	}, { make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })

	openButton = make("TextButton", {
		Name = "OpenShop",
		Text = "Tienda (B)",
		Font = Enum.Font.SpecialElite,
		TextSize = 18,
		TextColor3 = GOLD,
		BackgroundColor3 = Color3.fromRGB(30, 20, 20),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 96),
		Size = UDim2.fromOffset(140, 34),
		Parent = gui,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	openButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
end

local function refresh()
	openButton.Visible = inLobby()
	openButton.Text = string.format("Tienda (B) · %d", ProfileController.Data.coins)
	if not inLobby() then
		panel.Visible = false
	elseif panel.Visible then
		render()
	end
end

function ShopController.Start()
	build()
	ContextActionService:BindAction("MM_Shop", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and inLobby() then
			setOpen(not panel.Visible)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)

	ProfileController.Changed:Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)
	player:GetAttributeChangedSignal("Role"):Connect(refresh)
	for _, pass in ShopCatalog.Monetization.GamePasses do
		player:GetAttributeChangedSignal(pass.key):Connect(refresh)
	end
	-- Etiqueta [VIP] en el chat para quien tiene el gamepass.
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): any
		local source = message.TextSource
		local sender = if source then Players:GetPlayerByUserId(source.UserId) else nil
		if sender and sender:GetAttribute("VIP") == true then
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = '<font color="#F0C85A">[VIP]</font> ' .. message.PrefixText
			return props
		end
		return nil
	end
	refresh()

	Remotes.Event("ShopResult").OnClientEvent:Connect(function(ok, message)
		if typeof(message) == "string" then
			UIController.Toast(message, if ok then "success" else "warn")
		end
	end)
	Remotes.Event("GachaResult").OnClientEvent:Connect(function(form, duplicate, refund)
		local def = if typeof(form) == "string" then PropCatalog.Get(form) else nil
		local name = if def then def.name else tostring(form)
		if duplicate then
			UIController.Splash(name .. " (repetida)", GOLD)
			UIController.Toast(string.format("Ya la tenías: +%d monedas", tonumber(refund) or 0), "info")
		else
			UIController.Splash("¡Nueva forma: " .. name .. "!", if def and def.killColor then def.killColor else GOLD)
		end
	end)
	Remotes.Event("RoundEarnings").OnClientEvent:Connect(function(lines)
		if typeof(lines) ~= "table" then
			return
		end
		local total = 0
		for _, line in lines do
			if typeof(line) == "table" and typeof(line.amount) == "number" then
				total += line.amount
				UIController.Toast(string.format("+%d %s", line.amount, tostring(line.reason)), "success")
			end
		end
		if total > 0 then
			UIController.Toast(string.format("Total: +%d monedas", total), "success")
		end
	end)
end

return ShopController
