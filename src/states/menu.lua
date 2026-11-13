-- Menú principal.

local Gamestate = require("lib.gamestate")
local flux      = require("lib.flux")
local Config    = require("src.config")
local Palette   = require("src.palette")
local Fonts     = require("src.fonts")
local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Button    = require("src.ui.button")
local Fx        = require("src.fx")
local L         = require("locale.es")

local Menu = {}

local buttons = {}
local logo = { y = 0, scale = 1, rot = 0 }
local t = 0

function Menu:init()
    local cw = Config.CANVAS_W
    local bw, bh, gap = 170, 20, 5
    local bx = math.floor((cw - bw) / 2)
    local by = 160

    local defs = {
        { label = L.menu.jugarLocal, accent = Palette.gold,
          onClick = function() Gamestate.switch(require("src.states.game")) end },
        { label = L.menu.crearRed,   accent = Palette.green,
          onClick = function() Gamestate.switch(require("src.states.lobby"), "host") end },
        { label = L.menu.unirseRed,  accent = Palette.green,
          onClick = function() Gamestate.switch(require("src.states.lobby"), "join") end },
        { label = L.menu.reglas,     accent = Palette.blue,
          onClick = function() Gamestate.push(require("src.states.rules")) end },
        { label = L.menu.opciones,   accent = Palette.blue,
          onClick = function() Gamestate.push(require("src.states.options")) end },
        { label = L.menu.salir,      accent = Palette.red,
          onClick = function() love.event.quit() end },
    }

    for i, d in ipairs(defs) do
        buttons[i] = Button({
            label = d.label, accent = d.accent,
            x = bx, y = by + (i - 1) * (bh + gap), w = bw, h = bh,
            onClick = d.onClick, font = Fonts.bold,
        })
    end
end

function Menu:enter()
    Fx.background.setMood("menu")
    Fx.background.setIntensity(0.62)
    -- Entrada del logotipo con rebote.
    logo.y = -60
    logo.scale = 0.6
    flux.to(logo, 0.7, { y = 0, scale = 1 }):ease("backout")
end

function Menu:update(dt, mx, my)
    t = t + dt
    for _, b in ipairs(buttons) do b:update(dt, mx, my) end
    -- Balanceo lento del logotipo.
    logo.rot = math.sin(t * 0.8) * 0.02
end

function Menu:draw()
    local cw, ch = Config.CANVAS_W, Config.CANVAS_H

    -- Logotipo
    local title = L.titulo
    local font = Fonts.huge
    local tw = font:getWidth(title)
    love.graphics.push()
    love.graphics.translate(cw / 2, 92 + logo.y + math.sin(t * 1.4) * 2)
    love.graphics.rotate(logo.rot)
    love.graphics.scale(logo.scale, logo.scale)
    Text.outlined(title, -tw / 2, -font:getHeight() / 2, {
        font = font, color = Palette.gold, outline = Palette.line, shadow = 4,
        shadowColor = Palette.redDark,
    })
    love.graphics.pop()

    -- Subtítulo
    Text.centered(L.subtitulo, 0, 136, cw, {
        font = Fonts.small, color = Palette.bone, outline = Palette.line,
    })

    for _, b in ipairs(buttons) do b:draw() end

    -- Pie
    Text.centered("v0.1 - fase 1", 0, ch - 14, cw, {
        font = Fonts.small, color = Palette.gray, outline = Palette.line,
    })
end

function Menu:mousepressed(mx, my, btn)
    for _, b in ipairs(buttons) do b:mousepressed(mx, my, btn) end
end

function Menu:mousereleased(mx, my, btn)
    for _, b in ipairs(buttons) do b:mousereleased(mx, my, btn) end
end

function Menu:keypressed(key)
    if key == "return" or key == "space" then
        Gamestate.switch(require("src.states.game"))
    elseif key == "escape" then
        love.event.quit()
    end
end

return Menu
