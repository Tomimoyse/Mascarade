-- Fachada de efectos. El resto del juego llama sólo a Fx.*, nunca a los
-- submódulos directamente, para que sea fácil cambiar implementaciones.

local flux         = require("lib.flux")
local Shake        = require("src.fx.shake")
local Particles    = require("src.fx.particles")
local FloatingText = require("src.fx.floatingtext")
local Background   = require("src.fx.background")
local Palette      = require("src.palette")

local Fx = {}

Fx.shake        = Shake
Fx.particles    = Particles
Fx.text         = FloatingText
Fx.background   = Background

function Fx.load()
    Background.load()
end

function Fx.update(dt)
    flux.update(dt)
    Shake.update(dt)
    Particles.update(dt)
    Background.update(dt)
end

-- Dibuja las capas de efectos que van por encima del juego.
function Fx.drawOver()
    Particles.draw()
    FloatingText.draw()
end

function Fx.clear()
    Shake.reset()
    Particles.clear()
    FloatingText.clear()
end

---------------------------------------------------------------------------
-- Atajos de uso frecuente, para que las llamadas desde el juego sean cortas.
---------------------------------------------------------------------------

-- Golpe seco: temblor + chispas. Para capturas.
function Fx.impact(x, y, color)
    Shake.add(0.42)
    Particles.burst(x, y, {
        count = 18, speed = 110, gravity = 220, life = 0.55, size = 3,
        colors = { color or Palette.red, Palette.white, Palette.gold },
    })
end

-- Destello alegre: para coronaciones y promociones.
function Fx.celebrate(x, y, color)
    Shake.add(0.3)
    Particles.fountain(x, y, {
        count = 34, speed = 150, life = 0.9, size = 3,
        colors = { color or Palette.gold, Palette.white, Palette.gold },
    })
end

-- Polvillo suave: para colocar una carta o una ficha.
function Fx.puff(x, y, color)
    Particles.burst(x, y, {
        count = 7, speed = 42, gravity = 60, drag = 3.5, life = 0.35, size = 2,
        colors = { color or Palette.bone, Palette.gray },
    })
end

function Fx.popup(str, x, y, opts)
    return FloatingText.spawn(str, x, y, opts)
end

return Fx
