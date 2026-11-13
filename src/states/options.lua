-- Pantalla de opciones. Se apila sobre el estado anterior (push/pop).

local Gamestate = require("lib.gamestate")
local Config    = require("src.config")
local Palette   = require("src.palette")
local Fonts     = require("src.fonts")
local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Button    = require("src.ui.button")
local Settings  = require("src.settings")
local Audio     = require("src.audio")
local L         = require("locale.es")

local Options = {}

local rows = {}
local btnVolver

local PANEL = { x = 150, y = 46, w = 340, h = 250 }

-- Cada fila es un interruptor o un deslizador sobre una clave de Settings.
local function buildRows()
    rows = {}
    local function toggle(key, label)
        rows[#rows + 1] = { kind = "toggle", key = key, label = label }
    end
    toggle("crt",        L.opciones.crt)
    toggle("bloom",      L.opciones.bloom)
    toggle("fullscreen", L.opciones.pantalla)
    rows[#rows + 1] = { kind = "slider", key = "volume", label = L.opciones.volumen }
    toggle("mostrarAyuda", L.opciones.ayuda)
    toggle("revelarManos", L.opciones.revelar)
end

function Options:init()
    buildRows()
    btnVolver = Button({
        label = L.opciones.volver, accent = Palette.gold,
        x = PANEL.x + 12, y = PANEL.y + PANEL.h - 28, w = 90, h = 18,
        onClick = function() Gamestate.pop() end,
        sound = "back",
    })
end

function Options:enter(previous)
    self.previous = previous
end

local function rowY(i)
    return PANEL.y + 34 + (i - 1) * 26
end

local function applyFullscreen()
    local want = Settings.get("fullscreen")
    love.window.setFullscreen(want, "desktop")
end

function Options:update(dt, mx, my)
    btnVolver:update(dt, mx, my)
    self.mx, self.my = mx, my
    self.hoverRow = nil
    for i in ipairs(rows) do
        local y = rowY(i)
        if my >= y - 4 and my < y + 16 and mx >= PANEL.x + 12 and mx < PANEL.x + PANEL.w - 12 then
            self.hoverRow = i
        end
    end
end

function Options:draw()
    -- Oscurecemos lo que haya debajo.
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, Config.CANVAS_W, Config.CANVAS_H)
    love.graphics.setColor(1, 1, 1, 1)

    Panel.draw(PANEL.x, PANEL.y, PANEL.w, PANEL.h, {
        fill = Palette.panel, border = Palette.gold,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 4,
    })

    Text.centered(L.opciones.titulo, PANEL.x, PANEL.y + 8, PANEL.w, {
        font = Fonts.boldBig, color = Palette.gold, outline = Palette.line, shadow = 2,
    })
    Panel.divider(PANEL.x + 10, PANEL.y + 28, PANEL.w - 20)

    for i, row in ipairs(rows) do
        local y = rowY(i)
        local hovered = (self.hoverRow == i)
        local labelColor = hovered and Palette.white or Palette.bone

        if hovered then
            love.graphics.setColor(Palette.rgba(Palette.panelLight, 0.7))
            love.graphics.rectangle("fill", PANEL.x + 10, y - 3, PANEL.w - 20, 15)
            love.graphics.setColor(1, 1, 1, 1)
        end

        Text.outlined(row.label, PANEL.x + 16, y, {
            font = Fonts.small, color = labelColor, outline = Palette.line,
        })

        local vx = PANEL.x + PANEL.w - 70
        if row.kind == "toggle" then
            local on = Settings.get(row.key) and true or false
            local txt = on and L.opciones.activado or L.opciones.desactivado
            local col = on and Palette.green or Palette.gray
            -- Interruptor dibujado a mano.
            Panel.draw(vx, y - 2, 34, 13, {
                fill = on and Palette.hex("#1e4a2c") or Palette.panelDark,
                border = on and Palette.green or Palette.grayDark,
                radius = 2, shadowOffset = 1, highlight = nil,
            })
            love.graphics.setColor(col[1], col[2], col[3], 1)
            love.graphics.rectangle("fill", on and (vx + 22) or (vx + 3), y + 1, 9, 9)
            love.graphics.setColor(1, 1, 1, 1)
            Text.outlined(txt, vx + 40, y, {
                font = Fonts.small, color = col, outline = Palette.line,
            })
        else
            -- Deslizador de volumen
            local v = Settings.get("volume") or 0.7
            local bw = 56
            Panel.draw(vx, y - 1, bw, 11, {
                fill = Palette.panelDark, border = Palette.grayDark,
                radius = 1, shadowOffset = 1, highlight = nil,
            })
            love.graphics.setColor(Palette.rgba(Palette.gold, 1))
            love.graphics.rectangle("fill", vx + 2, y + 1, math.floor((bw - 4) * v), 7)
            love.graphics.setColor(1, 1, 1, 1)
            Text.outlined(tostring(math.floor(v * 100)), vx + bw + 6, y, {
                font = Fonts.small, color = Palette.bone, outline = Palette.line,
            })
        end
    end

    Text.outlined("Click para cambiar  -  flechas en el volumen", PANEL.x + 16,
        PANEL.y + PANEL.h - 44, { font = Fonts.small, color = Palette.gray, outline = Palette.line })

    btnVolver:draw()
end

function Options:mousepressed(mx, my, btn)
    if btnVolver:mousepressed(mx, my, btn) then return end
    if btn ~= 1 then return end
    local i = self.hoverRow
    if not i then return end
    local row = rows[i]
    if row.kind == "toggle" then
        Settings.toggle(row.key)
        Audio.play("click")
        if row.key == "fullscreen" then applyFullscreen() end
    else
        -- Click sobre la barra: fija el volumen según la posición horizontal.
        local vx, bw = PANEL.x + PANEL.w - 70, 56
        if mx >= vx and mx <= vx + bw then
            local v = math.max(0, math.min(1, (mx - vx - 2) / (bw - 4)))
            Settings.set("volume", math.floor(v * 20 + 0.5) / 20)
            Audio.applyVolume()
            Audio.play("click")
        end
    end
end

function Options:mousereleased(mx, my, btn)
    btnVolver:mousereleased(mx, my, btn)
end

function Options:keypressed(key)
    if key == "escape" or key == "backspace" then
        Audio.play("back")
        Gamestate.pop()
    elseif key == "left" or key == "right" then
        local v = Settings.get("volume") or 0.7
        v = math.max(0, math.min(1, v + (key == "right" and 0.05 or -0.05)))
        Settings.set("volume", math.floor(v * 20 + 0.5) / 20)
        Audio.applyVolume()
        Audio.play("click")
    end
end

return Options
