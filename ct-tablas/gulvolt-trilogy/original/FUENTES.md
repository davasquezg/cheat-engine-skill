# Tablas de referencia (de terceros) — cómo recuperarlas

Estos `.CT` **no se versionan** (están en `.gitignore`): son obra de sus autores y sus hilos piden no
repostearlas fuera de FearLess Revolution. Descárgalos con tu cuenta y guárdalos en esta carpeta con el
nombre indicado. El SHA-256 permite comprobar que es la misma revisión que se analizó.

| Guardar como | Juego | Autor | Hilo / adjunto | SHA-256 |
|---|---|---|---|---|
| `A.S.G.T.E v1.1.1frf.CT` | Trilogy Enhanced v1.1.1 (GV1 Health Editor) | ndck1 | [t=35891](https://fearlessrevolution.com/viewtopic.php?t=35891) → `A.S.G.T.E v1.1.1frf.CT` (3,7 KiB) | `66210926e775951e8b06b3aa79de75c59f9571880720121a3affebd85d6cc49f` |
| `gv1.CT` | GV1 Steam, 32 bits | WarCOzes | [t=1929](https://fearlessrevolution.com/viewtopic.php?f=4&t=1929) → `gv_win.CT` (26 928 B, CT v26, 57 entradas) | `199105cf4b6429d0562058132f199e10cf3141df508aad7545e5b378fb48d471` ⚠️ |
| `gv2.CT` | GV2 v1.0, 64 bits | Shinkansen | [t=12924](https://fearlessrevolution.com/viewtopic.php?t=12924) → `Shinkansen Azure Striker Gunvolt 2 V1001.CT` (174 926 B) | `33d56bdad5f43a329003430f9ebdf6b7ca7f326fde46863921d0193e3e804b2c` |
| `gv3.CT` | GV3, 64 bits | RTX_XXXX | [t=21777](https://fearlessrevolution.com/viewtopic.php?t=21777) → `Azure Striker Gunvolt 3(Update1.1).CT` (550 589 B) | `b6de255160662972d9a59f207348cbe4ad2f06b1cd5ffa77cb3ef89c03c28856` |
| `trilogy.CT` | Trilogy Enhanced (GV1, GV2, GV3 y Connect iX) | wepon1984 | [t=35866](https://fearlessrevolution.com/viewtopic.php?t=35866) → `Azure Striker Gunvolt Trilogy Enhanced.CT` (135 160 B, CT v46, 382 entradas) | `395928fcaeaf2241b414dc706a7d9d7e8d926af0f59f6cdf3d6898a0c3bab0fd` |

⚠️ **`gv1.CT`:** el archivo bajado el 2026-11-08 **no es la revisión analizada antes** (`Ver.20200917`, 22 KiB, SHA-256 `1c7ec29dceae1fbd…`).
Las direcciones están corridas (Credits en `gv_win.exe+BD4F9C` en vez de `+BE0204`), pero el bloque guardado
mantiene la misma forma relativa (materiales en `+0x3A8`, EXP en `+0x470`). Para este proyecto da igual, porque
del juego de 32 bits solo se aprovechan los offsets relativos y la lógica de los scripts.

Faltante: la tabla de **ndck1** `A.S.G.T.E v1.1.1frf.CT` (t=35891), que no se volvió a descargar.

Descargadas y renombradas el 2026-11-08.

Comprobar en PowerShell:

```powershell
Get-FileHash .\*.CT -Algorithm SHA256
```

Lo que se aprendió de estas tablas ya está documentado en `../ANALISIS_tablas_referencia.md`, así que el
proyecto puede continuar aunque falten; solo hacen falta para volver a comparar.

**Respaldo recomendado:** guarda una copia de esta carpeta fuera del repositorio (p. ej. en el NAS), porque
git no la protege.
