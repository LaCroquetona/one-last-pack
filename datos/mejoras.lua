-- Mejoras de suerte: se compran en la tienda y suben poco a poco lo que trae
-- de media un sobre (de un 75% de lo que cuesta hasta algo mas de un 100% con todo).
-- valores: lo que da cada nivel; coste: el primer nivel, en centimos;
-- multiplica: cuanto mas caro es cada nivel que el anterior
return {
    { id = "segunda", nombre = "SEGUNDA OPORTUNIDAD", texto = "El hueco de rara o mejor se tira dos veces y te quedas la mejor",
      valores = { 0.08, 0.16, 0.24, 0.32, 0.4 }, formato = "porcentaje", coste = 2000, multiplica = 2.4 },
    { id = "extra", nombre = "CARTA EXTRA", texto = "Probabilidad de que el sobre traiga una carta más",
      valores = { 0.06, 0.12, 0.18, 0.24, 0.3 }, formato = "porcentaje", coste = 1500, multiplica = 2.4 },
    { id = "godpack", nombre = "IMÁN DE GOD PACKS", texto = "Multiplica la probabilidad de que salga un god pack",
      valores = { 1.5, 2, 2.5, 3, 3.5 }, formato = "veces", coste = 2500, multiplica = 2.4 },
}
