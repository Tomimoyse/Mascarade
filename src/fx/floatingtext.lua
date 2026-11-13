-- Texto flotante con efecto "pop": entra creciendo con easing elástico,
-- sube, y se desvanece. Se usa para avisos de captura, coronación, etc.

local flux    = require("lib.flux")
local Palette = require("src.palette")
local Text    = require("src.ui.text")
local Fonts   = require("src.fonts")

local FloatingText = {}

local live = {}

-- opts = { color, font, rise, life, scale, outline }
function FloatingText.spawn(str, x, y, opts)
    opts = opts or {}
    local item = {
        str   = str,
        x     = x,
        y     = y,
        color = opts.color or Palette.gold,
        font  = opts.font or Fonts.boldBig,
        scale = 0.1,
        alpha = 1,
        rise  = opts.rise or 22,
        life  = opts.life or 1.1,
        rot   = (love.math.random() - 0.5) * 0.12,
    }
    live[#live + 1] = item

    local target = opts.scale or 1

    -- Pop de entrada: escala con rebote.
    flux.to(item, 0.34, { scale = target }):ease("elasticout")
    -- Subida suave durante toda la vida.
    flux.to(item, item.life, { y = y - item.rise }):ease("quadout")
    -- Desvanecido al final.
    flux.to(item, item.life * 0.4, { alpha = 0 })
        :delay(item.life * 0.6)
        :oncomplete(function()
            for i = #live, 1, -1 do
                if live[i] == item then table.remove(live, i) end
            end
        end)

    return item
end

function FloatingText.draw()
    for _, it in ipairs(live) do
        local w = it.font:getWidth(it.str)
        local h = it.font:getHeight()
        love.graphics.push()
        love.graphics.translate(math.floor(it.x), math.floor(it.y))
        love.graphics.rotate(it.rot)
        love.graphics.scale(it.scale, it.scale)
        Text.outlined(it.str, -w / 2, -h / 2, {
            font = it.font,
            color = it.color,
            outline = Palette.line,
            alpha = it.alpha,
            shadow = 2,
        })
        love.graphics.pop()
    end
end

function FloatingText.clear()
    for i = #live, 1, -1 do live[i] = nil end
end

return FloatingText
