-- Pruebas de las reglas de Mascarade.
-- Se ejecutan sin LÖVE:   lua tests/run.lua
-- O desde el propio juego: love . --test

package.path = "./?.lua;./?/init.lua;" .. package.path

local Game  = require("src.game")
local H     = require("tests.helpers")
local Match = Game.Match
local Board = Game.Board
local Moves = Game.Moves
local Cards = Game.Cards

---------------------------------------------------------------------------
-- Mini framework
---------------------------------------------------------------------------

local passed, failed, currentName = 0, 0, nil
local failures = {}

local function fail(msg)
    failed = failed + 1
    failures[#failures + 1] = string.format("  %s\n      %s", currentName, msg)
end

local function ok(cond, msg)
    if cond then passed = passed + 1 else fail(msg or "assertion") end
end

local function eq(got, want, msg)
    if got == want then
        passed = passed + 1
    else
        fail(string.format("%s  (esperado %s, obtenido %s)",
            msg or "igualdad", tostring(want), tostring(got)))
    end
end

local function test(name, fn)
    currentName = name
    local okCall, err = pcall(fn)
    if not okCall then fail("ERROR: " .. tostring(err)) end
end

local function section(title)
    io.write("\n", title, "\n")
end

---------------------------------------------------------------------------
section("Mazo y reparto")
---------------------------------------------------------------------------

test("el mazo tiene 32 cartas con la composicion correcta", function()
    local deck = Cards.buildDeck()
    eq(#deck, 32, "total de cartas")
    local count = {}
    for _, c in ipairs(deck) do count[c.kind] = (count[c.kind] or 0) + 1 end
    eq(count.peon, 16, "peones")
    eq(count.torre, 4, "torres")
    eq(count.caballo, 4, "caballos")
    eq(count.alfil, 4, "alfiles")
    eq(count.reina, 2, "reinas")
    eq(count.rey, 2, "reyes")
end)

test("la posicion inicial tiene 16 fichas por jugador en sus dos filas", function()
    local b = Board.newStandard()
    eq(b:countOf(1), 16, "fichas del jugador 1")
    eq(b:countOf(2), 16, "fichas del jugador 2")
    for col = 1, 8 do
        eq(b:at(col, 1).owner, 2, "fila 1 es del jugador 2")
        eq(b:at(col, 2).owner, 2, "fila 2 es del jugador 2")
        eq(b:at(col, 7).owner, 1, "fila 7 es del jugador 1")
        eq(b:at(col, 8).owner, 1, "fila 8 es del jugador 1")
    end
    ok(b:at(4, 4) == nil, "el centro esta vacio")
end)

test("al empezar reparte 5 cartas a cada uno y deja 22 en el mazo", function()
    local m = Match.new({ seed = 99 }):start()
    eq(#m.players[1].hand, 5, "mano del jugador 1")
    eq(#m.players[2].hand, 5, "mano del jugador 2")
    eq(#m.deck, 22, "cartas restantes en el mazo")
    eq(#m.discard, 0, "descarte vacio")
    ok(m.current == 1 or m.current == 2, "hay un jugador activo")
end)

test("la misma semilla produce la misma partida", function()
    local a = Match.new({ seed = 1234 }):start()
    local b = Match.new({ seed = 1234 }):start()
    eq(a.current, b.current, "mismo jugador inicial")
    for i = 1, 5 do
        eq(a.players[1].hand[i].id, b.players[1].hand[i].id, "misma carta " .. i)
    end
end)

---------------------------------------------------------------------------
section("Movimiento de las fichas")
---------------------------------------------------------------------------

test("el peon avanza 1 recto y no come de frente", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 2, col = 4, row = 4, name = "b" },
        },
    })
    local d = Moves.destinations(m.board, p.a, "peon")
    eq(#d, 0, "sin destinos: tiene un rival justo delante")
end)

test("el peon come en diagonal hacia adelante", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 2, col = 5, row = 4, name = "b" },
        },
    })
    local d = Moves.destinations(m.board, p.a, "peon")
    eq(#d, 2, "avance recto + captura diagonal")
    ok(H.hasDest(d, 4, 4), "avanza a 4,4")
    local cap = H.hasDest(d, 5, 4)
    ok(cap and cap.capture, "come en 5,4")
end)

test("el avance doble solo existe si la ficha no se ha movido nunca", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 7, name = "virgen" },
            { owner = 1, col = 6, row = 7, name = "usada", moved = true },
        },
    })
    ok(H.hasDest(Moves.destinations(m.board, p.virgen, "peon"), 4, 5),
        "la ficha virgen puede avanzar 2")
    ok(not H.hasDest(Moves.destinations(m.board, p.usada, "peon"), 6, 5),
        "la ficha ya movida no puede avanzar 2")
end)

test("el avance doble se bloquea si el camino no esta libre", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 7, name = "a" },
            { owner = 2, col = 4, row = 6, name = "estorbo" },
        },
    })
    eq(#Moves.destinations(m.board, p.a, "peon"), 0, "bloqueada del todo")
end)

test("torre, alfil y reina se deslizan y se detienen al chocar", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 4, name = "a", moved = true },
            { owner = 1, col = 4, row = 2, name = "propia" },
            { owner = 2, col = 7, row = 4, name = "rival" },
        },
    })
    local t = Moves.destinations(m.board, p.a, "torre")
    ok(H.hasDest(t, 4, 3), "llega hasta justo antes de la propia")
    ok(not H.hasDest(t, 4, 2), "no captura ficha propia")
    ok(not H.hasDest(t, 4, 1), "no atraviesa la propia")
    local cap = H.hasDest(t, 7, 4)
    ok(cap and cap.capture, "captura a la rival")
    ok(not H.hasDest(t, 8, 4), "no atraviesa a la rival")
    ok(not H.hasDest(Moves.destinations(m.board, p.a, "alfil"), 4, 3),
        "el alfil no se mueve en recto")
    ok(H.hasDest(Moves.destinations(m.board, p.a, "reina"), 4, 3),
        "la reina si se mueve en recto")
    ok(H.hasDest(Moves.destinations(m.board, p.a, "reina"), 6, 6),
        "la reina tambien en diagonal")
end)

test("el caballo salta por encima de las fichas", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 4, name = "a", moved = true },
            { owner = 1, col = 4, row = 3, name = "x" },
            { owner = 1, col = 5, row = 3, name = "y" },
            { owner = 1, col = 5, row = 4, name = "z" },
        },
    })
    ok(H.hasDest(Moves.destinations(m.board, p.a, "caballo"), 5, 2),
        "salta a 5,2 pese a estar rodeado")
end)

---------------------------------------------------------------------------
section("Rey: coronacion e intocabilidad")
---------------------------------------------------------------------------

test("la primera carta de rey corona la ficha", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 5, name = "a", moved = true } },
        hands = { [1] = { "rey" } },
    })
    ok(H.play(m, "rey", p.a, 4, 4), "la jugada es legal")
    ok(p.a.isKing, "la ficha queda coronada")
    eq(m.players[1].kingPieceId, p.a.id, "el jugador registra su rey")
    ok(H.hasEvent(m:drainEvents(), "kingCrowned"), "emite el evento de coronacion")
end)

test("la segunda carta de rey ya no corona a otra ficha", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "rey", king = true, moved = true },
            { owner = 1, col = 1, row = 5, name = "otra", moved = true },
        },
        hands = { [1] = { "rey" } },
    })
    ok(H.play(m, "rey", p.otra, 1, 4), "mueve la otra ficha como rey")
    ok(not p.otra.isKing, "no se corona una segunda ficha")
    eq(m.players[1].kingPieceId, p.rey.id, "el rey sigue siendo el primero")
end)

test("el rey coronado solo se mueve con disfraz de rey", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 4, name = "rey", king = true, moved = true } },
        hands = { [1] = { "torre", "rey" } },
    })
    eq(#Moves.destinations(m.board, p.rey, "torre"), 0, "la torre no lo mueve")
    eq(#Moves.destinations(m.board, p.rey, "reina"), 0, "la reina tampoco")
    ok(#Moves.destinations(m.board, p.rey, "rey") > 0, "el disfraz de rey si")
end)

test("el rey rival es intocable mientras le queden otras fichas", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 2, col = 4, row = 4, name = "reyRival", king = true },
            { owner = 2, col = 1, row = 1, name = "escolta" },
        },
    })
    ok(not H.hasDest(Moves.destinations(m.board, p.a, "torre"), 4, 4),
        "no se puede capturar al rey protegido")
    eq(Moves.captureBlockReason(m.board, p.a, p.reyRival), "reyIntocable",
        "el motivo es la intocabilidad")
end)

test("el rey rival si se puede capturar cuando es su ultima ficha", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 2, col = 4, row = 4, name = "reyRival", king = true },
        },
        hands = { [1] = { "torre" } },
    })
    local cap = H.hasDest(Moves.destinations(m.board, p.a, "torre"), 4, 4)
    ok(cap and cap.capture, "ahora si es capturable")
    ok(H.play(m, "torre", p.a, 4, 4), "la jugada es legal")
    eq(m.phase, "gameover", "la partida termina")
    eq(m.winner, 1, "gana el jugador 1")
    eq(m.result, "capture", "por captura")
end)

---------------------------------------------------------------------------
section("Encadenado de acciones")
---------------------------------------------------------------------------

test("comer concede una accion extra; no comer termina el turno", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 2, col = 4, row = 3, name = "victima" },
            { owner = 2, col = 8, row = 8, name = "escolta" },
        },
        hands = { [1] = { "torre", "alfil" } },
        current = 1,
    })
    ok(H.play(m, "torre", p.a, 4, 3), "come con la torre")
    eq(m.current, 1, "sigue siendo su turno")
    ok(H.hasEvent(m:drainEvents(), "extraAction"), "gana una accion extra")

    ok(H.play(m, "alfil", p.a, 3, 2), "mueve con el alfil sin comer")
    eq(m.current, 2, "el turno pasa al rival")
end)

test("regla 1: no se puede repetir el mismo disfraz seguido", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 2, col = 4, row = 3, name = "v1" },
            { owner = 2, col = 1, row = 3, name = "v2" },
        },
        hands = { [1] = { "torre", "torre" } },
    })
    ok(H.play(m, "torre", p.a, 4, 3), "primera torre: come")
    local okPlay, err = H.play(m, "torre", p.a, 1, 3, 1)
    ok(not okPlay, "la segunda torre seguida es ilegal")
    eq(err, "mismoDisfrazSeguido", "con el motivo correcto")
end)

test("regla 2: tope de disfraces por tipo y turno (1 reina)", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 1, row = 8, name = "a" },
            { owner = 2, col = 1, row = 5, name = "v1" },
            { owner = 2, col = 4, row = 5, name = "v2" },
            { owner = 2, col = 4, row = 2, name = "v3" },
        },
        hands = { [1] = { "reina", "torre", "reina" } },
    })
    ok(H.play(m, "reina", p.a, 1, 5), "primera reina: come")
    ok(H.play(m, "torre", p.a, 4, 5), "torre intercalada: come")
    local okPlay, err = H.play(m, "reina", p.a, 4, 2)
    ok(not okPlay, "la segunda reina del turno es ilegal")
    eq(err, "limiteDeTipo", "por el tope de tipo")
end)

test("regla 3: el encadenado se hace siempre con la misma ficha", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 1, col = 1, row = 5, name = "b", moved = true },
            { owner = 2, col = 4, row = 3, name = "v1" },
            { owner = 2, col = 1, row = 3, name = "v2" },
        },
        hands = { [1] = { "torre", "alfil" } },
    })
    ok(H.play(m, "torre", p.a, 4, 3), "la ficha A come")
    local okPlay, err = m:apply({ type = "playCard",
        cardId = H.card(m, 1, "alfil").id, pieceId = p.b.id, col = 2, row = 4 })
    ok(not okPlay, "no se puede continuar con la ficha B")
    eq(err, "otraFicha", "con el motivo correcto")
    eq(#m:getMovablePieces(H.card(m, 1, "alfil").id), 1,
        "solo se ofrece una ficha movible")
end)

test("excepcion de la linea 30: carta de rey sobre rey coronado + rey gratis", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "rey", king = true, moved = true },
            { owner = 2, col = 4, row = 4, name = "v1" },
            { owner = 2, col = 4, row = 3, name = "v2" },
            { owner = 2, col = 8, row = 8, name = "escolta" },
        },
        hands = { [1] = { "rey" } },
    })
    ok(H.play(m, "rey", p.rey, 4, 4), "la carta de rey mueve al rey y come")
    ok(m.turn.kingComboReady, "la excepcion queda armada")
    ok(m:canFreeKingMove(), "el movimiento gratis del rey es legal pese a las reglas 1 y 2")
    ok(m:apply({ type = "freeKingMove", col = 4, row = 3 }), "se mueve gratis y come")
    eq(m.current, 2, "el movimiento gratis termina el turno aunque coma")
end)

test("sin la excepcion, dos disfraces de rey seguidos son ilegales", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "rey", king = true, moved = true },
            { owner = 1, col = 1, row = 5, name = "otra", moved = true },
            { owner = 2, col = 2, row = 4, name = "v1" },
            { owner = 2, col = 8, row = 8, name = "escolta" },
        },
        hands = { [1] = { "rey" } },
    })
    -- Carta de rey sobre una ficha NO coronada que come: no arma la excepcion.
    ok(H.play(m, "rey", p.otra, 2, 4), "come con una ficha normal disfrazada de rey")
    ok(not m.turn.kingComboReady, "la excepcion no se arma")
    local okFree, reason = m:canFreeKingMove()
    ok(not okFree, "el movimiento gratis del rey queda bloqueado")
    eq(reason, "mismoDisfrazSeguido", "por repetir disfraz")
end)

test("el movimiento gratis del rey esta exento de la regla de la misma ficha", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 1, row = 5, name = "a", moved = true },
            { owner = 1, col = 8, row = 5, name = "rey", king = true, moved = true },
            { owner = 2, col = 1, row = 3, name = "v1" },
            { owner = 2, col = 8, row = 4, name = "v2" },
            { owner = 2, col = 5, row = 1, name = "escolta" },
        },
        hands = { [1] = { "torre" } },
    })
    ok(H.play(m, "torre", p.a, 1, 3), "la ficha A come y encadena")
    eq(m.turn.lockedPieceId, p.a.id, "la ficha A queda bloqueada")
    ok(m:canFreeKingMove(), "aun asi el rey puede moverse gratis")
    ok(m:apply({ type = "freeKingMove", col = 8, row = 4 }), "y lo hace")
    eq(m.current, 2, "termina el turno")
end)

---------------------------------------------------------------------------
section("Promocion")
---------------------------------------------------------------------------

test("llegar a la ultima fila permite cambiar un peon por una no-peon", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 2, name = "a", moved = true } },
        hands = { [1] = { "torre", "peon" } },
        discard = { "peon", "alfil", "reina" },
    })
    ok(H.play(m, "torre", p.a, 4, 1), "la torre llega a la fila 1")
    eq(m.phase, "promotion", "se abre la fase de promocion")
    local reward = m:getPromotionReward()
    eq(reward.kind, "alfil", "la recompensa se salta los peones del descarte")

    ok(m:apply({ type = "promote", cardId = H.card(m, 1, "peon").id }), "promociona")
    eq(#m.players[1].hand, 1, "la mano mantiene su tamano")
    eq(m.players[1].hand[1].kind, "alfil", "ha ganado el alfil")
    eq(m.current, 2, "el turno termina: el movimiento no comio")
end)

test("la promocion no puede recuperar una carta jugada en el turno en curso", function()
    -- La torre jugada este turno sigue en la zona de jugadas, no en el descarte.
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 2, name = "a", moved = true } },
        hands = { [1] = { "torre", "peon" } },
        discard = { "peon", "alfil" },
    })
    ok(H.play(m, "torre", p.a, 4, 1), "llega a la fila 1 con la torre")
    eq(#m:getPlayedThisTurn(), 1, "la torre esta en la zona de jugadas")
    eq(#m.discard, 2, "el descarte no la ha recibido todavia")
    eq(m:getPromotionReward().kind, "alfil", "la recompensa es la del descarte previo")
end)

test("la promocion es opcional", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 2, name = "a", moved = true } },
        hands = { [1] = { "torre", "peon" } },
        discard = { "alfil" },
    })
    ok(H.play(m, "torre", p.a, 4, 1), "llega a la ultima fila")
    ok(m:apply({ type = "skipPromote" }), "se puede renunciar")
    eq(m.players[1].hand[1].kind, "peon", "conserva su peon")
    eq(m.current, 2, "y el turno sigue su curso")
end)

test("moverse dentro de la ultima fila no vuelve a disparar la promocion", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 1, row = 1, name = "a", moved = true } },
        hands = { [1] = { "torre", "peon" } },
        discard = { "alfil" },
    })
    ok(H.play(m, "torre", p.a, 5, 1), "se desliza por la fila 1")
    eq(m.phase, "action", "no se abre la promocion")
    eq(m.current, 2, "el turno simplemente termina")
end)

test("sin cartas no-peon en el descarte no hay promocion", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 2, name = "a", moved = true } },
        hands = { [1] = { "torre", "peon" } },
        discard = { "peon", "peon" },
    })
    ok(H.play(m, "torre", p.a, 4, 1), "llega a la ultima fila")
    eq(m.phase, "action", "la promocion no esta disponible")
end)

test("sin carta de peon en la mano no hay promocion", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 2, name = "a", moved = true } },
        hands = { [1] = { "torre", "alfil" } },
        discard = { "reina" },
    })
    ok(H.play(m, "torre", p.a, 4, 1), "llega a la ultima fila")
    eq(m.phase, "action", "la promocion no esta disponible")
end)

test("la promocion no gasta la accion: se puede seguir encadenando", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 2, name = "a", moved = true },
            { owner = 2, col = 4, row = 1, name = "victima" },
            { owner = 2, col = 8, row = 8, name = "escolta" },
        },
        hands = { [1] = { "torre", "peon" } },
        discard = { "reina" },
    })
    ok(H.play(m, "torre", p.a, 4, 1), "come y llega a la ultima fila")
    eq(m.phase, "promotion", "se abre la promocion")
    ok(m:apply({ type = "promote", cardId = H.card(m, 1, "peon").id }), "promociona")
    eq(m.current, 1, "conserva el turno")
    ok(H.hasEvent(m:drainEvents(), "extraAction"), "y su accion extra")
end)

---------------------------------------------------------------------------
section("Descarte diferido")
---------------------------------------------------------------------------

test("las cartas usadas caen al descarte al cerrar el turno, en orden de uso", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 1, row = 8, name = "a" },
            { owner = 2, col = 1, row = 5, name = "v1" },
            { owner = 2, col = 4, row = 5, name = "v2" },
            { owner = 2, col = 8, row = 8, name = "escolta" },
        },
        hands = { [1] = { "reina", "torre" } },
    })
    ok(H.play(m, "reina", p.a, 1, 5), "juega la reina y come")
    eq(#m.discard, 0, "el descarte sigue vacio")
    eq(#m:getPlayedThisTurn(), 1, "la reina esta en la zona de jugadas")

    ok(H.play(m, "torre", p.a, 4, 5), "juega la torre y come")
    eq(#m.discard, 0, "el descarte sigue vacio")
    eq(#m:getPlayedThisTurn(), 2, "ahora hay dos cartas jugadas")

    ok(m:apply({ type = "endTurn" }), "cierra el turno")
    eq(#m.discard, 2, "las dos cartas caen juntas al descarte")
    eq(m.discard[1].kind, "torre", "la ultima usada queda arriba")
    eq(m.discard[2].kind, "reina", "y la primera debajo")
    eq(#m:getPlayedThisTurn(), 0, "la zona de jugadas queda limpia")
end)

test("un movimiento sin captura tambien vuelca su carta al descarte", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 5, name = "a", moved = true },
                   { owner = 2, col = 1, row = 1, name = "rival" } },
        hands = { [1] = { "torre" } },
    })
    ok(H.play(m, "torre", p.a, 4, 4), "mueve sin comer: el turno termina solo")
    eq(#m.discard, 1, "la carta ya esta en el descarte")
    eq(m.discard[1].kind, "torre", "y es la torre")
end)

---------------------------------------------------------------------------
section("Mazo, robo y carta muerta")
---------------------------------------------------------------------------

test("pasar roba 2 como primera accion y 1 como accion extra", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 2, col = 4, row = 3, name = "v" },
            { owner = 2, col = 8, row = 8, name = "escolta" },
        },
        hands = { [1] = { "torre" } },
        deck = { "peon", "peon", "peon", "peon" },
    })
    eq(m:getEndTurnDrawCount(), 2, "primera accion: 2 cartas")
    ok(H.play(m, "torre", p.a, 4, 3), "come y encadena")
    eq(m:getEndTurnDrawCount(), 1, "accion extra: 1 carta")
    ok(m:apply({ type = "endTurn" }), "pasa")
    eq(#m.players[1].hand, 1, "ha robado 1")
end)

test("un movimiento que no come termina el turno sin robar", function()
    local m, p = H.scenario({
        pieces = { { owner = 1, col = 4, row = 5, name = "a", moved = true } },
        hands = { [1] = { "torre" } },
        deck = { "peon", "peon" },
    })
    ok(H.play(m, "torre", p.a, 4, 4), "mueve sin comer")
    eq(m.current, 2, "turno terminado")
    eq(#m.players[1].hand, 0, "no ha robado nada")
end)

test("el robo respeta el limite de 5 cartas en mano", function()
    local m = H.scenario({
        pieces = { { owner = 1, col = 4, row = 5 }, { owner = 2, col = 1, row = 1 } },
        hands = { [1] = { "peon", "peon", "peon", "peon", "torre" } },
        deck = { "reina", "reina" },
    })
    ok(m:apply({ type = "endTurn" }), "pasa con la mano llena")
    eq(#m.players[1].hand, 5, "la mano sigue en 5")
    eq(#m.deck, 2, "no ha robado nada")
end)

test("el mazo se rebaraja con el descarte al agotarse", function()
    local m = H.scenario({
        pieces = { { owner = 1, col = 4, row = 5 }, { owner = 2, col = 1, row = 1 } },
        hands = { [1] = { "torre" } },
        deck = {},
        discard = { "alfil", "reina", "caballo" },
    })
    ok(m:apply({ type = "endTurn" }), "pasa y necesita robar")
    local evs = m:drainEvents()
    ok(H.hasEvent(evs, "deckReshuffled"), "ha rebarajado el descarte")
    eq(#m.players[1].hand, 3, "ha robado las 2 que podia")
    eq(#m.discard, 0, "el descarte queda vacio")
end)

test("una carta sin ningun movimiento legal no se puede jugar", function()
    -- Peon del jugador 1 en la fila 1: no puede avanzar mas ni comer.
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 1, name = "a", moved = true },
            { owner = 2, col = 8, row = 8, name = "rival" },
        },
        hands = { [1] = { "peon" } },
    })
    local inspect = m:inspectHand()
    eq(inspect[1].ok, false, "la carta aparece como injugable")
    eq(inspect[1].reason, "sinMovimiento", "con el motivo correcto")
    eq(#m:getPlayableCards(), 0, "no hay cartas jugables")
end)

test("la valvula de carta muerta la cambia por otra, una vez por turno", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 1, name = "a", moved = true },
            { owner = 2, col = 8, row = 8, name = "rival" },
        },
        hands = { [1] = { "peon", "peon" } },
        deck = { "reina", "alfil" },
    })
    local dead = m:getDeadCards()
    eq(#dead, 2, "los dos peones estan muertos")

    ok(m:apply({ type = "discardDead", cardId = dead[1].id }), "descarta uno")
    eq(#m.players[1].hand, 2, "la mano mantiene su tamano")
    ok(H.card(m, 1, "reina"), "ha robado la reina")

    local okAgain, err = m:apply({ type = "discardDead", cardId = H.card(m, 1, "peon").id })
    ok(not okAgain, "no se puede usar dos veces en el mismo turno")
    eq(err, "yaUsado", "con el motivo correcto")
end)

test("la valvula rechaza cartas que si tienen movimiento", function()
    local m = H.scenario({
        pieces = { { owner = 1, col = 4, row = 5, moved = true }, { owner = 2, col = 1, row = 1 } },
        hands = { [1] = { "torre" } },
        deck = { "reina" },
    })
    eq(#m:getDeadCards(), 0, "la torre no esta muerta")
    local okCall, err = m:apply({ type = "discardDead", cardId = H.card(m, 1, "torre").id })
    ok(not okCall, "no se puede descartar")
    eq(err, "cartaNoMuerta", "con el motivo correcto")
end)

---------------------------------------------------------------------------
section("Fin de partida")
---------------------------------------------------------------------------

test("tablas tras demasiados turnos sin ninguna captura", function()
    local Config = require("src.config")
    local m = H.scenario({
        pieces = { { owner = 1, col = 4, row = 5 }, { owner = 2, col = 4, row = 1 } },
        hands = { [1] = {}, [2] = {} },
    })
    for _ = 1, Config.DRAW_TURNS_WITHOUT_CAPTURE do
        if m.phase == "gameover" then break end
        m:apply({ type = "endTurn" })
    end
    eq(m.phase, "gameover", "la partida termina")
    eq(m.result, "draw", "en tablas")
    ok(m.winner == nil, "sin ganador")
end)

test("una captura reinicia el contador de tablas", function()
    local m, p = H.scenario({
        pieces = {
            { owner = 1, col = 4, row = 5, name = "a", moved = true },
            { owner = 2, col = 4, row = 3, name = "v" },
            { owner = 2, col = 8, row = 8, name = "escolta" },
        },
        hands = { [1] = { "torre" } },
    })
    m.turnsWithoutCapture = 20
    ok(H.play(m, "torre", p.a, 4, 3), "come")
    ok(m:apply({ type = "endTurn" }), "y pasa")
    eq(m.turnsWithoutCapture, 0, "el contador se reinicia")
end)

---------------------------------------------------------------------------
section("Secuenciador de eventos")
---------------------------------------------------------------------------

test("reproduce los eventos de uno en uno respetando las pausas", function()
    local Sequencer = require("src.ui.sequencer")
    local visto = {}
    local seq = Sequencer(function(ev)
        visto[#visto + 1] = ev.t
        return ev.t == "lento" and 0.5 or 0
    end)

    seq:push({ { t = "rapido" }, { t = "lento" }, { t = "rapido2" } })
    ok(seq:busy(), "arranca ocupado")

    seq:update(0)
    eq(#visto, 2, "procesa hasta el primero que pide esperar")
    eq(visto[2], "lento", "y ese es el lento")

    seq:update(0.2)
    eq(#visto, 2, "durante la pausa no avanza")

    seq:update(0.4)
    eq(#visto, 3, "al vencer la pausa sigue")
    ok(not seq:busy(), "y queda libre")
end)

test("un evento puede bloquear hasta que alguien lo reanuda", function()
    local Sequencer = require("src.ui.sequencer")
    local visto = {}
    local seq = Sequencer(function(ev)
        visto[#visto + 1] = ev.t
        return ev.t == "relevo" and "block" or 0
    end)

    seq:push({ { t = "a" }, { t = "relevo" }, { t = "b" } })
    seq:update(0)
    eq(#visto, 2, "se detiene en el bloqueo")
    ok(seq:isBlocked(), "queda bloqueado")

    seq:update(10)
    eq(#visto, 2, "el tiempo no lo desbloquea")

    seq:resume()
    seq:update(0)
    eq(#visto, 3, "al reanudar continua")
    ok(not seq:busy(), "y termina")
end)

test("clear vacia la cola y desbloquea", function()
    local Sequencer = require("src.ui.sequencer")
    local seq = Sequencer(function() return "block" end)
    seq:push({ { t = "x" }, { t = "y" } })
    seq:update(0)
    seq:clear()
    ok(not seq:busy(), "queda libre")
    ok(not seq:isBlocked(), "y desbloqueado")
end)

---------------------------------------------------------------------------
section("Sesion local")
---------------------------------------------------------------------------

test("la sesion local expone la API que espera la interfaz", function()
    local LocalSession = require("src.session.localsession")
    local s = LocalSession({ seed = 42 })
    local view = s:view()
    ok(view.board ~= nil, "da acceso al tablero")
    eq(#view.players[1].hand, 5, "ha repartido")
    ok(#s:poll() > 0, "entrega los eventos de inicio")
    eq(#s:poll(), 0, "y no los repite")
    ok(s:controls(1) and s:controls(2), "en local maneja a los dos")
    ok(s:needsHandoff(), "en hotseat hace falta relevo")
    eq(s:status(), "ok", "estado correcto")

    local okReq = s:request({ type = "endTurn" })
    ok(okReq, "acepta una accion legal")
    ok(#s:poll() > 0, "y genera eventos")
    s:close()
end)

---------------------------------------------------------------------------
section("Partida completa aleatoria")
---------------------------------------------------------------------------

test("200 partidas aleatorias terminan sin errores ni bloqueos", function()
    local Rng = require("src.game.rng")
    local problems = 0
    local wins, draws = 0, 0

    for seed = 1, 200 do
        local m = Match.new({ seed = seed }):start()
        local rng = Rng.new(seed * 7919)
        local steps = 0

        while m.phase ~= "gameover" and steps < 4000 do
            local actions = m:getLegalActions()
            if #actions == 0 then
                problems = problems + 1
                break
            end
            local a = actions[rng:int(1, #actions)]
            local okApply, err = m:apply(a)
            if not okApply then
                problems = problems + 1
                print(string.format("    semilla %d: accion %s rechazada (%s)",
                    seed, a.type, tostring(err)))
                break
            end
            m:drainEvents()
            steps = steps + 1
        end

        if m.phase == "gameover" then
            if m.winner then wins = wins + 1 else draws = draws + 1 end
        elseif steps >= 4000 then
            problems = problems + 1
        end
    end

    eq(problems, 0, "ninguna partida se bloquea ni rechaza acciones legales")
    print(string.format("    (%d por captura, %d en tablas)", wins, draws))
end)

test("la enumeracion de acciones nunca ofrece una accion ilegal", function()
    local m = Match.new({ seed = 2024 }):start()
    local Rng = require("src.game.rng")
    local rng = Rng.new(31337)
    for _ = 1, 400 do
        if m.phase == "gameover" then break end
        local actions = m:getLegalActions()
        -- Comprobamos que TODAS las acciones ofrecidas son aceptadas por una
        -- copia del estado, no solo la que acabamos elegiendo.
        local chosen = actions[rng:int(1, #actions)]
        local okApply = m:apply(chosen)
        ok(okApply, "la accion " .. chosen.type .. " ofrecida fue rechazada")
        m:drainEvents()
    end
end)

---------------------------------------------------------------------------
-- Resumen
---------------------------------------------------------------------------

print("")
print(string.rep("-", 56))
if failed == 0 then
    print(string.format("OK  %d comprobaciones superadas", passed))
else
    print(string.format("FALLOS  %d de %d comprobaciones", failed, passed + failed))
    print("")
    for _, f in ipairs(failures) do print(f) end
end
print(string.rep("-", 56))

os.exit(failed == 0 and 0 or 1)
