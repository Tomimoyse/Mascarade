-- Tablero 8x8 y las fichas que viven en él.
--
-- Convenio de coordenadas: columna 1..8 de izquierda a derecha, fila 1..8 de
-- arriba abajo. El jugador 2 empieza en las filas 1 y 2 (arriba) y avanza hacia
-- abajo; el jugador 1 empieza en las filas 7 y 8 y avanza hacia arriba.
--
-- Lua puro: este módulo no sabe nada de gráficos.

local Config = require("src.config")

local Board = {}
Board.__index = Board

local N = Config.BOARD_SIZE

---------------------------------------------------------------------------
-- Utilidades de coordenadas
---------------------------------------------------------------------------

function Board.inside(col, row)
    return col >= 1 and col <= N and row >= 1 and row <= N
end

-- Dirección de avance de los peones de cada jugador.
function Board.forward(owner)
    return owner == 1 and -1 or 1
end

-- Fila de promoción de cada jugador (la primera fila del rival).
function Board.promotionRow(owner)
    return owner == 1 and 1 or N
end

-- Filas iniciales de cada jugador.
function Board.homeRows(owner)
    if owner == 1 then return { 7, 8 } else return { 1, 2 } end
end

local function key(col, row)
    return (row - 1) * N + col
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------

function Board.new()
    local self = setmetatable({}, Board)
    self.grid = {}        -- [key] = ficha
    self.byId = {}        -- [id]  = ficha (sólo fichas vivas)
    self.count = { [1] = 0, [2] = 0 }
    self.nextId = 1
    return self
end

-- Coloca las 32 fichas en la formación inicial de ajedrez.
function Board.newStandard()
    local board = Board.new()
    for owner = 1, 2 do
        for _, row in ipairs(Board.homeRows(owner)) do
            for col = 1, N do
                board:spawn(owner, col, row)
            end
        end
    end
    return board
end

---------------------------------------------------------------------------
-- Consulta
---------------------------------------------------------------------------

function Board:at(col, row)
    if not Board.inside(col, row) then return nil end
    return self.grid[key(col, row)]
end

function Board:get(id)
    return self.byId[id]
end

function Board:countOf(owner)
    return self.count[owner] or 0
end

-- Lista (nueva) de las fichas vivas de un jugador.
function Board:piecesOf(owner)
    local out = {}
    for _, p in pairs(self.byId) do
        if p.owner == owner then out[#out + 1] = p end
    end
    -- Orden estable por id: los tests y la IA no deben depender de pairs().
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Todas las fichas vivas, ordenadas por id.
function Board:allPieces()
    local out = {}
    for _, p in pairs(self.byId) do out[#out + 1] = p end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Ficha coronada de un jugador, o nil.
function Board:kingOf(owner)
    for _, p in pairs(self.byId) do
        if p.owner == owner and p.isKing then return p end
    end
    return nil
end

---------------------------------------------------------------------------
-- Mutación
---------------------------------------------------------------------------

function Board:spawn(owner, col, row)
    local piece = {
        id       = self.nextId,
        owner    = owner,
        col      = col,
        row      = row,
        hasMoved = false,
        isKing   = false,
    }
    self.nextId = self.nextId + 1
    self.grid[key(col, row)] = piece
    self.byId[piece.id] = piece
    self.count[owner] = self.count[owner] + 1
    return piece
end

function Board:remove(piece)
    if not piece or not self.byId[piece.id] then return false end
    self.grid[key(piece.col, piece.row)] = nil
    self.byId[piece.id] = nil
    self.count[piece.owner] = self.count[piece.owner] - 1
    piece.alive = false
    return true
end

-- Mueve una ficha a una casilla vacía. No captura: eso lo decide quien llama.
function Board:move(piece, col, row)
    self.grid[key(piece.col, piece.row)] = nil
    piece.col, piece.row = col, row
    piece.hasMoved = true
    self.grid[key(col, row)] = piece
end

---------------------------------------------------------------------------
-- Depuración
---------------------------------------------------------------------------

-- Representación en texto, para los tests por consola.
--   .  casilla vacía        a/A  ficha del jugador 1 (A = rey coronado)
--                           b/B  ficha del jugador 2 (B = rey coronado)
function Board:toString()
    local lines = { "  1 2 3 4 5 6 7 8" }
    for row = 1, N do
        local cells = { tostring(row) }
        for col = 1, N do
            local p = self:at(col, row)
            if not p then
                cells[#cells + 1] = "."
            elseif p.owner == 1 then
                cells[#cells + 1] = p.isKing and "A" or "a"
            else
                cells[#cells + 1] = p.isKing and "B" or "b"
            end
        end
        lines[#lines + 1] = table.concat(cells, " ")
    end
    return table.concat(lines, "\n")
end

return Board
