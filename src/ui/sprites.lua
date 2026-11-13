-- Generación procedural de sprites. Todo el arte del juego se dibuja por código
-- en el arranque: no hay imágenes externas, y así es 100% original.

local Palette = require("src.palette")

local Sprites = {}

local function clamp(v, a, b)
    if v < a then return a elseif v > b then return b else return v end
end

local function mix(a, b, t)
    t = clamp(t, 0, 1)
    return a[1] + (b[1] - a[1]) * t,
           a[2] + (b[2] - a[2]) * t,
           a[3] + (b[3] - a[3]) * t
end

local function finish(data)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end

-- Disco con iluminación diagonal superior-izquierda y borde oscuro.
-- Es la ficha base del juego: un token circular sin tipo.
function Sprites.disc(d, base, top, rim)
    local data = love.image.newImageData(d, d)
    local c = (d - 1) / 2
    local r = d / 2 - 0.5
    for y = 0, d - 1 do
        for x = 0, d - 1 do
            local dx, dy = x - c, y - c
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= r then
                if dist > r - 1.3 then
                    data:setPixel(x, y, rim[1], rim[2], rim[3], 1)
                else
                    -- Luz que entra desde arriba-izquierda.
                    local l = ((-dx - dy) / (r * 1.7)) * 0.5 + 0.5
                    local rr, gg, bb = mix(base, top, l * 1.15 - 0.1)
                    data:setPixel(x, y, rr, gg, bb, 1)
                end
            end
        end
    end
    return finish(data)
end

-- Sombra blanda bajo la ficha (elipse achatada y semitransparente).
function Sprites.shadow(w, h)
    local data = love.image.newImageData(w, h)
    local cx, cy = (w - 1) / 2, (h - 1) / 2
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local dx = (x - cx) / (w / 2)
            local dy = (y - cy) / (h / 2)
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= 1 then
                local a = (1 - dist) * 0.5
                data:setPixel(x, y, 0, 0, 0, a)
            end
        end
    end
    return finish(data)
end

-- Corona de 9x6: marca la ficha coronada como rey.
function Sprites.crown()
    local art = {
        "..#...#...#..",
        ".#@#.#@#.#@#.",
        ".#@@@@@@@@@#.",
        "..#@@@@@@@#..",
        "..#@#@#@#@#..",
        "...#######...",
    }
    local h = #art
    local w = #art[1]
    local data = love.image.newImageData(w, h)
    local outline = Palette.line
    local body    = Palette.gold
    local shine   = Palette.hex("#fde7a0")
    for y = 1, h do
        for x = 1, w do
            local ch = art[y]:sub(x, x)
            if ch == "#" then
                data:setPixel(x - 1, y - 1, outline[1], outline[2], outline[3], 1)
            elseif ch == "@" then
                local c = (y <= 3) and shine or body
                data:setPixel(x - 1, y - 1, c[1], c[2], c[3], 1)
            end
        end
    end
    return finish(data)
end

---------------------------------------------------------------------------
-- Glifos de las piezas de ajedrez
---------------------------------------------------------------------------
--
-- Solo se dibuja la silueta con '@'. El contorno de 1 px y la iluminacion
-- vertical los añade fromArt() por codigo, asi que las siluetas se pueden
-- retocar sin tener que redibujar bordes a mano.
-- Hace falta dejar un margen transparente de 1 px para que quepa el contorno.

Sprites.GLYPH_ART = {
    peon = {
        "................",
        "................",
        "................",
        ".......@@.......",
        "......@@@@......",
        "......@@@@......",
        ".......@@.......",
        ".......@@.......",
        "......@@@@......",
        ".....@@@@@@.....",
        "....@@@@@@@@....",
        "....@@@@@@@@....",
        "................",
        "................",
        "................",
        "................",
    },
    torre = {
        "................",
        "................",
        "..@@...@@...@@..",
        "..@@@@@@@@@@@@..",
        "..@@@@@@@@@@@@..",
        "....@@@@@@@@....",
        "....@@@@@@@@....",
        "....@@@@@@@@....",
        "....@@@@@@@@....",
        "....@@@@@@@@....",
        "...@@@@@@@@@@...",
        "..@@@@@@@@@@@@..",
        "..@@@@@@@@@@@@..",
        "................",
        "................",
        "................",
    },
    caballo = {
        "................",
        "................",
        "......@@@.......",
        ".....@@@@@@.....",
        "....@@@@@@@@....",
        "...@@@@@@@@@@...",
        "...@@..@@@@@@...",
        "..@@...@@@@@@...",
        "..@....@@@@@@...",
        ".......@@@@@@...",
        "......@@@@@@@...",
        ".....@@@@@@@@...",
        "....@@@@@@@@@@..",
        "..@@@@@@@@@@@@..",
        "................",
        "................",
    },
    alfil = {
        "................",
        ".......@@.......",
        "......@@@@......",
        ".....@@@@@@.....",
        ".....@@@@@@.....",
        ".....@@.@@@.....",
        ".....@@@@@@.....",
        "......@@@@......",
        ".......@@.......",
        "......@@@@......",
        ".....@@@@@@.....",
        "....@@@@@@@@....",
        "...@@@@@@@@@@...",
        "..@@@@@@@@@@@@..",
        "................",
        "................",
    },
    reina = {
        "................",
        ".......@@.......",
        "......@@@@......",
        ".......@@.......",
        "..@..@@@@@@..@..",
        "..@@@@@@@@@@@@..",
        "..@@@@@@@@@@@@..",
        "...@@@@@@@@@@...",
        "....@@@@@@@@....",
        ".....@@@@@@.....",
        ".....@@@@@@.....",
        "....@@@@@@@@....",
        "...@@@@@@@@@@...",
        "..@@@@@@@@@@@@..",
        "................",
        "................",
    },
    rey = {
        "................",
        ".......@@.......",
        ".......@@.......",
        ".....@@@@@@.....",
        ".......@@.......",
        ".....@@@@@@.....",
        "....@@@@@@@@....",
        "....@@@@@@@@....",
        ".....@@@@@@.....",
        ".....@@@@@@.....",
        "....@@@@@@@@....",
        "...@@@@@@@@@@...",
        "..@@@@@@@@@@@@..",
        "..@@@@@@@@@@@@..",
        "................",
        "................",
    },
}

-- Convierte una silueta de texto en una imagen con contorno e iluminacion.
-- opts = { top, base, outline }
function Sprites.fromArt(art, opts)
    opts = opts or {}
    local top     = opts.top or Palette.white
    local base    = opts.base or Palette.bone
    local outline = opts.outline or Palette.line

    local h, w = #art, #art[1]
    local solid = {}
    local minY, maxY = h, 1
    for y = 1, h do
        solid[y] = {}
        for x = 1, w do
            local on = art[y]:sub(x, x) == "@"
            solid[y][x] = on
            if on then
                if y < minY then minY = y end
                if y > maxY then maxY = y end
            end
        end
    end

    local data = love.image.newImageData(w, h)
    local span = math.max(maxY - minY, 1)

    -- Relleno: mas claro arriba, mas oscuro abajo.
    for y = 1, h do
        for x = 1, w do
            if solid[y][x] then
                local t = (y - minY) / span
                local r, g, b = mix(top, base, t)
                data:setPixel(x - 1, y - 1, r, g, b, 1)
            end
        end
    end

    -- Contorno: todo pixel vacio pegado a uno solido (incluidas diagonales).
    for y = 1, h do
        for x = 1, w do
            if not solid[y][x] then
                local touching = false
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local ny, nx = y + dy, x + dx
                        if solid[ny] and solid[ny][nx] then touching = true end
                    end
                end
                if touching then
                    data:setPixel(x - 1, y - 1, outline[1], outline[2], outline[3], 1)
                end
            end
        end
    end

    return finish(data)
end

---------------------------------------------------------------------------
-- Carga de todo el atlas procedural
---------------------------------------------------------------------------

function Sprites.load()
    local DISC = 22

    Sprites.piece = {}
    -- Jugador 1: rojo. Jugador 2: azul.
    Sprites.piece[1] = Sprites.disc(DISC,
        Palette.hex("#b4262f"), Palette.hex("#f4717a"), Palette.hex("#4a0d14"))
    Sprites.piece[2] = Sprites.disc(DISC,
        Palette.hex("#2558a8"), Palette.hex("#7fb4f2"), Palette.hex("#0b1d42"))

    -- Ficha "fantasma" para previsualizar destinos.
    Sprites.ghost = Sprites.disc(DISC,
        Palette.hex("#3a3550"), Palette.hex("#6a6188"), Palette.hex("#1a1626"))

    Sprites.pieceShadow = Sprites.shadow(DISC + 4, 9)
    Sprites.crownIcon   = Sprites.crown()

    -- Glifos de las seis piezas, en hueso claro sobre contorno oscuro.
    Sprites.glyph = {}
    for kind, art in pairs(Sprites.GLYPH_ART) do
        Sprites.glyph[kind] = Sprites.fromArt(art, {
            top = Palette.hex("#fbf7ec"), base = Palette.hex("#b3a88f"),
            outline = Palette.line,
        })
    end
    Sprites.GLYPH_SIZE = 16

    Sprites.DISC = DISC
end

return Sprites
