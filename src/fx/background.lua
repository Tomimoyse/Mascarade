-- Fondo animado con el shader de remolino psicodélico.
-- Cada pantalla puede pedir su propia tríada de colores y su intensidad.

local Screen  = require("src.screen")
local Palette = require("src.palette")

local Background = {}

local shader
local time = 0

-- Paletas de fondo por contexto.
Background.MOODS = {
    menu    = { Palette.hex("#1b0730"), Palette.hex("#c02a55"), Palette.hex("#ffcf4d") },
    partida = { Palette.hex("#071424"), Palette.hex("#2f6fc4"), Palette.hex("#f2b63c") },
    victoria= { Palette.hex("#0d2416"), Palette.hex("#2f9e5a"), Palette.hex("#ffe27a") },
    derrota = { Palette.hex("#1c0610"), Palette.hex("#8e1d30"), Palette.hex("#e5394a") },
}

local colA = { 0, 0, 0 }
local colB = { 0, 0, 0 }
local colC = { 0, 0, 0 }
local target = Background.MOODS.menu
local intensity = 1

function Background.load()
    shader = love.graphics.newShader("assets/shaders/background.glsl")
    Background.setMood("menu", true)
end

-- Cambia la paleta del fondo. Si immediate es falso, hace una transición suave.
function Background.setMood(name, immediate)
    target = Background.MOODS[name] or Background.MOODS.menu
    if immediate then
        for i = 1, 3 do
            local c = target[i]
            local dst = (i == 1 and colA) or (i == 2 and colB) or colC
            dst[1], dst[2], dst[3] = c[1], c[2], c[3]
        end
    end
end

function Background.setIntensity(v)
    intensity = v
end

function Background.update(dt)
    time = time + dt
    -- Interpolación exponencial hacia la paleta objetivo.
    local k = math.min(dt * 2.5, 1)
    local dsts = { colA, colB, colC }
    for i = 1, 3 do
        local dst, src = dsts[i], target[i]
        for j = 1, 3 do
            dst[j] = dst[j] + (src[j] - dst[j]) * k
        end
    end
end

function Background.getTime()
    return time
end

-- Dibuja el fondo cubriendo todo el canvas interno.
function Background.draw()
    -- El canvas crece con la ventana, asi que el shader necesita su tamano real.
    shader:send("uRes", { Screen.w, Screen.h })
    shader:send("uTime", time)
    shader:send("uColA", colA)
    shader:send("uColB", colB)
    shader:send("uColC", colC)
    shader:send("uIntensity", intensity)
    shader:send("uLevels", 22.0)

    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, Screen.w, Screen.h)
    love.graphics.setShader()
end

return Background
