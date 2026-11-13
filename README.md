# Mascarade

Juego de mesa 1v1 para dos jugadores en el mismo equipo (hotseat), inspirado en
el ajedrez y las damas. Tablero de 8x8 con 32 fichas circulares **sin tipo**: el
movimiento de cada ficha lo decide la **carta de disfraz** que juegas sobre ella.

Hecho con [LÖVE2D](https://love2d.org/) 11.5 y Lua.

> **Estado: juego en red local.** Partida completa en hotseat o contra otra
> persona en la misma red. Lo siguiente es el pulido (animaciones, sonido,
> feedback) y los extras.

---

## Cómo ejecutarlo

Hay dos caminos. El segundo no instala nada en el sistema.

### 1. Con LÖVE instalado

Hace falta LÖVE 11.5.

```bash
sudo pacman -S love          # Arch / Omarchy
sudo apt install love        # Debian / Ubuntu
brew install --cask love     # macOS
```

Y después, desde la raíz del proyecto:

```bash
love .
```

### 2. Con Docker, sin instalar LÖVE

```bash
./docker/run.sh              # juega
./docker/run.sh --test       # pasa la suite de reglas
./docker/run.sh --state game --bot
```

La primera vez construye la imagen (unos segundos); después arranca al
instante. El script acepta los mismos argumentos que `love .`.

Qué hace por dentro: imagen base Arch con LÖVE 11.5, acceso a la GPU por
`/dev/dri`, el socket de Wayland (o X11 como respaldo) y el de PipeWire para el
sonido. El proyecto se monta en sólo lectura, y las opciones y capturas van a
`~/.local/share/mascarade-docker`. Usa `--network host`, que hará falta para el
juego en red local.

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
love . --state game --bot                     # un bot juega solo por la interfaz real
love . --nettest                              # prueba de integración del juego en red
love . --net host / --net 127.0.0.1           # arranca directamente en red
love . --info                                 # diagnóstico de resolución y escalado
love . --size 1600x900                        # fuerza el tamaño de ventana
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

  session/            Frontera entre la interfaz y la partida
    init.lua              Contrato de una sesión
    localsession.lua      Sesión local (hotseat)
    hostsession.lua       Anfitrión: árbitro y reparto censurado
    clientsession.lua     Cliente: sólo tiene la foto
    matchview.lua         Partida reconstruida desde una foto censurada

  net/                Red
    codec.lua             Serialización sin load()
    transport.lua         Capa fina sobre ENet, cambiable
    discovery.lua         Anuncio y búsqueda por broadcast UDP
    redact.lua            Qué parte del estado ve cada jugador
    protocol.lua          Vocabulario de los mensajes

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
    sequencer.lua         Reproduce los eventos de uno en uno, con pausas
  fx/                 Efectos: background, shake, particles, floatingtext
  audio/              Banco de sonidos y síntesis procedural

assets/
  fonts/              Silkscreen y Pixelify Sans (OFL)
  shaders/            background, brightpass, blur, crt (GLSL)

docker/
  Dockerfile          Imagen con LÖVE 11.5 sobre Arch
  run.sh              Lanzador: GPU, Wayland/X11, audio y volumen de guardado

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
- **Caja de diseño de 640x360, canvas elástico.** Toda la interfaz se coloca
  dentro de una caja fija de 640x360. El canvas sobre el que se dibuja, en
  cambio, crece hasta cubrir la ventana entera al mayor factor de escala
  **entero** que permita seguir viendo la caja completa. La caja queda centrada
  y el sobrante lo ocupa el fondo animado.

  Así el juego llena la pantalla sea cual sea su forma — una columna estrecha
  en un gestor con mosaico, una ultrapanorámica, lo que sea — sin barras negras
  y sin renunciar al escalado entero, que es lo que mantiene nítido el pixel
  art. `love . --info` imprime el reparto que ha calculado.
- **No hay imágenes externas.** Fichas, corona y sombras se generan por código
  en el arranque (`src/ui/sprites.lua`). El arte es 100% original.
- **No hay archivos de audio.** Todos los sonidos se sintetizan al arrancar
  (`src/audio/synth.lua`) y se reproducen con variación aleatoria de tono.

---

## Jugar en red local

En el menú, uno crea la partida y el otro se une.

- **Crear partida en red**: abre el puerto 27960, anuncia la partida en la red
  local y espera. La pantalla muestra tu IP por si hace falta dictársela.
- **Unirse a una partida**: busca partidas anunciadas en la red y las lista.
  Si el broadcast no llega (algunas wifis y cortafuegos lo bloquean), siempre
  puedes escribir la IP a mano.

Con Docker funciona igual: `docker/run.sh` ya usa `--network host`.

Para probar las dos puntas en una sola máquina:

```bash
love . --net host          # una terminal
love . --net 127.0.0.1     # otra terminal
```

### Cómo está montado, y por qué así

**El anfitrión es el árbitro.** Tiene la única partida de verdad y valida
todas las acciones contra el motor de reglas, las suyas incluidas. Un cliente
manipulado no puede jugar fuera de turno ni hacer una jugada ilegal.

**Nadie ve la mano del otro.** Después de cada jugada, el anfitrión recorta
una foto distinta del estado para cada jugador: su mano sí, la del rival sólo
como número. Las cartas del rival no salen de la máquina anfitriona, ni
siquiera cifradas: sencillamente no viajan. Su propia interfaz también mira
una foto censurada, así que el anfitrión tampoco tiene ventaja.

**La serialización no usa `load()`.** Lo cómodo sería mandar código Lua y
evaluarlo al recibirlo, pero eso es ejecución de código remoto. `src/net/codec.lua`
es un analizador explícito que sólo sabe construir datos.

**El transporte está detrás de una interfaz.** Hoy es ENet (que LÖVE ya trae).
El día que la partida sea por internet, se escribe otro transporte con los
mismos cuatro métodos y ni las sesiones ni la interfaz se enteran.

```bash
love . --nettest   # levanta anfitrión y cliente de verdad y juega una partida
```

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
