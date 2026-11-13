-- Censura del estado: qué parte de la partida puede ver cada jugador.
--
-- El anfitrión tiene la partida completa. Antes de mandar nada por la red,
-- recorta una foto distinta para cada jugador: su propia mano sí, la del rival
-- sólo como número. Las cartas del rival NUNCA salen de la máquina anfitriona.
--
-- Esto no es una comodidad: Mascarade es un juego de faroleo. Si el cliente
-- recibiera la mano del rival, bastaría con un depurador para verla.

local Cards = require("src.game.cards")

local Redact = {}

Redact.VERSION = 1

-- Carta tapada: ocupa sitio para que los recuentos cuadren, pero no dice nada.
local OCULTA = { id = 0, kind = "?" }

local function copiarCarta(c)
    return { id = c.id, kind = c.kind }
end

local function copiarCartas(lista)
    local out = {}
    for i, c in ipairs(lista or {}) do out[i] = copiarCarta(c) end
    return out
end

---------------------------------------------------------------------------
-- Foto del estado para un jugador concreto
---------------------------------------------------------------------------

function Redact.snapshot(match, forPlayer)
    local snap = {
        v           = Redact.VERSION,
        current     = match.current,
        phase       = match.phase,
        turnNumber  = match.turnNumber,
        winner      = match.winner,
        result      = match.result,
        sinCaptura  = match.turnsWithoutCapture,
        deck        = #match.deck,        -- sólo cuántas quedan
        discard     = copiarCartas(match.discard),   -- el descarte es público
        pieces      = {},
        hands       = {},
        kings       = {},
    }

    for _, p in ipairs(match.board:allPieces()) do
        snap.pieces[#snap.pieces + 1] = {
            id = p.id, owner = p.owner, col = p.col, row = p.row,
            hasMoved = p.hasMoved or false,
            isKing   = p.isKing or false,
        }
    end

    for idx = 1, 2 do
        local player = match.players[idx]
        local mano = { count = #player.hand }
        -- Sólo el destinatario recibe las cartas de su propia mano.
        if idx == forPlayer then mano.cards = copiarCartas(player.hand) end
        snap.hands[idx] = mano
        snap.kings[idx] = player.kingPieceId
    end

    local turn = match.turn
    if turn then
        snap.turn = {
            isFirstAction   = turn.isFirstAction or false,
            lockedPieceId   = turn.lockedPieceId,
            lastKind        = turn.lastKind,
            kingComboReady  = turn.kingComboReady or false,
            deadDiscardUsed = turn.deadDiscardUsed or false,
            captured        = turn.captured or false,
            playedByKind    = {},
            -- Las cartas usadas este turno están boca arriba: son públicas.
            played          = copiarCartas(turn.played),
        }
        for _, kind in ipairs(Cards.KINDS) do
            local n = turn.playedByKind[kind]
            if n and n > 0 then snap.turn.playedByKind[kind] = n end
        end
    end

    return snap
end

---------------------------------------------------------------------------
-- Censura de los eventos
---------------------------------------------------------------------------

-- La mayoría de eventos son públicos: una ficha que se mueve, una captura, una
-- coronación. Los que revelan cartas privadas hay que recortarlos.
local function redactEvent(ev, forPlayer)
    if ev.t == "drew" and ev.player ~= forPlayer then
        -- El rival ve cuántas cartas robas, no cuáles.
        return { t = "drew", player = ev.player, count = ev.count,
                 requested = ev.requested, cards = {} }
    end

    if ev.t == "deadCardDiscarded" and ev.player ~= forPlayer then
        -- La carta descartada va al descarte, así que es pública.
        -- La que roba a cambio, no.
        return { t = "deadCardDiscarded", player = ev.player, card = ev.card }
    end

    return ev
end

function Redact.events(events, forPlayer)
    local out = {}
    for i, ev in ipairs(events or {}) do
        out[i] = redactEvent(ev, forPlayer)
    end
    return out
end

Redact.OCULTA = OCULTA

return Redact
