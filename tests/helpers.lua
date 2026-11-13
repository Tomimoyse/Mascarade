-- Utilidades para montar posiciones concretas en los tests.
-- Permiten saltarse el reparto aleatorio y probar reglas aisladas.

local Match = require("src.game.match")
local Board = require("src.game.board")

local H = {}

local nextCardId = 10000
local function makeCard(kind)
    nextCardId = nextCardId + 1
    return { id = nextCardId, kind = kind }
end
H.makeCard = makeCard

-- Monta una partida con una posición concreta.
-- opts = {
--   pieces  = { {owner=1, col=4, row=5, name="a", king=true, moved=true}, ... },
--   hands   = { [1] = {"peon","torre"}, [2] = {...} },
--   deck    = {"peon", ...},     -- de la cima hacia abajo
--   discard = {"torre", ...},    -- de la cima hacia abajo
--   current = 1,
-- }
-- Devuelve la partida y una tabla nombre -> ficha.
function H.scenario(opts)
    opts = opts or {}
    local m = Match.new({ seed = opts.seed or 1 })

    m.board   = Board.new()
    m.deck    = {}
    m.discard = {}
    m.players = {
        { id = 1, hand = {}, kingPieceId = nil },
        { id = 2, hand = {}, kingPieceId = nil },
    }

    local named = {}
    for _, spec in ipairs(opts.pieces or {}) do
        local p = m.board:spawn(spec.owner, spec.col, spec.row)
        if spec.moved then p.hasMoved = true end
        if spec.king then
            p.isKing = true
            m.players[spec.owner].kingPieceId = p.id
        end
        if spec.name then named[spec.name] = p end
    end

    for owner = 1, 2 do
        local list = opts.hands and opts.hands[owner] or {}
        for _, kind in ipairs(list) do
            table.insert(m.players[owner].hand, makeCard(kind))
        end
    end
    for _, kind in ipairs(opts.deck or {}) do
        table.insert(m.deck, makeCard(kind))
    end
    for _, kind in ipairs(opts.discard or {}) do
        table.insert(m.discard, makeCard(kind))
    end

    m:_startTurn(opts.current or 1)
    m.events = {}
    return m, named
end

-- Primera carta de la mano con ese tipo (la n-ésima si se pide).
function H.card(m, owner, kind, n)
    n = n or 1
    for _, c in ipairs(m.players[owner].hand) do
        if c.kind == kind then
            n = n - 1
            if n == 0 then return c end
        end
    end
    return nil
end

-- Juega una carta por tipo, sin tener que buscar el id a mano.
function H.play(m, kind, piece, col, row, n)
    local c = H.card(m, m.current, kind, n)
    if not c then return false, "sinCartaEnMano:" .. kind end
    return m:apply({ type = "playCard", cardId = c.id,
                     pieceId = piece.id, col = col, row = row })
end

-- ¿Hay algún evento de este tipo en la cola?
function H.hasEvent(events, t)
    for _, ev in ipairs(events) do
        if ev.t == t then return ev end
    end
    return nil
end

-- Cuenta eventos de un tipo.
function H.countEvents(events, t)
    local n = 0
    for _, ev in ipairs(events) do
        if ev.t == t then n = n + 1 end
    end
    return n
end

-- ¿Existe este destino en la lista?
function H.hasDest(list, col, row)
    for _, d in ipairs(list) do
        if d.col == col and d.row == row then return d end
    end
    return nil
end

return H
