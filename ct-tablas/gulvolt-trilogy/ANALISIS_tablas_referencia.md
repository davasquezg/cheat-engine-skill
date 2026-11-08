# Análisis de tablas de referencia — Gunvolt 1, 2 y 3 (versiones individuales)

> Fecha: 2026-11-01. Fuente: tablas guardadas en `original/` (no se versionan). Objetivo: extraer **patrones** (estructuras, offsets relativos, lógica de inyección) para localizar los mismos datos en la *Trilogy Enhanced*. Nada de esto está validado aún en la Trilogy.

| Archivo | Juego / hilo | Autor | Ejecutable | Arquitectura | Método |
|---|---|---|---|---|---|
| `gv1.CT` | GV1 Steam 388800 — [t=1929](https://fearlessrevolution.com/viewtopic.php?t=1929) | WarCOzes (`wcz`) | `gv_win.exe` | **32 bits** | Direcciones estáticas `gv_win.exe+…` + 5 scripts (1 por AOB, 4 por dirección fija) |
| `gv2.CT` | GV2 v1.0 — [t=12924](https://fearlessrevolution.com/viewtopic.php?t=12924) | Shinkansen (V1001) | (`aobscan` sin módulo) | 64 bits | 2 inyecciones por AOB que **capturan punteros base**; todo lo demás es relativo a ellos |
| `gv3.CT` | GV3 — [t=21777](https://fearlessrevolution.com/viewtopic.php?t=21777) | RTX_XXXX (Update1.1) | `game.exe` | 64 bits | 6 inyecciones por AOB (`aobscanmodule`) |
| `A.S.G.T.E v1.1.1frf.CT` | Trilogy v1.1.1 — [t=35891](https://fearlessrevolution.com/viewtopic.php?t=35891) | ndck1 | `game1.exe` | 64 bits | 1 inyección por AOB (GV1) |
| `trilogy.CT` | Trilogy Enhanced — [t=35866](https://fearlessrevolution.com/viewtopic.php?t=35866) | wepon1984 | `game1.exe`…`game4.exe` | 64 bits | Direcciones estáticas y punteros de 1 a 7 niveles; AOB solo en GV3 y Connect iX (ver §8) |

## 1. Hallazgo principal: el **componente de vida** se repite en los tres juegos

| Campo | GV1 (32 b, entero) | GV2 (64 b, entero ×160) | GV3 (64 b, float) | Trilogy GV1 (ndck1) |
|---|---|---|---|---|
| HP actual | `+0` | `+8` (`HP/160`) | `+8` (float) | `[data]+0` (¿?) |
| HP máximo | `+4` | `+C` | `+C` (float) | `[data]+4` («Max Health») |
| Invencibilidad | `+8` (timer, `>0` = invulnerable) | `+178` (timer; en otro objeto) | `[rsi+510]` (float, otro objeto) | — |
| Flags | `+18` byte; bit 0 = jugador | — | `+18` (`or [rcx+18],1` al escribir HP) | — |
| ¿Es el jugador? | `byte [+18] == 1` | por cadena de punteros propia | `dword [+20] == 1` | — |
| Cómo se llega | inyección en la escritura del HP (`mov [eax],ecx`) | `[[[[char]+10]+568]+458]` | inyección en `movss [rcx+08],xmm0` | `rcx` en la instrucción del AOB `8B ?? 41 3B ?? 45 8B ?? 44 0F` |

**Lectura:** la tabla de ndck1 guarda `rcx` y llama «Max Health» a `[data]+4` → coincide con el **diseño de GV1** (`+0` HP, `+4` HP máx.). El AOB `8B ?? 41 3B ?? 45 8B ?? 44 0F` encaja con un *clamp* del HP, p. ej. `mov eax,[rcx] / cmp eax,r8d / mov r9d,r8d / cmovcc …`. **Hipótesis H1:** `game1.exe` conserva el componente de vida de GV1 (enteros, `+0/+4/+8/+18`).

**Patrón para la tabla nueva:** inyectar en la **escritura del HP**, distinguir jugador/enemigo por el flag, y desde ahí ofrecer *HP infinito*, *un golpe mortal* (escribir 0 si no es el jugador) e *invencibilidad* (timer). Es exactamente lo que hace GV3 con un solo punto de inyección.

## 2. GV1 (`gv1.CT`) — mapa de memoria estática

Bloque de **partida guardada** (offsets relativos a *Credits*; buscar Credits con un escaneo de valor y comprobar los vecinos):

| Campo | Dirección original | Δ desde Credits | Tipo |
|---|---|---|---|
| Total Time | `+BE0124` | `-0xE0` | 4 B |
| **Credits** | `+BE0204` | `0` | 4 B |
| Materiales `[0..27]` | `+BE05AC … +BE0618` | `+0x3A8 … +0x414` | 28 × 4 B |
| EXP | `+BE0674` | `+0x470` | 4 B |
| Level («no modificar») | `+BE0678` | `+0x474` | 2 B |

Orden de los materiales (índice = posición en el arreglo, paso 4):

| # | Material | # | Material | # | Material | # | Material |
|---|---|---|---|---|---|---|---|
| 0 | Microdegenerator | 7 | Hihirogane Shard | 14 | Graym Extract 239 | 21 | High-end NcGbx |
| 1 | Custom Servophoton | 8 | Antigravity Engine | 15 | Electromotive Graym | 22 | Garnet |
| 2 | Spinel Quasicrystal | 9 | Propulsion Mechanism | 16 | Kripp Alloy | 23 | Quartzite |
| 3 | Ultradense Magnet | 10 | Phoenix Ore | 17 | Xiwidia | 24 | Electrum |
| 4 | Genomic Resonator | 11 | Shock Response Plate | 18 | Faraging Steel | 25 | Graym Culture |
| 5 | Phased Fluid Metal | 12 | Six-miracle Graym | 19 | Nanochip 98 | 26 | Polymer Gm238 |
| 6 | Yellow Chalcedony | 13 | Apoitagara | 20 | Proto Infrastructure | 27 | Uranium-235 Crystal |

(0–7 = 3 estrellas, 8–15 = únicos, 16–27 = 0/1/2 estrellas intercalados.)

Bloque de **combate** (base `+14DC054`):

| Campo | Dirección | Δ base | Escala |
|---|---|---|---|
| Energía / campo eléctrico (EP) | `+14DC058` | `+4` | lleno = **5 000 000** |
| Skill Points | `+14DC05C` | `+8` | 1 punto = **20 000 000** (3 = 60 000 000) |
| Cooldown habilidad 1–4 | `+14DC064 …070` | `+0x10 + 4·i` | lleno = **76 800** |
| Score | `+14E90A4` | — | — |
| Medals / Time (nivel) | `+BDC53C` / `+BDC534` | — | — |

Scripts (lógica reutilizable):
- **Inf. Health:** en `mov [eax],ecx` (escritura de HP): si `byte [eax+18]==1` → `[eax] = [eax+4]`.
- **Invulnerable:** en `cmp dword ptr [eax+08],0 / jle` → fuerza `[eax+08] = 1000`.
- **Inf. Electric Field / Inf. Skill Points / No Skill Cooldown:** escriben las constantes de la tabla anterior en el punto donde el juego lee o escribe cada valor.
- **One Hit Kill** (nota de sokenbitya en el hilo): tras `sub eax,[ebp-5C]` (daño), cambiar `test eax,eax` por `cmp eax,eax`.

## 3. GV2 (`gv2.CT`) — dos punteros base capturados por inyección

**Character Stats** — AOB `8B 41 58 99 0F B6 D2 03 C2 C1 F8 08 C3` = *getter* `mov eax,[rcx+58] / cdq / movzx edx,dl / add eax,edx / sar eax,8 / ret` (convierte de punto fijo 24.8 a entero). Captura `rcx` = estructura del personaje.

| Campo | Offset | Notas |
|---|---|---|
| HP / HP máx. | `[[[base+10]+568]+458]` `+8` / `+C` | unidades ×160 |
| Invencibilidad | mismo objeto `+178` | el script escribe 10000 |
| Weapon Gauge (2) | `+38`, `+40` (máx. `+3C`, `+44`, ×256) | |
| Copen EP | `+48` (regeneración `+4C`, máx. `+50`) | |
| Gunvolt EP / Copen Bullit | `+58` (regeneración `+5C`, máx. `+60`) | es lo que lee el getter |
| Gunvolt SP | `+70` (máx. `+78`) | el script solo lo llena si `[+74]==0`: «solo jugando como Gunvolt o cuelga» |

Valores en **punto fijo 24.8**: el máximo es un `word` y el valor actual = máximo `<< 8`.

**Score Stats** — AOB `01 03 8B 03 3B C1 0F 4F C1 89 03` = `add [rbx],eax / mov eax,[rbx] / cmp eax,ecx / cmovg eax,ecx / mov [rbx],eax` (suma de puntaje con tope). Captura `rbx` = **Score**; todo lo demás está a distancia fija de él (bloque estático):

| Campo | Δ desde Score | Δ desde GV Credits |
|---|---|---|
| Time | `-0xE0BEC` | `-0x2544` |
| **Gunvolt Credits** | `-0xDE6A8` | `0` |
| Copen Credits | `-0xDE3E0` | `+0x2C8` |
| Gear `[0..49]` (ID byte, EXP word en `+2`, paso 4) | `-0xDE11C` | `+0x58C` |
| Materiales Gunvolt `[0..23]` (byte) | `-0xDE048` | `+0x660` |
| Subroutines `[…]` (ID byte, EXP word, paso 4) | `-0xDE028` | `+0x680` |
| Materiales Copen `[0..23]` (byte) | `-0xDDF58` | `+0x750` |
| Gunvolt EXP / LV | `-0xDDE90` / `-0xDDE8C` | `+0x818` / `+0x81C` |
| Copen EXP / LV | `-0xDDE58` / `-0xDDE54` | `+0x850` / `+0x854` |
| Memory (2 B) | `-0xDDE40` | `+0x868` |
| Bonus Tries (1 B) | `-0xDDDC8` | `+0x8E0` |
| Kudos (÷160) | `-0xCD270` | `+0x11438` |
| Kudos visual | `-0x5F68` | — |

Orden de materiales en GV2 (byte, 24 posiciones): Phase Fluid Metal, Microdegenerator, Ultradense Magnet, Custom Servophoton, Hihirogane Shard, Shock Response Plate, Propulsion Mechanism, Antigravity Engine, Phoenix Ore, Electromotive Graym, Kripp Alloy, Xiwidia, Foraging Steel, Nanochip 98, Proto Infrastructure, High-End NcGbx, Garnet, Quartzite, Electrum, Graym Culture, Polymer Gm238, Uranium-235 Crystal, Dummy, Dummy.

Problemas conocidos del hilo: los materiales al principio solo funcionaban para Copen (corregido en V1001); objetos de Shovel Knight aplicados por tabla no funcionan.

## 4. GV3 (`gv3.CT`) — inyecciones directas, valores en *float*

| Script | AOB (`game.exe`) | Instrucción | Qué hace |
|---|---|---|---|
| Health (+ PlayerMaxHealth / Enemy1HitKill) | `F3 0F 11 41 08 83 49 18 01 C3 0F` | `movss [rcx+08],xmm0 / or dword ptr [rcx+18],1 / ret` | si `[rcx+20]==1` (jugador) → HP = `[rcx+0C]`; si no y 1HK activo → HP = 0 |
| Invencible jugador | `F3 0F 10 86 10 05 00 00 45` | `movss xmm0,[rsi+510]` | escribe el byte `0x66` en `[rsi+510]` (timer de invencibilidad, float) |
| Invencible ambos | `E8 AC 17 DF FF` | `call game.exe+EF0890` | anula la llamada (**frágil**: el AOB incluye el desplazamiento relativo del `call`) |
| Talismán infinito | `88 91 9A 06 00 00` | `mov [rcx+69A],dl` | fuerza `dl = 8` |
| High Score | `F3 0F 11 83 F8 00 00 00 40` | `movss [rbx+F8],xmm0` | suma 99 999 999 (float) |

Avisos de la comunidad: congelar talismanes de GV3 **cierra el juego al cambiar a Gunvolt** (wepon1984, t=35866); desde una actualización, **depurar GV3 lo cierra** (Algester) → preferir AOB + inyección sin depurador, o el depurador VEH de CE.

## 5. Patrones que trasladamos a la Trilogy

1. **Un punto de inyección por estructura** y todo lo demás relativo a él (enfoque GV2), con validación del puntero antes de usarlo (como hicimos en MMSF).
2. **Componente de vida** (sección 1): inyección en la escritura del HP + flag de jugador → HP infinito, 1HK y, si el timer está en el mismo objeto (GV1), invencibilidad.
3. **Bloque de partida contiguo**: buscar *Credits* con escaneo de valor y verificar los vecinos con los Δ de las secciones 2 y 3. Si coinciden, todo el bloque sale con **un solo ancla** (resolver por AOB + respaldo estático, como `sf3_base` en MMSF).
4. **Escalas**: GV1 EP 5 000 000 y SP 20 000 000 por punto, cooldown 76 800; GV2 punto fijo 24.8 y HP/Kudos ×160; GV3 float. Hay que confirmar cuál usa cada `gameN.exe`.
5. **Evitar** AOB que incluyan desplazamientos de `call`/`jmp` (comodines en rel32) y scripts que copian bytes fijos sin revisar el desensamblado.

## 6. Verificaciones en vivo propuestas (por orden)

| # | Juego | Prueba | Resultado esperado si la hipótesis es correcta |
|---|---|---|---|
| 1 | GV1 | `diag_asgte.lua` con el Health Editor de ndck1 activo | `[data]+0` = HP actual, `[data]+4` = HP máx., `+8` sube al recibir daño, `+18` = 1 en el jugador |
| 2 | GV1 | Escanear Credits (4 B) → mirar Credits `+0x3A8` | 28 enteros = materiales en el orden de la sección 2 |
| 3 | GV1 | Escanear EP con la escala ×1 000 000 (lleno = 5 000 000) | `+4` = SP (20 000 000 por punto), `+0xC…` = cooldowns |
| 4 | GV2 | AOB del getter `8B 41 58 99 0F B6 D2 03 C2 C1 F8 08 C3` y del score `01 03 8B 03 3B C1 0F 4F C1 89 03` en el volcado de `game2.exe` | coincidencia única → la tabla de Shinkansen se puede portar casi entera |
| 5 | GV3 | AOB de Health / Talismán / Score de RTX_XXXX en el volcado del exe de GV3 | coincidencia única → portar; si no, buscar el mismo patrón de instrucciones |

## 7. Resultados en vivo — GV1 (`game1.exe`, 2026-11-01)

Informe de `diag_asgte.lua` con el Health Editor de ndck1 activo + volcado `dumps/game1.dmp` (base `7FF6E2490000`, tamaño `0x1149000`).

**Componente de vida (`[data]`)** — confirma la hipótesis H1 (diseño de GV1):

| Offset | Valor | Interpretación |
|---|---|---|
| `+00` | 3200 | HP actual (×16 → 200 en pantalla, **sin verificar**) |
| `+04` | 3200 | HP máximo |
| `+08` | 0 | candidato a timer de invencibilidad (GV1 original) — **sin verificar** |
| `+0C` / `+14` | 0x01000000 | ¿? |
| `+10` | 256 | ¿? |
| `+18` | 257 = `0x0101` | byte `+18 = 1` → **flag de jugador** como en GV1 |

**Punto de inyección de ndck1** (RVA `0x1AF947`). El AOB «no coincide» en el informe porque el script ya había reemplazado esos 5 bytes por un `jmp`. Bytes restaurados por contexto: `8B 01 / 41 3B C0` (`mov eax,[rcx]` / `cmp eax,r8d`) — 2 instrucciones completas, sin RIP-relativo → la copia de 5 bytes es **segura**.

```
F6 47 26 04           test byte ptr [rdi+26],4
74 09                 je …
48 8B 8F D8 03 00 00  mov rcx,[rdi+3D8]      ; rdi = objeto del personaje, +3D8 -> componente de vida
8B 01                 mov eax,[rcx]          ; <- inyección ndck1 (HP actual)
41 3B C0              cmp eax,r8d            ; r8d = HP máx. nuevo (<<4)
45 8B C8              mov r9d,r8d
44 0F 4E CD           cmovle r9d,ebp
…
44 89 41 04           mov [rcx+4],r8d        ; escribe HP máx.
44 89 09              mov [rcx],r9d          ; escribe HP
```

Es la rutina que **recalcula HP/HP máx. del personaje** (no la que aplica daño). Unidades ×16 (`shl …,4` / `sar …,4`); la misma rutina guarda las versiones ÷16 en `[rbx+28]` y `[rbx+58]` (otro objeto, por identificar).

**AOB propio, único en el volcado** (cubre la zona parchada con comodines y añade contexto):
`F6 47 26 04 74 ?? 48 8B 8F D8 03 00 00 ?? ?? ?? ?? ?? 45 8B C8 44 0F 4E CD` → 1 coincidencia. Con él podemos capturar **`rdi` (objeto del personaje)** además de `rcx`.

Pendiente: encontrar la instrucción que **resta HP al recibir daño** (para HP infinito / 1 golpe sin depender de esta rutina) y verificar `+08` como invencibilidad.

### 7.1 El depurador cierra `game1.exe` → análisis estático del volcado

Al adjuntar el depurador de CE ("Find out what writes") el proceso se cierra (anti-depuración, igual que lo reportado para GV3). Se buscaron en el volcado todas las cargas `mov r64,[r64+3D8]` (692) y, de ellas, las que escriben luego en `[R+0/+4]` del componente de vida (28).

**Rutina de daño** (se repite con variantes en RVA `0x90D41`, `0x91494`, `0x915FA`, `0x91899`, `0x91A8E`, `0x1A2729`, `0x1AAB62`):

```
mov r8,[rbx+3D8]        ; componente de vida de la VÍCTIMA
mov rax,[rbx+4B0]       ; objeto ATACANTE
mov rcx,[rax+3D8]       ; componente del atacante
mov edx,[r8]            ; HP víctima
sub edx,[rcx+8]         ; − poder de ataque del atacante (campo +08)
cmp/cmov … [r8+4]       ; limita a HP máx.
mov [r8],eax            ; escribe HP
```

→ **`+08` no es la invencibilidad: es el poder de ataque (daño que causa ese objeto)**. En el jugador vale 0 en reposo (o lo que cause su disparo). `+4B0` del objeto = quién golpeó.

Otras escrituras: `0xEFC69` (HP = HP máx.: reinicio/curación total), `0xEFC8C` (HP y máx. = `0x6400`), `0x1AA020` (cura: HP += máx.×64/256 = 25 %, con tope), `0x1D7338`/`0x1D7593` (HP y máx. = `0x10`), `0x1AF980` (recalculo de ndck1).

### 7.2 Multisonda — primera corrida (2026-11-01)

- **Bloque de combate ENCONTRADO con la misma forma de `gv1.CT`:** `game1.exe+7ED64C` = Energía (5 000 000 llena), `+4` = Skill Points (60 000 000 = 3 pts), `+0xC…+0x18` = cooldowns (76800/0/0/0). Hay una **copia idéntica 0x30 bytes después** (`+7ED67C`): falta saber cuál es la «real» (cambiar el valor de cada una y ver cuál afecta al juego).
- `Score` a `+0xD04C` (como en gv1.CT) **no** aplica: el valor leído parece la parte baja de un puntero. Se quitó de la sonda.
- **Partida:** Créditos = 18 → 60 coincidencias, ninguna con la forma de gv1.CT. La sonda 3 ahora hace dos pasadas (filtra como «Next Scan» al cambiar los Créditos) y busca de forma flexible el arreglo de 28 materiales a ±0x1000.
- Objeto del jugador `1FCEA7D9910`, componente de vida `1FCEA7D9CA8` = **objeto + 0x398** (el componente está incrustado en el objeto). La sonda de invencibilidad no detectó pérdida de HP en esa corrida.

### 7.3 Sonda de invencibilidad (2026-11-01)

Dos golpes de 384 (HP 3360 → 2976 → 2592; 384/16 = 24 de daño visible). Con un objeto equipado que consumía la **prevasión** en lugar de la vida no había pérdida de HP; el usuario lo desactivó.

| Campo (objeto jugador) | Comportamiento tras el golpe | Interpretación |
|---|---|---|
| `+518` | 0 → **11520** y baja ~400–600 por cada 50 ms hasta 0 (~1,5 s) | **candidato principal a temporizador de invencibilidad** |
| `+528` | 0 → 1 durante ~300 ms | flag de retroceso/aturdimiento |
| `+3D0` | 0 → 2 y se queda | estado (¿«dañado»/animación?) |
| `+3B4` (= componente `+1C`) | 255 un instante | destello |
| `+3A0` (= componente `+08`) | 384 un instante | daño recibido en ese fotograma (antes lo llamamos «poder de ataque»: es el campo que la rutina de daño lee del atacante) |

**Confirmado en vivo (2026-11-01): `objeto_jugador + 0x518` es el temporizador de invencibilidad.** Congelado en 11520 el jugador no recibe daño (equivale a «Invulnerable» de gv1.CT). Ruta: `[gv1_player]+518`, con `gv1_player` capturado por la sonda 1.

### Estado del port de gv1.CT

| Función de gv1.CT | En la Trilogy (`game1.exe`) | Estado |
|---|---|---|
| Inf. Health | `[gv1_hp]+0` = `[gv1_hp]+4` (HP = HP máx., ×16) | ✅ ruta lista (congelar o script) |
| Invulnerable | `[gv1_player]+518` congelado en 11520 | ✅ confirmado |
| Inf. Electric Field | `game1.exe+7ED64C` = 5 000 000 (o la copia `+7ED67C`) | 🟡 encontrado; falta saber cuál de las dos copias manda |
| Inf. Skill Points | `+4` del bloque de combate (20 000 000 por punto) | 🟡 idem |
| No Skill Cooldown | `+0xC…+0x18` (76 800) | 🟡 idem |
| Credits / Total Time / Materials / EXP / Level | **`game1.exe+7B3668`** (Créditos = 5530), misma forma que gv1.CT: materiales `+0x3A8`, EXP `+0x470`, nivel `+0x474`, Total Time `-0xE0` | 🟡 encontrado (única coincidencia); falta contrastar materiales/EXP/nivel con el menú |
| Score, Time, Medals | Time `Créditos−0x3CD0`, Medals `Créditos−0x3CC8` (Δ de gv1.CT) creados como «verificar»; Score sin ubicar | ⏳ |
| One Hit Kill | rutina de daño (7 sitios) | ⏳ sonda 2 |

### 7.4 Contraste con el menú del juego (captura del usuario, 2026-11-01)

| Menú | Valor | Memoria | Conclusión |
|---|---|---|---|
| PV 220/220 | 220 | HP ×16 = 3520 | ✅ escala ×16 confirmada |
| PE 500 | 500 | Energía 5 000 000 | ✅ escala ×10 000 |
| PH ◇◇◇ | 3 | Skill Points 60 000 000 | ✅ 20 000 000 por punto |
| Créditos | 584 000 (editado) | `game1.exe+7B3668` | ✅ se refleja en el menú y **persiste al guardar** (confirmado) |
| Materiales | — | `+0x3A8`, 28 × DWORD | ✅ las **cantidades** coinciden; ❌ el **orden de nombres** de gv1.CT no corresponde → mapear de nuevo |
| Puntos totales | 135 421 | — | ⏳ por escanear (candidato a «Score») |
| Tiempo total | 00:43:35 (2615 s) | `Créditos−0xE0` = 18 310 016 | ❌ no corresponde a 2615 s × 60; buscar aparte |

Script nuevo en la multisonda: **5. Materiales al máximo** (pide la cantidad 1–999, modo «solo los que tienes» o «todos»; verifica la forma del bloque antes de escribir; al desactivar restaura las cantidades previas).

### 7.5 Materiales: orden confirmado por etiquetado (2026-11-01)

Con el script de etiquetado (slot 0 = 99 … slot 27 = 72, a partir de `Créditos+0x3A8`) el inventario mostró **Microantigenerador = 97 … Cultivo de graym = 72** y **Polímero Gm238 = 9** (sin etiquetar). Conclusión:

- El arreglo de materiales empieza en **`Créditos + 0x3B0`** (8 bytes más adelante que en gv1.CT) y conserva **exactamente el orden de gv1.CT**: Microantigenerador (Microdegenerator) … Polímero Gm238, Cristal de uranio 235 (no aparece en el inventario porque el usuario no lo tiene).
- `Créditos+0x3A8` y `+0x3AC` **no son materiales** (recibieron 99 y 98 sin efecto visible): campos por identificar. El desplazamiento de +8 probablemente afecta también a EXP/nivel/tiempo (verificar `+0x478`/`+0x47C`).
- Iconos: 0–7 ★★★, 8–15 únicos, 16–27 en grupos 0★/★/★★.

### 7.6 Prestigio (Kudos) — estructura en el heap (2026-11-01)

Encontrado a mano en `1FCEA9A34D4` (sesión concreta). Investigación con `investigar_direccion_gv1.lua`:

| Offset (K) | Contenido |
|---|---|
| `+0x0` | Prestigio **en pantalla** (18 → 74 durante el muestreo) |
| `+0x4` | Prestigio **interno ×256** (4608 = 18×256 → 18944 = 74×256): punto fijo 24.8, como en GV2 |
| `+0x34`, `+0x3C` | punteros a código de `game1.exe` (`+234130`, `+4C470`) — **estables** entre corridas |
| `+0xC` | puntero a código que **cambia** con el estado (`+B2500` / `+B6640`): no sirve como firma |

- **Sin punteros estáticos** de 1 ni 2 niveles hacia la estructura (offset ≤ 0x2000).
- Solución adoptada: **firma de memoria** — buscar en el heap el QWORD `game1.exe+234130` (en `K+0x34`) y validar `K+0x3C = game1.exe+4C470` e interno = pantalla × 256 (script 9). Se re-localiza automáticamente si deja de validar (cambio de nivel).
- Para modificar el Prestigio hay que escribir el **interno** (`+0x4`); el de pantalla se recalcula.

## 8. Tabla de la trilogía de wepon1984 (`trilogy.CT`, analizada 2026-11-08)

CT v46, 382 entradas. Un grupo por ejecutable; al activarlo hace `OpenProcess("gameN.exe")`. **No trae Lua de tabla ni comentarios con la build.** Casi todo son direcciones estáticas sin AOB, así que se rompe con cada parche. Solo hay inyecciones AOB en GV3 (Health, PlayerMaxHealth, Enemy1HitKill) y en Connect iX (3 indicadores).

| Ejecutable | Juego | Contenido |
|---|---|---|
| `game1.exe` | GV1 | Nivel, EXP, Créditos, 28 materiales, Tiempo, Medallas, HP, temporizador de invencibilidad, EP, Skill Points, 4 cooldowns, Score, Kudos |
| `game2.exe` | GV2 | Gunvolt y Copen por separado (EXP, Créditos, Nivel, materiales en **1 byte**, 50 ranuras de equipo…); Score, Medallas, Tiempo, HP (×16), Kudos (×160) |
| `game3.exe` | GV3 | Base `game3.exe+1E2CE98` con cadenas de punteros (EXP, Nivel, Tiempo, Score, Kudos *float*, Image Chips…) + inyección de vida (`F3 0F 11 41 08 83 49 18 01 C3 0F`) |
| `game4.exe` | Connect iX | Bases `+190E590`, `+19279E8`, `+18223A8` (cadena de 7 niveles para la moneda) + 3 inyecciones de indicadores |

### 8.1 Cruce con nuestro mapa de GV1

La tabla es de **otra build** de `game1.exe`: los Créditos están en `+7AA5F0` y en la nuestra (2026-10-07) en `+7B3668` (Δ = **+0x9078**). El bloque de combate se corrió distinto (EP `+7E465C` → `+7ED64C`, Δ = **+0x8FF0**). Por eso las direcciones de abajo son solo **candidatas**: la columna «nuestra build» suma el Δ de la zona más cercana. **Ninguna está verificada.**

| Dato (wepon1984) | Su build | Relación | Nuestra build (candidata) | Contraste con lo que sabemos |
|---|---|---|---|---|
| Credit | `+7AA5F0` | — | `+7B3668` ✅ | Verificado en vivo |
| Materials | `+7AA9A0` | Créditos + 0x3B0 | `+7B3A18` ✅ | Coincide con §7.5 (+0x3B0, no +0x3A8) |
| Level («no modificar», 2 B) | `+7AAA6C` | Créditos + **0x47C** | `+7B3AE4` | Confirma la sospecha de §7.5: el +8 también corre el nivel. Corregir el «¿Nivel? `+0x474`» de `CLAUDE.md` |
| EXP | `+7A6930` | Créditos − 0x3CC0 | `+7AF9A8` (Δ 0x9078) | En gv1.CT EXP iba junto al nivel (+0x470 → aquí sería +0x478). Probar las dos |
| **HP** | `[+7AA1C0]+398` | puntero a objeto jugador | `[+7B3238]+398` | La forma coincide: componente de vida = objeto + 0x398. Daría un **puntero estático** al jugador sin inyección |
| Invincibility Timer (*Float*) | `[+7AA1C0]+518` | objeto + 0x518 | `[+7B3238]+518` | Coincide con nuestro `[gv1_player]+518`. Nosotros lo leímos como entero (11520); él lo declara *Float*. Revisar el tipo |
| Energy Bar (lleno 5 000 000) | `+7E465C` | bloque de combate | `+7ED64C` ✅ | Coincide (escala y posición) |
| Skill Point (3 = 60 000 000) | `+7E4660` | EP + 4 | `+7ED650` ✅ | Coincide |
| Skills Cooldown 1–4 (76 800) | `+7E4668…74` | EP + 0xC… | `+7ED658…` ✅ | Coincide. Usa el **primer** bloque, no la copia en `+7ED67C` (indicio de cuál manda) |
| Time | `+7D80D4` | — | `+7E10C4` o `+7E114C` | Δ incierto: medir |
| Medals | `+7D80DC` | Time + 8 | Time + 8 | En gv1.CT también iban juntos (+8) |
| Score | `+8A6C68` | — | sin Δ fiable | Lejos de las otras zonas: buscar con escaneo |
| Kudos (máx. 1 599 840) | `+8CBE10` | — | sin Δ fiable | 1 599 840 = 9999 × **160**, no ×256 como nuestra estructura K (§7.6). Puede ser otra copia (total del nivel o HUD). Comparar en vivo |

### 8.2 Qué aporta al proyecto

1. **Tres pendientes resueltos sin depurador:** dónde buscar EXP, Score y Tiempo/Medallas en GV1.
2. **Puntero estático al jugador** (`[game1.exe+7B3238]` candidato): si se confirma, la tabla final puede leer HP e invencibilidad sin la inyección de captura. Igual conviene resolverlo por AOB (la instrucción que lee esa global) para sobrevivir parches.
3. **Indicio sobre el bloque de combate duplicado:** wepon1984 usa el primero (`+7ED64C`).
4. **GV2, GV3 y Connect iX ya tienen un mapa de partida** para la Trilogy (antes solo teníamos las tablas de las versiones individuales). Las escalas de GV2 coinciden con §3 (HP ×16, Kudos ×160).
5. **Defecto en el original:** 6 armas EX de Connect iX tienen `DropDownListLink` a «Anchor Nexus», que no tiene lista. La tabla alfa quita esos enlaces al portar.
6. **Créditos de la versión FearLess:** al derivar de esta tabla, también hay que acreditar a wepon1984 (no solo a ndck1).

### 8.3 Verificación (sin depurador)

Implementada en `sondas/verificar_candidatas_gv1.lua` (también como «🔎 Verificar candidatas» en la multisonda y en la tabla alfa). Es un script Lua para el Lua Engine que lea cada candidata de §8.1 y muestre el valor junto a lo que se ve en pantalla. Para Time y EXP, que pruebe las dos opciones de Δ. Para el puntero al jugador, que compruebe `[[+7B3238]+398+18] == 1` (marca de jugador) y HP actual ≤ máximo.

### 8.4 Resultado de la verificación v1 (2026-11-08, 2 min de muestreo)

Informe: `dumps/verificar_candidatas_gv1_v1_2026-11-08.txt`. Durante el muestreo el personaje subió de nivel, recogió 1 medalla y terminó con 1902 de Prestigio en pantalla.

| Dato | Resultado | Conclusión |
|---|---|---|
| Nivel `Créditos+0x47C` | 31 → 32 (1 cambio) | ✅ **Nivel** |
| EXP `Créditos+0x478` | 303 450 → 312 000 (15 cambios) | ✅ **EXP** (forma de gv1.CT + 8, igual que los materiales) |
| EXP `+7AF9A8` (Δ de wepon1984) / `Créditos+0x470` | 0, sin cambios | ❌ |
| `Créditos+0x474` | 14, sin cambios | ❌ no es el nivel (campo desconocido) |
| Puntero `[+7B3238]` | no apunta al jugador | ❌ (el Δ local era +0x9060, no +0x9078) |
| Punteros al objeto jugador en `game1.exe` | **`+7B3220`**, `+7E02F8`, `+7ED630` (= `gv1_player`) | ✅ en esta sesión; falta confirmar tras reiniciar el juego |
| Bloque de combate `+7ED64C` | Energía cambió 73 veces | ✅ **manda** |
| Copia `+7ED67C` | sin cambios; difiere en `+1C…+24` (230 400 = 3 × 76 800) y `+2C` | ❌ no manda (¿copia del punto de control?) |
| Energía | 6 500 000 (no 5 000 000) | el «lleno» depende de mejoras: se etiqueta solo como ×10 000 |
| Tiempo `+7E114C` / `+7E10C4` | 0 / 79 824 036, sin cambios | ❌ |
| Medallas (Tiempo + 8) | 0 y 0 con 1 medalla recogida | ❌ |
| Score `+8AFCE0` / `+8AFC58` | 0xFFFFFFFF / 0 | ❌ |
| Kudos `+8D4E88` / `+8D4E00` | 0 y 0 con 1902 en pantalla | ❌ |

**Segunda corrida (03:37, misma sesión; `dumps/verificar_candidatas_gv1_v1b_2026-11-08.txt`):** repite todo. EXP +0x478 cambió 13 veces más (318 750 → 325 050). La Energía del bloque 1 bajó a 6 405 000 mientras la copia siguió en 6 500 000: confirma que la copia no manda. El Prestigio en pantalla pasó de **1902 a 2620** y las 4 candidatas de Kudos siguieron en 0: descartadas. Las Medallas pasaron de **1 a 2** y las 2 candidatas siguieron en 0: descartadas también. Los 3 punteros al jugador apuntan al mismo objeto (`1B365BE3910`), pero sin reiniciar el juego todavía no prueban que sobrevivan.

**Menú de estado al terminar la misión (captura del usuario):** Nv 32 · PV 355/355 · PE 650 · PH 3 · Créditos 299 779 · Puntos totales 1 409 193 · Tiempo total 04:45:05.
- PE 650 = 6 500 000 / 10 000 → escala de la Energía **×10 000** confirmada; PH 3 = 60 000 000 / 20 000 000 ✅.
- **Bloque de combate `+0x2C` = 355** (350 en la primera corrida, con Nv 31): probable **PV máx. sin escalar** (`game1.exe+7ED678`; en la copia vale 0). Candidato.
- Puntos totales y Tiempo total: la v2 del script los pide y los busca en `game1.exe` (sección F; el tiempo en s, fotogramas y ms).

Lección: **los Δ entre builds no son uniformes** ni siquiera dentro de una misma zona (+0x9060 a +0x9078). Trasladar con Δ fijo solo sirve como pista; lo fiable es buscar el valor (v2 del script: Kudos ×1/×160/×256 y Medallas por valor, Tiempo por «aumentó» en `game1.exe`) o buscar punteros al objeto ya capturado.

### 8.5 Resultado de la verificación v2 (2026-11-08 03:53, otra partida cargada)

Informe: `dumps/verificar_candidatas_gv1_v2_2026-11-08.txt`. Se cargó una partida anterior (Nv 31, Créditos 296 939) y en 2 min el personaje subió a Nv 36.

| Dato | Resultado | Conclusión |
|---|---|---|
| Punteros `+7B3220`, `+7E02F8`, `+7ED630` | los 3 apuntan al **nuevo** objeto jugador (`1F2A8A0E910`, antes `1B365BE3910`) | ✅ sobreviven a recargar la partida (falta reiniciar el exe) |
| Bloque de combate `+0x2C` | 350 → 375 con 5 subidas de nivel | ✅ **PV máx. sin escalar** (+5 por nivel) |
| Nivel / EXP | 31 → 36 / 295 350 → 398 850 | ✅ (otra vez) |
| `Créditos+0x438` (`+7B3AA0`) | = EXP (398 850), mismo ritmo | copia de la EXP (candidato) |
| Kudos ×1 (38 escrito a mano) | 80 coincidencias; `+7FFEC8` 38 → 2357 y `+7FFEE0` 38 → 2363 | candidatos (falta el valor final de pantalla) |
| Kudos ×160 / ×256 | 0 / 9 coincidencias, ninguna cambió | ❌ en `game1.exe` |
| Medallas | el usuario tenía 0 (no se buscó) | pendiente |
| Tiempo («aumentó» cada 10 s) | 1862 supervivientes. Destacan `+7E10D4` (≈ 7100/s, valor ≈ 126 s × 7500) y `Créditos−0xE0` = `+7B3588` (≈ 7500/s) | `+7E10D4` = wepon1984 `+7D80D4` + **0x9000** exacto → **Tiempo de nivel** probable; `Créditos−0xE0` = **Tiempo total** (forma de gv1.CT), unidad por confirmar |

Hipótesis: en la zona de `+7D…`/`+8…` el Δ con la build de wepon1984 es **+0x9000**, no +0x9078 ni +0x8FF0. Si se cumple, Medallas = `+7E10DC`, Score = `+8AFC68` y Kudos = `+8D4E10`. La v3 del script sigue esas direcciones durante 5 min.

### 8.6 Resultado de la verificación v3 (2026-11-08 04:04, 5 min)

Informe: `dumps/verificar_candidatas_gv1_v3_2026-11-08_0404.txt` (con las observaciones del usuario al final). Prestigio en pantalla 988 → 2807 · Medallas 1 → 3 · Nv 36 → 43.

| Dato | Resultado | Conclusión |
|---|---|---|
| Medallas `+7E10DC` | 1 → 3 (2 cambios), igual que la pantalla | ✅ **Medallas del nivel**; confirma el Δ **+0x9000** de la zona |
| Tiempo de nivel `+7E10D4` | 167 cambios en 301 s | ✅ |
| Tiempo total `Créditos−0xE0` | 301 cambios; 113 320 832 con el menú en 04:06:38 (14 798 s) | ✅ ≈ **7660 unidades/s** (probablemente 60 × 128 = 7680; la diferencia sería el tiempo entre leer el menú y lanzar el script) |
| PV máx. `+7ED678` | 375 → 410 con 7 niveles | ✅ (+5 por nivel) |
| Score `+8AFC68` | 16 777 215 (0xFFFFFF), fijo | ❌ |
| Puntos totales 1 409 193 | 0 coincidencias en `game1.exe` | ❌ no es estático |
| Kudos `+8D4E10` (×160) | 0, fijo | ❌ |
| `+7FFEC8` / `+7FFEE0` | 0 → 3134 / 0 → 2880 con el Prestigio 988 → 2807 | ❌ no son el Prestigio (empezaron en 0 con 988 en pantalla); contadores de combate sin identificar |
| Prestigio ×1 / ×160 / ×256 en `game1.exe` | 12 / 0 / 0 coincidencias de 988; ninguna cambió | ❌ **no hay Kudos estático**: se mantiene la estructura K del heap (§7.6) |
| Otras medallas | `Créditos+0x44C` (+7B3AB4), `+8C1764`, `+8C2DBC`: 1 → 2 | copias (¿medallas guardadas?) sin confirmar |

Con esto el Δ con la build de wepon1984 queda así: **+0x9078** en el bloque de partida (Créditos, materiales), **+0x9060** en el puntero al jugador, **+0x8FF0** en el bloque de combate y **+0x9000** en la zona del nivel en curso (Tiempo, Medallas).

## 9. GV3 (`game3.exe`) — plan: como mínimo, los mismos cheats que GV1 (2026-11-08)

Fuentes: `gv3.CT` de RTX_XXXX (GV3 suelto, `game.exe`, 5 AOB; §4) y el grupo de GV3 de wepon1984 (`trilogy.CT`: base `game3.exe+1E2CE98` con cadenas de punteros + la misma AOB de vida). Nada verificado aún en nuestra build.

| Cheat de GV1 (mínimo) | Pista en GV3 | Fuente | Estado |
|---|---|---|---|
| Captura del jugador / HP actual y máx. | AOB `F3 0F 11 41 08 83 49 18 01 C3 0F` (`movss [rcx+08],xmm0`): HP *float* `+08`, máx. `+0C`, jugador si `[rcx+20]==1` | RTX + wepon1984 | ⏳ diag B |
| Invencibilidad | AOB `F3 0F 10 86 10 05 00 00 45` (`[rsi+510]` float) · cadena `[[[base]+10]+10]+592` (temporizador) / `+594` (on/off) | RTX · wepon1984 | ⏳ diag B / C |
| Prestigio ×N / mantener | `[base]+264` *float* | wepon1984 | ⏳ diag C |
| EXP ×N / EXP / Nivel | `[[[base]+20]+110]+2A80` / `+2A86` (byte) | wepon1984 | ⏳ diag C |
| PH / habilidades / cooldowns | Talismanes: AOB `88 91 9A 06 00 00` (`mov [rcx+69A],dl` → 8) | RTX | ⏳ diag B |
| PE | «Fetters Gauge» `[base]+478` *float* | wepon1984 | ⏳ diag C |
| Tiempo de nivel | `[base]+354` *float* | wepon1984 | ⏳ diag C |
| Score (GV1 no lo tiene fijo) | `[base]+44` · AOB HighScore `F3 0F 11 83 F8 00 00 00 40` (`[rbx+F8]` float) | wepon1984 · RTX | ⏳ |
| Créditos, materiales, medallas, tiempo total, PV máx. | **sin datos** en las referencias | — | por buscar (si existen en GV3) |
| 🎁 Extra: One Hit Kill | en el mismo hook de vida (enemigo → HP 0) | RTX | ⏳ |
| 🎁 Extra: Image Chips | `[base]+198` (bits) | wepon1984 | ⏳ |

Riesgos conocidos: «Invencible ambos» de RTX usa un `call` relativo (`E8 AC 17 DF FF`), casi seguro roto; congelar talismanes **cierra el juego al cambiar a Gunvolt** (wepon1984); el depurador cierra GV3 (Algester) → todo sin depurador.

Primer paso: `sondas/diag_gv3.lua` (solo lectura): build, unicidad de las 5 AOB, cadenas desde la base de wepon1984 y, si no sirve, barrido de ±0x80000 usando el Nivel y el Prestigio de pantalla; muestreo de 5 min.

### 9.1 Diagnóstico v1 (2026-11-08 05:09; `dumps/diag_gv3_v1_2026-11-08_0509.txt`)

- Build de `game3.exe`: TimeDateStamp `6ACDDCD4` = **2026-10-13** (base `7FF708690000`, tamaño `0x2130000`).
- AOB de vida `F3 0F 11 41 08 83 49 18 01 C3 0F` → **única** en `game3.exe+8B5B62` ✅.
- Las otras 4 AOB de RTX_XXXX → 0 coincidencias: su tabla es del GV3 suelto (`game.exe`), otro binario.
- Base de wepon1984 `+1E2CE98` → contiene texto («oLocalIm»): la zona se movió; el barrido ±0x80000 con Nivel 32 / Prestigio 5 no encontró la base.

**¿Qué aporta `gv3.CT` (RTX_XXXX)?** Solo la AOB de vida funciona tal cual, pero sus **offsets de campo** pueden seguir valiendo aunque el código cambie: `+510` temporizador de invencibilidad (float) en el objeto jugador, `+69A` talismanes (byte), `+F8` Score (float); y la lógica de vida (jugador si `[rcx+20]==1`, HP máx. en `+0C`, 1HK poniendo a 0 el HP de los enemigos). La v2 del diagnóstico los busca con AOB flexibles y con un mapa de campos alrededor del componente de vida capturado.

### 9.2 Diagnóstico v2 (2026-11-08 05:26 y 05:32; `dumps/diag_gv3_v2_2026-11-08_0526/0527/0532.txt`)

- **Base de wepon1984 hallada en `game3.exe+1F02FE8`** (Δ **+0xD6150** respecto a su build). Desde ahí sus cadenas leen EXP 35 708, **Kudos 4108,46 (pantalla 4108)**, Score 911 858 y Tiempo 6,97 → con esta base salen EXP, Nivel, Prestigio (*float*), Score, Tiempo, Fetters, invencibilidad e Image Chips **sin inyección**. Pendiente: confirmar cada campo por comportamiento (v3).
- AOB flexibles de RTX_XXXX: `+510` aparece en 14 sitios, todos `[rbp+510]` → ambigua; `+69A` no aparece (el campo de talismanes se movió); `+F8` 29 sitios → inútil como firma.
- La captura no se pudo instalar: la zona de vida ya estaba parchada por otro script (el «Health» de GV3 portado de wepon1984 en la tabla alfa). La v3 informa el destino del salto y sigue sin captura.

### 9.3 Diagnóstico v3 (2026-11-08 05:36, 5 min; `dumps/diag_gv3_v3_2026-11-08_0536.txt`)

Base `game3.exe+1F02FE8` encaja otra vez (estable entre corridas de la misma sesión). Pantalla al final: Nivel 37, HP lleno, Prestigio 2446.

| Campo (cadena de wepon1984) | Muestreo 5 min | Conclusión |
|---|---|---|
| EXP `[[[B]+20]+110]+2A80` | 36 863 → 40 313 (51 cambios) | ✅ EXP |
| Nivel `…+2A86` (byte) | 34 → 36 (pantalla 37 poco después) | ✅ Nivel |
| Prestigio `[B]+264` (float) | 579 → 1899,86 (59 cambios) | ✅ (en la v2: 4108,46 con 4108 en pantalla). `[B]+268` float sube a la par (¿ritmo/multiplicador?) |
| Score `[B]+44` | 2800 → 204 025 (4 cambios) | ✅; `[B]+348` es la misma cifra en float |
| Fetters `[B]+478` (float) | 126 → 180,5 (44 cambios) | ✅ cambia (significado exacto por confirmar) |
| Tiempo `[B]+354` (float) | 5,59 → 6,56 (274 cambios) | ⚠️ cambia, pero ~1 unidad en 300 s: unidad por confirmar |
| Image Chips `[B]+198` (byte, bits) | 1 → 31 (4 cambios) | ✅ máscara de chips del nivel (31 = 5 chips); `[B]+0xA0` también 0 → 31 |
| Invencibilidad `[[[B]+10]+10]+592` (2 B) | 0 → 0 con **39 cambios** | ✅ sube con cada golpe y vuelve a 0 → temporizador |
| `…+594` (2 B) | 255 → 255 con 26 cambios | cambia durante los golpes (¿estado?) |

No hubo captura del jugador: el «Health» de GV3 de la tabla estaba activo (el parche salta a `7FF708680000`).

**Image Chips (fuentes):** según el resumen de la wiki de la saga obtenido en la búsqueda (no se pudo abrir la página: HTTP 402; Steam devolvió 429), los Image Chips son la forma principal de conseguir **Image Pulses**: cada **par** de chips da 1 Image Pulse y completar todos los del nivel da 1 más; reintentar desde un punto de control no borra los chips ya recogidos. La tabla de wepon1984 agrupa los niveles en 0, 3, 5 y 7 chips (World Moebius 0; Sunrise Throne 3; Futures Institute / Ballistic Missiles 5; el resto 7). Por eso la tabla ofrece una lista «todos» = 7 / 31 / 127. **Por probar:** si al terminar el nivel cuenta `+198` o `+0xA0`, y que no rompa nada marcar chips en un nivel con menos.

Con esto la alfa **v0.4** arma el grupo de GV3: invencibilidad (Lua, aprende el valor del temporizador), EXP ×N, Prestigio ×N / mantener (float), Image Chips, valores y el «Health» de wepon1984 (vida máx. / One Hit Kill), cuya AOB es única en esta build.

### 9.4 Pruebas del usuario con la v0.4 (2026-11-08)

- **Prestigio ×N / mantener ✅** funciona.
- **«Invencibilidad» ❌**: mantener alto `jugador+0x592` (el «Invincibility Timer» de wepon1984) pone el juego en **cámara lenta**: es el temporizador del efecto de golpe (*hitstop*), no la invencibilidad. Se conserva como «Cámara lenta» y se usa como **marca de golpe** en `sonda_invencibilidad_gv3.lua`, que busca temporizadores y banderas en el objeto jugador (0x1000 bytes) y en el objeto base (0x800). El mapa de la v3 se cortó en 80 filas (hasta `jugador+0x5E8`), así que la invencibilidad puede estar más adelante; pista de RTX_XXXX: float en `+0x510` de algún objeto.
- **Kudos bloqueados** (castigo; negativo en pantalla, positivo en memoria): el usuario lo redujo a `1EB84B92A1C`, `1EC07DA7578`, `1EC087719D0`. La primera es **`[B]+0x2FC`** (`[B]` = `1EB84B92720` en esa sesión), en el mismo objeto que los Kudos (`+0x264`); en el mapa de la v3, `[B]+0x2FC` cambió 26 veces. Las otras dos están en el heap, fuera de los objetos conocidos. **`1EC07DA7578` descartada**: cayó a 0 al pasar a otra fase del nivel (copia temporal); queda `1EC087719D0` por aclarar. `sonda_kudos_bloqueados_gv3.lua` confirma el tipo (entero/float) y cómo se paga; mientras tanto, el script «quitar ×N / anular» usa `[B]+0x2FC` y detecta el tipo solo.

### 9.5 Sonda de Kudos bloqueados (2026-11-08 06:17; `dumps/sonda_kudos_bloqueados_gv3_2026-11-08_*.txt`)

Pantalla al empezar: castigo −680, Kudos 8672.

| Dirección | Lectura | Conclusión |
|---|---|---|
| `[B]+0x2FC` (`1EB84B92A1C`) | **float 680,26** (= pantalla); 680 → 0 con 93 cambios en 5 min | ✅ **castigo vivo** (*float*, positivo en memoria) |
| `1EC087719D0` | entero 680, sin cambios | ❌ copia fija del castigo inicial |
| `[B]+0x2F8` / `+0x300` | 1 / constante | sin relación |
| Kudos `[B]+0x264` | 8672 → 8978,24 (1 cambio) | el castigo baja **solo**, no al ganar Kudos (solo 1 de 93 bajadas coincidió con una subida de Kudos) |

Punteros estáticos al castigo: `[game3.exe+1F02FE8]+0x2FC` y `[game3.exe+1F02FD8]+0x12AC` (respaldo: otro objeto que contiene al base a −0xFB0).

### 9.6 Diagnóstico v3, segunda corrida (2026-11-08 06:47) y prueba de EXP ×N

Pantalla al final: HP ~60 %, Prestigio 14 556, Nivel 37. Cadenas: EXP 371 228 → 373 733 (52 cambios), Nivel 37 fijo, Score 0 → 7 051 047, Kudos 0 → 9741,17, Fetters 100 → 140,89, Image Chips 127 fijo (puesto con la lista «7 de 7»).

- **EXP ×N ❌:** entre la corrida de 05:36 (EXP 40 313, Nv 36) y esta (EXP 371 228, Nv 37) el multiplicador infló la EXP de la cadena, pero el nivel casi no se movió → `[[[B]+20]+110]+2A80` es una copia o un acumulador, **no** la EXP que decide el nivel. Siguiente paso: `sonda_exp_gv3.lua` (EXP del menú buscada en toda la memoria + muestreo).
- El objeto jugador cambió 2 veces durante el muestreo (cambio de fase): los trucos que lo usan deben volver a resolverlo en cada lectura (ya lo hacen).
- En el objeto base, `[B]+0x2AC` (0 → 1, 97 cambios) y `[B]+0x5E0` (0 → 15, 53 cambios) son nuevos candidatos sin significado aún.
