-- Serialización de mensajes para la red.
--
-- POR QUÉ NO USAMOS load(): lo cómodo sería serializar a código Lua y
-- deserializar con load(). Eso es ejecución de código remoto: cualquiera que
-- pueda mandarnos un paquete puede ejecutar lo que quiera en nuestra máquina.
-- En una LAN con un amigo "no pasa nada", pero es justo el agujero que no se
-- quiere arrastrar hasta el juego online. Así que aquí hay un codificador y un
-- analizador explícitos, que sólo saben construir datos.
--
-- Formato, con una etiqueta de un byte por valor:
--   z              nil
--   b0 / b1        booleano
--   n<numero>;     número
--   s<bytes>:<...> cadena, con la longitud por delante
--   t<clave><valor>...e   tabla
--
-- Es legible a ojo, lo que ayuda muchísimo a depurar protocolos.

local Codec = {}

Codec.VERSION = 1

---------------------------------------------------------------------------
-- Codificación
---------------------------------------------------------------------------

local encodeValue

local function encodeTable(v, out, depth)
    if depth > 32 then error("tabla demasiado anidada") end
    out[#out + 1] = "t"
    -- Primero la parte de lista, para que el resultado sea estable.
    local n = #v
    for i = 1, n do
        encodeValue(i, out, depth + 1)
        encodeValue(v[i], out, depth + 1)
    end
    -- Después el resto de claves, ordenadas: así dos tablas iguales producen
    -- siempre la misma cadena (útil en los tests).
    local keys = {}
    for k in pairs(v) do
        local esIndice = (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0)
        if not esIndice then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return tostring(a) < tostring(b) end
        return type(a) < type(b)
    end)
    for _, k in ipairs(keys) do
        encodeValue(k, out, depth + 1)
        encodeValue(v[k], out, depth + 1)
    end
    out[#out + 1] = "e"
end

encodeValue = function(v, out, depth)
    local tv = type(v)
    if v == nil then
        out[#out + 1] = "z"
    elseif tv == "boolean" then
        out[#out + 1] = v and "b1" or "b0"
    elseif tv == "number" then
        out[#out + 1] = "n" .. string.format("%.14g", v) .. ";"
    elseif tv == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif tv == "table" then
        encodeTable(v, out, depth)
    else
        error("no se puede serializar un valor de tipo " .. tv)
    end
end

-- Devuelve la cadena, o nil + motivo.
function Codec.encode(value)
    local out = {}
    local ok, err = pcall(encodeValue, value, out, 0)
    if not ok then return nil, tostring(err) end
    return table.concat(out)
end

---------------------------------------------------------------------------
-- Decodificación
---------------------------------------------------------------------------

-- Analizador con cursor. Ante cualquier cosa rara, aborta con error() y
-- Codec.decode lo convierte en nil + motivo. Nunca ejecuta nada.
local function decodeValue(s, i, depth)
    if depth > 32 then error("demasiado anidado") end
    local tag = s:sub(i, i)
    if tag == "" then error("fin de datos inesperado") end

    if tag == "z" then
        return nil, i + 1

    elseif tag == "b" then
        local b = s:sub(i + 1, i + 1)
        if b == "1" then return true, i + 2 end
        if b == "0" then return false, i + 2 end
        error("booleano invalido")

    elseif tag == "n" then
        local fin = s:find(";", i + 1, true)
        if not fin then error("numero sin terminar") end
        local num = tonumber(s:sub(i + 1, fin - 1))
        if not num then error("numero invalido") end
        return num, fin + 1

    elseif tag == "s" then
        local sep = s:find(":", i + 1, true)
        if not sep then error("cadena sin longitud") end
        local len = tonumber(s:sub(i + 1, sep - 1))
        if not len or len < 0 or len % 1 ~= 0 then error("longitud invalida") end
        local desde = sep + 1
        local hasta = desde + len - 1
        if hasta > #s then error("cadena truncada") end
        return s:sub(desde, hasta), hasta + 1

    elseif tag == "t" then
        local t = {}
        local j = i + 1
        local guard = 0
        while true do
            if j > #s then error("tabla sin cerrar") end
            if s:sub(j, j) == "e" then return t, j + 1 end
            guard = guard + 1
            if guard > 100000 then error("tabla demasiado grande") end
            local k, v
            k, j = decodeValue(s, j, depth + 1)
            if k == nil then error("clave nil") end
            v, j = decodeValue(s, j, depth + 1)
            t[k] = v
        end
    end

    error("etiqueta desconocida: " .. tag)
end

-- Devuelve el valor, o nil + motivo.
function Codec.decode(s)
    if type(s) ~= "string" then return nil, "no es una cadena" end
    local ok, value, pos = pcall(decodeValue, s, 1, 0)
    if not ok then return nil, tostring(value) end
    if pos ~= #s + 1 then return nil, "sobran bytes al final" end
    return value
end

return Codec
