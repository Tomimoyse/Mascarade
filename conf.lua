-- Configuración de arranque de LÖVE.
-- Se ejecuta antes de que se cree la ventana y antes de main.lua.

function love.conf(t)
    -- Carpeta de guardado (opciones del jugador).
    t.identity = "mascarade"
    t.appendidentity = false

    -- Versión de LÖVE contra la que está hecho el juego.
    t.version = "11.5"
    t.console = false

    t.window.title = "Mascarade"
    t.window.icon = nil

    -- Ventana = canvas interno (640x360) x2. Escala entera exacta a 720p y 1080p.
    t.window.width = 1280
    t.window.height = 720
    t.window.minwidth = 640
    t.window.minheight = 360
    t.window.resizable = true
    t.window.borderless = false
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop"

    t.window.vsync = 1
    t.window.msaa = 0          -- nada de antialiasing: es pixel art
    t.window.depth = false
    t.window.stencil = true
    t.window.usedpiscale = false -- queremos píxeles reales, no escalado por DPI

    -- Módulos que no usamos, desactivados para arrancar más rápido.
    t.modules.physics = false
    t.modules.joystick = false
    t.modules.touch = false
    t.modules.video = false
    t.modules.thread = false
end
