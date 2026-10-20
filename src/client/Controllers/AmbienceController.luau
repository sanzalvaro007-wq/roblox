--!strict
-- Parpadeo de lámparas en el cliente (sin tráfico de red). El servidor marca qué
-- lámparas parpadean con el atributo "Flicker"; la cordura baja puede provocar ráfagas.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AmbienceController = {}

local burstUntil = 0
local burstCenter: Vector3? = nil
local BURST_RADIUS = 40

-- Ráfaga de parpadeo local alrededor de `center` (alucinación o susto).
function AmbienceController.Burst(center: Vector3, duration: number)
	burstCenter = center
	burstUntil = os.clock() + duration
end

local function step()
	local now = os.clock()
	local bursting = now < burstUntil
	for _, lamp in CollectionService:GetTagged("MansionLamp") do
		if not lamp:IsA("BasePart") then
			continue
		end
		local light = lamp:FindFirstChildOfClass("PointLight")
		if not light then
			continue
		end
		local flicker = lamp:GetAttribute("Flicker") == true
		local ghostUntil = lamp:GetAttribute("GhostUntil")
		local haunted = typeof(ghostUntil) == "number" and ghostUntil > workspace:GetServerTimeNow()
		local inBurst = bursting and burstCenter ~= nil and (lamp.Position - burstCenter).Magnitude <= BURST_RADIUS
		if haunted then
			-- Un fantasma la ha apagado; parpadea justo antes de volver.
			local left = (ghostUntil :: number) - workspace:GetServerTimeNow()
			light.Enabled = left < 1 and math.random() > 0.5
		elseif inBurst then
			light.Enabled = math.random() > 0.5
		elseif flicker then
			-- Encendida casi siempre, con cortes cortos e irregulares.
			local n = math.noise(lamp.Position.X * 0.1, lamp.Position.Z * 0.1, now * 3)
			light.Enabled = n > -0.35
		else
			light.Enabled = true
		end
		lamp.Material = if light.Enabled then Enum.Material.Neon else Enum.Material.SmoothPlastic
		for _, flame in lamp:GetChildren() do
			if flame:IsA("BasePart") and flame.Name == "Flame" then
				flame.Transparency = if light.Enabled then 0 else 1
			end
		end
	end

	-- Los ojos de los cuadros se encienden cuando tu cordura baja.
	local sanity = Players.LocalPlayer:GetAttribute("Sanity")
	local fear = if typeof(sanity) == "number" then math.clamp((60 - sanity) / 45, 0, 1) else 0
	local pulse = 0.75 + 0.25 * math.sin(now * 2)
	local eyeColor = Color3.fromRGB(70, 10, 10):Lerp(Color3.fromRGB(255, 40, 30), fear * pulse)
	for _, e in CollectionService:GetTagged("PaintingEye") do
		if e:IsA("Frame") then
			e.BackgroundColor3 = eyeColor
		end
	end
end

function AmbienceController.Start()
	RunService.Heartbeat:Connect(step)
end

return AmbienceController
