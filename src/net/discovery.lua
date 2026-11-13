-- Descubrimiento de partidas en la red local, por broadcast UDP.
--
-- El anfitrión grita "aquí hay una partida" cada segundo; quien quiera unirse
-- escucha y va montando una lista. Si la red bloquea el broadcast (pasa en
-- algunas wifis públicas y con algunos cortafuegos), siempre queda escribir
-- la IP a mano, así que esto es una comodidad y no un requisito.

local socket = require("socket")

local Discovery = {}

Discovery.PORT    = 27961       -- puerto de anuncios, distinto al del juego
Discovery.MAGIC   = "MASCARADE1"
Discovery.PERIODO = 1.0         -- segundos entre anuncios
Discovery.OLVIDO  = 4.0         -- sin noticias, la partida desaparece

---------------------------------------------------------------------------
-- Anunciante (lo usa el anfitrión)
---------------------------------------------------------------------------

local Announcer = {}
Announcer.__index = Announcer

-- opts = { gamePort, name }
function Discovery.announce(opts)
    opts = opts or {}
    local udp, err = socket.udp()
    if not udp then return nil, tostring(err) end
    udp:settimeout(0)
    local ok, errOpt = udp:setoption("broadcast", true)
    if not ok then
        udp:close()
        return nil, "sin permiso de broadcast: " .. tostring(errOpt)
    end

    return setmetatable({
        udp      = udp,
        gamePort = opts.gamePort or 27960,
        name     = opts.name or "Partida de Mascarade",
        acc      = Discovery.PERIODO,   -- anuncia de inmediato
    }, Announcer)
end

function Announcer:update(dt)
    if not self.udp then return end
    self.acc = self.acc + dt
    if self.acc < Discovery.PERIODO then return end
    self.acc = 0
    -- Formato plano separado por barras: no hace falta nada más.
    local msg = table.concat({ Discovery.MAGIC, self.gamePort, self.name }, "|")
    self.udp:sendto(msg, "255.255.255.255", Discovery.PORT)
end

function Announcer:close()
    if self.udp then self.udp:close(); self.udp = nil end
end

---------------------------------------------------------------------------
-- Buscador (lo usa quien se une)
---------------------------------------------------------------------------

local Browser = {}
Browser.__index = Browser

function Discovery.browse()
    local udp, err = socket.udp()
    if not udp then return nil, tostring(err) end
    udp:settimeout(0)
    -- Varias instancias en la misma máquina tienen que poder escuchar a la vez.
    pcall(function() udp:setoption("reuseaddr", true) end)
    local ok, errBind = udp:setsockname("*", Discovery.PORT)
    if not ok then
        udp:close()
        return nil, "no se pudo escuchar en el puerto " .. Discovery.PORT ..
                    " (" .. tostring(errBind) .. ")"
    end
    return setmetatable({ udp = udp, found = {}, time = 0 }, Browser)
end

function Browser:update(dt)
    if not self.udp then return end
    self.time = self.time + dt

    -- Vaciamos todo lo que haya llegado.
    local guard = 0
    while guard < 64 do
        guard = guard + 1
        local data, ip = self.udp:receivefrom()
        if not data then break end
        local magic, port, name = data:match("^([^|]+)|(%d+)|(.*)$")
        if magic == Discovery.MAGIC and ip then
            local clave = ip .. ":" .. port
            self.found[clave] = {
                ip = ip, port = tonumber(port),
                name = (name ~= "" and name) or ("Partida en " .. ip),
                visto = self.time,
            }
        end
    end

    -- Olvidamos las partidas que han dejado de anunciarse.
    for clave, p in pairs(self.found) do
        if self.time - p.visto > Discovery.OLVIDO then self.found[clave] = nil end
    end
end

-- Lista ordenada por IP, para que no baile en pantalla.
function Browser:list()
    local out = {}
    for _, p in pairs(self.found) do out[#out + 1] = p end
    table.sort(out, function(a, b)
        if a.ip == b.ip then return a.port < b.port end
        return a.ip < b.ip
    end)
    return out
end

function Browser:close()
    if self.udp then self.udp:close(); self.udp = nil end
end

---------------------------------------------------------------------------
-- Utilidad: nuestra IP en la red local, para poder dictarla por teléfono
---------------------------------------------------------------------------

function Discovery.localAddress()
    -- Truco clásico: "conectar" un UDP a una IP externa no manda nada, pero
    -- hace que el sistema elija la interfaz de salida y podamos leerla.
    local udp = socket.udp()
    if not udp then return "?" end
    udp:settimeout(0)
    local ok = pcall(function() udp:setpeername("8.8.8.8", 53) end)
    local ip = "?"
    if ok then
        local dir = udp:getsockname()
        if dir and dir ~= "0.0.0.0" then ip = dir end
    end
    udp:close()
    return ip
end

return Discovery
