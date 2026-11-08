# Azure Striker Gunvolt Trilogy Enhanced — análisis preliminar

> Estado: **preliminar**. Nada validado aún en el juego.

## Fuente

| Dato | Valor |
|---|---|
| Hilo FearLess | <https://fearlessrevolution.com/viewtopic.php?t=35891> — publicado 2025-07-28 por **ndck1** (en el script figura «ndck76») |
| Juego | *Azure Striker Gunvolt Trilogy Enhanced* — Steam app 3813350 |
| Tabla original | `original/A.S.G.T.E v1.1.1frf.CT` (no se versiona; ver `.gitignore`) |
| SHA-256 | `66210926e775951e8b06b3aa79de75c59f9571880720121a3affebd85d6cc49f` |
| Autor del script | **ndck76** (según la cabecera del script) |
| Versión objetivo | Juego **v1.1.1 / Build 19353876**, script del 2025-07-29. El post anuncia Health Editor (GV1 y GV2) y Skills No Cooldown (GV3), pero el archivo adjunto solo trae GV1. Un usuario pidió actualizarla a **v1.2.1** (2026-01-14), sin respuesta |
| CE | `CheatEngineTableVersion="45"` (CE 7.5+) |

## Tablas de referencia en FearLess (leídas el 2026-11-01)

| Hilo | Juego / versión | Autor | Adjuntos | Aporte para el patrón |
|---|---|---|---|---|
| [t=35866](https://fearlessrevolution.com/viewtopic.php?t=35866) | **Trilogy Enhanced** (hilo [REQUEST]) | **wepon1984**, 2026-03-24 | `Azure Striker Gunvolt Trilogy Enhanced.CT` (132 KB) | «Colección de punteros y scripts» para los 3 juegos: Skill Point GV2 corregido, Fetters Gauge GV3; quitó los punteros de talismanes de GV3 porque **congelarlos cierra el juego al cambiar a Gunvolt**. Es la base más cercana a nuestra build |
| [t=1929](https://fearlessrevolution.com/viewtopic.php?t=1929) | GV1 Steam (388800), builds 766242 → 1535920, Ver.20200917 | WarC0zes / WarCOzes | `gv_win.CT` (22 KB) | Exe **`gv_win.exe` de 32 bits** (`[ebp-50]`): los AOB no sirven tal cual, pero sí la lógica. Inf. Health, Invulnerable, Inf. Electric Field, Inf. Skill Points, No Skill Cooldown, punteros y lista de materiales. Nota de sokenbitya: One Hit Kill cambiando `test eax,eax` → `cmp eax,eax` tras `sub eax,[ebp-5C]` (daño) |
| [t=12924](https://fearlessrevolution.com/viewtopic.php?t=12924) | GV2 v1.0 64 bits, V1001 (2020-06-28) | Shinkansen | `Shinkansen Azure Striker Gunvolt 2 V1001.CT` (171 KB) | Estructuras: HP, Weapon Gauge/EP/Bullit, Gunvolt SP, Score, Time, Kudos, Subroutines/Gear ID y EXP, Materials y Credits de Copen y de Gunvolt, EXP/LV, Memory, Tries. Usa «Base Address Scan» |
| [t=12893](https://fearlessrevolution.com/viewtopic.php?t=12893) | GV2 (2020-06) | astor; MBRKiNG | `Azure Striker Gunvolt 2.CT` (37 KB, requiere I2CETableCEA); `GV2.CT` (16 KB) | Instant kill, energía y SP infinitos; no cooldown, sin límite de capacidad, ítems (abrir menú de venta), bonus round |
| [t=21777](https://fearlessrevolution.com/viewtopic.php?t=21777) | GV3 (2022-10 → 2.0.1) | RTX_XXXX; Algester | `Azure Striker Gunvolt 3(Update1.1).CT` (538 KB); `Gunvolt3.ct` (7 KB) | Invencible, HP máx., 1 hit kill, talismán infinito, high score. Algester: **desde la actualización, depurar GV3 lo cierra** (posible anti-debug / leaderboard) → evitar "Find out what writes" con el depurador por defecto; probar VEH o kernel debugger |
| [t=23480](https://fearlessrevolution.com/viewtopic.php?t=23480) | GV3 | Sinclair1 | Trainer externo (Cheat Evolution) | Solo lista de opciones: Kudos multiplier, HP, Instant Kill, Money, No Kudos Lock, Fetters Gauge, No Skill Cooldown |

Otros datos: motor propio de **Inti Creates** (no Unity/Mono). VampTY (t=35866) dice que en la colección la mayoría de los valores están en **direcciones estáticas** → candidato a resolver por AOB + base estática, como en MMSF.

## Instalación local (leída el 2026-11-01)

Ruta: `C:\Program Files (x86)\Steam\steamapps\common\Azure Striker Gunvolt Trilogy Enhanced` (9,1 GB).

| Ejecutable | TimeDateStamp (UTC) | SizeOfImage | SHA-256 (12) |
|---|---|---|---|
| `game.exe` | 2026-10-06 01:32 | 0x643000 | `eb3ce723d764` |
| `game1.exe` — **GV1** (confirmado 2026-11-01) | 2026-10-07 01:27 | 0x1149000 | `8502cad08098` |
| `game2.exe` | 2026-10-05 01:46 | 0xC4C000 | `eda03e440046` |
| `game3.exe` | 2026-10-13 07:25 | 0x2130000 | `a2352d3d7287` |
| `game4.exe` | 2026-10-14 08:41 | 0x1FD5000 | `b3e137fac125` |

- **Cinco ejecutables**, no tres. **Confirmado por el usuario (2026-11-01): `game.exe` es el menú y lanza cada juego como un proceso aparte (`gameN.exe`).** Consecuencias para la tabla: (a) CE debe adjuntarse al proceso hijo, no al menú; (b) al volver al menú el proceso del juego termina y se pierden inyecciones y símbolos → cada grupo de juego necesita su propio «Enable» que se adjunte al `gameN.exe` correcto (como hace ndck1 con `OpenProcess("game1.exe")`), idealmente detectando cuál está corriendo; (c) nunca dejar scripts activos al cambiar de juego. Cuál `gameN.exe` corresponde a cada juego **está sin verificar** (hay `Data0`…`Data3` y `DataAddon`).
- **Sin recurso de versión** (FileVersion vacío): la versión se identifica por TimeDateStamp/SHA-256.
- **SteamStub (sección `.bind`, `.text` con entropía 8,0)** en los cinco: el código está cifrado en disco. Las firmas AOB deben generarse desde un **volcado de memoria** (`sigmaker.py --dump`), igual que en MMSF. `diag_asgte.lua` guarda ese volcado en `dumps/` (ignorado por git).
- Los ejecutables son de **octubre de 2026**; la tabla original apunta a la **v1.1.1 (julio de 2025)**. **Verificado por el usuario (2026-11-01): el Health Editor de ndck1 SIGUE funcionando en `game1.exe`** → el AOB `8B ?? 41 3B ?? 45 8B ?? 44 0F` sobrevivió a las actualizaciones y es buen punto de partida.
- `gv1.CT` (WarCOzes, 32 bits) **no funciona** en la Trilogy (confirmado): solo sirve como mapa de patrones.

## Contenido de la tabla original

```
Caution: DO NOT freeze any pointers when the game is loading      (cabecera)
└─ Azure Striker Gunvolt 1                                         (grupo, moHideChildren)
   └─ Enable                    [AA + Lua: OpenProcess("game1.exe")]
      └─ Health Editor          [AA: inyección por AOB]
         └─ Max Health          4 Bytes  [data]+4
More CHEATS AVAILABLE HERE      [AA con Lua: abre modengine.net]
<LuaScript> de tabla            muestra el mismo aviso al cargar la tabla
```

Es decir, **solo hay una trampa (HP) y solo para Gunvolt 1**. *Gunvolt 2* y *Gunvolt 3* no tienen nada.

## Hallazgos (auditoría estática)

1. **Lua de tabla publicitario.** `<LuaScript>` se ejecuta al abrir la tabla (si el usuario acepta) y ofrece abrir `modengine.net` con `shellExecute`. La entrada "More CHEATS AVAILABLE HERE" hace lo mismo. No aporta nada a la tabla: en nuestra versión se elimina.
2. **`{$lua}` sin `{$asm}` de cierre** en "More CHEATS…" (aviso de `ct_tool validate`). Se elimina junto con lo anterior.
3. **AOB con comodines finos:** `8Bxx413Bxx458Bxx440F` = `8B ?? 41 3B ?? 45 8B ?? 44 0F`.
   - Parece `mov r32,[r+disp8]` / `cmp eax,[r+..]` / `mov r32,[r+..]` / inicio de `cmovcc`. Hay que **confirmar en vivo que es única** en `game1.exe` y ver qué instrucciones toca.
   - La inyección copia los **5 primeros bytes** con `readmem(hp1,5)`. Si esos 5 bytes cortan una instrucción o incluyen algo relativo a RIP, el código reubicado falla → revisar el desensamblado.
4. **`data` = `rcx`** capturado en la inyección; "Max Health" lee `[data]+4`. Falta saber:
   - si `+4` es HP máximo o HP actual (el nombre dice "Max", pero no se ha verificado);
   - dónde está el HP actual (probablemente `+0` o vecino).
5. **`OpenProcess("game1.exe")`** en "Enable": cada juego del recopilatorio corre en un ejecutable propio (`game1.exe`, y presumiblemente `game2.exe` / `game3.exe` — **sin verificar**). Una tabla para la trilogía tiene que manejar los tres procesos.
6. **Aviso "no congelar al cargar"**: típico de punteros capturados por inyección; al cambiar de escena `data` puede quedar apuntando a memoria liberada.

## Plan de trabajo

| Fase | Tarea | Estado |
|---|---|---|
| 0 | Carpeta, análisis, script de diagnóstico | ✅ |
| 1 | Conectar la carpeta de instalación del juego (versión del exe, nombres `game*.exe`) | ✅ GV1 = `game1.exe`; falta GV2/GV3 |
| 1b | Análisis de las tablas individuales de GV1/GV2/GV3 → `ANALISIS_tablas_referencia.md` | ✅ |
| 2 | En vivo (GV1): ejecutar `diag_asgte.lua` → unicidad del AOB, desensamblado, valores en `[data]+0..+10` | ✅ volcado + estructura de vida |
| 2b | Multisonda sin depurador (`sondas/multisonda_gv1.CT`): captura del jugador, contador de daño, bloques de partida/combate de gv1.CT, invencibilidad | ✅ |
| 3 | Mapear campos de GV1 (HP actual / máx., EP/prevasión, Kudos, Credits, etc.) | 🟡 HP, invencibilidad, créditos, materiales, PE/SP/cooldowns y Prestigio ✅; faltan EXP, score, tiempo, copia del bloque de combate y One Hit Kill |
| 4 | Repetir para GV2 y GV3 | ⏳ |
| 5 | Construir la tabla propia (ES/EN) con la skill: inyecciones por AOB robustas, scripts de valor fijo, sin Lua publicitario | ⏳ |
| 6 | Versión compatible con FearLess (cabecera `[ndck1] (original author)` + `[Skolleks]`), PM al autor y espera de 48 h | ⏳ |

## Pendiente de confirmar con el usuario / en el juego

- Qué `gameN.exe` corresponde a GV2 y GV3 (y qué es el quinto). GV1 = `game1.exe` ✅.
- Descargar la tabla de wepon1984 (t=35866) a `original/` para comparar patrones (las de GV1/GV2/GV3 individuales ya se analizaron).
- Qué trampas se quieren por juego.
