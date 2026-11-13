-- Pantalla de partida.
--
-- No habla con el motor de reglas directamente, sino con una SESIÓN
-- (src/session). Hoy la sesión es local; mañana podrá ser remota y esta
-- pantalla no se entera.
--
-- Los eventos que devuelve la sesión no se pintan de golpe: pasan por un
-- SECUENCIADOR que los reproduce de uno en uno con pausas, para que una cadena
-- de capturas se pueda seguir con la vista.
--
-- Flujo de selección:
--   1. Click en una carta jugable  -> quedan marcadas las fichas movibles.
--   2. Click en una ficha movible  -> se muestran sus destinos legales.
--   3. Click en un destino         -> se aplica la jugada.
--   Click derecho o ESC cancela en cualquier punto.

local Gamestate = require("lib.gamestate")
local flux      = require("lib.flux")

local Config    = require("src.config")
local Palette   = require("src.palette")
local Fonts     = require("src.fonts")
local Settings  = require("src.settings")
local Audio     = require("src.audio")
local Fx        = require("src.fx")
local Screen    = require("src.screen")

local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Sprites   = require("src.ui.sprites")
local CardView  = require("src.ui.cardview")
local BoardView = require("src.ui.boardview")
local Tooltip   = require("src.ui.tooltip")
local Button    = require("src.ui.button")
local Sequencer = require("src.ui.sequencer")
local LY        = require("src.ui.layout")

local Session   = require("src.session")
local GameRules = require("src.game")
local Cards     = require("src.game.cards")
local L         = require("locale.es")

local Game = {}

-- Flags de desarrollo (ver README).
Game.autoplay  = 0
Game.clickTest = false
Game.seed      = nil
Game.stopAt    = nil
Game.bot       = false   -- juega solo a traves de la propia interfaz

---------------------------------------------------------------------------
-- Estado de la vista
---------------------------------------------------------------------------

local session, match, seq
local t = 0

local sel   = { cardId = nil, pieceId = nil, kingMove = false, deadMode = false }
local hover = { cardId = nil, pieceId = nil, col = nil, row = nil }

-- Estado visual: posición animada de cada ficha, elevación de cada carta y
-- las fichas que se están muriendo (ya no están en el tablero pero aún se ven).
local vis = { pieces = {}, cards = {}, dying = {} }

-- Superposiciones que detienen la partida.
local handoff = { active = false, player = 1 }
local coin    = { active = false, winner = 1, t = 0, dur = 1.7 }

local buttons, promoButtons, overButtons, handoffButton = {}, {}, {}, nil

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

local function pieceVisual(piece)
    local v = vis.pieces[piece.id]
    if not v then
        local cx, cy = LY.cellCenter(piece.col, piece.row)
        v = { x = cx, y = cy, lift = 0, scale = 1 }
        vis.pieces[piece.id] = v
    end
    return v
end

local function cardVisual(cardId)
    local v = vis.cards[cardId]
    if not v then
        v = { lift = 0, scale = 1 }
        vis.cards[cardId] = v
    end
    return v
end

local function clearSelection()
    sel.cardId, sel.pieceId, sel.kingMove, sel.deadMode = nil, nil, false, false
end

-- Mientras se reproduce una animación o hay una superposición, no se juega.
local function locked()
    return seq:busy() or handoff.active or coin.active
end

local function activeDestinations()
    if locked() then return {}, nil end
    if sel.kingMove then
        return match:getKingDestinations(), match:currentPlayer().kingPieceId
    end
    if sel.cardId and sel.pieceId then
        return match:getDestinations(sel.cardId, sel.pieceId), sel.pieceId
    end
    if sel.cardId and hover.pieceId then
        return match:getDestinations(sel.cardId, hover.pieceId), hover.pieceId
    end
    return {}, nil
end

local function isMovable(pieceId)
    if not sel.cardId then return false end
    for _, p in ipairs(match:getMovablePieces(sel.cardId)) do
        if p.id == pieceId then return true end
    end
    return false
end

local function deadSet()
    local set = {}
    for _, c in ipairs(match:getDeadCards()) do set[c.id] = true end
    return set
end

-- ¿Se puede ver la mano del jugador activo? Durante el relevo está tapada.
local function handVisible()
    return not handoff.active and not coin.active
end

---------------------------------------------------------------------------
-- Reproducción de eventos
---------------------------------------------------------------------------

-- Devuelve cuántos segundos esperar antes del siguiente evento, o "block"
-- para detenerse hasta que el jugador confirme.
local function playEvent(ev)
    if ev.t == "coinFlip" then
        coin.active, coin.winner, coin.t = true, ev.winner, 0
        Audio.play("coin")
        return coin.dur

    elseif ev.t == "dealt" then
        Audio.play("cardDraw")
        return 0.35

    elseif ev.t == "turnStart" then
        Audio.play("turnChange")
        clearSelection()
        if session:needsHandoff() then
            handoff.active, handoff.player = true, ev.player
            return "block"
        end
        return 0.2

    elseif ev.t == "cardPlayed" then
        Audio.play("cardPlace")
        Fx.puff(Config.CANVAS_W / 2, LY.hand.y, CardView.accent(ev.card.kind))
        return 0.22

    elseif ev.t == "pieceCaptured" then
        -- La ficha comida no desaparece de golpe: se queda muriéndose encima
        -- del tablero mientras la atacante se desliza hasta su casilla.
        local cx, cy = LY.cellCenter(ev.col, ev.row)
        local d = { owner = ev.owner, isKing = ev.wasKing,
                    x = cx, y = cy, scale = 1, alpha = 1 }
        vis.dying[#vis.dying + 1] = d
        vis.pieces[ev.pieceId] = nil

        Fx.after(0.18, function()
            Fx.impact(cx, cy, Palette.player[ev.owner])
            Fx.popup(L.partida.captura, cx, cy - 14, { color = Palette.red })
            Audio.play("capture")
            flux.to(d, 0.20, { scale = 0.1, alpha = 0 }):ease("backin")
                :oncomplete(function()
                    for i = #vis.dying, 1, -1 do
                        if vis.dying[i] == d then table.remove(vis.dying, i) end
                    end
                end)
        end)
        return 0

    elseif ev.t == "pieceMoved" then
        local piece = match.board:get(ev.pieceId)
        if piece then
            local v = pieceVisual(piece)
            local cx, cy = LY.cellCenter(ev.col, ev.row)
            flux.to(v, Config.T.pieceMove, { x = cx, y = cy }):ease("quadout")
        end
        Audio.play("pieceMove")
        return 0.34

    elseif ev.t == "kingCrowned" then
        local piece = match.board:get(ev.pieceId)
        if piece then
            local v = pieceVisual(piece)
            Fx.celebrate(v.x, v.y, Palette.gold)
            Fx.popup(L.partida.coronacion, v.x, v.y - 18,
                { color = Palette.gold, font = Fonts.boldBig })
        end
        Audio.play("crown")
        return 0.75

    elseif ev.t == "extraAction" then
        Fx.popup(L.partida.accionExtra, Config.CANVAS_W / 2, 118,
            { color = Palette.green, font = Fonts.boldBig })
        Audio.play("extraAction")
        return 0.45

    elseif ev.t == "promotionAvailable" then
        return 0.3

    elseif ev.t == "promoted" then
        Fx.popup(L.partida.promocion, Config.CANVAS_W / 2, 128,
            { color = Palette.gold, font = Fonts.boldBig })
        Audio.play("promote")
        return 0.55

    elseif ev.t == "promotionSkipped" then
        return 0.1

    elseif ev.t == "deadCardDiscarded" then
        Audio.play("cardFlip")
        return 0.3

    elseif ev.t == "passed" then
        return 0.12

    elseif ev.t == "drew" then
        if ev.count > 0 then Audio.play("cardDraw") end
        return ev.count > 0 and 0.3 or 0

    elseif ev.t == "playedDiscarded" then
        Audio.play("cardFlip", { pitch = 0.85 })
        return 0.3

    elseif ev.t == "deckReshuffled" then
        Fx.popup("MAZO REBARAJADO", Config.CANVAS_W / 2, 140,
            { color = Palette.blue, font = Fonts.small })
        Audio.play("cardDraw", { pitch = 0.75 })
        return 0.45

    elseif ev.t == "turnEnd" then
        return 0.15

    elseif ev.t == "gameOver" then
        Fx.shake.add(0.7)
        Audio.play(ev.winner and "victory" or "defeat")
        return 0.7
    end

    return 0
end

-- Pide una acción a la sesión. Los eventos que genere se encolan.
local function act(action)
    if locked() then return false end
    local ok, err = session:request(action)
    if not ok then
        Audio.play("error")
        if err then
            Fx.popup(L.motivos[err] or err, Config.CANVAS_W / 2, 150,
                { color = Palette.red, font = Fonts.small })
        end
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- Botones
---------------------------------------------------------------------------

local function buildButtons()
    local a = LY.panelAcciones
    local bw, bh, gap = a.w - 16, 20, 6
    local bx, by = a.x + 8, a.y + 24

    buttons = {}
    buttons.endTurn = Button({
        label = L.partida.terminarTurno, accent = Palette.green,
        x = bx, y = by, w = bw, h = bh,
        onClick = function() clearSelection(); act({ type = "endTurn" }) end,
    })
    buttons.king = Button({
        label = L.partida.moverRey, accent = Palette.gold,
        x = bx, y = by + (bh + gap), w = bw, h = bh,
        onClick = function()
            sel.cardId, sel.pieceId, sel.deadMode = nil, nil, false
            sel.kingMove = not sel.kingMove
        end,
    })
    buttons.dead = Button({
        label = L.partida.cambiarMuerta, accent = Palette.purple,
        x = bx, y = by + (bh + gap) * 2, w = bw, h = bh,
        onClick = function()
            sel.cardId, sel.pieceId, sel.kingMove = nil, nil, false
            sel.deadMode = not sel.deadMode
        end,
    })

    handoffButton = Button({
        label = L.relevo.listo, accent = Palette.gold,
        x = Config.CANVAS_W / 2 - 50, y = 196, w = 100, h = 22,
        onClick = function()
            handoff.active = false
            seq:resume()
        end,
    })
end

local function refreshButtons()
    local playable = (match.phase == "action") and not locked()
    buttons.endTurn:setEnabled(playable)
    buttons.endTurn.label = playable
        and string.format(L.partida.robaN, match:getEndTurnDrawCount())
        or L.partida.terminarTurno
    buttons.king:setEnabled(playable and match:canFreeKingMove())
    buttons.dead:setEnabled(playable and #match:getDeadCards() > 0)
end

---------------------------------------------------------------------------
-- Entrada al estado
---------------------------------------------------------------------------

-- OJO: hump.gamestate pasa el estado ANTERIOR como primer argumento de enter.
-- La sesion, si viene de fuera, llega en el segundo.
--   Gamestate.switch(Game, miSesion)
function Game:enter(_previous, newSession)
    Fx.background.setMood("partida")
    Fx.background.setIntensity(0.5)
    Fx.clear()

    session = newSession or Session.Local({ seed = Game.seed })
    match   = session:view()
    seq     = Sequencer(playEvent)

    vis.pieces, vis.cards, vis.dying = {}, {}, {}
    clearSelection()
    handoff.active, coin.active = false, false
    promoButtons, overButtons = {}, {}
    t = 0

    buildButtons()
    seq:push(session:poll())

    if Game.autoplay and Game.autoplay > 0 then self:runAutoplay() end
    if Game.clickTest then self:runClickTest() end
end

function Game:leave()
    if session then session:close() end
end

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------

function Game:update(dt, mx, my)
    t = t + dt
    match = session:view()

    session:update(dt)
    seq:push(session:poll())
    seq:update(dt)

    if coin.active then
        coin.t = coin.t + dt
        if coin.t >= coin.dur then coin.active = false end
    end

    -- ¿Qué hay bajo el ratón?
    hover.cardId, hover.pieceId, hover.col, hover.row = nil, nil, nil, nil
    if not locked() then
        local hand = match:currentPlayer().hand
        for i = #hand, 1, -1 do
            local x, y = LY.handSlot(i, #hand)
            local v = cardVisual(hand[i].id)
            if mx >= x and mx < x + LY.card.w
               and my >= y - v.lift and my < y + LY.card.h - v.lift then
                hover.cardId = hand[i].id
                break
            end
        end
        if not hover.cardId then
            local col, row = LY.cellAt(mx, my)
            if col then
                hover.col, hover.row = col, row
                local piece = match.board:at(col, row)
                if piece then hover.pieceId = piece.id end
            end
        end
    end

    -- Animación de la mano.
    for _, card in ipairs(match:currentPlayer().hand) do
        local v = cardVisual(card.id)
        local wantLift = 0
        if handVisible() then
            if hover.cardId == card.id then wantLift = 10 end
            if sel.cardId == card.id then wantLift = 14 end
        end
        if v.target ~= wantLift then
            v.target = wantLift
            flux.to(v, Config.T.cardHover, { lift = wantLift })
                :ease(wantLift > 0 and "backout" or "quadout")
        end
    end

    -- Animación de las fichas.
    for _, piece in ipairs(match.board:allPieces()) do
        local v = pieceVisual(piece)
        local wantLift, wantScale = 0, 1
        if hover.pieceId == piece.id and (isMovable(piece.id) or not sel.cardId) then
            wantLift, wantScale = 5, 1.1
        end
        if sel.pieceId == piece.id then wantLift, wantScale = 6, 1.14 end
        if v.targetLift ~= wantLift then
            v.targetLift = wantLift
            flux.to(v, 0.16, { lift = wantLift, scale = wantScale }):ease("backout")
        end
    end

    if Game.bot then self:updateBot(dt) end

    refreshButtons()
    for _, b in pairs(buttons) do b:update(dt, mx, my) end
    for _, b in ipairs(promoButtons) do b:update(dt, mx, my) end
    for _, b in ipairs(overButtons) do b:update(dt, mx, my) end
    if handoff.active then handoffButton:update(dt, mx, my) end
end

---------------------------------------------------------------------------
-- Dibujado
---------------------------------------------------------------------------

local function drawBoard()
    BoardView.drawFrame()
    BoardView.drawCells()

    local dests, fromId = activeDestinations()
    local phase = t * 20

    if fromId then
        local p = match.board:get(fromId)
        if p then BoardView.highlight(p.col, p.row, "select", phase) end
    end

    if sel.cardId and not sel.pieceId and not sel.kingMove then
        for _, p in ipairs(match:getMovablePieces(sel.cardId)) do
            if p.id ~= hover.pieceId then
                local x, y = LY.cellOrigin(p.col, p.row)
                local a = 0.18 + 0.10 * math.sin(t * 5)
                love.graphics.setColor(Palette.rgba(Palette.gold, a))
                love.graphics.rectangle("fill", x, y, LY.CELL, LY.CELL)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end

    for _, d in ipairs(dests) do
        BoardView.highlight(d.col, d.row, d.capture and "capture" or "move", phase)
    end

    -- Fichas muriéndose, por debajo de las vivas.
    for _, d in ipairs(vis.dying) do
        BoardView.drawPieceAt({ owner = d.owner, isKing = d.isKing }, d.x, d.y,
            { scale = d.scale, alpha = d.alpha })
    end

    for _, piece in ipairs(match.board:allPieces()) do
        local v = pieceVisual(piece)
        BoardView.drawPieceAt(piece, v.x, v.y, { lift = v.lift, scale = v.scale })
    end
end

local function drawPlayerPanel(area, idx, isCurrent)
    local accent = Palette.player[idx]
    Panel.draw(area.x, area.y, area.w, area.h, {
        fill = isCurrent and Palette.mix(Palette.panel, accent, 0.14) or Palette.panel,
        border = isCurrent and accent or Palette.line,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 3,
    })

    Text.outlined(session:describe(idx), area.x + 8, area.y + 6,
        { font = Fonts.bold, color = accent, outline = Palette.line })

    if isCurrent then
        local a = 0.6 + 0.4 * math.sin(t * 4)
        Text.outlined(L.partida.suTurno, area.x + area.w - 54, area.y + 6,
            { font = Fonts.small, color = Palette.gold, outline = Palette.line, alpha = a })
    end

    Text.outlined(string.format("%s %d   %s %d", L.partida.fichas,
        match.board:countOf(idx), L.partida.mano, #match.players[idx].hand),
        area.x + 8, area.y + 21,
        { font = Fonts.small, color = Palette.bone, outline = Palette.line })

    local king = match.board:kingOf(idx)
    if king then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Sprites.crownIcon, area.x + 8, area.y + 35)
        Text.outlined(string.format("%s en %d,%d", L.partida.rey, king.col, king.row),
            area.x + 24, area.y + 34,
            { font = Fonts.small, color = Palette.gold, outline = Palette.line })
    else
        Text.outlined(L.partida.sinRey, area.x + 8, area.y + 34,
            { font = Fonts.small, color = Palette.grayDark, outline = Palette.line })
    end
end

local function drawChainPanel()
    local area = LY.panelCadena
    Panel.draw(area.x, area.y, area.w, area.h, {
        fill = Palette.panel, border = Palette.line,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 3,
    })
    Text.outlined(L.partida.cadena, area.x + 8, area.y + 6,
        { font = Fonts.bold, color = Palette.bone, outline = Palette.line })
    Text.outlined("T" .. tostring(match.turnNumber), area.x + area.w - 30, area.y + 6,
        { font = Fonts.small, color = Palette.grayDark, outline = Palette.line })
    Panel.divider(area.x + 7, area.y + 19, area.w - 14)

    local turn = match.turn or {}
    for i, kind in ipairs(Cards.KINDS) do
        local x = area.x + 10 + ((i - 1) % 3) * 58
        local y = area.y + 26 + math.floor((i - 1) / 3) * 30
        local used  = (turn.playedByKind and turn.playedByKind[kind]) or 0
        local limit = Cards.chainLimit(kind)
        local agotado, vetado = used >= limit, (turn.lastKind == kind)

        love.graphics.setColor(1, 1, 1, agotado and 0.3 or 1)
        love.graphics.draw(Sprites.glyph[kind], x, y - 2)
        love.graphics.setColor(1, 1, 1, 1)

        local color = Palette.bone
        if agotado then color = Palette.grayDark
        elseif vetado then color = Palette.red
        elseif used > 0 then color = Palette.gold end
        Text.outlined(string.format("%d/%d", used, limit), x + 18, y + 4,
            { font = Fonts.small, color = color, outline = Palette.line })
    end

    local footer, color = L.partida.sinCadena, Palette.grayDark
    if turn.lockedPieceId then
        footer, color = string.format(L.partida.bloqueada, turn.lockedPieceId), Palette.gold
    elseif turn.lastKind then
        footer, color = string.format(L.partida.ultimo, L.cartas[turn.lastKind]), Palette.red
    end
    Text.outlined(footer, area.x + 8, area.y + area.h - 14,
        { font = Fonts.small, color = color, outline = Palette.line })
end

local function drawPiles()
    local area = LY.panelPilas
    Panel.draw(area.x, area.y, area.w, area.h, {
        fill = Palette.panel, border = Palette.line,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 3,
    })
    local y = area.y + 10

    if #match.deck > 0 then
        CardView.drawBack(area.x + 10, y, { small = true })
    else
        CardView.drawSlot(area.x + 10, y, { small = true, phase = t * 10 })
    end
    Text.outlined(L.partida.mazo, area.x + 46, y + 6,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })
    Text.outlined(tostring(#match.deck), area.x + 46, y + 18,
        { font = Fonts.boldBig, color = Palette.bone, outline = Palette.line })

    local dx = area.x + 100
    if match.discard[1] then
        CardView.draw(match.discard[1].kind, dx, y, { small = true })
    else
        CardView.drawSlot(dx, y, { small = true, phase = t * 10 })
    end
    Text.outlined(L.partida.descarte, dx + 36, y + 6,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })
    Text.outlined(tostring(#match.discard), dx + 36, y + 18,
        { font = Fonts.boldBig, color = Palette.bone, outline = Palette.line })
end

local function drawPlayed()
    local area = LY.panelJugadas
    Panel.draw(area.x, area.y, area.w, area.h, {
        fill = Palette.hex("#1b1428"), border = Palette.line,
        highlight = nil, radius = 3, shadowOffset = 3,
    })
    Text.outlined(L.partida.jugadas, area.x + 8, area.y + 5,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })

    local played = match:getPlayedThisTurn()
    if #played == 0 then
        Text.outlined("-", area.x + 10, area.y + 28,
            { font = Fonts.small, color = Palette.grayDark, outline = Palette.line })
        return
    end
    local step = math.min(LY.cardSmall.w + 4, math.floor((area.w - 20) / #played))
    for i, card in ipairs(played) do
        CardView.draw(card.kind, area.x + 10 + (i - 1) * step, area.y + 16,
            { small = true, shadowOffset = 2 })
    end
end

local function drawActions()
    local area = LY.panelAcciones
    Panel.draw(area.x, area.y, area.w, area.h, {
        fill = Palette.panel, border = Palette.line,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 3,
    })
    local hint = ""
    if locked() then hint = "..."
    elseif sel.deadMode then hint = L.partida.eligeMuerta
    elseif sel.kingMove or (sel.cardId and sel.pieceId) then hint = L.partida.eligeDestino
    elseif sel.cardId then hint = L.partida.eligeFicha end
    Text.outlined(hint, area.x + 8, area.y + 8,
        { font = Fonts.small, color = Palette.gold, outline = Palette.line })

    for _, b in pairs(buttons) do b:draw() end
end

local function drawHand()
    local h = LY.hand
    Panel.draw(h.x, h.y, h.w, h.h, {
        fill = Palette.hex("#1b1428"), border = Palette.hex("#3a2a50"),
        highlight = nil, radius = 3, shadowOffset = 0,
    })

    local hand = match:currentPlayer().hand
    local inspect = handVisible() and match:inspectHand() or nil
    local dead = handVisible() and deadSet() or {}

    for i, card in ipairs(hand) do
        local x, y = LY.handSlot(i, #hand)
        local v = cardVisual(card.id)
        local idle = (v.lift == 0) and math.sin(t * 1.6 + i * 0.8) * 1.2 or 0

        if not handVisible() then
            -- Durante el relevo la mano del jugador entrante está tapada.
            CardView.drawBack(x, y + idle, {})
        else
            local playable = inspect[i] and inspect[i].ok
            CardView.draw(card.kind, x, y - v.lift + idle, {
                selected = (sel.cardId == card.id),
                disabled = not playable and not (sel.deadMode and dead[card.id]),
                scale = v.scale,
            })
            if sel.deadMode and dead[card.id] then
                local a = 0.5 + 0.5 * math.sin(t * 6)
                Panel.dashed(x - 2, y - v.lift + idle - 2,
                    LY.card.w + 4, LY.card.h + 4,
                    { color = Palette.purple, alpha = a, phase = t * 22 })
            end
        end
    end

    local rival = match:opponentOf(match.current)
    local n = #match.players[rival].hand
    local rx = h.x + h.w - 112
    Text.outlined(string.format("%s J%d", L.partida.mano, rival), rx, h.y + 10,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })
    Text.outlined(tostring(n), rx + 80, h.y + 8,
        { font = Fonts.boldBig, color = Palette.bone, outline = Palette.line })
    for i = 1, n do
        CardView.drawBack(rx + (i - 1) * 19, h.y + 24,
            { small = true, scale = 0.62, shadowOffset = 2 })
    end
end

---------------------------------------------------------------------------
-- Superposiciones
---------------------------------------------------------------------------

-- Cara o cruz: se lanza una ficha que gira sobre su eje vertical.
local function drawCoin()
    local p = math.min(coin.t / coin.dur, 1)
    local cx, cy = LY.cellCenter(4.5, 4.5)

    local fade = math.min(p * 4, 1)
    Screen.scrim(0.7 * fade)

    Panel.draw(cx - 110, cy - 86, 220, 160, {
        fill = Palette.panel, border = Palette.gold,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 4, alpha = fade,
    })

    -- El giro frena con el tiempo; la cara que se ve alterna con cada media vuelta.
    local phase = 9 * math.pi * (1 - (1 - p) ^ 3)
    local face  = (p > 0.9) and coin.winner or ((math.floor(phase / math.pi) % 2) + 1)
    local sx    = math.abs(math.cos(phase))
    local hop   = math.abs(math.sin(p * math.pi * 2.5)) * 26 * (1 - p)

    local img = Sprites.piece[face]
    local d = Sprites.DISC
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", cx, cy + 20, 14 * (1 - hop / 40), 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(cx), math.floor(cy - hop), 0,
        math.max(sx, 0.08) * 2, 2, d / 2, d / 2)

    Text.centered(L.moneda.titulo, 0, cy - 72, Config.CANVAS_W,
        { font = Fonts.boldBig, color = Palette.gold, outline = Palette.line, shadow = 2 })
    if p > 0.85 then
        Text.centered(string.format(L.moneda.empieza, session:describe(coin.winner)),
            0, cy + 44, Config.CANVAS_W,
            { font = Fonts.boldBig, color = Palette.player[coin.winner],
              outline = Palette.line, shadow = 2, alpha = (p - 0.85) / 0.15 })
    end
end

local HAND_OVER = { x = 170, y = 120, w = 300, h = 110 }

local function drawHandoff()
    Screen.scrim(0.72)

    local accent = Palette.player[handoff.player]
    Panel.draw(HAND_OVER.x, HAND_OVER.y, HAND_OVER.w, HAND_OVER.h, {
        fill = Palette.panel, border = accent,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 4,
    })
    Text.centered(L.relevo.titulo, HAND_OVER.x, HAND_OVER.y + 10, HAND_OVER.w,
        { font = Fonts.boldBig, color = Palette.gold, outline = Palette.line, shadow = 2 })
    Text.centered(string.format(L.relevo.texto, session:describe(handoff.player)),
        HAND_OVER.x, HAND_OVER.y + 36, HAND_OVER.w,
        { font = Fonts.bold, color = accent, outline = Palette.line })
    Text.centered(L.relevo.oculta, HAND_OVER.x, HAND_OVER.y + 50, HAND_OVER.w,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })

    handoffButton:draw()
end

local PROMO = { x = 190, y = 100, w = 260, h = 130 }

local function buildPromoButtons()
    promoButtons = {}
    if #match:getPromotionCards() == 0 then return end
    promoButtons[1] = Button({
        label = "Descartar un peon", accent = Palette.gold,
        x = PROMO.x + 16, y = PROMO.y + PROMO.h - 52, w = 108, h = 20,
        onClick = function()
            local cards = match:getPromotionCards()
            if cards[1] then act({ type = "promote", cardId = cards[1].id }) end
            promoButtons = {}
        end,
    })
    promoButtons[2] = Button({
        label = L.partida.promoNo, accent = Palette.gray,
        x = PROMO.x + 136, y = PROMO.y + PROMO.h - 52, w = 108, h = 20,
        onClick = function() act({ type = "skipPromote" }); promoButtons = {} end,
        sound = "back",
    })
end

local function drawPromotion()
    Screen.scrim(0.55)

    Panel.draw(PROMO.x, PROMO.y, PROMO.w, PROMO.h, {
        fill = Palette.panel, border = Palette.gold,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 4,
    })
    Text.centered(L.partida.promoTitulo, PROMO.x, PROMO.y + 8, PROMO.w,
        { font = Fonts.boldBig, color = Palette.gold, outline = Palette.line, shadow = 2 })
    Text.outlined(L.partida.promoTexto, PROMO.x + 14, PROMO.y + 28,
        { font = Fonts.small, color = Palette.bone, outline = Palette.line,
          limit = PROMO.w - 28, align = "left" })

    local reward = match:getPromotionReward()
    if reward then
        CardView.draw(reward.kind, PROMO.x + (PROMO.w - LY.cardSmall.w) / 2,
            PROMO.y + 46, { small = true })
    end
    for _, b in ipairs(promoButtons) do b:draw() end
end

local OVER = { x = 200, y = 100, w = 240, h = 128 }

local function buildOverButtons()
    overButtons = {}
    overButtons[1] = Button({
        label = L.fin.reiniciar, accent = Palette.green,
        x = OVER.x + 20, y = OVER.y + 70, w = 200, h = 20,
        onClick = function() Game:enter() end,
    })
    overButtons[2] = Button({
        label = L.fin.menu, accent = Palette.gray,
        x = OVER.x + 20, y = OVER.y + 96, w = 200, h = 20,
        onClick = function() Gamestate.switch(require("src.states.menu")) end,
        sound = "back",
    })
end

local function drawGameOver()
    Screen.scrim(0.6)

    local accent = match.winner and Palette.player[match.winner] or Palette.gray
    Panel.draw(OVER.x, OVER.y, OVER.w, OVER.h, {
        fill = Palette.panel, border = accent,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 4,
    })
    local title = match.winner and string.format(L.fin.victoria, match.winner) or L.fin.tablas
    local sub   = match.winner and L.fin.porCaptura or L.fin.porTablas
    Text.centered(title, OVER.x, OVER.y + 14, OVER.w,
        { font = Fonts.boldBig, color = accent, outline = Palette.line, shadow = 2 })
    Text.centered(sub, OVER.x, OVER.y + 38, OVER.w,
        { font = Fonts.small, color = Palette.bone, outline = Palette.line })
    for _, b in ipairs(overButtons) do b:draw() end
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------

local function updateTooltip(mx, my)
    if hover.cardId and handVisible() then
        local card, entry
        local inspect = match:inspectHand()
        for i, c in ipairs(match:currentPlayer().hand) do
            if c.id == hover.cardId then card, entry = c, inspect[i] end
        end
        if card then
            Tooltip.set(mx, my, {
                title  = L.cartas[card.kind],
                lines  = { L.cartasDesc[card.kind] },
                accent = CardView.accent(card.kind),
                warn   = (entry and not entry.ok)
                         and (L.motivos[entry.reason] or entry.reason) or nil,
            })
        end
        return
    end

    if hover.pieceId then
        local p = match.board:get(hover.pieceId)
        if p then
            local lines = { session:describe(p.owner) }
            if p.isKing then
                lines[#lines + 1] = L.partida.reyIntocable
            elseif not p.hasMoved then
                lines[#lines + 1] = "Nunca se ha movido: avance doble"
            end
            Tooltip.set(mx, my, {
                title  = p.isKing and "REY CORONADO" or ("Ficha #" .. p.id),
                lines  = lines,
                accent = Palette.player[p.owner],
            })
        end
    end
end

---------------------------------------------------------------------------
-- Draw principal
---------------------------------------------------------------------------

function Game:draw()
    drawBoard()
    drawPlayerPanel(LY.panelRival, match:opponentOf(match.current), false)
    drawPlayerPanel(LY.panelPropio, match.current, true)
    drawChainPanel()
    drawPiles()
    drawPlayed()
    drawActions()
    drawHand()

    if coin.active then
        drawCoin()
    elseif handoff.active then
        drawHandoff()
    elseif match.phase == "promotion" and not seq:busy() then
        if #promoButtons == 0 then buildPromoButtons() end
        drawPromotion()
    elseif match.phase == "gameover" and not seq:busy() then
        if #overButtons == 0 then buildOverButtons() end
        drawGameOver()
    elseif not locked() then
        updateTooltip(Screen.toCanvas(love.mouse.getPosition()))
    end

    Tooltip.draw()

    if Settings.get("mostrarAyuda") then
        local ayuda = { "ESC  pausa", "Click dcho  cancela",
                        "ESPACIO  terminar turno", "F1 CRT   F2 bloom" }
        for i, linea in ipairs(ayuda) do
            Text.outlined(linea, LY.hand.x + 10, LY.hand.y + 10 + (i - 1) * 11,
                { font = Fonts.small, color = Palette.grayDark, outline = Palette.line })
        end
    end
end

---------------------------------------------------------------------------
-- Entrada
---------------------------------------------------------------------------

function Game:mousepressed(mx, my, btn)
    if coin.active then return end

    if handoff.active then
        handoffButton:mousepressed(mx, my, btn)
        return
    end
    if match.phase == "gameover" and not seq:busy() then
        for _, b in ipairs(overButtons) do b:mousepressed(mx, my, btn) end
        return
    end
    if match.phase == "promotion" and not seq:busy() then
        for _, b in ipairs(promoButtons) do b:mousepressed(mx, my, btn) end
        return
    end
    if locked() then return end

    if btn == 2 then
        clearSelection()
        Audio.play("back")
        return
    end
    if btn ~= 1 then return end

    for _, b in pairs(buttons) do
        if b:mousepressed(mx, my, btn) then return end
    end

    if hover.cardId then
        if sel.deadMode then
            if deadSet()[hover.cardId] then
                act({ type = "discardDead", cardId = hover.cardId })
                sel.deadMode = false
            else
                Audio.play("error")
            end
            return
        end
        local inspect = match:inspectHand()
        for i, c in ipairs(match:currentPlayer().hand) do
            if c.id == hover.cardId then
                if inspect[i].ok then
                    sel.kingMove, sel.pieceId = false, nil
                    sel.cardId = (sel.cardId == c.id) and nil or c.id
                    Audio.play("cardFlip")
                    if sel.cardId then
                        local movable = match:getMovablePieces(sel.cardId)
                        if #movable == 1 then sel.pieceId = movable[1].id end
                    end
                else
                    Audio.play("error")
                end
                return
            end
        end
        return
    end

    if hover.col then
        local dests, fromId = activeDestinations()
        for _, d in ipairs(dests) do
            if d.col == hover.col and d.row == hover.row then
                if sel.kingMove then
                    act({ type = "freeKingMove", col = d.col, row = d.row })
                else
                    act({ type = "playCard", cardId = sel.cardId,
                          pieceId = sel.pieceId or fromId, col = d.col, row = d.row })
                end
                clearSelection()
                return
            end
        end
        if sel.cardId and hover.pieceId and isMovable(hover.pieceId) then
            sel.pieceId = hover.pieceId
            Audio.play("click")
            return
        end
    end

    clearSelection()
end

function Game:mousereleased(mx, my, btn)
    for _, b in pairs(buttons) do b:mousereleased(mx, my, btn) end
    for _, b in ipairs(promoButtons) do b:mousereleased(mx, my, btn) end
    for _, b in ipairs(overButtons) do b:mousereleased(mx, my, btn) end
    if handoff.active then handoffButton:mousereleased(mx, my, btn) end
end

function Game:keypressed(key)
    if handoff.active then
        if key == "return" or key == "space" then
            handoff.active = false
            seq:resume()
            Audio.play("click")
        end
        return
    end
    if key == "escape" then
        if sel.cardId or sel.kingMove or sel.deadMode then
            clearSelection()
            Audio.play("back")
        else
            Audio.play("back")
            Gamestate.push(require("src.states.pause"))
        end
    elseif key == "p" then
        Gamestate.push(require("src.states.pause"))
    elseif key == "space" and match.phase == "action" and not locked() then
        clearSelection()
        act({ type = "endTurn" })
    end
end

---------------------------------------------------------------------------
-- Herramientas de desarrollo
---------------------------------------------------------------------------

-- Bot de pruebas: pasa el relevo y juega una accion legal cada poco, pero
-- SIEMPRE a traves de session:request, asi que recorre el mismo camino que un
-- jugador real (secuenciador, modales, relevo incluidos).
local botRng, botWait
function Game:updateBot(dt)
    botRng = botRng or GameRules.Rng.new(2024)
    botWait = (botWait or 0) - dt

    if handoff.active then
        handoff.active = false
        seq:resume()
        return
    end
    if seq:busy() or coin.active then return end
    if match.phase == "gameover" then return end
    if botWait > 0 then return end
    botWait = 0.35

    local actions = match:getLegalActions()
    if #actions == 0 then return end
    session:request(actions[botRng:int(1, #actions)])
end

function Game:runAutoplay()
    local rng = GameRules.Rng.new(12345)
    for _ = 1, Game.autoplay do
        if match.phase == "gameover" then break end
        if Game.stopAt and match.phase == Game.stopAt then break end
        local actions = match:getLegalActions()
        if #actions == 0 then break end
        match:apply(actions[rng:int(1, #actions)])
    end
    if Game.stopAt then print("fase alcanzada: " .. match.phase) end

    -- Nos saltamos la reproducción: queremos ver el estado final, no la película.
    match:drainEvents()
    seq:clear()
    handoff.active, coin.active = false, false
    for _, piece in ipairs(match.board:allPieces()) do
        local v = pieceVisual(piece)
        v.x, v.y = LY.cellCenter(piece.col, piece.row)
    end
    vis.dying = {}

    local playable = match:getPlayableCards()
    if playable[1] then
        sel.cardId = playable[1].id
        local movable = match:getMovablePieces(sel.cardId)
        if movable[1] then sel.pieceId = movable[1].id end
    end
end

-- Recorre con clicks sintéticos el camino carta -> ficha -> destino.
function Game:runClickTest()
    local function click(x, y)
        seq:clear()
        handoff.active, coin.active = false, false
        Game:update(0.016, x, y)
        Game:mousepressed(x, y, 1)
        Game:mousereleased(x, y, 1)
    end

    print("--- prueba de clicks ---")
    seq:clear()
    handoff.active, coin.active = false, false
    clearSelection()

    local guard = 0
    while #match:getPlayableCards() == 0 and match.phase == "action" and guard < 12 do
        match:apply({ type = "endTurn" })
        match:drainEvents()
        guard = guard + 1
    end
    local playable = match:getPlayableCards()
    if #playable == 0 then print("  sin cartas jugables tras " .. guard .. " pasos"); return end
    if guard > 0 then print("  (" .. guard .. " turnos pasados para rellenar la mano)") end

    local hand = match:currentPlayer().hand
    local index
    for i, c in ipairs(hand) do if c.id == playable[1].id then index = i end end
    local cx, cy = LY.handSlot(index, #hand)
    click(cx + LY.card.w / 2, cy + LY.card.h / 2)
    print(string.format("  carta elegida: %s -> %s", playable[1].kind,
        tostring(sel.cardId == playable[1].id)))

    local movable = match:getMovablePieces(playable[1].id)
    if #movable == 0 then print("  sin fichas movibles"); return end
    local target = movable[#movable]
    for _, pc in ipairs(movable) do
        for _, d in ipairs(match:getDestinations(playable[1].id, pc.id)) do
            if d.capture then target = pc; break end
        end
        if target == pc then break end
    end
    local px, py = LY.cellCenter(target.col, target.row)
    click(px, py)
    print(string.format("  ficha elegida: #%d -> %s", target.id,
        tostring(sel.pieceId == target.id)))

    local dests = match:getDestinations(sel.cardId, sel.pieceId)
    if #dests == 0 then print("  sin destinos"); return end
    local d = dests[1]
    for _, c in ipairs(dests) do if c.capture then d = c; break end end
    local dx, dy = LY.cellCenter(d.col, d.row)
    click(dx, dy)
    print(string.format("  destino %d,%d  movida=%s  comio=%s",
        d.col, d.row, tostring(target.col == d.col and target.row == d.row),
        tostring(d.capture and true or false)))
    print(string.format("  fase=%s  jugadas este turno=%d",
        match.phase, #match:getPlayedThisTurn()))
    print("--- fin de la prueba ---")
end

return Game
