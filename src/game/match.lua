-- Motor de la partida: estado, acciones y reglas de Mascarade.
--
-- Principios de diseño:
--   * Lua puro. Ni una llamada a love.*. Se puede ejecutar desde los tests.
--   * No espera ni anima. Recibe acciones, muta el estado y encola eventos.
--     La capa visual consume esa cola y la reproduce paso a paso.
--   * Toda la validación vive aquí. La interfaz sólo pregunta qué puede hacer.
--
-- Uso típico:
--   local m = Match.new({ seed = 42 })
--   m:start()
--   local ok, err = m:apply({ type = "playCard", cardId = 3, pieceId = 9,
--                             col = 4, row = 5 })
--   for _, ev in ipairs(m:drainEvents()) do ... end

local Config = require("src.config")
local Cards  = require("src.game.cards")
local Board  = require("src.game.board")
local Moves  = require("src.game.moves")
local Rng    = require("src.game.rng")

local Match = {}
Match.__index = Match

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------

function Match.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Match)
    self.rng     = Rng.new(opts.seed)
    self.seed    = opts.seed
    self.phase   = "setup"   -- setup | action | promotion | gameover
    self.events  = {}
    self.winner  = nil
    self.result  = nil       -- "capture" | "draw"
    self.turnNumber = 0
    self.turnsWithoutCapture = 0
    return self
end

-- Reparte, tira la moneda y deja la partida lista para el primer turno.
function Match:start()
    self.board   = Board.newStandard()
    self.deck    = self.rng:shuffle(Cards.buildDeck())
    self.discard = {}
    self.players = {
        { id = 1, hand = {}, kingPieceId = nil },
        { id = 2, hand = {}, kingPieceId = nil },
    }

    local first = self.rng:int(1, 2)
    self:_emit({ t = "coinFlip", winner = first })

    -- Reparto inicial: 5 cartas a cada uno, empezando por quien abre.
    for _ = 1, Config.INITIAL_HAND do
        for offset = 0, 1 do
            local idx = ((first - 1 + offset) % 2) + 1
            local card = self:_popDeck()
            if card then
                local hand = self.players[idx].hand
                hand[#hand + 1] = card
            end
        end
    end
    self:_emit({ t = "dealt", counts = { #self.players[1].hand, #self.players[2].hand } })

    self:_startTurn(first)
    return self
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

function Match:_emit(ev)
    self.events[#self.events + 1] = ev
    return ev
end

-- Devuelve los eventos acumulados y vacía la cola.
function Match:drainEvents()
    local out = self.events
    self.events = {}
    return out
end

---------------------------------------------------------------------------
-- Mazo, descarte y mano
---------------------------------------------------------------------------

-- Vuelve a barajar el descarte dentro del mazo (regla C1).
function Match:_reshuffle()
    if #self.discard == 0 then return false end
    local n = #self.discard
    for i = 1, n do
        self.deck[#self.deck + 1] = self.discard[i]
        self.discard[i] = nil
    end
    self.rng:shuffle(self.deck)
    self:_emit({ t = "deckReshuffled", count = n })
    return true
end

-- Saca la carta de arriba del mazo, rebarajando el descarte si hace falta.
function Match:_popDeck()
    if #self.deck == 0 then self:_reshuffle() end
    if #self.deck == 0 then return nil end
    return table.remove(self.deck, 1)
end

-- Pone una carta en la cima del descarte.
function Match:_pushDiscard(card)
    table.insert(self.discard, 1, card)
end

-- Roba hasta n cartas respetando el límite de mano.
function Match:_drawCards(playerIdx, n)
    local player = self.players[playerIdx]
    local drawn = {}
    for _ = 1, n do
        if #player.hand >= Config.HAND_LIMIT then break end
        local card = self:_popDeck()
        if not card then break end
        player.hand[#player.hand + 1] = card
        drawn[#drawn + 1] = card
    end
    self:_emit({ t = "drew", player = playerIdx, cards = drawn,
                 count = #drawn, requested = n })
    return drawn
end

-- Busca una carta en la mano por id.
function Match:_findInHand(playerIdx, cardId)
    for i, c in ipairs(self.players[playerIdx].hand) do
        if c.id == cardId then return c, i end
    end
    return nil
end

-- Primera carta que no sea peón del descarte, mirando desde la cima.
function Match:_topNonPawn()
    for i, c in ipairs(self.discard) do
        if c.kind ~= "peon" then return c, i end
    end
    return nil
end

---------------------------------------------------------------------------
-- Turnos
---------------------------------------------------------------------------

function Match:_startTurn(playerIdx)
    self.current = playerIdx
    self.turnNumber = self.turnNumber + 1
    self.turn = {
        isFirstAction   = true,   -- aún no se ha gastado la acción del turno
        lockedPieceId   = nil,    -- ficha sobre la que se encadena
        playedByKind    = {},     -- disfraces jugados este turno, por tipo
        lastKind        = nil,    -- último disfraz (incluye el rey gratis)
        kingComboReady  = false,  -- excepción de la línea 30 del documento
        deadDiscardUsed = false,  -- válvula de carta muerta (1 por turno)
        captured        = false,  -- ¿se ha comido algo este turno?
        pendingPromotion = nil,
    }
    self.phase = "action"
    self:_emit({ t = "turnStart", player = playerIdx, number = self.turnNumber })
end

-- Cierra el turno. drawCount sólo es > 0 cuando el jugador pasa explícitamente.
function Match:_finishTurn(drawCount)
    if drawCount and drawCount > 0 then
        self:_drawCards(self.current, drawCount)
    end
    self:_emit({ t = "turnEnd", player = self.current })

    if self.turn.captured then
        self.turnsWithoutCapture = 0
    else
        self.turnsWithoutCapture = self.turnsWithoutCapture + 1
        if self.turnsWithoutCapture >= Config.DRAW_TURNS_WITHOUT_CAPTURE then
            return self:_gameOver(nil, "draw")
        end
    end

    self:_startTurn(3 - self.current)
end

function Match:_gameOver(winner, reason)
    self.phase  = "gameover"
    self.winner = winner
    self.result = reason
    self:_emit({ t = "gameOver", winner = winner, reason = reason })
end

---------------------------------------------------------------------------
-- Reglas de encadenado
---------------------------------------------------------------------------

function Match:_playedCount(kind)
    return self.turn.playedByKind[kind] or 0
end

-- ¿Se puede usar un disfraz de este tipo ahora mismo?
-- isFreeKing marca el movimiento gratis del rey, que cuenta como disfraz de
-- rey a efectos de las reglas 1 y 2 salvo en la excepción de la línea 30.
-- Devuelve true, o false + motivo.
function Match:_kindAllowed(kind, isFreeKing)
    local turn = self.turn

    -- Excepción: carta de rey sobre un rey ya coronado que comió, seguida del
    -- movimiento gratis del rey. Salta las reglas 1 y 2 a la vez.
    if isFreeKing and turn.kingComboReady then
        return true
    end

    -- Regla 1: no se repite el mismo disfraz dos veces seguidas.
    if turn.lastKind == kind then
        return false, "mismoDisfrazSeguido"
    end

    -- Regla 2: tope de disfraces por tipo y turno.
    if self:_playedCount(kind) >= Cards.chainLimit(kind) then
        return false, "limiteDeTipo"
    end

    return true
end

-- ¿Esta ficha es válida para encadenar? (regla 3)
function Match:_pieceAllowed(piece)
    if not piece or piece.owner ~= self.current then return false, "fichaAjena" end
    if self.turn.lockedPieceId and piece.id ~= self.turn.lockedPieceId then
        return false, "otraFicha"
    end
    return true
end

---------------------------------------------------------------------------
-- Consultas para la interfaz y la IA
---------------------------------------------------------------------------

function Match:currentPlayer()
    return self.players[self.current]
end

function Match:opponentOf(playerIdx)
    return 3 - playerIdx
end

-- Cartas que se pueden jugar ahora mismo.
-- Devuelve una lista de { card = carta, ok = bool, reason = string? }.
function Match:inspectHand()
    local out = {}
    if self.phase ~= "action" then return out end

    local player = self:currentPlayer()
    for _, card in ipairs(player.hand) do
        local ok, reason = self:_kindAllowed(card.kind, false)
        if ok then
            -- Además tiene que existir al menos un movimiento legal (regla A6-a).
            if #self:getMovablePieces(card.id) == 0 then
                ok, reason = false, "sinMovimiento"
            end
        end
        out[#out + 1] = { card = card, ok = ok, reason = reason }
    end
    return out
end

function Match:getPlayableCards()
    local out = {}
    for _, entry in ipairs(self:inspectHand()) do
        if entry.ok then out[#out + 1] = entry.card end
    end
    return out
end

-- Fichas que se pueden mover con una carta concreta.
function Match:getMovablePieces(cardId)
    local out = {}
    if self.phase ~= "action" then return out end
    local card = self:_findInHand(self.current, cardId)
    if not card then return out end

    local candidates
    if self.turn.lockedPieceId then
        local locked = self.board:get(self.turn.lockedPieceId)
        candidates = locked and { locked } or {}
    else
        candidates = self.board:piecesOf(self.current)
    end

    for _, piece in ipairs(candidates) do
        if #Moves.destinations(self.board, piece, card.kind) > 0 then
            out[#out + 1] = piece
        end
    end
    return out
end

-- Destinos legales de una ficha con una carta concreta.
function Match:getDestinations(cardId, pieceId)
    if self.phase ~= "action" then return {} end
    local card = self:_findInHand(self.current, cardId)
    if not card then return {} end
    if not self:_kindAllowed(card.kind, false) then return {} end
    local piece = self.board:get(pieceId)
    if not piece or not self:_pieceAllowed(piece) then return {} end
    return Moves.destinations(self.board, piece, card.kind)
end

-- ¿Puede el jugador usar el movimiento gratis del rey?
function Match:canFreeKingMove()
    if self.phase ~= "action" then return false, "faseIncorrecta" end
    local player = self:currentPlayer()
    if not player.kingPieceId then return false, "sinRey" end
    local king = self.board:get(player.kingPieceId)
    if not king then return false, "sinRey" end
    local ok, reason = self:_kindAllowed("rey", true)
    if not ok then return false, reason end
    if #Moves.destinations(self.board, king, "rey") == 0 then
        return false, "sinMovimiento"
    end
    return true
end

function Match:getKingDestinations()
    if not self:canFreeKingMove() then return {} end
    local king = self.board:get(self:currentPlayer().kingPieceId)
    return Moves.destinations(self.board, king, "rey")
end

-- Cartas muertas de la mano: su disfraz no tiene ningún movimiento legal con
-- ninguna ficha del jugador, ignorando las reglas de encadenado (regla A6-B).
function Match:getDeadCards()
    local out = {}
    if self.phase ~= "action" or self.turn.deadDiscardUsed then return out end
    for _, card in ipairs(self:currentPlayer().hand) do
        if not Moves.anyLegalFor(self.board, self.current, card.kind) then
            out[#out + 1] = card
        end
    end
    return out
end

-- Cuántas cartas robaría el jugador si terminase el turno ahora.
function Match:getEndTurnDrawCount()
    if self.phase ~= "action" then return 0 end
    return self.turn.isFirstAction and 2 or 1
end

-- Cartas de peón de la mano, para la promoción.
function Match:getPromotionCards()
    local out = {}
    if self.phase ~= "promotion" then return out end
    for _, card in ipairs(self:currentPlayer().hand) do
        if card.kind == "peon" then out[#out + 1] = card end
    end
    return out
end

-- Carta que se ganaría al promocionar.
function Match:getPromotionReward()
    if self.phase ~= "promotion" then return nil end
    return (self:_topNonPawn())
end

-- Enumeración completa de acciones legales. La usan los tests y la IA.
function Match:getLegalActions()
    local out = {}
    if self.phase == "gameover" then return out end

    if self.phase == "promotion" then
        out[#out + 1] = { type = "skipPromote" }
        for _, card in ipairs(self:getPromotionCards()) do
            out[#out + 1] = { type = "promote", cardId = card.id }
        end
        return out
    end

    out[#out + 1] = { type = "endTurn" }

    for _, card in ipairs(self:getPlayableCards()) do
        for _, piece in ipairs(self:getMovablePieces(card.id)) do
            for _, d in ipairs(self:getDestinations(card.id, piece.id)) do
                out[#out + 1] = { type = "playCard", cardId = card.id,
                                  pieceId = piece.id, col = d.col, row = d.row }
            end
        end
    end

    if self:canFreeKingMove() then
        for _, d in ipairs(self:getKingDestinations()) do
            out[#out + 1] = { type = "freeKingMove", col = d.col, row = d.row }
        end
    end

    for _, card in ipairs(self:getDeadCards()) do
        out[#out + 1] = { type = "discardDead", cardId = card.id }
    end

    return out
end

---------------------------------------------------------------------------
-- Resolución de un movimiento
---------------------------------------------------------------------------

-- ¿Dispara esta llegada la promoción? (reglas D1, D2, D3)
function Match:_promotionAvailable(piece, fromRow)
    local goal = Board.promotionRow(piece.owner)
    if piece.row ~= goal then return false end
    if fromRow == goal then return false end          -- D2: sólo al entrar
    if not self:_topNonPawn() then return false end   -- D3: descarte sin no-peones
    for _, card in ipairs(self:currentPlayer().hand) do
        if card.kind == "peon" then return true end
    end
    return false
end

-- Ejecuta el desplazamiento y la captura. Devuelve si comió.
function Match:_performMove(piece, col, row)
    local target = self.board:at(col, row)
    local captured = false

    if target then
        self.board:remove(target)
        captured = true
        self:_emit({ t = "pieceCaptured", pieceId = target.id, owner = target.owner,
                     col = col, row = row, wasKing = target.isKing })
    end

    local fromCol, fromRow = piece.col, piece.row
    self.board:move(piece, col, row)
    self:_emit({ t = "pieceMoved", pieceId = piece.id, owner = piece.owner,
                 fromCol = fromCol, fromRow = fromRow, col = col, row = row })

    return captured, fromRow
end

-- Qué pasa después de mover: fin de partida, promoción, acción extra o fin de turno.
function Match:_afterMove(piece, captured, fromRow, endsTurnRegardless)
    if captured then
        self.turn.captured = true
        local rival = self:opponentOf(self.current)
        if self.board:countOf(rival) == 0 then
            return self:_gameOver(self.current, "capture")
        end
    end

    if self:_promotionAvailable(piece, fromRow) then
        self.phase = "promotion"
        self.turn.pendingPromotion = {
            pieceId = piece.id,
            captured = captured,
            endsTurn = endsTurnRegardless,
        }
        self:_emit({ t = "promotionAvailable", pieceId = piece.id,
                     reward = self:_topNonPawn() })
        return
    end

    self:_resolvePostMove(captured, endsTurnRegardless)
end

function Match:_resolvePostMove(captured, endsTurnRegardless)
    if endsTurnRegardless or not captured then
        return self:_finishTurn(0)
    end
    -- Comió: gana una acción extra y el turno continúa.
    self.turn.isFirstAction = false
    self:_emit({ t = "extraAction", player = self.current })
    self.phase = "action"
end

---------------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------------

local handlers = {}

-- Pasar el turno robando (2 si es la primera acción, 1 si es la acción extra).
function handlers.endTurn(self)
    if self.phase ~= "action" then return false, "faseIncorrecta" end
    local n = self:getEndTurnDrawCount()
    self:_emit({ t = "passed", player = self.current, draws = n })
    self:_finishTurn(n)
    return true
end

-- Jugar una carta de disfraz y mover una ficha propia.
function handlers.playCard(self, action)
    if self.phase ~= "action" then return false, "faseIncorrecta" end

    local card, handIndex = self:_findInHand(self.current, action.cardId)
    if not card then return false, "cartaNoEnMano" end

    local ok, reason = self:_kindAllowed(card.kind, false)
    if not ok then return false, reason end

    local piece = self.board:get(action.pieceId)
    local pieceOk, pieceReason = self:_pieceAllowed(piece)
    if not pieceOk then return false, pieceReason end

    local dest = Moves.find(self.board, piece, card.kind, action.col, action.row)
    if not dest then return false, "destinoIlegal" end

    -- A partir de aquí la jugada es válida: mutamos.
    local player = self:currentPlayer()
    local wasKing = piece.isKing

    table.remove(player.hand, handIndex)
    self:_pushDiscard(card)
    self:_emit({ t = "cardPlayed", player = self.current, card = card,
                 pieceId = piece.id })

    local captured, fromRow = self:_performMove(piece, action.col, action.row)

    -- Coronación: la primera carta de rey convierte esa ficha en rey (regla B1).
    if card.kind == "rey" and not player.kingPieceId then
        piece.isKing = true
        player.kingPieceId = piece.id
        self:_emit({ t = "kingCrowned", player = self.current, pieceId = piece.id })
    end

    -- Contadores de encadenado.
    self.turn.playedByKind[card.kind] = self:_playedCount(card.kind) + 1
    self.turn.lastKind = card.kind
    self.turn.lockedPieceId = self.turn.lockedPieceId or piece.id
    -- La excepción de la línea 30 sólo se arma con una carta de rey jugada
    -- sobre un rey YA coronado que además comió.
    self.turn.kingComboReady = (card.kind == "rey") and wasKing and captured

    self:_afterMove(piece, captured, fromRow, false)
    return true
end

-- Mover el rey coronado sin gastar carta. Termina el turno, coma o no.
function handlers.freeKingMove(self, action)
    local ok, reason = self:canFreeKingMove()
    if not ok then return false, reason end

    local king = self.board:get(self:currentPlayer().kingPieceId)
    local dest = Moves.find(self.board, king, "rey", action.col, action.row)
    if not dest then return false, "destinoIlegal" end

    self:_emit({ t = "freeKingMove", player = self.current, pieceId = king.id })

    local captured, fromRow = self:_performMove(king, action.col, action.row)

    self.turn.playedByKind.rey = self:_playedCount("rey") + 1
    self.turn.lastKind = "rey"
    self.turn.kingComboReady = false

    self:_afterMove(king, captured, fromRow, true)
    return true
end

-- Promoción: descartar un peón y recuperar la primera no-peón del descarte.
function handlers.promote(self, action)
    if self.phase ~= "promotion" then return false, "faseIncorrecta" end

    local card, handIndex = self:_findInHand(self.current, action.cardId)
    if not card then return false, "cartaNoEnMano" end
    if card.kind ~= "peon" then return false, "noEsPeon" end

    -- El peón va a la cima del descarte y después buscamos la primera no-peón.
    table.remove(self.players[self.current].hand, handIndex)
    self:_pushDiscard(card)

    local reward, rewardIndex = self:_topNonPawn()
    if not reward then
        -- No debería ocurrir: _promotionAvailable ya lo comprueba.
        table.remove(self.discard, 1)
        table.insert(self.players[self.current].hand, handIndex, card)
        return false, "descarteSinNoPeon"
    end

    table.remove(self.discard, rewardIndex)
    local hand = self.players[self.current].hand
    hand[#hand + 1] = reward

    self:_emit({ t = "promoted", player = self.current,
                 discarded = card, gained = reward })

    local pending = self.turn.pendingPromotion
    self.turn.pendingPromotion = nil
    self.phase = "action"
    self:_resolvePostMove(pending.captured, pending.endsTurn)
    return true
end

function handlers.skipPromote(self)
    if self.phase ~= "promotion" then return false, "faseIncorrecta" end
    local pending = self.turn.pendingPromotion
    self.turn.pendingPromotion = nil
    self.phase = "action"
    self:_emit({ t = "promotionSkipped", player = self.current })
    self:_resolvePostMove(pending.captured, pending.endsTurn)
    return true
end

-- Válvula antibloqueo: descartar una carta muerta y robar 1. Gratis, 1 por turno.
function handlers.discardDead(self, action)
    if self.phase ~= "action" then return false, "faseIncorrecta" end
    if self.turn.deadDiscardUsed then return false, "yaUsado" end

    local card, handIndex = self:_findInHand(self.current, action.cardId)
    if not card then return false, "cartaNoEnMano" end
    if Moves.anyLegalFor(self.board, self.current, card.kind) then
        return false, "cartaNoMuerta"
    end

    -- Apartamos la carta ANTES de robar, para no poder recuperarla si el
    -- mazo se agota y hay que rebarajar el descarte.
    table.remove(self.players[self.current].hand, handIndex)
    local drawn = self:_drawCards(self.current, 1)
    self:_pushDiscard(card)
    self.turn.deadDiscardUsed = true

    self:_emit({ t = "deadCardDiscarded", player = self.current,
                 card = card, gained = drawn[1] })
    return true
end

-- Punto de entrada único de las acciones.
function Match:apply(action)
    if type(action) ~= "table" or not action.type then
        return false, "accionInvalida"
    end
    if self.phase == "gameover" then return false, "partidaTerminada" end
    local handler = handlers[action.type]
    if not handler then return false, "accionDesconocida" end
    return handler(self, action)
end

---------------------------------------------------------------------------
-- Depuración
---------------------------------------------------------------------------

local function handToString(hand)
    local parts = {}
    for _, c in ipairs(hand) do
        parts[#parts + 1] = string.format("%s(%d)", c.kind, c.id)
    end
    return #parts > 0 and table.concat(parts, " ") or "(vacia)"
end

function Match:toString()
    local lines = {}
    lines[#lines + 1] = self.board:toString()
    lines[#lines + 1] = string.format(
        "turno %d  jugador %d  fase %s  mazo %d  descarte %d  sinCaptura %d",
        self.turnNumber, self.current or 0, self.phase,
        #(self.deck or {}), #(self.discard or {}), self.turnsWithoutCapture)
    for i = 1, 2 do
        lines[#lines + 1] = string.format("  J%d fichas=%d rey=%s mano: %s",
            i, self.board:countOf(i),
            self.players[i].kingPieceId and tostring(self.players[i].kingPieceId) or "-",
            handToString(self.players[i].hand))
    end
    if self.turn then
        local kinds = {}
        for _, k in ipairs(Cards.KINDS) do
            local n = self.turn.playedByKind[k]
            if n and n > 0 then kinds[#kinds + 1] = k .. "x" .. n end
        end
        lines[#lines + 1] = string.format("  cadena: ultimo=%s ficha=%s jugados=[%s]%s",
            tostring(self.turn.lastKind), tostring(self.turn.lockedPieceId),
            table.concat(kinds, " "),
            self.turn.kingComboReady and " comboRey" or "")
    end
    return table.concat(lines, "\n")
end

return Match
