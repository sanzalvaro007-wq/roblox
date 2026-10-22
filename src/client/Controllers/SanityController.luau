--!strict
-- Alucinaciones SOLO en este cliente, según el atributo "Sanity" (autoritativo en el servidor).
-- Nada de esto existe para los demás jugadores ni para el servidor:
--   < Mild:   pasos falsos detrás de ti, color apagado
--   < Strong: figuras en la penumbra que desaparecen al mirarlas, lámparas que fallan
--   < Severe: muebles que se te acercan, el EMF miente, visión borrosa

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local PropCatalog = require(Shared:WaitForChild("PropCatalog"))

local UIController = require(script.Parent:WaitForChild("UIController"))
local AmbienceController = require(script.Parent:WaitForChild("AmbienceController"))

local S = Config.Sanity
local player = Players.LocalPlayer

local SanityController = {}

local grade: ColorCorrectionEffect
local blur: BlurEffect
local folder: Folder? = nil

local function sanity(): number?
	local state = ReplicatedStorage:GetAttribute("RoundState")
	if state ~= Enums.RoundState.Playing then
		return nil
	end
	if player:GetAttribute("Role") ~= Enums.Role.Investigator or player:GetAttribute("Alive") ~= true then
		return nil
	end
	if player:GetAttribute("Escaped") == true then
		return nil
	end
	local value = player:GetAttribute("Sanity")
	return if typeof(value) == "number" then value else nil
end

local function root(): BasePart?
	local character = player.Character
	local r = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if r and r:IsA("BasePart") then r else nil
end

local function hallucinationFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Hallucinations"
	f.Parent = workspace.CurrentCamera
	folder = f
	return f
end

local function ghostPart(size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = hallucinationFolder()
	return p
end

-- Busca un punto en el suelo a `distance` studs en una dirección aleatoria, con visión directa.
local function findSpot(origin: Vector3, minDist: number, maxDist: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { hallucinationFolder() }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	for _ = 1, 8 do
		local angle = math.random() * math.pi * 2
		local dist = minDist + math.random() * (maxDist - minDist)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)) * dist
		if not workspace:Raycast(origin, dir, params) then
			local down = workspace:Raycast(origin + dir, Vector3.new(0, -10, 0), params)
			if down then
				return down.Position
			end
		end
	end
	return nil
end

local function fakeFootsteps(r: BasePart)
	local behind = r.Position - r.CFrame.LookVector * 8 + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
	local anchor = ghostPart(Vector3.one, CFrame.new(behind), Color3.new())
	anchor.Transparency = 1
	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds.Footstep
	sound.Volume = 0.8
	sound.RollOffMaxDistance = 40
	sound.Looped = true
	sound.PlaybackSpeed = 1.2
	sound.Parent = anchor
	sound:Play()
	task.delay(1.6 + math.random(), function()
		anchor:Destroy()
	end)
end

local function shadowFigure(r: BasePart)
	local spot = findSpot(r.Position, 18, 30)
	if not spot then
		return
	end
	local body = ghostPart(Vector3.new(1.6, 6, 0.8), CFrame.lookAt(spot + Vector3.new(0, 3, 0), r.Position), Color3.fromRGB(5, 5, 5))
	body.Transparency = 0.15
	local eyes = ghostPart(Vector3.new(0.8, 0.1, 0.05), body.CFrame * CFrame.new(0, 2.4, -0.45), Color3.fromRGB(255, 40, 40))
	eyes.Material = Enum.Material.Neon
	local spawned = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local toFigure = (body.Position - camera.CFrame.Position).Unit
		-- Desaparece cuando la miras directamente o tras unos segundos.
		if camera.CFrame.LookVector:Dot(toFigure) > 0.93 or os.clock() - spawned > 3.5 then
			conn:Disconnect()
			body:Destroy()
			eyes:Destroy()
		end
	end)
end

local function creepingProp(r: BasePart)
	local spot = findSpot(r.Position, 10, 16)
	if not spot then
		return
	end
	local def = PropCatalog.List[math.random(1, #PropCatalog.List)]
	local model = PropCatalog.Build(def.id)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local target = r.Position * Vector3.new(1, 0, 1) + Vector3.new(0, spot.Y, 0)
	local start = CFrame.lookAt(spot, target)
	model:PivotTo(start)
	model.Parent = hallucinationFolder()
	local value = Instance.new("CFrameValue")
	value.Value = start
	value.Changed:Connect(function(cf)
		model:PivotTo(cf)
	end)
	local finish = start:Lerp(CFrame.lookAt(target, target + start.LookVector), 0.75)
	local tween = TweenService:Create(value, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = finish })
	tween:Play()
	tween.Completed:Once(function()
		UIController.Flash(Color3.fromRGB(120, 0, 0), 0.5, 0.2)
		model:Destroy()
		value:Destroy()
	end)
end

local function scheduler()
	while true do
		task.wait(1)
		local s = sanity()
		local r = root()
		if not s or not r then
			continue
		end
		if s < S.Mild and math.random() < 0.08 then
			fakeFootsteps(r)
		end
		if s < S.Strong then
			if math.random() < 0.06 then
				shadowFigure(r)
			end
			if math.random() < 0.05 then
				AmbienceController.Burst(r.Position, 1.2)
			end
		end
		if s < S.Severe then
			if math.random() < 0.04 then
				creepingProp(r)
			end
			if math.random() < 0.15 then
				-- El EMF "miente": el servidor lo corregirá en la siguiente lectura.
				UIController.EmfLevel = math.random(3, 5)
			end
		end
	end
end

local function updateEffects()
	local s = sanity()
	local ratio = if s then 1 - s / S.Max else 0
	grade.Saturation = -0.7 * ratio
	grade.Contrast = 0.25 * ratio
	grade.TintColor = Color3.new(1, 1 - 0.15 * ratio, 1 - 0.1 * ratio)
	if s and s < S.Severe then
		blur.Size = 4 + math.sin(os.clock() * 2) * 3
	else
		blur.Size = 0
	end
end

function SanityController.Start()
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "SanityGrade"
	grade.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "SanityBlur"
	blur.Size = 0
	blur.Parent = Lighting
	RunService.RenderStepped:Connect(updateEffects)
	task.spawn(scheduler)
end

return SanityController
