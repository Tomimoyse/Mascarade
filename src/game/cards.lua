-- Mazo de disfraces: composición, creación y utilidades sobre los tipos.
-- Lua puro, sin dependencias de LÖVE.

local Config = require("src.config")

local Cards = {}

Cards.KINDS = Config.KINDS
Cards.COMPOSITION = Config.DECK_COMPOSITION

-- Conjunto para comprobaciones rápidas.
local KIND_SET = {}
for _, k in ipairs(Cards.KINDS) do KIND_SET[k] = true end

function Cards.isKind(k)
    return KIND_SET[k] == true
end

-- Crea las 32 cartas del mazo, sin barajar. Cada carta lleva un id único
-- para que la interfaz pueda seguirla por pantalla.
function Cards.buildDeck()
    local deck = {}
    local id = 0
    for _, kind in ipairs(Cards.KINDS) do
        for _ = 1, Cards.COMPOSITION[kind] do
            id = id + 1
            deck[#deck + 1] = { id = id, kind = kind }
        end
    end
    return deck
end

-- Número total de cartas que debería tener el mazo (32).
function Cards.totalCount()
    local n = 0
    for _, kind in ipairs(Cards.KINDS) do
        n = n + Cards.COMPOSITION[kind]
    end
    return n
end

-- Máximo de disfraces de este tipo que se pueden jugar en un mismo turno.
function Cards.chainLimit(kind)
    return Config.CHAIN_LIMIT_BY_KIND[kind] or 0
end

return Cards
