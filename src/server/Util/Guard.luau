--!strict
-- Validación de remotes: límite de frecuencia por jugador y comprobación de tipos.

local Players = game:GetService("Players")

local Guard = {}

local lastCall: { [Player]: { [string]: number } } = {}

-- Devuelve false si el jugador llama a `key` más rápido que `interval` segundos.
function Guard.RateLimit(player: Player, key: string, interval: number): boolean
	local now = os.clock()
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local last = calls[key]
	if last and now - last < interval then
		return false
	end
	calls[key] = now
	return true
end

function Guard.IsFiniteVector(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local vec = v :: Vector3
	for _, n in { vec.X, vec.Y, vec.Z } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return vec.Magnitude > 0.01
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)

return Guard
