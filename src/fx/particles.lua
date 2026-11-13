-- Sistema de partículas propio: cuadrados de 1-3 px, sin suavizado.
-- Usamos uno hecho a mano en vez de love.graphics.newParticleSystem para
-- tener control total sobre el aspecto pixelado y sobre el pooling.

local Palette = require("src.palette")

local Particles = {}

local MAX = 600
local pool = {}      -- partículas libres reutilizables
local live = {}      -- partículas activas

local function acquire()
    local p = pool[#pool]
    if p then
        pool[#pool] = nil
        return p
    end
    return {}
end

local function release(p)
    if #pool < MAX then pool[#pool + 1] = p end
end

-- Emite un estallido de partículas.
-- opts = { count, speed, spread, angle, gravity, drag, life, size, colors, fade }
function Particles.burst(x, y, opts)
    opts = opts or {}
    local count   = opts.count or 12
    local speed   = opts.speed or 70
    local spread  = opts.spread or math.pi * 2
    local angle   = opts.angle or 0
    local gravity = opts.gravity or 180
    local drag    = opts.drag or 1.8
    local life    = opts.life or 0.5
    local size    = opts.size or 2
    local colors  = opts.colors or { Palette.gold, Palette.white }

    for _ = 1, count do
        if #live >= MAX then break end
        local p = acquire()
        local a = angle + (love.math.random() - 0.5) * spread
        local v = speed * (0.45 + love.math.random() * 0.85)
        p.x, p.y = x, y
        p.vx = math.cos(a) * v
        p.vy = math.sin(a) * v
        p.gravity = gravity
        p.drag = drag
        p.life = life * (0.6 + love.math.random() * 0.8)
        p.maxLife = p.life
        p.size = math.max(1, math.floor(size * (0.6 + love.math.random() * 0.9)))
        p.color = colors[love.math.random(#colors)]
        p.fade = opts.fade ~= false
        live[#live + 1] = p
    end
end

-- Lluvia ascendente de chispas (para coronaciones y momentos épicos).
function Particles.fountain(x, y, opts)
    opts = opts or {}
    opts.angle = -math.pi / 2
    opts.spread = opts.spread or 1.2
    opts.speed = opts.speed or 120
    opts.gravity = opts.gravity or 260
    Particles.burst(x, y, opts)
end

function Particles.update(dt)
    for i = #live, 1, -1 do
        local p = live[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(live, i)
            release(p)
        else
            local d = 1 - p.drag * dt
            if d < 0 then d = 0 end
            p.vx = p.vx * d
            p.vy = p.vy * d + p.gravity * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
end

function Particles.draw()
    for _, p in ipairs(live) do
        local t = p.life / p.maxLife
        local a = p.fade and math.min(t * 1.6, 1) or 1
        local s = p.size
        -- Las partículas se encogen al final de su vida.
        if t < 0.35 then s = math.max(1, s - 1) end
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Particles.count()
    return #live
end

function Particles.clear()
    for i = #live, 1, -1 do
        release(live[i])
        live[i] = nil
    end
end

return Particles
