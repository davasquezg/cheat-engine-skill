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
  function ms.firstScan(_,vt,_,val) ms.r={}
    if vt==vtByteArray then ms.r = AOBHITS[val] or {} return end
    local v=tonumber(val,16)
    for a,x in pairs(MEM) do if x==v then ms.r[#ms.r+1]=a end end table.sort(ms.r) end
  function ms.waitTillDone() end function ms.destroy() end
  return ms
end
function createFoundList(ms) local fl={Count=#ms.r, Address={}}
  for i,a in ipairs(ms.r) do fl.Address[i-1]=string.format("%X",a) end
  function fl.initialize() end function fl.deinitialize() end function fl.destroy() end return fl end
