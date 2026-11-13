-- Opciones del jugador, persistidas en el directorio de guardado de LÖVE
-- (love.filesystem.getSaveDirectory() -> .../mascarade/settings.lua).

local Settings = {}

local FILE = "settings.lua"

local defaults = {
    crt        = true,
    bloom      = true,
    fullscreen = false,
    volume     = 0.7,
    mostrarAyuda = true,
    -- Opción de desarrollo: ver las dos manos a la vez (útil para probar reglas).
    revelarManos = false,
}

Settings.data = {}

-- Serializa una tabla plana de valores simples.
local function serialize(t)
    local out = { "return {" }
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = t[k]
        local lit
        if type(v) == "string" then
            lit = string.format("%q", v)
        else
            lit = tostring(v)
        end
        out[#out + 1] = string.format("  [%q] = %s,", k, lit)
    end
    out[#out + 1] = "}"
    return table.concat(out, "\n")
end

function Settings.load()
    -- Partimos siempre de los valores por defecto.
    for k, v in pairs(defaults) do Settings.data[k] = v end

    local info = love.filesystem.getInfo(FILE)
    if not info then return end

    local contents = love.filesystem.read(FILE)
    if not contents then return end

    local chunk = load(contents, FILE, "t", {})
    if not chunk then return end

    local ok, stored = pcall(chunk)
    if not ok or type(stored) ~= "table" then return end

    -- Sólo aceptamos claves conocidas y del tipo esperado.
    for k, v in pairs(stored) do
        if defaults[k] ~= nil and type(v) == type(defaults[k]) then
            Settings.data[k] = v
        end
    end
end

function Settings.save()
    love.filesystem.write(FILE, serialize(Settings.data))
end

function Settings.get(k)
    return Settings.data[k]
end

function Settings.set(k, v)
    Settings.data[k] = v
    Settings.save()
end

function Settings.toggle(k)
    Settings.set(k, not Settings.data[k])
    return Settings.data[k]
end

return Settings
