-- Carga una partida de una version anterior (PARTIDA=...) y recorre las
-- pantallas pasando dias: no debe fallar nada
return function(t)
    local ok, esperar, click, foto, Z = t.ok, t.esperar, t.click, t.foto, t.Z
    local partida, mercado = t.partida, t.mercado
    esperar(30); love.keypressed("space"); esperar(10)
    click("continuar"); esperar(10)
    local dia = mercado.dia()
    ok(dia > 1, "partida cargada en el dia " .. dia)
    ok(partida.sobres("set4") >= 3, "conserva sus sobres")
    for _, e in ipairs({ "ir_tienda", "ir_armario", "ir_mesa", "ir_movil" }) do
        click(e); esperar(25)
    end
    for _ = 1, 60 do require("src.nav").pasarDia() end
    esperar(5)
    ok(#mercado.setsSalidos() == 8, "salen los sets nuevos (" .. #mercado.setsSalidos() .. ")")
    click("ir_tienda"); esperar(10)
    foto("90_carga_tienda")
end
