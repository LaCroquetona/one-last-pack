-- Prueba de la mesa, el directo y la economia (v0.7.2), con partida nueva
return function(t)
    local ok, esperar, click, foto, Z = t.ok, t.esperar, t.click, t.foto, t.Z
    local partida, mercado = t.partida, t.mercado
    local apertura = require "src.apertura"
    local directo = require "src.directo"
    local generador = require "src.generador"
    local datos = require "datos.mercado"

    esperar(30)
    love.keypressed("space")   -- saltar la firma
    esperar(10)
    click("nueva")
    esperar(3)
    if Z["modal_si"] then click("modal_si") end
    esperar(10)
    -- el tutorial se sigue a la vez que la prueba
    click("tut_sig")
    esperar(3)
    -- todo desbloqueado: aqui se prueba la mesa, no los desbloqueos
    partida.desbloqueos = { todo = true }
    partida.mejoras.autofundas = 2
    ok(partida.sobres("set1") == 3, "se empieza con 3 sobres")

    -- economia: venta rapida al 100% del valor
    local id = mercado.cartasDe("s1")[1].id
    ok(mercado.ventaRapida(id, true) == mercado.valor(id, true), "venta rapida = valor de mercado")
    ok(datos.anuncios.rango[1] >= 1.0, "el movil ofrece al menos el valor")

    -- la mesa: caja, tapete y panel del directo
    click("ir_mesa")
    esperar(5)
    foto("10_mesa_vacia")
    ok(Z["caja_set1"] ~= nil, "el sobre se ve en la caja")
    ok(Z["dir_empezar"] ~= nil, "boton de empezar directo")

    -- nombre del canal
    click("dir_nombre")
    for _ = 1, 10 do love.keypressed("backspace") end
    love.textinput("croqueta_tv")
    esperar(2)
    foto("11_nombre_canal")
    love.keypressed("return")
    esperar(2)
    ok(partida.canal.nombre == "CROQUETA_TV", "nombre del canal: " .. partida.canal.nombre)

    click("dir_empezar")
    esperar(5)
    ok(directo.activo(), "empieza el directo")
    ok(partida.tutorial == 3, "tutorial: tras el directo toca arrastrar el sobre")

    -- arrastrar el sobre: se balancea
    local z = Z["caja_set1"]
    t.pulsar(z.x + z.w / 2, z.y + z.h / 2)
    for k = 0, 20 do
        t.mover(z.x + 20 + k * 12, z.y + 30 + k * 4)
        esperar(1)
    end
    esperar(1)
    foto("12_arrastrando_sobre")
    for _ = 1, 6 do
        t.mover(310, 170)
        esperar(1)
    end
    foto("13_balanceo")
    t.soltar()
    esperar(10)
    ok(apertura.activa(), "el sobre cae en el tapete")
    ok(partida.sobres("set1") == 2, "se gasta un sobre")
    foto("14_sobre_en_tapete")

    -- mantener sobre el tapete para rasgar
    t.pulsar(310, 170)
    esperar(70)
    foto("15_revelando")
    -- mantener hace pasar las normales; con click se pasan las buenas
    for _ = 1, 40 do
        if apertura.enResumen() then break end
        esperar(20)
        if not apertura.enResumen() then
            t.soltar()
            esperar(2)
            t.pulsar(310, 170)
        end
    end
    t.soltar()
    esperar(2)
    ok(apertura.enResumen(), "acaba en el resumen")
    foto("16_resumen")

    -- al momento las cartas pasan a estar sueltas en la mesa
    for _ = 1, 200 do
        if #partida.mesa > 0 then break end
        esperar(1)
    end
    esperar(30)
    ok(#partida.mesa >= 7 and not apertura.activa(), "las cartas del sobre quedan sueltas en la mesa (" .. #partida.mesa .. ")")
    foto("16b_cartas_sueltas")
    ok(partida.tutorial == false, "intro acabada al abrir el primer sobre (" .. tostring(partida.tutorial) .. ")")

    -- se puede mover una
    local s1 = partida.mesa[1]
    local zs = Z["m" .. s1.u]
    ok(zs ~= nil, "la carta suelta se puede tocar")
    if zs then
        local x0 = s1.x
        t.pulsar(zs.x + zs.w / 2, zs.y + zs.h / 2)
        for k = 1, 10 do
            t.mover(zs.x + zs.w / 2 + k * 6, zs.y + zs.h / 2 + k * 8)
            esperar(1)
        end
        t.soltar()
        esperar(3)
        ok(math.abs(s1.x - x0) > 20, "la carta se ha movido")
    end

    -- funda: de la caja a una carta suelta
    local fundas = partida.fundasLibres
    local zf = Z["caja_funda"]
    ok(zf ~= nil, "las fundas se pueden coger con el sobre abierto")
    local s2 = partida.mesa[3]
    local zr = Z["m" .. s2.u]
    if zf and zr then
        t.pulsar(zf.x + zf.w / 2, zf.y + zf.h / 2)
        for k = 1, 12 do
            t.mover(zf.x + (zr.x + zr.w / 2 - zf.x) * k / 12, zf.y + (zr.y + zr.h / 2 - zf.y) * k / 12)
            esperar(1)
        end
        foto("17_funda_en_mano")
        t.soltar()
        esperar(5)
        ok(partida.fundasLibres == fundas - 1, "la funda se gasta al soltarla en la carta")
        foto("18_carta_enfundada")
    end
    -- tocar una carta suelta: sus botones
    local zt = Z["m" .. partida.mesa[2].u]
    if zt then t.clickEn(zt.x + zt.w / 2, zt.y + zt.h / 2) end
    esperar(3)
    -- desde la 0.10.2 tocarla abre INSPECCIONAR (con VENDER ESTA y AL ARMARIO)
    ok(Z["insp_vender"] ~= nil and Z["insp_armario"] ~= nil, "la carta suelta tiene sus botones")
    esperar(2)
    foto("18b_botones_carta")
    love.keypressed("escape")
    esperar(2)

    -- espacio: recoge la mesa y abre el siguiente (con DEV: secreta forzada)
    generador.forzar = "secreta"
    local enMesa = {}
    for _, e in ipairs(partida.mesa) do enMesa[#enMesa + 1] = partida.copia(e.id, e.u) end
    love.keypressed("space")
    esperar(5)
    ok(apertura.bloqueada(), "espacio abre el siguiente sobre")
    local quedan = 0
    for _, c in ipairs(enMesa) do if c.m then quedan = quedan + 1 end end
    ok(#partida.mesa == 0 and quedan == 0, "al abrir otro, lo de la mesa vuelve al armario")
    t.pulsar(310, 170)
    for _ = 1, 40 do
        if apertura.enResumen() then break end
        esperar(20)
        if not apertura.enResumen() then
            t.soltar()
            esperar(2)
            t.pulsar(310, 170)
        end
    end
    t.soltar()
    esperar(40)
    foto("19_resumen_secreta")

    -- con muchos seguidores el chat se anima
    partida.canal.seguidores = 1500
    partida.regalar("set1", 6, true)
    for _ = 1, 200 do esperar(1) end
    generador.forzar = "secreta"
    love.keypressed("space")
    esperar(5)
    t.pulsar(310, 170)
    local fotoChat = false
    for _ = 1, 60 do
        if apertura.enResumen() then break end
        esperar(15)
        if not fotoChat and directo.espectadores() > 20 then
            foto("20_chat_lleno")
            fotoChat = true
        end
        if not apertura.enResumen() then
            t.soltar()
            esperar(2)
            t.pulsar(310, 170)
        end
    end
    t.soltar()
    esperar(120)
    foto("21_chat_tras_secreta")
    ok(directo.espectadores() > 20, "con 1.500 seguidores hay gente: " .. directo.espectadores())

    -- en la tienda el directo sigue
    click("ir_tienda")
    esperar(10)
    ok(directo.activo(), "en la tienda sigue el directo")
    -- cajas de sobres
    partida.dinero = partida.dinero + 10000
    esperar(2)
    local antesCaja = partida.sobres("set1")
    if partida.desbloqueos and not partida.desbloqueos.todo then partida.desbloqueos.cajas = true end
    esperar(2)
    click("prod_caja")
    esperar(3)
    foto("22a_tienda_cajas")
    click("comprarProd")
    esperar(5)
    ok(partida.cajasDe("set1") == 1 and partida.sobres("set1") == antesCaja, "se compra una caja cerrada")
    local dineroCaja = partida.dinero
    click("comprarProd")
    esperar(3)
    partida.venderCaja(require("datos.sobres").set1, true)
    ok(partida.cajasDe("set1") == 1 and partida.dinero > dineroCaja - 4000, "se vende una caja cerrada")
    click("tipo_set1")
    esperar(2)
    -- la caja se abre en la mesa: se arrastra al tapete
    click("ir_mesa")
    esperar(5)
    local zc = Z["cajabox_set1"]
    ok(zc ~= nil, "la caja cerrada sale en la caja lateral")
    if zc then
        t.pulsar(zc.x + zc.w / 2, zc.y + zc.h / 2)
        for k = 1, 14 do
            t.mover(zc.x + k * 16, zc.y + k * 4)
            esperar(1)
        end
        t.soltar()
        esperar(50)
        foto("22b_caja_tiembla")
        esperar(42)
        foto("22c_caja_tapa")
        esperar(150)
        foto("22d_caja_esquina")
        ok(partida.cajaAbierta and partida.cajaAbierta.quedan == 18 and partida.cajasDe("set1") == 0, "caja abierta en la esquina con 18")
        local antesS = partida.sobres("set1")
        require("src.dev").saltar = true
        love.keypressed("space")
        esperar(5)
        ok(partida.cajaAbierta.quedan == 17 and partida.sobres("set1") >= antesS, "espacio saca el sobre de la caja, no de los guardados")
        esperar(100)
        foto("22e_sobre_de_la_caja")
        require("src.dev").saltar = false
    end
    click("ir_tienda")
    esperar(5)
    foto("22_tienda_en_directo")
    click("ir_mesa")
    esperar(5)

    -- parar: resumen
    click("dir_parar")
    esperar(10)
    ok(not directo.activo(), "se para el directo")
    foto("23_fin_directo")
    click("dir_vale")
    esperar(5)

    -- volver a empezar y el movil lo corta
    click("dir_empezar")
    esperar(5)
    click("ir_movil")
    esperar(30)
    ok(not directo.activo(), "ir al movil acaba el directo")
    foto("24_resumen_al_ir_al_movil")
    if Z["dir_vale"] then click("dir_vale") end
    esperar(5)

    -- copias a la mesa desde el armario y se ven en el tapete
    click("ir_armario")
    esperar(10)
    foto("25_armario")
    local idM = next(partida.inv)
    local c = partida.lista(idM)[1]
    partida.aLaMesa(idM, c)
    click("ir_mesa")
    esperar(10)
    ok(Z["m" .. c.u] ~= nil, "la copia sacada se ve en la mesa")
    local zm = Z["m" .. c.u]
    if zm then t.clickEn(zm.x + zm.w / 2, zm.y + zm.h / 2) end
    esperar(5)
    foto("26_copia_en_mesa")
    ok(Z["insp_armario"] ~= nil, "la copia elegida tiene sus botones (INSPECCIONAR)")
    love.keypressed("escape")
    esperar(2)

    -- sin sobres
    for _, tipo in ipairs(require("datos.sobres").lista) do
        while partida.sobres(tipo.id) > 0 do partida.sacarSobre(tipo.id) end
    end
    apertura.recoger()
    esperar(5)
    foto("27_sin_sobres")

    -- v0.7.3: mejoras de suerte
    local dev = require "src.dev"
    click("ir_tienda")
    esperar(5)
    partida.dinero = partida.dinero + 100000
    esperar(2)
    click("ir_movil")
    esperar(30)
    click("m_app_mejoras")
    esperar(25)
    click("m_mej_segunda")
    esperar(3)
    foto("30_mejoras")
    ok(partida.nivelMejora("segunda") == 1 and generador.suerte.segunda == 0.016, "mejora comprada y aplicada")
    click("m_inicio")
    esperar(20)

    -- encargos del movil
    partida.generarEncargo()
    partida.generarEncargo()
    local e = partida.ofertasEncargo[1]
    e.tipo, e.n, e.primera = "set1", 1, nil
    click("ir_movil")
    esperar(30)
    click("m_app_encargos")
    esperar(25)
    foto("31_encargos")
    ok(partida.aceptarEncargo(1), "se acepta un encargo")
    -- solo el sobre del encargo, para que ESPACIO abra ese
    partida.guardados, partida.guardados1, partida.cajaAbierta = {}, {}, nil
    partida.regalar("set1", 1, true)
    click("ir_mesa")
    esperar(10)
    local dinero = partida.dinero
    dev.saltar = true
    love.keypressed("space")
    esperar(10)
    ok(#partida.encargos == 0 and partida.dinero >= dinero + e.pago, "encargo cumplido y cobrado (" .. e.pago .. ")")
    esperar(120)

    -- peticion del chat
    partida.canal.seguidores = 500
    click("dir_empezar")
    esperar(200)
    directo.forzarPeticion()
    local pe = directo.peticion()
    ok(pe ~= nil, "el chat pide un sobre")
    esperar(10)
    foto("32_peticion")
    if pe then
        for _, tipo in ipairs(require("datos.sobres").lista) do
            while partida.sobres(tipo.id) > 0 do partida.sacarSobre(tipo.id) end
        end
        partida.regalar(pe.tipo, 1, true)
        love.keypressed("space")
        esperar(60)
        ok(directo.peticion() == nil, "peticion cumplida al abrir ese sobre")
        foto("33_peticion_cumplida")
    end
    dev.saltar = false

    -- todas las pantallas sin errores
    if Z["dir_parar"] then click("dir_parar") esperar(5) end
    if Z["dir_vale"] then click("dir_vale") esperar(3) end
    click("ir_armario")
    esperar(5)
    -- god pack: todo holo o mejor
    local gen = require "src.generador"
    gen.forzar = "godpack"
    local defs = gen.sobre(require("datos.sobres").set1)
    local malas = 0
    for _, d in ipairs(defs) do if require("datos.rarezas")[d.rareza].nivel < 4 then malas = malas + 1 end end
    ok(malas == 0, "god pack sin raras ni peores")
    -- auto funda/top por rareza
    partida.opciones.fundaDesde, partida.opciones.topDesde = 4, 5
    partida.topsLibres = 5
    local _, cc = partida.anadir(mercado.cartasDe("s1")[1].id, false)
    local idF
    for _, d in ipairs(mercado.cartasDe("s1")) do if d.rareza == "fullart" then idF = d.id end end
    local _, cf = partida.anadir(idF, false)
    ok(not cc.f and cf.f and cf.t, "comun sin funda, full art con funda y top")
    -- apartar sobres de 1ª ed
    partida.regalar("set1", 2, true)
    partida.apartar("s", "set1", true)
    ok(partida.disponibles("set1") == partida.sobres("set1", false), "los apartados no cuentan en la mesa")
    for _, m in ipairs({ "modo_copias", "modo_rareza", "modo_album", "modo_sellado" }) do
        click(m)
        esperar(5)
    end
    foto("40_sellado")
    click("ir_movil")
    esperar(30)
    for _, a in ipairs({ "cartera", "mercado", "ventas", "noticias", "calendario", "encargos", "mejoras", "logros" }) do
        click("m_inicio")
        esperar(15)
        click("m_app_" .. a)
        esperar(20)
    end
    foto("41_movil_inicio")
    ok(true, "se recorren todas las pantallas sin errores")
end
