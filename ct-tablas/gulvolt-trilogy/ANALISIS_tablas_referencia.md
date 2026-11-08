# Análisis de tablas de referencia — Gunvolt 1, 2 y 3 (versiones individuales)

> Fecha: 2026-11-01. Fuente: tablas guardadas en `original/` (no se versionan). Objetivo: extraer **patrones** (estructuras, offsets relativos, lógica de inyección) para localizar los mismos datos en la *Trilogy Enhanced*. Nada de esto está validado aún en la Trilogy.

| Archivo | Juego / hilo | Autor | Ejecutable | Arquitectura | Método |
|---|---|---|---|---|---|
| `gv1.CT` | GV1 Steam 388800 — [t=1929](https://fearlessrevolution.com/viewtopic.php?t=1929) | WarCOzes (`wcz`) | `gv_win.exe` | **32 bits** | Direcciones estáticas `gv_win.exe+…` + 5 scripts (1 por AOB, 4 por dirección fija) |
| `gv2.CT` | GV2 v1.0 — [t=12924](https://fearlessrevolution.com/viewtopic.php?t=12924) | Shinkansen (V1001) | (`aobscan` sin módulo) | 64 bits | 2 inyecciones por AOB que **capturan punteros base**; todo lo demás es relativo a ellos |
| `gv3.CT` | GV3 — [t=21777](https://fearlessrevolution.com/viewtopic.php?t=21777) | RTX_XXXX (Update1.1) | `game.exe` | 64 bits | 6 inyecciones por AOB (`aobscanmodule`) |
| `A.S.G.T.E v1.1.1frf.CT` | Trilogy v1.1.1 — [t=35891](https://fearlessrevolution.com/viewtopic.php?t=35891) | ndck1 | `game1.exe` | 64 bits | 1 inyección por AOB (GV1) |

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
