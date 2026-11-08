# Tabla original (de terceros) — cómo recuperarla

`MEGAMAN_STARFORCE_Legacy_Collection.CT` **no se versiona** (`.gitignore`): es obra de **wepon1984**.
Es la entrada de `../build_v9.py` y `../build_fearless.py`.

| Guardar como | Autor | Hilo | SHA-256 |
|---|---|---|---|
| `MEGAMAN_STARFORCE_Legacy_Collection.CT` | wepon1984 | [FearLess t=38738](https://fearlessrevolution.com/viewtopic.php?t=38738) | `9b1b11a1f01b0495ed149fa8668dd33f4446b8ab3cb898ae8c602b9c752459c8` |

```powershell
Get-FileHash .\MEGAMAN_STARFORCE_Legacy_Collection.CT -Algorithm SHA256
cd ..
python build_v9.py original\MEGAMAN_STARFORCE_Legacy_Collection.CT --lang es -o MEGAMAN_STARFORCE_Legacy_Collection_v9_AOB_build1.0.2.0_ES.CT
```

**Respaldo recomendado:** copia esta carpeta fuera del repositorio (NAS), porque git no la protege.
