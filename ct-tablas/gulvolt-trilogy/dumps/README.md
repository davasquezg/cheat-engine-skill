# dumps/ — salidas de las sondas

Carpeta de trabajo donde los scripts Lua escriben sus resultados (ruta absoluta
`D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\`).

| Archivo | Lo genera | ¿Se versiona? |
|---|---|---|
| `game1.dmp` (y `game2.dmp`…) | `../diag_asgte.lua` (volcado del módulo con `writeRegionToFile`) | **No** (`*.dmp` en `.gitignore`: es código del juego) |
| `resultados_multisonda_gv1.txt` | Multisonda (bloques de partida y combate) | Sí |
| `resultados_invencibilidad_gv1.txt` | Sonda de invencibilidad | Sí |
| `investigar_direccion.txt` | `../sondas/investigar_direccion_gv1.lua` | Sí |
| `verificar_candidatas_gv1_v3_<fecha>_<hora>.txt` | `../sondas/verificar_candidatas_gv1.lua` v3 (un archivo por corrida) | Sí |
| `verificar_candidatas_gv1_v2_2026-11-08.txt` | Corrida v2 (punteros tras recargar, PV máx., pistas de Tiempo/Kudos) | Sí |
| `verificar_candidatas_gv1_v1_2026-11-08.txt` | Corrida v1 + observaciones del usuario (ANALISIS §8.4) | Sí |
| `verificar_candidatas_gv1_v1b_2026-11-08.txt` | Segunda corrida v1 (Prestigio 1902 → 2620) | Sí |
| `kudos_diag.txt` | `../sondas/kudos_diag_gv1.lua` (se va agregando cada paso) | Sí |

## Regenerar el volcado de `game1.exe`

1. Abre GV1 desde el menú de la colección y entra a un nivel.
2. Adjunta Cheat Engine a **`game1.exe`** (no a `game.exe`, que es el menú).
3. Memory View → Tools → Lua Engine → pega `../diag_asgte.lua` → Execute.
4. Debe quedar `dumps\game1.dmp` (≈ 17 MB, tamaño del módulo `0x1149000`).

Con el volcado, las firmas se analizan así:

```bash
python ../../../cheat-engine-tables/scripts/sigmaker.py peinfo game1.dmp --dump
```

Los resultados ya obtenidos (direcciones, offsets, firmas) están en `../CLAUDE.md` y
`../ANALISIS_tablas_referencia.md`, así que perder esta carpeta no pierde el trabajo hecho.
