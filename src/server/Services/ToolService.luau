--!strict
-- Herramientas de los Investigadores: linterna (batería), cámara (carretes, aturde y revela),
-- detector EMF (lectura calculada en el servidor) y sprint con aguante.
-- El cliente nunca sabe dónde está la Anomalía: solo recibe el nivel del EMF.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Util = script.Parent.Parent:WaitForChild("Util")
local Guard = require(Util:WaitForChild("Guard"))
local PlayerUtil = require(Util:WaitForChild("PlayerUtil"))
local MorphService = require(script.Parent:WaitForChild("MorphService"))

local I = Config.Investigator

local ToolService = {}

local lastPhoto: { [Player]: number } = {}
local sprintWanted: { [Player]: boolean } = {}
local sneakWanted: { [Player]: boolean } = {}
local moveNoise: { [Player]: number } = {}

local function flashlightOf(player: Player): SpotLight?
	local head = PlayerUtil.Head(player)
	local light = if head then head:FindFirstChild("Flashlight") else nil
	return if light and light:IsA("SpotLight") then light else nil
end

local function setFlashlight(player: Player, on: boolean)
	local light = flashlightOf(player)
	if light then
		light.Enabled = on
	end
	player:SetAttribute("Flashlight", on)
end

function ToolService.Setup(player: Player)
	player:SetAttribute("Battery", I.BatteryMax)
	player:SetAttribute("Film", I.Film)
	player:SetAttribute("Stamina", I.StaminaMax)
	player:SetAttribute("EquippedTool", Enums.Tool.None)
	player:SetAttribute("Flashlight", false)
	sprintWanted[player] = false
	sneakWanted[player] = false
	moveNoise[player] = 0
	local head = PlayerUtil.Head(player)
	if head and not head:FindFirstChild("Flashlight") then
		local light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Angle = 55
		light.Range = 45
		light.Brightness = 2.2
		light.Color = Color3.fromRGB(255, 240, 210)
		light.Shadows = true
		light.Face = Enum.NormalId.Front
		light.Enabled = false
		light.Parent = head
	end
end

function ToolService.Reset(player: Player)
	setFlashlight(player, false)
	for _, name in { "Battery", "Film", "Stamina", "EquippedTool", "Flashlight", "Sneaking" } do
		player:SetAttribute(name, nil)
	end
	sprintWanted[player] = nil
	sneakWanted[player] = nil
	moveNoise[player] = nil
	lastPhoto[player] = nil
end

-- Ruido de movimiento del último tick (lo lee NoiseService).
function ToolService.MovementNoise(player: Player): number
	return moveNoise[player] or 0
end

function ToolService.AddBattery(player: Player, amount: number)
	local battery = player:GetAttribute("Battery")
	if typeof(battery) == "number" then
		player:SetAttribute("Battery", math.min(I.BatteryMax, battery + amount))
	end
end

local function canSee(origin: Vector3, look: Vector3, point: Vector3, ignore: { Instance }, target: Model): boolean
	local offset = point - origin
	local dist = offset.Magnitude
	if dist > I.PhotoRange or dist < 0.1 then
		return dist < 0.1
	end
	if look:Dot(offset.Unit) < math.cos(math.rad(I.PhotoConeDegrees / 2)) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, offset, params)
	return result == nil or result.Instance:IsDescendantOf(target)
end

local function flashEffect(head: BasePart)
	local flash = Instance.new("PointLight")
	flash.Name = "CameraFlash"
	flash.Range = 30
	flash.Brightness = 8
	flash.Color = Color3.fromRGB(230, 240, 255)
	flash.Parent = head
	task.delay(0.15, function()
		flash:Destroy()
	end)
end

local function onPhoto(player: Player, look: any)
	if ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
		return
	end
	if not PlayerUtil.IsInvestigator(player) or player:GetAttribute("EquippedTool") ~= Enums.Tool.Camera then
		return
	end
	if not Guard.IsFiniteVector(look) then
		return
	end
	local film = player:GetAttribute("Film")
	if typeof(film) ~= "number" or film <= 0 then
		return
	end
	local now = os.clock()
	if lastPhoto[player] and now - lastPhoto[player] < I.PhotoCooldown then
		return
	end
	local head = PlayerUtil.Head(player)
	if not head then
		return
	end
	lastPhoto[player] = now
	player:SetAttribute("Film", film - 1)
	flashEffect(head)

	local anomaly = PlayerUtil.Anomaly()
	local hit = false
	if anomaly and anomaly.Character then
		local ignore: { Instance } = {}
		for _, other in PlayerUtil.Investigators() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		local direction = (look :: Vector3).Unit
		local points: { Vector3 } = {}
		local root = PlayerUtil.Root(anomaly)
		if root then
			table.insert(points, root.Position)
		end
		local disguise = MorphService.Disguise(anomaly)
		if disguise and disguise.PrimaryPart then
			table.insert(points, disguise.PrimaryPart.Position)
		end
		for _, point in points do
			if canSee(head.Position, direction, point, ignore, anomaly.Character) then
				hit = true
				break
			end
		end
		if hit then
			local wasMorphed = MorphService.IsMorphed(anomaly)
			MorphService.Unmorph(anomaly)
			local stunned = MorphService.Stun(
				anomaly,
				if wasMorphed then Config.Anomaly.PhotoStunTime else Config.Anomaly.PhotoStunTimeUnmorphed
			)
			MorphService.Reveal(anomaly, Config.Anomaly.PhotoRevealTime)
			Remotes.Event("Notify"):FireClient(
				anomaly,
				if stunned then "¡Un flash te ha revelado!" else "Un flash te ha revelado (inmune al aturdimiento)",
				"danger"
			)
		end
	end
	Remotes.Event("PhotoResult"):FireClient(player, hit)
end

local function emfLevel(distance: number, morphed: boolean): number
	local level = 0
	for i, threshold in I.EmfLevels do
		if distance <= threshold then
			level = #I.EmfLevels - i + 1
			break
		end
	end
	-- Transformada emite más energía: un "tell" para quien sepa leer el EMF.
	if morphed and level > 0 then
		level = math.min(5, level + 1)
	end
	return level
end

local function updateMovement(player: Player, dt: number, state: string?)
	local humanoid = PlayerUtil.Humanoid(player)
	if not humanoid then
		return
	end
	local stamina = player:GetAttribute("Stamina")
	if typeof(stamina) ~= "number" then
		return
	end
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sneaking = sneakWanted[player] == true
	local sprinting = not sneaking and sprintWanted[player] == true and moving and stamina > 0
	if sprinting then
		stamina = math.max(0, stamina - I.StaminaDrain * dt)
		if stamina <= 0 then
			sprintWanted[player] = false
		end
	else
		stamina = math.min(I.StaminaMax, stamina + I.StaminaRegen * dt)
	end
	player:SetAttribute("Stamina", stamina)
	local N = Config.Noise
	if state == Enums.RoundState.Preparing then
		humanoid.WalkSpeed = 0
		moveNoise[player] = N.Still
	else
		humanoid.WalkSpeed = if sprinting then I.SprintSpeed elseif sneaking then I.SneakSpeed else I.WalkSpeed
		moveNoise[player] = if not moving then N.Still elseif sprinting then N.Sprint elseif sneaking then N.Sneak else N.Walk
	end
end

function ToolService.Init()
	Remotes.Event("ToggleFlashlight").OnServerEvent:Connect(function(player, on)
		if typeof(on) ~= "boolean" or not Guard.RateLimit(player, "Flashlight", 0.15) then
			return
		end
		if not PlayerUtil.IsInvestigator(player) then
			return
		end
		local battery = player:GetAttribute("Battery")
		if on and (typeof(battery) ~= "number" or battery <= 0) then
			Remotes.Event("Notify"):FireClient(player, "La linterna no tiene batería", "warn")
			return
		end
		setFlashlight(player, on)
	end)

	Remotes.Event("EquipTool").OnServerEvent:Connect(function(player, tool)
		if typeof(tool) ~= "string" or not Guard.RateLimit(player, "Equip", 0.15) then
			return
		end
		if tool ~= Enums.Tool.None and tool ~= Enums.Tool.Camera and tool ~= Enums.Tool.EMF then
			return
		end
		if PlayerUtil.IsInvestigator(player) then
			player:SetAttribute("EquippedTool", tool)
		end
	end)

	Remotes.Event("TakePhoto").OnServerEvent:Connect(function(player, look)
		if Guard.RateLimit(player, "Photo", 0.25) then
			onPhoto(player, look)
		end
	end)

	Remotes.Event("RequestSprint").OnServerEvent:Connect(function(player, on)
		if typeof(on) ~= "boolean" or not Guard.RateLimit(player, "Sprint", 0.05) then
			return
		end
		local stamina = player:GetAttribute("Stamina")
		if on and (typeof(stamina) ~= "number" or stamina < I.StaminaMinToSprint) then
			return
		end
		sprintWanted[player] = on
	end)

	Remotes.Event("RequestSneak").OnServerEvent:Connect(function(player, on)
		if typeof(on) ~= "boolean" or not Guard.RateLimit(player, "Sneak", 0.1) then
			return
		end
		if PlayerUtil.IsInvestigator(player) then
			sneakWanted[player] = on
			player:SetAttribute("Sneaking", on)
		end
	end)

	-- Batería, aguante y velocidad.
	task.spawn(function()
		local dt = 0.1
		while true do
			task.wait(dt)
			local state = ReplicatedStorage:GetAttribute("RoundState")
			if state ~= Enums.RoundState.Playing and state ~= Enums.RoundState.Preparing then
				continue
			end
			for _, player in PlayerUtil.Investigators() do
				updateMovement(player, dt, state)
				if player:GetAttribute("Flashlight") == true then
					local battery = player:GetAttribute("Battery")
					if typeof(battery) == "number" then
						battery = math.max(0, battery - I.BatteryDrain * dt)
						player:SetAttribute("Battery", battery)
						if battery <= 0 then
							setFlashlight(player, false)
							Remotes.Event("Notify"):FireClient(player, "La linterna se ha apagado", "warn")
						end
					end
				end
			end
		end
	end)

	-- EMF: solo se envía al dueño del detector.
	task.spawn(function()
		while true do
			task.wait(I.EmfInterval)
			if ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
				continue
			end
			local anomaly = PlayerUtil.Anomaly()
			local anomalyRoot = if anomaly then PlayerUtil.Root(anomaly) else nil
			local morphed = anomaly ~= nil and MorphService.IsMorphed(anomaly)
			for _, player in PlayerUtil.Investigators() do
				if player:GetAttribute("EquippedTool") == Enums.Tool.EMF then
					local root = PlayerUtil.Root(player)
					local level = 0
					if root and anomalyRoot then
						level = emfLevel((anomalyRoot.Position - root.Position).Magnitude, morphed)
					end
					Remotes.Event("EmfReading"):FireClient(player, level)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPhoto[player] = nil
		sprintWanted[player] = nil
		sneakWanted[player] = nil
		moveNoise[player] = nil
	end)
end

return ToolService
