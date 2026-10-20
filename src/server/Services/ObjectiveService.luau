--!strict
-- Objetivos de los Investigadores: recoger fusibles, colocarlos en la caja,
-- restaurar la energía y escapar por la puerta principal.
-- Los ProximityPrompt se disparan en el servidor, y aun así validamos rol y estado.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerUtil = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("PlayerUtil"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local ToolService = require(script.Parent:WaitForChild("ToolService"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))

type Mansion = {
	Model: Model,
	FuseSpawns: { Vector3 },
	BatterySpawns: { Vector3 },
	FuseBox: CFrame,
	Exit: CFrame,
	Lamps: { BasePart },
}

local O = Config.Objectives

local ObjectiveService = {}

local folder: Folder? = nil
local exitPrompt: ProximityPrompt? = nil
local fuseLights: { BasePart } = {}
local lamps: { BasePart } = {}

local function roundPlaying(): boolean
	return ReplicatedStorage:GetAttribute("RoundState") == Enums.RoundState.Playing
end

local function notifyAll(text: string, kind: string?)
	Remotes.Event("Notify"):FireAllClients(text, kind)
end

local function makePrompt(parent: BasePart, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = true
	-- Sin clic: si el aviso es clicable, en primera persona captura el ratón y la cámara
	-- se queda bloqueada mientras lo miras.
	prompt.ClickablePrompt = false
	prompt.Parent = parent
	return prompt
end

local function setCarrying(player: Player, carrying: boolean)
	player:SetAttribute("CarryingFuse", carrying)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild("CarriedFuse")
	if existing then
		existing:Destroy()
	end
	local root = PlayerUtil.Root(player)
	if carrying and root then
		local fuse = Instance.new("Part")
		fuse.Name = "CarriedFuse"
		fuse.Size = Vector3.new(0.4, 0.8, 0.4)
		fuse.Material = Enum.Material.Metal
		fuse.Color = Color3.fromRGB(200, 160, 60)
		fuse.CanCollide = false
		fuse.CanQuery = false
		fuse.Massless = true
		fuse.CFrame = root.CFrame * CFrame.new(0.9, -0.3, -0.6)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = fuse
		weld.Parent = fuse
		fuse.Parent = character
	end
end

local function spawnFuse(position: Vector3)
	if not folder then
		return
	end
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Anchored = true
	fuse.CanCollide = false
	fuse.Size = Vector3.new(0.6, 1.2, 0.6)
	-- Discreto a propósito: hay que buscarlo con la linterna.
	fuse.Material = Enum.Material.Metal
	fuse.Color = Color3.fromRGB(200, 160, 60)
	fuse.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0))
	local glow = Instance.new("PointLight")
	glow.Range = 3
	glow.Brightness = 0.15
	glow.Color = fuse.Color
	glow.Parent = fuse
	local prompt = makePrompt(fuse, "Recoger", "Fusible", 0)
	prompt.Triggered:Connect(function(player)
		if not roundPlaying() or not PlayerUtil.IsInvestigator(player) then
			return
		end
		if player:GetAttribute("CarryingFuse") == true then
			Remotes.Event("Notify"):FireClient(player, "Ya llevas un fusible", "warn")
			return
		end
		if fuse.Parent == nil then
			return
		end
		fuse:Destroy()
		setCarrying(player, true)
		Remotes.Event("Notify"):FireClient(player, "Fusible recogido. Llévalo a la caja de fusibles", "info")
	end)
	fuse.Parent = folder
end

local function spawnBattery(position: Vector3)
	if not folder then
		return
	end
	local battery = Instance.new("Part")
	battery.Name = "Battery"
	battery.Anchored = true
	battery.CanCollide = false
	battery.Size = Vector3.new(0.5, 1, 0.5)
	battery.Material = Enum.Material.Metal
	battery.Color = Color3.fromRGB(60, 120, 200)
	battery.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
	local prompt = makePrompt(battery, "Recoger", "Pila", 0)
	prompt.Triggered:Connect(function(player)
		if not roundPlaying() or not PlayerUtil.IsInvestigator(player) or battery.Parent == nil then
			return
		end
		battery:Destroy()
		ToolService.AddBattery(player, Config.Investigator.BatteryPickupAmount)
		Remotes.Event("Notify"):FireClient(player, "+" .. Config.Investigator.BatteryPickupAmount .. "% de batería", "info")
	end)
	battery.Parent = folder
end

local function setPower(on: boolean)
	ReplicatedStorage:SetAttribute("PowerOn", on)
	for _, lamp in lamps do
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = if on then 1.6 else 0.6
			light.Range = if on then 30 else 24
		end
		if on then
			lamp:SetAttribute("Flicker", false)
		end
	end
	if exitPrompt then
		exitPrompt.Enabled = on
	end
end

local function updateFuseLights()
	local inserted = ReplicatedStorage:GetAttribute("FusesInserted") or 0
	for i, indicator in fuseLights do
		indicator.Color = if i <= inserted then Color3.fromRGB(80, 255, 100) else Color3.fromRGB(80, 20, 20)
	end
end

local function buildFuseBox(cf: CFrame, required: number)
	if not folder then
		return
	end
	local box = Instance.new("Part")
	box.Name = "FuseBox"
	box.Anchored = true
	box.Size = Vector3.new(3, 4, 0.8)
	box.CFrame = cf
	box.Material = Enum.Material.CorrodedMetal
	box.Color = Color3.fromRGB(70, 75, 70)
	box.Parent = folder
	CollectionService:AddTag(box, "FuseBox")
	fuseLights = {}
	for i = 1, required do
		local indicator = Instance.new("Part")
		indicator.Name = "Slot" .. i
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.Size = Vector3.new(0.35, 0.35, 0.1)
		indicator.Material = Enum.Material.Neon
		local x = (i - (required + 1) / 2) * 0.45
		indicator.CFrame = cf * CFrame.new(x, 1.4, -0.45)
		indicator.Parent = folder
		table.insert(fuseLights, indicator)
	end
	updateFuseLights()

	local prompt = makePrompt(box, "Colocar fusible", "Caja de fusibles", O.FuseInsertHold)
	prompt.Triggered:Connect(function(player)
		if not roundPlaying() or not PlayerUtil.IsInvestigator(player) then
			return
		end
		if player:GetAttribute("CarryingFuse") ~= true then
			Remotes.Event("Notify"):FireClient(player, "Necesitas un fusible", "warn")
			return
		end
		local inserted = (ReplicatedStorage:GetAttribute("FusesInserted") or 0) :: number
		local needed = (ReplicatedStorage:GetAttribute("FusesRequired") or 0) :: number
		if inserted >= needed then
			return
		end
		setCarrying(player, false)
		EconomyService.Award(player, ShopCatalog.Rewards.Fuse, "Fusibles colocados")
		inserted += 1
		ReplicatedStorage:SetAttribute("FusesInserted", inserted)
		updateFuseLights()
		if inserted >= needed then
			setPower(true)
			notifyAll("¡Energía restaurada! La puerta principal se ha desbloqueado", "success")
		else
			notifyAll(string.format("Fusible colocado (%d/%d)", inserted, needed), "info")
		end
	end)
end

local function buildExit(cf: CFrame)
	if not folder then
		return
	end
	local door = Instance.new("Part")
	door.Name = "ExitDoor"
	door.Anchored = true
	door.Size = Vector3.new(Config.Mansion.DoorWidth, Config.Mansion.DoorHeight, 0.6)
	door.CFrame = cf
	door.Material = Enum.Material.Wood
	door.Color = Color3.fromRGB(70, 25, 20)
	door.Parent = folder
	CollectionService:AddTag(door, "ExitDoor")
	local prompt = makePrompt(door, "Escapar", "Puerta principal", O.EscapeHold)
	prompt.Enabled = false
	prompt.Triggered:Connect(function(player)
		if not roundPlaying() or not PlayerUtil.IsInvestigator(player) then
			return
		end
		if ReplicatedStorage:GetAttribute("PowerOn") ~= true then
			return
		end
		ObjectiveService.Escape(player)
	end)
	exitPrompt = prompt
end

function ObjectiveService.Escape(player: Player)
	player:SetAttribute("Escaped", true)
	EconomyService.Award(player, ShopCatalog.Rewards.Escape, "Escape")
	DataService.AddStat(player, "escapes", 1)
	setCarrying(player, false)
	ToolService.Reset(player)
	CharacterService.MoveToLobby(player)
	ReplicatedStorage:SetAttribute("Escaped", (ReplicatedStorage:GetAttribute("Escaped") or 0) + 1)
	notifyAll(player.DisplayName .. " ha escapado de la mansión", "success")
end

-- Un Investigador muere o se va: suelta su fusible donde estaba.
function ObjectiveService.DropFuse(player: Player, position: Vector3?)
	if player:GetAttribute("CarryingFuse") == true then
		player:SetAttribute("CarryingFuse", false)
		if position then
			spawnFuse(position - Vector3.new(0, 2.5, 0))
		end
	end
end

function ObjectiveService.FusesRequiredFor(investigators: number): number
	return math.min(O.FusesMax, O.FusesBase + investigators // O.FusesPerInvestigators)
end

function ObjectiveService.Setup(mansion: Mansion, investigators: number)
	ObjectiveService.Cleanup()
	local f = Instance.new("Folder")
	f.Name = "Objectives"
	f.Parent = mansion.Model
	folder = f
	lamps = mansion.Lamps

	local required = ObjectiveService.FusesRequiredFor(investigators)
	ReplicatedStorage:SetAttribute("FusesRequired", required)
	ReplicatedStorage:SetAttribute("FusesInserted", 0)
	ReplicatedStorage:SetAttribute("Escaped", 0)

	buildFuseBox(mansion.FuseBox, required)
	buildExit(mansion.Exit)
	setPower(false)

	-- Un fusible de repuesto para que una mala racha no bloquee la partida.
	local spots = table.clone(mansion.FuseSpawns)
	for i = #spots, 2, -1 do
		local j = math.random(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	for i = 1, required + 1 do
		local base = spots[((i - 1) % math.max(1, #spots)) + 1]
		if base then
			local extra = if i > #spots then Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)) else Vector3.zero
			spawnFuse(base + extra)
		end
	end

	local batterySpots = table.clone(mansion.BatterySpawns)
	for i = #batterySpots, 2, -1 do
		local j = math.random(1, i)
		batterySpots[i], batterySpots[j] = batterySpots[j], batterySpots[i]
	end
	for i = 1, math.min(O.BatteryPickups, #batterySpots) do
		spawnBattery(batterySpots[i])
	end
end

function ObjectiveService.Cleanup()
	if folder then
		folder:Destroy()
	end
	folder = nil
	exitPrompt = nil
	fuseLights = {}
	lamps = {}
	ReplicatedStorage:SetAttribute("PowerOn", false)
	ReplicatedStorage:SetAttribute("FusesInserted", 0)
	ReplicatedStorage:SetAttribute("FusesRequired", 0)
end

function ObjectiveService.ResetPlayer(player: Player)
	setCarrying(player, false)
	player:SetAttribute("CarryingFuse", nil)
end

return ObjectiveService
