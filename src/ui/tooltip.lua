-- Tooltips: un panel de texto que sigue al ratón sin salirse del canvas.
--
-- Uso: durante el update, quien detecte un hover llama a Tooltip.set(...).
-- Al final del draw, Tooltip.draw() pinta el que haya quedado activo.

local Screen  = require("src.screen")
local Palette = require("src.palette")
local Panel   = require("src.ui.panel")
local Text    = require("src.ui.text")
local Fonts   = require("src.fonts")

local Tooltip = {}

local pending = nil

-- opts = { title, lines = {...}, accent, warn = "texto en rojo" }
function Tooltip.set(x, y, opts)
    pending = opts
    if pending then
        pending.x, pending.y = x, y
    end
end

function Tooltip.clear()
    pending = nil
end

local MAX_W = 150

function Tooltip.draw()
    local t = pending
    pending = nil
    if not t then return end

    local lines = {}
    for _, l in ipairs(t.lines or {}) do
        -- Partimos los textos largos en varias líneas.
        local _, wrapped = Fonts.small:getWrap(l, MAX_W - 12)
        for _, w in ipairs(wrapped) do lines[#lines + 1] = w end
    end
    local warnLines = {}
    if t.warn then
        local _, wrapped = Fonts.small:getWrap(t.warn, MAX_W - 12)
        for _, w in ipairs(wrapped) do warnLines[#warnLines + 1] = w end
    end

    -- Medidas
    local w = 0
    if t.title then w = math.max(w, Fonts.bold:getWidth(t.title)) end
    for _, l in ipairs(lines) do w = math.max(w, Fonts.small:getWidth(l)) end
    for _, l in ipairs(warnLines) do w = math.max(w, Fonts.small:getWidth(l)) end
    w = math.min(w + 12, MAX_W)

    local h = 6
    if t.title then h = h + 11 end
    h = h + #lines * 10 + #warnLines * 10 + 5

    -- Colocación: arriba a la derecha del cursor, pero siempre dentro.
    local vx, vy, vw, vh = Screen.fullRect()
    local x = math.floor(t.x + 10)
    local y = math.floor(t.y - h - 6)
    if x + w > vx + vw - 4 then x = math.floor(t.x - w - 10) end
    if x < vx + 4 then x = vx + 4 end
    if y < vy + 4 then y = math.floor(t.y + 14) end
    if y + h > vy + vh - 4 then y = vy + vh - 4 - h end

    Panel.draw(x, y, w, h, {
        fill = Palette.hex("#15102a"), border = t.accent or Palette.gold,
        highlight = Palette.panelLight, radius = 2, shadowOffset = 3,
    })

    local ty = y + 4
    if t.title then
        Text.outlined(t.title, x + 6, ty, { font = Fonts.bold,
            color = t.accent or Palette.gold, outline = Palette.line })
        ty = ty + 11
    end
    for _, l in ipairs(lines) do
        Text.outlined(l, x + 6, ty, { font = Fonts.small,
            color = Palette.bone, outline = Palette.line })
        ty = ty + 10
    end
    for _, l in ipairs(warnLines) do
        Text.outlined(l, x + 6, ty, { font = Fonts.small,
            color = Palette.red, outline = Palette.line })
        ty = ty + 10
    end
end

return Tooltip
