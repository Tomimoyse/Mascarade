-- Pausa. Se apila sobre la partida y dibuja el estado de debajo oscurecido.

local Gamestate = require("lib.gamestate")
local Config    = require("src.config")
local Palette   = require("src.palette")
local Screen    = require("src.screen")
local Fonts     = require("src.fonts")
local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Button    = require("src.ui.button")
local Audio     = require("src.audio")
local L         = require("locale.es")

local Pause = {}

local PANEL = { x = 220, y = 96, w = 200, h = 136 }
local buttons = {}

function Pause:init()
    local bw, bh, gap = 164, 20, 7
    local bx = PANEL.x + 18
    local by = PANEL.y + 38
    local defs = {
        { L.pausa.seguir,   Palette.green, function() Gamestate.pop() end },
        { L.pausa.opciones, Palette.blue,  function() Gamestate.push(require("src.states.options")) end },
        { L.pausa.abandonar, Palette.red,  function()
            Gamestate.pop()
            Gamestate.switch(require("src.states.menu"))
        end },
    }
    for i, d in ipairs(defs) do
        buttons[i] = Button({
            label = d[1], accent = d[2], onClick = d[3],
            x = bx, y = by + (i - 1) * (bh + gap), w = bw, h = bh,
        })
    end
end

function Pause:enter(previous)
    self.previous = previous
end

function Pause:update(dt, mx, my)
    for _, b in ipairs(buttons) do b:update(dt, mx, my) end
end

function Pause:draw()
    Screen.scrim(0.6)

    Panel.draw(PANEL.x, PANEL.y, PANEL.w, PANEL.h, {
        fill = Palette.panel, border = Palette.gold,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 4,
    })
    Text.centered(L.pausa.titulo, PANEL.x, PANEL.y + 10, PANEL.w, {
        font = Fonts.boldBig, color = Palette.gold, outline = Palette.line, shadow = 2,
    })
    for _, b in ipairs(buttons) do b:draw() end
end

function Pause:mousepressed(mx, my, btn)
    for _, b in ipairs(buttons) do b:mousepressed(mx, my, btn) end
end

function Pause:mousereleased(mx, my, btn)
    for _, b in ipairs(buttons) do b:mousereleased(mx, my, btn) end
end

function Pause:keypressed(key)
    if key == "escape" or key == "p" then
        Audio.play("back")
        Gamestate.pop()
    end
end

return Pause
