# MMSF Legacy Collection — tabla v8 (build 1.0.2.0)

**Tabla lista para usar:** `MEGAMAN_STARFORCE_Legacy_Collection_v8_AOB_build1.0.2.0.CT`.

Opcional: reprodúcela desde la **tabla original** de FearLess Revolution con el parche:

```bash
# 1) Descarga la original: https://fearlessrevolution.com/viewtopic.php?t=38738
# 2) Aplica el parche (desde esta carpeta)
python build_v8.py MEGAMAN_STARFORCE_Legacy_Collection.CT -o MMSF_LC_v8.CT
python ../../cheat-engine-tables/scripts/ct_tool.py validate MMSF_LC_v8.CT
```

- **Tabla original esperada (SHA-256):** `9b1b11a1f01b0495ed149fa8668dd33f4446b8ab3cb898ae8c602b9c752459c8`. Si el autor publicó otra revisión, el script avisa. Con `--force` puedes intentar igual, pero los IDs podrían no coincidir.
- **Verificación:** el resultado es idéntico, en contenido, a la tabla v8 validada en el juego el 2026-10-12.
- **`resolvers.json`:** contiene las bases y firmas AOB de la build 1.0.2.0. Si el juego se actualiza y las firmas fallan, regenera las firmas con `sigmaker.py` (ver la skill) y vuelve a ejecutar el parche.

## Qué cambia respecto de la original

| Área | Cambio |
|---|---|
| Bases | `[Resolver]` con 3 firmas AOB por base y respaldo estático; los grupos de los juegos quedan anidados bajo él |
| SF1 | "HP actual" (+2E), nueva entrada "HP base" (+28) y el campo +30 marcado como desconocido |
| Cartas | Notas "editar solo desde el mapa", mapa de bytes por borde y aviso en el grupo "5. All" |
| SF2 | "Gorgon Eye" duplicado marcado como sin verificar |
| SF3 Battle | Submenú **Noise Gauge** cuya cabecera es un script (valor fijo, entre 500 y 9999) y submenú **Delete Time** (fijo en 1) |
