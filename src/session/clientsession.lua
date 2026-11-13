-- Sesión de cliente: la partida de verdad está en otra máquina.
--
-- Aquí sólo hay una FOTO censurada del estado, que el anfitrión reenvía tras
-- cada jugada. La mano del rival nunca llega: lo único que se sabe de ella es
-- cuántas cartas tiene.
--
-- Las acciones se mandan al anfitrión, que es quien decide. Como la vista
-- local tiene toda la información pública, la interfaz puede resaltar
-- movimientos legales sin preguntar nada, y en una LAN la respuesta llega
-- antes de que al jugador le dé tiempo a notarlo.

local Object    = require("lib.classic")
local Codec     = require("src.net.codec")
local Transport = require("src.net.transport")
local Protocol  = require("src.net.protocol")
local MatchView = require("src.session.matchview")
local L         = require("locale.es")

local ClientSession = Object:extend()

-- opts = { address, port, name }
function ClientSession:new(opts)
    opts = opts or {}
    self.name     = opts.name or L.red.invitado
    self.myIndex  = nil
    self.hostName = nil
    self.phase    = "connecting"   -- connecting | playing | ended | disconnected | error
    self.error    = nil
    self.pending  = {}
    self.remoteView = nil
    self.timeout  = 0

    local t, err = Transport.client(opts.address or "127.0.0.1", opts.port)
    if not t then
        self.phase, self.error = "error", err
        return
    end
    self.transport = t
end

---------------------------------------------------------------------------
-- Mensajes del anfitrión
---------------------------------------------------------------------------

function ClientSession:_onMessage(raw)
    local msg = Codec.decode(raw)
    if type(msg) ~= "table" or not msg.t then return end

    if msg.t == Protocol.WELCOME then
        self.myIndex  = tonumber(msg.index) or 2
        self.hostName = type(msg.hostName) == "string" and msg.hostName:sub(1, 24) or nil

    elseif msg.t == Protocol.STATE then
        if type(msg.snap) ~= "table" then return end
        self.remoteView = MatchView.fromSnapshot(msg.snap, self.myIndex or 2)
        self.phase = "playing"
        for _, ev in ipairs(msg.events or {}) do
            self.pending[#self.pending + 1] = ev
        end

    elseif msg.t == Protocol.REJECTED then
        -- El anfitrión ha dicho que no. Lo convertimos en un evento para que
        -- la interfaz lo enseñe por el mismo camino que todo lo demás.
        self.pending[#self.pending + 1] =
            { t = "rechazada", reason = tostring(msg.reason or "ilegal") }

    elseif msg.t == Protocol.BYE then
        self.phase = "disconnected"
        self.pending[#self.pending + 1] = { t = "rivalDesconectado" }
    end
end

---------------------------------------------------------------------------
-- API de sesión
---------------------------------------------------------------------------

function ClientSession:update(dt)
    if not self.transport then return end

    if self.phase == "connecting" then
        self.timeout = self.timeout + dt
        if self.timeout > 10 then
            self.phase = "error"
            self.error = L.red.sinRespuesta
            self.transport:close()
            self.transport = nil
            return
        end
    end

    for _, ev in ipairs(self.transport:update()) do
        if ev.type == "connect" then
            self.transport:send(Codec.encode({
                t = Protocol.HELLO, name = self.name, v = Protocol.VERSION }))
        elseif ev.type == "message" then
            self:_onMessage(ev.data)
        elseif ev.type == "disconnect" then
            if self.phase ~= "ended" then
                self.phase = "disconnected"
                self.pending[#self.pending + 1] = { t = "rivalDesconectado" }
            end
        end
    end
end

function ClientSession:view()
    return self.remoteView
end

-- Mandamos la acción y seguimos. Si el anfitrión la rechaza, llegará un
-- evento "rechazada" y la interfaz lo enseñará.
function ClientSession:request(action)
    if not self.transport or self.phase ~= "playing" then
        return false, "sinConexion"
    end
    if not self.remoteView or self.remoteView.current ~= self.myIndex then
        return false, "noEsTuTurno"
    end
    self.transport:send(Codec.encode({ t = Protocol.ACTION, a = action }))
    return true
end

function ClientSession:poll()
    local out = self.pending
    self.pending = {}
    return out
end

function ClientSession:controls(idx)
    return idx == self.myIndex
end

function ClientSession:localPlayer()
    return self.myIndex or 2
end

function ClientSession:needsHandoff()
    return false
end

function ClientSession:status()
    return self.phase
end

function ClientSession:describe(idx)
    if idx == self.myIndex then return L.red.tu end
    return self.hostName or string.format(L.partida.jugador, idx)
end

-- Solo una partida local se puede reiniciar desde aqui; en red haria falta
-- ponerse de acuerdo con el otro jugador.
function ClientSession:canRestart()
    return false
end

function ClientSession:close()
    if self.transport then
        self.transport:close()
        self.transport = nil
    end
end

return ClientSession
