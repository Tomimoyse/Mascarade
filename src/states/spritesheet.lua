-- Pantalla de desarrollo: muestra todo el arte generado por código, para
-- poder revisarlo de un vistazo. No forma parte del juego.
--   love . --state spritesheet

local Gamestate = require("lib.gamestate")
local Config    = require("src.config")
local Palette   = require("src.palette")
local Screen    = require("src.screen")
local Fonts     = require("src.fonts")
local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Sprites   = require("src.ui.sprites")
local CardView  = require("src.ui.cardview")
local Fx        = require("src.fx")
local Cards     = require("src.game.cards")

local Sheet = {}
local t = 0

function Sheet:enter()
    Fx.background.setMood("partida")
    Fx.background.setIntensity(0.25)
end

function Sheet:update(dt) t = t + dt end

function Sheet:draw()
    Screen.scrim(0.5)

    Text.outlined("ARTE GENERADO POR CODIGO", 8, 6,
        { font = Fonts.bold, color = Palette.gold, outline = Palette.line })

    -- Glifos a 1x, 2x y 3x
    local x = 10
    for _, kind in ipairs(Cards.KINDS) do
        local img = Sprites.glyph[kind]
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, 22, 0, 1, 1)
        love.graphics.draw(img, x, 42, 0, 2, 2)
        Text.outlined(kind, x, 78, { font = Fonts.small, color = Palette.bone,
            outline = Palette.line })
        x = x + 56
    end

    -- Cartas grandes
    local cx = 10
    for _, kind in ipairs(Cards.KINDS) do
        CardView.draw(kind, cx, 96, {})
        cx = cx + 60
    end
    CardView.drawBack(cx, 96, {})

    -- Cartas pequeñas y estados
    local sx = 10
    for _, kind in ipairs(Cards.KINDS) do
        CardView.draw(kind, sx, 182, { small = true })
        sx = sx + 36
    end
    CardView.draw("reina", sx + 10, 182, { small = true, disabled = true })
    CardView.drawBack(sx + 50, 182, { small = true })
    CardView.drawSlot(sx + 90, 182, { small = true, phase = t * 10 })

    Text.outlined("seleccionada / deshabilitada / volteo", 10, 232,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })
    CardView.draw("torre", 10, 244, { selected = true })
    CardView.draw("torre", 74, 244, { disabled = true })
    CardView.draw("torre", 138, 244, { flip = math.sin(t * 3) })

    -- Fichas
    local px = 230
    for owner = 1, 2 do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Sprites.pieceShadow, px, 268)
        love.graphics.draw(Sprites.piece[owner], px + 2, 252)
        px = px + 34
    end
    love.graphics.draw(Sprites.piece[1], px + 2, 252)
    love.graphics.draw(Sprites.crownIcon, px, 246)
    Text.outlined("fichas y corona", 230, 290,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })

    Text.outlined("ESC para volver", 8, Config.CANVAS_H - 18,
        { font = Fonts.small, color = Palette.grayDark, outline = Palette.line })
end

function Sheet:keypressed(key)
    if key == "escape" then Gamestate.switch(require("src.states.menu")) end
end

return Sheet
