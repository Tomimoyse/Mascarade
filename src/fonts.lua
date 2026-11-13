-- Carga de tipografías pixel.
--
-- Silkscreen (OFL) está diseñada sobre una rejilla de 8 px: se ve nítida a
-- tamaño 8 y a sus múltiplos. Pixelify Sans (OFL) se usa sólo para títulos.
-- Si algún tamaño se ve borroso, es que no cae en la rejilla de la fuente:
-- ajusta aquí el número y listo.

local Fonts = {}

local PATH_REG   = "assets/fonts/Silkscreen-Regular.ttf"
local PATH_BOLD  = "assets/fonts/Silkscreen-Bold.ttf"
local PATH_TITLE = "assets/fonts/PixelifySans.ttf"

-- Crea una fuente con filtro nearest para que no se interpole al escalar.
local function newPixelFont(path, size)
    local f = love.graphics.newFont(path, size, "mono")
    f:setFilter("nearest", "nearest")
    return f
end

function Fonts.load()
    Fonts.small  = newPixelFont(PATH_REG, 8)    -- texto de UI, tooltips
    Fonts.body   = newPixelFont(PATH_REG, 16)   -- etiquetas normales
    Fonts.bold   = newPixelFont(PATH_BOLD, 8)   -- énfasis pequeño
    Fonts.boldBig = newPixelFont(PATH_BOLD, 16) -- énfasis grande
    Fonts.title  = newPixelFont(PATH_TITLE, 32) -- títulos de pantalla
    Fonts.huge   = newPixelFont(PATH_TITLE, 64) -- logotipo

    Fonts.default = Fonts.small
    love.graphics.setFont(Fonts.default)
end

return Fonts
