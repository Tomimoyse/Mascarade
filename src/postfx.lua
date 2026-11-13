-- Cadena de postprocesado: bloom (bright pass + blur separable) y CRT.
-- Se aplica al volcar el canvas interno a la ventana.

local Screen   = require("src.screen")
local Settings = require("src.settings")

local Postfx = {}

local shaders = {}
local bloomA, bloomB, blackPixel

function Postfx.load()
    shaders.bright = love.graphics.newShader("assets/shaders/brightpass.glsl")
    shaders.blur   = love.graphics.newShader("assets/shaders/blur.glsl")
    shaders.crt    = love.graphics.newShader("assets/shaders/crt.glsl")

    Postfx.resize(Screen.w, Screen.h)
    Screen.onResize(Postfx.resize)

    -- Textura negra de 1x1 para cuando el bloom está desactivado.
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 0, 0, 0, 1)
    blackPixel = love.graphics.newImage(data)

end

-- El canvas cambia de tamaño con la ventana, así que el bloom y las scanlines
-- tienen que seguirlo.
local bloomW, bloomH = 1, 1
function Postfx.resize(w, h)
    bloomW = math.max(1, math.floor(w / 2))
    bloomH = math.max(1, math.floor(h / 2))
    bloomA = love.graphics.newCanvas(bloomW, bloomH)
    bloomB = love.graphics.newCanvas(bloomW, bloomH)
    bloomA:setFilter("linear", "linear")
    bloomB:setFilter("linear", "linear")
    if shaders.crt then shaders.crt:send("uCanvasRes", { w, h }) end
end

-- Genera el canvas de bloom a partir de la escena.
local function buildBloom(scene)
    local prevBlend = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha", "premultiplied")

    -- 1) Bright pass, reduciendo a media resolución.
    --    Pasamos la escena a filtro lineal sólo para este downsample.
    scene:setFilter("linear", "linear")
    love.graphics.setCanvas(bloomA)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setShader(shaders.bright)
    shaders.bright:send("uThreshold", 0.55)
    shaders.bright:send("uKnee", 0.25)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(scene, 0, 0, 0,
        bloomW / Screen.w, bloomH / Screen.h)
    scene:setFilter("nearest", "nearest")

    -- 2) Desenfoque horizontal y vertical.
    love.graphics.setShader(shaders.blur)
    shaders.blur:send("uScale", 1.0)

    love.graphics.setCanvas(bloomB)
    love.graphics.clear(0, 0, 0, 1)
    shaders.blur:send("uDir", { 1 / bloomW, 0 })
    love.graphics.draw(bloomA)

    love.graphics.setCanvas(bloomA)
    love.graphics.clear(0, 0, 0, 1)
    shaders.blur:send("uDir", { 0, 1 / bloomH })
    love.graphics.draw(bloomB)

    love.graphics.setShader()
    love.graphics.setCanvas()
    love.graphics.setBlendMode(prevBlend)
end

-- Vuelca el canvas interno a la ventana aplicando los efectos activos.
function Postfx.present(time)
    local scene   = Screen.canvas
    local useCrt   = Settings.get("crt") and true or false
    local useBloom = Settings.get("bloom") and true or false

    if useBloom then buildBloom(scene) end

    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)

    if useCrt or useBloom then
        local sh = shaders.crt
        love.graphics.setShader(sh)
        sh:send("uCrt", useCrt and 1.0 or 0.0)
        sh:send("uBloom", useBloom and 0.85 or 0.0)
        sh:send("uBloomTex", useBloom and bloomA or blackPixel)
    end

    love.graphics.draw(scene, Screen.ox, Screen.oy, 0, Screen.scale, Screen.scale)
    love.graphics.setShader()
end

return Postfx
