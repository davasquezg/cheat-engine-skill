-- =====================================================================================
-- sonda_invencibilidad_gv3.lua (v5) — Busca la invencibilidad de GV3 (game3.exe) en la ENTIDAD del jugador.
-- Historia (ANALISIS §9.7–9.10):
--   v1–v3: el objeto [[[game3.exe+1F02FE8]+10]+10] tiene el parpadeo (+0x21C) y la cámara lenta (+0x590): es
--          VISUAL. Ningún campo suyo dura lo mismo que el parpadeo. El hook de vida (game3.exe+8B5B62) ve un
--          componente con [+20] = 1 y HP float, pero forzarlo al máximo NO protege («Vida infinita» y el
--          «Health» de wepon1984 no funcionan) → probablemente es la barra de la interfaz.
--   RTX_XXXX (GV3 suelto) tenía la invencibilidad en +0x510 de OTRO objeto (rsi).
-- Esta v5:
--   1) Instala un gancho de REGISTRO en la AOB de vida (si otro script la parchó, guarda su parche y lo
--      restaura al final) y espera al primer golpe para capturar el componente C ([+20] = 1).
--   2) Busca en toda la memoria escribible los QWORD que apuntan a C (sus dueños: la entidad real).
--   3) Durante 30 s sigue, SIN guardar las muestras: C (−0x400…+0xC00), hasta 3 dueños (±0x800) y el objeto
--      visual (0x1000). En cada golpe (inicio del parpadeo) toma el valor de reposo de cada DWORD y, al acabar
--      el parpadeo, puntúa los que cambiaron en los primeros 300 ms y volvieron a su valor ±400 ms del final.
--   Además informa el valor de +0x510 de cada dueño (pista de RTX_XXXX).
-- Uso: GV3 dentro de un nivel. Desactiva «Vida», «Health» y «Cámara lenta». Recibe UN golpe para capturar
-- (pitido); luego 3–4 golpes SEPARADOS ≥ 5 s y NO ataques. Lua Engine > pegar > Execute (o desde la tabla).
-- Escribe en el juego SOLO el gancho de registro (y lo restaura).
-- Resultado: ventana + portapapeles + dumps\sonda_invencibilidad_gv3_v5_<fecha>_<hora>.txt.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local OUTFILE = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\sonda_invencibilidad_gv3_v5_]] ..
                os.date("%Y-%m-%d_%H%M") .. ".txt"
local MS, TICKS, ESPERA = 50, 600, 90000
local FIN_PARP, INICIO, TOL = 20, 6, 8    -- fin = 1 s en 1,0; debe cambiar en ≤300 ms; volver ±400 ms
local VIDA_AOB = "F3 0F 11 41 08 83 49 18 01 C3 0F"
local VIDA_ORI = { 0xF3, 0x0F, 0x11, 0x41, 0x08 }

local b3 = getAddressSafe("game3.exe")
if not b3 then showMessage("Adjunta Cheat Engine a game3.exe primero."); return end
local size = getModuleSize("game3.exe")
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function visual()
  local a = readQword(BASE)
  a = valido(a) and readQword(a + 0x10) or nil
  a = valido(a) and readQword(a + 0x10) or nil
  return valido(a) and a or nil
end
if not visual() then showMessage("No se encontró el objeto del jugador de GV3. Entra a un nivel."); return end

local out = {}
local function p(f, ...) out[#out + 1] = string.format(f, ...) end
local function u32(b, o) return b[o + 1] | (b[o + 2] << 8) | (b[o + 3] << 16) | (b[o + 4] << 24) end
local function fmt(v)
  local f = string.unpack("<f", string.pack("<I4", v))
  if f == f and math.abs(f) >= 1e-3 and math.abs(f) < 1e7 then return string.format("%d|%.2f", v, f) end
  return tostring(v)
end

-- ---------------------------------------------------------------- 1) gancho de registro
local function escanear(tipo, valor, desde, hasta, prot, alin, maxN, hex)
  local ms = createMemScan()
  ms.firstScan(soExactValue, tipo, rtRounded, valor, "", desde, hasta, prot, alin,
               alin == fsmAligned and "8" or "1", hex, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, maxN) - 1 do r[#r + 1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end
local A, puesto, ajeno = nil, false, nil
local function quitarGancho()
  if puesto and A then
    writeBytes(A, ajeno or VIDA_ORI)
    unregisterSymbol("gv3_ring"); unregisterSymbol("gv3_idx")
    puesto = false
  end
end
local okG, errG = pcall(function()
  local r, total = escanear(vtByteArray, VIDA_AOB, b3, b3 + size, "", fsmNotAligned, 2, true)
  if total == 1 then
    A = r[1]
  else
    local r2, t2 = escanear(vtByteArray, "E9 ?? ?? ?? ?? 83 49 18 01 C3 0F", b3, b3 + size, "", fsmNotAligned, 2, true)
    if t2 ~= 1 then error(string.format("la AOB de vida aparece %d veces", total)) end
    A = r2[1]; ajeno = readBytes(A, 5, true); writeBytes(A, VIDA_ORI)
  end
  local dirA = string.format("game3.exe+%X", A - b3)
  local src = string.format([[
alloc(gv3reg_mem,$400,%s)
label(gv3reg_ret)
label(gv3_ring)
label(gv3_idx)
registersymbol(gv3_ring)
registersymbol(gv3_idx)
gv3reg_mem:
  movss [rcx+08],xmm0
  push rax
  push rbx
  mov eax,[gv3_idx]
  and eax,3F
  lea rbx,[gv3_ring]
  mov [rbx+rax*8],rcx
  inc dword ptr [gv3_idx]
  pop rbx
  pop rax
  jmp gv3reg_ret
align 10
gv3_idx:
  dd 0 0 0 0
gv3_ring:
  dq 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  dq 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
%s:
  jmp gv3reg_mem
gv3reg_ret:
]], dirA, dirA)
  if not autoAssemble(src) then
    if ajeno then writeBytes(A, ajeno) end
    error("autoAssemble falló al instalar el gancho")
  end
  puesto = true
end)
if not okG then showMessage("No se pudo instalar el gancho de registro: " .. tostring(errG)); return end

local idxPrev = 0
local function buscarJugadorEnGancho()
  local idx = readInteger(getAddress("gv3_idx")) or 0
  local ring = getAddress("gv3_ring")
  for k = math.max(idxPrev, idx - 64), idx - 1 do
    local rcx = readQword(ring + 8 * (k & 0x3F))
    if valido(rcx) and readInteger(rcx + 0x20) == 1 then idxPrev = idx; return rcx end
  end
  idxPrev = idx
  return nil
end

-- ---------------------------------------------------------------- 2) regiones a seguir
local C, regiones = nil, {}
local function prepararRegiones()
  regiones[#regiones + 1] = { n = "componente C", base = C - 0x400, rel = -0x400, largo = 0x1000 }
  local hs, total = escanear(vtQword, string.format("%X", C), 0x10000, 0x7FFFFFFFFFFF, "+W", fsmAligned, 20, true)
  p("Dueños de C (QWORD que apuntan a C): %d", total)
  for _, h in ipairs(hs) do
    local enMod = h >= b3 and h < b3 + size
    p("  %X%s  · [+0x510 desde el QWORD] int %s / float %s", h, enMod and string.format(" (game3.exe+%X)", h - b3) or "",
      tostring(readInteger(h + 0x510)), tostring(readFloat(h + 0x510)))
  end
  local n = 0
  for _, h in ipairs(hs) do
    if n < 3 and not (h >= b3 and h < b3 + size) then
      n = n + 1
      regiones[#regiones + 1] = { n = string.format("dueño %d (%X)", n, h), base = h - 0x800, rel = -0x800, largo = 0x1000 }
    end
  end
  local V = visual()
  regiones[#regiones + 1] = { n = string.format("objeto visual (%X)", V), base = V, rel = 0, largo = 0x1000 }
  for _, r in ipairs(regiones) do r.val, r.reposo, r.ultimoDif, r.primerDif, r.puntos, r.ej = {}, {}, {}, {}, {}, {} end
end

-- ---------------------------------------------------------------- 3) seguimiento en línea
local nLect, enGolpe, inicio, seguidos, golpes, durs = 0, false, 0, 0, 0, {}
local function leerRegiones()
  for _, r in ipairs(regiones) do
    local b = readBytes(r.base, r.largo, true)
    if b then
      for i = 0, r.largo // 4 - 1 do
        local v = u32(b, 4 * i)
        r.val[i] = v
        if enGolpe and r.reposo[i] ~= nil and v ~= r.reposo[i] then
          r.ultimoDif[i] = nLect
          if not r.primerDif[i] then r.primerDif[i] = nLect end
        end
      end
    end
  end
end
local function empezarGolpe()
  enGolpe, inicio, seguidos = true, nLect, 0
  for _, r in ipairs(regiones) do
    for i, v in pairs(r.val) do r.reposo[i] = v; r.ultimoDif[i] = nil; r.primerDif[i] = nil end
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
        if not r.ej[i] then r.ej[i] = string.format("%s → … → %s", fmt(rep), fmt(r.val[i])) end
      end
    end
  end
end

local function analizar()
  quitarGancho()
  p("\nGolpes medidos: %d · parpadeo (ms): %s", golpes, table.concat(durs, ", "))
  for _, r in ipairs(regiones) do
    local c = {}
    for i, pt in pairs(r.puntos) do c[#c + 1] = { o = 4 * i + r.rel, s = pt, e = r.ej[i] } end
    table.sort(c, function(x, y) if x.s ~= y.s then return x.s > y.s end return x.o < y.o end)
    p("\n== %s: cambian al recibir el golpe y vuelven al terminar el parpadeo ==", r.n)
    for i = 1, math.min(#c, 15) do
      p("  %s0x%03X  %d/%d golpes  %s", c[i].o < 0 and "−" or "+", math.abs(c[i].o), c[i].s, golpes, c[i].e)
    end
    if #c == 0 then p("  (ninguno)") end
  end
  local rep = table.concat(out, "\n")
  local fh = io.open(OUTFILE, "w"); if fh then fh:write(rep); fh:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
end

p("== Sonda de invencibilidad GV3 v5 — %s ==", os.date("%Y-%m-%d %H:%M"))
p("gancho de registro en game3.exe+%X%s", A - b3, ajeno and " (sobre el parche de otro script; se restaura)" or "")
showMessage("Gancho instalado. Al cerrar este aviso: recibe UN golpe para capturar (pitido).\n" ..
  "Luego empiezan 30 s: recibe 3–4 golpes SEPARADOS ≥ 5 s y NO ataques.")
local t0, parpPrev, estable = getTickCount(), 1, FIN_PARP
local t = createTimer(nil, false)
t.Interval = MS
t.OnTimer = function(tm)
  local ok, e = pcall(function()
    if not C then
      C = buscarJugadorEnGancho()
      if C then
        p("componente C = %X  HP %s / %s · objeto visual %X (C %+X)", C, tostring(readFloat(C + 8)),
          tostring(readFloat(C + 0xC)), visual(), C - visual())
        prepararRegiones()
        beep()
      elseif getTickCount() - t0 > ESPERA then
        error("no se capturó al jugador en 90 s (¿no recibiste daño?)")
      end
      return
    end
    nLect = nLect + 1
    local V = visual()
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
    if not okA then quitarGancho(); showMessage("ERROR al analizar: " .. tostring(errA)) end
  end
end
t.Enabled = true
