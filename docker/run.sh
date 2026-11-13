#!/usr/bin/env bash
# Ejecuta Mascarade dentro de un contenedor, sin instalar LÖVE en el sistema.
#
#   ./docker/run.sh                       juega
#   ./docker/run.sh --test                pasa la suite de reglas
#   ./docker/run.sh --state game --bot    cualquier flag del juego
#
# La primera vez construye la imagen (unos segundos). Las opciones del juego y
# las capturas se guardan en ~/.local/share/mascarade-docker.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGEN="mascarade"
GUARDADO="${HOME}/.local/share/mascarade-docker"

# Construimos la imagen si no existe todavía.
if ! docker image inspect "$IMAGEN" >/dev/null 2>&1; then
    echo ">> Construyendo la imagen $IMAGEN (solo la primera vez)..."
    docker build -t "$IMAGEN" -f "$RAIZ/docker/Dockerfile" "$RAIZ/docker"
fi

mkdir -p "$GUARDADO"

ARGS=(
    --rm --interactive
    --user "$(id -u):$(id -g)"
    --device /dev/dri                      # aceleración por GPU
    --network host                         # necesario para el juego en red local
    -e HOME=/save
    -v "$RAIZ:/game:ro"
    -v "$GUARDADO:/save"
)

# Servidor gráfico: Wayland si lo hay, X11 si no.
if [[ -n "${WAYLAND_DISPLAY:-}" && -S "${XDG_RUNTIME_DIR:-}/${WAYLAND_DISPLAY}" ]]; then
    ARGS+=(
        -e SDL_VIDEODRIVER=wayland
        -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
        -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
        -v "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR"
    )
elif [[ -n "${DISPLAY:-}" ]]; then
    ARGS+=(
        -e SDL_VIDEODRIVER=x11
        -e DISPLAY="$DISPLAY"
        -v /tmp/.X11-unix:/tmp/.X11-unix
    )
    echo ">> Usando X11. Si la ventana no abre, prueba: xhost +local:"
else
    echo "!! No encuentro ni Wayland ni X11." >&2
    exit 1
fi

# Audio por el socket de PipeWire/PulseAudio, si está disponible.
if [[ -S "${XDG_RUNTIME_DIR:-}/pulse/native" ]]; then
    ARGS+=(
        -e SDL_AUDIODRIVER=pulseaudio
        -e PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"
    )
else
    ARGS+=(-e SDL_AUDIODRIVER=dummy)
fi

exec docker run "${ARGS[@]}" "$IMAGEN" /game "$@"
