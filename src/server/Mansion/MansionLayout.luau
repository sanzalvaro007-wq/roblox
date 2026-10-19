--!strict
-- Generador lógico de la mansión (sin instancias de Roblox, así se puede testear con el CLI de Luau).
--
-- 1. Crece un conjunto orgánico de celdas desde el vestíbulo (borde sur de la rejilla).
-- 2. Fusiona algunas celdas vecinas en salas grandes de 2 celdas.
-- 3. Une las salas con un árbol aleatorio (Kruskal) + puertas extra para crear bucles.
-- 4. Valida conectividad y reglas; si falla tras N intentos usa un layout seguro fijo.

export type Rng = {
	int: (min: number, max: number) -> number,
	float: () -> number,
}

export type Cell = { x: number, y: number }

export type Room = {
	id: number,
	cells: { Cell },
	kind: string,
}

export type Door = {
	a: number, -- id de sala
	b: number,
	cellA: Cell,
	cellB: Cell,
}

export type Layout = {
	width: number,
	height: number,
	cellRoom: { [number]: number }, -- índice de celda -> id de sala
	rooms: { Room },
	doors: { Door },
	foyer: number,
	exitCell: Cell,
	exitDir: Cell, -- dirección hacia fuera de la mansión
	anomalyRoom: number,
	fuseBoxRoom: number,
	distances: { [number]: number },
	fallback: boolean,
}

export type Params = {
	GridWidth: number,
	GridHeight: number,
	MinCells: number,
	MaxCells: number,
	MinRooms: number,
	MergeChance: number,
	ExtraDoors: number,
	MaxAttempts: number,
}

local DIRS: { Cell } = {
	{ x = 1, y = 0 },
	{ x = -1, y = 0 },
	{ x = 0, y = 1 },
	{ x = 0, y = -1 },
}

local ROOM_KINDS = {
	"Biblioteca",
	"Comedor",
	"Salón",
	"Dormitorio",
	"Cocina",
	"Estudio",
	"Galería",
	"Capilla",
	"Invernadero",
	"Sala de música",
}

local MansionLayout = {}

local function index(width: number, x: number, y: number): number
	return y * width + x
end

local function inBounds(width: number, height: number, x: number, y: number): boolean
	return x >= 0 and y >= 0 and x < width and y < height
end

local function shuffle<T>(list: { T }, rng: Rng)
	for i = #list, 2, -1 do
		local j = rng.int(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- Distancias en número de puertas desde la sala `from`.
local function bfs(layout: Layout, from: number): { [number]: number }
	local adj: { [number]: { number } } = {}
	for _, room in layout.rooms do
		adj[room.id] = {}
	end
	for _, door in layout.doors do
		table.insert(adj[door.a], door.b)
		table.insert(adj[door.b], door.a)
	end
	local dist: { [number]: number } = { [from] = 0 }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, n in adj[current] do
			if dist[n] == nil then
				dist[n] = dist[current] + 1
				table.insert(queue, n)
			end
		end
	end
	return dist
end

local function assignSpecialRooms(layout: Layout, rng: Rng)
	layout.distances = bfs(layout, layout.foyer)

	-- La Anomalía empieza en la sala más lejana del vestíbulo (en puertas y, a igualdad,
	-- en distancia física), para que no haya una emboscada nada más empezar.
	local best, bestScore = layout.foyer, -math.huge
	for _, room in layout.rooms do
		local d = layout.distances[room.id] or -1
		local far = 0
		for _, c in room.cells do
			far = math.max(far, math.abs(c.x - layout.exitCell.x) + math.abs(c.y - layout.exitCell.y))
		end
		local score = d * 10 + far + rng.float() * 0.5
		if score > bestScore then
			best, bestScore = room.id, score
		end
	end
	layout.anomalyRoom = best

	-- La caja de fusibles: sala a distancia >= 2 que no sea la de la Anomalía, si existe.
	local candidates = {}
	for _, room in layout.rooms do
		local d = layout.distances[room.id] or 0
		if room.id ~= layout.foyer and room.id ~= layout.anomalyRoom and d >= 2 then
			table.insert(candidates, room.id)
		end
	end
	if #candidates == 0 then
		for _, room in layout.rooms do
			if room.id ~= layout.foyer and room.id ~= layout.anomalyRoom then
				table.insert(candidates, room.id)
			end
		end
	end
	layout.fuseBoxRoom = if #candidates > 0 then candidates[rng.int(1, #candidates)] else layout.anomalyRoom

	-- Tipos de sala (solo estética y elección de muebles).
	local kinds = table.clone(ROOM_KINDS)
	shuffle(kinds, rng)
	local k = 1
	for _, room in layout.rooms do
		if room.id == layout.foyer then
			room.kind = "Vestíbulo"
		else
			room.kind = kinds[((k - 1) % #kinds) + 1]
			k += 1
		end
	end
end

function MansionLayout.Generate(params: Params, rng: Rng): Layout
	local w, h = params.GridWidth, params.GridHeight
	local target = rng.int(params.MinCells, math.min(params.MaxCells, w * h))

	-- 1. Crecimiento orgánico desde el vestíbulo.
	local start: Cell = { x = w // 2, y = h - 1 }
	local inSet: { [number]: boolean } = { [index(w, start.x, start.y)] = true }
	local cells: { Cell } = { start }
	local guard = 0
	while #cells < target do
		guard += 1
		if guard > 5000 then
			error("crecimiento atascado")
		end
		local from = cells[rng.int(1, #cells)]
		local dir = DIRS[rng.int(1, #DIRS)]
		local nx, ny = from.x + dir.x, from.y + dir.y
		if inBounds(w, h, nx, ny) and not inSet[index(w, nx, ny)] then
			inSet[index(w, nx, ny)] = true
			table.insert(cells, { x = nx, y = ny })
		end
	end

	-- 2. Salas: algunas celdas se fusionan con una vecina.
	local cellRoom: { [number]: number } = {}
	local rooms: { Room } = {}
	local order = table.clone(cells)
	shuffle(order, rng)
	for _, cell in order do
		local ci = index(w, cell.x, cell.y)
		if cellRoom[ci] == nil then
			local room: Room = { id = #rooms + 1, cells = { cell }, kind = "" }
			table.insert(rooms, room)
			cellRoom[ci] = room.id
			if rng.float() < params.MergeChance then
				local dirs = table.clone(DIRS)
				shuffle(dirs, rng)
				for _, dir in dirs do
					local nx, ny = cell.x + dir.x, cell.y + dir.y
					local ni = index(w, nx, ny)
					if inBounds(w, h, nx, ny) and inSet[ni] and cellRoom[ni] == nil then
						cellRoom[ni] = room.id
						table.insert(room.cells, { x = nx, y = ny })
						break
					end
				end
			end
		end
	end

	-- 3. Candidatos de puerta: una pared compartida aleatoria por cada par de salas vecinas.
	local pairEdges: { [string]: { Door } } = {}
	local pairKeys: { string } = {}
	for _, cell in cells do
		local a = cellRoom[index(w, cell.x, cell.y)]
		for _, dir in { DIRS[1], DIRS[3] } do -- solo E y S para no duplicar
			local nx, ny = cell.x + dir.x, cell.y + dir.y
			local ni = index(w, nx, ny)
			if inBounds(w, h, nx, ny) and inSet[ni] then
				local b = cellRoom[ni]
				if b ~= a then
					local lo, hi = math.min(a, b), math.max(a, b)
					local key = lo .. ":" .. hi
					if not pairEdges[key] then
						pairEdges[key] = {}
						table.insert(pairKeys, key)
					end
					table.insert(pairEdges[key], { a = a, b = b, cellA = cell, cellB = { x = nx, y = ny } })
				end
			end
		end
	end
	shuffle(pairKeys, rng)

	-- Kruskal con union-find.
	local parent: { [number]: number } = {}
	for _, room in rooms do
		parent[room.id] = room.id
	end
	local function find(x: number): number
		while parent[x] ~= x do
			parent[x] = parent[parent[x]]
			x = parent[x]
		end
		return x
	end

	local doors: { Door } = {}
	local leftovers: { string } = {}
	for _, key in pairKeys do
		local edges = pairEdges[key]
		local edge = edges[rng.int(1, #edges)]
		local ra, rb = find(edge.a), find(edge.b)
		if ra ~= rb then
			parent[ra] = rb
			table.insert(doors, edge)
		else
			table.insert(leftovers, key)
		end
	end
	for i = 1, math.min(params.ExtraDoors, #leftovers) do
		local edges = pairEdges[leftovers[i]]
		table.insert(doors, edges[rng.int(1, #edges)])
	end

	local layout: Layout = {
		width = w,
		height = h,
		cellRoom = cellRoom,
		rooms = rooms,
		doors = doors,
		foyer = cellRoom[index(w, start.x, start.y)],
		exitCell = start,
		exitDir = { x = 0, y = 1 },
		anomalyRoom = 0,
		fuseBoxRoom = 0,
		distances = {},
		fallback = false,
	}
	assignSpecialRooms(layout, rng)
	return layout
end

-- Layout seguro hecho a mano: rejilla de 3x4 celdas con un pasillo central.
function MansionLayout.Fallback(params: Params, rng: Rng): Layout
	local w, h = params.GridWidth, params.GridHeight
	local x0 = math.max(0, w // 2 - 1)
	local y0 = math.max(0, h - 4)
	local cellRoom: { [number]: number } = {}
	local rooms: { Room } = {}
	for dy = 0, 3 do
		for dx = 0, 2 do
			local x, y = x0 + dx, y0 + dy
			local room: Room = { id = #rooms + 1, cells = { { x = x, y = y } }, kind = "" }
			table.insert(rooms, room)
			cellRoom[index(w, x, y)] = room.id
		end
	end
	local function roomAt(dx: number, dy: number): number
		return cellRoom[index(w, x0 + dx, y0 + dy)]
	end
	local doors: { Door } = {}
	local function door(ax: number, ay: number, bx: number, by: number)
		table.insert(doors, {
			a = roomAt(ax, ay),
			b = roomAt(bx, by),
			cellA = { x = x0 + ax, y = y0 + ay },
			cellB = { x = x0 + bx, y = y0 + by },
		})
	end
	-- Pasillo central (columna 1) de sur a norte, y cada sala lateral conectada al pasillo.
	for dy = 3, 1, -1 do
		door(1, dy, 1, dy - 1)
	end
	for dy = 0, 3 do
		door(0, dy, 1, dy)
		door(1, dy, 2, dy)
	end
	local start = { x = x0 + 1, y = y0 + 3 }
	local layout: Layout = {
		width = w,
		height = h,
		cellRoom = cellRoom,
		rooms = rooms,
		doors = doors,
		foyer = cellRoom[index(w, start.x, start.y)],
		exitCell = start,
		exitDir = { x = 0, y = 1 },
		anomalyRoom = 0,
		fuseBoxRoom = 0,
		distances = {},
		fallback = true,
	}
	assignSpecialRooms(layout, rng)
	return layout
end

function MansionLayout.Validate(layout: Layout, params: Params): (boolean, string?)
	local w, h = layout.width, layout.height
	if #layout.rooms < params.MinRooms then
		return false, "pocas salas: " .. #layout.rooms
	end

	-- Cada sala: celdas dentro de la rejilla, registradas y contiguas.
	for _, room in layout.rooms do
		if #room.cells == 0 or #room.cells > 2 then
			return false, "sala con tamaño inválido"
		end
		for _, c in room.cells do
			if not inBounds(w, h, c.x, c.y) then
				return false, "celda fuera de la rejilla"
			end
			if layout.cellRoom[index(w, c.x, c.y)] ~= room.id then
				return false, "celda solapada o sin registrar"
			end
		end
		if #room.cells == 2 then
			local a, b = room.cells[1], room.cells[2]
			if math.abs(a.x - b.x) + math.abs(a.y - b.y) ~= 1 then
				return false, "sala grande no contigua"
			end
		end
	end

	-- Cada puerta une celdas vecinas de salas distintas.
	for _, door in layout.doors do
		if door.a == door.b then
			return false, "puerta dentro de una misma sala"
		end
		if math.abs(door.cellA.x - door.cellB.x) + math.abs(door.cellA.y - door.cellB.y) ~= 1 then
			return false, "puerta entre celdas no vecinas"
		end
		if layout.cellRoom[index(w, door.cellA.x, door.cellA.y)] ~= door.a
			or layout.cellRoom[index(w, door.cellB.x, door.cellB.y)] ~= door.b
		then
			return false, "puerta con salas incorrectas"
		end
	end

	-- Conectividad: desde el vestíbulo se llega a todas las salas.
	local dist = bfs(layout, layout.foyer)
	for _, room in layout.rooms do
		if dist[room.id] == nil then
			return false, "sala inalcanzable: " .. room.id
		end
	end

	-- La salida está en el vestíbulo y da al exterior.
	local ex, ey = layout.exitCell.x, layout.exitCell.y
	if layout.cellRoom[index(w, ex, ey)] ~= layout.foyer then
		return false, "la salida no está en el vestíbulo"
	end
	local ox, oy = ex + layout.exitDir.x, ey + layout.exitDir.y
	if inBounds(w, h, ox, oy) and layout.cellRoom[index(w, ox, oy)] ~= nil then
		return false, "la salida no da al exterior"
	end

	-- La Anomalía no empieza junto a los Investigadores.
	if layout.anomalyRoom == layout.foyer or (dist[layout.anomalyRoom] or 0) < 2 then
		return false, "la Anomalía empieza demasiado cerca"
	end
	if layout.fuseBoxRoom == layout.foyer then
		return false, "la caja de fusibles está en el vestíbulo"
	end
	return true, nil
end

-- Punto de entrada: intenta generar y validar; si no, layout seguro.
function MansionLayout.GenerateSafe(params: Params, rng: Rng): (Layout, number)
	for attempt = 1, params.MaxAttempts do
		local ok, result = pcall(MansionLayout.Generate, params, rng)
		if ok then
			local valid = MansionLayout.Validate(result, params)
			if valid then
				return result, attempt
			end
		end
	end
	return MansionLayout.Fallback(params, rng), params.MaxAttempts + 1
end

MansionLayout.Index = index

return MansionLayout
