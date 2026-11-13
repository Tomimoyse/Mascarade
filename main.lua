-- Mascarade - punto de entrada.
--
-- Pipeline de dibujado:
--   1. Todo el juego se dibuja en un canvas interno de 640x360.
--   2. El fondo lo pinta un shader de remolino; encima va el estado actual.
--   3. El canvas se vuelca a la ventana con escala entera y postprocesado
--      (bloom + CRT), ambos conmutables desde las opciones.
--
-- No usamos Gamestate.registerEvents: despachamos los callbacks a mano para
-- poder convertir las coordenadas del ratón al espacio del canvas interno.

local Gamestate = require("lib.gamestate")
local flux      = require("lib.flux")

local Config    = require("src.config")
local Settings  = require("src.settings")
local Screen    = require("src.screen")
local Postfx    = require("src.postfx")
local Fonts     = require("src.fonts")
local Sprites   = require("src.ui.sprites")
local Audio     = require("src.audio")
local Fx        = require("src.fx")
local Shake     = require("src.fx.shake")

-- Posición del ratón en coordenadas del canvas interno.
local mx, my = 0, 0

-- Modo de desarrollo: "love . --shot [segundos]" arranca el juego, espera,
-- guarda una captura en el directorio de guardado y sale. Sirve para revisar
-- el aspecto sin tener que jugar a mano.
local shot = { active = false, delay = 1.5, timer = 0, taken = false }
local startState = "menu"

-- Llama a un callback del estado actual, si lo tiene definido.
local function dispatch(name, ...)
    local state = Gamestate.current()
    local fn = state and state[name]
    if fn then return fn(state, ...) end
end

function love.load(args)
    for i, a in ipairs(args or {}) do
        if a == "--shot" then
            shot.active = true
            shot.delay = tonumber(args[i + 1]) or 1.5
        elseif a == "--state" then
            startState = args[i + 1] or "menu"
        elseif a == "--autoplay" then
            require("src.states.game").autoplay = tonumber(args[i + 1]) or 40
        elseif a == "--clicks" then
            require("src.states.game").clickTest = true
        elseif a == "--seed" then
            require("src.states.game").seed = tonumber(args[i + 1])
        elseif a == "--until" then
            require("src.states.game").stopAt = args[i + 1]
        elseif a == "--test" then
            -- Ejecuta la suite de reglas por consola y sale.
            require("tests.run")
            return
        elseif a == "--demo" then
            -- Juega una partida aleatoria por consola y sale.
            _G.arg = { args[i + 1], args[i + 2] }
            require("tests.demo")
            love.event.quit()
            return
        end
    end

    love.graphics.setDefaultFilter("nearest", "nearest", 0)
    love.graphics.setLineStyle("rough")
    love.mouse.setVisible(true)

    Settings.load()
    Screen.load()
    Fonts.load()
    Sprites.load()
    Postfx.load()
    Audio.load()
    Fx.load()

    if Settings.get("fullscreen") then
        love.window.setFullscreen(true, "desktop")
        Screen.resize(love.graphics.getDimensions())
    end

    Gamestate.switch(require("src.states." .. startState))
end

function love.update(dt)
    -- Clamp del delta: si la ventana se congela, las animaciones no pegan saltos.
    if dt > 1 / 20 then dt = 1 / 20 end

    local wx, wy = love.mouse.getPosition()
    mx, my = Screen.toCanvas(wx, wy)

    Fx.update(dt)
    Audio.update(dt)
    dispatch("update", dt, mx, my)

    if shot.active then
        shot.timer = shot.timer + dt
        if shot.timer >= shot.delay and not shot.taken then
            shot.taken = true
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", "captura.png")
                love.event.quit()
            end)
        end
    end
end

function love.draw()
    Screen.beginDraw()

    -- El temblor se aplica a toda la escena, fondo incluido.
    local sx, sy, srot = Shake.get()
    love.graphics.push()
    if sx ~= 0 or sy ~= 0 or srot ~= 0 then
        love.graphics.translate(Config.CANVAS_W / 2, Config.CANVAS_H / 2)
        love.graphics.rotate(srot)
        love.graphics.translate(-Config.CANVAS_W / 2 + sx, -Config.CANVAS_H / 2 + sy)
    end

    Fx.background.draw()
    dispatch("draw")
    Fx.drawOver()

    love.graphics.pop()
    Screen.endDraw()

    Postfx.present(Fx.background.getTime())
end

---------------------------------------------------------------------------
-- Entrada
---------------------------------------------------------------------------

function love.mousepressed(x, y, button, istouch, presses)
    local cx, cy = Screen.toCanvas(x, y)
    dispatch("mousepressed", cx, cy, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    local cx, cy = Screen.toCanvas(x, y)
    dispatch("mousereleased", cx, cy, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    local cx, cy = Screen.toCanvas(x, y)
    dispatch("mousemoved", cx, cy, dx / Screen.scale, dy / Screen.scale, istouch)
end

function love.wheelmoved(x, y)
    dispatch("wheelmoved", x, y)
end

function love.textinput(text)
    dispatch("textinput", text)
end

function love.keypressed(key, scancode, isrepeat)
    -- Atajos globales, disponibles en cualquier pantalla.
    if key == "f11" then
        local fs = not love.window.getFullscreen()
        love.window.setFullscreen(fs, "desktop")
        Settings.set("fullscreen", fs)
        Screen.resize(love.graphics.getDimensions())
        return
    elseif key == "f1" then
        Settings.toggle("crt")
        Audio.play("click")
        return
    elseif key == "f2" then
        Settings.toggle("bloom")
        Audio.play("click")
        return
    end
    dispatch("keypressed", key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    dispatch("keyreleased", key, scancode)
end

function love.resize(w, h)
    Screen.resize(w, h)
    dispatch("resize", w, h)
end

function love.quit()
    Settings.save()
    return false
end
