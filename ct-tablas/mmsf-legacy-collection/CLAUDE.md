# CLAUDE.md — Mega Man Star Force Legacy Collection

Estado: ✅ **publicada (v9)**. Tabla original de **wepon1984** ([FearLess t=38738](https://fearlessrevolution.com/viewtopic.php?t=38738)); permiso del autor para publicar la versión modificada (PM del 2026-10-12, respuesta afirmativa).

## Archivos

| Archivo | Rol |
|---|---|
| `build_v9.py` | Genera la v9 ES/EN desde la tabla original (`--lang es|en|base`). Verifica el SHA-256 de la original |
| `build_fearless.py` | Genera `fearless/..._FearLess_EN.CT` (cabecera `[wepon1984] (original author)` + `[Skolleks]`) |
| `i18n.py` | Traducciones (descripciones, listas, textos de scripts). Nombres propios del juego no se traducen |
| `resolvers.json` | Bases `sf12_base` / `sf3_base`: 3 firmas AOB cada una + respaldo estático |
| `*_v9_*_ES.CT`, `*_v9_*_EN.CT` | Tablas publicadas (generadas; no editar a mano) |
| `*_v8_*.CT` | Versión anterior, solo referencia |
| `fearless/` | Tabla para el foro + `POST_bbcode.txt` (sin enlaces externos) |
| `original/FUENTES.md` | De dónde bajar la tabla original y su SHA-256 (el `.CT` original no se versiona) |

La tabla original (SHA-256 `9b1b11a1…59c8`) **no se versiona**: va en `original/MEGAMAN_STARFORCE_Legacy_Collection.CT` (ignorado por git). Restaurada y verificada el 2026-11-08: `build_v9.py` reproduce las v9 ES/EN byte a byte.

## Regenerar

```bash
cd ct-tablas/mmsf-legacy-collection
python build_v9.py original/MEGAMAN_STARFORCE_Legacy_Collection.CT --lang es -o MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_ES.CT
python build_v9.py original/MEGAMAN_STARFORCE_Legacy_Collection.CT --lang en -o MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_EN.CT
python build_fearless.py original/MEGAMAN_STARFORCE_Legacy_Collection.CT
python ../../cheat-engine-tables/scripts/ct_tool.py validate <cada .CT>
```

## Datos verificados en el juego (build 1.0.2.0)

- `sf12_base = exe+DEB4850` (gemelo `+DEB4858`); `sf3_base = exe+DEB7EE0` (gemelo `+DEB7EE8`). Exe empaquetado → firmas desde volcado.
- SF1 jugador `[[[sf12_base+238]+170]+28]`: `+28` HP base, `+2E` HP actual, `+30` desconocido.
- SF3 bloque jugador `[[sf3_base]+1C0]+A8`: `+58` Mr Hertzes (Key Item = moneda de la tienda), `+170` HP+10, `+171` HP+20. HP máx. = 100 + 10a + 20b, tope 1000 (18/36).
- Scripts SF3 (generados por `freeze_script` / `hp_lock_script`): Noise Gauge `[[sf3_base]+190]+38]+2D4` (500–9999), Delete Time `[[sf3_base]+168]+10]+60` = 1.

## Pendiente

- Opcional: contador de Mr. Hertz salvados (otra dirección, solo lectura).
