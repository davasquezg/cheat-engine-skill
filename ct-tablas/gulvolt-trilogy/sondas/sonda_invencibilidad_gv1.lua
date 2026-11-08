-- =====================================================================================
-- sonda_invencibilidad_gv1.lua — Busca el temporizador de invencibilidad de GV1 (game1.exe)
-- SIN depurador: muestrea el objeto del jugador cada 50 ms durante 10 s mientras recibes
-- golpes y busca campos que pasan de 0 a >0 justo tras perder HP y luego bajan a 0.
-- Requisito: sonda "Captura jugador" activa (símbolos gv1_player y gv1_hp).
-- Resultado: ventana + portapapeles + archivo en la carpeta dumps. No escribe memoria.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local OUTFILE = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\resultados_invencibilidad_gv1.txt]]
local SIZE, TICKS, MS = 0x800, 200, 50

local pp, ph = getAddressSafe("gv1_player"), getAddressSafe("gv1_hp")
if not pp or not ph then showMessage("Activa primero la sonda 'Captura jugador' y entra a un nivel."); return end
local P, H = readQword(pp), readQword(ph)
if not P or P == 0 or not H or H == 0 then
  showMessage("Aún no se capturó el jugador: muévete o recibe un golpe y vuelve a intentar."); return
end

local snaps, hps = {}, {}
showMessage("Al cerrar este aviso empiezan 10 s de muestreo.\nRecibe 1 o 2 golpes en ese tiempo.")

local function u32(b, o) return b[o+1] + b[o+2]*256 + b[o+3]*65536 + b[o+4]*16777216 end

local function analizar()
  local hits = {}
  for k = 2, #hps do if hps[k] < hps[k-1] then hits[#hits+1] = k end end
  local out = { string.format("Objeto jugador = %X  componente HP = %X  muestras = %d  golpes detectados = %d",
                               P, H, #snaps, #hits) }
  for k = 1, #hits do out[#out+1] = string.format("  golpe en t=%d ms: HP %d -> %d", (hits[k]-1)*MS, hps[hits[k]-1], hps[hits[k]]) end
  if #hits == 0 then out[#out+1] = "No se detectó pérdida de HP: repite recibiendo un golpe." end
  local cands = {}
  for o = 0, SIZE - 4, 4 do
    local score, ejemplo = 0, nil
    for _, k in ipairs(hits) do
      local antes = u32(snaps[k-1], o)
      local pico, kp = 0, nil
      for j = k, math.min(k + 3, #snaps) do local v = u32(snaps[j], o); if v > pico then pico, kp = v, j end end
      if antes == 0 and pico > 0 and pico < 100000 then
        local mono, vuelve = true, false
        local prev = pico
        for j = kp + 1, #snaps do
          local v = u32(snaps[j], o)
          if v > prev then mono = false; break end
          prev = v
          if v == 0 then vuelve = true; break end
        end
        if mono then
          score = score + (vuelve and 2 or 1)
          if not ejemplo then
            local s = {}
            for j = k - 1, math.min(k + 12, #snaps) do s[#s+1] = tostring(u32(snaps[j], o)) end
            ejemplo = table.concat(s, ",")
          end
        end
      end
    end
    if score > 0 then cands[#cands+1] = { o = o, s = score, e = ejemplo } end
  end
  table.sort(cands, function(a, b) return a.s > b.s end)
  out[#out+1] = "\nCandidatos a temporizador de invencibilidad (offset en el objeto del jugador):"
  for i = 1, math.min(#cands, 15) do
    out[#out+1] = string.format("  +%03X  puntaje %d  valores: %s", cands[i].o, cands[i].s, cands[i].e)
  end
  if #cands == 0 then out[#out+1] = "  (ninguno)" end
  local rep = table.concat(out, "\n")
  local f = io.open(OUTFILE, "w"); if f then f:write(rep); f:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles)")
end

local t = createTimer(nil, false)
t.Interval = MS
t.OnTimer = function(tm)
  local ok = pcall(function()
    snaps[#snaps+1] = readBytes(P, SIZE, true)
    hps[#hps+1] = readInteger(H)
  end)
  if not ok or #snaps >= TICKS then tm.destroy(); analizar() end
end
t.Enabled = true
