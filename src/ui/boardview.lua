-- Dibujado del tablero y de las fichas.
--
-- Esta capa NO conoce las reglas: recibe una lista de fichas con la forma
--   { col = 1..8, row = 1..8, owner = 1|2, isKing = bool }
-- para que la lógica de la Fase 2 pueda enchufarse sin tocar nada de aquí.

local Config  = require("src.config")
local Palette = require("src.palette")
local Panel   = require("src.ui.panel")
local Sprites = require("src.ui.sprites")
local L       = require("src.ui.layout")

local BoardView = {}

local N = Config.BOARD_SIZE

-- Colores de las casillas: mesa de juego, no tablero de ajedrez clásico.
local LIGHT = Palette.hex("#30506e")
local DARK  = Palette.hex("#1c3247")

-- Marco y fondo del tablero.
function BoardView.drawFrame()
    local b = L.board
    Panel.draw(b.x - 4, b.y - 4, b.w + 8, b.h + 8, {
        fill         = Palette.hex("#140f1e"),
        border       = Palette.hex("#3c2a18"),
        highlight    = Palette.hex("#6b4a28"),
        radius       = 3,
        shadowOffset = 3,
    })
end

-- Casillas.
function BoardView.drawCells()
    local b = L.board
    for row = 1, N do
        for col = 1, N do
            local x, y = L.cellOrigin(col, row)
            local c = ((col + row) % 2 == 0) and LIGHT or DARK
            love.graphics.setColor(c[1], c[2], c[3], 1)
            love.graphics.rectangle("fill", x, y, L.CELL, L.CELL)
        end
    end
    -- Sombra interior en los bordes, para que el tablero parezca hundido.
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", b.x, b.y, b.w, 1)
    love.graphics.rectangle("fill", b.x, b.y, 1, b.h)
    love.graphics.setColor(1, 1, 1, 0.07)
    love.graphics.rectangle("fill", b.x, b.y + b.h - 1, b.w, 1)
    love.graphics.rectangle("fill", b.x + b.w - 1, b.y, 1, b.h)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Resalta una casilla (selección, destino legal, última jugada).
-- style = "select" | "move" | "capture" | "last"
function BoardView.highlight(col, row, style, phase)
    local x, y = L.cellOrigin(col, row)
    if style == "select" then
        love.graphics.setColor(Palette.rgba(Palette.gold, 0.30))
        love.graphics.rectangle("fill", x, y, L.CELL, L.CELL)
        Panel.dashed(x, y, L.CELL, L.CELL, { color = Palette.gold, phase = phase })
    elseif style == "move" then
        love.graphics.setColor(Palette.rgba(Palette.green, 0.22))
        love.graphics.rectangle("fill", x, y, L.CELL, L.CELL)
        love.graphics.setColor(Palette.rgba(Palette.green, 0.8))
        local cx, cy = L.cellCenter(col, row)
        love.graphics.rectangle("fill", math.floor(cx) - 2, math.floor(cy) - 2, 4, 4)
    elseif style == "capture" then
        love.graphics.setColor(Palette.rgba(Palette.red, 0.28))
        love.graphics.rectangle("fill", x, y, L.CELL, L.CELL)
        Panel.dashed(x, y, L.CELL, L.CELL, { color = Palette.red, phase = phase })
    elseif style == "last" then
        love.graphics.setColor(Palette.rgba(Palette.gold, 0.14))
        love.graphics.rectangle("fill", x, y, L.CELL, L.CELL)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Dibuja una ficha en una posición arbitraria del canvas (en píxeles).
-- Separar posición y casilla permite animar el desplazamiento.
-- opts = { scale, lift, alpha, tint }
function BoardView.drawPieceAt(piece, cx, cy, opts)
    opts = opts or {}
    local lift  = opts.lift or 0
    local scale = opts.scale or 1
    local alpha = opts.alpha or 1
    local img   = Sprites.piece[piece.owner] or Sprites.piece[1]
    local d     = Sprites.DISC

    -- Sombra en el suelo: no se eleva con la ficha, se encoge.
    local sh = Sprites.pieceShadow
    local shrink = 1 - math.min(lift / 14, 0.35)
    love.graphics.setColor(1, 1, 1, alpha * 0.9)
    love.graphics.draw(sh, math.floor(cx), math.floor(cy) + 8, 0,
        shrink, shrink, sh:getWidth() / 2, sh:getHeight() / 2)

    if opts.tint then
        love.graphics.setColor(opts.tint[1], opts.tint[2], opts.tint[3], alpha)
    else
        love.graphics.setColor(1, 1, 1, alpha)
    end
    love.graphics.draw(img, math.floor(cx), math.floor(cy - lift), 0,
        scale, scale, d / 2, d / 2)

    if piece.isKing then
        local cr = Sprites.crownIcon
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(cr, math.floor(cx), math.floor(cy - lift - 9), 0,
            1, 1, cr:getWidth() / 2, cr:getHeight() / 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Variante que coloca la ficha en el centro de su casilla.
function BoardView.drawPiece(piece, opts)
    local cx, cy = L.cellCenter(piece.col, piece.row)
    BoardView.drawPieceAt(piece, cx, cy, opts)
end

-- Dibuja el tablero completo con una lista de fichas.
function BoardView.draw(pieces, opts)
    opts = opts or {}
    BoardView.drawFrame()
    BoardView.drawCells()
    if opts.beforePieces then opts.beforePieces() end
    for _, p in ipairs(pieces or {}) do
        BoardView.drawPiece(p, opts.pieceOpts and opts.pieceOpts(p) or nil)
    end
    if opts.afterPieces then opts.afterPieces() end
end

-- Posición inicial de ajedrez: dos filas completas por jugador.
-- El jugador 1 ocupa las filas 7 y 8 (abajo), el jugador 2 las filas 1 y 2.
function BoardView.startingPieces()
    local pieces = {}
    for col = 1, N do
        pieces[#pieces + 1] = { col = col, row = 1, owner = 2 }
        pieces[#pieces + 1] = { col = col, row = 2, owner = 2 }
        pieces[#pieces + 1] = { col = col, row = 7, owner = 1 }
        pieces[#pieces + 1] = { col = col, row = 8, owner = 1 }
    end
    return pieces
end

return BoardView
