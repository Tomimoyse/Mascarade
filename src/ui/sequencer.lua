-- Secuenciador de eventos.
--
-- El motor resuelve un turno entero de golpe y deja una cola de eventos. Si la
-- interfaz los pintase todos en el mismo frame, el jugador no vería nada: una
-- cadena de tres capturas ocurriría de una vez. Este módulo los reproduce de
-- uno en uno, con una pausa después de cada uno.
--
-- El manejador devuelve, por cada evento:
--   un número   -> segundos a esperar antes del siguiente
--   "block"     -> se detiene hasta que alguien llame a resume()
--   nil / 0     -> continúa inmediatamente con el siguiente

local Object = require("lib.classic")

local Sequencer = Object:extend()

function Sequencer:new(handler)
    self.queue   = {}
    self.wait    = 0
    self.blocked = false
    self.handler = handler
end

function Sequencer:setHandler(fn)
    self.handler = fn
end

function Sequencer:push(events)
    for _, ev in ipairs(events or {}) do
        self.queue[#self.queue + 1] = ev
    end
end

-- ¿Hay algo reproduciéndose? Mientras lo haya, la interfaz bloquea la entrada.
function Sequencer:busy()
    return self.blocked or self.wait > 0 or #self.queue > 0
end

function Sequencer:isBlocked()
    return self.blocked
end

function Sequencer:resume()
    self.blocked = false
end

function Sequencer:clear()
    self.queue   = {}
    self.wait    = 0
    self.blocked = false
end

function Sequencer:update(dt)
    if self.blocked then return end

    if self.wait > 0 then
        self.wait = self.wait - dt
        if self.wait > 0 then return end
        self.wait = 0
    end

    -- Procesamos eventos encadenados hasta que uno pida esperar o bloquear.
    local guard = 0
    while not self.blocked and self.wait <= 0 and guard < 64 do
        local ev = table.remove(self.queue, 1)
        if not ev then return end
        guard = guard + 1
        local r = self.handler and self.handler(ev) or 0
        if r == "block" then
            self.blocked = true
        elseif type(r) == "number" and r > 0 then
            self.wait = r
        end
    end
end

return Sequencer
