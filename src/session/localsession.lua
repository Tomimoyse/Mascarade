-- Sesión local: el motor de reglas corre en esta misma máquina.
-- Cubre el modo hotseat (dos personas en el mismo ratón).

local Object = require("lib.classic")
local Match  = require("src.game.match")
local L      = require("locale.es")

local LocalSession = Object:extend()

function LocalSession:new(opts)
    opts = opts or {}
    self.match = Match.new({ seed = opts.seed or os.time() })
    self.match:start()
    -- En hotseat la misma persona pasa el ratón, así que hay que tapar la mano
    -- al cambiar de turno.
    self.hotseat = opts.hotseat ~= false
end

function LocalSession:view()
    return self.match
end

function LocalSession:request(action)
    return self.match:apply(action)
end

function LocalSession:poll()
    return self.match:drainEvents()
end

function LocalSession:update(dt) end

-- En local se manejan los dos jugadores desde el mismo sitio.
function LocalSession:controls(_)
    return true
end

-- En hotseat "mi jugador" es siempre el que tiene el turno: la mano que se
-- ve en pantalla es la de quien va a jugar.
function LocalSession:localPlayer()
    return self.match.current
end

function LocalSession:needsHandoff()
    return self.hotseat
end

function LocalSession:status()
    return "ok"
end

function LocalSession:describe(idx)
    return string.format(L.partida.jugador, idx)
end

-- Solo una partida local se puede reiniciar desde aqui; en red haria falta
-- ponerse de acuerdo con el otro jugador.
function LocalSession:canRestart()
    return true
end

function LocalSession:close() end

return LocalSession
