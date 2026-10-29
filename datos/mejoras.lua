-- Mejoras: se compran en el movil (app MEJORAS), por grupos.
-- Muchos niveles baratos al principio que se notan poco a poco: el primero
-- cuesta unos pocos euros y cada uno es algo mas caro (multiplica). Al
-- maximo dan lo mismo que antes (con las tres de suerte un sobre trae ~100-105%).
-- valores: lo que da cada nivel; nada: lo que hay sin la mejora; coste: el
-- primer nivel, en centimos; multiplica: cuanto mas caro es cada nivel
-- formato: como se ensena el efecto (src/movil.lua)
local function niveles(desde, paso, n)
    local v = {}
    for k = 1, n do v[k] = math.floor((desde + paso * (k - 1)) * 1000 + 0.5) / 1000 end
    return v
end

return {
    -- SUERTE: medido abriendo 20.000 sobres de cada set
    { id = "segunda", grupo = "suerte", nombre = "SEGUNDA OPORTUNIDAD", texto = "El hueco de rara o mejor se tira dos veces y te quedas la mejor",
      valores = niveles(0.016, 0.016, 10), nada = 0, formato = "porcentaje", coste = 400, multiplica = 1.55 },
    { id = "extra", grupo = "suerte", nombre = "CARTA EXTRA", texto = "Probabilidad de que el sobre traiga una carta más",
      valores = niveles(0.045, 0.045, 10), nada = 0, formato = "porcentaje", coste = 350, multiplica = 1.55 },
    { id = "godpack", grupo = "suerte", nombre = "IMÁN DE GOD PACKS", texto = "Multiplica la probabilidad de que salga un god pack",
      valores = niveles(1.12, 0.12, 10), nada = 1, formato = "veces", coste = 450, multiplica = 1.55 },

    -- VENTA
    { id = "comision", grupo = "venta", nombre = "CUENTA PRO", texto = "La app de ventas se queda menos de cada venta del móvil",
      valores = niveles(0.005, 0.005, 10), nada = 0, formato = "comision", coste = 300, multiplica = 1.5 },
    { id = "anuncios", grupo = "venta", nombre = "ESCAPARATE", texto = "Más anuncios publicados a la vez",
      valores = niveles(1, 1, 10), nada = 0, formato = "huecos", coste = 400, multiplica = 1.5 },
    { id = "regateo", grupo = "venta", nombre = "BUENA REPUTACIÓN", texto = "Llegan más ofertas altas (de un 20% o más sobre el valor)",
      valores = { 2.8, 2.6, 2.4, 2.2, 2.0, 1.85, 1.7, 1.55, 1.4, 1.3 }, nada = 3, formato = "curva", coste = 300, multiplica = 1.5 },

    -- DIRECTO
    { id = "camara", grupo = "directo", nombre = "CÁMARA HD", texto = "Ganas más seguidores en cada directo",
      valores = niveles(1.05, 0.05, 10), nada = 1, formato = "veces", coste = 500, multiplica = 1.55 },
    { id = "micro", grupo = "directo", nombre = "MICRO DE ESTUDIO", texto = "El chat te da propinas más a menudo",
      valores = niveles(1.12, 0.12, 10), nada = 1, formato = "veces", coste = 300, multiplica = 1.5 },
    { id = "aro", grupo = "directo", nombre = "ARO DE LUZ", texto = "Las peticiones pagan más y en la venta de sobres el chat paga más margen",
      valores = niveles(1.12, 0.12, 10), nada = 1, formato = "veces", coste = 300, multiplica = 1.5 },
    { id = "rechazar", grupo = "directo", nombre = "LISTA NEGRA", texto = "En la venta de sobres en directo puedes rechazar una compra concreta (con la X)",
      valores = { 1 }, nada = 0, formato = "nombres", nombres = { [0] = "NO", "SÍ" }, coste = 1500, multiplica = 1 },
    { id = "perfil", grupo = "directo", nombre = "TIENDA EN EL PERFIL", texto = "En la venta de sobres en directo llegan más compradores",
      valores = niveles(1.08, 0.08, 10), nada = 1, formato = "veces", coste = 600, multiplica = 1.55 },

    -- TIENDA
    { id = "mayorista", grupo = "tienda", nombre = "MAYORISTA", texto = "Sobres y cajas de la tienda más baratos",
      valores = niveles(0.008, 0.008, 10), nada = 0, formato = "rebaja", coste = 800, multiplica = 1.6 },
    { id = "proveedor", grupo = "tienda", nombre = "PROVEEDOR", texto = "Llegan más sobres de cada set a la tienda cada día",
      valores = { 3, 5, 8, 12, 16, 20, 25, 30 }, nada = 0, formato = "stock", coste = 500, multiplica = 1.6 },
    { id = "autofundas", grupo = "tienda", nombre = "SERVICIO DE FUNDAS", texto = "Las cartas buenas te llegan protegidas solas (eliges la rareza en el armario)",
      valores = { 1, 2 }, nada = 0, formato = "nombres", nombres = { [0] = "NO", "FUNDAS", "FUNDAS Y TOPS" }, coste = 800, multiplica = 3 },

    -- MESA
    { id = "velocidad", grupo = "mesa", nombre = "MANOS RÁPIDAS", texto = "Abres los sobres más rápido (lo cambias en la mesa con el botón de la velocidad)",
      valores = { 1.25, 1.5, 1.75, 2, 2.5, 3 }, nada = 1, formato = "veces", coste = 400, multiplica = 1.6 },
}
