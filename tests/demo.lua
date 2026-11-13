-- Demostración por consola: juega una partida con dos jugadores aleatorios e
-- imprime lo que va pasando. Sirve para ver las reglas funcionando sin interfaz.
--
--   lua tests/demo.lua [semilla] [maxTurnos]

package.path = "./?.lua;./?/init.lua;" .. package.path

local Match = require("src.game.match")
local Rng   = require("src.game.rng")

local seed     = tonumber(arg and arg[1]) or os.time()
local maxTurns = tonumber(arg and arg[2]) or 40

local m   = Match.new({ seed = seed })
local rng = Rng.new(seed + 1)
m:start()

local KIND = { peon = "peon", torre = "torre", caballo = "caballo",
               alfil = "alfil", reina = "reina", rey = "rey" }

-- Traduce un evento a una línea legible.
local function describe(ev)
    if ev.t == "coinFlip" then
        return string.format("Cara o cruz: empieza el jugador %d", ev.winner)
    elseif ev.t == "dealt" then
        return string.format("Reparto: %d y %d cartas", ev.counts[1], ev.counts[2])
    elseif ev.t == "turnStart" then
        return string.format("\n--- Turno %d, jugador %d ---", ev.number, ev.player)
    elseif ev.t == "cardPlayed" then
        return string.format("  J%d juega %s", ev.player, KIND[ev.card.kind])
    elseif ev.t == "freeKingMove" then
        return string.format("  J%d mueve su rey gratis", ev.player)
    elseif ev.t == "pieceMoved" then
        return string.format("    ficha %d: %d,%d -> %d,%d",
            ev.pieceId, ev.fromCol, ev.fromRow, ev.col, ev.row)
    elseif ev.t == "pieceCaptured" then
        return string.format("    COME la ficha %d de J%d en %d,%d%s",
            ev.pieceId, ev.owner, ev.col, ev.row, ev.wasKing and " (!! el REY)" or "")
    elseif ev.t == "kingCrowned" then
        return string.format("    CORONACION: la ficha %d de J%d es ahora rey",
            ev.pieceId, ev.player)
    elseif ev.t == "extraAction" then
        return "    -> gana una accion extra"
    elseif ev.t == "promotionAvailable" then
        return string.format("    promocion disponible (recompensa: %s)",
            ev.reward and KIND[ev.reward.kind] or "?")
    elseif ev.t == "promoted" then
        return string.format("    PROMOCION: descarta %s y recupera %s",
            KIND[ev.discarded.kind], KIND[ev.gained.kind])
    elseif ev.t == "promotionSkipped" then
        return "    renuncia a la promocion"
    elseif ev.t == "deadCardDiscarded" then
        return string.format("    cambia la carta muerta %s por %s",
            KIND[ev.card.kind], ev.gained and KIND[ev.gained.kind] or "nada")
    elseif ev.t == "passed" then
        return string.format("  J%d pasa y roba %d", ev.player, ev.draws)
    elseif ev.t == "drew" then
        if ev.count == 0 then return nil end
        return string.format("    roba %d carta(s)", ev.count)
    elseif ev.t == "playedDiscarded" then
        return string.format("    (%d carta(s) usadas van al descarte)", ev.count)
    elseif ev.t == "deckReshuffled" then
        return string.format("    [mazo rebarajado con %d cartas del descarte]", ev.count)
    elseif ev.t == "gameOver" then
        if ev.winner then
            return string.format("\n*** GANA EL JUGADOR %d (se comio todas las fichas) ***", ev.winner)
        end
        return "\n*** TABLAS (demasiados turnos sin capturas) ***"
    end
    return nil
end

local function flush()
    for _, ev in ipairs(m:drainEvents()) do
        local line = describe(ev)
        if line then print(line) end
    end
end

print(string.format("Mascarade - partida de demostracion (semilla %d)", seed))
flush()

while m.phase ~= "gameover" and m.turnNumber <= maxTurns do
    local actions = m:getLegalActions()
    if #actions == 0 then
        print("  !! sin acciones legales")
        break
    end
    m:apply(actions[rng:int(1, #actions)])
    flush()
end

print("")
print(m:toString())
