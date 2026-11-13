-- Vocabulario del protocolo. Un sitio único donde mirar qué se manda.
--
--   cliente -> anfitrion
--     hello   { name }                     me presento
--     action  { a = <accion> }             pido jugar algo
--
--   anfitrion -> cliente
--     welcome { index, hostName }          eres el jugador N
--     state   { snap, events }             foto censurada + lo que ha pasado
--     rejected{ reason }                   tu accion no valia
--     bye     { reason }                   se acabo

local Protocol = {}

Protocol.VERSION = 1

Protocol.HELLO    = "hello"
Protocol.ACTION   = "action"
Protocol.WELCOME  = "welcome"
Protocol.STATE    = "state"
Protocol.REJECTED = "rejected"
Protocol.BYE      = "bye"

return Protocol
