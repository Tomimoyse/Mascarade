-- Transporte de red, por encima de ENet (que LÖVE ya trae de serie).
--
-- Es deliberadamente una capa fina y con una interfaz propia: el día que
-- queramos jugar por internet a través de un relé o de websockets, se escribe
-- otro transporte con estos mismos cuatro métodos y ni las sesiones ni la
-- interfaz se enteran.
--
--   t:update()      -> lista de { type = "connect"|"disconnect"|"message",
--                                 peer = <peer>, data = <cadena> }
--   t:send(texto, peer)   peer nil = a todos
--   t:close()
--   t:peerCount()

local enet = require("enet")

local Transport = {}

Transport.DEFAULT_PORT = 27960
Transport.CHANNELS = 1

---------------------------------------------------------------------------
-- Base común
---------------------------------------------------------------------------

local Base = {}
Base.__index = Base

-- Vacía la cola de ENet y la traduce a nuestros eventos.
function Base:update()
    local out = {}
    if not self.host then return out end

    -- service(0) no bloquea: devuelve lo que haya y vuelve enseguida.
    local ok, event = pcall(self.host.service, self.host, 0)
    while ok and event do
        if event.type == "connect" then
            out[#out + 1] = { type = "connect", peer = event.peer }
        elseif event.type == "disconnect" then
            out[#out + 1] = { type = "disconnect", peer = event.peer }
        elseif event.type == "receive" then
            out[#out + 1] = { type = "message", peer = event.peer, data = event.data }
        end
        ok, event = pcall(self.host.service, self.host, 0)
    end
    if not ok then
        out[#out + 1] = { type = "error", message = tostring(event) }
    end
    return out
end

function Base:send(texto, peer)
    if not self.host then return false end
    local destino = peer or self.peer
    local ok = pcall(function()
        if destino then
            destino:send(texto, 0, "reliable")
        else
            self.host:broadcast(texto, 0, "reliable")
        end
    end)
    return ok
end

function Base:flush()
    if self.host then pcall(self.host.flush, self.host) end
end

function Base:peerCount()
    if not self.host then return 0 end
    local ok, n = pcall(self.host.peer_count, self.host)
    return ok and n or 0
end

function Base:close()
    if not self.host then return end
    if self.peer then pcall(self.peer.disconnect_now, self.peer) end
    pcall(self.host.flush, self.host)
    pcall(self.host.destroy, self.host)
    self.host, self.peer = nil, nil
end

---------------------------------------------------------------------------
-- Anfitrión
---------------------------------------------------------------------------

-- Escucha en todas las interfaces. Devuelve el transporte, o nil + motivo.
function Transport.host(port)
    port = port or Transport.DEFAULT_PORT
    local self = setmetatable({ kind = "host", port = port }, Base)
    -- 4 huecos: de sobra para una partida a dos, con margen para reconexiones.
    local ok, host = pcall(enet.host_create, "*:" .. port, 4, Transport.CHANNELS)
    if not ok or not host then
        return nil, "no se pudo abrir el puerto " .. port .. " (" .. tostring(host) .. ")"
    end
    self.host = host
    return self
end

---------------------------------------------------------------------------
-- Cliente
---------------------------------------------------------------------------

-- 'direccion' puede ser "192.168.1.42" o "192.168.1.42:27960".
function Transport.client(direccion, port)
    port = port or Transport.DEFAULT_PORT
    if not direccion:find(":") then direccion = direccion .. ":" .. port end

    local self = setmetatable({ kind = "client", address = direccion }, Base)
    local ok, host = pcall(enet.host_create)
    if not ok or not host then
        return nil, "no se pudo crear el cliente (" .. tostring(host) .. ")"
    end
    self.host = host

    local okConn, peer = pcall(host.connect, host, direccion, Transport.CHANNELS)
    if not okConn or not peer then
        pcall(host.destroy, host)
        return nil, "direccion invalida: " .. direccion
    end
    self.peer = peer
    return self
end

return Transport
