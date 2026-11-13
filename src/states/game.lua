-- Pantalla de partida: conecta el motor de reglas (src/game) con la interfaz.
--
-- La pantalla no conoce las reglas. Pregunta al motor qué se puede hacer
-- (inspectHand, getMovablePieces, getDestinations, canFreeKingMove...) y le
-- manda acciones. Todo el feedback sale de la cola de eventos del motor.
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

local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Sprites   = require("src.ui.sprites")
local CardView  = require("src.ui.cardview")
local BoardView = require("src.ui.boardview")
local Tooltip   = require("src.ui.tooltip")
local Button    = require("src.ui.button")
local LY        = require("src.ui.layout")
local Screen    = require("src.screen")

local GameRules = require("src.game")
local Cards     = require("src.game.cards")
local L         = require("locale.es")

local Game = {}

---------------------------------------------------------------------------
-- Estado de la vista
---------------------------------------------------------------------------

local match          -- partida en curso (motor de reglas)
local t = 0          -- reloj local, para pulsos y marcas punteadas

-- Selección actual del jugador.
local sel = { cardId = nil, pieceId = nil, kingMove = false, deadMode = false }

-- Qué hay bajo el ratón en este frame.
local hover = { cardId = nil, pieceId = nil, col = nil, row = nil }

-- Estado visual por ficha y por carta (posición animada, elevación, escala).
local vis = { pieces = {}, cards = {} }

local buttons = {}
local promoButtons = {}
local overButtons = {}

---------------------------------------------------------------------------
-- Utilidades de estado visual
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

-- Destinos que hay que pintar ahora mismo, y de qué ficha salen.
local function activeDestinations()
    if sel.kingMove then
        return match:getKingDestinations(), match:currentPlayer().kingPieceId
    end
    if sel.cardId and sel.pieceId then
        return match:getDestinations(sel.cardId, sel.pieceId), sel.pieceId
    end
    -- Previsualización al pasar por encima de una ficha movible.
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

---------------------------------------------------------------------------
-- Consumo de la cola de eventos del motor
---------------------------------------------------------------------------

-- Nota de fase: aquí los eventos se resuelven de golpe. En la Fase 4 esta
-- función se convierte en una corrutina que los reproduce uno a uno con pausas.
local function consumeEvents()
    for _, ev in ipairs(match:drainEvents()) do
        if ev.t == "pieceMoved" then
            local piece = match.board:get(ev.pieceId)
            if piece then
                local v = pieceVisual(piece)
                local cx, cy = LY.cellCenter(ev.col, ev.row)
                flux.to(v, Config.T.pieceMove, { x = cx, y = cy }):ease("quadout")
            end
            Audio.play("pieceMove")

        elseif ev.t == "pieceCaptured" then
            local cx, cy = LY.cellCenter(ev.col, ev.row)
            Fx.impact(cx, cy, Palette.player[ev.owner])
            Fx.popup(L.partida.captura, cx, cy - 14, { color = Palette.red })
            Audio.play("capture")
            vis.pieces[ev.pieceId] = nil

        elseif ev.t == "cardPlayed" then
            Audio.play("cardPlace")

        elseif ev.t == "kingCrowned" then
            local piece = match.board:get(ev.pieceId)
            if piece then
                local cx, cy = LY.cellCenter(piece.col, piece.row)
                Fx.celebrate(cx, cy, Palette.gold)
                Fx.popup(L.partida.coronacion, cx, cy - 18,
                    { color = Palette.gold, font = Fonts.boldBig })
            end
            Audio.play("crown")

        elseif ev.t == "extraAction" then
            Fx.popup(L.partida.accionExtra, Config.CANVAS_W / 2, 120,
                { color = Palette.green, font = Fonts.boldBig })
            Audio.play("extraAction")

        elseif ev.t == "promoted" then
            Fx.popup(L.partida.promocion, Config.CANVAS_W / 2, 130,
                { color = Palette.gold, font = Fonts.boldBig })
            Audio.play("promote")

        elseif ev.t == "drew" and ev.count > 0 then
            Audio.play("cardDraw")

        elseif ev.t == "deadCardDiscarded" then
            Audio.play("cardFlip")

        elseif ev.t == "deckReshuffled" then
            Audio.play("cardDraw", { pitch = 0.8 })

        elseif ev.t == "turnStart" then
            Audio.play("turnChange")
            clearSelection()

        elseif ev.t == "gameOver" then
            Fx.shake.add(0.7)
            Audio.play(ev.winner and "victory" or "defeat")
        end
    end
end

-- Aplica una acción del motor y procesa lo que genere.
local function act(action)
    local ok, err = match:apply(action)
    if not ok then
        Audio.play("error")
        if err then
            Fx.popup(L.motivos[err] or err, Config.CANVAS_W / 2, 150,
                { color = Palette.red, font = Fonts.small })
        end
        return false
    end
    consumeEvents()
    return true
end

---------------------------------------------------------------------------
-- Botones de acción
---------------------------------------------------------------------------

local function buildButtons()
    local a = LY.panelAcciones
    local bw, bh, gap = a.w - 16, 20, 6
    local bx, by = a.x + 8, a.y + 24

    buttons = {}
    buttons.endTurn = Button({
        label = L.partida.terminarTurno, accent = Palette.green,
        x = bx, y = by, w = bw, h = bh,
        onClick = function()
            clearSelection()
            act({ type = "endTurn" })
        end,
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
end

-- Devuelve un conjunto de ids de cartas muertas, para marcarlas en la mano.
local function deadSet()
    local set = {}
    for _, c in ipairs(match:getDeadCards()) do set[c.id] = true end
    return set
end

local function refreshButtons()
    local playable = (match.phase == "action")
    buttons.endTurn:setEnabled(playable)
    buttons.endTurn.label = playable
        and string.format(L.partida.robaN, match:getEndTurnDrawCount())
        or L.partida.terminarTurno
    buttons.king:setEnabled(playable and match:canFreeKingMove())
    buttons.dead:setEnabled(playable and #match:getDeadCards() > 0)
end

---------------------------------------------------------------------------
-- Entrada y salida del estado
---------------------------------------------------------------------------

-- Flags de desarrollo:
--   --autoplay N   aplica N acciones legales al azar nada mas entrar
--   --clicks       simula la secuencia carta -> ficha -> destino y la informa
-- Sirven para revisar estados avanzados y para comprobar que el camino de
-- clicks no se rompe, sin tener que jugar a mano.
Game.autoplay = 0
Game.clickTest = false
Game.seed = nil
Game.stopAt = nil   -- "promotion" / "gameover": para la simulacion en esa fase

function Game:enter()
    Fx.background.setMood("partida")
    Fx.background.setIntensity(0.5)
    Fx.clear()

    match = GameRules.Match.new({ seed = Game.seed or os.time() })
    match:start()

    vis.pieces, vis.cards = {}, {}
    clearSelection()
    t = 0

    buildButtons()
    consumeEvents()

    if Game.autoplay and Game.autoplay > 0 then
        local rng = GameRules.Rng.new(12345)
        for _ = 1, Game.autoplay do
            if match.phase == "gameover" then break end
            if Game.stopAt and match.phase == Game.stopAt then break end
            local actions = match:getLegalActions()
            if #actions == 0 then break end
            match:apply(actions[rng:int(1, #actions)])
        end
        if Game.stopAt then
            print("fase alcanzada: " .. match.phase)
        end
        match:drainEvents()
        -- Dejamos una carta elegida para poder ver los resaltados.
        local playable = match:getPlayableCards()
        if playable[1] then
            sel.cardId = playable[1].id
            local movable = match:getMovablePieces(sel.cardId)
            if movable[1] then sel.pieceId = movable[1].id end
        end
        -- Las fichas arrancan ya en su casilla, sin animacion de entrada.
        for _, piece in ipairs(match.board:allPieces()) do
            local v = pieceVisual(piece)
            v.x, v.y = LY.cellCenter(piece.col, piece.row)
        end
    end

    if Game.clickTest then Game:runClickTest() end
end

-- Recorre con clicks sintéticos el camino carta -> ficha -> destino.
function Game:runClickTest()
    local function click(x, y, btn)
        Game:update(0.016, x, y)
        Game:mousepressed(x, y, btn or 1)
        Game:mousereleased(x, y, btn or 1)
    end

    print("--- prueba de clicks ---")
    clearSelection()

    -- Si la mano esta seca, pasamos turnos hasta que haya con que jugar.
    local guard = 0
    while #match:getPlayableCards() == 0 and match.phase == "action" and guard < 12 do
        match:apply({ type = "endTurn" })
        match:drainEvents()
        guard = guard + 1
    end
    local playable = match:getPlayableCards()
    if #playable == 0 then print("  sin cartas jugables tras " .. guard .. " pasos"); return end
    if guard > 0 then print("  (" .. guard .. " turnos pasados para rellenar la mano)") end

    -- 1) Click sobre la primera carta jugable de la mano.
    local hand = match:currentPlayer().hand
    local index
    for i, c in ipairs(hand) do if c.id == playable[1].id then index = i end end
    local cx, cy = LY.handSlot(index, #hand)
    click(cx + LY.card.w / 2, cy + LY.card.h / 2)
    print(string.format("  carta elegida: %s -> %s", playable[1].kind,
        tostring(sel.cardId == playable[1].id)))

    -- 2) Click sobre una ficha movible. Preferimos una que pueda comer, para
    --    que la prueba recorra tambien el camino del encadenado.
    local movable = match:getMovablePieces(playable[1].id)
    if #movable == 0 then print("  sin fichas movibles"); return end
    local target = movable[#movable]
    for _, p in ipairs(movable) do
        for _, d in ipairs(match:getDestinations(playable[1].id, p.id)) do
            if d.capture then target = p; break end
        end
        if target == p then break end
    end
    local px, py = LY.cellCenter(target.col, target.row)
    click(px, py)
    print(string.format("  ficha elegida: #%d -> %s", target.id,
        tostring(sel.pieceId == target.id)))

    -- 3) Click sobre un destino legal.
    local dests = match:getDestinations(sel.cardId, sel.pieceId)
    if #dests == 0 then print("  sin destinos"); return end
    local before = match.board:countOf(match:opponentOf(match.current))
    local fromCol, fromRow = target.col, target.row
    local d = dests[1]
    for _, c in ipairs(dests) do if c.capture then d = c; break end end
    local dx, dy = LY.cellCenter(d.col, d.row)
    click(dx, dy)
    print(string.format("  destino %d,%d  movida=%s  comio=%s",
        d.col, d.row,
        tostring(target.col == d.col and target.row == d.row),
        tostring(match.board:countOf(match:opponentOf(match.current)) < before
                 or (d.capture and true or false))))
    print(string.format("  fase=%s  jugadas este turno=%d",
        match.phase, #match:getPlayedThisTurn()))
    print("--- fin de la prueba ---")
end

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------

function Game:update(dt, mx, my)
    t = t + dt

    -- ¿Qué hay bajo el ratón?
    hover.cardId, hover.pieceId, hover.col, hover.row = nil, nil, nil, nil

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

    -- Animación de las cartas de la mano.
    for i, card in ipairs(hand) do
        local v = cardVisual(card.id)
        local wantLift = 0
        if hover.cardId == card.id then wantLift = 10 end
        if sel.cardId == card.id then wantLift = 14 end
        if v.target ~= wantLift then
            v.target = wantLift
            flux.to(v, Config.T.cardHover, { lift = wantLift })
                :ease(wantLift > 0 and "backout" or "quadout")
        end
    end

    -- Animación de las fichas: elevación al pasar por encima si son relevantes.
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

    refreshButtons()
    for _, b in pairs(buttons) do b:update(dt, mx, my) end
    for _, b in ipairs(promoButtons) do b:update(dt, mx, my) end
    for _, b in ipairs(overButtons) do b:update(dt, mx, my) end
end

---------------------------------------------------------------------------
-- Dibujado: tablero
---------------------------------------------------------------------------

local function drawBoard()
    BoardView.drawFrame()
    BoardView.drawCells()

    local dests, fromId = activeDestinations()
    local phase = t * 20

    -- Ficha de origen marcada.
    if fromId then
        local p = match.board:get(fromId)
        if p then BoardView.highlight(p.col, p.row, "select", phase) end
    end

    -- Fichas candidatas cuando hay carta elegida pero no ficha.
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

    -- Destinos legales.
    for _, d in ipairs(dests) do
        BoardView.highlight(d.col, d.row, d.capture and "capture" or "move", phase)
    end

    -- Fichas, dibujadas desde su posición animada.
    for _, piece in ipairs(match.board:allPieces()) do
        local v = pieceVisual(piece)
        BoardView.drawPieceAt(piece, v.x, v.y, { lift = v.lift, scale = v.scale })
    end
end

---------------------------------------------------------------------------
-- Dibujado: paneles laterales
---------------------------------------------------------------------------

local function drawPlayerPanel(area, idx, isCurrent)
    local accent = Palette.player[idx]
    Panel.draw(area.x, area.y, area.w, area.h, {
        fill = isCurrent and Palette.mix(Palette.panel, accent, 0.14) or Palette.panel,
        border = isCurrent and accent or Palette.line,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 3,
    })

    Text.outlined(string.format(L.partida.jugador, idx), area.x + 8, area.y + 6,
        { font = Fonts.bold, color = accent, outline = Palette.line })

    if isCurrent then
        local a = 0.6 + 0.4 * math.sin(t * 4)
        Text.outlined(L.partida.suTurno, area.x + area.w - 54, area.y + 6,
            { font = Fonts.small, color = Palette.gold, outline = Palette.line, alpha = a })
    end

    local king = match.board:kingOf(idx)
    Text.outlined(string.format("%s %d   %s %d", L.partida.fichas,
        match.board:countOf(idx), L.partida.mano, #match.players[idx].hand),
        area.x + 8, area.y + 21,
        { font = Fonts.small, color = Palette.bone, outline = Palette.line })

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

-- Panel de cadena: cuántos disfraces de cada tipo se han jugado este turno y
-- cuál no se puede repetir ahora.
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
    local gx, gy = area.x + 10, area.y + 26
    for i, kind in ipairs(Cards.KINDS) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local x = gx + col * 58
        local y = gy + row * 30
        local used = (turn.playedByKind and turn.playedByKind[kind]) or 0
        local limit = Cards.chainLimit(kind)
        local agotado = used >= limit
        local vetado = (turn.lastKind == kind)

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

    local footer = L.partida.sinCadena
    local color = Palette.grayDark
    if turn.lockedPieceId then
        footer = string.format(L.partida.bloqueada, turn.lockedPieceId)
        color = Palette.gold
    elseif turn.lastKind then
        footer = string.format(L.partida.ultimo, L.cartas[turn.lastKind])
        color = Palette.red
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
    -- Mazo
    if #match.deck > 0 then
        CardView.drawBack(area.x + 10, y, { small = true })
    else
        CardView.drawSlot(area.x + 10, y, { small = true, phase = t * 10 })
    end
    Text.outlined(L.partida.mazo, area.x + 46, y + 6,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })
    Text.outlined(tostring(#match.deck), area.x + 46, y + 18,
        { font = Fonts.boldBig, color = Palette.bone, outline = Palette.line })

    -- Descarte: se ve la carta de arriba.
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

-- Cartas usadas en el turno en curso: todavía no están en el descarte.
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
    -- Las cartas se solapan si no caben.
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

    -- Pista de qué toca hacer ahora.
    local hint = ""
    if sel.deadMode then hint = L.partida.eligeMuerta
    elseif sel.kingMove then hint = L.partida.eligeDestino
    elseif sel.cardId and sel.pieceId then hint = L.partida.eligeDestino
    elseif sel.cardId then hint = L.partida.eligeFicha end
    Text.outlined(hint, area.x + 8, area.y + 8,
        { font = Fonts.small, color = Palette.gold, outline = Palette.line })

    for _, b in pairs(buttons) do b:draw() end
end

---------------------------------------------------------------------------
-- Dibujado: mano
---------------------------------------------------------------------------

local function drawHand()
    local h = LY.hand
    Panel.draw(h.x, h.y, h.w, h.h, {
        fill = Palette.hex("#1b1428"), border = Palette.hex("#3a2a50"),
        highlight = nil, radius = 3, shadowOffset = 0,
    })

    local player = match:currentPlayer()
    local hand = player.hand
    local inspect = match:inspectHand()
    local dead = deadSet()

    for i, card in ipairs(hand) do
        local x, y = LY.handSlot(i, #hand)
        local v = cardVisual(card.id)
        local entry = inspect[i]
        local playable = entry and entry.ok

        -- Oscilación suave en reposo, desfasada por carta.
        local idle = (v.lift == 0) and math.sin(t * 1.6 + i * 0.8) * 1.2 or 0

        CardView.draw(card.kind, x, y - v.lift + idle, {
            selected = (sel.cardId == card.id),
            disabled = not playable and not (sel.deadMode and dead[card.id]),
            scale = v.scale,
        })

        -- En modo "cambiar carta muerta", las candidatas laten en morado.
        if sel.deadMode and dead[card.id] then
            local a = 0.5 + 0.5 * math.sin(t * 6)
            Panel.dashed(x - 2, y - v.lift + idle - 2, LY.card.w + 4, LY.card.h + 4,
                { color = Palette.purple, alpha = a, phase = t * 22 })
        end
    end

    -- Mano del rival, de dorso, a la derecha de la franja.
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
-- Dibujado: tooltips
---------------------------------------------------------------------------

local function updateTooltip(mx, my)
    if hover.cardId then
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
                warn   = (entry and not entry.ok) and (L.motivos[entry.reason] or entry.reason) or nil,
            })
        end
        return
    end

    if hover.pieceId then
        local p = match.board:get(hover.pieceId)
        if p then
            local lines = { string.format(L.partida.jugador, p.owner) }
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
-- Dibujado: modales
---------------------------------------------------------------------------

local PROMO = { x = 190, y = 100, w = 260, h = 130 }

local function buildPromoButtons()
    promoButtons = {}
    local cards = match:getPromotionCards()
    if #cards == 0 then return end
    -- Un botón por cada peón de la mano, más el de renunciar.
    promoButtons[1] = Button({
        label = "Descartar un peon", accent = Palette.gold,
        x = PROMO.x + 16, y = PROMO.y + PROMO.h - 52, w = 110, h = 20,
        onClick = function()
            act({ type = "promote", cardId = match:getPromotionCards()[1].id })
            promoButtons = {}
        end,
    })
    promoButtons[2] = Button({
        label = L.partida.promoNo, accent = Palette.gray,
        x = PROMO.x + 134, y = PROMO.y + PROMO.h - 52, w = 110, h = 20,
        onClick = function()
            act({ type = "skipPromote" })
            promoButtons = {}
        end,
        sound = "back",
    })
end

local function drawPromotion()
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, Config.CANVAS_W, Config.CANVAS_H)
    love.graphics.setColor(1, 1, 1, 1)

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
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Config.CANVAS_W, Config.CANVAS_H)
    love.graphics.setColor(1, 1, 1, 1)

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

    if match.phase == "promotion" then
        if #promoButtons == 0 then buildPromoButtons() end
        drawPromotion()
    elseif match.phase == "gameover" then
        if #overButtons == 0 then buildOverButtons() end
        drawGameOver()
    else
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
    if match.phase == "gameover" then
        for _, b in ipairs(overButtons) do b:mousepressed(mx, my, btn) end
        return
    end
    if match.phase == "promotion" then
        for _, b in ipairs(promoButtons) do b:mousepressed(mx, my, btn) end
        return
    end

    if btn == 2 then
        clearSelection()
        Audio.play("back")
        return
    end
    if btn ~= 1 then return end

    for _, b in pairs(buttons) do
        if b:mousepressed(mx, my, btn) then return end
    end

    -- Click en la mano.
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
                    sel.kingMove = false
                    sel.pieceId = nil
                    sel.cardId = (sel.cardId == c.id) and nil or c.id
                    Audio.play("cardFlip")
                    -- Si sólo hay una ficha posible, la elegimos por el jugador.
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

    -- Click en el tablero.
    if hover.col then
        local dests, fromId = activeDestinations()
        for _, d in ipairs(dests) do
            if d.col == hover.col and d.row == hover.row then
                if sel.kingMove then
                    act({ type = "freeKingMove", col = d.col, row = d.row })
                else
                    -- El destino previsualizado puede ser de la ficha bajo el ratón.
                    act({ type = "playCard", cardId = sel.cardId,
                          pieceId = sel.pieceId or fromId,
                          col = d.col, row = d.row })
                end
                clearSelection()
                return
            end
        end

        -- Elegir ficha para la carta seleccionada.
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
end

function Game:keypressed(key)
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
    elseif key == "space" and match.phase == "action" then
        clearSelection()
        act({ type = "endTurn" })
    end
end

return Game
