-- Prueba del bloque Lua del Resolver con API de CE simulada
MOCK_MODULE = "MEGAMAN_STARFORCE_Legacy_Collection.exe"
dofile("tests/mock_ce_base.lua")

SYMS = {}
function registerSymbol(n,a) SYMS[n]=a end
function unregisterSymbol(n) SYMS[n]=nil end
syntaxcheck=false
local MB=0x140000000
-- Caso 1: AOB encuentra instrucción en RVA 0x500000 con disp NEGATIVO (como uint32)
-- destino = 0x500000+7+disp = 0x0E000000 -> disp = 0x0DB00000-7  (positivo); probamos negativo:
-- instrucción en RVA 0x0F000000, destino 0x0E120A40 -> disp = 0x0E120A40-0x0F000007 (<0)
local ins = MB+0x0F000000
local disp = 0x0E120A40 - (0x0F000000+7)
MEM[ins+3] = disp & 0xFFFFFFFF
AOBHITS = { ["48 8B 05 ?? ?? ?? ?? 48 85 C0"] = { ins } }
MEM[MB+0x0E120A40] = 0x22220000   -- puntero legible
MEM[MB+0x0E124218] = 0x33330000
local blk = io.open("/tmp/claude-0/blk_test.lua"):read("a")
load(blk)()
assert(SYMS.sf12_base == MB+0x0E120A40, "AOB/RIP mal resuelto")
assert(SYMS.sf3_base == MB+0x0E124218, "respaldo mal aplicado")
print("TEST RESOLVER OK")
