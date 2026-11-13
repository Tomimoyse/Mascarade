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
        suTurno       = "SU TURNO",
        terminarTurno = "Terminar turno",
        robaN         = "Terminar turno +%d",
        moverRey      = "Mover rey gratis",
        cambiarMuerta = "Cambiar carta muerta",
        cancelar      = "Cancelar",
        mazo          = "Mazo",
        descarte      = "Descarte",
        mano          = "Mano",
        fichas        = "Fichas",
        rey           = "Rey",
        sinRey        = "sin coronar",
        cadena        = "Cadena del turno",
        jugadas       = "Jugadas este turno",
        ultimo        = "Ultimo: %s",
        bloqueada     = "Ficha fijada: #%d",
        sinCadena     = "Turno sin empezar",
        accionExtra   = "ACCION EXTRA",
        coronacion    = "CORONACION",
        promocion     = "PROMOCION",
        captura       = "CAPTURA",
        tablas        = "TABLAS",
        reyIntocable  = "El rey rival cae el ultimo",
        eligeFicha    = "Elige una ficha",
        eligeDestino  = "Elige el destino",
        eligeMuerta   = "Elige la carta muerta a cambiar",
        promoTitulo   = "Promocion",
        promoTexto    = "Descarta un peon y recupera esta carta del descarte:",
        promoNo       = "No promocionar",
    },

    motivos = {
        mismoDisfrazSeguido = "No puedes repetir disfraz seguido",
        limiteDeTipo        = "Ya has agotado este disfraz este turno",
        sinMovimiento       = "Sin movimientos legales",
        otraFicha           = "Solo puedes mover la ficha fijada",
        fichaAjena          = "No es una ficha tuya",
        destinoIlegal       = "Destino ilegal",
        sinRey              = "Todavia no has coronado",
        cartaNoMuerta       = "Esta carta si tiene movimientos",
        yaUsado             = "Ya has cambiado una carta este turno",
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
        victoria  = "Gana el jugador %d",
        tablas    = "Tablas",
        porCaptura = "Se comio todas las fichas rivales",
        porTablas = "Demasiados turnos sin ninguna captura",
        reiniciar = "Revancha",
        menu      = "Menu principal",
    },

    aviso = {
        faseDemo = "Fase 1: base tecnica",
        faseDemoDesc = "Las reglas llegan en la Fase 2.",
    },
}
