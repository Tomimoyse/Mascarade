-- Frontera entre la interfaz y la partida.
--
-- La pantalla de juego NO habla con el motor de reglas directamente: habla con
-- una "sesión". Eso permite que la misma interfaz sirva para una partida local
-- y, más adelante, para una partida en red, donde el motor vive en otra máquina.
--
-- Una sesión expone:
--   session:view()            objeto con la API de consulta del motor
--   session:request(accion)   pide una acción; devuelve ok, motivo
--   session:poll()            eventos nuevos desde la última llamada
--   session:update(dt)
--   session:controls(idx)     ¿este cliente maneja a ese jugador?
--   session:needsHandoff()    ¿hay que ocultar la mano al cambiar de turno?
--   session:status()          "ok" | "waiting" | "disconnected"
--   session:describe(idx)     nombre a mostrar para un jugador
--   session:close()
--
-- En red, view() devolverá una foto censurada del estado (sin la mano del
-- rival) que imita esta misma API, y request() mandará la acción al anfitrión.

return {
    Local = require("src.session.localsession"),
}
