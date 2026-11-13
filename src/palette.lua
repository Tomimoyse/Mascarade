-- Paleta del juego: fondos oscuros con acentos vivos (rojo, azul, dorado).
-- Cada color es una tabla {r, g, b} normalizada 0..1.

local function hex(s)
    local r = tonumber(s:sub(2, 3), 16) / 255
    local g = tonumber(s:sub(4, 5), 16) / 255
    local b = tonumber(s:sub(6, 7), 16) / 255
    return { r, g, b }
end

local P = {
    -- Oscuros / estructura
    void       = hex("#0b0812"),
    ink        = hex("#151022"),
    line       = hex("#07050d"),

    -- Mesa de juego
    felt       = hex("#1a2b3c"),
    feltLight  = hex("#26405a"),
    feltDark   = hex("#101c28"),

    -- Paneles de UI
    panel      = hex("#241b33"),
    panelLight = hex("#352a4a"),
    panelDark  = hex("#160f22"),

    -- Neutros
    white      = hex("#f6f3ea"),
    bone       = hex("#d9d2bf"),
    gray       = hex("#7d748c"),
    grayDark   = hex("#4a4358"),

    -- Acentos
    red        = hex("#e5394a"),
    redDark    = hex("#8d1d2e"),
    blue       = hex("#3d82e0"),
    blueDark   = hex("#1e4091"),
    gold       = hex("#f3b93f"),
    goldDark   = hex("#a9711c"),
    green      = hex("#53c472"),
    purple     = hex("#9150e0"),
}

P.hex = hex

-- Devuelve el color con alfa: P.rgba(P.red, 0.5)
function P.rgba(c, a)
    return c[1], c[2], c[3], a or 1
end

-- Mezcla dos colores (t = 0 devuelve a, t = 1 devuelve b).
function P.mix(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
    }
end

-- Aclara u oscurece un color (f > 1 aclara, f < 1 oscurece).
function P.scale(c, f)
    return { math.min(c[1] * f, 1), math.min(c[2] * f, 1), math.min(c[3] * f, 1) }
end

-- Colores identitarios de cada jugador.
P.player = { P.red, P.blue }

return P
