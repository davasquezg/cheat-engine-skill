# CLAUDE.md — Azure Striker Gunvolt Trilogy Enhanced

Estado: 🧪 **investigación de GV1** (`game1.exe`). Tabla **alfa** `Gunvolt_Trilogy_Enhanced_v0.13-alpha_ES.CT` (no publicada; las anteriores quedan como referencia). GV3 en curso: grupo propio desde la v0.4: GV1 rescatado de la multisonda + candidatas, y GV2/GV3/Connect iX portados de wepon1984. La herramienta de investigación sigue siendo `sondas/multisonda_gv1.CT`.

- Tabla de partida: **ndck1** ([FearLess t=35891](https://fearlessrevolution.com/viewtopic.php?t=35891), v1.1.1 / build 19353876): solo "Health Editor" de GV1. Su AOB `8B ?? 41 3B ?? 45 8B ?? 44 0F` **sigue funcionando** en la build actual.
- Referencias analizadas (en `original/`, local, fuera de git): `gv1.CT` (GV1 32 bits, WarCOzes, t=1929), `gv2.CT` (Shinkansen, t=12924), `gv3.CT` (RTX_XXXX, t=21777) y `trilogy.CT` (**wepon1984**, t=35866, los 4 exe; otra build: ver `ANALISIS_tablas_referencia.md` §8). Falta volver a bajar la de ndck1.
- Documentación: `NOTAS_analisis.md` (auditoría y plan por fases) · `ANALISIS_tablas_referencia.md` (patrones + resultados en vivo, secciones 7.x).

## Juego y build

- Ruta: `C:\Program Files (x86)\Steam\steamapps\common\Azure Striker Gunvolt Trilogy Enhanced`.
- `game.exe` = menú; lanza cada juego como **proceso aparte**. **GV1 = `game1.exe`** (confirmado). GV2/GV3/`game4.exe`: sin mapear.
- Los 5 exe tienen **SteamStub** (`.bind`) → firmas desde volcado (`diag_asgte.lua` guarda `dumps/game1.dmp`). Sin recurso de versión: la build se identifica por TimeDateStamp (`game1.exe` 2026-10-07, SHA-256 `8502cad08098…`).
- **El depurador de CE cierra el juego** → todo se investiga sin depurador (sondas por inyección, muestreo con temporizadores Lua, análisis estático del volcado con capstone).

## Mapa de memoria de GV1 (verificado en vivo, build 2026-10-07)

| Dato | Ubicación | Notas |
|---|---|---|
| Objeto jugador / componente vida | inyección en `F6 47 26 04 74 ?? ×13 45 8B C8 44 0F 4E CD` (+6: `mov rcx,[rdi+3D8]`) → `gv1_player` (rdi), `gv1_hp` ([rdi+3D8]) | componente = objeto + 0x398 |
| HP actual / máx. | `[gv1_hp]+0` / `+4` | ×16 (220 en pantalla = 3520) |
| Marca de jugador | byte `[gv1_hp]+18` = 1 | |
| Invencibilidad | `[gv1_player]+518` = 11520 | ✅ confirmada; interruptor en la multisonda |
| Créditos | `game1.exe+7B3668` | ✅ persiste al guardar |
| Materiales (28) | `Créditos + 0x3B0`, DWORD, orden de gv1.CT | `+0x3A8`/`+0x3AC` NO son materiales |
| Nivel | `Créditos + 0x47C` (2 B) | ✅ subió 31 → 32 (2026-11-08). `+0x474` NO es el nivel |
| EXP total | `Créditos + 0x478` | ✅ (2026-11-08); «EXP ×N» la registra como `gv1_exp`. El juego la copia en `Créditos+0x438` |
| Puntero estático al jugador | `[game1.exe+7B3220]` (también `+7E02F8`, `+7ED630`) | ✅ sigue válido tras recargar la partida (otro objeto). Falta reiniciar el exe |
| PV máx. sin escalar | bloque de combate `+0x2C` = `game1.exe+7ED678` | ✅ +5 por nivel (350 en Nv 31 → 375 en Nv 36), coincide con el menú |
| Medallas del nivel | `game1.exe+7E10DC` | ✅ 1 → 3, igual que la pantalla (v3) |
| Tiempo de nivel / Tiempo total | `game1.exe+7E10D4` / `Créditos − 0xE0` | ✅ ≈ 7660 unidades por segundo (¿60 × 128?). Zona `+7D…`: Δ con wepon1984 = **+0x9000** |
| Score / Kudos estáticos / Puntos totales | — | ❌ no están en `game1.exe` (v3, §8.6); el Prestigio solo existe en el heap (estructura K) |
| Tiempo / Medallas / Score / Kudos / Puntos y Tiempo totales | se buscan con `verificar_candidatas_gv1.lua` v2 (secciones D, D2, E, F) | los Δ de wepon1984 fallaron (§8.4) |
| PE / Skill Points / 4 cooldowns | `game1.exe+7ED64C` / `+4` / `+0xC…+0x18` | ×10 000 / 20 000 000 por punto / 76 800 = lista. Copia en `+7ED67C` que **no manda** (§8.4) |
| Prestigio (Kudos) | heap, estructura K: `K+0` pantalla, `K+4` interno ×256 | ✅ localizada por firma: `K+0x34 = game1.exe+234130`, `K+0x3C = game1.exe+4C470` (compartida por ~214 objetos) + `K−0x14 = 1662` + interno = pantalla×256. `K+0xC` cambia: no usar |
| Rutina de daño | 7 sitios `mov r8,[reg+3D8]` (RVA `90D41`, `91494`, `915FA`, `91899`, `91A8E`, `1A2729`, `1AAB62`) | daño = `[[atacante+4B0]+3D8]+8`. Contador en la multisonda; resultados pendientes |

## Archivos

| Archivo | Rol |
|---|---|
| `diag_asgte.lua` | Diagnóstico inicial: procesos, AOB de ndck1, volcado del módulo a `dumps/` |
| `build_trilogia_alpha.py` | **Genera `Gunvolt_Trilogy_Enhanced_<VERSION>_ES.CT`** (hoy v0.13-alpha). **Cada regeneración con cambios sube `VERSION`** y se conserva el `.CT` anterior; historial en el docstring: reutiliza `gv1_trucos()`/`gv1_sondas()` de la multisonda, agrega las candidatas de GV1 y porta GV2/GV3/Connect iX desde `original/trilogy.CT` (verifica su SHA-256). Un grupo por exe: activarlo adjunta CE a ese exe. Verde = verificado, gris = candidato, naranja = wepon1984 |
| `sondas/autoacople.lua` | **Autoacople** (lo activa el LuaScript de la tabla): detecta `game1…game4.exe`, acopla CE y activa el grupo del juego; se re-acopla al cambiar de juego. Las descripciones de grupo que busca se comprueban al generar la tabla |
| `sondas/gv3.py` · `*_gv3.lua` | Grupo de GV3 de la alfa (`gv3_trucos()`/`gv3_sondas()`): base `game3.exe+1F02FE8`, cámara lenta (`jugador+0x592`, NO es invencibilidad), EXP ×N ❌ (dirección no real; `sonda_exp_gv3.lua`), Prestigio ×N ✅, Kudos bloqueados `[B]+0x2FC` (*float* ✅), Image Chips. Sondas: `sonda_invencibilidad_gv3.lua`, `sonda_kudos_bloqueados_gv3.lua` |
| `sondas/diag_gv3.lua` | **GV3**, primer diagnóstico (solo lectura): build, unicidad de las AOB de RTX_XXXX/wepon1984, cadenas desde la base de wepon1984, barrido de bases con Nivel/Prestigio de pantalla y 5 min de muestreo → `dumps/diag_gv3_<fecha>_<hora>.txt` |
| `sondas/verificar_candidatas_gv1.lua` | Verificación de solo lectura de las candidatas de wepon1984 (§8.1): bloque de partida, puntero estático al jugador, bloque de combate y su copia, Tiempo/Medallas/Score/Kudos con los dos Δ y 2 min de muestreo (EXP y Kudos frente a la pantalla) |
| `sondas/build_multisonda.py` | **Genera `multisonda_gv1.CT`** incrustando los `.lua` de la carpeta. Editar los `.lua` o este script y regenerar; no editar el `.CT` a mano. Expone `gv1_trucos()` y `gv1_sondas()` |
| `sondas/multisonda_gv1.CT` | Tabla de trabajo: grupo **▶ GV1 — Trucos** (captura, invencibilidad, Prestigio ×N, materiales, valores) + **🔧 Sondas** |
| `sondas/kudos_gv1.lua` · `prestigio_mult_gv1.lua` | Localizador del Prestigio por firma + multiplicador/mantener (un solo script de la tabla; factor y «mantener» en listas desplegables `gv1_kudos_mult` / `gv1_kudos_keep`) |
| `sondas/exp_mult_gv1.lua` | EXP ×N independiente; factor en la lista desplegable `gv1_exp_mult` (×1, ×2 … ×1024; cambia en vivo) |
| `sondas/kudos_diag_gv1.lua` | Diagnóstico paso a paso del Prestigio para el Lua Engine (versión 2) |
| `sondas/investigar_direccion_gv1.lua` | Investiga una dirección hallada a mano: tipos, punteros estáticos 1–2 niveles, vecinos, muestreo |
| `sondas/materiales_*.lua` | Máximo de materiales y etiquetado 99…72 (con restauración al desactivar) |
| `sondas/invencible_*.lua` · `sonda_invencibilidad_gv1.lua` | Interruptor de invencibilidad / sonda que la descubrió |
| `sondas/obsoletos/` | Buscadores de valores descartados (no sirven para el Prestigio escalado) |

Los scripts Lua escriben informes en `D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\` (ruta absoluta). Los informes `.txt` se versionan; los volcados `*.dmp` no (ver `dumps/README.md` para regenerarlos). Las tablas de referencia van en `original/` y no se versionan: `original/FUENTES.md` dice de dónde bajarlas y su SHA-256.

```bash
cd ct-tablas/gulvolt-trilogy/sondas
python build_multisonda.py
python ../../../cheat-engine-tables/scripts/ct_tool.py validate multisonda_gv1.CT
cd ..
python build_trilogia_alpha.py          # requiere original/trilogy.CT
python ../../cheat-engine-tables/scripts/ct_tool.py validate Gunvolt_Trilogy_Enhanced_v0.13-alpha_ES.CT
```

## Próximos pasos

Historial de versiones y comparación con gv1.CT / wepon1984: [`CHANGELOG.md`](CHANGELOG.md).

1. **GV3 (`game3.exe`) — objetivo actual** (el usuario saltó GV2): llegar como mínimo a los cheats de GV1. Plan y matriz de paridad en `ANALISIS_tablas_referencia.md` §9; primer paso `sondas/diag_gv3.lua`. Método general abajo (los pasos de GV2 se aplican igual). GV1 quedó en v0.3-alpha (commit `89fac92`).
1b. GV2 (`game2.exe`): después de GV3, con el método de abajo.
2. GV1, pendientes menores: confirmar el puntero `[+7B3220]` tras **reiniciar el exe**; One Hit Kill e HP infinito como script (resultados del contador de daño); resolver las direcciones fijas por AOB (como `sf3_base` en MMSF); versión EN.
3. Connect iX (`game4.exe`) con el mismo método.
4. Versión FearLess: cabecera `[ndck1] (original author)` + `[Skolleks]`, PM a ndck1 y 48 h de espera. Como se usan datos de `trilogy.CT`, acreditar y avisar también a wepon1984.

## Método para pasar al siguiente Gunvolt (aprendido en GV1)

Punto de partida para GV2: el grupo de wepon1984 ya está en la alfa (🟠) y `ANALISIS_tablas_referencia.md` §3 tiene la tabla de Shinkansen (dos AOB que capturan las estructuras, todo lo demás relativo a ellas).

1. **Huella y volcado.** Adjuntar CE a `game2.exe` (confirmar que es GV2) y correr `diag_asgte.lua` para el volcado (SteamStub). Anotar la build (TimeDateStamp, SHA-256) en este archivo. Suponer que el depurador también lo cierra: trabajar sin él.
2. **Probar primero las AOB de Shinkansen** (getter `8B 41 58 99 0F B6 D2 03 C2 C1 F8 08 C3` y suma del Score `01 03 8B 03 3B C1 0F 4F C1 89 03`): si siguen siendo únicas en el volcado (`sigmaker.py check --dump`), dan las dos estructuras sin depender de la build.
3. **Ancla por valor.** Buscar los Créditos de Gunvolt con un escaneo normal y comparar con wepon1984 (`game2.exe+923158`): eso da el Δ del **bloque de partida**. No usar ese Δ para el resto: en GV1 cada zona se corrió distinto (+0x9078, +0x9060, +0x8FF0, +0x9000).
4. **Verificador para GV2.** Copiar `sondas/verificar_candidatas_gv1.lua` como `verificar_candidatas_gv2.lua`: cambiar `MOD`, las anclas y la lista `C` (direcciones de wepon1984 + Δ por zona y los Δ relativos de Shinkansen en §3). Mantener las búsquedas por valor (Kudos ×1/×160/×256, Medallas, Totales del menú), el escaneo «aumentó» para el Tiempo y la búsqueda de punteros al objeto jugador. Muestreo de 5 min jugando, con valores de pantalla al inicio y al final.
5. **Particularidades de GV2** (de las referencias, por confirmar): dos personajes (Gunvolt y Copen) con Créditos, EXP, Nivel y materiales **separados**; materiales de **1 byte** (24, con otro orden que GV1); HP y Kudos ×160; EP en punto fijo 24.8; objeto jugador con HP en `+420` e invencibilidad en `+598` (wepon1984), no `+398`/`+518` como GV1. El SP de Gunvolt solo se escribe jugando con Gunvolt (si no, el juego se cuelga, según Shinkansen).
6. **Tabla.** Crear `sondas/build_multisonda_gv2.py` (o funciones `gv2_trucos()` / `gv2_sondas()`), reemplazar en `build_trilogia_alpha.py` el grupo 🟠 de GV2 por el verificado, **subir la versión** de la alfa y anotar el cambio en `CHANGELOG.md`.
7. **Reglas que se mantienen:** editar desde el mapa sin menús abiertos; desactivar los scripts antes de recargar la tabla; guardar cada informe en `dumps/` con versión y fecha, junto con lo que el usuario vio en pantalla.
