--!strict
-- Huellas de la Anomalía para la luz UV. Son piezas invisibles (Transparency 1) que el
-- cliente con la UV equipada vuelve visibles solo para sí mismo, dentro de su alcance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))

local PlayerUtil = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("PlayerUtil"))
local MansionService = require(script.Parent:WaitForChild("MansionService"))

local I = Config.Investigator

local FootprintService = {}

local prints: { BasePart } = {}
local leftFoot = false

local function clearOld()
	local now = workspace:GetServerTimeNow()
	for i = #prints, 1, -1 do
		local p = prints[i]
		local created = p:GetAttribute("CreatedAt")
		if p.Parent == nil or typeof(created) ~= "number" or now - created > I.FootprintLifetime then
			p:Destroy()
			table.remove(prints, i)
		end
	end
	while #prints > I.FootprintMax do
		local oldest = table.remove(prints, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

local function step()
	if ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
		return
	end
	local mansion = MansionService.Get()
	local anomaly = PlayerUtil.Anomaly()
	if not mansion or not anomaly or not anomaly.Character then
		return
	end
	local root = PlayerUtil.Root(anomaly)
	local humanoid = PlayerUtil.Humanoid(anomaly)
	if not root or not humanoid or humanoid.MoveDirection.Magnitude < 0.1 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mansion.Model }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params)
	if not hit then
		return
	end
	leftFoot = not leftFoot
	local forward = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	forward = if forward.Magnitude > 0 then forward.Unit else Vector3.new(0, 0, -1)
	local side = forward:Cross(Vector3.yAxis) * (if leftFoot then -0.5 else 0.5)
	local pos = hit.Position + side + Vector3.new(0, 0.03, 0)
	local footprint = Instance.new("Part")
	footprint.Name = "Footprint"
	footprint.Anchored = true
	footprint.CanCollide = false
	footprint.CanQuery = false
	footprint.CanTouch = false
	footprint.CastShadow = false
	footprint.Transparency = 1
	footprint.Material = Enum.Material.Neon
	footprint.Color = Color3.fromRGB(170, 90, 255)
	footprint.Size = Vector3.new(0.7, 0.05, 1.2)
	footprint.CFrame = CFrame.lookAt(pos, pos + forward)
	footprint:SetAttribute("CreatedAt", workspace:GetServerTimeNow())
	footprint:AddTag("Footprint")
	footprint.Parent = mansion.Model
	table.insert(prints, footprint)
	clearOld()
end

function FootprintService.Init()
	task.spawn(function()
		while true do
			task.wait(I.FootprintInterval)
			step()
		end
	end)
end

return FootprintService
