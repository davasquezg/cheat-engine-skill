# Changelog — Azure Striker Gunvolt Trilogy Enhanced (tabla de Skolleks)

Tabla en desarrollo: `Gunvolt_Trilogy_Enhanced_<versión>_ES.CT`, generada por `build_trilogia_alpha.py` (no se edita a mano). Cada versión anterior se conserva en esta carpeta como referencia.
Build del juego: `game1.exe` del 2026-10-07 (SHA-256 `8502cad08098…`). Leyenda de la tabla: 🟢 verificado en vivo · ⚪ candidato · 🟠 portado de wepon1984 sin verificar.

## [v0.13-alpha] — 2026-11-09

- **Agregado — 🔌 Autoacople:** al cargar la tabla (LuaScript de la tabla) se activa solo y, cada 1,5 s, detecta cuál de los juegos de la colección está abierto (`game1.exe` GV1, `game2.exe` GV2, `game3.exe` GV3, `game4.exe` Connect iX), **acopla Cheat Engine a ese proceso y activa su grupo** (los de los otros juegos se desactivan). Si vuelves al menú y abres otro juego, se suelta y se re-acopla solo. El estado aparece en el título de la ventana de CE («acoplado a GV3 …» / «esperando un juego…»). Desactivar la entrada = dejar de vigilar; los grupos siguen sirviendo para acoplar a mano.

## [v0.12-alpha] — 2026-11-08

- **No funciona ❌:** «Vida: infinita / One Hit Kill» (el usuario no ve efecto). Igual que el «Health» de wepon1984: la instrucción enganchada escribe un HP que baja con los golpes, pero forzarlo no protege → probablemente es la barra de la interfaz, no el HP real.
- **Sonda de invencibilidad v5:** el objeto `[[[B]+10]+10]` resultó ser **visual** (parpadeo, cámara lenta). La v5 busca la **entidad** que es dueña del componente de vida (QWORD que apuntan a él en toda la memoria), sigue componente, dueños y objeto visual durante 30 s y puntúa los campos que cambian al recibir el golpe y vuelven al terminar el parpadeo. Calcula en línea, sin guardar las muestras.

## [v0.11-alpha] — 2026-11-08

- **Agregado (🧪): «Vida: infinita / One Hit Kill»** propio para GV3, con listas Sí/No. Usa la misma AOB y la misma lógica que el «Health» de wepon1984 / RTX_XXXX: la sonda v3 confirmó que esa instrucción solo ve al jugador al recibir daño, con `[+20] = 1` y HP *float* 200/380. Además captura el componente de vida (`gv3_hp`) y muestra HP, HP máx. y la marca de jugador.
- **Quitado:** el «Health» de wepon1984 del grupo de GV3 (sigue acreditado): parchaba la misma instrucción y no se podían usar los dos a la vez.
- **Sonda de invencibilidad v4:** busca los *i-frames* en el **componente de vida** (en la v3 ningún campo del objeto jugador duraba lo mismo que el parpadeo) y punteros del jugador al componente.

## [v0.10-alpha] — 2026-11-08

- **Sonda de invencibilidad y vida v3:** la v2 confundía los golpes que das con los que recibes (la cámara lenta salta en ambos). Ahora la marca de golpe es el **parpadeo** del jugador; cada golpe se mide hasta el fin del parpadeo; el registro del hook de vida funciona aunque «Health» esté activo (guarda su parche y lo restaura) y sigue el HP del componente del jugador.

## [v0.9-alpha] — 2026-11-08

- **Probado ✅:** Kudos bloqueados quitar ×N / anular («funciona perfecto»).
- **No funciona ❌:** el script «Health» de wepon1984 (vida máx. / One Hit Kill) en esta build, aunque su AOB es única. Se marca en la tabla y se investiga.
- **Corregido:** la cámara lenta es un *float* en `jugador+0x590` (wepon1984 leía su mitad alta en `+0x592`).
- **Sonda de invencibilidad y vida v2:** mide cuánto dura cada campo candidato tras cada golpe frente al parpadeo, registra qué objetos pasan por el hook de vida (y su `[+20]`), y ya no da falsos temporizadores por floats desnormales.

## [v0.8-alpha] — 2026-11-08

- **Cambiado:** las notas `##` y las sondas pasan de azul a **celeste claro** (`FFCC66` en BGR); con la interfaz oscura de Cheat Engine el azul no se leía.
- **GV3 — EXP ×N ❌:** no sube el nivel. La EXP de la cadena de wepon1984 (`[[[B]+20]+110]+2A80`) pasó de 40 313 a 371 228 entre dos corridas con el multiplicador, pero el nivel solo subió de 36 a 37: no es la EXP que decide el nivel. Se marca como no funcional y se agrega la **sonda de EXP real** (busca la EXP del menú en toda la memoria y sigue las coincidencias que suben).

## [v0.7-alpha] — 2026-11-08

- **Confirmado:** el castigo de Kudos bloqueados es **`[game3.exe+1F02FE8]+0x2FC` como *float*** (680,26 con −680 en pantalla). Se paga solo con el tiempo (93 bajadas en 5 min) hasta 0. La tabla lo muestra como *float* y el script ya no tiene que adivinar el tipo.
- **Descartado:** `1EC087719D0` (entero 680 fijo durante 5 min: copia del castigo inicial, no editable).

## [v0.6-alpha] — 2026-11-08

- **Cambiado:** la sonda de Kudos bloqueados ya no propone `1EC07DA7578`: el usuario vio que cae a 0 al pasar a otra fase del nivel (copia temporal). Quedan `[B]+0x2FC` (`1EB84B92A1C` en esa sesión) y `1EC087719D0`.

## [v0.5-alpha] — 2026-11-08

GV3, primeras pruebas del usuario en el juego.

- **Probado ✅:** Prestigio ×N / mantener («funciona genial»).
- **Corregido:** el campo `jugador+0x592` que wepon1984 llamaba «Invincibility Timer» es el temporizador de **cámara lenta** del golpe: al mantenerlo, el juego va lento y no da invencibilidad. El script pasa a llamarse «Cámara lenta (Sí/No)».
- **Agregado (🧪):** **Kudos bloqueados** (el castigo que en pantalla sale negativo): «quitar ×N» multiplica cada pago del castigo (×1 … ×1024) y «anular» lo deja en 0. Dirección `[game3.exe+1F02FE8]+0x2FC`, hallada por el usuario (`1EB84B92A1C` = objeto base + 0x2FC); falta confirmarla con la sonda.
- **Sondas nuevas:** invencibilidad de GV3 (método de GV1: temporizadores y banderas que se encienden con cada golpe) y Kudos bloqueados (tipo del valor, punteros estáticos, relación con los Kudos durante 5 min).

## [v0.4-alpha] — 2026-11-08

GV3 (`game3.exe`, build 2026-10-13). Diagnósticos v1–v3 en `dumps/diag_gv3_*.txt`; ANALISIS §9.

- **Agregado — grupo de GV3 propio:** base de wepon1984 hallada en `game3.exe+1F02FE8` (Δ +0xD6150 respecto a su build).
  - 🟢 Vida máx. del jugador y **One Hit Kill** (script «Health» de wepon1984 / RTX_XXXX; su AOB es única en `game3.exe+8B5B62`).
  - 🧪 **Invencibilidad** Sí/No (mantiene el temporizador `jugador+0x592`; aprende su valor tras el primer golpe).
  - 🧪 **EXP ×N** y **Prestigio ×N / mantener** con listas ×1 … ×1024 (el Prestigio de GV3 es *float*).
  - 🟢 **Image Chips** del nivel con lista «todos» (3 / 5 / 7 chips).
  - 🟢 Valores: EXP, Nivel, Prestigio, Score, barra Fetters; ⚪ Tiempo de nivel, copias de Score e Image Chips.
- **Quitado:** las entradas de GV3 de wepon1984 que usaban la base vieja (`+1E2CE98`, que en esta build es texto).
- 🧪 = verificado el dato, falta probar el truco en el juego.

## [v0.3-alpha] — 2026-11-08

Verificación v3 (5 min de muestreo; informe `dumps/verificar_candidatas_gv1_v3_2026-11-08_0404.txt`).

- **Agregado (🟢):** Medallas del nivel `game1.exe+7E10DC`, Tiempo de nivel `+7E10D4`, Tiempo total `Créditos−0xE0` (≈ 7660 unidades por segundo).
- **Cambiado:** EXP ×N y Prestigio ×N pasan a ser **dos scripts separados**. El factor se elige en una **lista desplegable** de la tabla (×1, ×2, ×4 … ×1024), se puede cambiar en vivo y se recuerda al desactivar. «Mantener Prestigio» también es una lista (Sí/No). Ya no hay cuadros de texto al activar.
- **Quitado:** Score y Kudos estáticos (no existen en `game1.exe` en esta build) y las candidatas de wepon1984 que fallaron.
- **Movido a ⚪:** dos contadores de combate (`+7FFEC8`, `+7FFEE0`), que no son el Prestigio; la copia de la EXP (`Créditos+0x438`) y una posible copia de las medallas (`Créditos+0x44C`).

## [v0.2-alpha] — 2026-11-08

Verificación v1 y v2 (informes `…_v1_…`, `…_v1b_…`, `…_v2_…` en `dumps/`).

- **Agregado (🟢):** Nivel `Créditos+0x47C`, EXP total `Créditos+0x478`, PV máx. sin escalar (bloque de combate `+0x2C`, +5 por nivel) y **puntero estático al jugador** `[game1.exe+7B3220]` (HP, HP máx., invencibilidad). El puntero siguió válido tras recargar la partida.
- **Cambiado:** el multiplicador de Prestigio también multiplica la EXP (`gv1_exp`). La Energía se etiqueta «×10 000», sin valor de «llena» (con mejoras llega a 6 500 000).
- **Comprobado:** la copia del bloque de combate (`+7ED67C`) **no manda**.
- **Quitado:** candidatas de wepon1984 trasladadas con un Δ fijo que no acertaron (EXP `+7AF9A8`, Nivel `+0x474`, puntero `+7B3238`…).
- «🔎 Verificar candidatas» v3: 5 min de muestreo y un informe por corrida con fecha y hora.

## [v0.1-alpha] — 2026-11-08

- Primera tabla de la trilogía: un grupo por ejecutable (`game1.exe` … `game4.exe`). Activar el grupo adjunta Cheat Engine a ese juego (patrón de wepon1984).
- **GV1:** todo lo verificado de la multisonda (captura del jugador, invencibilidad, Prestigio ×N, materiales al máximo, Créditos, PE, PH y cooldowns) más las candidatas trasladadas desde la tabla de wepon1984, y las sondas de investigación.
- **GV2, GV3 y Connect iX:** grupos de wepon1984 portados sin cambios (🟠). Se quitaron 6 enlaces `DropDownListLink` rotos del original (armas EX de Connect iX → «Anchor Nexus», que no tiene lista).
- Créditos en notas `##` y en *Table Extras → Comments*.

---

## Comparación de GV1 con las tablas de referencia (estado en v0.3-alpha)

| | **gv1.CT** — WarCOzes ([t=1929](https://fearlessrevolution.com/viewtopic.php?t=1929)) | **trilogy.CT, grupo GV1** — wepon1984 ([t=35866](https://fearlessrevolution.com/viewtopic.php?t=35866)) | **v0.3-alpha** (esta tabla) |
|---|---|---|---|
| Juego / ejecutable | GV1 original de Steam, `gv_win.exe` **32 bits** | Trilogy, `game1.exe` 64 bits, **otra build** | Trilogy, `game1.exe` 64 bits, build 2026-10-07 |
| ¿Funciona en la build actual? | No (otro ejecutable) | **No**: todas sus direcciones son fijas y en esta build están corridas entre +0x8FF0 y +0x9078 según la zona | Sí, verificado en vivo |
| Entradas de GV1 | 57 (7 scripts) | 50 (0 scripts) | **103** (10 scripts) |
| Método | Direcciones fijas + 5 scripts (1 con AOB) | Solo direcciones fijas | Inyección AOB que tolera la zona ya parchada, firma de memoria en el heap (Prestigio), direcciones fijas **verificadas una por una** y puntero estático al jugador. Todo sin depurador (el juego se cierra con él) |
| Vida | Script *Inf. Health* | `[+7AA1C0]+398` | Captura del jugador por AOB, puntero `[+7B3220]`, HP actual/máx./daño del golpe, PV máx. sin escalar |
| Invencibilidad | Script *Invulnerable* | Temporizador (lectura, *Float*) | Interruptor Sí/No |
| One Hit Kill | Sí (nota de sokenbitya en el hilo) | No | ❌ Pendiente (el contador de daño en 7 sitios ya está en las sondas) |
| Prestigio (Kudos) | — | Dirección fija ×160 (en esta build **no existe** fija) | Localizado en el heap por firma; **×1 … ×1024** y «mantener» |
| EXP / Nivel | Dirección + tecla NUM1 (+1000 EXP) / Nivel | Direcciones (otra zona) | Direcciones verificadas + **EXP ×1 … ×1024**; Nivel de solo lectura |
| Créditos | Sí | Sí | Sí (verificado; persiste al guardar) |
| Materiales (28) | Direcciones sueltas | 28 en grupos por estrellas | 28 con nombre ES/EN y estrellas + **«Materiales al máximo»** (pide cantidad, se deshace al desactivar) + etiquetado para comprobar el orden |
| PE / PH / cooldowns | Scripts de infinito + direcciones | Direcciones | Direcciones verificadas (congelar = infinito); se sabe qué copia del bloque manda |
| Tiempo | Tiempo + Tiempo total (tecla NUM3 congela) | Tiempo | Tiempo de nivel + Tiempo total, con su escala |
| Medallas | Sí | Sí | Sí |
| Score | Sí (tecla NUM2 +100 000) | Sí | ❌ No es fijo en esta build |
| Herramientas de diagnóstico | — | — | Verificador en vivo, multisonda, contador de daño, etiquetado de materiales, sonda de invencibilidad |
| Idioma | Inglés | Inglés | Español (inglés pendiente) |
| Resistencia a parches | 1 AOB; el resto se rompe | Se rompe con cada parche (ya roto) | Captura y Prestigio sobreviven (AOB / firma). Los valores fijos llevan el ancla documentada; falta resolverlos por AOB como `sf3_base` en MMSF |

### Lo que todavía hacen mejor las referencias

- **One Hit Kill** e **HP infinito como script** (gv1.CT). Aquí se puede editar el HP y hay invencibilidad, pero no hay un script de HP infinito ni de 1HK.
- **Teclas rápidas** (gv1.CT: NUM1/NUM2/NUM3).
- **Score** editable (las dos referencias, cada una en su build).

### Qué se aprendió (vale para GV2, GV3 y Connect iX)

1. Las direcciones de otra build **no se trasladan con un solo Δ**: en GV1 cada zona se corrió distinto (+0x9078 bloque de partida, +0x9060 puntero al jugador, +0x8FF0 bloque de combate, +0x9000 nivel en curso). Sirven como pista; cada dato se confirma en vivo.
2. Lo que funcionó: localizar un ancla por valor (Créditos), medir el Δ de cada zona y confirmar con **comportamiento** (subir de nivel, recoger una medalla, ganar Prestigio) durante un muestreo largo.
3. Un dato que el juego muestra puede **no existir fijo** en el ejecutable (Prestigio, Score, Puntos totales de GV1): entonces se busca la estructura en el heap y se localiza por firma.
4. Los punteros al objeto jugador se encuentran buscando en el módulo los QWORD que apuntan al objeto ya capturado por la inyección.
