-- Pantalla de reglas. Texto desplazable con la rueda del ratón.

local Gamestate = require("lib.gamestate")
local Config    = require("src.config")
local Palette   = require("src.palette")
local Screen    = require("src.screen")
local Fonts     = require("src.fonts")
local Text      = require("src.ui.text")
local Panel     = require("src.ui.panel")
local Button    = require("src.ui.button")
local Audio     = require("src.audio")
local L         = require("locale.es")

local Rules = {}

local PANEL = { x = 56, y = 30, w = 528, h = 300 }
local scroll = 0
local maxScroll = 0
local btnVolver

-- Cada entrada es { titulo } o { nil, texto }.
local CONTENIDO = {
    { "El tablero" },
    { nil, "32 fichas circulares identicas, 16 por jugador, colocadas como en el ajedrez. Las fichas no tienen tipo: el movimiento lo da la carta que juegas." },
    { "Tu turno" },
    { nil, "Pasar y robar 2 cartas (solo como primera accion), o jugar una carta de disfraz y mover una ficha propia como esa pieza." },
    { nil, "Si el movimiento come una ficha rival, ganas una accion extra. Si no come, el turno termina." },
    { "Encadenar" },
    { nil, "No puedes repetir el mismo disfraz dos veces seguidas. Hay un maximo por tipo y por turno: 8 peones, 2 torres, 2 caballos, 2 alfiles, 1 reina, 1 rey." },
    { nil, "Todo el encadenado se hace con la misma ficha que movio primero." },
    { "Coronacion" },
    { nil, "Tu primera carta de rey corona esa ficha para siempre. El rey solo se mueve como rey, es intocable hasta que sea tu ultima ficha, y te da una accion gratis: moverlo sin gastar carta." },
    { "Promocion" },
    { nil, "Si una ficha llega a la primera fila del rival, puedes descartar una carta de peon y recuperar del descarte la primera carta que no sea peon. Es gratis." },
    { "Victoria" },
    { nil, "Gana quien se come las 16 fichas del rival." },
}

function Rules:init()
    btnVolver = Button({
        label = L.reglas.volver, accent = Palette.gold,
        x = PANEL.x + PANEL.w - 102, y = PANEL.y + PANEL.h - 26, w = 90, h = 18,
        onClick = function() Gamestate.pop() end,
        sound = "back",
    })
end

function Rules:enter()
    scroll = 0
end

function Rules:update(dt, mx, my)
    btnVolver:update(dt, mx, my)
end

function Rules:draw()
    Screen.scrim(0.6)

    Panel.draw(PANEL.x, PANEL.y, PANEL.w, PANEL.h, {
        fill = Palette.panel, border = Palette.gold,
        highlight = Palette.panelLight, radius = 3, shadowOffset = 4,
    })
    Text.centered(L.reglas.titulo, PANEL.x, PANEL.y + 8, PANEL.w, {
        font = Fonts.boldBig, color = Palette.gold, outline = Palette.line, shadow = 2,
    })
    Panel.divider(PANEL.x + 10, PANEL.y + 28, PANEL.w - 20)

    -- Recorte del area de texto
    local ax, ay = PANEL.x + 14, PANEL.y + 34
    local aw, ah = PANEL.w - 28, PANEL.h - 68
    love.graphics.setScissor(ax, ay, aw, ah)

    local y = ay - scroll
    for _, entry in ipairs(CONTENIDO) do
        if entry[1] then
            y = y + 4
            Text.outlined(entry[1]:upper(), ax, y, {
                font = Fonts.bold, color = Palette.gold, outline = Palette.line,
            })
            y = y + 12
        else
            local _, lines = Fonts.small:getWrap(entry[2], aw)
            Text.outlined(entry[2], ax, y, {
                font = Fonts.small, color = Palette.bone, outline = Palette.line,
                limit = aw, align = "left",
            })
            y = y + #lines * 10 + 3
        end
    end
    maxScroll = math.max(0, (y + scroll) - (ay + ah))
    love.graphics.setScissor()

    -- Barra de desplazamiento
    if maxScroll > 0 then
        local bx = PANEL.x + PANEL.w - 10
        love.graphics.setColor(Palette.rgba(Palette.panelDark, 1))
        love.graphics.rectangle("fill", bx, ay, 3, ah)
        local frac = ah / (ah + maxScroll)
        local bh = math.max(8, math.floor(ah * frac))
        local by = ay + math.floor((ah - bh) * (scroll / maxScroll))
        love.graphics.setColor(Palette.rgba(Palette.gold, 1))
        love.graphics.rectangle("fill", bx, by, 3, bh)
        love.graphics.setColor(1, 1, 1, 1)
    end

    btnVolver:draw()
end

function Rules:wheelmoved(x, y)
    scroll = math.max(0, math.min(maxScroll, scroll - y * 16))
end

function Rules:mousepressed(mx, my, btn) btnVolver:mousepressed(mx, my, btn) end
function Rules:mousereleased(mx, my, btn) btnVolver:mousereleased(mx, my, btn) end

function Rules:keypressed(key)
    if key == "escape" or key == "backspace" then
        Audio.play("back")
        Gamestate.pop()
    elseif key == "down" then
        scroll = math.min(maxScroll, scroll + 16)
    elseif key == "up" then
        scroll = math.max(0, scroll - 16)
    end
end

return Rules
