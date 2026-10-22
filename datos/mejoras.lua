-- Mejoras: se compran en el movil (app MEJORAS), por grupos.
-- SUERTE sube poco a poco lo que trae de media un sobre (de un 85% de lo que
-- cuesta hasta algo menos de un 100% con todo). VENTA y DIRECTO ayudan a ganar
-- un poco mas sin regalar nada.
-- valores: lo que da cada nivel; nada: lo que hay sin la mejora; coste: el
-- primer nivel, en centimos; multiplica: cuanto mas caro es cada nivel
return {
    -- SUERTE: medido abriendo 20.000 sobres de cada set: cada una sube unos 6-8
    -- puntos lo que trae un sobre; con las tres al maximo, ~100-105%
    { id = "segunda", grupo = "suerte", nombre = "SEGUNDA OPORTUNIDAD", texto = "El hueco de rara o mejor se tira dos veces y te quedas la mejor",
      valores = { 0.03, 0.06, 0.09, 0.12, 0.16 }, nada = 0, formato = "porcentaje", coste = 2500, multiplica = 2.2 },
    { id = "extra", grupo = "suerte", nombre = "CARTA EXTRA", texto = "Probabilidad de que el sobre traiga una carta más",
      valores = { 0.1, 0.18, 0.27, 0.36, 0.45 }, nada = 0, formato = "porcentaje", coste = 2000, multiplica = 2.2 },
    { id = "godpack", grupo = "suerte", nombre = "IMÁN DE GOD PACKS", texto = "Multiplica la probabilidad de que salga un god pack",
      valores = { 1.25, 1.5, 1.75, 2, 2.2 }, nada = 1, formato = "veces", coste = 2500, multiplica = 2.2 },

    -- VENTA: el escaparate era muy barato para lo que daba
    { id = "comision", grupo = "venta", nombre = "CUENTA PRO", texto = "La app de ventas se queda menos de cada venta del móvil",
      valores = { 0.01, 0.02, 0.03, 0.04, 0.05 }, nada = 0, formato = "comision", coste = 2000, multiplica = 2 },
    { id = "anuncios", grupo = "venta", nombre = "ESCAPARATE", texto = "Más anuncios publicados a la vez",
      valores = { 1, 2, 3, 4, 5 }, nada = 0, formato = "huecos", coste = 2500, multiplica = 2.3 },
    { id = "regateo", grupo = "venta", nombre = "BUENA REPUTACIÓN", texto = "Llegan más ofertas altas (de un 20% o más sobre el valor)",
      valores = { 2.6, 2.2, 1.9, 1.6, 1.3 }, nada = 3, formato = "curva", coste = 2000, multiplica = 2.1 },

    -- DIRECTO: la camara ya rentaba sola; micro y aro casi no se notaban
    { id = "camara", grupo = "directo", nombre = "CÁMARA HD", texto = "Ganas más seguidores en cada directo",
      valores = { 1.1, 1.2, 1.3, 1.4, 1.5 }, nada = 1, formato = "veces", coste = 3000, multiplica = 2.3 },
    { id = "micro", grupo = "directo", nombre = "MICRO DE ESTUDIO", texto = "El chat te da propinas más a menudo",
      valores = { 1.3, 1.6, 1.9, 2.2, 2.5 }, nada = 1, formato = "veces", coste = 1200, multiplica = 2 },
    { id = "aro", grupo = "directo", nombre = "ARO DE LUZ", texto = "Las peticiones pagan más y en la venta de sobres el chat paga más margen",
      valores = { 1.25, 1.5, 1.75, 2, 2.3 }, nada = 1, formato = "veces", coste = 1500, multiplica = 2.1 },
}
