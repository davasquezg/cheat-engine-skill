# Flujo en vivo: recuperar bases rotas tras un parche

Requisitos: Windows, Cheat Engine 7.5 o superior, el juego en ejecución (offline / un jugador) y `lua/ct_helpers.lua` accesible.

## 0. Identificar la build

```powershell
# Steam: BuildID del juego (el nombre del manifiesto depende del AppID)
Select-String -Path "C:\Program Files (x86)\Steam\steamapps\appmanifest_*.acf" -Pattern '"name"|"buildid"'
# Huella del ejecutable
python scripts\sigmaker.py peinfo "...\MEGAMAN_STARFORCE_Legacy_Collection.exe"
```
Guarda SHA-256, TimeDateStamp y BuildID. Si `peinfo` avisa de **POSIBLE EMPAQUETADO/DRM**, el análisis estático del `.exe` no va a servir y hay que trabajar sobre un volcado (paso 4b).

## 1. Ver qué se rompió (offline)

```bash
python scripts/ct_tool.py info  tabla.CT          # anclas y número de dependientes
python scripts/ct_tool.py chains tabla.CT --filter zenny
```
Elige un **valor ancla** por cada base: fácil de leer en pantalla, estable y de 4 bytes (dinero, HP fuera de combate). En MMSF:

| Base | Valor ancla | Cadena (orden de aplicación) |
|---|---|---|
| SF1 (`sf12_base`) | Zenny SF1 | `[[[B]+238]+70]+70` → `{0x238,0x70,0x70}` |
| SF2 (`sf12_base`) | Zenny SF2 | `[[[B]+240]+70]+70` → `{0x240,0x70,0x70}` |
| SF3 (`sf3_base`)  | Zenny SF3 | `[[[B]+1C0]+A8]+14` → `{0x1C0,0xA8,0x14}` |

`B` es la base estática (`modulo+RVA`) que hay que encontrar.

## 2. Encontrar la dirección actual del valor ancla

1. CE → abrir el proceso. *Value type* 4 Bytes, *First Scan* con el Zenny que muestra el juego.
2. Gasta o gana Zenny → *Next Scan* hasta que queden 1 o 2 direcciones.
3. Cambia el valor en CE y comprueba que el juego lo refleja. Si no, es una copia: prueba con la otra dirección.

## 3. Reconstruir la base estática

### 3a. Método rápido: la forma de la cadena no cambió

En la ventana Lua de CE (Ctrl+Alt+L):

```lua
-- OJO: la ruta debe ser la REAL; si dofile falla CE solo dice "Undefined lua error".
-- Alternativa robusta: pegar el contenido de ct_helpers.lua en Memory View > Tools > Lua Engine (Ctrl+L).
dofile([[C:\ruta\cheat-engine-tables\lua\ct_helpers.lua]])
ctFindStatic(0x2A4B1C070, {0x238, 0x70, 0x70}, "MEGAMAN_STARFORCE_Legacy_Collection.exe")
--> BASE ESTÁTICA: "MEGAMAN_STARFORCE_Legacy_Collection.exe"+E1xxxxx
ctVerify("MEGAMAN_STARFORCE_Legacy_Collection.exe", 0xE1xxxxx, {0x238,0x70,0x70})
```
- **Un candidato**: listo.
- **Varios candidatos**: cierra y reabre el juego (o carga otra partida), repite y quédate con la intersección.
- **Se rompe en un nivel**: la estructura cambió. Pasa a 3b.

Repite el proceso con SF2 y confirma que sale **la misma** base (en la tabla original SF1 y SF2 comparten base). Luego haz SF3.

### 3b. Método general: Pointer Scanner de CE

Clic derecho sobre la dirección → *Pointer scan for this address*:
- *Max level* 4–5, *Max offset* 0x1000 (súbelo a 0x2000 si no aparece nada).
- *Pointers must end with specific offsets*: escribe los offsets conocidos de **abajo hacia arriba** (70, 70, 238). Esto reduce mucho el resultado.
- Reinicia el juego → *Rescan memory* con la nueva dirección del valor. Repite 2–3 veces.
- Elige la ruta que sale de `MEGAMAN_STARFORCE_Legacy_Collection.exe+…` y cuyo primer offset sea `0` (como en la tabla original).

Si los offsets intermedios cambiaron, corrígelos en la tabla. Con `ct_tool.py chains` ves qué entradas comparten ese tramo.

## 4. Generar el AOB (para que la próxima actualización no rompa la tabla)

### 4a. Desde el `.exe` en disco (sin empaquetar)
```bash
python scripts/sigmaker.py refs "...\MEGAMAN_STARFORCE_Legacy_Collection.exe" --rva 0xE1xxxxx
python scripts/sigmaker.py make "...\MEGAMAN_STARFORCE_Legacy_Collection.exe" --rva 0xE1xxxxx \
       --symbol sf12_base --replaces '"MEGAMAN_STARFORCE_Legacy_Collection.exe"+0E120A40' --json sig_sf12.json
```

### 4b. Desde un volcado de memoria (si el ejecutable está empaquetado o protegido)
```lua
ctDumpModule("MEGAMAN_STARFORCE_Legacy_Collection.exe", [[C:\temp\mmsf.dmp]])
```
```bash
python scripts/sigmaker.py make --dump C:\temp\mmsf.dmp --rva 0xE1xxxxx --symbol sf12_base
```

### 4c. Manual desde CE (control cruzado)
Memory View → *Go to address* `MEGAMAN...exe+E1xxxxx` → clic derecho → *Find out what accesses this address*. Juega un momento. Las instrucciones del tipo `mov rax,[MEGAMAN...exe+E1xxxxx]` son las candidatas. Copia sus bytes y pasa el disp32 a `??`.

Para elegir entre varias firmas, prefiere:
- `mov reg,[rip+disp]` antes que `cmp`/`lea`;
- la firma más corta que siga siendo **ÚNICA**;
- instrucciones que se ejecuten a menudo (aparecen primero en *what accesses*).

Comprueba la firma elegida con `sigmaker.py check`.

## 5. Actualizar la tabla

Completa `aob`, `disp_offset`, `instr_len` y `fallback_offset` en `templates/resolvers.<juego>.json`. Después:

```bash
python scripts/ct_tool.py resolve tabla_original.CT --config resolvers.json --nest -o tabla_vN.CT
python scripts/ct_tool.py validate tabla_vN.CT
python scripts/ct_tool.py diff tabla_original.CT tabla_vN.CT
```
Volver a ejecutar `resolve` sobre una tabla que ya tiene resolver **lo actualiza en el mismo lugar**, sin duplicarlo.

## 6. Validar en el juego (checklist)

- [ ] Al activar `[Resolver]`, la ventana Lua muestra `AOB (1 coincidencia/s)` para cada base. Si dice `RESPALDO`, el AOB no sirvió.
- [ ] El Zenny de SF1, SF2 y SF3 coincide con lo que muestra el juego.
- [ ] Cambiar el Zenny en CE → el juego lo refleja después de abrir y cerrar el menú.
- [ ] Entrar en combate: HP, Custom Gauge y Delete Time muestran valores coherentes (la tabla ya avisa que algunos punteros solo funcionan en batalla).
- [ ] Una muestra de 3–5 cartas por color: la cantidad coincide con la carpeta/inventario.
- [ ] Desactivar el resolver: los hijos se ocultan y se desactivan.
- [ ] Reiniciar el juego y activar de nuevo: todo sigue resolviendo (prueba de persistencia).
- [ ] Guardar la tabla con la build anotada (BuildID, SHA-256).

## Solución de problemas

| Síntoma | Causa probable | Acción |
|---|---|---|
| `AOB falló (0 coincidencias)` | El parche cambió el código | Repetir el paso 4; mientras tanto se usa el respaldo |
| `AOB falló (n coincidencias, >1 destinos)` | Firma demasiado corta | `sigmaker make --min-len 20` |
| Valores `??` | Juego no cargado o fuera de combate | Entrar al juego o la batalla correspondiente |
| `ctFindStatic` truncado | Valor muy común | `opts={maxPerLevel=2000}` o Pointer Scanner |
| `sigmaker refs` = 0 | `.exe` empaquetado, o la base se lee con `mov reg,imm64` | Usar `--dump` o 4c |
| El juego se cierra al congelar | Puntero transitorio (la tabla ya lo advierte) | No congelar; editar una vez |

## Consultar el estado del resolver

`print()` del resolver va a **Memory View → Tools → Lua Engine** (no a la ventana `Ctrl+Alt+L`, que solo ejecuta scripts). Lo más directo es pegar esto en `Ctrl+Alt+L` con el resolver activo:

```lua
local MOD = "MEGAMAN_STARFORCE_Legacy_Collection.exe"
local mb, out = getAddressSafe(MOD), {}
if not CT_RESOLVER then out[1] = "CT_RESOLVER no existe: ¿activaste el [Resolver]?" else
  for sym, r in pairs(CT_RESOLVER) do
    out[#out+1] = string.format("%-10s = %s+%X  [%s]", sym, MOD, r.address - mb, r.method) end end
local txt = table.concat(out, "\n"); writeToClipboard(txt); showMessage(txt)
```
Esperado: `AOB #1 de 3 (1 coincidencia/s)` para cada base.
