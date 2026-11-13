-- Reparto del canvas interno (640x360). Un único sitio donde cambiar la
-- composición de la pantalla de partida.

local Config = require("src.config")

local L = {}

L.CELL = 30                               -- lado de una casilla, en píxeles
L.BOARD_PX = L.CELL * Config.BOARD_SIZE   -- 240

-- Tablero centrado horizontalmente, pegado arriba.
L.board = {
    x = math.floor((Config.CANVAS_W - L.BOARD_PX) / 2),  -- 200
    y = 16,
    w = L.BOARD_PX,
    h = L.BOARD_PX,
}

-- Columnas laterales de información.
L.left  = { x = 8,   y = 16, w = 184, h = 240 }
L.right = { x = 448, y = 16, w = 184, h = 240 }

-- Franja inferior: mano del jugador activo y botones de acción.
L.hand = { x = 8, y = 262, w = 624, h = 90 }

-- Medidas de las cartas.
L.card = { w = 44, h = 62 }

-- Centro de una casilla del tablero (col, fila de 1 a 8).
function L.cellCenter(col, row)
    return L.board.x + (col - 0.5) * L.CELL,
           L.board.y + (row - 0.5) * L.CELL
end

-- Esquina superior izquierda de una casilla.
function L.cellOrigin(col, row)
    return L.board.x + (col - 1) * L.CELL,
           L.board.y + (row - 1) * L.CELL
end

-- Casilla bajo un punto del canvas, o nil si está fuera del tablero.
function L.cellAt(x, y)
    local col = math.floor((x - L.board.x) / L.CELL) + 1
    local row = math.floor((y - L.board.y) / L.CELL) + 1
    if col < 1 or col > Config.BOARD_SIZE or row < 1 or row > Config.BOARD_SIZE then
        return nil
    end
    return col, row
end

return L
