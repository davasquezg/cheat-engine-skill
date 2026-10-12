# Formato de archivo `.CT` (Cheat Engine)

Un `.CT` es XML UTF-8. Lo que sigue resume lo verificado sobre tablas reales (incluida la tabla de prueba de Mega Man Star Force, `CheatEngineTableVersion="52"`). Si algo no calza, compáralo con una tabla que tú mismo guardes desde tu versión de CE: esa es la referencia válida.

## Esqueleto

```xml
<?xml version="1.0" encoding="utf-8"?>
<CheatTable CheatEngineTableVersion="52">
  <CheatEntries>
    <CheatEntry> ... </CheatEntry>
  </CheatEntries>
  <UserdefinedSymbols/>           <!-- símbolos definidos a mano (Name/Address) -->
  <LuaScript>...</LuaScript>      <!-- opcional: Lua de tabla, CE pregunta si ejecutarlo -->
  <Structures>...</Structures>    <!-- opcional: disecciones de estructuras -->
</CheatTable>
```

## `<CheatEntry>`: campos habituales

| Elemento | Notas |
|---|---|
| `ID` | Entero único en toda la tabla. Al crear entradas nuevas, usa `max(ID)+1`. |
| `Description` | Va **entre comillas dobles** dentro del texto: `"HP"`. Los prefijos `##` son una convención de comentario (no hacen nada). |
| `Options` | Atributos: `moHideChildren`, `moDeactivateChildrenAsWell`, `moActivateChildrenAsWell`, `moManualExpandCollapse`, `moAllowManualCollapseAndExpand`, `moDefaultCollapsed`, `moAlwaysHideChildren`. |
| `GroupHeader` | `1` = encabezado de grupo. Puede tener o no `<Address>`. |
| `VariableType` | `Byte`, `2 Bytes`, `4 Bytes`, `8 Bytes`, `Float`, `Double`, `String`, `Array of byte`, `Binary`, `Auto Assembler Script`, `Custom`. |
| `Address` | Ver la sección siguiente. |
| `Offsets/Offset` | Hex sin `0x`. **Orden inverso** (ver abajo). |
| `ShowAsHex`, `ShowAsSigned` | `1`/`0`. |
| `Color` | BGR en hex (`0000FF` = rojo). |
| `DropDownList` / `DropDownListLink` | Lista `valor:texto` por línea; `Link` apunta a la **Description** de otra entrada que tiene la lista. |
| `AssemblerScript` | Script AA (con `[ENABLE]`/`[DISABLE]`). Puede contener bloques `{$lua}` ... `{$asm}`. |
| `Hotkeys` | Teclas rápidas; antes de editarlas a mano, revisa cómo las guarda tu versión de CE. |
| `CheatEntries` | Hijos. |

## Direcciones

| Forma | Significado |
|---|---|
| `"modulo.exe"+0E120A40` | Estática: base del módulo + RVA. Es frágil ante parches. |
| `simbolo` / `simbolo+10` | Símbolo registrado (`registersymbol`, `registerSymbol()` de Lua o `UserdefinedSymbols`). |
| `+288` / `-4` | **Relativa** a la dirección resuelta del ancestro más cercano que tenga `<Address>`. Los encabezados de grupo sin dirección no cuentan. |
| `1A2B3C4D` | Absoluta: solo sirve durante una sesión. |

### Orden de los offsets

En el XML, el **primer** `<Offset>` es el **último** que se aplica (el más cercano al valor). En la GUI de CE aparece arriba. Ejemplo real (Zenny, SF1):

```xml
<Address>+238</Address>
<Offsets><Offset>70</Offset><Offset>70</Offset></Offsets>
```
y su padre es `"MEGAMAN_STARFORCE_Legacy_Collection.exe"+0E120A40` con `Offsets=[0]`. La cadena completa queda así:

```
[[["MEGAMAN...exe"+0E120A40]+238]+70]+70
   └ base del juego ┘
```

`ct_tool.py chains` hace esta expansión para cada entrada, y `ctFindStatic()` (Lua) recibe los offsets en ese mismo orden de aplicación: `{0x238, 0x70, 0x70}`.

## Patrón de tabla resistente a parches

1. **Pocas anclas.** Todas las entradas cuelgan de 1–3 bases. La tabla de prueba tiene 2207 direcciones y solo 2 anclas.
2. **Anclas por símbolo**, no por `modulo+RVA`. Un script `[Resolver]` las calcula con AOB y registra el símbolo.
3. **Respaldo estático** dentro del resolver, para cuando el AOB falla.
4. **Grupos anidados bajo el resolver** (`moHideChildren` + `moDeactivateChildrenAsWell`). Así nadie congela valores con la base sin resolver.
5. **Documentar la build** (SHA-256, TimeDateStamp, Steam BuildID) en una entrada `##` o en el `note` del resolver.
