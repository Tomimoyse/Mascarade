# Mascarade

Juego de mesa 1v1 para dos jugadores en el mismo equipo (hotseat), inspirado en
el ajedrez y las damas. Tablero de 8x8 con 32 fichas circulares **sin tipo**: el
movimiento de cada ficha lo decide la **carta de disfraz** que juegas sobre ella.

Hecho con [LÖVE2D](https://love2d.org/) 11.5 y Lua.

> **Estado: Fase 1 (base técnica).** El motor, el escalado, los shaders y los
> efectos están listos. Las reglas del juego llegan en la Fase 2.

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

  game/               Lógica pura de las reglas (Fase 2). Sin love.graphics.
  states/             Pantallas: menu, game, options, rules, pause
  ui/                 Widgets: panel, button, text, layout, sprites, boardview
  fx/                 Efectos: background, shake, particles, floatingtext
  audio/              Banco de sonidos y síntesis procedural

assets/
  fonts/              Silkscreen y Pixelify Sans (OFL)
  shaders/            background, brightpass, blur, crt (GLSL)

locale/es.lua         Todos los textos visibles del juego
tests/                Pruebas de las reglas por consola (Fase 2)
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

## Créditos y licencias

- Tipografías **Silkscreen** y **Pixelify Sans**, licencia SIL Open Font License
  (textos de licencia en `assets/fonts/`).
- Librerías `classic` y `flux` de [rxi](https://github.com/rxi), `hump` de
  [vrld](https://github.com/vrld), todas MIT.
- El resto del código y de los recursos son originales de este proyecto.
