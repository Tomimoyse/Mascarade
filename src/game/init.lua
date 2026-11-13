-- Fachada del módulo de reglas. La interfaz y los tests sólo requieren esto.
--
--   local Game = require("src.game")
--   local m = Game.Match.new({ seed = 7 }):start()

return {
    Match = require("src.game.match"),
    Board = require("src.game.board"),
    Moves = require("src.game.moves"),
    Cards = require("src.game.cards"),
    Rng   = require("src.game.rng"),
}
