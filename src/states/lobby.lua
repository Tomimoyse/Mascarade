-- Vestíbulo de red: crear una partida o unirse a una de la red local.
--
-- Dos modos, decididos al entrar:
--   "host" -> abre el puerto, anuncia la partida y espera a un rival.
--   "join" -> escucha los anuncios y ofrece la lista, con IP manual de apoyo.
--
-- En cuanto la sesión dice que está jugando, le pasa el testigo a la pantalla
-- de partida. La sesión se crea aquí y viaja con ella.

local Gamestate = require("lib.gamestate")

local Config    = require("src.config")
local Palette   = require("src.palette")
local Fonts     = require("src.fonts")
local Screen    = require("src.screen")
local Audio     = require("src.audio")
local Fx        = require("src.fx")

local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Button    = require("src.ui.button")

local HostSession   = require("src.session.hostsession")
local ClientSession = require("src.session.clientsession")
local Discovery     = require("src.net.discovery")
local Transport     = require("src.net.transport")
local L             = require("locale.es")

local Lobby = {}

-- Flag de desarrollo: "--net <ip>" se conecta solo, sin esperar al click.
Lobby.autoJoin = nil

local PANEL = { x = 120, y = 56, w = 400, h = 230 }

local mode          -- "host" | "join"
local session       -- sesión en construcción
local browser       -- buscador de partidas (modo join)
local t = 0
local buttons = {}
local ipText = ""
local ipFocus = false
local errorMsg = nil
local foundList = {}

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------

local function cleanup()
    if browser then browser:close(); browser = nil end
    -- OJO: la sesión no se cierra si ya se la hemos pasado a la partida.
    if session and not Lobby.handedOver then session:close() end
    session = nil
    Lobby.handedOver = false
end

local function volver()
    cleanup()
    Gamestate.switch(require("src.states.menu"))
end

local function startHosting()
    errorMsg = nil
    session = HostSession({ port = Transport.DEFAULT_PORT, name = L.red.partidaDe })
    if session:status() == "error" then
        errorMsg = session.error
        session = nil
    end
end

local function joinAt(ip, port)
    errorMsg = nil
    if session then session:close() end
    session = ClientSession({ address = ip, port = port or Transport.DEFAULT_PORT })
    if session:status() == "error" then
        errorMsg = session.error
        session = nil
    end
end

local function startBrowsing()
    errorMsg = nil
    local b, err = Discovery.browse()
    if not b then errorMsg = err else browser = b end
end

function Lobby:enter(_previous, newMode)
    Fx.background.setMood("menu")
    Fx.background.setIntensity(0.45)
    mode = newMode or "host"
    t = 0
    ipText, ipFocus = "", false
    errorMsg = nil
    foundList = {}
    Lobby.handedOver = false

    buttons = {}
    buttons.back = Button({
        label = L.red.volver, accent = Palette.gray,
        x = PANEL.x + 14, y = PANEL.y + PANEL.h - 30, w = 100, h = 20,
        onClick = volver, sound = "back",
    })

    if mode == "host" then
        startHosting()
    elseif Lobby.autoJoin then
        joinAt(Lobby.autoJoin)
    else
        startBrowsing()
    end

    if mode == "join" and not Lobby.autoJoin then
        buttons.join = Button({
            label = L.red.unirse, accent = Palette.gold,
            x = PANEL.x + PANEL.w - 128, y = PANEL.y + PANEL.h - 30, w = 114, h = 20,
            onClick = function()
                if ipText ~= "" then joinAt(ipText) end
            end,
        })
    end
end

function Lobby:leave()
    cleanup()
end

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------

function Lobby:update(dt, mx, my)
    t = t + dt

    if session then session:update(dt) end
    if browser then
        browser:update(dt)
        foundList = browser:list()
    end

    -- En cuanto hay partida, el testigo pasa a la pantalla de juego.
    if session and session:status() == "playing" and session:view() then
        Lobby.handedOver = true
        local s = session
        session = nil
        if browser then browser:close(); browser = nil end
        Gamestate.switch(require("src.states.game"), s)
        return
    end

    if session and session:status() == "error" then
        errorMsg = session.error
        session:close()
        session = nil
    end

    for _, b in pairs(buttons) do b:update(dt, mx, my) end
end

---------------------------------------------------------------------------
-- Dibujado
---------------------------------------------------------------------------

-- Una fila por partida encontrada, clicable.
local function rowRect(i)
    return PANEL.x + 16, PANEL.y + 64 + (i - 1) * 20, PANEL.w - 32, 18
end

local function drawHost()
    Text.centered(L.red.esperando, PANEL.x, PANEL.y + 52, PANEL.w,
        { font = Fonts.bold, color = Palette.gold, outline = Palette.line })

    -- Puntos suspensivos animados, para que se note que sigue vivo.
    local puntos = string.rep(".", 1 + math.floor(t * 2) % 3)
    Text.centered(puntos, PANEL.x, PANEL.y + 68, PANEL.w,
        { font = Fonts.boldBig, color = Palette.gold, outline = Palette.line })

    local ip = (session and session.address) or "?"
    Text.centered(string.format(L.red.tuIP, ip), PANEL.x, PANEL.y + 108, PANEL.w,
        { font = Fonts.small, color = Palette.white, outline = Palette.line })
    Text.centered(string.format(L.red.puerto, Transport.DEFAULT_PORT),
        PANEL.x, PANEL.y + 122, PANEL.w,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })
    Text.centered(L.red.comoJugar, PANEL.x, PANEL.y + 146, PANEL.w,
        { font = Fonts.small, color = Palette.grayDark, outline = Palette.line })
end

local function drawJoin(mx, my)
    if session then
        Text.centered(string.format(L.red.conectando, session.address or ipText),
            PANEL.x, PANEL.y + 90, PANEL.w,
            { font = Fonts.bold, color = Palette.gold, outline = Palette.line })
        return
    end

    Text.outlined(L.red.buscando, PANEL.x + 16, PANEL.y + 44,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })

    if #foundList == 0 then
        Text.outlined(L.red.ningunaAun, PANEL.x + 16, PANEL.y + 66,
            { font = Fonts.small, color = Palette.grayDark, outline = Palette.line })
    end

    for i, p in ipairs(foundList) do
        if i > 4 then break end
        local x, y, w, h = rowRect(i)
        local hovered = mx >= x and mx < x + w and my >= y and my < y + h
        Panel.draw(x, y, w, h, {
            fill = hovered and Palette.panelLight or Palette.panelDark,
            border = hovered and Palette.gold or Palette.grayDark,
            highlight = nil, radius = 2, shadowOffset = 2,
        })
        Text.outlined(p.name, x + 6, y + 5,
            { font = Fonts.small, color = Palette.bone, outline = Palette.line })
        Text.outlined(p.ip, x + w - 86, y + 5,
            { font = Fonts.small, color = Palette.gray, outline = Palette.line })
    end

    -- Campo de IP manual, por si el broadcast no llega.
    local fy = PANEL.y + PANEL.h - 62
    Text.outlined(L.red.ipManual, PANEL.x + 16, fy,
        { font = Fonts.small, color = Palette.gray, outline = Palette.line })
    local fx, fw = PANEL.x + 110, 180
    Panel.draw(fx, fy - 3, fw, 16, {
        fill = Palette.panelDark,
        border = ipFocus and Palette.gold or Palette.grayDark,
        highlight = nil, radius = 2, shadowOffset = 1,
    })
    local cursor = (ipFocus and math.floor(t * 2) % 2 == 0) and "_" or ""
    Text.outlined(ipText .. cursor, fx + 5, fy + 1,
        { font = Fonts.small, color = Palette.white, outline = Palette.line })
end

function Lobby:draw()
    Panel.draw(PANEL.x, PANEL.y, PANEL.w, PANEL.h, {
        fill = Palette.panel, border = Palette.gold,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 4,
    })
    Text.centered(mode == "host" and L.red.crear or L.red.unirse,
        PANEL.x, PANEL.y + 10, PANEL.w,
        { font = Fonts.boldBig, color = Palette.gold, outline = Palette.line, shadow = 2 })
    Panel.divider(PANEL.x + 12, PANEL.y + 32, PANEL.w - 24)

    local mx, my = Screen.toCanvas(love.mouse.getPosition())
    if mode == "host" then drawHost() else drawJoin(mx, my) end

    if errorMsg then
        Text.centered(errorMsg, PANEL.x, PANEL.y + PANEL.h - 48, PANEL.w,
            { font = Fonts.small, color = Palette.red, outline = Palette.line })
    end

    for _, b in pairs(buttons) do b:draw() end
end

---------------------------------------------------------------------------
-- Entrada
---------------------------------------------------------------------------

function Lobby:mousepressed(mx, my, btn)
    for _, b in pairs(buttons) do
        if b:mousepressed(mx, my, btn) then return end
    end
    if mode ~= "join" or session then return end

    -- Click en una partida de la lista.
    for i, p in ipairs(foundList) do
        if i > 4 then break end
        local x, y, w, h = rowRect(i)
        if mx >= x and mx < x + w and my >= y and my < y + h then
            Audio.play("click")
            joinAt(p.ip, p.port)
            return
        end
    end

    -- Click en el campo de IP.
    local fy = PANEL.y + PANEL.h - 62
    local fx, fw = PANEL.x + 110, 180
    ipFocus = (mx >= fx and mx < fx + fw and my >= fy - 3 and my < fy + 13)
end

function Lobby:mousereleased(mx, my, btn)
    for _, b in pairs(buttons) do b:mousereleased(mx, my, btn) end
end

function Lobby:textinput(text)
    -- Solo lo que puede formar una IP o un puerto.
    if ipFocus and #ipText < 21 and text:match("[%d%.:]") then
        ipText = ipText .. text
    end
end

function Lobby:keypressed(key)
    if key == "escape" then
        Audio.play("back")
        volver()
    elseif key == "backspace" and ipFocus then
        ipText = ipText:sub(1, -2)
    elseif key == "return" and mode == "join" and ipText ~= "" then
        joinAt(ipText)
    end
end

return Lobby
