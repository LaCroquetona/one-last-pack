-- Capturas de lo que se arrastra (pendulo) y de las cajas en la mesa
return function(t)
    local ok, esperar, click, foto, Z = t.ok, t.esperar, t.click, t.foto, t.Z
    local partida = t.partida
    local apertura = require "src.apertura"

    esperar(30)
    love.keypressed("space")
    esperar(10)
    click("nueva")
    esperar(3)
    if Z["modal_si"] then click("modal_si") end
    esperar(10)
    partida.dinero = partida.dinero + 10000
    -- todo desbloqueado (las cajas salen con el S2 desde la 0.9.0)
    partida.tutorial = false
    partida.desbloqueos = { todo = true }
    click("ir_tienda")
    esperar(5)
    click("sec_cajas")
    esperar(3)
    click("caja")
    esperar(3)
    click("caja")
    esperar(3)
    click("sec_sobres")
    click("ir_mesa")
    esperar(10)
    foto("v1_cajas_laterales")

    -- la caja en la mano, moviendose a la derecha
    local zc = Z["cajabox_set1"]
    t.pulsar(zc.x + zc.w / 2, zc.y + zc.h / 2)
    for k = 1, 10 do
        t.mover(zc.x + k * 20, zc.y + 40 + k * 6)
        esperar(1)
    end
    foto("v2_caja_en_mano")
    for _ = 1, 8 do esperar(1) end
    foto("v3_caja_parada")
    -- se suelta fuera del tapete: vuelve
    t.mover(zc.x, zc.y)
    esperar(2)
    t.soltar()
    esperar(10)

    -- un sobre: se arrastra, se abre y quedan las cartas sueltas
    local z = Z["caja_set1"]
    t.pulsar(z.x + z.w / 2, z.y + z.h / 2)
    for k = 0, 12 do
        t.mover(z.x + 20 + k * 18, z.y + 30 + k * 4)
        esperar(1)
    end
    foto("v4_sobre_en_mano")
    for _ = 1, 6 do t.mover(310, 170) esperar(1) end
    t.soltar()
    esperar(10)
    t.pulsar(310, 170)
    esperar(70)
    for _ = 1, 40 do
        if apertura.enResumen() then break end
        esperar(20)
        if not apertura.enResumen() then t.soltar() esperar(2) t.pulsar(310, 170) end
    end
    t.soltar()
    for _ = 1, 300 do
        if #partida.mesa > 0 then break end
        esperar(1)
    end
    esperar(30)
    ok(#partida.mesa > 0, "cartas sueltas en la mesa")
    local s = partida.mesa[1]
    local zm = Z["m" .. s.u]
    -- se coge por la esquina de arriba y se mueve a la derecha
    t.pulsar(zm.x + 4, zm.y + 4)
    for k = 1, 12 do
        t.mover(zm.x + 4 + k * 14, zm.y + 4 + k * 2)
        esperar(1)
    end
    foto("v5_carta_pendulo")
    for k = 1, 6 do
        t.mover(zm.x + 4 + 168 - k * 22, zm.y + 28 - k * 2)
        esperar(1)
    end
    foto("v6_carta_vuelta")
    t.soltar()
    esperar(3)
    foto("v7_carta_suelta")
    esperar(30)
    ok(s.ra == nil, "la carta se asienta")
end
