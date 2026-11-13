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
-- Diagnostico de pantalla: se imprime una vez la ventana se ha asentado,
-- porque los gestores con mosaico la redimensionan despues de crearla.
local info = { active = false, timer = 0, delay = 1.2 }
local startState = "menu"
local lobbyMode = nil

-- Llama a un callback del estado actual, si lo tiene definido.
local function dispatch(name, ...)
    local state = Gamestate.current()
    local fn = state and state[name]
    if fn then return fn(state, ...) end
end

function love.load(args)
    args = args or {}

    -- Modos de consola: hacen su trabajo y salen, sin abrir el juego.
    -- Van en pcall para que un fallo salga por la terminal en vez de abrir la
    -- pantalla de error de LOVE, que aqui se quedaria esperando para siempre.
    local function consola(fn)
        io.stdout:setvbuf("line")
        local ok, res = pcall(fn)
        if not ok then
            print("ERROR: " .. tostring(res))
            love.event.quit(1)
        else
            love.event.quit(tonumber(res) or 0)
        end
    end

    for i, a in ipairs(args) do
        if a == "--test" then
            return consola(function() require("tests.run") end)

        elseif a == "--nettest" then
            return consola(function() return require("tests.nettest")() end)

        elseif a == "--demo" then
            return consola(function()
                _G.arg = { args[i + 1], args[i + 2] }
                require("tests.demo")
            end)

        elseif a == "--shot" then
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
        elseif a == "--bot" then
            require("src.states.game").bot = true
        elseif a == "--net" then
            -- "--net host" crea la partida; "--net 192.168.1.5" se une a ella.
            local destino = args[i + 1]
            startState = "lobby"
            if destino == "host" then
                lobbyMode = "host"
            else
                lobbyMode = "join"
                require("src.states.lobby").autoJoin = destino or "127.0.0.1"
            end
        elseif a == "--info" then
            info.active = true
        elseif a == "--size" then
            -- "--size 1920x1080": fuerza el tamano de ventana, para probar el
            -- escalado sin depender de como la coloque el gestor de ventanas.
            local w, h = tostring(args[i + 1] or ""):match("^(%d+)x(%d+)$")
            if w then
                love.window.setMode(tonumber(w), tonumber(h),
                    { resizable = true, vsync = 1 })
            end
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

    Gamestate.switch(require("src.states." .. startState), lobbyMode)
end

function love.update(dt)
    -- Clamp del delta: si la ventana se congela, las animaciones no pegan saltos.
    if dt > 1 / 20 then dt = 1 / 20 end

    Screen.poll()

    local wx, wy = love.mouse.getPosition()
    mx, my = Screen.toCanvas(wx, wy)

    Fx.update(dt)
    Audio.update(dt)
    dispatch("update", dt, mx, my)

    if info.active then
        info.timer = info.timer + dt
        if info.timer >= info.delay then
            local Config = require("src.config")
            local w, h = love.graphics.getDimensions()
            local pw, ph = love.graphics.getPixelDimensions()
            local dw, dh = love.window.getDesktopDimensions()
            local _, _, flags = love.window.getMode()
            print(string.format("ventana logica     : %d x %d", w, h))
            print(string.format("ventana en pixeles : %d x %d", pw, ph))
            print(string.format("escritorio         : %d x %d", dw, dh))
            print(string.format("dpi scale          : %.3f", love.window.getDPIScale()))
            print(string.format("fullscreen=%s  usedpiscale=%s",
                tostring(flags.fullscreen), tostring(flags.usedpiscale)))
            print(string.format("caja de diseno     : %d x %d", Screen.DESIGN_W, Screen.DESIGN_H))
            print(string.format("canvas             : %d x %d  (caja centrada en %d,%d)",
                Screen.w, Screen.h, Screen.dx, Screen.dy))
            print(string.format("escala aplicada    : %d   resto %d,%d px",
                Screen.scale, Screen.ox, Screen.oy))
            print(string.format("area aprovechada   : %.1f%% del ancho, %.1f%% del alto",
                Screen.w * Screen.scale / pw * 100, Screen.h * Screen.scale / ph * 100))
            love.event.quit()
            return
        end
    end

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
        love.graphics.translate(Screen.w / 2, Screen.h / 2)
        love.graphics.rotate(srot)
        love.graphics.translate(-Screen.w / 2 + sx, -Screen.h / 2 + sy)
    end

    -- El fondo cubre el canvas entero; el juego va en la caja de diseño.
    Fx.background.draw()

    love.graphics.push()
    love.graphics.translate(Screen.dx, Screen.dy)
    dispatch("draw")
    Fx.drawOver()
    love.graphics.pop()

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
