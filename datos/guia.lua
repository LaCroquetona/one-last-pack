-- Explicaciones de cada pantalla y app (las pinta src/tutorial.lua con la
-- mascota). Salen solas la primera vez que entras (si ya esta desbloqueado)
-- y se vuelven a ver con el boton ? de la barra.
-- titulo: arriba del panel; pasos: { texto, apunta (id de ui), pose };
-- requiere: desbloqueo que hace falta; auto = false: solo con el ?;
-- bloquea = false: no oscurece ni para el juego (la mesa sigue viva).
-- Poses: saludo, piensa, pulgar (sprites/mascota_*.png)
return {
    -- la intro de la partida nueva (los "hecho" estan en src/tutorial.lua)
    intro = {
        { texto = "¡EH, BUENAS! SOY TU SOCIO. AQUÍ SE ABREN SOBRES, SE HACEN DIRECTOS Y SE SACA UN DINERILLO. LO DEMÁS TE LO VOY CONTANDO SOBRE LA MARCHA.",
          boton = "¡VAMOS!", pose = "saludo" },
        { texto = "PRIMERO, ENCIENDE EL DIRECTO: MIENTRAS ABRES, EL CHAT TE DEJA PROPINAS Y GANAS SEGUIDORES.",
          apunta = "dir_empezar", boton = "AHORA NO", pose = "pulgar" },
        { texto = "AHORA ARRASTRA UN SOBRE DE LA CAJA AL TAPETE Y MANTÉN PULSADO PARA RASGARLO. ¡A VER QUÉ SALE!",
          apunta = "caja_set1", pose = "pulgar" },
    },

    mesa = { titulo = "LA MESA", auto = false, bloquea = false, pasos = {
        { texto = "AQUÍ SE ABRE: ARRASTRA UN SOBRE AL TAPETE Y MANTÉN PULSADO. LAS CARTAS SE QUEDAN SUELTAS: TÓCALAS PARA ENFUNDARLAS, VENDERLAS O GUARDARLAS.",
          apunta = "caja_set1", pose = "saludo" },
        { texto = "EL DIRECTO ES TU NEGOCIO: CUANTOS MÁS SEGUIDORES, MÁS PROPINAS. OJO, QUE SI COGES EL MÓVIL SE CORTA.",
          apunta = "dir_empezar", pose = "piensa" },
        { texto = "SI TE ARREPIENTES, UN SOBRE SE GUARDA SIN ABRIR CON GUARDAR O ARRASTRÁNDOLO A LA CAJA. Y TRAE LAS MISMAS CARTAS, ¿EH? NADA DE TRAMPAS.",
          pose = "pulgar" },
    } },

    -- la primera vez que haces un directo de venta (en la mesa)
    venta = { titulo = "DIRECTO DE VENTA", requiere = "venta", bloquea = false, pasos = {
        { texto = "AQUÍ NO ABRES PARA TI: EL CHAT TE COMPRA LOS SOBRES QUE TIENES GUARDADOS. CADA PEDIDO SALE EN EL MÓVIL DEL TRÍPODE: QUÉ SET QUIERE, CUÁNTO PAGA Y CUÁNTO ESPERA.",
          apunta = "dir_vender", pose = "saludo" },
        { texto = "PARA VENDÉRSELO, ABRE UN SOBRE DE ESE SET EN EL TAPETE: COBRAS AL MOMENTO Y LAS CARTAS SON SUYAS. SI TARDAS MUCHO, SE CANSA Y SE VA.",
          pose = "pulgar" },
        { texto = "¿QUIERES ABRIR UNO PARA TI? TOCA VENDIENDO Y PASA A PARA MÍ: LO QUE ABRES ES TUYO Y LOS PEDIDOS ESPERAN SIN CORRER EL TIEMPO.",
          apunta = "dir_vender", pose = "piensa" },
        { texto = "CUANTO MÁS ABRES Y MEJOR SALE, MÁS HYPE (LA RAYITA NARANJA): LLEGAN MÁS COMPRADORES Y PAGAN MÁS.",
          apunta = "dir_vender", pose = "pulgar" },
    } },

    armario = { titulo = "EL ARMARIO", pasos = {
        { texto = "ESTE ES TU ARMARIO: AQUÍ VA TODO LO QUE SACAS. ARRIBA ELIGES EL SET.",
          apunta = "set_", pose = "saludo" },
        { texto = "COPIAS: TUS CARTAS UNA A UNA, CON SUS REPETIDAS. TOCA UNA PARA VERLA, ENFUNDARLA O VENDERLA.",
          apunta = "modo_copias", pose = "saludo" },
        { texto = "RAREZA: LAS MISMAS CARTAS POR GRUPOS. VIENE BIEN PARA VENDER TODAS LAS COMUNES DE GOLPE.",
          apunta = "modo_rareza", pose = "piensa" },
        { texto = "ÁLBUM: LO QUE LLEVAS DEL SET, LO QUE TE FALTA Y LOS PREMIOS POR IR COMPLETÁNDOLO.",
          apunta = "modo_album", pose = "piensa" },
        { texto = "EN EL ÁLBUM, TOCA UNA CARTA QUE TE FALTE Y LA MARCAS COMO BUSCADA: TE AVISO CUANDO SALGA O CUANDO ALGUIEN LA VENDA.",
          apunta = "modo_album", pose = "pulgar" },
        { texto = "SELLADO: TU ARMARIO CON LO QUE GUARDAS SIN ABRIR. CADA COSA VA AL PRIMER HUECO LIBRE; TOCA UN HUECO PARA MANDARLO A LA MESA O APARTARLO.",
          apunta = "modo_sellado", pose = "piensa" },
        { texto = "PARA VENDER, TOCA UNA CARTA Y USA LA BANDEJA, O VENDER EN LOTE PARA MUCHAS. LO QUE VALE MUCHO, MEJOR POR EL MÓVIL: PAGAN MÁS.",
          apunta = "venderLote", pose = "pulgar" },
    } },

    tienda = { titulo = "LA TIENDA", pasos = {
        { texto = "AQUÍ COMPRAS SOBRES DE LOS SETS QUE ESTÁN A LA VENTA. CADA DÍA LLEGAN MÁS, PERO LA 1ª EDICIÓN NO DURA PARA SIEMPRE.",
          apunta = "comprar1", pose = "saludo" },
    } },
    tienda_cajas = { titulo = "PRODUCTOS", requiere = "cajas", pasos = {
        { texto = "¡HAN LLEGADO CAJAS Y ETB! LA CAJA TRAE 18 SOBRES MÁS BARATOS; LA ETB, 9 SOBRES Y FUNDAS. ÁBRELAS EN LA MESA O GUÁRDALAS CERRADAS PARA REVENDERLAS.",
          apunta = "prod_caja", pose = "pulgar" },
        { texto = "CADA SET TIENE SU ESTANTERÍA: ARRIBA ELIGES EL SET, Y EN MIX ESTÁN LAS FUNDAS Y LOS TOPS.",
          apunta = "tset_", pose = "piensa" },
    } },

    movil = { titulo = "TU MÓVIL", pasos = {
        { texto = "A LA IZQUIERDA PASAS EL DÍA: LLEGAN SOBRES A LA TIENDA Y SE MUEVEN LOS PRECIOS. LAS APPS IRÁN LLEGANDO.",
          apunta = "pasarDia", pose = "saludo" },
    } },

    app_cartera = { titulo = "CARTERA", pasos = {
        { texto = "LO QUE VALE TU COLECCIÓN Y CÓMO VA CAMBIANDO. CUÁNDO VENDER Y CUÁNDO AGUANTAR YA ES COSA TUYA.",
          pose = "piensa" },
    } },
    app_mercado = { titulo = "MERCADO", pasos = {
        { texto = "LO QUE VALE CADA COSA HOY. ENTRA EN UN SET PARA VER SUS SOBRES, SUS CAJAS Y SUS CARTAS.",
          apunta = "m_set_", pose = "saludo" },
    } },
    app_set = { titulo = "MERCADO", pasos = {
        { texto = "CADA SET VA POR SECCIONES: SOBRES Y SELLADO (CAJAS, ETB...) DE 1ª EDICIÓN, REIMPRESIONES CUANDO LAS HAYA, Y LAS CARTAS.",
          apunta = "m_sec_", pose = "saludo" },
        { texto = "LA 1ª EDICIÓN SOLO SE VENDE EN LA TIENDA UNOS DÍAS. LUEGO LLEGAN LAS REIMPRESIONES, Y CADA UNA TIENE SU PRECIO.",
          pose = "piensa" },
        { texto = "TAMBIÉN VENDE GENTE DE SEGUNDA MANO: MIRA SUS ESTRELLAS Y SUS VENTAS. Y LOS PRECIOS SE MUEVEN CON NOTICIAS, AGOTADOS Y TORNEOS.",
          pose = "pulgar" },
    } },
    app_ficha = { titulo = "UNA CARTA", pasos = {
        { texto = "SU PRECIO, SU GRÁFICA Y QUIÉN LA VENDE HOY. CON LA ESTRELLA LA MARCAS COMO BUSCADA Y TE AVISO SI SALE.",
          apunta = "m_buscar", pose = "pulgar" },
    } },
    app_ventas = { titulo = "VENTAS", pasos = {
        { texto = "PUBLICAS TUS CARTAS Y LA GENTE TE HACE OFERTAS. PAGAN MÁS QUE LA VENTA RÁPIDA, PERO HAY QUE ESPERAR.",
          pose = "saludo" },
        { texto = "CADA DÍA LLEGAN OFERTAS NUEVAS. LA APP SE QUEDA UNA COMISIÓN, Y A CADA OFERTA PUEDES PEDIRLE UN 15% MÁS UNA VEZ.",
          pose = "piensa" },
    } },
    app_noticias = { titulo = "NOTICIAS", pasos = {
        { texto = "LO QUE PASA EN EL MUNDILLO. UNA BUENA NOTICIA PUEDE DISPARAR UNA CARTA, Y UNA MALA, HUNDIRLA.",
          pose = "piensa" },
    } },
    app_calendario = { titulo = "CALENDARIO", pasos = {
        { texto = "CUÁNDO SALE CADA SET, CUÁNDO SE AGOTA Y CUÁNDO SE REIMPRIME. LO QUE AÚN NO SE SABE, AQUÍ NO SALE.",
          pose = "piensa" },
    } },
    app_encargos = { titulo = "ENCARGOS", pasos = {
        { texto = "GENTE QUE TE PAGA POR HACER ALGO EN UNOS DÍAS: ABRIR SOBRES DE UN SET, ENFUNDAR CARTAS O SACAR CARTAS DE UNA RAREZA. ¡Y LAS CARTAS SON PARA TI!",
          pose = "saludo" },
        { texto = "ACEPTA LOS QUE TE CUADREN: SI SE ACABA EL PLAZO, NO COBRAS. COMO MUCHO LLEVAS 3 A LA VEZ.",
          pose = "piensa" },
    } },
    app_mejoras = { titulo = "MEJORAS", pasos = {
        { texto = "SUERTE, VENTAS, DIRECTO Y TIENDA: CADA PESTAÑA ES UN CAMINO PARA HACER CRECER EL NEGOCIO.",
          pose = "saludo" },
        { texto = "CADA NIVEL SE NOTA UN POCO, NO ESPERES MILAGROS. PERO SUMADOS, SE NOTAN.",
          pose = "pulgar" },
    } },
    app_logros = { titulo = "LOGROS", pasos = {
        { texto = "TUS HAZAÑAS. NO DAN DINERO, PERO PARA FARDAR NO HAY NADA MEJOR.",
          pose = "pulgar" },
    } },

    -- la primera vez que coges el movil en directo
    movilDirecto = { titulo = "¡OJO!", pasos = {
        { texto = "¡QUIETO! EL MÓVIL ES EL QUE ESTÁ GRABANDO: SI LO COGES, SE CORTA EL DIRECTO Y SE ACABAN LAS PROPINAS. LA TIENDA Y EL ARMARIO SÍ PUEDES MIRARLOS SIN CORTAR.",
          pose = "piensa" },
    } },

    -- que explicaciones mira cada pantalla al entrar (en orden)
    pantallas = {
        tienda = { "tienda", "tienda_cajas" },
        armario = { "armario" },
        mesa = { "mesa", "venta" },
    },
}
