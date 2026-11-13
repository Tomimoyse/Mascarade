-- Canvas interno de baja resolución, escalado entero y relleno de la ventana.
--
-- Hay dos tamaños distintos y conviene no confundirlos:
--
--   CAJA DE DISEÑO (640x360): el área donde se coloca toda la interfaz. Es
--   fija, y todas las coordenadas del juego están referidas a ella.
--
--   CANVAS: puede ser MÁS GRANDE que la caja de diseño. Crece hasta cubrir
--   la ventana entera al factor de escala elegido. La caja de diseño va
--   centrada dentro, y el sobrante lo ocupa el fondo animado.
--
-- Así el juego llena la pantalla sea cual sea su forma, sin barras negras y
-- sin renunciar al escalado entero, que es lo que mantiene nítido el pixel art.

local Config = require("src.config")

local Screen = {}

-- Caja de diseño: lo que la interfaz da por hecho que existe.
Screen.DESIGN_W = Config.CANVAS_W
Screen.DESIGN_H = Config.CANVAS_H

-- Tamaño real del canvas (>= caja de diseño).
Screen.w, Screen.h = Screen.DESIGN_W, Screen.DESIGN_H
Screen.scale = 1
Screen.ox, Screen.oy = 0, 0   -- resto sin usar en la ventana (0..escala-1 px)
Screen.dx, Screen.dy = 0, 0   -- desplazamiento de la caja dentro del canvas

-- Avisos para quien necesite rehacer recursos al cambiar el tamaño.
local listeners = {}

function Screen.onResize(fn)
    listeners[#listeners + 1] = fn
end

local function rebuildCanvas()
    Screen.canvas = love.graphics.newCanvas(Screen.w, Screen.h)
    Screen.canvas:setFilter("nearest", "nearest")
    for _, fn in ipairs(listeners) do fn(Screen.w, Screen.h) end
end

function Screen.load()
    love.graphics.setDefaultFilter("nearest", "nearest", 0)
    Screen.resize(love.graphics.getDimensions())
end

-- Comprueba si la ventana ha cambiado de tamaño y reajusta si hace falta.
--
-- No basta con el callback love.resize: hay entornos donde no llega nunca
-- (por ejemplo dentro de un contenedor con Wayland y libdecor, donde el
-- gestor de ventanas redimensiona la ventana sin que el evento se propague).
-- Mirar el tamaño cada frame cuesta dos llamadas y nos quita el problema.
function Screen.poll()
    local w, h = love.graphics.getDimensions()
    if w ~= Screen.lastW or h ~= Screen.lastH then
        Screen.resize(w, h)
        return true
    end
    return false
end

-- Cálculo puro del reparto, sin tocar love.graphics: así se puede probar
-- con tests para cualquier tamaño de ventana.
-- Devuelve { scale, w, h, dx, dy, ox, oy }.
function Screen.computeLayout(windowW, windowH, designW, designH)
    designW = designW or Screen.DESIGN_W
    designH = designH or Screen.DESIGN_H
    windowW = math.max(math.floor(windowW or 1), 1)
    windowH = math.max(math.floor(windowH or 1), 1)

    -- La escala más grande con la que la caja de diseño sigue cabiendo entera.
    local scale = math.max(1, math.floor(math.min(windowW / designW, windowH / designH)))

    -- El canvas crece hasta cubrir la ventana a esa escala.
    local w = math.max(designW, math.floor(windowW / scale))
    local h = math.max(designH, math.floor(windowH / scale))

    return {
        scale = scale,
        w = w, h = h,
        -- Caja de diseño centrada dentro del canvas.
        dx = math.floor((w - designW) / 2),
        dy = math.floor((h - designH) / 2),
        -- Resto de píxeles que no llega a una unidad de escala completa.
        ox = math.floor((windowW - w * scale) / 2),
        oy = math.floor((windowH - h * scale) / 2),
    }
end

-- Recalcula escala y tamaño del canvas para la ventana dada.
function Screen.resize(windowW, windowH)
    Screen.lastW, Screen.lastH = windowW, windowH
    local l = Screen.computeLayout(windowW, windowH)
    local changed = (l.w ~= Screen.w) or (l.h ~= Screen.h) or not Screen.canvas
    Screen.scale = l.scale
    Screen.w, Screen.h = l.w, l.h
    Screen.dx, Screen.dy = l.dx, l.dy
    Screen.ox, Screen.oy = l.ox, l.oy
    if changed then rebuildCanvas() end
end

-- Coordenadas de ventana -> coordenadas de la caja de diseño.
function Screen.toCanvas(x, y)
    return (x - Screen.ox) / Screen.scale - Screen.dx,
           (y - Screen.oy) / Screen.scale - Screen.dy
end

-- Rectángulo que cubre TODO el canvas, en coordenadas de la caja de diseño.
-- Lo usan los oscurecimientos de los modales, que deben tapar también el
-- margen que queda fuera de la caja.
function Screen.fullRect()
    return -Screen.dx, -Screen.dy, Screen.w, Screen.h
end

-- Oscurece la pantalla entera. Pensado para los fondos de los modales.
function Screen.scrim(alpha)
    local x, y, w, h = Screen.fullRect()
    love.graphics.setColor(0, 0, 0, alpha or 0.6)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

function Screen.beginDraw()
    love.graphics.setCanvas(Screen.canvas)
    love.graphics.clear(0, 0, 0, 1)
end

function Screen.endDraw()
    love.graphics.setCanvas()
end

return Screen
