-- Botón de UI. Se eleva al pasar el ratón, se hunde al pulsar y vuelve con
-- easing elástico. Todos los desplazamientos son enteros para no romper el pixel art.

local Object  = require("lib.classic")
local flux    = require("lib.flux")
local Palette = require("src.palette")
local Panel   = require("src.ui.panel")
local Text    = require("src.ui.text")
local Fonts   = require("src.fonts")
local Audio   = require("src.audio")

local Button = Object:extend()

-- opts = {
--   label, x, y, w, h, onClick, font,
--   accent (color del borde al hover), fill, align,
--   enabled, tooltip, sound
-- }
function Button:new(opts)
    self.label   = opts.label or ""
    self.x       = opts.x or 0
    self.y       = opts.y or 0
    self.w       = opts.w or 100
    self.h       = opts.h or 18
    self.onClick = opts.onClick
    self.font    = opts.font or Fonts.bold
    self.accent  = opts.accent or Palette.gold
    self.fill    = opts.fill or Palette.panel
    self.enabled = opts.enabled ~= false
    self.tooltip = opts.tooltip
    self.sound   = opts.sound or "click"

    -- Estado de animación
    self.lift    = 0     -- elevación en píxeles (hover)
    self.press   = 0     -- hundimiento al pulsar
    self.glow    = 0     -- 0..1, intensidad del acento
    self.hovered = false
    self.held    = false
end

function Button:setEnabled(v)
    self.enabled = v and true or false
    if not self.enabled then
        self.hovered = false
        self.held = false
    end
end

function Button:contains(mx, my)
    return mx >= self.x and mx < self.x + self.w
       and my >= self.y - self.lift and my < self.y + self.h - self.lift
end

function Button:update(dt, mx, my)
    local was = self.hovered
    self.hovered = self.enabled and self:contains(mx, my) or false

    if self.hovered ~= was then
        if self.hovered then
            Audio.play("hover")
            flux.to(self, 0.16, { lift = 2, glow = 1 }):ease("backout")
        else
            flux.to(self, 0.20, { lift = 0, glow = 0 }):ease("quadout")
        end
    end
end

function Button:mousepressed(mx, my, btn)
    if btn ~= 1 or not self.enabled then return false end
    if not self:contains(mx, my) then return false end
    self.held = true
    flux.to(self, 0.06, { press = 2 })
    return true
end

function Button:mousereleased(mx, my, btn)
    if btn ~= 1 then return false end
    local wasHeld = self.held
    self.held = false
    flux.to(self, 0.30, { press = 0 }):ease("elasticout")
    if wasHeld and self.enabled and self:contains(mx, my) then
        Audio.play(self.sound)
        if self.onClick then self.onClick(self) end
        return true
    end
    return false
end

function Button:draw()
    local x = math.floor(self.x)
    local y = math.floor(self.y - self.lift + self.press)
    local alpha = self.enabled and 1 or 0.45

    local fill = self.fill
    if self.enabled and self.glow > 0 then
        fill = Palette.mix(self.fill, Palette.panelLight, self.glow)
    end

    local border = self.enabled
        and Palette.mix(Palette.line, self.accent, self.glow)
        or Palette.grayDark

    Panel.draw(x, y, self.w, self.h, {
        fill         = fill,
        border       = border,
        highlight    = self.enabled and Palette.panelLight or nil,
        radius       = 2,
        shadowOffset = math.max(1, 3 - self.press),
        alpha        = alpha,
    })

    local color = self.enabled
        and Palette.mix(Palette.bone, Palette.white, self.glow)
        or Palette.gray

    local ty = y + math.floor((self.h - self.font:getHeight()) / 2)
    Text.centered(self.label, x, ty, self.w, {
        font = self.font, color = color, outline = Palette.line, alpha = alpha,
    })
end

return Button
