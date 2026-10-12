-- Mock mínimo de la API de Cheat Engine para probar ct_helpers.lua fuera de CE
MEM = {}
local MOD, MODBASE, MODSIZE = (MOCK_MODULE or "game.exe"), 0x140000000, 0x10000000
soExactValue, vtQword, vtByteArray, rtRounded, fsmAligned, fsmNotAligned = 0,1,2,3,4,5
function getAddressSafe(s) if type(s)=="number" then return s end if s==MOD then return MODBASE end
  local m,o = s:match('^"?([^"+]+)"?%+(%x+)$'); if m==MOD then return MODBASE+tonumber(o,16) end end
function getModuleSize() return MODSIZE end
function readQword(a) return MEM[a] end
function readInteger(a) return MEM[a] end
function createMemScan()
  local ms = {}
  function ms.firstScan(_,_,_,val) local v=tonumber(val,16); ms.r={}
    for a,x in pairs(MEM) do if x==v then ms.r[#ms.r+1]=a end end table.sort(ms.r) end
  function ms.waitTillDone() end function ms.destroy() end
  return ms
end
function createFoundList(ms) local fl={Count=#ms.r, Address={}}
  for i,a in ipairs(ms.r) do fl.Address[i-1]=string.format("%X",a) end
  function fl.initialize() end function fl.deinitialize() end function fl.destroy() end return fl end
-- Construir cadena: [[[game.exe+E200000]+238]+70]+70 -> Zenny
local S, B, A1, A2 = MODBASE+0xE200000, 0x20000000, 0x30000000, 0x40000000
MEM[S]=B; MEM[B+0x238]=A1; MEM[A1+0x70]=A2; MEM[A2+0x70]=123456
-- Señuelos: otro puntero a A2 fuera de módulo, y una base estática errónea a otra cosa
MEM[0x50000008]=A2; MEM[MODBASE+0x100]=0x60000000
dofile("lua/ct_helpers.lua")
local z = ctFollow("game.exe+E200000", {0x238,0x70,0x70})
print(string.format("ctFollow -> %X (esperado %X)", z, A2+0x70))
local r = ctFindStatic(A2+0x70, {0x238,0x70,0x70}, MOD)
assert(#r==1 and r[1]==0xE200000, "ctFindStatic falló")
print("TEST OK")
