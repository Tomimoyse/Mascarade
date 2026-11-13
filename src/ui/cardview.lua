-- Dibujado de las cartas de disfraz.
--
-- No guarda estado de juego: recibe el tipo de carta y dónde pintarla. El
-- estado de animación (elevación, escala, volteo) lo lleva quien la dibuja.

local Palette = require("src.palette")
local Panel   = require("src.ui.panel")
local Text    = require("src.ui.text")
local Fonts   = require("src.fonts")
local Sprites = require("src.ui.sprites")
local L       = require("locale.es")

local CardView = {}

-- Tamaño normal (mano) y reducido (jugadas del turno, mazo, descarte).
CardView.W, CardView.H = 54, 76
CardView.SMALL_W, CardView.SMALL_H = 30, 42

-- Cada disfraz tiene su color: permite leer la mano de un vistazo.
CardView.ACCENT = {
    peon    = Palette.hex("#9aa6b8"),
    torre   = Palette.hex("#3d82e0"),
    caballo = Palette.hex("#53c472"),
    alfil   = Palette.hex("#9150e0"),
    reina   = Palette.hex("#e5394a"),
    rey     = Palette.hex("#f3b93f"),
}

local FACE   = Palette.hex("#211a30")
local FACE_HI = Palette.hex("#352a4a")
local BACK   = Palette.hex("#2b1a3c")

function CardView.accent(kind)
    return CardView.ACCENT[kind] or Palette.bone
end

---------------------------------------------------------------------------
-- Cara de la carta
---------------------------------------------------------------------------

-- opts = {
--   small, scale, alpha, selected, disabled, highlight,
--   flip = 1 (1 = de frente, 0 = de canto),
-- }
function CardView.draw(kind, x, y, opts)
    opts = opts or {}
    local small  = opts.small
    local w      = small and CardView.SMALL_W or CardView.W
    local h      = small and CardView.SMALL_H or CardView.H
    local scale  = opts.scale or 1
    local alpha  = opts.alpha or 1
    local flip   = opts.flip or 1
    local accent = CardView.accent(kind)

    love.graphics.push()
    love.graphics.translate(math.floor(x + w / 2), math.floor(y + h / 2))
    love.graphics.scale(scale * flip, scale)
    love.graphics.translate(-w / 2, -h / 2)

    -- Si está muy de canto, sólo se ve el borde.
    if math.abs(flip) < 0.12 then
        love.graphics.setColor(Palette.rgba(accent, alpha))
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local fill = opts.selected and Palette.mix(FACE, accent, 0.22) or FACE
    if opts.disabled then fill = Palette.hex("#1a1626") end

    Panel.draw(0, 0, w, h, {
        fill         = fill,
        border       = opts.disabled and Palette.grayDark or accent,
        highlight    = opts.disabled and nil or FACE_HI,
        radius       = 3,
        shadowOffset = opts.shadowOffset or 3,
        alpha        = alpha,
    })

    -- Banda de color bajo el borde superior: identifica el disfraz de lejos.
    love.graphics.setColor(Palette.rgba(accent, alpha * (opts.disabled and 0.3 or 0.85)))
    love.graphics.rectangle("fill", 4, 3, w - 8, 2)

    -- Glifo de la pieza.
    local img = Sprites.glyph[kind]
    if img then
        local gs = small and 1 or 2
        local gw = Sprites.GLYPH_SIZE * gs
        local gy = small and 5 or 10
        love.graphics.setColor(1, 1, 1, alpha * (opts.disabled and 0.4 or 1))
        love.graphics.draw(img, math.floor((w - gw) / 2), gy, 0, gs, gs)
    end

    -- Nombre, sólo en la carta grande.
    if not small then
        local name = L.cartas[kind] or kind
        Text.centered(name, 0, h - 16, w, {
            font = Fonts.small,
            color = opts.disabled and Palette.gray or Palette.bone,
            outline = Palette.line,
            alpha = alpha,
        })
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------------------
-- Dorso
---------------------------------------------------------------------------

function CardView.drawBack(x, y, opts)
    opts = opts or {}
    local small = opts.small
    local w = small and CardView.SMALL_W or CardView.W
    local h = small and CardView.SMALL_H or CardView.H
    local alpha = opts.alpha or 1
    local scale = opts.scale or 1

    love.graphics.push()
    love.graphics.translate(math.floor(x + w / 2), math.floor(y + h / 2))
    love.graphics.scale(scale, scale)
    love.graphics.translate(-w / 2, -h / 2)

    Panel.draw(0, 0, w, h, {
        fill = BACK, border = Palette.goldDark, highlight = Palette.hex("#4a2f63"),
        radius = 3, shadowOffset = opts.shadowOffset or 3, alpha = alpha,
    })

    -- Rombo central con marco interior.
    love.graphics.setColor(Palette.rgba(Palette.goldDark, alpha * 0.7))
    love.graphics.rectangle("line", 4.5, 4.5, w - 9, h - 9)
    love.graphics.setColor(Palette.rgba(Palette.gold, alpha * 0.8))
    local cx, cy = w / 2, h / 2
    local r = small and 6 or 10
    for i = 0, r do
        local hw = i
        love.graphics.rectangle("fill", math.floor(cx - hw), math.floor(cy - r + i), hw * 2 + 1, 1)
        love.graphics.rectangle("fill", math.floor(cx - hw), math.floor(cy + r - i), hw * 2 + 1, 1)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------------------
-- Hueco vacío (mazo agotado, descarte vacío)
---------------------------------------------------------------------------

function CardView.drawSlot(x, y, opts)
    opts = opts or {}
    local w = opts.small and CardView.SMALL_W or CardView.W
    local h = opts.small and CardView.SMALL_H or CardView.H
    love.graphics.setColor(Palette.rgba(Palette.panelDark, 0.6))
    Panel.shape(x, y, w, h, 3)
    Panel.dashed(x, y, w, h, { color = Palette.grayDark, step = 2, phase = opts.phase or 0 })
    love.graphics.setColor(1, 1, 1, 1)
end

return CardView
