-- Banco de sonidos. Cada efecto se sintetiza una vez al cargar y se reproduce
-- desde un pool de fuentes clonadas, con variación aleatoria de tono para que
-- repetirlo no suene mecánico.

local Synth    = require("src.audio.synth")
local Settings = require("src.settings")

local Audio = {}

local S = Synth
local W = Synth.wave
local E = Synth.Env

local POOL_SIZE = 4

-- name -> { sources = {...}, next = 1, volume = n, pitch = n, pitchVar = n }
local bank = {}

---------------------------------------------------------------------------
-- Definición de los sonidos
---------------------------------------------------------------------------

-- Devuelve name -> { dur, layers, volume, pitchVar }
local function definitions()
    return {
        -- Navegación de menú
        hover = {
            dur = 0.06, volume = 0.25, pitchVar = 0.10,
            layers = { S.tone(900, 1200, { wave = W.pulse(0.25), env = E.blip, amp = 0.28 }) },
        },
        click = {
            dur = 0.09, volume = 0.5, pitchVar = 0.08,
            layers = {
                S.tone(520, 880, { wave = W.square, env = E.blip, amp = 0.32 }),
                S.noise({ env = E.pluck, amp = 0.10, lowpass = 0.45 }),
            },
        },
        back = {
            dur = 0.10, volume = 0.45, pitchVar = 0.08,
            layers = { S.tone(700, 380, { wave = W.square, env = E.blip, amp = 0.32 }) },
        },
        error = {
            dur = 0.18, volume = 0.5, pitchVar = 0.05,
            layers = {
                S.tone(180, 120, { wave = W.saw, env = E.hold, amp = 0.30 }),
                S.tone(91, 83, { wave = W.square, env = E.hold, amp = 0.18 }),
            },
        },

        -- Cartas
        cardDraw = {
            dur = 0.16, volume = 0.45, pitchVar = 0.14,
            layers = { S.noise({ env = E.pad, amp = 0.34, lowpass = 0.30 }) },
        },
        cardFlip = {
            dur = 0.13, volume = 0.5, pitchVar = 0.12,
            layers = {
                S.noise({ env = E.blip, amp = 0.26, lowpass = 0.55 }),
                S.tone(420, 1050, { wave = W.tri, env = E.blip, amp = 0.20 }),
            },
        },
        cardPlace = {
            dur = 0.14, volume = 0.6, pitchVar = 0.10,
            layers = {
                S.tone(240, 90, { wave = W.sine, env = E.thud, amp = 0.55, curve = 0.5 }),
                S.noise({ env = E.pluck, amp = 0.16, lowpass = 0.25 }),
            },
        },

        -- Tablero
        pieceMove = {
            dur = 0.12, volume = 0.5, pitchVar = 0.12,
            layers = {
                S.tone(300, 140, { wave = W.sine, env = E.thud, amp = 0.45 }),
                S.noise({ env = E.pluck, amp = 0.10, lowpass = 0.20 }),
            },
        },
        capture = {
            dur = 0.32, volume = 0.85, pitchVar = 0.09,
            layers = {
                S.tone(420, 60, { wave = W.square, env = E.thud, amp = 0.40, curve = 0.45 }),
                S.noise({ env = E.pluck, amp = 0.34, lowpass = 0.60 }),
                S.tone(70, 42, { wave = W.sine, env = E.pad, amp = 0.35 }),
            },
        },
        extraAction = {
            dur = 0.22, volume = 0.6, pitchVar = 0.06,
            layers = { S.arp({ 660, 880, 1320 }, { wave = W.pulse(0.35), amp = 0.30 }) },
        },

        -- Eventos especiales
        crown = {
            dur = 0.70, volume = 0.85, pitchVar = 0.03,
            layers = {
                S.arp({ 523, 659, 784, 1047, 1319 }, { wave = W.pulse(0.4), amp = 0.26 }),
                S.tone(131, 262, { wave = W.tri, env = E.pad, amp = 0.22 }),
            },
        },
        promote = {
            dur = 0.45, volume = 0.7, pitchVar = 0.05,
            layers = { S.arp({ 440, 587, 740, 880 }, { wave = W.tri, amp = 0.30 }) },
        },
        coin = {
            dur = 0.55, volume = 0.7, pitchVar = 0.04,
            layers = {
                S.tone(1800, 1500, { wave = W.sine, env = E.pluck, amp = 0.22 }),
                S.tone(2700, 2250, { wave = W.sine, env = E.pluck, amp = 0.14 }),
            },
        },
        turnChange = {
            dur = 0.26, volume = 0.5, pitchVar = 0.06,
            layers = { S.arp({ 330, 440 }, { wave = W.tri, amp = 0.28 }) },
        },

        -- Fin de partida
        victory = {
            dur = 1.20, volume = 0.9, pitchVar = 0.0,
            layers = {
                S.arp({ 523, 659, 784, 1047, 784, 1047, 1319 },
                      { wave = W.pulse(0.45), amp = 0.26 }),
                S.tone(131, 196, { wave = W.tri, env = E.pad, amp = 0.20 }),
            },
        },
        defeat = {
            dur = 1.20, volume = 0.9, pitchVar = 0.0,
            layers = {
                S.arp({ 440, 392, 330, 262, 196 }, { wave = W.saw, amp = 0.22 }),
                S.tone(110, 70, { wave = W.sine, env = E.pad, amp = 0.26 }),
            },
        },
    }
end

---------------------------------------------------------------------------
-- Carga y reproducción
---------------------------------------------------------------------------

function Audio.load()
    bank = {}
    for name, def in pairs(definitions()) do
        local data = Synth.render(def.dur, def.layers)
        local base = love.audio.newSource(data, "static")
        local sources = { base }
        for i = 2, POOL_SIZE do
            sources[i] = base:clone()
        end
        bank[name] = {
            sources  = sources,
            next     = 1,
            volume   = def.volume or 0.6,
            pitchVar = def.pitchVar or 0.08,
        }
    end
    Audio.applyVolume()
end

-- Reaplica el volumen maestro de las opciones.
function Audio.applyVolume()
    love.audio.setVolume(Settings.get("volume") or 0.7)
end

-- Reproduce un sonido. opts = { pitch, volume, var }
function Audio.play(name, opts)
    local entry = bank[name]
    if not entry then return end
    opts = opts or {}

    local src = entry.sources[entry.next]
    entry.next = entry.next % #entry.sources + 1

    local var = opts.var or entry.pitchVar
    local pitch = (opts.pitch or 1) * (1 + (love.math.random() * 2 - 1) * var)
    src:setPitch(math.max(0.2, pitch))
    src:setVolume((opts.volume or 1) * entry.volume)
    src:stop()
    src:play()
    return src
end

-- Reproduce con un retardo: útil para encadenar sonidos en una resolución.
-- Requiere que alguien llame a Audio.update(dt).
local pending = {}
function Audio.playAfter(delay, name, opts)
    pending[#pending + 1] = { t = delay, name = name, opts = opts }
end

function Audio.update(dt)
    for i = #pending, 1, -1 do
        local p = pending[i]
        p.t = p.t - dt
        if p.t <= 0 then
            Audio.play(p.name, p.opts)
            table.remove(pending, i)
        end
    end
end

function Audio.stopAll()
    love.audio.stop()
    for i = #pending, 1, -1 do pending[i] = nil end
end

return Audio
