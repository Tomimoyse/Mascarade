# Imagen para ejecutar Mascarade sin instalar LÖVE en el sistema.
#
# Base Arch porque es la que trae love 11.5, justo la version del proyecto, y
# porque asi los drivers de Mesa cuadran con los del anfitrion Arch.

FROM archlinux:base

RUN pacman -Sy --noconfirm --needed \
        love \
        mesa \
        libdecor \
        wayland \
        libxkbcommon \
        vulkan-intel vulkan-radeon \
        libpulse \
        ttf-dejavu \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

# El juego se monta en /game al arrancar; el directorio de guardado de LÖVE
# (opciones y capturas) va a /save para que sobreviva entre ejecuciones.
ENV HOME=/save
WORKDIR /game

ENTRYPOINT ["love"]
CMD ["/game"]
