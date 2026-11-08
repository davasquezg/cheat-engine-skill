# Tablas de referencia (de terceros) — cómo recuperarlas

Estos `.CT` **no se versionan** (están en `.gitignore`): son obra de sus autores y sus hilos piden no
repostearlas fuera de FearLess Revolution. Descárgalos con tu cuenta y guárdalos en esta carpeta con el
nombre indicado. El SHA-256 permite comprobar que es la misma revisión que se analizó.

| Guardar como | Juego | Autor | Hilo / adjunto | SHA-256 |
|---|---|---|---|---|
| `A.S.G.T.E v1.1.1frf.CT` | Trilogy Enhanced v1.1.1 (GV1 Health Editor) | ndck1 | [t=35891](https://fearlessrevolution.com/viewtopic.php?t=35891) → `A.S.G.T.E v1.1.1frf.CT` (3,7 KiB) | `66210926e775951e8b06b3aa79de75c59f9571880720121a3affebd85d6cc49f` |
| `gv1.CT` | GV1 Steam, 32 bits | WarCOzes | [t=1929](https://fearlessrevolution.com/viewtopic.php?f=4&t=1929) → `gv_win.CT` Ver.20200917 (22 KiB) | `1c7ec29dceae1fbd…` (prefijo registrado) |
| `gv2.CT` | GV2 v1.0, 64 bits | Shinkansen | [t=12924](https://fearlessrevolution.com/viewtopic.php?t=12924) → `Shinkansen Azure Striker Gunvolt 2 V1001.CT` (171 KiB) | `33d56bdad5f43a32…` (prefijo registrado) |
| `gv3.CT` | GV3, 64 bits | RTX_XXXX | [t=21777](https://fearlessrevolution.com/viewtopic.php?t=21777) → `Azure Striker Gunvolt 3(Update1.1).CT` (538 KiB) | `b6de255160662972…` (prefijo registrado) |
| *(pendiente)* | Trilogy Enhanced (los 3 juegos) | wepon1984 | [t=35866](https://fearlessrevolution.com/viewtopic.php?t=35866) → `Azure Striker Gunvolt Trilogy Enhanced.CT` (132 KiB) | — |

Comprobar en PowerShell:

```powershell
Get-FileHash .\*.CT -Algorithm SHA256
```

Lo que se aprendió de estas tablas ya está documentado en `../ANALISIS_tablas_referencia.md`, así que el
proyecto puede continuar aunque falten; solo hacen falta para volver a comparar.

**Respaldo recomendado:** guarda una copia de esta carpeta fuera del repositorio (p. ej. en el NAS), porque
git no la protege.
