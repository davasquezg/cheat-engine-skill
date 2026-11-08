-- =====================================================================================
-- investigar_direccion_gv1.lua — Investiga una dirección encontrada a mano (p. ej. Prestigio)
-- para convertirla en algo que sobreviva a reinicios. Pegar en Memory View > Tools > Lua Engine.
--   1) Lee el valor como 4 bytes / float / 2 bytes / 1 byte.
--   2) Lo relaciona con lo ya conocido (gv1_player, gv1_hp, bloque de partida y de combate).
--   3) Busca PUNTEROS ESTÁTICOS (desde game1.exe) de 1 y 2 niveles hacia la dirección.
--   4) Vuelca los vecinos (±0x40) y muestrea 10 s para ver cómo cambia (juega mientras tanto).
-- Resultado: ventana + portapapeles + archivo en dumps. No escribe memoria del juego.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local OBJ      = 0x1FCEA9A34D4          -- <<< dirección a investigar (cámbiala si hace falta)
local MAXOFF   = 0x2000                 -- offset máximo por nivel de puntero
local MOD      = "game1.exe"
local OUTFILE  = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\investigar_direccion.txt]]

local out = {}
local function p(f, ...) out[#out + 1] = string.format(f, ...) end
local base = getAddressSafe(MOD); local size = getModuleSize(MOD)
if not base then showMessage("Adjunta CE a " .. MOD); return end
local function dir(a)
  if a >= base and a < base + size then return string.format("%s+%X", MOD, a - base) end
  return string.format("%X", a)
end

-- 1) Valor en varios tipos
p("== Dirección %X ==", OBJ)
p("  4 bytes = %s   float = %s   2 bytes = %s   1 byte = %s",
  tostring(readInteger(OBJ)), tostring(readFloat(OBJ)), tostring(readSmallInteger(OBJ)), tostring(readBytes(OBJ, 1)))

-- 2) Relación con lo conocido
local function rel(nombre, a)
  if a then p("  %-28s %X   Δ = %s0x%X", nombre, a, OBJ >= a and "+" or "-", math.abs(OBJ - a)) end
end
p("\n== Relación con estructuras conocidas ==")
local pp, ph = getAddressSafe("gv1_player"), getAddressSafe("gv1_hp")
rel("objeto jugador (gv1_player)", pp and readQword(pp))
rel("componente vida (gv1_hp)", ph and readQword(ph))
rel("bloque partida (Créditos)", base + 0x7B3668)
rel("bloque combate (Energía)", base + 0x7ED64C)

-- Escaneo de QWORD con valor entre lo y hi dentro de [desde, hasta)
local function qwordsEntre(lo, hi, desde, hasta, maxN)
  local ms = createMemScan()
  ms.firstScan(soValueBetween, vtQword, rtRounded, string.format("%X", lo), string.format("%X", hi),
               desde, hasta, "", fsmAligned, "8", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r = {}
  for i = 0, math.min(fl.Count, maxN) - 1 do
    local a = tonumber(fl.Address[i], 16)
    r[#r + 1] = { a = a, v = readQword(a) }
  end
  local total = fl.Count
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end

-- 3a) Nivel 1: game1.exe+X -> [ ] + off = OBJ
p("\n== Punteros estáticos de 1 nivel (game1.exe+X → +off) ==")
local n1 = 0
local r1 = qwordsEntre(OBJ - MAXOFF, OBJ, base, base + size, 500)
for _, h in ipairs(r1) do
  p("  [%s] + 0x%X", dir(h.a), OBJ - h.v); n1 = n1 + 1
  if n1 >= 20 then break end
end
if n1 == 0 then p("  (ninguno)") end

-- 3b) Nivel 2: game1.exe+X -> [ ]+o1 -> [ ]+o2 = OBJ
p("\n== Punteros estáticos de 2 niveles ==")
local holders, totalH = qwordsEntre(OBJ - MAXOFF, OBJ, 0x10000, 0x7FFFFFFFFFFF, 300)
p("  (objetos intermedios candidatos: %d, se revisan hasta 300)", totalH)
local n2 = 0
for _, h in ipairs(holders) do
  if not (h.a >= base and h.a < base + size) then
    local o2 = OBJ - h.v
    local r2 = qwordsEntre(h.a - MAXOFF, h.a, base, base + size, 20)
    for _, s in ipairs(r2) do
      p("  [[%s] + 0x%X] + 0x%X", dir(s.a), h.a - s.v, o2); n2 = n2 + 1
      if n2 >= 25 then break end
    end
  end
  if n2 >= 25 then break end
end
if n2 == 0 then p("  (ninguno: puede requerir 3+ niveles o una inyección de código)") end

-- 4a) Vecinos
p("\n== Vecinos (4 bytes) ==")
for off = -0x40, 0x40, 4 do
  local a = OBJ + off
  p("  %s%-5s %X : %s", off == 0 and ">" or " ", string.format("%+d", off), a, tostring(readInteger(a)))
end

-- 4b) Muestreo 10 s del valor y vecinos que cambian
local snaps = {}
local t = createTimer(nil, false)
t.Interval = 100
t.OnTimer = function(tm)
  local s = {}
  for off = -0x40, 0x40, 4 do s[off] = readInteger(OBJ + off) end
  snaps[#snaps + 1] = s
  if #snaps >= 100 then
    tm.destroy()
    p("\n== Muestreo 10 s: campos que cambiaron (offset: primero → último, nº de cambios) ==")
    for off = -0x40, 0x40, 4 do
      local c, prev = 0, snaps[1][off]
      for i = 2, #snaps do if snaps[i][off] ~= prev then c = c + 1; prev = snaps[i][off] end end
      if c > 0 then p("  %+5d : %s → %s  (%d cambios)", off, tostring(snaps[1][off]), tostring(snaps[#snaps][off]), c) end
    end
    local rep = table.concat(out, "\n")
    local f = io.open(OUTFILE, "w"); if f then f:write(rep); f:close() end
    writeToClipboard(rep)
    showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en dumps)")
  end
end
showMessage("Escaneos listos. Al cerrar este aviso empiezan 10 s de muestreo:\njuega normal (gana/pierde Prestigio).")
t.Enabled = true
