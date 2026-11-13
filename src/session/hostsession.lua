-- Sesión de anfitrión: esta máquina tiene la partida de verdad.
--
-- El anfitrión es el árbitro. Valida todas las acciones (las suyas y las del
-- rival) contra el motor de reglas, y después reparte a cada uno una foto
-- CENSURADA del estado. Su propia interfaz también mira una foto censurada:
-- así el anfitrión tampoco puede ver la mano del rival.

local Object    = require("lib.classic")
local Match     = require("src.game.match")
local Codec     = require("src.net.codec")
local Redact    = require("src.net.redact")
local Transport = require("src.net.transport")
local Discovery = require("src.net.discovery")
local Protocol  = require("src.net.protocol")
local MatchView = require("src.session.matchview")
local L         = require("locale.es")

local HostSession = Object:extend()

-- opts = { port, name, seed, announce = true }
function HostSession:new(opts)
    opts = opts or {}
    self.localIndex  = 1
    self.remoteIndex = 2
    self.name        = opts.name or L.red.partidaDe
    self.port        = opts.port or Transport.DEFAULT_PORT
    self.seed        = opts.seed
    self.phase       = "waiting"     -- waiting | playing | ended | error
    self.error       = nil
    self.pending     = {}
    self.clientPeer  = nil
    self.clientName  = nil
    self.localView   = nil

    local t, err = Transport.host(self.port)
    if not t then
        self.phase, self.error = "error", err
        return
    end
    self.transport = t

    if opts.announce ~= false then
        self.announcer = Discovery.announce({ gamePort = self.port, name = self.name })
    end
    self.address = Discovery.localAddress()
end

---------------------------------------------------------------------------
-- Reparto del estado
---------------------------------------------------------------------------

-- Tras cada cambio: rehace la vista local y manda la del rival por la red.
function HostSession:_publish()
    if not self.match then return end
    local events = self.match:drainEvents()

    local snapLocal = Redact.snapshot(self.match, self.localIndex)
    self.localView = MatchView.fromSnapshot(snapLocal, self.localIndex)
    for _, ev in ipairs(Redact.events(events, self.localIndex)) do
        self.pending[#self.pending + 1] = ev
    end

    if self.clientPeer then
        self.transport:send(Codec.encode({
            t      = Protocol.STATE,
            snap   = Redact.snapshot(self.match, self.remoteIndex),
            events = Redact.events(events, self.remoteIndex),
        }), self.clientPeer)
    end
end

function HostSession:_startMatch()
    self.match = Match.new({ seed = self.seed })
    self.match:start()
    self.phase = "playing"
    self:_publish()
end

---------------------------------------------------------------------------
-- Mensajes del cliente
---------------------------------------------------------------------------

function HostSession:_onMessage(peer, raw)
    local msg, err = Codec.decode(raw)
    if type(msg) ~= "table" or not msg.t then
        -- Un paquete que no entendemos no tumba la partida: se ignora.
        return
    end

    if msg.t == Protocol.HELLO then
        if self.clientPeer and self.clientPeer ~= peer then
            self.transport:send(Codec.encode({
                t = Protocol.BYE, reason = "llena" }), peer)
            pcall(peer.disconnect_later, peer)
            return
        end
        self.clientPeer = peer
        self.clientName = type(msg.name) == "string" and msg.name:sub(1, 24) or nil
        self.transport:send(Codec.encode({
            t = Protocol.WELCOME, index = self.remoteIndex,
            hostName = self.name, v = Protocol.VERSION,
        }), peer)
        if not self.match then self:_startMatch() else self:_publish() end

    elseif msg.t == Protocol.ACTION then
        if peer ~= self.clientPeer or not self.match then return end
        -- El rival solo puede actuar en su turno. Esto es lo que impide que
        -- un cliente manipulado juegue por el anfitrion.
        if self.match.current ~= self.remoteIndex then
            self.transport:send(Codec.encode({
                t = Protocol.REJECTED, reason = "noEsTuTurno" }), peer)
            return
        end
        local ok, motivo = self.match:apply(msg.a)
        if not ok then
            self.transport:send(Codec.encode({
                t = Protocol.REJECTED, reason = motivo or "ilegal" }), peer)
            self.match:drainEvents()
            return
        end
        self:_publish()
    end
end

---------------------------------------------------------------------------
-- API de sesión
---------------------------------------------------------------------------

function HostSession:update(dt)
    if self.announcer and self.phase == "waiting" then
        self.announcer:update(dt)
    end
    if not self.transport then return end

    for _, ev in ipairs(self.transport:update()) do
        if ev.type == "connect" then
            -- Esperamos su "hello" antes de darle sitio.
        elseif ev.type == "message" then
            self:_onMessage(ev.peer, ev.data)
        elseif ev.type == "disconnect" then
            if ev.peer == self.clientPeer then
                self.clientPeer = nil
                self.phase = "disconnected"
                self.pending[#self.pending + 1] = { t = "rivalDesconectado" }
            end
        end
    end
end

function HostSession:view()
    return self.localView
end

function HostSession:request(action)
    if not self.match then return false, "sinPartida" end
    if self.match.current ~= self.localIndex then return false, "noEsTuTurno" end
    local ok, err = self.match:apply(action)
    if not ok then
        self.match:drainEvents()
        return false, err
    end
    self:_publish()
    return true
end

function HostSession:poll()
    local out = self.pending
    self.pending = {}
    return out
end

function HostSession:controls(idx)
    return idx == self.localIndex
end

function HostSession:localPlayer()
    return self.localIndex
end

-- En red no hay relevo: cada uno mira su propia pantalla.
function HostSession:needsHandoff()
    return false
end

function HostSession:status()
    return self.phase
end

function HostSession:describe(idx)
    if idx == self.localIndex then return L.red.tu end
    return self.clientName or string.format(L.partida.jugador, idx)
end

-- Solo una partida local se puede reiniciar desde aqui; en red haria falta
-- ponerse de acuerdo con el otro jugador.
function HostSession:canRestart()
    return false
end

function HostSession:close()
    if self.announcer then self.announcer:close(); self.announcer = nil end
    if self.transport then
        if self.clientPeer then
            self.transport:send(Codec.encode({ t = Protocol.BYE, reason = "cerrada" }),
                self.clientPeer)
            self.transport:flush()
        end
        self.transport:close()
        self.transport = nil
    end
end

return HostSession
