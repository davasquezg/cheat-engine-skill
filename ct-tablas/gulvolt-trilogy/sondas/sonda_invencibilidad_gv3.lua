-- =====================================================================================
-- sonda_invencibilidad_gv3.lua (v7) — Busca la invencibilidad de GV3 (game3.exe) en la ENTIDAD que alimenta al
-- objeto visual del jugador. Solo lectura: no instala ganchos.
-- Historia (ANALISIS §9.7–9.13):
--   · El objeto V = [[[game3.exe+1F02FE8]+10]+10] es VISUAL: parpadeo (+0x21C/+0x22C/+0x3A8), máscara +0x274
--     (bit 0x10000 apagado durante el parpadeo) y estado de animación +0x060/+0x050. El juego REESCRIBE la máscara
--     y la animación en cada fotograma: forzarlas no da invencibilidad (modos 1 y 2, 2026-11-09).
--   · El componente de vida y sus dueños no tienen campos que sigan al parpadeo.
-- Esta v7 mapea lo que todavía no se ha mirado:
--   · I = [[game3.exe+1F02FE8]+10] (objeto intermedio entre la base y V), 0x1000 bytes;
--   · B = [game3.exe+1F02FE8] (objeto base), 0x800 bytes;
--   · hasta 4 objetos que apuntan a V (QWORD = V en memoria escribible), ±0x800 alrededor del puntero;
--   · V (para comparar).
-- En cada golpe (inicio del parpadeo V+0x21C) toma el reposo de cada DWORD y, al acabar el parpadeo, puntúa los
-- que cambiaron en ≤300 ms y volvieron a su valor ±400 ms del final. También marca los que SUBEN al golpe
-- (posibles temporizadores).
-- Uso: GV3 dentro de un nivel, todos los trucos de GV3 DESACTIVADOS. 30 s: recibe 3–4 golpes SEPARADOS ≥ 5 s
-- y NO ataques. Resultado: ventana + portapapeles + dumps\sonda_invencibilidad_gv3_v7_<fecha>_<hora>.txt.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local OUTFILE = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\sonda_invencibilidad_gv3_v7_]] ..
                os.date("%Y-%m-%d_%H%M") .. ".txt"
local MS, TICKS = 50, 600
local FIN_PARP, INICIO, TOL = 20, 6, 8

local b3 = getAddressSafe("game3.exe")
if not b3 then showMessage("Adjunta Cheat Engine a game3.exe primero."); return end
local size = getModuleSize("game3.exe")
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function objs()
  local B = readQword(BASE); if not valido(B) then return nil end
  local I = readQword(B + 0x10); if not valido(I) then return nil end
  local V = readQword(I + 0x10); if not valido(V) then return nil end
  return B, I, V
end
local B0, I0, V0 = objs()
if not B0 then showMessage("No se encontró el objeto del jugador de GV3. Entra a un nivel."); return end

local out = {}
local function p(f, ...) out[#out + 1] = string.format(f, ...) end
local function u32(b, o) return b[o + 1] | (b[o + 2] << 8) | (b[o + 3] << 16) | (b[o + 4] << 24) end
local function fmt(v)
  local f = string.unpack("<f", string.pack("<I4", v))
  if f == f and math.abs(f) >= 1e-3 and math.abs(f) < 1e7 then return string.format("%d|%.2f", v, f) end
  return tostring(v)
end

-- ---------------------------------------------------------------- regiones
p("== Sonda de invencibilidad GV3 v7 — %s ==", os.date("%Y-%m-%d %H:%M"))
p("B = %X · I = [B+10] = %X · V = [I+10] = %X", B0, I0, V0)
local regiones = {
  { n = string.format("I = [B+10] (%X)", I0), base = I0, rel = 0, largo = 0x1000 },
  { n = string.format("B (%X)", B0), base = B0, rel = 0, largo = 0x800 },
}
local ms = createMemScan()
ms.firstScan(soExactValue, vtQword, rtRounded, string.format("%X", V0), "", 0x10000, 0x7FFFFFFFFFFF, "+W",
             fsmAligned, "8", true, false, false, false)
ms.waitTillDone()
local fl = createFoundList(ms); fl.initialize()
p("Punteros a V en memoria escribible: %d", fl.Count)
local n = 0
for i = 0, math.min(fl.Count, 12) - 1 do
  local h = tonumber(fl.Address[i], 16)
  local enMod = h >= b3 and h < b3 + size
  local esI = h == I0 + 0x10
  p("  %X%s%s", h, enMod and string.format(" (game3.exe+%X)", h - b3) or "", esI and "  (= I+0x10, ya incluido)" or "")
  if n < 4 and not enMod and not esI then
    n = n + 1
    regiones[#regiones + 1] = { n = string.format("dueño de V %d (puntero en %X)", n, h), base = h - 0x800, rel = -0x800, largo = 0x1000 }
  end
end
fl.deinitialize(); fl.destroy(); ms.destroy()
regiones[#regiones + 1] = { n = string.format("V (%X)", V0), base = V0, rel = 0, largo = 0x1000 }
for _, r in ipairs(regiones) do r.val, r.reposo, r.ultimoDif, r.primerDif, r.pico, r.puntos, r.timer, r.ej = {}, {}, {}, {}, {}, {}, {}, {} end

-- ---------------------------------------------------------------- seguimiento en línea
local nLect, enGolpe, inicio, golpes, durs = 0, false, 0, 0, {}
local function leerRegiones()
  for _, r in ipairs(regiones) do
    local b = readBytes(r.base, r.largo, true)
    if b then
      for i = 0, r.largo // 4 - 1 do
        local v = u32(b, 4 * i)
        r.val[i] = v
        if enGolpe and r.reposo[i] ~= nil and v ~= r.reposo[i] then
          r.ultimoDif[i] = nLect
          if not r.primerDif[i] then r.primerDif[i] = nLect; r.pico[i] = v end
        end
      end
    end
  end
end
local function empezarGolpe()
  enGolpe, inicio = true, nLect
  for _, r in ipairs(regiones) do
    for i, v in pairs(r.val) do r.reposo[i] = v; r.ultimoDif[i] = nil; r.primerDif[i] = nil; r.pico[i] = nil end
  end
end
local function terminarGolpe(fin)
  enGolpe = false
  golpes = golpes + 1
  durs[#durs + 1] = (fin - inicio + 1) * MS
  for _, r in ipairs(regiones) do
    for i, rep in pairs(r.reposo) do
      local pd, ud = r.primerDif[i], r.ultimoDif[i]
      if pd and ud and pd - inicio <= INICIO and math.abs(ud - fin) <= TOL and r.val[i] == rep then
        r.puntos[i] = (r.puntos[i] or 0) + 1
        if r.pico[i] and r.pico[i] > rep then r.timer[i] = (r.timer[i] or 0) + 1 end
        if not r.ej[i] then r.ej[i] = string.format("%s → %s → %s", fmt(rep), fmt(r.pico[i] or rep), fmt(r.val[i])) end
      end
    end
  end
end

local function analizar()
  p("\nGolpes medidos: %d · parpadeo (ms): %s", golpes, table.concat(durs, ", "))
  for _, r in ipairs(regiones) do
    local c = {}
    for i, pt in pairs(r.puntos) do c[#c + 1] = { o = 4 * i + r.rel, s = pt, t = r.timer[i] or 0, e = r.ej[i] } end
    table.sort(c, function(x, y) if x.s ~= y.s then return x.s > y.s end return x.o < y.o end)
    p("\n== %s: cambian al golpe y vuelven al terminar el parpadeo ==", r.n)
    for i = 1, math.min(#c, 15) do
      p("  %s0x%03X  %d/%d golpes%s  %s", c[i].o < 0 and "−" or "+", math.abs(c[i].o), c[i].s, golpes,
        c[i].t > 0 and string.format(" (sube al golpe en %d)", c[i].t) or "", c[i].e)
    end
    if #c == 0 then p("  (ninguno)") end
  end
  local rep = table.concat(out, "\n")
  local fh = io.open(OUTFILE, "w"); if fh then fh:write(rep); fh:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
end

showMessage("Al cerrar este aviso empiezan 30 s: recibe 3–4 golpes SEPARADOS ≥ 5 s y NO ataques.\n" ..
  "(Todos los trucos de GV3 desactivados.)")
local estable = FIN_PARP
local t = createTimer(nil, false)
t.Interval = MS
t.OnTimer = function(tm)
  local ok, e = pcall(function()
    nLect = nLect + 1
    local _, _, V = objs()
    local a = V and readFloat(V + 0x21C) or 1
    if a ~= a then a = 1 end
    if not enGolpe and a < 0.99 and estable >= FIN_PARP then empezarGolpe() end
    leerRegiones()
    if a >= 0.99 then estable = estable + 1 else estable = 0 end
    if enGolpe and estable >= FIN_PARP then terminarGolpe(nLect - FIN_PARP) end
  end)
  if not ok or nLect >= TICKS then
    tm.destroy()
    if not ok then p("ERROR: %s", tostring(e)) end
    local okA, errA = pcall(analizar)
    if not okA then showMessage("ERROR al analizar: " .. tostring(errA)) end
  end
end
t.Enabled = true
