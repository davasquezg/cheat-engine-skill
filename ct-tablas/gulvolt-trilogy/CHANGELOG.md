# Changelog — Azure Striker Gunvolt Trilogy Enhanced (tabla de Skolleks)

Tabla en desarrollo: `Gunvolt_Trilogy_Enhanced_<versión>_ES.CT`, generada por `build_trilogia_alpha.py` (no se edita a mano). Cada versión anterior se conserva en esta carpeta como referencia.
Build del juego: `game1.exe` del 2026-10-07 (SHA-256 `8502cad08098…`). Leyenda de la tabla: 🟢 verificado en vivo · ⚪ candidato · 🟠 portado de wepon1984 sin verificar.

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
