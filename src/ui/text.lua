-- Dibujado de texto con contorno y sombra marcada, al estilo pixel art.
-- Todo el texto del juego pasa por aquí para que tenga un aspecto coherente.

local Palette = require("src.palette")

local Text = {}

local OUTLINE_OFFSETS = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
}

-- Texto con contorno de 1 px en las 8 direcciones.
-- opts = { font, color, outline, align, limit, shadow }
function Text.outlined(str, x, y, opts)
    opts = opts or {}
    local font    = opts.font or love.graphics.getFont()
    local color   = opts.color or Palette.white
    local outline = opts.outline or Palette.line
    local align   = opts.align
    local limit   = opts.limit

    local prevFont = love.graphics.getFont()
    love.graphics.setFont(font)

    local function put(dx, dy, c)
        love.graphics.setColor(c[1], c[2], c[3], (opts.alpha or 1) * (c[4] or 1))
        if limit and align then
            love.graphics.printf(str, math.floor(x + dx), math.floor(y + dy), limit, align)
        else
            love.graphics.print(str, math.floor(x + dx), math.floor(y + dy))
        end
    end

    -- Sombra desplazada (opcional, por debajo del contorno).
    if opts.shadow then
        local s = opts.shadow
        put(s, s, opts.shadowColor or Palette.void)
    end

    for _, o in ipairs(OUTLINE_OFFSETS) do
        put(o[1], o[2], outline)
    end
    put(0, 0, color)

    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Variante más barata: sólo sombra desplazada, sin contorno.
function Text.shadowed(str, x, y, opts)
    opts = opts or {}
    local font   = opts.font or love.graphics.getFont()
    local color  = opts.color or Palette.white
    local shadow = opts.shadowColor or Palette.void
    local off    = opts.shadow or 1

    local prevFont = love.graphics.getFont()
    love.graphics.setFont(font)

    local function put(dx, dy, c)
        love.graphics.setColor(c[1], c[2], c[3], (opts.alpha or 1))
        if opts.limit and opts.align then
            love.graphics.printf(str, math.floor(x + dx), math.floor(y + dy), opts.limit, opts.align)
        else
            love.graphics.print(str, math.floor(x + dx), math.floor(y + dy))
        end
    end

    put(off, off, shadow)
    put(0, 0, color)

    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Ancho/alto de un texto con una fuente dada.
function Text.size(str, font)
    return font:getWidth(str), font:getHeight()
end

-- Centra horizontalmente un texto dentro de [x, x + w].
function Text.centered(str, x, y, w, opts)
    opts = opts or {}
    local font = opts.font or love.graphics.getFont()
    local tw = font:getWidth(str)
    Text.outlined(str, x + (w - tw) / 2, y, opts)
end

return Text
