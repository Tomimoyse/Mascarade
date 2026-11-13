-- Constantes globales del juego.
-- Este módulo no depende de love.* para poder usarse también desde los tests.

local Config = {}

-- Resolución del canvas interno. Todo el juego se dibuja aquí y luego se
-- escala a la ventana con filtro nearest y escala entera.
Config.CANVAS_W = 640
Config.CANVAS_H = 360

-- Resolución a la que se calcula el bloom (mitad, por rendimiento).
Config.BLOOM_W = 320
Config.BLOOM_H = 180

-- Tablero
Config.BOARD_SIZE = 8          -- 8x8
Config.PIECES_PER_PLAYER = 16

-- Cartas
Config.HAND_LIMIT = 5
Config.INITIAL_HAND = 5

-- Composición del mazo de disfraces (32 cartas en total).
Config.DECK_COMPOSITION = {
    peon    = 16,
    torre   = 4,
    caballo = 4,
    alfil   = 4,
    reina   = 2,
    rey     = 2,
}

-- Máximo de disfraces de cada tipo que se pueden jugar en un mismo turno
-- (número de piezas reglamentarias de ajedrez por bando).
Config.CHAIN_LIMIT_BY_KIND = {
    peon    = 8,
    torre   = 2,
    caballo = 2,
    alfil   = 2,
    reina   = 1,
    rey     = 1,
}

-- Tablas: si pasan tantos turnos seguidos sin ninguna captura, la partida se
-- declara en tablas. 60 turnos son 30 por jugador. El numero sale de medir
-- 300 partidas aleatorias: la primera captura llega en el turno 9 de mediana,
-- pero el percentil 99 esta en el turno 44, asi que por debajo de 60 se
-- cortarian aperturas lentas perfectamente validas.
Config.DRAW_TURNS_WITHOUT_CAPTURE = 60

-- Orden canónico de los tipos de carta (para UI y tests).
Config.KINDS = { "peon", "torre", "caballo", "alfil", "reina", "rey" }

-- Tiempos de animación (segundos). Centralizados para poder ajustar el feel.
Config.T = {
    cardHover   = 0.14,
    cardMove    = 0.28,
    cardFlip    = 0.26,
    pieceMove   = 0.30,
    capturePop  = 0.22,
    beat        = 0.18,  -- pausa corta entre pasos de una resolución
}

return Config
