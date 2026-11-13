-- Todos los textos visibles del juego, en un solo sitio.
-- Uso: local L = require("locale.es");  L.menu.jugar

return {
    titulo = "MASCARADE",
    subtitulo = "disfraces sobre un tablero de 8x8",

    menu = {
        jugar    = "Jugar",
        opciones = "Opciones",
        reglas   = "Reglas",
        salir    = "Salir",
    },

    opciones = {
        titulo     = "Opciones",
        crt        = "Filtro CRT",
        bloom      = "Bloom",
        pantalla   = "Pantalla completa",
        volumen    = "Volumen",
        ayuda      = "Mostrar ayudas",
        revelar    = "Revelar ambas manos (debug)",
        volver     = "Volver",
        activado   = "SI",
        desactivado = "NO",
    },

    reglas = {
        titulo = "Reglas",
        volver = "Volver",
    },

    pausa = {
        titulo   = "Pausa",
        seguir   = "Continuar",
        opciones = "Opciones",
        abandonar = "Abandonar partida",
    },

    partida = {
        turnoDe       = "Turno de %s",
        jugador       = "Jugador %d",
        robar2        = "Pasar y robar 2",
        robar1        = "Pasar y robar 1",
        terminarTurno = "Terminar turno",
        moverRey      = "Mover rey (gratis)",
        cancelar      = "Cancelar",
        mazo          = "Mazo",
        descarte      = "Descarte",
        mano          = "Mano",
        fichas        = "Fichas",
        accionExtra   = "ACCION EXTRA",
        coronacion    = "CORONACION",
        promocion     = "PROMOCION",
        captura       = "CAPTURA",
        reyIntocable  = "El rey debe caer al final",
    },

    cartas = {
        peon    = "Peon",
        torre   = "Torre",
        caballo = "Caballo",
        alfil   = "Alfil",
        reina   = "Reina",
        rey     = "Rey",
    },

    cartasDesc = {
        peon    = "Avanza 1 recto. Come 1 en diagonal.",
        torre   = "Se desliza en linea recta.",
        caballo = "Salta en L. No lo bloquean.",
        alfil   = "Se desliza en diagonal.",
        reina   = "Recta y diagonal, sin limite.",
        rey     = "1 casilla en cualquier direccion.",
    },

    fin = {
        victoria = "Gana el %s",
        tablas   = "Tablas",
        reiniciar = "Revancha",
        menu      = "Menu principal",
    },

    aviso = {
        faseDemo = "Fase 1: base tecnica",
        faseDemoDesc = "Las reglas llegan en la Fase 2.",
    },
}
