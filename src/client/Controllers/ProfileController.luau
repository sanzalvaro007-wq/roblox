--!strict
-- Copia local (solo lectura) del perfil que envía el servidor: monedas, inventario, equipo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local ProfileController = {}

local changed = Instance.new("BindableEvent")
ProfileController.Changed = changed.Event

ProfileController.Data = {
	coins = 0,
	owned = {} :: { [string]: boolean },
	equipped = {} :: { [string]: string },
	consumables = {} :: { [string]: number },
	stats = {} :: { [string]: number },
	persist = true,
}

function ProfileController.Owns(id: string): boolean
	return ProfileController.Data.owned[id] == true
end

function ProfileController.Count(id: string): number
	return ProfileController.Data.consumables[id] or 0
end

function ProfileController.Init()
	Remotes.Event("ProfileSync").OnClientEvent:Connect(function(snapshot)
		if typeof(snapshot) ~= "table" then
			return
		end
		local data = ProfileController.Data
		data.coins = tonumber(snapshot.coins) or 0
		data.owned = if typeof(snapshot.owned) == "table" then snapshot.owned else {}
		data.equipped = if typeof(snapshot.equipped) == "table" then snapshot.equipped else {}
		data.consumables = if typeof(snapshot.consumables) == "table" then snapshot.consumables else {}
		data.stats = if typeof(snapshot.stats) == "table" then snapshot.stats else {}
		data.persist = snapshot.persist ~= false
		changed:Fire()
	end)
end

return ProfileController
