-- Pantalla de partida.
--
-- FASE 1: todavía no hay reglas. Esto es un banco de pruebas de la base
-- técnica: tablero dibujado, fichas en posición inicial, hover con elevación,
-- y feedback (temblor, partículas, texto flotante, sonido) al hacer click.
-- En la Fase 2 se enchufa aquí el módulo de lógica, y en la Fase 3 se sustituye
-- este placeholder por la interfaz real.

local Gamestate = require("lib.gamestate")
local flux      = require("lib.flux")
local Config    = require("src.config")
local Palette   = require("src.palette")
local Fonts     = require("src.fonts")
local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Sprites   = require("src.ui.sprites")
local BoardView = require("src.ui.boardview")
local LY        = require("src.ui.layout")
local Fx        = require("src.fx")
local Audio     = require("src.audio")
local Settings  = require("src.settings")
local L         = require("locale.es")

local Game = {}

local pieces = {}
local hovered = nil
local t = 0
local turno = 1

-- Cartas de muestra para comprobar la composición de la franja inferior.
local manoDemo = { "peon", "torre", "caballo", "reina", "rey" }

function Game:enter()
    Fx.background.setMood("partida")
    Fx.background.setIntensity(0.55)
    Fx.clear()

    pieces = BoardView.startingPieces()
    for _, p in ipairs(pieces) do
        p.lift = 0
        p.scale = 1
    end
    hovered = nil
    t = 0
    turno = 1
    Audio.play("turnChange")
end

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------

local function pieceAt(col, row)
    for _, p in ipairs(pieces) do
        if p.col == col and p.row == row then return p end
    end
end

function Game:update(dt, mx, my)
    t = t + dt

    local col, row = LY.cellAt(mx, my)
    local target = col and pieceAt(col, row) or nil

    if target ~= hovered then
        if hovered then
            flux.to(hovered, 0.20, { lift = 0, scale = 1 }):ease("quadout")
        end
        hovered = target
        if hovered then
            flux.to(hovered, 0.18, { lift = 5, scale = 1.12 }):ease("backout")
            Audio.play("hover", { volume = 0.5 })
        end
    end
end

---------------------------------------------------------------------------
-- Dibujado
---------------------------------------------------------------------------

-- Dorso de carta provisional, para ver la composición de la mano.
local function drawCardBack(x, y, w, h, label, lift)
    y = y - (lift or 0)
    Panel.draw(x, y, w, h, {
        fill = Palette.hex("#2b1a3c"), border = Palette.gold,
        highlight = Palette.hex("#4a2f63"), radius = 3, shadowOffset = 3,
    })
    -- Rombo central
    love.graphics.setColor(Palette.rgba(Palette.gold, 0.75))
    local cx, cy = x + w / 2, y + h / 2
    for i = 0, 7 do
        love.graphics.rectangle("fill", math.floor(cx - i), math.floor(cy - 8 + i), i * 2 + 1, 1)
        love.graphics.rectangle("fill", math.floor(cx - i), math.floor(cy + 8 - i), i * 2 + 1, 1)
    end
    love.graphics.setColor(1, 1, 1, 1)
    Text.centered(label, x, y + h - 13, w, {
        font = Fonts.small, color = Palette.bone, outline = Palette.line,
    })
end

local function drawSidePanel(area, titulo, lineas, accent)
    Panel.draw(area.x, area.y, area.w, area.h, {
        fill = Palette.panel, border = accent,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 3,
    })
    Text.outlined(titulo, area.x + 8, area.y + 7, {
        font = Fonts.bold, color = accent, outline = Palette.line,
    })
    Panel.divider(area.x + 7, area.y + 20, area.w - 14)
    local y = area.y + 28
    for _, linea in ipairs(lineas) do
        Text.outlined(linea, area.x + 8, y, {
            font = Fonts.small, color = Palette.bone, outline = Palette.line,
        })
        y = y + 11
    end
end

function Game:draw()
    -- Tablero con las fichas
    BoardView.draw(pieces, {
        beforePieces = function()
            if hovered then
                BoardView.highlight(hovered.col, hovered.row, "select", t * 18)
            end
        end,
        pieceOpts = function(p)
            return { lift = p.lift, scale = p.scale }
        end,
    })

    -- Paneles laterales
    drawSidePanel(LY.left, string.format(L.partida.jugador, 1), {
        L.partida.fichas .. ": 16",
        L.partida.mano .. ": 5",
        "",
        turno == 1 and "> SU TURNO" or "",
    }, Palette.red)

    drawSidePanel(LY.right, string.format(L.partida.jugador, 2), {
        L.partida.fichas .. ": 16",
        L.partida.mano .. ": 5",
        "",
        turno == 2 and "> SU TURNO" or "",
    }, Palette.blue)

    -- Mazo y descarte, en el panel derecho
    local dx, dy = LY.right.x + 8, LY.right.y + 120
    Text.outlined(L.partida.mazo .. ": 22", dx, dy, {
        font = Fonts.small, color = Palette.gray, outline = Palette.line })
    Text.outlined(L.partida.descarte .. ": 0", dx, dy + 11, {
        font = Fonts.small, color = Palette.gray, outline = Palette.line })

    -- Franja de la mano
    local h = LY.hand
    Panel.draw(h.x, h.y, h.w, h.h, {
        fill = Palette.hex("#1b1428"), border = Palette.hex("#3a2a50"),
        highlight = nil, radius = 3, shadowOffset = 0,
    })

    local cw, chh = LY.card.w, LY.card.h
    local gap = 8
    local total = #manoDemo * cw + (#manoDemo - 1) * gap
    local sx = h.x + math.floor((h.w - total) / 2)
    for i, kind in ipairs(manoDemo) do
        -- Oscilación suave en reposo, desfasada por carta.
        local idle = math.sin(t * 1.6 + i * 0.7) * 1.5
        drawCardBack(sx + (i - 1) * (cw + gap), h.y + 14 + idle, cw, chh,
            L.cartas[kind], 0)
    end

    -- Aviso de fase y ayuda de teclas, dentro del panel de la mano para no
    -- quedar debajo de la vineta del CRT.
    Text.outlined(L.aviso.faseDemo, h.x + 10, h.y + 8, {
        font = Fonts.bold, color = Palette.gold, outline = Palette.line })
    Text.outlined(L.aviso.faseDemoDesc, h.x + 10, h.y + 20, {
        font = Fonts.small, color = Palette.gray, outline = Palette.line })

    if Settings.get("mostrarAyuda") then
        local ayuda = { "ESC pausa", "F1 CRT   F2 bloom", "F11 pantalla completa" }
        for i, linea in ipairs(ayuda) do
            Text.outlined(linea, h.x + 10, h.y + 42 + (i - 1) * 11, {
                font = Fonts.small, color = Palette.grayDark, outline = Palette.line })
        end
        local pruebas = { "PRUEBAS", "Click ficha: impacto",
                          "TAB: cambiar turno", "ESPACIO: coronacion" }
        for i, linea in ipairs(pruebas) do
            Text.outlined(linea, h.x + h.w - 128, h.y + 10 + (i - 1) * 11, {
                font = i == 1 and Fonts.bold or Fonts.small,
                color = i == 1 and Palette.gold or Palette.grayDark,
                outline = Palette.line })
        end
    end
end

---------------------------------------------------------------------------
-- Entrada
---------------------------------------------------------------------------

function Game:mousepressed(mx, my, btn)
    if btn ~= 1 then return end
    if not hovered then return end

    -- Demostración del feedback: temblor, partículas, texto y sonido.
    local cx, cy = LY.cellCenter(hovered.col, hovered.row)
    local color = Palette.player[hovered.owner]
    Fx.impact(cx, cy, color)
    Fx.popup(L.partida.captura .. "!", cx, cy - 12, { color = Palette.gold })
    Audio.play("capture")

    flux.to(hovered, 0.08, { scale = 1.35 }):ease("quadout")
        :after(hovered, 0.35, { scale = 1.12 }):ease("elasticout")
end

function Game:keypressed(key)
    if key == "escape" or key == "p" then
        Audio.play("back")
        Gamestate.push(require("src.states.pause"))
    elseif key == "tab" then
        -- Cambio de turno simulado, para probar el aviso lateral.
        turno = turno == 1 and 2 or 1
        Audio.play("turnChange")
        Fx.popup(string.format(L.partida.turnoDe, string.format(L.partida.jugador, turno)),
            Config.CANVAS_W / 2, 140, { color = Palette.player[turno], font = Fonts.boldBig })
    elseif key == "space" then
        -- Prueba de celebración.
        local cx, cy = LY.cellCenter(4, 4)
        Fx.celebrate(cx, cy, Palette.gold)
        Fx.popup(L.partida.coronacion .. "!", cx, cy - 16, { color = Palette.gold, font = Fonts.boldBig })
        Audio.play("crown")
    end
end

return Game
