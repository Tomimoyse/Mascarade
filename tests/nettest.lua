-- Prueba de integracion del juego en red.
--
-- Levanta un anfitrion y un cliente de verdad (ENet, sockets, el protocolo
-- entero) dentro del mismo proceso, y juega una partida completa entre los
-- dos. Comprueba sobre todo que la informacion oculta sigue oculta.
--
--   love . --nettest
--
-- Necesita LOVE porque enet solo esta disponible ahi.

local HostSession   = require("src.session.hostsession")
local ClientSession = require("src.session.clientsession")
local Rng           = require("src.game.rng")

local passed, failed = 0, 0
local fallos = {}

local function ok(cond, msg)
    if cond then passed = passed + 1
    else failed = failed + 1; fallos[#fallos + 1] = msg end
end

local function eq(got, want, msg)
    if got == want then passed = passed + 1
    else
        failed = failed + 1
        fallos[#fallos + 1] = string.format("%s (esperado %s, obtenido %s)",
            msg, tostring(want), tostring(got))
    end
end

-- Avanza las dos sesiones unos cuantos ciclos, como haria love.update.
local function bombear(host, client, veces)
    for _ = 1, (veces or 40) do
        host:update(0.016)
        client:update(0.016)
        love.timer.sleep(0.002)
    end
end

-- Busca un valor dentro de una estructura.
local function contiene(t, buscado, visto)
    visto = visto or {}
    if t == buscado then return true end
    if type(t) ~= "table" or visto[t] then return false end
    visto[t] = true
    for k, v in pairs(t) do
        if contiene(k, buscado, visto) or contiene(v, buscado, visto) then return true end
    end
    return false
end

-- Busca una CARTA concreta (pareja id + tipo) dentro de una estructura.
--
-- Hace falta ser asi de preciso: los ids de carta y los de ficha van los dos
-- de 1 a 32, igual que columnas, filas y contadores. Buscar el numero suelto
-- da falsos positivos constantemente; la pareja id+tipo no.
local function contieneCarta(t, carta, visto)
    visto = visto or {}
    if type(t) ~= "table" or visto[t] then return false end
    visto[t] = true
    if t.id == carta.id and t.kind == carta.kind then return true end
    for _, v in pairs(t) do
        if contieneCarta(v, carta, visto) then return true end
    end
    return false
end

local function run()
    print("=== prueba de red: anfitrion + cliente por ENet ===")

    local PUERTO = 27999
    local host = HostSession({ port = PUERTO, seed = 1234,
                               announce = false, name = "Anfitrion" })
    if host:status() == "error" then
        print("  no se pudo abrir el puerto: " .. tostring(host.error))
        return 1
    end

    local client = ClientSession({ address = "127.0.0.1", port = PUERTO,
                                   name = "Cliente" })
    ok(client:status() ~= "error", "el cliente arranca (" .. tostring(client.error) .. ")")

    ---------------------------------------------------------------------
    print("-- conexion")
    bombear(host, client, 120)

    eq(client:status(), "playing", "el cliente entra en la partida")
    eq(client:localPlayer(), 2, "el cliente es el jugador 2")
    eq(host:localPlayer(), 1, "el anfitrion es el jugador 1")
    ok(client:view() ~= nil, "el cliente recibe una foto del estado")
    ok(host:view() ~= nil, "el anfitrion tambien mira una foto")
    eq(host:status(), "playing", "el anfitrion esta jugando")

    local vc, vh = client:view(), host:view()
    eq(vc.board:countOf(1), 16, "el cliente ve las 16 fichas del rival")
    eq(vc.board:countOf(2), 16, "y las suyas")
    eq(#vc.discard, 0, "descarte vacio al empezar")
    eq(#vc.deck, 22, "y 22 cartas en el mazo")

    ---------------------------------------------------------------------
    print("-- informacion oculta")
    local manoAnfitrion = host.match.players[1].hand
    local manoCliente   = host.match.players[2].hand
    eq(#manoAnfitrion, 5, "el anfitrion tiene 5 cartas")
    eq(#manoCliente, 5, "el cliente tiene 5 cartas")

    eq(#vc.players[1].hand, 5, "el cliente cuenta bien las cartas del rival")
    for i, c in ipairs(vc.players[1].hand) do
        eq(c.kind, "?", "la carta " .. i .. " del rival llega tapada")
        ok(c.id < 0, "y con un id de relleno, no uno real")
    end
    for _, c in ipairs(manoAnfitrion) do
        ok(not contieneCarta(vc, c),
            string.format("la carta %s(%d) del anfitrion no llega al cliente", c.kind, c.id))
    end
    for _, c in ipairs(manoCliente) do
        ok(contieneCarta(vc, c),
            string.format("el cliente si ve su propia %s(%d)", c.kind, c.id))
    end

    -- Y al reves: el anfitrion tampoco ve la mano del cliente en SU vista.
    eq(vh.players[2].hand[1].kind, "?", "el anfitrion ve tapada la mano del cliente")
    for _, c in ipairs(manoCliente) do
        ok(not contieneCarta(vh, c),
            string.format("la carta %s(%d) del cliente no esta en la vista del anfitrion",
                c.kind, c.id))
    end

    ---------------------------------------------------------------------
    print("-- nadie puede jugar fuera de su turno")
    local quienEmpieza = host.match.current
    local fuera = (quienEmpieza == 1) and client or host
    local okFuera, motivo = fuera:request({ type = "endTurn" })
    ok(not okFuera, "la sesion que no tiene el turno se niega a enviar")
    eq(motivo, "noEsTuTurno", "con el motivo correcto")

    -- Y aunque un cliente manipulado se saltase esa comprobacion y mandase
    -- la accion igual, el anfitrion la rechaza.
    if quienEmpieza == 1 then
        local Codec    = require("src.net.codec")
        local Protocol = require("src.net.protocol")
        client.transport:send(Codec.encode({
            t = Protocol.ACTION, a = { type = "endTurn" } }))
        local turnoAntes = host.match.turnNumber
        bombear(host, client, 40)
        eq(host.match.turnNumber, turnoAntes,
            "el anfitrion ignora la accion fuera de turno de un cliente manipulado")
        ok(contiene(client:poll(), "rechazada"), "y le contesta que la rechaza")
    end

    ---------------------------------------------------------------------
    print("-- partida completa entre los dos")
    local rng = Rng.new(99)
    local jugadas, guard = 0, 0
    while guard < 4000 do
        guard = guard + 1
        local m = host.match
        if m.phase == "gameover" then break end

        local quien = (m.current == 1) and host or client
        local vista = quien:view()
        if vista then
            local acciones = vista:getLegalActions()
            if #acciones > 0 then
                quien:request(acciones[rng:int(1, #acciones)])
                jugadas = jugadas + 1
            end
        end
        bombear(host, client, 3)
        host:poll(); client:poll()
    end

    print(string.format("   %d jugadas, turno %d, fase %s",
        jugadas, host.match.turnNumber, host.match.phase))
    eq(host.match.phase, "gameover", "la partida termina")
    ok(jugadas > 20, "se han jugado bastantes acciones (" .. jugadas .. ")")

    -- Las dos vistas deben coincidir en todo lo publico.
    bombear(host, client, 30)
    vc, vh = client:view(), host:view()
    eq(vc.board:countOf(1), vh.board:countOf(1), "coinciden las fichas del jugador 1")
    eq(vc.board:countOf(2), vh.board:countOf(2), "coinciden las del jugador 2")
    eq(vc.turnNumber, vh.turnNumber, "coincide el numero de turno")
    eq(tostring(vc.winner), tostring(vh.winner), "coincide el ganador")
    eq(#vc.discard, #vh.discard, "coincide el descarte")

    ---------------------------------------------------------------------
    print("-- desconexion limpia")
    client:close()
    bombear(host, client, 60)
    ok(host:status() == "disconnected" or host.clientPeer == nil,
        "el anfitrion detecta que el rival se fue")
    host:close()

    ---------------------------------------------------------------------
    print("")
    print(string.rep("-", 56))
    if failed == 0 then
        print(string.format("OK  %d comprobaciones de red superadas", passed))
    else
        print(string.format("FALLOS  %d de %d", failed, passed + failed))
        for _, f in ipairs(fallos) do print("  " .. f) end
    end
    print(string.rep("-", 56))
    return failed == 0 and 0 or 1
end

return run
