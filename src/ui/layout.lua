-- Reparto del canvas interno (640x360). Un único sitio donde cambiar la
-- composición de la pantalla de partida.
--
--   +----------------+-------------------+----------------+
--   | rival          |      TABLERO      | mazo/descarte  |
--   | jugador        |       8 x 8       | jugadas turno  |
--   | cadena         |                   | acciones       |
--   +----------------+-------------------+----------------+
--   |                   MANO DEL JUGADOR                  |
--   +-----------------------------------------------------+

local Config = require("src.config")

local L = {}

L.CELL = 30                               -- lado de una casilla, en píxeles
L.BOARD_PX = L.CELL * Config.BOARD_SIZE   -- 240

-- Tablero centrado horizontalmente.
L.board = {
    x = math.floor((Config.CANVAS_W - L.BOARD_PX) / 2),  -- 200
    y = 18,
    w = L.BOARD_PX,
    h = L.BOARD_PX,
}

-- Columna izquierda: información de los jugadores y de la cadena en curso.
L.left         = { x = 6, y = 18, w = 188, h = 240 }
L.panelRival   = { x = 6, y = 18,  w = 188, h = 54 }
L.panelPropio  = { x = 6, y = 76,  w = 188, h = 54 }
L.panelCadena  = { x = 6, y = 134, w = 188, h = 124 }

-- Columna derecha: mazos, cartas jugadas y botones de acción.
L.right        = { x = 446, y = 18,  w = 188, h = 240 }
L.panelPilas   = { x = 446, y = 18,  w = 188, h = 62 }
L.panelJugadas = { x = 446, y = 84,  w = 188, h = 62 }
L.panelAcciones= { x = 446, y = 150, w = 188, h = 108 }

-- Franja inferior: mano del jugador activo.
L.hand = { x = 6, y = 264, w = 628, h = 90 }

-- Medidas de las cartas (coinciden con src/ui/cardview.lua).
L.card      = { w = 54, h = 76 }
L.cardSmall = { w = 30, h = 42 }
L.handGap   = 10
L.handY     = 274

-- Posición de la carta i-ésima de una mano de n cartas.
function L.handSlot(i, n)
    local total = n * L.card.w + math.max(n - 1, 0) * L.handGap
    local x0 = L.hand.x + math.floor((L.hand.w - total) / 2)
    return x0 + (i - 1) * (L.card.w + L.handGap), L.handY
end

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

-- ¿Está el punto dentro de un rectángulo { x, y, w, h }?
function L.inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

return L
