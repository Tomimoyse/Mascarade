-- Generador de números pseudoaleatorios determinista (Park-Miller / "minimal
-- standard"). Lo usamos en vez de love.math para que la lógica sea Lua puro y
-- los tests den siempre el mismo resultado con la misma semilla.
--
-- Multiplicador 16807 y módulo 2^31-1: el producto máximo es ~3.6e13, muy por
-- debajo de 2^53, así que la aritmética en coma flotante es exacta.

local Rng = {}
Rng.__index = Rng

local M = 2147483647  -- 2^31 - 1
local A = 16807

function Rng.new(seed)
    local self = setmetatable({}, Rng)
    self:setSeed(seed or os.time())
    return self
end

function Rng:setSeed(seed)
    local s = math.floor(math.abs(seed or 1)) % M
    if s == 0 then s = 1 end
    self.state = s
    -- Unas cuantas iteraciones de calentamiento: semillas pequeñas y
    -- consecutivas producen primeros valores muy parecidos.
    for _ = 1, 8 do self:next() end
end

-- Siguiente entero en [1, 2^31-2].
function Rng:next()
    self.state = (self.state * A) % M
    return self.state
end

-- Flotante en [0, 1).
function Rng:float()
    return (self:next() - 1) / (M - 1)
end

-- Entero en [1, n], o en [a, b] si se pasan dos argumentos.
function Rng:int(a, b)
    if b == nil then a, b = 1, a end
    local n = b - a + 1
    if n <= 0 then return a end
    return a + (self:next() % n)
end

-- Baraja una lista en el sitio (Fisher-Yates).
function Rng:shuffle(list)
    for i = #list, 2, -1 do
        local j = self:int(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

return Rng
