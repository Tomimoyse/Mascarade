-- Vista de una partida remota, reconstruida a partir de una foto censurada.
--
-- El truco: en vez de reimplementar las consultas del motor, reconstruimos un
-- objeto con la misma forma que Match y le colgamos sus propios métodos. Así
-- getDestinations, inspectHand, canFreeKingMove y compañía funcionan tal cual,
-- sin duplicar una sola regla.
--
-- La mano del rival y el mazo se rellenan con cartas tapadas: ocupan sitio
-- para que los recuentos cuadren, pero no dicen nada.

local Match  = require("src.game.match")
local Board  = require("src.game.board")

local MatchView = {}

local function cartasTapadas(n)
    local out = {}
    for i = 1, (n or 0) do out[i] = { id = -i, kind = "?" } end
    return out
end

-- Construye la vista. 'me' es el jugador que la va a mirar.
function MatchView.fromSnapshot(snap, me)
    local view = setmetatable({}, Match)

    view.board      = Board.restore(snap.pieces)
    view.deck       = cartasTapadas(snap.deck)
    view.discard    = snap.discard or {}
    view.current    = snap.current
    view.phase      = snap.phase
    view.turnNumber = snap.turnNumber or 0
    view.winner     = snap.winner
    view.result     = snap.result
    view.turnsWithoutCapture = snap.sinCaptura or 0
    view.events     = {}
    view.localPlayer = me
    view.isRemote    = true

    view.players = {}
    for idx = 1, 2 do
        local mano = (snap.hands and snap.hands[idx]) or { count = 0 }
        view.players[idx] = {
            id          = idx,
            hand        = mano.cards or cartasTapadas(mano.count),
            kingPieceId = snap.kings and snap.kings[idx] or nil,
        }
    end

    local t = snap.turn
    view.turn = {
        isFirstAction   = t and t.isFirstAction or false,
        lockedPieceId   = t and t.lockedPieceId or nil,
        lastKind        = t and t.lastKind or nil,
        kingComboReady  = t and t.kingComboReady or false,
        deadDiscardUsed = t and t.deadDiscardUsed or false,
        captured        = t and t.captured or false,
        playedByKind    = (t and t.playedByKind) or {},
        played          = (t and t.played) or {},
        pendingPromotion = nil,
    }

    -- Una vista no se muta en local: las acciones se piden al anfitrión y es
    -- él quien manda la foto siguiente. Si alguien intenta aplicar una acción
    -- aquí, mejor que falle a las claras que desincronizarse en silencio.
    view.apply = function()
        return false, "partidaRemota"
    end

    return view
end

return MatchView
