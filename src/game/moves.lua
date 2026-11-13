-- Generación de movimientos legales.
--
-- Una ficha no tiene tipo: el tipo lo pone la carta de disfraz que se juega
-- sobre ella. Por eso todas las funciones reciben el 'kind' de la carta.
--
-- Reglas de ajedrez estándar, con tres particularidades de Mascarade:
--   * El peón avanza recto y sólo come en diagonal (ajedrez exacto).
--   * El avance doble del peón está disponible mientras la ficha no se haya
--     movido nunca, sea cual sea su casilla (regla A2-b1).
--   * El rey coronado del rival es intocable mientras le queden otras fichas.
--
-- Lua puro: este módulo no sabe nada de gráficos.

local Board = require("src.game.board")

local Moves = {}

local RAYS = {
    torre = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } },
    alfil = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } },
    reina = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
              { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } },
}

local KING_STEPS = RAYS.reina

local KNIGHT_STEPS = {
    { 1, 2 }, { 2, 1 }, { -1, 2 }, { -2, 1 },
    { 1, -2 }, { 2, -1 }, { -1, -2 }, { -2, -1 },
}

---------------------------------------------------------------------------
-- Capturas
---------------------------------------------------------------------------

-- ¿Puede 'attacker' capturar a 'target'?
-- El rey coronado sólo es capturable cuando es la última ficha de su dueño.
function Moves.canCapture(board, attacker, target)
    if not target then return false end
    if target.owner == attacker.owner then return false end
    if target.isKing and board:countOf(target.owner) > 1 then return false end
    return true
end

-- Motivo por el que una captura es ilegal (para tooltips de la interfaz).
function Moves.captureBlockReason(board, attacker, target)
    if not target then return nil end
    if target.owner == attacker.owner then return "propia" end
    if target.isKing and board:countOf(target.owner) > 1 then return "reyIntocable" end
    return nil
end

---------------------------------------------------------------------------
-- Generación por tipo de disfraz
---------------------------------------------------------------------------

local function addIfLegal(board, piece, list, col, row)
    if not Board.inside(col, row) then return false end
    local target = board:at(col, row)
    if not target then
        list[#list + 1] = { col = col, row = row, capture = false }
        return true   -- se puede seguir deslizando
    end
    if Moves.canCapture(board, piece, target) then
        list[#list + 1] = { col = col, row = row, capture = true, targetId = target.id }
    end
    return false      -- hay una ficha: el rayo se detiene aquí
end

local function slide(board, piece, list, dirs)
    for _, d in ipairs(dirs) do
        local col, row = piece.col, piece.row
        while true do
            col, row = col + d[1], row + d[2]
            if not addIfLegal(board, piece, list, col, row) then break end
        end
    end
end

local function step(board, piece, list, steps)
    for _, d in ipairs(steps) do
        addIfLegal(board, piece, list, piece.col + d[1], piece.row + d[2])
    end
end

local function pawn(board, piece, list)
    local dir = Board.forward(piece.owner)

    -- Avance recto: nunca captura.
    local r1 = piece.row + dir
    if Board.inside(piece.col, r1) and not board:at(piece.col, r1) then
        list[#list + 1] = { col = piece.col, row = r1, capture = false }

        -- Avance doble: sólo si la ficha no se ha movido nunca (regla A2-b1).
        if not piece.hasMoved then
            local r2 = piece.row + dir * 2
            if Board.inside(piece.col, r2) and not board:at(piece.col, r2) then
                list[#list + 1] = { col = piece.col, row = r2, capture = false, double = true }
            end
        end
    end

    -- Capturas en diagonal: sólo si hay una ficha rival capturable.
    for _, dc in ipairs({ -1, 1 }) do
        local c, r = piece.col + dc, piece.row + dir
        if Board.inside(c, r) then
            local target = board:at(c, r)
            if target and Moves.canCapture(board, piece, target) then
                list[#list + 1] = { col = c, row = r, capture = true, targetId = target.id }
            end
        end
    end
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

-- Destinos legales de 'piece' si se mueve con un disfraz de tipo 'kind'.
-- Devuelve una lista de { col, row, capture, targetId?, double? }.
-- No comprueba las reglas de encadenado: de eso se encarga Match.
function Moves.destinations(board, piece, kind)
    local list = {}
    if not piece or not kind then return list end

    -- Una ficha coronada sólo se mueve como rey.
    if piece.isKing and kind ~= "rey" then return list end

    if kind == "peon" then
        pawn(board, piece, list)
    elseif kind == "caballo" then
        step(board, piece, list, KNIGHT_STEPS)
    elseif kind == "rey" then
        step(board, piece, list, KING_STEPS)
    elseif RAYS[kind] then
        slide(board, piece, list, RAYS[kind])
    end

    return list
end

-- ¿Tiene esta ficha algún movimiento legal con este disfraz?
function Moves.hasAny(board, piece, kind)
    return #Moves.destinations(board, piece, kind) > 0
end

-- ¿Existe algún movimiento legal de este disfraz con ALGUNA ficha del jugador?
-- Ignora por completo las reglas de encadenado: es la definición de
-- "carta muerta" usada por la válvula de descarte (regla A6-B).
function Moves.anyLegalFor(board, owner, kind)
    for _, piece in ipairs(board:piecesOf(owner)) do
        if #Moves.destinations(board, piece, kind) > 0 then return true end
    end
    return false
end

-- Busca un destino concreto dentro de la lista de destinos legales.
function Moves.find(board, piece, kind, col, row)
    for _, d in ipairs(Moves.destinations(board, piece, kind)) do
        if d.col == col and d.row == row then return d end
    end
    return nil
end

return Moves
