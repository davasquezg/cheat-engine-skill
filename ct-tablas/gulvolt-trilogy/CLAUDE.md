# CLAUDE.md — Azure Striker Gunvolt Trilogy Enhanced

Estado: 🧪 **investigación de GV1** (`game1.exe`). Aún no hay tabla publicada; la herramienta de trabajo es `sondas/multisonda_gv1.CT`.

- Tabla de partida: **ndck1** ([FearLess t=35891](https://fearlessrevolution.com/viewtopic.php?t=35891), v1.1.1 / build 19353876): solo "Health Editor" de GV1. Su AOB `8B ?? 41 3B ?? 45 8B ?? 44 0F` **sigue funcionando** en la build actual.
- Referencias analizadas (en `original/`, local, fuera de git): GV1 32 bits de WarCOzes (t=1929), GV2 de Shinkansen (t=12924), GV3 de RTX_XXXX (t=21777). Pendiente: tabla de la trilogía de **wepon1984** (t=35866).
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
| Nivel? | `Créditos + 0x474` (2 B) | sin verificar |
| PE / Skill Points / 4 cooldowns | `game1.exe+7ED64C` / `+4` / `+0xC…+0x18` | ×10 000 / 20 000 000 por punto / 76 800 = lista. Copia idéntica en `+7ED67C`: falta saber cuál manda |
| Prestigio (Kudos) | heap, estructura K: `K+0` pantalla, `K+4` interno ×256 | ✅ localizada por firma: `K+0x34 = game1.exe+234130`, `K+0x3C = game1.exe+4C470` (compartida por ~214 objetos) + `K−0x14 = 1662` + interno = pantalla×256. `K+0xC` cambia: no usar |
| Rutina de daño | 7 sitios `mov r8,[reg+3D8]` (RVA `90D41`, `91494`, `915FA`, `91899`, `91A8E`, `1A2729`, `1AAB62`) | daño = `[[atacante+4B0]+3D8]+8`. Contador en la multisonda; resultados pendientes |

## Archivos

| Archivo | Rol |
|---|---|
| `diag_asgte.lua` | Diagnóstico inicial: procesos, AOB de ndck1, volcado del módulo a `dumps/` |
| `sondas/build_multisonda.py` | **Genera `multisonda_gv1.CT`** incrustando los `.lua` de la carpeta. Editar los `.lua` o este script y regenerar; no editar el `.CT` a mano |
| `sondas/multisonda_gv1.CT` | Tabla de trabajo: grupo **▶ GV1 — Trucos** (captura, invencibilidad, Prestigio ×N, materiales, valores) + **🔧 Sondas** |
| `sondas/kudos_gv1.lua` · `multiplicador_gv1.lua` | Localizador del Prestigio por firma + multiplicador/mantener (combinados en un solo script de la tabla) |
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
```

## Próximos pasos

1. GV1: ubicar EXP, puntuación y tiempo; decidir cuál copia del bloque de combate manda; resultados del contador de daño → One Hit Kill.
2. Construir la tabla definitiva de GV1 (ES/EN) con `build_*.py`, resolviendo las direcciones estáticas por AOB (como `sf3_base` en MMSF).
3. Mapear `game2.exe` / `game3.exe` / `game4.exe` y repetir para GV2 y GV3.
4. Versión FearLess: cabecera `[ndck1] (original author)` + `[Skolleks]`, PM a ndck1 y 48 h de espera.
