# Plantillas Auto Assembler

## 1. Resolver de bases (AOB + respaldo) — lo genera `ct_tool.py resolve`

Se genera a partir de un JSON:

```json
{
  "module": "Juego.exe",
  "description": "[Resolver] Bases — activar primero",
  "bases": [
    { "symbol": "game_base",
      "replaces": "\"Juego.exe\"+0E120A40",
      "aob": "48 8B 05 ?? ?? ?? ?? 48 85 C0 74 ?? 48 8B 40 ??",
      "disp_offset": 3, "instr_len": 7,
      "fallback_offset": "0E120A40",
      "note": "mov rax,[rip+X] @ build 2026-xx" }
  ]
}
```

- `disp_offset`: posición del disp32 contada desde el **inicio de la firma**.
- `instr_len`: posición del **fin de la instrucción** que contiene el disp, también contada desde el inicio de la firma. Si la firma empieza con bytes previos, suma esos bytes a ambos valores (sigmaker lo hace solo).
- La base se calcula como `hit + instr_len + disp32 (con signo)`.

## 2. Inyección de código con AOB (estándar de la comunidad)

Úsala para cheats de comportamiento ("HP infinito", "sin coste de carta"), no para leer bases.

```asm
[ENABLE]
aobscanmodule(INJ_HP, Juego.exe, 66 29 43 ?? 0F B7 43 ??)   // sub [rbx+??],ax ; movzx eax,[rbx+??]
alloc(newmem_hp, $1000, INJ_HP)
label(code_hp)
label(return_hp)

newmem_hp:
  // Solo el jugador: comparar con el puntero del jugador si hace falta
  // cmp rbx,[player_ptr]
  // jne code_hp
  xor ax,ax                 // daño = 0
code_hp:
  sub [rbx+18],ax           // instrucción original (ajustar al desensamblado real)
  movzx eax,word ptr [rbx+18]
  jmp return_hp

INJ_HP:
  jmp newmem_hp
  nop 3                     // completar hasta cubrir las instrucciones reemplazadas (≥5 bytes)
return_hp:
registersymbol(INJ_HP)

[DISABLE]
INJ_HP:
  db 66 29 43 18 0F B7 43 18   // bytes originales EXACTOS
unregistersymbol(INJ_HP)
dealloc(newmem_hp)
```

Reglas:
- **Copia los bytes originales del Memory View**, no del AOB con comodines.
- `alloc(..., $1000, INJ)` reserva memoria cerca de la inyección, así basta un `jmp` de 5 bytes.
- Si el código se comparte con enemigos, filtra por el puntero del jugador. En MMSF, el HP de batalla es `[[[[base]+288]+18]+10]+F0`, así que puedes comparar `rbx` con `[[[base]+288]+18]+10`.
- Para generar el esqueleto, usa *Template → AOB Injection* en Memory View (Ctrl+A) y adapta solo el cuerpo.

## 3. Bloque Lua dentro de AA

```asm
[ENABLE]
{$lua}
if syntaxcheck then return end   -- obligatorio: CE comprueba la sintaxis al editar
-- código Lua
{$asm}
[DISABLE]
{$lua}
if syntaxcheck then return end
-- deshacer
{$asm}
```

## 4. Entrada de puntero colgada de un símbolo (XML)

```xml
<CheatEntry>
  <ID>9001</ID>
  <Description>"Zenny"</Description>
  <VariableType>4 Bytes</VariableType>
  <Address>sf12_base</Address>
  <Offsets>            <!-- orden inverso: primero el último offset -->
    <Offset>70</Offset>
    <Offset>70</Offset>
    <Offset>238</Offset>
    <Offset>0</Offset>
  </Offsets>
</CheatEntry>
```
Esta entrada equivale a `[[[[sf12_base]+0]+238]+70]+70`.
