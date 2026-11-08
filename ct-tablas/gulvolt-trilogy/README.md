# Azure Striker Gunvolt Trilogy Enhanced — tabla en desarrollo (alfa)

**Español** · [English](README.en.md)

> 🚧 **Alfa.** `Gunvolt_Trilogy_Enhanced_v0.8-alpha_ES.CT`: GV1 verificado en vivo; GV3 en curso (grupo propio, datos verificados y trucos por probar); GV2 y Connect iX portados de la tabla de wepon1984 sin verificar. Cambios y comparación con las tablas de referencia: [`CHANGELOG.md`](CHANGELOG.md).

Proyecto para crear una tabla de Cheat Engine para *Azure Striker Gunvolt Trilogy Enhanced* (Steam), que cubra los tres juegos. Toma como punto de partida la tabla de **ndck1** (firma «ndck76» en el script) publicada en [FearLess Revolution (t=35891)](https://fearlessrevolution.com/viewtopic.php?t=35891).

| Archivo | Contenido |
|---|---|
| `CHANGELOG.md` | Historial de versiones de la alfa y comparación con gv1.CT (WarCOzes) y la tabla de wepon1984 |
| `build_trilogia_alpha.py` | Generador de la tabla alfa (`Gunvolt_Trilogy_Enhanced_<versión>_ES.CT`) |
| `NOTAS_analisis.md` | Auditoría de la tabla original y plan de trabajo |
| `ANALISIS_tablas_referencia.md` | Patrones de las tablas de GV1, GV2 y GV3 individuales |
| `diag_asgte.lua` | Script de diagnóstico para la consola Lua de Cheat Engine (solo lectura) |
| `sondas/` | Multisonda de GV1 sin depurador (`multisonda_gv1.CT`, scripts Lua y generador). Grupo **▶ GV1 — Trucos**: invencibilidad, Prestigio ×N / mantener, materiales al máximo, créditos, PE, PH y cooldowns |
| `CLAUDE.md` | Estado del proyecto, mapa de memoria verificado y próximos pasos (para Claude Code / Cowork) |

La tabla original **no se incluye** en el repositorio. Descárgala desde su hilo.

Solo para juego offline / un jugador. Licencias y créditos: ver [`LICENSE`](../../LICENSE), [`LICENSE-docs`](../../LICENSE-docs) y [`CREDITS.md`](../../CREDITS.md).
