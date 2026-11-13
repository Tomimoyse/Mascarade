# Mascarade

Juego de mesa 1v1 para dos jugadores en el mismo equipo (hotseat), inspirado en
el ajedrez y las damas. Tablero de 8x8 con 32 fichas circulares **sin tipo**: el
movimiento de cada ficha lo decide la **carta de disfraz** que juegas sobre ella.

Hecho con [LÖVE2D](https://love2d.org/) 11.5 y Lua.

> **Estado: Fase 3 (representación visual).** La partida ya se juega entera con
> el ratón. Falta el ciclo completo con relevo entre jugadores y la resolución
> animada paso a paso (Fase 4), y el pulido (Fase 5).

---

## Cómo ejecutarlo

Hace falta LÖVE 11.5.

```bash
# Arch / Omarchy
sudo pacman -S love

# Debian / Ubuntu
sudo apt install love

# macOS
brew install --cask love
```

Y después, desde la raíz del proyecto:

```bash
love .
```

### Banderas de desarrollo

```bash
love . --state game          # arranca directamente en una pantalla
love . --shot 2.0            # espera 2 s, guarda una captura y sale
love . --state game --shot 3 # combinables
love . --test                # ejecuta la suite de reglas y sale
love . --demo 7 40           # juega una partida por consola (semilla, turnos)
love . --state spritesheet   # hoja con todo el arte generado por código
love . --state game --seed 5 --autoplay 300   # partida simulada, para revisar estados
love . --state game --until promotion         # simula hasta llegar a esa fase
love . --state game --clicks                  # prueba la secuencia de clicks y la informa
```

### Pruebas de las reglas

Las reglas son Lua puro, así que se pueden probar sin LÖVE:

```bash
lua tests/run.lua        # 394 comprobaciones
lua tests/demo.lua 7 40  # partida de demostración por consola
```

Las capturas van al directorio de guardado de LÖVE
(`~/.local/share/love/mascarade/captura.png` en Linux).

---

## Controles

| Tecla / ratón | Acción |
|---|---|
| Ratón | Navegar menús, seleccionar fichas |
| `Esc` / `P` | Pausa (en partida) · volver (en menús) |
| `F1` | Activar/desactivar el filtro CRT |
| `F2` | Activar/desactivar el bloom |
| `F11` | Pantalla completa |
| `Tab` | *(prueba)* cambiar de turno |
| `Espacio` | *(prueba)* efecto de coronación |
| Click en ficha | *(prueba)* efecto de captura |

Las teclas marcadas como *(prueba)* son del banco de pruebas de la Fase 1 y
desaparecerán cuando entre la lógica real.

---

## Estructura del proyecto

```
main.lua              Punto de entrada: pipeline de dibujado y despacho de eventos
conf.lua              Configuración de arranque de LÖVE (ventana, módulos)

lib/                  Librerías de terceros (MIT)
  classic.lua           Clases OOP (rxi)
  flux.lua              Tweens con easing (rxi)
  timer.lua             Temporizadores y corrutinas (hump)
  gamestate.lua         Pila de estados (hump)

src/
  config.lua          Constantes: resolución, mazo, límites de encadenado
  palette.lua         Paleta de colores
  fonts.lua           Carga de tipografías pixel
  settings.lua        Opciones persistidas en disco
  screen.lua          Canvas interno 640x360, escala entera y letterbox
  postfx.lua          Cadena de postprocesado: bloom + CRT

  game/               Lógica pura de las reglas. Sin love.graphics.
    rng.lua               PRNG determinista (Park-Miller)
    cards.lua             Composición del mazo de 32 disfraces
    board.lua             Tablero 8x8 y fichas
    moves.lua             Movimientos legales por tipo de disfraz
    match.lua             Turnos, acciones, encadenado y fin de partida
  states/             Pantallas: menu, game, options, rules, pause
  ui/                 Capa visual, sin reglas dentro
    layout.lua            Reparto del canvas en paneles
    panel.lua             Paneles pixel con chaflán y sombra
    text.lua              Texto con contorno y sombra
    button.lua            Botones con elevación y hundido
    tooltip.lua           Tooltips que siguen al ratón
    sprites.lua           Fichas, corona y glifos de ajedrez por código
    cardview.lua          Cartas: cara, dorso, hueco y volteo
    boardview.lua         Tablero, casillas, resaltados y fichas
  fx/                 Efectos: background, shake, particles, floatingtext
  audio/              Banco de sonidos y síntesis procedural

assets/
  fonts/              Silkscreen y Pixelify Sans (OFL)
  shaders/            background, brightpass, blur, crt (GLSL)

locale/es.lua         Todos los textos visibles del juego
tests/
  run.lua             Suite de pruebas de las reglas
  demo.lua            Partida de demostración por consola
  helpers.lua         Montaje de posiciones concretas para los tests
```

### Decisiones de arquitectura

- **La lógica no sabe dibujar.** Todo lo que vaya en `src/game/` será Lua puro,
  sin una sola llamada a `love.graphics`. Así las reglas se pueden probar por
  consola y una IA futura puede usar exactamente la misma API.
- **La lógica no espera.** `Match` recibe acciones, muta su estado y emite una
  cola de eventos (`pieceMoved`, `pieceCaptured`, `kingCrowned`...). La capa
  visual consume esa cola animándola paso a paso, con pausas.
- **Todo se dibuja en 640x360** y se escala a la ventana con un factor entero y
  filtro `nearest`. Nada de posiciones fraccionarias en la UI.
- **No hay imágenes externas.** Fichas, corona y sombras se generan por código
  en el arranque (`src/ui/sprites.lua`). El arte es 100% original.
- **No hay archivos de audio.** Todos los sonidos se sintetizan al arrancar
  (`src/audio/synth.lua`) y se reproducen con variación aleatoria de tono.

---

## Cómo se juega con el ratón

1. **Click en una carta** de tu mano. Las cartas que no puedes jugar salen en
   gris; al pasar el ratón por encima el tooltip dice por qué.
2. Las **fichas que puede mover esa carta** se marcan con un latido dorado.
   Click en una de ellas. Si sólo hay una posible, se elige sola.
3. Los **destinos legales** aparecen en verde, y en rojo los que capturan.
   Click en uno para jugar.

Click derecho o `ESC` cancela en cualquier punto. Los botones de la derecha
cubren las acciones que no pasan por una carta: terminar el turno, mover el rey
coronado gratis y cambiar una carta muerta.

El panel **Cadena del turno** lleva la cuenta de cuántos disfraces de cada tipo
llevas jugados y cuál no puedes repetir ahora; **Jugadas este turno** muestra las
cartas que aún no han caído al descarte.

## Créditos y licencias

- Tipografías **Silkscreen** y **Pixelify Sans**, licencia SIL Open Font License
  (textos de licencia en `assets/fonts/`).
- Librerías `classic` y `flux` de [rxi](https://github.com/rxi), `hump` de
  [vrld](https://github.com/vrld), todas MIT.
- El resto del código y de los recursos son originales de este proyecto.

---

## Detalle de implementación: el descarte es diferido

Las cartas que juegas **no** van al descarte en el momento. Se quedan a la vista
en una zona de "jugadas este turno" y caen todas juntas al descarte al cerrar el
turno, apiladas en orden de uso (la última usada queda arriba).

Esto importa para la promoción: la carta que acabas de usar para llegar a la
última fila **no** está todavía en el descarte, así que la promoción solo puede
recuperar cartas de turnos anteriores.

## Reglas de la casa

Dos reglas que **no** están en el documento de diseño original y se añadieron
para cerrar huecos. Están marcadas aquí para que queden explícitas:

- **Carta muerta.** Una vez por turno, gratis y sin gastar la acción, puedes
  descartar una carta cuyo disfraz no tenga ningún movimiento legal con ninguna
  de tus fichas, y robar una de reemplazo. Evita quedarte atascado con la mano
  llena de cartas injugables.
- **Tablas.** Si pasan 60 turnos seguidos (30 por jugador) sin ninguna captura,
  la partida se declara en tablas. El número sale de medir 300 partidas
  aleatorias: la primera captura llega en el turno 9 de mediana, pero el
  percentil 99 está en el turno 44. Está en `Config.DRAW_TURNS_WITHOUT_CAPTURE`.
