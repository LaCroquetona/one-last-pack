local esperado = require "esperado"

return function(t)
    local ok, esperar, click, foto, Z = t.ok, t.esperar, t.click, t.foto, t.Z
    local partida, mercado, armario = t.partida, t.mercado, t.armario

    esperar(30)
    love.keypressed("space")   -- saltar la firma
    esperar(10)
    foto("00_menu")

    -- la partida v5 se convierte al cargar
    ok(partida.existe(), "la partida v5 se reconoce")
    click("continuar")
    esperar(5)
    local n, p1, f = t.contarInv()
    ok(n == esperado.n, "mismas cartas tras convertir: " .. n .. " / " .. esperado.n)
    ok(p1 == esperado.p1, "mismas de 1ª ed: " .. p1 .. " / " .. esperado.p1)
    ok(f == esperado.f, "mismas fundas: " .. f .. " / " .. esperado.f)
    ok(#partida.anuncios == esperado.anuncios, "mismos anuncios: " .. #partida.anuncios)
    for _, a in ipairs(partida.anuncios) do
        local c = partida.copia(a.id, a.u)
        ok(c and c.a and (c.p or false) == a.primera, "anuncio con su copia reservada (carta " .. a.id .. ")")
    end
    ok(partida.dinero == esperado.dinero, "mismo dinero")
    -- el mercado viejo se convierte: precios validos e historiales iguales de largos
    local malos = 0
    for cid, c in pairs(mercado.estado.cartas) do
        if not (c.p1 and c.p1 > 0 and c.p1 == c.p1) or #c.h1 ~= #c.hn or #c.h1 ~= #c.v then malos = malos + 1 end
        if mercado.hayNormales(partida.carta(cid).set) and not c.pn then malos = malos + 1 end
    end
    ok(malos == 0, "mercado convertido sin precios rotos (" .. malos .. ")")
    ok(mercado.estado.version == 2 and mercado.estado.sets.s1 ~= nil, "mercado en version 2")
    foto("01_armario")

    -- una carta con muchas copias mezcladas para probar la bandeja
    local id = 3
    for k = 1, 25 do partida.anadir(id, k <= 9) end
    local copias = partida.copias(id)
    armario.seleccionar(id)
    esperar(3)
    foto("02_bandeja")

    -- arrastrar por encima de las copias elige varias
    local x0 = Z["cerrarBandeja"].x
    t.pulsar(150, 294)
    for x = 150, 330, 6 do
        t.mover(x, 294)
        esperar(1)
    end
    t.soltar()
    esperar(3)
    local elegidas = 0
    for _ in pairs(partida.lista(id)) do end
    foto("03_barrido")
    ok(Z["sel_vender"] ~= nil, "aparece el boton de vender elegidas")

    -- con pocas copias van centradas
    local idPocas
    for cid, l in pairs(partida.inv) do
        if #l == 1 then idPocas = cid break end
    end
    armario.seleccionar(idPocas)
    esperar(3)
    local zc = Z["cp_" .. partida.inv[idPocas][1].u]
    ok(zc and math.abs(zc.x + 18 - 383) < 3, "una sola copia sale centrada (x " .. (zc and zc.x or -1) .. ")")
    t.mover(zc.x + 10, zc.y + 20)
    esperar(3)
    foto("03b_una_copia_hover")
    armario.seleccionar(id)
    esperar(3)
    click("filtro_primera")
    esperar(2)
    foto("04_filtro_primera")
    -- vender las 1ª ed elegidas
    local antes = partida.deEdicion(id, true)
    local dinero = partida.dinero
    click("sel_vender")
    esperar(2)
    ok(partida.deEdicion(id, true) == 0, "vendidas las de 1ª ed elegidas (" .. antes .. ")")
    ok(partida.deEdicion(id, false) == copias - antes, "las normales siguen ahí")
    ok(partida.dinero > dinero, "cobradas")

    -- enfundar y a la mesa
    click("filtro_normal")
    click("sel_enfundar")
    ok(partida.enfundadas(id) >= 1, "enfundadas las elegidas: " .. partida.enfundadas(id))
    click("filtro_sinFunda")
    click("filtro_ninguna")
    click("filtro_todas")
    click("sel_mesa")
    esperar(2)
    ok(#partida.mesa > 0 and #partida.mesa <= partida.MAX_MESA, "copias en la mesa: " .. #partida.mesa)
    foto("05_tras_mesa")

    -- venta en lote: por defecto no toca 1ª ed, fundas, movil ni mesa, y deja una
    click("venderLote")
    esperar(3)
    foto("06_lote")
    local o = { todo = false, primeras = false, fundas = false }
    local r = partida.lote(o)
    local antesInv = {}
    for cid, l in pairs(partida.inv) do
        local copia = {}
        for _, c in ipairs(l) do copia[#copia + 1] = { p = c.p, f = c.f, a = c.a, m = c.m, u = c.u } end
        antesInv[cid] = copia
    end
    click("lote_si")
    esperar(2)
    local mal = 0
    for cid, l in pairs(antesInv) do
        local quedan = {}
        for _, c in ipairs(partida.inv[cid] or {}) do quedan[c.u] = true end
        local n2 = 0
        for _, c in ipairs(l) do
            if quedan[c.u] then n2 = n2 + 1 end
            if not quedan[c.u] and (c.p or c.f or c.a or c.m) then mal = mal + 1 end
        end
        if n2 == 0 then mal = mal + 1 end
    end
    ok(mal == 0, "el lote solo vende repes normales sin funda (" .. r.n .. " cartas)")
    ok(partida.lote(o).n == 0, "tras vender no quedan repes de ese tipo")

    -- todo, incluidas las de 1ª ed y enfundadas
    click("venderLote")
    esperar(2)
    click("lote_todo_true")
    click("lote_primeras_true")
    esperar(2)
    foto("07_lote_todo")
    click("lote_no")

    -- mesa
    click("modo_mesa")
    esperar(3)
    foto("08_mesa")
    local s = partida.mesa[1]
    click("m" .. s.u)
    esperar(2)
    foto("09_mesa_sel")
    click("mesa_guardar")
    ok(not partida.copia(s.id, s.u).m, "la copia vuelve al armario")

    -- guardar y volver a cargar
    partida.guardarYa()
    local n1 = partida.totalCartas()
    local mesa1 = #partida.mesa
    partida.cargar()
    ok(partida.totalCartas() == n1, "se guarda y se carga igual: " .. n1)
    ok(#partida.mesa == mesa1, "la mesa se guarda")

    -- movil: ficha de una carta de un set reimpreso con las dos lineas
    local ficha
    for cid in pairs(partida.inv) do
        local def = partida.carta(cid)
        if mercado.hayNormales(def.set) and def.rareza == "secreta" then ficha = cid break end
    end
    click("modo_copias")
    click("ir_movil")
    esperar(30)
    foto("10_movil")
    if ficha then
        require("src.nav").ficha(ficha, true)
        esperar(20)
        foto("11_ficha")
        -- arrastrar para hacer scroll
        t.pulsar(320, 300)
        for y = 300, 200, -10 do
            t.mover(320, y)
            esperar(1)
        end
        t.soltar()
        esperar(3)
        foto("12_ficha_scroll")
    end
    click("m_inicio")
    esperar(3)
    click("m_app_cartera")
    esperar(15)
    foto("13_cartera")
    -- arrastrar la lista de la cartera hace scroll y no abre la carta que pulsas
    local antesApp = Z["m_tab_top"] ~= nil
    t.pulsar(320, 300)
    for y = 300, 150, -10 do
        t.mover(320, y)
        esperar(1)
    end
    t.soltar()
    esperar(3)
    foto("13b_cartera_scroll")
    ok(Z["m_tab_top"] == nil or Z["m_tab_top"].y < 120, "la lista se ha movido")
    ok(Z["m_seguir"] == nil, "arrastrar no abre la ficha")
    -- un toque sin arrastrar si abre la ficha
    for zid, z in pairs(Z) do
        if zid:match("^m_carta_") and z.y > 120 and z.y < 300 then
            t.clickEn(z.x + 10, z.y + 5)
            break
        end
    end
    esperar(3)
    ok(Z["m_seguir"] ~= nil, "un toque abre la ficha")
    _ = antesApp
    click("ir_tienda")
    esperar(20)
    foto("14_tienda")

    -- abrir sobres y que entren como copias
    local antesN = partida.totalCartas()
    partida.regalar("set1", 3, true)
    require("src.nav").lote(3)
    esperar(5)
    ok(partida.totalCartas() > antesN, "abrir sobres añade copias")
    foto("15_lote_sobres")
    -- pasar 40 dias no rompe nada
    for _ = 1, 40 do require("src.nav").pasarDia() end
    ok(true, "40 días pasados")

    -- tirada: si compras mas de tu cuota se imprime mas
    local st = mercado.estado.sets.s4
    local antesT = st.tirada
    mercado.comprados("s4", 2000)
    ok(st.tirada >= math.floor((st.comprados) / 0.15) and st.tirada > antesT, "comprar mucho agranda la tirada: " .. antesT .. " -> " .. st.tirada)
    local _, parte = mercado.tirada("s4")
    ok(parte <= 0.15 + 1e-6, "nunca tienes más del 15%: " .. string.format("%.3f", parte))

    -- crash: un almacen de 1ª edicion hunde la 1ª edicion de ese set
    local n = mercado.noticia("almacen1")
    if n then
        local suma0 = 0
        for _, def in ipairs(mercado.cartasDe(n.set)) do suma0 = suma0 + math.log(mercado.valorExacto(def.id, true)) end
        for _ = 1, 3 do mercado.pasarDia() end
        local suma1 = 0
        for _, def in ipairs(mercado.cartasDe(n.set)) do suma1 = suma1 + math.log(mercado.valorExacto(def.id, true)) end
        local caida = math.exp((suma1 - suma0) / #mercado.cartasDe(n.set)) - 1
        ok(caida < -0.15, "el almacén hunde la 1ª ed del " .. n.set .. ": " .. string.format("%.0f%%", caida * 100))
    else
        ok(false, "no se pudo forzar el almacén")
    end
    -- las noticias siguen avisando aunque haya muchas guardadas
    local avisadas = 0
    for _ = 1, 60 do avisadas = avisadas + #mercado.pasarDia() end
    ok(#mercado.estado.noticias == 40 and avisadas > 20, "siguen llegando noticias nuevas: " .. avisadas)
    click("ir_movil")
    esperar(20)
    click("ir_dev")
    esperar(3)
    foto("15b_dev")
    click("ir_dev")

    -- partida nueva y abrir un sobre entero con la animacion
    partida.borrar()
    local nav = require "src.nav"
    nav.empezar()
    esperar(5)
    ok(partida.totalCartas() == 0 and partida.dinero == require("datos.sobres").inicio.dinero, "partida nueva limpia")
    partida.regalar("set1", 1, true)
    nav.abrir("set1")
    esperar(10)
    t.pulsar(320, 160)
    esperar(40)
    t.soltar()
    for _ = 1, 80 do
        t.clickEn(320, 160)
        esperar(4)
    end
    foto("16_resumen")
    ok(partida.totalCartas() == 7, "el sobre da 7 copias: " .. partida.totalCartas())
    ok(partida.deEdicion(partida.orden[1], true) == 1, "son de 1ª edición")
    click("armario")
    esperar(5)
    foto("17_armario_nuevo")
    ok(partida.sobres("set1", true) == 3, "se empieza con 3 sobres de 1ª ed: " .. partida.sobres("set1", true))

    -- premios: completar el set 1 da sus sobres y su dinero, una sola vez
    local antesS, antesD = partida.sobres("set1"), partida.dinero
    for _, def in ipairs(mercado.cartasDe("s1")) do partida.anadir(def.id, true) end
    local premios = require "datos.premios"
    local esperadoS = premios.primera.sobres
    for _, h in ipairs(premios.hitos) do esperadoS = esperadoS + h.sobres end
    ok(partida.sobres("set1") - antesS == esperadoS, "premios del set 1: +" .. (partida.sobres("set1") - antesS) .. " sobres (esperado " .. esperadoS .. ")")
    ok(partida.dinero > antesD, "y dinero")
    for _, def in ipairs(mercado.cartasDe("s1")) do partida.anadir(def.id, true) end
    ok(partida.sobres("set1") - antesS == esperadoS, "no se dan dos veces")
    esperar(10)
    foto("18_premio_toast")
    click("modo_album")
    esperar(3)
    foto("19_album_premios")
end
