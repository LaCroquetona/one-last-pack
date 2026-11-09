-- Carpetas propias: de pie en la estanteria de albumes, con 9 bolsillos por
-- pagina. Se arrastra la carta que quieras de abajo a cualquier bolsillo (va
-- la mejor copia libre); tocando un bolsillo sale INSPECCIONAR para cambiar
-- la copia o sacarla. Las copias de una carpeta no se venden.
local p = require "datos.paleta"
local sobres = require "datos.sobres"
local rarezas = require "datos.rarezas"
local partida = require "src.partida"
local mercado = require "src.mercado"
local carta = require "src.carta"
local fuentes = require "src.fuentes"
local muebles = require "src.muebles"
local ui = require "src.ui"
local sonido = require "src.sonido"
local fx = require "src.fx"
local inspeccionar = require "src.inspeccionar"
local utf8 = require "utf8"

local lg = love.graphics
local carpeta = {}

local CW, CH = carta.ANCHO, carta.ALTO
local PAPEL = { 0.92, 0.9, 0.86 }
local X, Y = 138, 28                         -- la carpeta abierta
local DX = 458                               -- columna de la derecha
local B = { x = 132, y = 234, w = 502, h = 120 } -- tu coleccion
local POR_BANDEJA = 11
local NOMBRES = { "FAVORITAS", "MIS JOYAS", "HOLOS", "FULL ARTS", "SECRETAS", "CHASE", "1ª EDICIÓN", "PARA EL DIRECTO",
    "PARA CAMBIAR", "MI COLECCIÓN", "TOP 9", "BICHOS", "LAS RARAS", "PARA ENSEÑAR" }

local abierta      -- id de la carpeta abierta (nil: estanteria)
local pliego = 1   -- paginas 2p-1 y 2p
local bandeja = { pagina = 1, set = 0, rareza = 0, sin = false }
local editando     -- nombre mientras se escribe

function carpeta.colores(k)
    local t = sobres.lista[((k.tapa or 1) - 1) % #sobres.lista + 1]
    return t.colores
end

function carpeta.abierta() return abierta end

function carpeta.abrir(cid)
    abierta = cid
    pliego = 1
    bandeja.pagina = 1
    sonido.tocar("giro")
end

function carpeta.cerrar()
    carpeta.acabarNombre()
    abierta = nil
end

function carpeta.reiniciar()
    abierta, editando = nil, nil
end

-- de pie en la balda (mismo tamaño que un album): tapa, nombre de lado y cuantas lleva
function carpeta.lomo(k, x, y)
    local A = muebles.ALBUM
    -- el album ESPECIALES: negro con filo dorado
    local C = k.especial and { base = p.negro, borde = muebles.ORO.oro, rayas = muebles.ORO.oro, letras = p.amarillo } or carpeta.colores(k)
    local w, h, d = A.w, A.h, A.d
    muebles.bloque(x, y, w, h, d, { C.base, PAPEL, { C.base[1] * 0.6, C.base[2] * 0.6, C.base[3] * 0.6 } })
    muebles.rect(C.borde, x, y, 4, h)
    for i = 0, 2 do muebles.rect(p.grisclaro, x + 1, y + 16 + i * 32, 2, 5) end
    for yy = 0, h - 1, 9 do muebles.rect(C.rayas, x + 4, y + yy, w - 4, 2, 0.3) end
    -- la etiqueta con el nombre, de abajo arriba
    muebles.rect(PAPEL, x + 9, y + 6, 14, h - 26)
    muebles.rect(C.borde, x + 9, y + 6, 14, 1)
    lg.push()
    lg.translate(x + 13, y + h - 21)
    lg.rotate(-math.pi / 2)
    fuentes.texto(k.nombre, 0, 0, 1, p.negro, "center", h - 26)
    lg.pop()
    local n = k.cuenta or partida.cuentaCarpeta(k)
    fuentes.texto(n .. "", x + 2, y + h - 12, 1, C.letras, "center", w - 2)
    lg.setColor(1, 1, 1)
end

-- el sitio vacio para una nueva
function carpeta.hueco(x, y, encima)
    local A = muebles.ALBUM
    lg.setColor(encima and p.lima or p.gris)
    for i = 0, A.h - 1, 3 do
        lg.rectangle("fill", x, y + i, 1, 1)
        lg.rectangle("fill", x + A.w - 1, y + i, 1, 1)
    end
    for i = 0, A.w - 1, 3 do
        lg.rectangle("fill", x + i, y, 1, 1)
        lg.rectangle("fill", x + i, y + A.h - 1, 1, 1)
    end
    fuentes.texto("+", x, y + 30, 2, encima and p.lima or p.grisclaro, "center", A.w)
    lg.push()
    lg.translate(x + 13, y + A.h - 12)
    lg.rotate(-math.pi / 2)
    fuentes.texto("NUEVA CARPETA", 0, 0, 1, encima and p.lima or p.grisclaro, "center", A.h - 50)
    lg.pop()
    lg.setColor(1, 1, 1)
end

-- las cartas de abajo, con los filtros
local function listaBandeja()
    local salidos = mercado.setsSalidos()
    local set = bandeja.set > 0 and salidos[bandeja.set] and salidos[bandeja.set].id or nil
    local enAlguna = {}
    if bandeja.sin then
        for _, k in ipairs(partida.carpetas) do
            for _, b in pairs(k.b) do enAlguna[b.id] = true end
        end
    end
    local lista = {}
    for id, l in pairs(partida.inv) do
        local def = partida.carta(id)
        if def and #l > 0 and (not set or def.set == set) and rarezas.de(def).nivel >= bandeja.rareza and not enAlguna[id] then
            table.insert(lista, def)
        end
    end
    table.sort(lista, function(a, b) return a.id < b.id end)
    return lista
end

local function pintarBolsillo(k, slot, bx, by, encima)
    lg.setColor(p.grisclaro[1], p.grisclaro[2], p.grisclaro[3], 0.35)
    lg.rectangle("fill", bx, by, 42, 56)
    lg.setColor(p.gris[1], p.gris[2], p.gris[3], 0.5)
    lg.rectangle("line", bx + 0.5, by + 0.5, 41, 55)
    local b = k.b[slot]
    local cogida = ui.arrastrando()
    if b and cogida ~= "kb" .. slot then
        local c = partida.copia(b.id, b.u)
        local def = partida.carta(b.id)
        if c and def then
            local h = ui.hoverCarta("kb" .. slot, bx + 21, by + 28, CW, CH)
            carta.dibujar(def, bx + 21, by + 28, 1, 1, 0, true, h, c.f, { primera = c.p, top = c.t, quieta = h == nil })
            lg.setColor(1, 1, 1, 0.06)
            lg.rectangle("fill", bx + 1, by + 1, 40, 54)
        end
    end
    if encima then
        lg.setColor(p.lima)
        lg.rectangle("line", bx - 0.5, by - 0.5, 43, 57)
    end
    ui.zona("kb" .. slot, bx, by, 42, 56)
end

local function pagina(k, num, x, y)
    lg.setColor(PAPEL)
    lg.rectangle("fill", x, y, 140, 180)
    local cogida = ui.arrastrando()
    for i = 0, 8 do
        local c, f = i % 3, math.floor(i / 3)
        local bx, by = x + 4 + c * 44, y + 4 + f * 58
        local slot = (num - 1) * 9 + i + 1
        local encima = cogida and cogida:match("^k") and ui.mx >= bx and ui.mx < bx + 42 and ui.my >= by and ui.my < by + 56
        pintarBolsillo(k, slot, bx, by, encima)
    end
    fuentes.texto(num .. "", x, y + 172, 1, p.gris, "center", 140)
end

local function boton(id, texto, x, y, w, h, color, activo)
    ui.boton(id, texto, x, y, w, h, color, activo)
end

local function pintarTapaCerrada(k, x, y, w, h)
    local C = carpeta.colores(k)
    lg.setColor(0, 0, 0, 0.4)
    lg.rectangle("fill", x + 2, y + 3, w, h)
    muebles.rect(C.borde, x, y, w, h)
    muebles.rect(C.base, x + 4, y + 2, w - 6, h - 4)
    for yy = 0, h - 5, 7 do muebles.rect(C.rayas, x + 4, y + 2 + yy, w - 6, 2, 0.35) end
    muebles.rect(C.borde, x, y, 4, h)
    for i = 0, 2 do muebles.rect(p.grisclaro, x + 1, y + 14 + i * math.floor((h - 28) / 2), 2, 4) end
    local ew = w - 12
    muebles.rect(PAPEL, x + 8, y + h / 2 - 8, ew, 16)
    lg.setColor(C.borde)
    lg.rectangle("line", x + 8.5, y + h / 2 - 7.5, ew - 1, 15)
    fuentes.texto(k.nombre, x + 8, y + h / 2 - 3, 1, p.negro, "center", ew)
end

-- la carpeta abierta (arriba), su tapa y nombre (derecha) y tu coleccion (abajo)
function carpeta.dibujar()
    local k = partida.carpeta(abierta)
    if not k then
        abierta = nil
        return
    end
    local C = carpeta.colores(k)
    local paginas = partida.paginasCarpeta(k)
    pliego = math.max(1, math.min(pliego, paginas / 2))
    lg.setColor(0, 0, 0, 0.4)
    lg.rectangle("fill", X + 3, Y + 4, 308, 198)
    muebles.rect(C.borde, X, Y, 308, 198)
    muebles.rect(C.base, X + 2, Y + 2, 304, 194)
    pagina(k, pliego * 2 - 1, X + 6, Y + 6)
    pagina(k, pliego * 2, X + 162, Y + 6)
    for r = 0, 5 do
        muebles.rect(p.grisclaro, X + 150, Y + 18 + r * 30, 8, 4)
        muebles.rect(p.blanco, X + 151, Y + 18 + r * 30, 6, 1)
    end
    fuentes.texto(k.nombre, X, Y + 189, 1, C.letras, "center", 308)

    -- derecha: la tapa, el nombre y como va
    fuentes.texto("TU CARPETA", DX, Y + 2, 1, p.lima, "center", 176)
    pintarTapaCerrada(k, DX + 58, Y + 14, 60, 84)
    fuentes.texto("TAPA", DX + 8, Y + 112, 1, p.grisclaro)
    boton("kp_tapa_-1", "<", DX + 60, Y + 109, 14, 12, p.azul)
    muebles.rect(C.borde, DX + 80, Y + 109, 40, 12)
    muebles.rect(C.base, DX + 82, Y + 111, 36, 8)
    boton("kp_tapa_1", ">", DX + 126, Y + 109, 14, 12, p.azul)
    fuentes.texto("NOMBRE", DX + 8, Y + 130, 1, p.grisclaro)
    boton("kp_nombre_-1", "<", DX + 60, Y + 127, 14, 12, p.azul, not editando)
    boton("kp_nombre_1", ">", DX + 126, Y + 127, 14, 12, p.azul, not editando)
    if editando then
        local cursor = math.floor(love.timer.getTime() * 2) % 2 == 0 and "_" or ""
        ui.caja(DX + 8, Y + 143, 120, 13, p.azulosc)
        fuentes.texto(editando .. cursor, DX + 12, Y + 147, 1, p.cian)
        boton("kp_nombreok", "OK", DX + 132, Y + 143, 36, 13, p.verde)
    else
        boton("kp_escribir", "ESCRIBIR NOMBRE...", DX + 8, Y + 143, 160, 13, p.grisosc)
    end
    fuentes.texto("TOCA UNA CARTA: INSPECCIONAR", DX, Y + 166, 1, p.gris, "center", 176)
    fuentes.texto("(CAMBIAR LA COPIA O SACARLA)", DX, Y + 176, 1, p.gris, "center", 176)
    fuentes.texto("ARRÁSTRALA FUERA: AL ARMARIO", DX, Y + 186, 1, p.gris, "center", 176)

    -- abajo: tu coleccion para arrastrar
    lg.setColor(0, 0, 0, 0.45)
    lg.rectangle("fill", B.x, B.y - 4, B.w, 4)
    ui.caja(B.x, B.y, B.w, B.h, p.negro)
    ui.zona("kp_bandeja", B.x, B.y, B.w, B.h)
    fuentes.texto("TU COLECCIÓN", B.x + 8, B.y + 6, 1, p.grisclaro)
    local salidos = mercado.setsSalidos()
    local fx0 = B.x + 76
    local setTxt = bandeja.set > 0 and salidos[bandeja.set] and ("SET: " .. salidos[bandeja.set].codigo) or "SET: TODOS"
    local rz
    for _, r in ipairs(rarezas.lista) do if r.nivel == bandeja.rareza then rz = r end end
    local rarTxt = bandeja.rareza > 0 and rz and (rz.nombre:upper() .. "+") or "RAREZA: TODAS"
    for _, f in ipairs({ { "kp_fset", setTxt, bandeja.set > 0 }, { "kp_frar", rarTxt, bandeja.rareza > 0 },
        { "kp_fsin", "SIN CARPETA", bandeja.sin } }) do
        local w = fuentes.ancho(f[2]) + 10
        boton(f[1], f[2], fx0, B.y + 3, w, 11, f[3] and p.azul or p.grisosc)
        fx0 = fx0 + w + 3
    end
    local lista = listaBandeja()
    local paginasB = math.max(1, math.ceil(#lista / POR_BANDEJA))
    bandeja.pagina = math.max(1, math.min(bandeja.pagina, paginasB))
    fuentes.texto(bandeja.pagina .. "/" .. paginasB, B.x, B.y + 6, 1, p.grisclaro, "right", B.w - 8)
    local cogida = ui.arrastrando()
    for i = 1, POR_BANDEJA do
        local def = lista[(bandeja.pagina - 1) * POR_BANDEJA + i]
        if def then
            local cx, cy = B.x + 32 + (i - 1) * 44, B.y + 58
            local libres = partida.libresCarpeta(def.id)
            local c = partida.mejorLibre(def.id) or partida.lista(def.id)[1]
            if cogida == "kc" .. def.id then
                carta.hueco(def, cx, cy, 1)
            else
                local h = libres > 0 and ui.hoverCarta("kc" .. def.id, cx, cy, CW, CH) or nil
                carta.dibujar(def, cx, cy, 1, 1, 0, true, h, c.f, { primera = c.p, top = c.t, quieta = h == nil })
                if libres == 0 then
                    lg.setColor(0, 0, 0, 0.55)
                    lg.rectangle("fill", cx - CW / 2, cy - CH / 2, CW, CH)
                    fuentes.texto("EN USO", cx - CW / 2, cy - 2, 1, p.gris, "center", CW)
                end
            end
            carta.contador(libres, cx + CW / 2, cy + CH / 2)
            ui.zona("kc" .. def.id, cx - CW / 2, cy - CH / 2, CW, CH)
            if ui.encima == "kc" .. def.id and not cogida then
                ui.tooltip(rarezas.nombre(def), rarezas.de(def).color, {
                    { libres .. (libres == 1 and " COPIA LIBRE" or " COPIAS LIBRES") },
                    { "Arrástrala a un bolsillo", p.gris },
                })
            end
        end
    end
    if #lista == 0 then
        fuentes.texto("NO HAY CARTAS CON ESTOS FILTROS", B.x, B.y + 56, 1, p.gris, "center", B.w)
    end
    boton("kp_bant", "<", B.x + 2, B.y + 48, 8, 20, p.azul, bandeja.pagina > 1)
    boton("kp_bsig", ">", B.x + B.w - 10, B.y + 48, 8, 20, p.azul, bandeja.pagina < paginasB)
    fuentes.texto("ARRASTRA UNA A UN BOLSILLO: VA LA MEJOR COPIA LIBRE (1ª ED, CON FUNDA)", B.x + 8, B.y + 96, 1, p.gris)
    fuentes.texto("LAS DE UNA CARPETA NO SE VENDEN NI VAN EN EL LOTE", B.x + 8, B.y + 106, 1, p.gris)
end

-- panel de la izquierda (en el sitio del del album)
function carpeta.panel()
    local k = partida.carpeta(abierta)
    if not k then return end
    ui.boton("kp_cerrar", "< A LA ESTANTERÍA", 6, 84, 118, 12, p.morado)
    ui.caja(6, 98, 118, 194)
    local paginas = partida.paginasCarpeta(k)
    fuentes.texto("PÁGINAS " .. (pliego * 2 - 1) .. "-" .. (pliego * 2) .. " DE " .. paginas, 6, 106, 1, p.blanco, "center", 118)
    ui.boton("kp_pant", "<", 12, 118, 50, 14, p.azul, pliego > 1)
    ui.boton("kp_psig", ">", 68, 118, 50, 14, p.azul, pliego < paginas / 2)
    -- lo que lleva, por rareza
    local porNivel, n, p1, fu, valor = {}, 0, 0, 0, 0
    for _, b in pairs(k.b) do
        local c, def = partida.copia(b.id, b.u), partida.carta(b.id)
        if c and def then
            n = n + 1
            local r = rarezas.de(def)
            porNivel[r.id] = (porNivel[r.id] or 0) + 1
            if c.p then p1 = p1 + 1 end
            if c.f then fu = fu + 1 end
            valor = valor + mercado.valor(b.id, c.p)
        end
    end
    local y = 142
    for i = #rarezas.lista, 1, -1 do
        local r = rarezas.lista[i]
        if porNivel[r.id] then
            fuentes.texto(r.nombre, 14, y, 1, r.color)
            fuentes.texto(porNivel[r.id] .. "", 14, y, 1, p.blanco, "right", 98)
            y = y + 10
        end
    end
    y = math.max(y + 6, 200)
    fuentes.texto("CARTAS", 14, y, 1, p.blanco)
    fuentes.texto(n .. "/" .. paginas * 9, 14, y, 1, p.blanco, "right", 98)
    fuentes.texto("DE 1ª ED", 14, y + 10, 1, p.amarillo)
    fuentes.texto(p1 .. "", 14, y + 10, 1, p.blanco, "right", 98)
    fuentes.texto("EN FUNDA", 14, y + 20, 1, p.cian)
    fuentes.texto(fu .. "", 14, y + 20, 1, p.blanco, "right", 98)
    fuentes.texto("VALOR", 14, y + 34, 1, p.blanco)
    fuentes.texto(ui.dinero(valor), 14, y + 34, 1, p.amarillo, "right", 98)
    ui.boton("kp_borrar", "BORRAR CARPETA", 12, 272, 106, 12, p.rojo)
end

function carpeta.acabarNombre()
    if not editando then return end
    local k = partida.carpeta(abierta)
    local nombre = editando:gsub("^%s+", ""):gsub("%s+$", "")
    if k and nombre ~= "" then k.nombre = nombre end
    editando = nil
    love.keyboard.setTextInput(false)
    partida.guardar()
end

function carpeta.texto(t)
    if not editando then return false end
    for _, cp in utf8.codes(t) do
        local c = utf8.char(cp):upper()
        if c == "ñ" then c = "Ñ" end
        if utf8.len(editando) < partida.NOMBRE_CARPETA and (c:match("^[%u%d ]$") or c == "Ñ") then editando = editando .. c end
    end
    return true
end

function carpeta.tecla(tecla)
    if not editando then return false end
    if tecla == "backspace" then
        local n = utf8.offset(editando, -1)
        if n then editando = editando:sub(1, n - 1) end
    elseif tecla == "return" or tecla == "kpenter" or tecla == "escape" then
        carpeta.acabarNombre()
    end
    return true
end

local function abrirBolsillo(slot)
    local k = partida.carpeta(abierta)
    local b = k and k.b[slot]
    if b then inspeccionar.abrir(b.id, b.u, { carpeta = { cid = k.id, slot = slot } }) end
end

-- true si era suyo
function carpeta.click(id)
    if not abierta then return false end
    local k = partida.carpeta(abierta)
    if not k then return false end
    local slot = tonumber(id:match("^kb(%d+)$") or "")
    if slot then
        abrirBolsillo(slot)
        return true
    end
    if id:match("^kc%d") then return true end
    if not id:match("^kp_") then return false end
    local d = tonumber(id:match("^kp_tapa_(%-?1)$") or "")
    if d then
        k.tapa = ((k.tapa or 1) - 1 + d) % #sobres.lista + 1
        partida.guardar()
        return true
    end
    d = tonumber(id:match("^kp_nombre_(%-?1)$") or "")
    if d then
        local pos = 0
        for i, n in ipairs(NOMBRES) do if n == k.nombre then pos = i end end
        k.nombre = NOMBRES[(pos - 1 + d) % #NOMBRES + 1]
        partida.guardar()
    elseif id == "kp_escribir" then
        editando = ""
        love.keyboard.setTextInput(true)
    elseif id == "kp_nombreok" then
        carpeta.acabarNombre()
    elseif id == "kp_cerrar" then
        carpeta.cerrar()
    elseif id == "kp_pant" or id == "kp_psig" then
        pliego = pliego + (id == "kp_psig" and 1 or -1)
        sonido.tocar("giro")
    elseif id == "kp_bant" or id == "kp_bsig" then
        bandeja.pagina = bandeja.pagina + (id == "kp_bsig" and 1 or -1)
    elseif id == "kp_fset" then
        bandeja.set = (bandeja.set + 1) % (#mercado.setsSalidos() + 1)
        bandeja.pagina = 1
    elseif id == "kp_frar" then
        -- todas, y luego de rara para arriba
        local niveles = { 0 }
        for _, r in ipairs(rarezas.lista) do
            if r.nivel >= 3 then table.insert(niveles, r.nivel) end
        end
        local pos = 1
        for i, n in ipairs(niveles) do if n == bandeja.rareza then pos = i end end
        bandeja.rareza = niveles[pos % #niveles + 1]
        bandeja.pagina = 1
    elseif id == "kp_fsin" then
        bandeja.sin = not bandeja.sin
        bandeja.pagina = 1
    elseif id == "kp_borrar" then
        local n = partida.cuentaCarpeta(k)
        ui.confirmar("¿BORRAR LA CARPETA " .. k.nombre .. "?", {
            n > 0 and ("SUS " .. n .. " CARTAS VUELVEN AL ARMARIO") or "ESTÁ VACÍA",
        }, "SÍ, BORRARLA", function()
            partida.borrarCarpeta(k.id)
            partida.guardar()
            carpeta.cerrar()
        end)
    end
    return true
end

-- coger una carta de abajo o de un bolsillo
function carpeta.coger(id, x, y)
    if not abierta or not id then return false end
    local def = tonumber(id:match("^kc(%d+)$") or "")
    if def then
        if partida.libresCarpeta(def) > 0 then ui.cogerSi(id, x, y) end
        return true
    end
    if id:match("^kb%d+$") then
        local k = partida.carpeta(abierta)
        if k and k.b[tonumber(id:sub(3))] then ui.cogerSi(id, x, y) end
        return true
    end
    return false
end

-- true si era suyo
function carpeta.soltar(c, x, y)
    if not abierta or not c.id:match("^k[bc]%d") then return false end
    if not c.moviendo then
        carpeta.click(c.id)
        return true
    end
    local destino = ui.zonaEn(x, y, "kb")
    local slot = destino and tonumber(destino:sub(3))
    if c.id:match("^kc") then
        local id = tonumber(c.id:sub(3))
        if slot and partida.meterEnCarpeta(abierta, slot, id) then
            sonido.tocar("encima", 1.2)
            fx.explosion(x, y, p.lima, 6, 40)
            partida.guardar()
        end
    else
        local de = tonumber(c.id:sub(3))
        if slot then
            if partida.moverEnCarpeta(abierta, de, slot) then sonido.tocar("encima", 1.1) end
        elseif not (x >= X and x < X + 308 and y >= Y and y < Y + 198) then
            -- fuera de la carpeta: vuelve al armario
            partida.sacarDeCarpeta(abierta, de)
            sonido.tocar("giro")
            fx.texto(x, y - 10, "AL ARMARIO", p.grisclaro)
        end
        partida.guardar()
    end
    return true
end

function carpeta.dibujarCogida()
    local cogida = ui.arrastrando()
    if not abierta or not cogida then return end
    local def, c
    local idc = tonumber(cogida:match("^kc(%d+)$") or "")
    if idc then
        def, c = partida.carta(idc), partida.mejorLibre(idc)
    else
        local slot = tonumber(cogida:match("^kb(%d+)$") or "")
        local k = partida.carpeta(abierta)
        local b = slot and k and k.b[slot]
        if b then def, c = partida.carta(b.id), partida.copia(b.id, b.u) end
    end
    if not def or not c then return end
    local balanceo = math.sin(love.timer.getTime() * 6) * 0.04
    carta.dibujar(def, ui.mx, ui.my, 1.08, 1.08, balanceo, true, { kx = 0, ky = 0, brillo = 1, lx = 0, ly = 0 }, c.f,
        { primera = c.p, top = c.t })
end

-- para las pruebas
carpeta.NOMBRES = NOMBRES
function carpeta.estado() return { abierta = abierta, pliego = pliego, bandeja = bandeja } end

return carpeta
