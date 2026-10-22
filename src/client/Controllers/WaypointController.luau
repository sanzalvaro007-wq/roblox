--!strict
-- Marcadores para Investigadores: la caja de fusibles mientras llevas un fusible y la
-- puerta principal cuando vuelve la energía. Se ven a través de las paredes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

local WaypointController = {}

type Marker = { gui: BillboardGui, text: TextLabel }

local markers: { [string]: Marker } = {}

local function marker(name: string, color: Color3): Marker
	local gui = Instance.new("BillboardGui")
	gui.Name = "Waypoint_" .. name
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(200, 44)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.Enabled = false
	local text = UIController.Label({
		TextSize = 18,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, text = text }
end

local function first(tag: string): BasePart?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			return inst
		end
	end
	return nil
end

local function show(m: Marker, target: BasePart?, title: string)
	if not target then
		m.gui.Enabled = false
		return
	end
	m.gui.Adornee = target
	m.gui.Enabled = true
	local camera = workspace.CurrentCamera
	local meters = math.floor((target.Position - camera.CFrame.Position).Magnitude * 0.28 + 0.5)
	m.text.Text = string.format("▼ %s · %d m", title, meters)
end

local function step()
	local investigating = player:GetAttribute("Role") == Enums.Role.Investigator
		and player:GetAttribute("Alive") == true
		and player:GetAttribute("Escaped") ~= true
		and ReplicatedStorage:GetAttribute("RoundState") == Enums.RoundState.Playing
	local powerOn = ReplicatedStorage:GetAttribute("PowerOn") == true
	local carrying = player:GetAttribute("CarryingFuse") == true

	if investigating and carrying and not powerOn then
		show(markers.FuseBox, first("FuseBox"), "Caja de fusibles")
	else
		markers.FuseBox.gui.Enabled = false
	end
	if investigating and powerOn then
		show(markers.Exit, first("ExitDoor"), "Salida")
	else
		markers.Exit.gui.Enabled = false
	end
end

function WaypointController.Start()
	markers.FuseBox = marker("FuseBox", Color3.fromRGB(255, 210, 90))
	markers.Exit = marker("Exit", Color3.fromRGB(130, 240, 150))
	RunService.RenderStepped:Connect(step)
end

return WaypointController
