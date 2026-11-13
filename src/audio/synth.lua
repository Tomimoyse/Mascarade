-- Síntesis procedural de sonidos. No hay archivos de audio en el proyecto:
-- todas las muestras se generan en el arranque a partir de osciladores simples.
-- Son placeholders decentes, fáciles de sustituir por .ogg más adelante.

local Synth = {}

local RATE = 44100
Synth.RATE = RATE

---------------------------------------------------------------------------
-- Osciladores. Reciben la fase acumulada (en ciclos, no en radianes).
---------------------------------------------------------------------------
local function sine(p)   return math.sin(p * 2 * math.pi) end
local function square(p) return (p % 1) < 0.5 and 1 or -1 end
local function saw(p)    return (p % 1) * 2 - 1 end
local function tri(p)
    local x = p % 1
    return x < 0.5 and (x * 4 - 1) or (3 - x * 4)
end
-- Pulso con ancho variable: más nasal, muy "chiptune".
local function pulse(width)
    return function(p) return (p % 1) < width and 1 or -1 end
end

Synth.wave = { sine = sine, square = square, saw = saw, tri = tri, pulse = pulse }

---------------------------------------------------------------------------
-- Envolventes. Reciben u = progreso normalizado 0..1.
---------------------------------------------------------------------------
local Env = {}
function Env.pluck(u)  return (1 - u) ^ 3 end
function Env.blip(u)   return math.min(u * 60, 1) * (1 - u) ^ 2 end
function Env.thud(u)   return math.min(u * 120, 1) * (1 - u) ^ 5 end
function Env.pad(u)    return math.sin(u * math.pi) end
function Env.hold(u)   return math.min(u * 80, 1) * math.min((1 - u) * 12, 1) end
Synth.Env = Env

---------------------------------------------------------------------------
-- Construcción de muestras
---------------------------------------------------------------------------

-- Crea un SoundData sumando varias capas.
-- layers: lista de funciones gen(t, u) -> muestra en [-1, 1]
function Synth.render(dur, layers)
    local n = math.max(1, math.floor(RATE * dur))
    local sd = love.sound.newSoundData(n, RATE, 16, 1)
    for i = 0, n - 1 do
        local t = i / RATE
        local u = i / n
        local v = 0
        for _, gen in ipairs(layers) do
            v = v + gen(t, u)
        end
        if v > 1 then v = 1 elseif v < -1 then v = -1 end
        sd:setSample(i, v)
    end
    return sd
end

-- Capa de tono con barrido de frecuencia de f0 a f1.
-- opts = { wave, env, amp, curve }
function Synth.tone(f0, f1, opts)
    opts = opts or {}
    local wave  = opts.wave or sine
    local env   = opts.env or Env.pluck
    local amp   = opts.amp or 0.5
    local curve = opts.curve or 1
    local phase = 0
    return function(t, u)
        local f = f0 + (f1 - f0) * (u ^ curve)
        phase = phase + f / RATE
        return wave(phase) * env(u) * amp
    end
end

-- Capa de ruido blanco filtrado (percusión, roce de cartas).
function Synth.noise(opts)
    opts = opts or {}
    local env = opts.env or Env.pluck
    local amp = opts.amp or 0.3
    local lp  = opts.lowpass or 1   -- 1 = sin filtrar, 0.05 = muy oscuro
    local last = 0
    return function(t, u)
        local r = love.math.random() * 2 - 1
        last = last + (r - last) * lp
        return last * env(u) * amp
    end
end

-- Arpegio: varias notas seguidas dentro de la misma muestra.
function Synth.arp(freqs, opts)
    opts = opts or {}
    local wave = opts.wave or square
    local amp  = opts.amp or 0.35
    local n    = #freqs
    local phase = 0
    return function(t, u)
        local idx = math.min(math.floor(u * n) + 1, n)
        local lu  = (u * n) % 1
        phase = phase + freqs[idx] / RATE
        local e = math.min(lu * 30, 1) * (1 - lu) ^ 1.5
        return wave(phase) * e * amp * (1 - u * 0.35)
    end
end

return Synth
