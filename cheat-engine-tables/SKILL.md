---
name: "cheat-engine-tables"
description: "Crear, auditar, reparar y endurecer tablas de Cheat Engine (.CT) para juegos de un jugador: pointers rotos por parches, bases estáticas a AOB con respaldo, validación en vivo."
---

# Cheat Engine Tables (.CT)

Kit para trabajar con tablas `.CT` de Cheat Engine 7.5 o superior en juegos **offline / de un jugador**. Cubre:
- análisis y reparación offline del XML;
- recuperación en vivo de bases de punteros rotas por un parche;
- conversión de anclas estáticas en **símbolos resueltos por AOB con respaldo estático**.

Juego de referencia para pruebas: *Mega Man Star Force Legacy Collection* (tabla de FearLess Revolution, t=38738). La tabla quedó validada en vivo el 2026-10-10.

## Alcance y límites

- **Sí**: juegos para un jugador, emuladores y colecciones retro; modificar el estado local de la partida.
- **No**: juegos en línea o competitivos, títulos con anti-cheat activo (EAC, BattlEye, Vanguard…), evadir DRM o anti-cheat, ni distribuir binarios modificados. Si el pedido apunta a eso, decláralo fuera de alcance.
- Nunca inventes offsets ni AOB. Todo valor nuevo sale de una medición (CE, `sigmaker`, `ctFindStatic`) y se marca `PENDIENTE` hasta verificarlo en el juego.

## Kit (`cheat-engine-tables-kit.zip`)

| Archivo | Uso |
|---|---|
| `scripts/ct_tool.py` | `info`, `tree`, `chains`, `rebase`, `resolve`, `validate`, `diff`. Solo usa la biblioteca estándar (Python 3.9+). |
| `scripts/sigmaker.py` | `peinfo`, `refs`, `make`, `check`. Firmas AOB x64 RIP-relativas desde el `.exe` o un volcado (`--dump`). Requiere `pefile`, `capstone` y `numpy`. |
| `lua/ct_helpers.lua` | Para la ventana Lua de CE: `ctFindStatic`, `ctFollow`, `ctVerify`, `ctDumpModule`. |
| `templates/resolvers.<juego>.json` | Configuración del resolver (símbolo, AOB, disp_offset, instr_len, respaldo). |
| `tests/run_tests.sh` | Pruebas de humo: PE sintético y API de CE simulada. |
| `references/ct-format.md` | Esquema XML, orden inverso de `<Offsets>`, direcciones relativas. |
| `references/live-workflow.md` | Procedimiento en vivo paso a paso, checklist de validación y solución de problemas. |
| `references/aa-templates.md` | Plantillas AA: resolver, inyección AOB, Lua dentro de AA, entradas de puntero. |

Antes de usar el kit, búscalo en el entorno: carpeta conectada, `uploads` o `~/cheat-engine-tables`. Si no está, pide al usuario que adjunte `cheat-engine-tables-kit.zip`. Al descomprimirlo, ejecuta `bash tests/run_tests.sh`; en Windows, instala antes las dependencias con `pip install pefile capstone numpy`.

Si el kit no está disponible, todo lo esencial para trabajar a mano está en "Notas técnicas", "Plantillas mínimas" y "Script de búsqueda inversa" de este archivo.

## Flujo de trabajo

### A. Auditar (siempre lo primero)

```bash
python scripts/ct_tool.py info tabla.CT        # versión, tipos, ANCLAS y nº de dependientes
python scripts/ct_tool.py validate tabla.CT    # errores estructurales + anclas estáticas
python scripts/ct_tool.py chains tabla.CT --filter <valor>
```
Informa al usuario: cuántas anclas hay, cuántas entradas dependen de cada una y qué valor ancla conviene usar para cada base (dinero o HP: legible y estable).

### B. Recuperar bases (en vivo, con el usuario o en su equipo)

1. **Huella de la build:** `sigmaker.py peinfo` (SHA-256, TimeDateStamp, aviso de empaquetado) y el Steam BuildID (`appmanifest_*.acf`).
2. **Valor ancla:** localizarlo con un escaneo normal de CE (First/Next Scan) y confirmarlo escribiéndolo.
3. **Base estática:** entrega al usuario el **script autocontenido** de la sección "Script de búsqueda inversa" ya rellenado con su dirección y sus offsets. **No uses `dofile`** con rutas de ejemplo (ver Lecciones). Si la cadena se rompe en un nivel, la estructura cambió: usar el Pointer Scanner con *Pointers must end with specific offsets* y hacer 2–3 rescans tras reiniciar el juego.
4. **Confirmación:** sigue la cadena hacia adelante desde la base candidata con un **segundo valor** de la misma base. Si dos juegos comparten base, comprueba que ambos resuelven desde la misma.
5. **Orden de offsets:** compruébalo con una cadena de offsets **distintos** (por ejemplo, el HP). Una cadena simétrica como `+70,+70` no sirve para eso.

### C. Endurecer: AOB + respaldo

1. `sigmaker.py make <exe> --rva <RVA nueva> --symbol <sym> --replaces '<ancla vieja>' --json sig.json`. Si `peinfo` avisa de empaquetado o `refs` devuelve 0, primero ejecuta `ctDumpModule(...)` en CE y luego usa `sigmaker.py make --dump volcado.dmp ...`. Las versiones de Microsoft Store o Game Pass (`WindowsApps`, `XboxGames`) no se pueden copiar: usa directamente el volcado.
2. `sigmaker.py check` sobre la firma elegida: tiene que resolver a una sola RVA. Prefiere `mov reg,[rip+disp]` y la firma única más corta. Si hay **bases gemelas** (dos RVA contiguas a +8 que apuntan al mismo objeto), quédate con la que lea el código del juego.
3. Completar el JSON del resolver y aplicarlo:
   ```bash
   python scripts/ct_tool.py resolve tabla.CT --config resolvers.json --nest -o tabla_vN.CT
   ```
   `resolve` reemplaza las anclas por símbolos, inserta o actualiza el script `[Resolver]` sin duplicarlo y, con `--nest`, cuelga los grupos dependientes bajo él (`moHideChildren` + `moDeactivateChildrenAsWell`).
4. `validate` (0 errores) y `diff` contra el original. Los únicos cambios deben ser las anclas y el resolver.

### D. Validar en el juego (obligatorio antes de declarar "funcional")

- [ ] Al activar `[Resolver]`, la ventana Lua muestra `AOB (1 coincidencia/s)` para cada base. Si dice `RESPALDO`, el AOB no sirvió.
- [ ] Un valor por base (por ejemplo, el dinero) coincide con lo que muestra el juego y se puede escribir.
- [ ] Una muestra de valores por subsistema: combate, inventario, cartas u objetos, habilidades. Prueba todo **desde el mapa**, sin menús abiertos.
- [ ] Los campos dudosos se comprueban con una prueba de comportamiento: recibir daño, curarse o subir una mejora, y ver qué campo cambia.
- [ ] Al desactivar el resolver, los hijos se ocultan y se desactivan.
- [ ] Reiniciar el juego y activar de nuevo: todo sigue resolviendo.
- [ ] La build queda anotada (BuildID, SHA-256) en el `note` del resolver.

Distingue siempre en el informe qué se **validó en el juego** y qué es solo validación estructural. Lleva una tabla de estado por juego y subsistema durante la sesión.

### E. Crear tablas nuevas

1. Encontrar valores con CE y llegar a la base con el Pointer Scanner.
2. Agrupar todas las entradas bajo **una base por subsistema**: los hijos usan direcciones relativas `+X` y los offsets van en orden inverso en el XML.
3. Endurecer siguiendo C.
4. Para cheats de comportamiento, usar la inyección AOB (plantilla abajo) copiando los bytes originales reales del Memory View.

## Lecciones de validación en vivo

**Ejecutar Lua en Cheat Engine**
- `dofile([[C:\...\x.lua]])` con una ruta de ejemplo falla con un genérico **"Undefined lua error"**. Por defecto, entrega scripts **autocontenidos** para pegar y ejecutar.
- Cada ejecución empieza de cero: una línea suelta como `findStatic(...)` da `attempt to call a nil value`. Regenera siempre el script **completo**, con las funciones incluidas.
- En la ventana *Lua script: Cheat Table*, la salida de `print()` puede no verse. Termina siempre con `writeToClipboard(txt)` y `showMessage(txt)`, envuelve todo en `pcall` e indica al usuario que el escaneo tarda entre 5 y 30 s (CE parece congelado). La alternativa es Memory View → Tools → Lua Engine (`Ctrl+L`).
- Las direcciones dinámicas cambian al cambiar de zona o recargar. El script debe imprimir `(lee N)` para que el usuario confirme el valor antes de interpretar el resultado.

**Bases**
- Es normal obtener **dos bases gemelas contiguas** (+0 y +8) que apuntan al mismo objeto. Elige la menor como respaldo y deja que el AOB decida.
- En colecciones con varios juegos, la distancia entre bases **cambia con el parche**. No calcules una base sumando la distancia antigua a otra: busca cada una por separado.

**Escritura de valores**
- **Editar solo desde el mapa.** Con el Folder, la Biblioteca u otro inventario abierto, el juego trabaja sobre una copia que sobrescribe la edición al cerrar el menú. Síntoma: "pongo 1 y no se agrega", aunque la dirección es correcta.
- Para saber si el juego revierte un valor, usa la prueba de persistencia: escribir, esperar 3 s con `createTimer` y volver a leer. Si se resetea, usa *Find out what writes to this address*.
- **Entradas de 4 bytes sobre campos de 1 byte** pisan los campos vecinos. Por ejemplo, en el grupo "All" de MMSF1 las entradas de 4 bytes desde `+71` pisan `+72`, `+73` y `+74` (Mega y Giga). Márcalas con un aviso o conviértelas a `Byte`.
- Las etiquetas de la tabla original pueden estar mal (en MMSF1, "Max HP" no era el máximo). Verifícalas con una prueba de comportamiento antes de corregir o renombrar.
- Si una entrada "no funciona", diagnostica comparando su registro con los vecinos que sí funcionan: puntero, bytes alrededor y orden de las posiciones. Si todo coincide, el problema es el momento en que se escribe, no la dirección.

## Convenciones de entrega

- Nombre de archivo: `<Juego>_v<N>_<estado>.CT` (por ejemplo, `_bases-OK_AOB-PENDIENTE`). Nunca sobrescribir el original.
- Documentar en el `note` del resolver: build, método (AOB o respaldo), qué se validó y la fecha.
- Agregar notas `##` en la tabla con lo aprendido: editar desde el mapa, mapa de bytes por campo y avisos de solapamiento.
- Mientras falte la medición en vivo, marcar el archivo como `-PENDIENTE`.

## Notas técnicas

- `.CT` = XML UTF-8. `<CheatTable CheatEngineTableVersion="N">` → `<CheatEntries>` → `<CheatEntry>` (`ID` único; `Description` entre comillas; `GroupHeader`; `VariableType`; `Address`; `Offsets/Offset`; `ShowAsHex`; `DropDownList`/`DropDownListLink`, que apunta a la Description de otra entrada; `AssemblerScript`; hijos en `CheatEntries`). Al final van `UserdefinedSymbols` y, opcionalmente, `LuaScript`.
- `<Offsets>` en el XML va **al revés**: el primer elemento es el último offset aplicado. Esto quedó confirmado en vivo con el HP de MMSF1 (`[170,28,2E]`). Por ejemplo, `Address=+238` con `Offsets=[70,70]` bajo un padre `mod+X` con `Offsets=[0]` equivale a `[[[mod+X]+238]+70]+70`.
- `+X` / `-X` es relativo al **ancestro más cercano con `<Address>`**. Los grupos sin dirección son transparentes.
- Fórmula RIP-relativa: `base = hit + instr_len + int32(hit + disp_offset)`, con disp con signo. `disp_offset` e `instr_len` se cuentan desde el inicio de la firma.
- No pierdas el prefijo REX (`48`/`4C`) al cortar la firma. Pon comodines en el disp32 y en los rel32 de `call`/`jmp`/`jcc`.
- Los bloques `{$lua}` dentro de AA deben empezar con `if syntaxcheck then return end` y cerrarse con `{$asm}`, tanto en `[ENABLE]` como en `[DISABLE]`.
- Si el resolver usa un respaldo obsoleto, los grupos muestran `P->00000000`. Eso confirma que la base antigua ya no sirve.

### Caso MMSF Legacy Collection

| Base | Original (CT v52) | Build 2026-10 | Gemela | Juegos |
|---|---|---|---|---|
| `sf12_base` | `exe+0E120A40` | `exe+DEB4850` | `+DEB4858` | SF1 y SF2 (comparten base) |
| `sf3_base` | `exe+0E124218` | `exe+DEB7EE0` | `+DEB7EE8` | SF3 |

- La forma de las cadenas no cambió con el parche. Valores ancla, con offsets en orden de aplicación: Zenny SF1 `{0x238,0x70,0x70}`, SF2 `{0x240,0x70,0x70}`, SF3 `{0x1C0,0xA8,0x14}`.
- Estructura del jugador en SF1 (`[[[B+238]+170]+28]`): `+28` HP base (inicial 100), `+2E` HP actual (2 bytes); `+30` no es Max HP. El total que muestra la pantalla de stats se calcula.
- Cartas SF1: posición = `+28 + 8·(n-1)` en la lista `[[[B+238]+98]+10]`. En el registro, `+70` blanco, `+71` amarillo, `+72` azul (Mega), `+73` rojo (Giga).
- En SF3 la tabla solo tiene HP de batalla. Fuera de combate se usan HP Upgrade +10/+20 (`[[B+1C0]+A8]+170/171`).
- AOB: PENDIENTE.

## Script de búsqueda inversa (pegar y ejecutar en CE)

Rellena `MOD`, la dirección actual del valor ancla y los offsets en orden de aplicación:

```lua
local MOD = "Juego.exe"
local OUT = {}
local function log(s) OUT[#OUT+1] = s; print(s) end
local function holders(value, prot, maxn)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtQword, rtRounded, string.format("%X", value), "",
               0, 0x7FFFFFFFFFFF, prot, fsmAligned, "4", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, maxn) - 1 do r[#r+1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end
local function findStatic(label, target, offs)
  local mb = getAddressSafe(MOD)
  if not mb then log("Módulo no encontrado"); return end
  local me = mb + getModuleSize(MOD)
  log(string.format("== %s: valor en %X (lee %s) ==", label, target, tostring(readInteger(target))))
  local cur = { target }
  for k = #offs, 1, -1 do
    local last, nxt, seen = (k == 1), {}, {}
    for _, t in ipairs(cur) do
      local hs, total = holders(t - offs[k], last and "" or "+W", 500)
      if total > #hs then log(string.format("  aviso: %d coincidencias, truncado", total)) end
      for _, h in ipairs(hs) do
        if not seen[h] and (not last or (h >= mb and h < me)) then seen[h] = true; nxt[#nxt+1] = h end
      end
    end
    log(string.format("  nivel %d (offset +%X): %d candidato(s)", k, offs[k], #nxt))
    if #nxt == 0 then log("  -> cadena rota en este nivel"); return end
    cur = nxt
  end
  for _, s in ipairs(cur) do log(string.format("  BASE: \"%s\"+%X", MOD, s - mb)) end
end
local ok, err = pcall(function()
  findStatic("Valor ancla", 0xDIRECCION, {0x238, 0x70, 0x70})
end)
if not ok then log("ERROR: " .. tostring(err)) end
local txt = table.concat(OUT, "\n")
writeToClipboard(txt)
showMessage(txt .. "\n\n(Resultado copiado al portapapeles)")
```

## Plantillas mínimas

### Resolver (AA con Lua), que `ct_tool.py resolve` genera automáticamente

```
[ENABLE]
{$lua}
if syntaxcheck then return end
local MODULE = "Juego.exe"
local BASES = { { symbol="game_base", aob="48 8B 05 ?? ?? ?? ?? 48 85 C0", disp=3, len=7, fallback=0xE120A40 } }
-- Para cada base: createMemScan + firstScan(soExactValue, vtByteArray, ..., base, base+getModuleSize(MODULE), "", fsmNotAligned, "1", true, ...)
-- destino = hit + len + int32(readInteger(hit+disp)); si 0 o >1 destinos -> modBase + fallback
-- registerSymbol(symbol, destino, true); print del método usado
{$asm}
[DISABLE]
{$lua}
if syntaxcheck then return end
unregisterSymbol("game_base")
{$asm}
```

### Inyección AOB (cheat de comportamiento)

```
[ENABLE]
aobscanmodule(INJ, Juego.exe, <bytes con ??>)
alloc(newmem, $1000, INJ)
label(code)
label(return)
newmem:
  // lógica nueva (filtrar jugador vs enemigos si el código es compartido)
code:
  // instrucciones originales
  jmp return
INJ:
  jmp newmem
  nop N
return:
registersymbol(INJ)
[DISABLE]
INJ:
  db <bytes originales EXACTOS>
unregistersymbol(INJ)
dealloc(newmem)
```

### Prueba de persistencia de un valor

```lua
local addr = 0xDIRECCION
writeBytes(addr, 8)
local t = createTimer(nil, false); t.Interval = 3000
t.OnTimer = function(s) s.destroy()
  showMessage("a los 3 s = " .. tostring(readBytes(addr, 1))) end
t.Enabled = true
```