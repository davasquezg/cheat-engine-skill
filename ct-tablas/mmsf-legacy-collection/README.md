# MMSF Legacy Collection — tabla v9 (build 1.0.2.0)

**Español** · [English](README.en.md)

**Tablas listas para usar:**

| Idioma | Archivo |
|---|---|
| Español | `MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_ES.CT` |
| Inglés | `MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_EN.CT` |

**Novedad de la v9:** submenú **Mejoras de HP** en SF3 (script de HP máximo 1000 con cantidades fijas + edición manual). La v8 (`..._v8_..._ES.CT` / `_EN.CT`) se conserva en esta carpeta como referencia.

Las dos usan las mismas direcciones, bases y scripts. Solo cambian las etiquetas, notas y mensajes. Los nombres propios del juego (cartas, habilidades, objetos) se mantienen como en la tabla original.

Opcional: reprodúcelas desde la **tabla original** de FearLess Revolution con el parche:

```bash
# 1) Descarga la original: https://fearlessrevolution.com/viewtopic.php?t=38738
# 2) Aplica el parche (desde esta carpeta)
python build_v9.py MEGAMAN_STARFORCE_Legacy_Collection.CT --lang es    # español
python build_v9.py MEGAMAN_STARFORCE_Legacy_Collection.CT --lang en    # inglés
python ../../cheat-engine-tables/scripts/ct_tool.py validate MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_ES.CT
```

- **Tabla original esperada (SHA-256):** `9b1b11a1f01b0495ed149fa8668dd33f4446b8ab3cb898ae8c602b9c752459c8`. Si el autor publicó otra revisión, el script avisa. Con `--force` puedes intentar igual, pero los IDs podrían no coincidir.
- **Verificación:** las direcciones, offsets y tipos de ambas versiones son idénticos a los de la tabla v8 validada en el juego el 2026-10-12; la v9 solo agrega el submenú Mejoras de HP (fórmula y tope de 1000 validados en el juego).
- **`resolvers.json`:** contiene las bases y firmas AOB de la build 1.0.2.0. Si el juego se actualiza y las firmas fallan, regenera las firmas con `sigmaker.py` (ver la skill) y vuelve a ejecutar el parche.
- **`i18n.py`:** contiene las traducciones. Para corregir o agregar un texto, edítalo ahí y vuelve a generar las tablas.

- **Referencia:** cada tabla trae el enlace al repositorio y el crédito a wepon1984 en una nota `##` al inicio y en *Table Extras → Comments* de Cheat Engine. La versión para FearLess (`fearless/`) no incluye enlaces externos, como piden las reglas del foro.

## Qué cambia respecto de la original

| Área | Cambio |
|---|---|
| Bases | `[Resolver]` con 3 firmas AOB por base y respaldo estático; los grupos de los juegos quedan anidados bajo él |
| SF1 | "HP actual" (+2E), nueva entrada "HP base" (+28) y el campo +30 marcado como desconocido |
| Cartas | Notas "editar solo desde el mapa", mapa de bytes por borde y aviso en el grupo "5. All" |
| SF2 | "Gorgon Eye" duplicado marcado como sin verificar |
| SF3 Batalla | Submenú **Noise Gauge** cuya cabecera es un script (valor fijo, entre 500 y 9999) y submenú **Delete Time** (fijo en 1) |
| SF3 HP | Submenú **Mejoras de HP** cuya cabecera es un script: pide un HP máximo objetivo (100–1000, por defecto **1000** = 18 × +10 / 36 × +20) y mantiene fijas ambas cantidades; dentro quedan las entradas para edición manual. Fórmula `100 + 10×(+10) + 20×(+20)`, **tope de 1000 HP** (validado en el juego) |
| SF3 | "Mr Hertzes" marcado: el valor se mantiene pero no afecta al juego |
| Idiomas | Versiones en español e inglés generadas desde `i18n.py` |
