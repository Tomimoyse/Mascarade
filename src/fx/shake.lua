-- Temblor de pantalla basado en "trauma": un valor 0..1 que decae y cuyo
-- cuadrado modula la amplitud. Da sacudidas que arrancan fuerte y mueren rápido.

local Shake = {}

local trauma = 0
local decay = 2.2
local t = 0
local seed = love.math and love.math.random(1000) or 0

-- amount: 0..1. Se acumula, pero con techo.
function Shake.add(amount)
    trauma = math.min(trauma + (amount or 0.3), 1)
end

function Shake.update(dt)
    t = t + dt
    trauma = math.max(trauma - decay * dt, 0)
end

-- Devuelve el desplazamiento y la rotación a aplicar al dibujar la escena.
function Shake.get()
    if trauma <= 0 then return 0, 0, 0 end
    local s = trauma * trauma
    local amp = 6 * s
    -- Oscilación de alta frecuencia con dos senos desfasados (barato y suficiente).
    local dx = math.sin(t * 47 + seed) * amp
    local dy = math.cos(t * 41 + seed * 1.7) * amp
    local rot = math.sin(t * 37 + seed * 0.5) * 0.015 * s
    return dx, dy, rot
end

function Shake.getTrauma()
    return trauma
end

function Shake.reset()
    trauma = 0
end

return Shake
