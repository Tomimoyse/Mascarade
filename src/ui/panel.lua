-- Paneles de UI en pixel art: esquinas achaflanadas a 45 grados, borde de 1 px,
-- sombra desplazada y brillo interior superior. Aspecto de mesa de juego.

local Palette = require("src.palette")

local Panel = {}

-- Rellena un rectángulo con las esquinas cortadas en diagonal.
-- r = radio del chaflán en píxeles (0 = esquinas rectas).
function Panel.shape(x, y, w, h, r)
    x, y = math.floor(x), math.floor(y)
    w, h = math.floor(w), math.floor(h)
    r = r or 0
    if r <= 0 or w < r * 2 or h < r * 2 then
        love.graphics.rectangle("fill", x, y, w, h)
        return
    end
    -- Cuerpo central
    love.graphics.rectangle("fill", x, y + r, w, h - r * 2)
    -- Filas superiores e inferiores, cada una un píxel menos metida
    for i = 0, r - 1 do
        local inset = r - i
        love.graphics.rectangle("fill", x + inset, y + i, w - inset * 2, 1)
        love.graphics.rectangle("fill", x + inset, y + h - 1 - i, w - inset * 2, 1)
    end
end

-- Dibuja un panel completo.
-- opts = {
--   fill, border, shadow, highlight,  -- colores (nil desactiva esa capa)
--   radius = 2, shadowOffset = 2, alpha = 1,
-- }
function Panel.draw(x, y, w, h, opts)
    opts = opts or {}
    local r      = opts.radius or 2
    local alpha  = opts.alpha or 1
    local fill   = opts.fill or Palette.panel
    local border = opts.border
    local shadow = opts.shadow
    local hl     = opts.highlight
    local off    = opts.shadowOffset or 2

    if border == nil then border = Palette.line end
    if shadow == nil then shadow = Palette.void end

    -- Sombra desplazada
    if shadow then
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], 0.55 * alpha)
        Panel.shape(x + off, y + off, w, h, r)
    end

    -- Borde (la figura completa) y relleno un píxel por dentro
    if border then
        love.graphics.setColor(border[1], border[2], border[3], alpha)
        Panel.shape(x, y, w, h, r)
        love.graphics.setColor(fill[1], fill[2], fill[3], alpha)
        Panel.shape(x + 1, y + 1, w - 2, h - 2, math.max(r - 1, 0))
    else
        love.graphics.setColor(fill[1], fill[2], fill[3], alpha)
        Panel.shape(x, y, w, h, r)
    end

    -- Brillo interior en el borde superior: da volumen sin usar degradados
    if hl then
        love.graphics.setColor(hl[1], hl[2], hl[3], 0.9 * alpha)
        love.graphics.rectangle("fill", x + r + 1, y + 1, w - (r + 1) * 2, 1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Línea separadora de 1 px con sombra, para dividir secciones de un panel.
function Panel.divider(x, y, w, opts)
    opts = opts or {}
    local c = opts.color or Palette.panelDark
    local hl = opts.highlight or Palette.panelLight
    love.graphics.setColor(c[1], c[2], c[3], opts.alpha or 1)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), 1)
    love.graphics.setColor(hl[1], hl[2], hl[3], (opts.alpha or 1) * 0.5)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y) + 1, math.floor(w), 1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Marco punteado, para resaltar zonas válidas (destinos legales, huecos).
function Panel.dashed(x, y, w, h, opts)
    opts = opts or {}
    local c = opts.color or Palette.gold
    local step = opts.step or 3
    local phase = math.floor((opts.phase or 0) % (step * 2))
    love.graphics.setColor(c[1], c[2], c[3], opts.alpha or 1)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    for i = 0, w - 1 do
        if (i + phase) % (step * 2) < step then
            love.graphics.rectangle("fill", x + i, y, 1, 1)
            love.graphics.rectangle("fill", x + w - 1 - i, y + h - 1, 1, 1)
        end
    end
    for i = 0, h - 1 do
        if (i + phase) % (step * 2) < step then
            love.graphics.rectangle("fill", x + w - 1, y + i, 1, 1)
            love.graphics.rectangle("fill", x, y + h - 1 - i, 1, 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Panel
