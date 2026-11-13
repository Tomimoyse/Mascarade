-- Canvas interno de baja resolución + escalado entero con letterbox.
-- Todo el juego dibuja en 640x360; esta capa lo lleva a la ventana.

local Config = require("src.config")

local Screen = {}

Screen.w = Config.CANVAS_W
Screen.h = Config.CANVAS_H
Screen.scale = 1
Screen.ox = 0
Screen.oy = 0

function Screen.load()
    love.graphics.setDefaultFilter("nearest", "nearest", 0)
    Screen.canvas = love.graphics.newCanvas(Screen.w, Screen.h)
    Screen.canvas:setFilter("nearest", "nearest")
    Screen.resize(love.graphics.getDimensions())
end

-- Recalcula la escala entera y el centrado al cambiar el tamaño de la ventana.
function Screen.resize(windowW, windowH)
    local s = math.min(windowW / Screen.w, windowH / Screen.h)
    Screen.scale = math.max(1, math.floor(s))
    Screen.ox = math.floor((windowW - Screen.w * Screen.scale) / 2)
    Screen.oy = math.floor((windowH - Screen.h * Screen.scale) / 2)
end

-- Convierte coordenadas de ventana a coordenadas del canvas interno.
function Screen.toCanvas(x, y)
    return (x - Screen.ox) / Screen.scale, (y - Screen.oy) / Screen.scale
end

-- ¿Está este punto (en coordenadas de canvas) dentro del área visible?
function Screen.inside(x, y)
    return x >= 0 and y >= 0 and x < Screen.w and y < Screen.h
end

function Screen.beginDraw()
    love.graphics.setCanvas(Screen.canvas)
    love.graphics.clear(0, 0, 0, 1)
end

function Screen.endDraw()
    love.graphics.setCanvas()
end

return Screen
