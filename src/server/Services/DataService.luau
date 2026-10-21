--!strict
-- Guardado de progreso con DataStore. Inspirado en ProfileStore pero sin dependencias:
-- - Bloqueo de sesión con UpdateAsync (evita duplicar monedas al saltar entre servidores).
-- - Reintentos con espera creciente, autoguardado y guardado al cerrar el servidor.
-- - Si el DataStore no está disponible (Studio sin acceso a APIs), funciona en memoria
--   y avisa de que esa sesión no se guarda.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local STORE_NAME = "MimicManor_v1"
local LOCK_TIMEOUT = 600 -- segundos: un bloqueo más viejo se considera abandonado
local AUTOSAVE_INTERVAL = 120
local MAX_RECEIPTS = 50

export type Data = {
	version: number,
	coins: number,
	owned: { [string]: boolean },
	equipped: { [string]: string },
	consumables: { [string]: number },
	stats: { [string]: number },
	receipts: { string },
	lock: { job: string, time: number }?,
}

type Profile = {
	data: Data,
	persist: boolean,
	released: boolean,
}

local DataService = {}

local profiles: { [Player]: Profile } = {}
local loading: { [Player]: boolean } = {}
local store: DataStore? = nil
local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local function defaults(): Data
	return {
		version = 1,
		coins = 0,
		owned = {},
		equipped = { Flashlight = "Default", EMF = "Default", LightColor = "Default", AnomalyEyes = "Default" },
		consumables = { Trap_Bell = 0, Revive = 0 },
		stats = { rounds = 0, wins = 0, escapes = 0, kills = 0 },
		receipts = {},
		lock = nil,
	}
end

-- Rellena campos que falten en datos antiguos sin borrar nada.
local function reconcile(data: any): Data
	local base = defaults() :: any
	if typeof(data) ~= "table" then
		return base
	end
	for key, value in base do
		if data[key] == nil then
			data[key] = value
		elseif typeof(value) == "table" and typeof(data[key]) == "table" and key ~= "receipts" then
			for k, v in value do
				if data[key][k] == nil then
					data[key][k] = v
				end
			end
		end
	end
	return data
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return result
	end
	return nil
end

function DataService.Sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	player:SetAttribute("Coins", data.coins)
	Remotes.Event("ProfileSync"):FireClient(player, {
		coins = data.coins,
		owned = data.owned,
		equipped = data.equipped,
		consumables = data.consumables,
		stats = data.stats,
		persist = profile.persist,
	})
end

local function load(player: Player)
	loading[player] = true
	local ds = getStore()
	local data: Data? = nil
	local persist = false
	local attempts = if RunService:IsStudio() then 1 else 6
	if ds then
		for attempt = 1, attempts do
			local lockedElsewhere = false
			local ok, result = pcall(function()
				return ds:UpdateAsync(keyFor(player), function(old)
					local current = reconcile(old)
					local lock = current.lock
					if lock and lock.job ~= jobId and os.time() - lock.time < LOCK_TIMEOUT and attempt < attempts then
						lockedElsewhere = true
						return nil -- cancelar: otro servidor aún tiene la sesión
					end
					current.lock = { job = jobId, time = os.time() }
					return current
				end)
			end)
			if ok and result then
				data = reconcile(result)
				persist = true
				break
			end
			if not ok then
				warn("[DataService] error cargando", player.UserId, result)
			end
			if not player.Parent then
				loading[player] = nil
				return
			end
			task.wait(if lockedElsewhere then 4 else 2 ^ attempt)
		end
	end
	if not player.Parent then
		loading[player] = nil
		return
	end
	if not data then
		data = defaults()
		Remotes.Event("Notify"):FireClient(player, "No se pudo cargar tu progreso: esta sesión no se guardará", "warn")
	end
	profiles[player] = { data = data :: Data, persist = persist, released = false }
	loading[player] = nil
	DataService.Sync(player)
end

local function save(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or not profile.persist or profile.released then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end
	local snapshot = deepCopy(profile.data)
	snapshot.lock = if release then nil else { job = jobId, time = os.time() }
	for attempt = 1, 3 do
		local lost = false
		local ok, err = pcall(function()
			ds:UpdateAsync(keyFor(player), function(old)
				if old and old.lock and old.lock.job ~= jobId then
					lost = true
					return nil -- otro servidor robó la sesión: no sobrescribir
				end
				return snapshot
			end)
		end)
		if ok then
			if lost then
				warn("[DataService] sesión perdida para", player.UserId)
				profile.persist = false
				return false
			end
			if release then
				profile.released = true
			end
			return true
		end
		warn("[DataService] error guardando", player.UserId, err)
		task.wait(attempt * 2)
	end
	return false
end

function DataService.Get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

function DataService.WaitFor(player: Player, timeout: number?): Data?
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and not profiles[player] and os.clock() < deadline do
		task.wait(0.2)
	end
	return DataService.Get(player)
end

function DataService.AddCoins(player: Player, amount: number)
	local data = DataService.Get(player)
	if data then
		data.coins = math.max(0, data.coins + math.floor(amount))
		DataService.Sync(player)
	end
end

-- Cobra `price` si hay saldo. Devuelve true si se ha cobrado.
function DataService.Spend(player: Player, price: number): boolean
	local data = DataService.Get(player)
	if not data or data.coins < price then
		return false
	end
	data.coins -= price
	return true
end

function DataService.Owns(player: Player, id: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.owned[id] == true
end

function DataService.Grant(player: Player, id: string)
	local data = DataService.Get(player)
	if data then
		data.owned[id] = true
	end
end

function DataService.AddStat(player: Player, stat: string, amount: number)
	local data = DataService.Get(player)
	if data then
		data.stats[stat] = (data.stats[stat] or 0) + amount
	end
end

-- Recibos de Robux ya procesados (para no conceder dos veces la misma compra).
function DataService.HasReceipt(player: Player, receiptId: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and table.find(data.receipts, receiptId) ~= nil
end

function DataService.AddReceipt(player: Player, receiptId: string)
	local data = DataService.Get(player)
	if data then
		table.insert(data.receipts, receiptId)
		while #data.receipts > MAX_RECEIPTS do
			table.remove(data.receipts, 1)
		end
	end
end

-- Guardado inmediato (compras con Robux). Devuelve true si quedó persistido.
function DataService.SaveNow(player: Player): boolean
	return save(player, false)
end

function DataService.IsPersistent(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.persist
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		while loading[player] do
			task.wait(0.5)
		end
		save(player, true)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player, false)
			end
		end
	end)
end

return DataService
