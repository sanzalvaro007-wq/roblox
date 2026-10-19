--!strict
-- Iluminación nocturna base. La tecnología Future se fija en default.project.json
-- (no se puede cambiar desde scripts). Los efectos de cordura son locales del cliente.

local Lighting = game:GetService("Lighting")

local AtmosphereService = {}

function AtmosphereService.Init()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.2
	Lighting.Ambient = Color3.fromRGB(8, 8, 12)
	Lighting.OutdoorAmbient = Color3.fromRGB(18, 18, 26)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ExposureCompensation = -0.2
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.45
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(40, 42, 50)
	atmosphere.Decay = Color3.fromRGB(20, 20, 28)
	atmosphere.Glare = 0
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting

	local grade = Lighting:FindFirstChild("BaseGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "BaseGrade"
	if grade:IsA("ColorCorrectionEffect") then
		grade.Saturation = -0.35
		grade.Contrast = 0.15
		grade.TintColor = Color3.fromRGB(235, 225, 210)
	end
	grade.Parent = Lighting
end

return AtmosphereService
