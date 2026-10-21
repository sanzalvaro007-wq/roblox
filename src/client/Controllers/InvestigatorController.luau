--!strict
-- Controles del Investigador (PC, mando y móvil). Solo envía peticiones;
-- el servidor valida batería, carrete, cooldowns y si la foto acierta.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DoorController = require(script.Parent:WaitForChild("DoorController"))
local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

local InvestigatorController = {}

local bound = false
local sneaking = false
local localLightPart: Part? = nil

local function active(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	return player:GetAttribute("Role") == Enums.Role.Investigator
		and player:GetAttribute("Alive") == true
		and player:GetAttribute("Escaped") ~= true
		and (state == Enums.RoundState.Playing or state == Enums.RoundState.Preparing)
end

local function equip(tool: string)
	local current = player:GetAttribute("EquippedTool")
	Remotes.Event("EquipTool"):FireServer(if current == tool then Enums.Tool.None else tool)
end

local function playSound(id: string, volume: number)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = workspace.CurrentCamera
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		sound:Destroy()
	end)
end

local function takePhoto()
	if player:GetAttribute("EquippedTool") ~= Enums.Tool.Camera then
		return
	end
	local film = player:GetAttribute("Film")
	if typeof(film) ~= "number" or film <= 0 then
		UIController.Toast("No te queda carrete", "warn")
		return
	end
	local camera = workspace.CurrentCamera
	Remotes.Event("TakePhoto"):FireServer(camera.CFrame.LookVector)
	UIController.Flash(Color3.new(1, 1, 1), 0.35, 0.1)
	playSound(Config.Sounds.Shutter, 0.6)
end

-- ¿Saldría la Anomalía en la foto? Solo cuenta si se la ve (sin disfraz): entonces el clic
-- dispara el flash aunque detrás haya una puerta. Imita ToolService.canSee.
local function anomalyInShot(): boolean
	if not active() or ReplicatedStorage:GetAttribute("RoundState") ~= Enums.RoundState.Playing then
		return false
	end
	local film = player:GetAttribute("Film")
	if player:GetAttribute("EquippedTool") ~= Enums.Tool.Camera or typeof(film) ~= "number" or film <= 0 then
		return false
	end
	local camera = workspace.CurrentCamera.CFrame
	local ignore: { Instance } = {}
	local target: Model? = nil
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			if other:GetAttribute("Role") == Enums.Role.Anomaly then
				target = character
			elseif other:GetAttribute("Role") == Enums.Role.Investigator then
				table.insert(ignore, character)
			end
		end
	end
	if not target then
		return false
	end
	local head = target:FindFirstChild("Head")
	local root = target:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") or head.Transparency >= 1 or not root or not root:IsA("BasePart") then
		return false
	end
	local offset = root.Position - camera.Position
	if offset.Magnitude > Config.Investigator.PhotoRange or camera.LookVector:Dot(offset.Unit) < math.cos(math.rad(Config.Investigator.PhotoConeDegrees / 2)) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(camera.Position, offset, params)
	return hit == nil or hit.Instance:IsDescendantOf(target)
end

local function handle(actionName: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if not active() then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "MM_Sprint" then
		if inputState == Enum.UserInputState.Begin then
			Remotes.Event("RequestSprint"):FireServer(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			Remotes.Event("RequestSprint"):FireServer(false)
		end
		return Enum.ContextActionResult.Pass
	end
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "MM_Sneak" then
		sneaking = not sneaking
		Remotes.Event("RequestSneak"):FireServer(sneaking)
		UIController.Toast(if sneaking then "Sigilo: andas en silencio" else "Sigilo desactivado", "info")
	elseif actionName == "MM_EmoteHelp" then
		Remotes.Event("RequestEmote"):FireServer("Help")
	elseif actionName == "MM_EmoteHere" then
		Remotes.Event("RequestEmote"):FireServer("Here")
	elseif actionName == "MM_EmoteRun" then
		Remotes.Event("RequestEmote"):FireServer("Run")
	elseif actionName == "MM_Flashlight" then
		Remotes.Event("ToggleFlashlight"):FireServer(player:GetAttribute("Flashlight") ~= true)
	elseif actionName == "MM_Camera" then
		equip(Enums.Tool.Camera)
	elseif actionName == "MM_EMF" then
		equip(Enums.Tool.EMF)
	elseif actionName == "MM_UV" then
		equip(Enums.Tool.UV)
	elseif actionName == "MM_Trap" then
		Remotes.Event("PlaceTrap"):FireServer()
	elseif actionName == "MM_CycleTool" then
		local current = player:GetAttribute("EquippedTool")
		local nextTool = if current == Enums.Tool.Camera
			then Enums.Tool.EMF
			elseif current == Enums.Tool.EMF then Enums.Tool.UV
			elseif current == Enums.Tool.UV then Enums.Tool.None
			else Enums.Tool.Camera
		Remotes.Event("EquipTool"):FireServer(nextTool)
	elseif actionName == "MM_Use" then
		-- Clic sobre una puerta: abrirla o cerrarla, salvo que la Anomalía salga en la foto.
		if DoorController.TryClick() then
			return Enum.ContextActionResult.Sink
		end
		if player:GetAttribute("EquippedTool") == Enums.Tool.Camera then
			takePhoto()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

local function bind()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindAction("MM_Flashlight", handle, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("MM_Flashlight", "Luz")
	ContextActionService:SetPosition("MM_Flashlight", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindAction("MM_Camera", handle, false, Enum.KeyCode.One, Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("MM_EMF", handle, false, Enum.KeyCode.Two, Enum.KeyCode.DPadRight)
	ContextActionService:BindAction("MM_UV", handle, false, Enum.KeyCode.Three)
	ContextActionService:BindAction("MM_Trap", handle, true, Enum.KeyCode.T)
	ContextActionService:SetTitle("MM_Trap", "Campana")
	ContextActionService:SetPosition("MM_Trap", UDim2.new(1, -290, 1, -150))
	ContextActionService:BindAction("MM_CycleTool", handle, true, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("MM_CycleTool", "Útil")
	ContextActionService:SetPosition("MM_CycleTool", UDim2.new(1, -230, 1, -90))
	ContextActionService:BindAction("MM_Use", handle, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("MM_Use", "Foto")
	ContextActionService:SetPosition("MM_Use", UDim2.new(1, -110, 1, -150))
	ContextActionService:BindAction("MM_Sprint", handle, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("MM_Sprint", "Correr")
	ContextActionService:SetPosition("MM_Sprint", UDim2.new(1, -170, 1, -210))
	ContextActionService:BindAction("MM_Sneak", handle, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("MM_Sneak", "Sigilo")
	ContextActionService:SetPosition("MM_Sneak", UDim2.new(1, -230, 1, -210))
	-- Gritos: la alternativa a la voz. Avisan a los tuyos pero hacen mucho ruido.
	ContextActionService:BindAction("MM_EmoteHelp", handle, true, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle("MM_EmoteHelp", "Grito")
	ContextActionService:SetPosition("MM_EmoteHelp", UDim2.new(1, -110, 1, -210))
	ContextActionService:BindAction("MM_EmoteHere", handle, false, Enum.KeyCode.H)
	ContextActionService:BindAction("MM_EmoteRun", handle, false, Enum.KeyCode.J, Enum.KeyCode.DPadDown)
end

local function unbind()
	if not bound then
		return
	end
	bound = false
	for _, name in {
		"MM_Flashlight",
		"MM_Camera",
		"MM_EMF",
		"MM_UV",
		"MM_Trap",
		"MM_CycleTool",
		"MM_Use",
		"MM_Sprint",
		"MM_Sneak",
		"MM_EmoteHelp",
		"MM_EmoteHere",
		"MM_EmoteRun",
	} do
		ContextActionService:UnbindAction(name)
	end
	sneaking = false
end

local function refresh()
	if active() then
		bind()
	else
		unbind()
	end
end

-- Linterna local que apunta hacia donde mira la cámara. La del servidor, pegada a la
-- cabeza, es la que ven los demás; localmente la apagamos para no duplicar.
-- La pieza va en workspace (no en la cámara): las luces dentro de Camera no siempre iluminan.
-- El foco sale de delante de la cabeza y no de la cámara: en tercera persona la cámara
-- está detrás del personaje y su cuerpo tapaba el haz justo al acercarte a algo.
local AURA_RANGE = 9
local FILL_REACH = 24
local MAX_LIGHT_RANGE = 60 -- límite de Roblox
local WALL_BEAM_RANGE = 6
-- Al pegarte a una pared el foco acaba casi dentro de la cabeza: tu propio cuerpo (o el
-- sombrero) proyectaba sombra y tapaba el haz. Localmente tu personaje no hace sombra.
local shadowlessCharacter: Model? = nil

local function removeOwnShadows(character: Model)
	if shadowlessCharacter == character then
		return
	end
	shadowlessCharacter = character
	local function strip(d: Instance)
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	for _, d in character:GetDescendants() do
		strip(d)
	end
	character.DescendantAdded:Connect(strip)
end

local function lightPart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = parent
	return part
end

local function makeLocalLight(): Part
	local part = lightPart("LocalFlashlight", workspace)
	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Brightness = 3
	beam.Color = Color3.fromRGB(255, 240, 210)
	beam.Shadows = true
	beam.Face = Enum.NormalId.Front
	beam.Parent = part
	-- Luz cercana sin sombras: ilumina lo que tienes pegado delante aunque el cono no llegue.
	local near = Instance.new("PointLight")
	near.Name = "Near"
	near.Range = 8
	near.Brightness = 0.6
	near.Color = beam.Color
	near.Shadows = false
	near.Parent = part
	-- Relleno: una luz puntual justo delante de la superficie a la que apuntas.
	local fill = Instance.new("PointLight")
	fill.Name = "Fill"
	fill.Color = beam.Color
	fill.Shadows = false
	fill.Parent = lightPart("FillAnchor", part)
	-- Halo tenue para ver tus pies y lo que tienes al lado, incluso sin linterna.
	local aura = Instance.new("PointLight")
	aura.Name = "Aura"
	aura.Range = AURA_RANGE
	aura.Brightness = 0.25
	aura.Color = Color3.fromRGB(200, 200, 220)
	aura.Shadows = false
	aura.Parent = part
	return part
end

local function updateLocalFlashlight()
	local inPlay = active()
	local on = inPlay and player:GetAttribute("Flashlight") == true
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	local serverLight = if head then head:FindFirstChild("Flashlight") else nil
	local angle, range = 60, 50
	if serverLight and serverLight:IsA("SpotLight") then
		serverLight.Brightness = if on then 0 else 2.6
		angle, range = serverLight.Angle, serverLight.Range -- variante comprada en la tienda
	end
	range = math.min(range, MAX_LIGHT_RANGE)
	if character then
		removeOwnShadows(character)
	end
	if not inPlay then
		if localLightPart then
			localLightPart:Destroy()
			localLightPart = nil
		end
		return
	end
	if not localLightPart then
		localLightPart = makeLocalLight()
	end
	local part = localLightPart :: Part
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector

	-- Los rayos ignoran tu cuerpo y a los fantasmas (invisibles para ti, pero los rayos los tocan).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { part }
	for _, other in Players:GetPlayers() do
		if other.Character and (other == player or other:GetAttribute("Ghost") == true) then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore

	-- Origen: un poco por delante de la cabeza, sin meterse nunca dentro de una pared.
	local start = if head and head:IsA("BasePart") then head.Position else camera.CFrame.Position
	local ahead = 1
	local wall = workspace:Raycast(start, look * ahead, params)
	if wall then
		ahead = math.max(0, (wall.Position - start).Magnitude - 0.3)
	end
	local origin = start + look * ahead
	part.CFrame = CFrame.lookAt(origin, origin + look)

	local beam = part:FindFirstChild("Beam") :: SpotLight?
	if beam then
		beam.Enabled = on
		beam.Angle = angle
		-- Pegado a algo, las sombras del foco solo dan problemas: se quitan hasta separarte.
		-- Sin sombras la luz atraviesa paredes, así que de paso se acorta para no alumbrar
		-- la sala de al lado; lo que tienes delante ya lo ilumina la luz cercana.
		beam.Shadows = wall == nil
		beam.Range = if wall then WALL_BEAM_RANGE else range
	end
	local near = part:FindFirstChild("Near") :: PointLight?
	if near then
		near.Enabled = on
		near.Brightness = if wall then 1.2 else 0.6
	end
	local anchor = part:FindFirstChild("FillAnchor") :: Part?
	local fill = if anchor then anchor:FindFirstChild("Fill") :: PointLight? else nil
	if anchor and fill then
		local hit = if on then workspace:Raycast(origin, look * FILL_REACH, params) else nil
		fill.Enabled = hit ~= nil
		if hit then
			local dist = (hit.Position - origin).Magnitude
			anchor.CFrame = CFrame.new(hit.Position + hit.Normal * math.clamp(dist * 0.5, 0.4, 2))
			-- Más fuerte cuanto más cerca, como el círculo de una linterna real.
			fill.Brightness = 1.2 * (1 - dist / FILL_REACH) + 0.3
			fill.Range = 6 + dist * 0.3
		end
	end
end

-- Luz UV: las huellas de la Anomalía (invisibles para todos) se ven solo en este cliente,
-- dentro del cono de la cámara y del alcance (mayor con el gamepass UV Pro).
local revealed: { [BasePart]: boolean } = {}
local function updateUv()
	local battery = player:GetAttribute("Battery")
	local on = active()
		and player:GetAttribute("EquippedTool") == Enums.Tool.UV
		and typeof(battery) == "number"
		and battery > 0
	local camera = workspace.CurrentCamera
	local range = if player:GetAttribute("UVPro") == true then Config.Investigator.UvRangePro else Config.Investigator.UvRange
	local seen: { [BasePart]: boolean } = {}
	if on then
		for _, footprint in CollectionService:GetTagged("Footprint") do
			if footprint:IsA("BasePart") then
				local offset = footprint.Position - camera.CFrame.Position
				local dist = offset.Magnitude
				if dist <= range and dist > 0 and camera.CFrame.LookVector:Dot(offset.Unit) > 0.75 then
					-- Más tenue cuanto más lejos o más vieja.
					local created = footprint:GetAttribute("CreatedAt")
					local age = if typeof(created) == "number" then workspace:GetServerTimeNow() - created else 0
					local fade = math.clamp(age / Config.Investigator.FootprintLifetime, 0, 1)
					footprint.Transparency = math.clamp(0.1 + 0.6 * (dist / range) + 0.3 * fade, 0, 0.95)
					seen[footprint] = true
				end
			end
		end
	end
	for footprint in revealed do
		if not seen[footprint] and footprint.Parent then
			footprint.Transparency = 1
		end
	end
	revealed = seen
end

function InvestigatorController.Start()
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)
	for _, attr in { "Role", "Alive", "Escaped" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()
	DoorController.Defer(anomalyInShot)

	Remotes.Event("PhotoResult").OnClientEvent:Connect(function(hit)
		if hit then
			UIController.Toast("¡Anomalía capturada en la foto!", "success")
		else
			UIController.Toast("Nada fuera de lo normal...", "info")
		end
	end)

	RunService.RenderStepped:Connect(updateLocalFlashlight)
	RunService.RenderStepped:Connect(updateUv)
end

return InvestigatorController
