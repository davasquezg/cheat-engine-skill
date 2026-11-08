-- =====================================================================================
-- buscador_cambios_gv1.lua — Búsqueda por CAMBIOS (valor desconocido) para GV1, sin depurador.
-- Sirve cuando el número en pantalla no coincide con la memoria (escala, redondeo, float…).
--   1.ª ejecución: elige tipo (4 bytes / float / 2 bytes) y ámbito (módulo / todo) y hace un
--                  escaneo de "valor desconocido".
--   Siguientes:    +  subió   -  bajó   =  no cambió   número = valor exacto en memoria
--                  v  ver lista   r  reiniciar
--   Con ≤ 10 resultados muestra sus valores y deja registrar uno como símbolo (gv1_kudos…).
-- No escribe memoria del juego. Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local MOD = "game1.exe"
local base = getAddressSafe(MOD)
if not base then error("Adjunta Cheat Engine a " .. MOD) end
local size = getModuleSize(MOD)

local function lista(maxN)
  local fl = createFoundList(BC_GV1.ms); fl.initialize()
  local n, out = fl.Count, {}
  for i = 0, math.min(n, maxN) - 1 do
    out[#out + 1] = { a = tonumber(fl.Address[i], 16), v = fl.Value[i] }
  end
  fl.deinitialize(); fl.destroy()
  return n, out
end
local function dir(a)
  if a >= base and a < base + size then return string.format("%s+%X", MOD, a - base) end
  return string.format("%X", a)
end

if not BC_GV1 then
  local t = inputQuery("Buscador por cambios GV1", "Tipo: D = 4 bytes · F = float · W = 2 bytes", "D")
  if not t then return end
  t = t:upper():sub(1, 1)
  local vt, al = vtDword, "4"
  if t == "F" then vt = vtSingle elseif t == "W" then vt, al = vtWord, "2" end
  local s = inputQuery("Buscador por cambios GV1",
    "Ámbito: M = solo game1.exe (rápido) · P = toda la memoria escribible (lento, más resultados)", "P")
  if not s then return end
  local desde, hasta = 0x10000, 0x7FFFFFFFFFFF
  if s:upper():sub(1, 1) == "M" then desde, hasta = base, base + size end
  local ms = createMemScan()
  ms.firstScan(soUnknownValue, vt, rtRounded, "", "", desde, hasta, "+W", fsmAligned, al,
               false, false, false, false)
  ms.waitTillDone()
  BC_GV1 = { ms = ms, pasos = 1 }
  local n = lista(0)
  showMessage(string.format("Escaneo inicial listo: %d direcciones.\nAhora haz que el valor cambie (o no) y vuelve a ejecutar:\n+ subió · - bajó · = no cambió", n))
  return
end

local op = inputQuery("Buscador por cambios GV1",
  "Paso " .. (BC_GV1.pasos + 1) .. ":  + subió · - bajó · = no cambió · número exacto · v ver · r reiniciar", "=")
if not op or op == "" then return end
if op == "r" then BC_GV1.ms.destroy(); BC_GV1 = nil; showMessage("Reiniciado."); return end

if op ~= "v" then
  local so, inp = soUnchanged, ""
  if op == "+" then so = soIncreasedValue
  elseif op == "-" then so = soDecreasedValue
  elseif op == "=" then so = soUnchanged
  elseif tonumber(op) then so, inp = soExactValue, op
  else error("Opción no válida: " .. op) end
  BC_GV1.ms.nextScan(so, rtRounded, inp, "", false, false, false, false, false, "")
  BC_GV1.ms.waitTillDone()
  BC_GV1.pasos = BC_GV1.pasos + 1
end

local n, L = lista(20)
local lines = { string.format("Paso %d (%s): quedan %d", BC_GV1.pasos, op, n) }
for i, x in ipairs(L) do lines[#lines + 1] = string.format("  %2d) %s = %s", i, dir(x.a), tostring(x.v)) end
if n > 20 then lines[#lines + 1] = "  …  (sigue filtrando: '=' varias veces con el valor quieto ayuda mucho)" end
local rep = table.concat(lines, "\n")
writeToClipboard(rep)
showMessage(rep)

if n > 0 and n <= 10 then
  local sel = inputQuery("Buscador por cambios GV1", "Número de la lista a registrar (vacío = ninguno):", "")
  local i = tonumber(sel or "")
  if i and L[i] then
    local nombre = inputQuery("Buscador por cambios GV1", "Nombre del símbolo:", "gv1_kudos")
    if nombre and nombre ~= "" then
      registerSymbol(nombre, L[i].a, true)
      local m = getAddressList().createMemoryRecord()
      m.Description = nombre .. "  " .. dir(L[i].a)
      m.Address = dir(L[i].a)
      showMessage("Registrado '" .. nombre .. "' en " .. dir(L[i].a) .. " y agregado a la tabla.\n(Ajusta el tipo de la entrada si elegiste float o 2 bytes.)")
    end
  end
end
