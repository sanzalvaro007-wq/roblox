--!strict
-- Decoración de la mansión: lámparas de araña colgadas del techo y cuadros inquietantes.
-- Los cuadros se pintan con Frames en un SurfaceGui (sin imágenes subidas) y son 13+:
-- dan mal rollo, sin sangre ni gore. Los ojos llevan la etiqueta "PaintingEye" para que el
-- cliente los haga brillar cuando la cordura baja.

local CollectionService = game:GetService("CollectionService")

local Decor = {}

local BRASS = Color3.fromRGB(150, 118, 70)
local FRAME_WOOD = Color3.fromRGB(45, 30, 22)

local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Araña de bronce con velas. Devuelve la pieza "Lamp" (globo central con la luz), que es
-- la que parpadea y apagan los fantasmas; las llamas son hijas suyas y se apagan con ella.
function Decor.Chandelier(parent: Instance, ceilingPoint: Vector3): Part
	local model = Instance.new("Model")
	model.Name = "Chandelier"
	model.Parent = parent
	local drop = 3.2
	local center = ceilingPoint - Vector3.new(0, drop, 0)
	piece(model, "Chain", Vector3.new(0.15, drop - 0.4, 0.15), CFrame.new(ceilingPoint - Vector3.new(0, (drop - 0.4) / 2, 0)), BRASS, Enum.Material.Metal)
	piece(model, "Canopy", Vector3.new(0.3, 1.2, 1.2), CFrame.new(ceilingPoint - Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), BRASS, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	local ring = piece(model, "Ring", Vector3.new(0.2, 4, 4), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), BRASS, Enum.Material.Metal)
	ring.Shape = Enum.PartType.Cylinder

	local lamp = piece(model, "Lamp", Vector3.new(1.1, 1.1, 1.1), CFrame.new(center + Vector3.new(0, 0.35, 0)), Color3.fromRGB(255, 200, 140), Enum.Material.Neon)
	lamp.Shape = Enum.PartType.Ball
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		local at = center + Vector3.new(math.cos(a) * 1.85, 0, math.sin(a) * 1.85)
		piece(model, "Candle", Vector3.new(0.6, 0.25, 0.25), CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(225, 215, 190), Enum.Material.SmoothPlastic).Shape =
			Enum.PartType.Cylinder
		local flame = piece(lamp, "Flame", Vector3.new(0.15, 0.25, 0.15), CFrame.new(at + Vector3.new(0, 0.85, 0)), Color3.fromRGB(255, 190, 110), Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
	end
	return lamp
end

-- Pinceles para los cuadros (posiciones y tamaños en escala 0-1 del lienzo).
local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, round: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = f
	end
	f.Parent = parent
	return f
end

local function eye(parent: Instance, x: number, y: number, size: number)
	local e = rect(parent, x, y, size, size * 0.7, Color3.fromRGB(70, 10, 10), 0.5)
	e.Name = "Eye"
	CollectionService:AddTag(e, "PaintingEye")
end

local function gradient(parent: Frame, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

local PAINTINGS: { (Frame) -> () } = {
	-- Retrato de una dama sin cara.
	function(c)
		gradient(c, Color3.fromRGB(40, 32, 30), Color3.fromRGB(12, 10, 10))
		rect(c, 0.5, 0.95, 0.9, 0.5, Color3.fromRGB(25, 20, 28), 0.45) -- vestido
		rect(c, 0.5, 0.67, 0.14, 0.12, Color3.fromRGB(150, 140, 130)) -- cuello
		rect(c, 0.5, 0.4, 0.4, 0.42, Color3.fromRGB(30, 22, 18), 0.5) -- pelo
		rect(c, 0.5, 0.44, 0.3, 0.34, Color3.fromRGB(170, 160, 150), 0.5) -- cara lisa
	end,
	-- Retrato de un caballero con los ojos negros.
	function(c)
		gradient(c, Color3.fromRGB(35, 40, 35), Color3.fromRGB(10, 12, 10))
		rect(c, 0.5, 0.95, 0.95, 0.5, Color3.fromRGB(18, 18, 20), 0.4) -- chaqueta
		rect(c, 0.5, 0.72, 0.12, 0.12, Color3.fromRGB(200, 195, 185)) -- camisa
		rect(c, 0.5, 0.42, 0.32, 0.38, Color3.fromRGB(150, 135, 120), 0.5) -- cara
		rect(c, 0.5, 0.26, 0.36, 0.12, Color3.fromRGB(20, 15, 12), 0.5) -- pelo
		rect(c, 0.42, 0.42, 0.08, 0.06, Color3.fromRGB(5, 5, 5), 0.5)
		rect(c, 0.58, 0.42, 0.08, 0.06, Color3.fromRGB(5, 5, 5), 0.5)
		eye(c, 0.42, 0.42, 0.03)
		eye(c, 0.58, 0.42, 0.03)
		rect(c, 0.5, 0.55, 0.12, 0.015, Color3.fromRGB(60, 30, 30)) -- boca
	end,
	-- La figura alta del bosque.
	function(c)
		gradient(c, Color3.fromRGB(45, 50, 60), Color3.fromRGB(15, 18, 20))
		for i, x in { 0.1, 0.22, 0.78, 0.9, 0.33, 0.66 } do
			rect(c, x, 0.55, 0.035 + (i % 2) * 0.015, 1.1, Color3.fromRGB(12, 12, 14)) -- árboles
		end
		rect(c, 0.5, 0.62, 0.08, 0.6, Color3.fromRGB(5, 5, 6)) -- cuerpo
		rect(c, 0.5, 0.28, 0.08, 0.09, Color3.fromRGB(5, 5, 6), 0.5) -- cabeza
		rect(c, 0.44, 0.55, 0.015, 0.45, Color3.fromRGB(5, 5, 6)) -- brazos largos
		rect(c, 0.56, 0.55, 0.015, 0.45, Color3.fromRGB(5, 5, 6))
		eye(c, 0.485, 0.28, 0.015)
		eye(c, 0.515, 0.28, 0.015)
		rect(c, 0.5, 0.97, 1, 0.08, Color3.fromRGB(10, 12, 10)) -- suelo
	end,
	-- La mansión de noche con una ventana encendida.
	function(c)
		gradient(c, Color3.fromRGB(30, 30, 45), Color3.fromRGB(8, 8, 12))
		rect(c, 0.75, 0.18, 0.14, 0.11, Color3.fromRGB(200, 200, 180), 0.5) -- luna
		rect(c, 0.5, 0.68, 0.7, 0.45, Color3.fromRGB(8, 8, 10)) -- casa
		rect(c, 0.3, 0.38, 0.12, 0.25, Color3.fromRGB(8, 8, 10)) -- torre
		rect(c, 0.3, 0.24, 0.16, 0.06, Color3.fromRGB(8, 8, 10))
		local window = rect(c, 0.62, 0.6, 0.06, 0.08, Color3.fromRGB(200, 150, 70))
		window.Name = "Window"
		rect(c, 0.62, 0.6, 0.025, 0.05, Color3.fromRGB(10, 8, 8)) -- alguien mirando
		rect(c, 0.5, 0.95, 1, 0.1, Color3.fromRGB(12, 14, 12))
	end,
	-- Oscuridad llena de ojos.
	function(c)
		c.BackgroundColor3 = Color3.fromRGB(6, 5, 6)
		local spots = { { 0.2, 0.2 }, { 0.7, 0.15 }, { 0.45, 0.4 }, { 0.15, 0.6 }, { 0.8, 0.55 }, { 0.35, 0.8 }, { 0.65, 0.85 } }
		for _, s in spots do
			eye(c, s[1] - 0.04, s[2], 0.04)
			eye(c, s[1] + 0.04, s[2], 0.04)
		end
	end,
	-- Niña con muñeca, de espaldas.
	function(c)
		gradient(c, Color3.fromRGB(50, 40, 35), Color3.fromRGB(15, 12, 10))
		rect(c, 0.5, 0.92, 1, 0.16, Color3.fromRGB(35, 25, 20)) -- suelo
		rect(c, 0.5, 0.68, 0.24, 0.36, Color3.fromRGB(150, 145, 140), 0.35) -- vestido
		rect(c, 0.5, 0.42, 0.18, 0.18, Color3.fromRGB(25, 18, 14), 0.5) -- pelo
		rect(c, 0.5, 0.52, 0.2, 0.12, Color3.fromRGB(25, 18, 14), 0.3) -- melena
		rect(c, 0.68, 0.74, 0.08, 0.12, Color3.fromRGB(170, 160, 150), 0.4) -- muñeca
		rect(c, 0.68, 0.66, 0.07, 0.06, Color3.fromRGB(190, 180, 170), 0.5)
		eye(c, 0.665, 0.66, 0.012)
		eye(c, 0.695, 0.66, 0.012)
	end,
}

-- Cuadro colgado en una pared; `cf` mira hacia la sala (el lienzo está en su cara frontal).
function Decor.Painting(parent: Instance, cf: CFrame, kind: number)
	local model = Instance.new("Model")
	model.Name = "Painting"
	model.Parent = parent
	local w, h = 3.6, 4.6
	piece(model, "Frame", Vector3.new(w + 0.6, h + 0.6, 0.3), cf, FRAME_WOOD, Enum.Material.Wood)
	piece(model, "Gilt", Vector3.new(w + 0.2, h + 0.2, 0.32), cf * CFrame.new(0, 0, -0.02), BRASS, Enum.Material.Metal)
	local canvas = piece(model, "Canvas", Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, -0.16), Color3.fromRGB(20, 18, 16), Enum.Material.Fabric)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.MaxDistance = 80
	gui.Parent = canvas
	local c = Instance.new("Frame")
	c.Size = UDim2.fromScale(1, 1)
	c.BorderSizePixel = 0
	c.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	c.ClipsDescendants = true
	c.Parent = gui
	PAINTINGS[((kind - 1) % #PAINTINGS) + 1](c)
	CollectionService:AddTag(canvas, "CreepyPainting")
end

Decor.PaintingCount = #PAINTINGS

return Decor
