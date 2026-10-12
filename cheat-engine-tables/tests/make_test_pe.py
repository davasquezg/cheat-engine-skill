#!/usr/bin/env python3
# Genera un PE64 mínimo sintético para probar sigmaker.py (sin compilador).
import struct, sys
IMAGE_BASE = 0x140000000
TEXT_RVA, DATA_RVA, ALIGN = 0x1000, 0x2000, 0x200
TARGET = DATA_RVA + 0x40           # "puntero estático" a encontrar

code = bytearray(b"\xCC" * 0x40)
def ripmov(opbytes, target):        # instrucción con disp32 RIP-relativo al final
    rva = TEXT_RVA + len(code)
    end = rva + len(opbytes) + 4
    code.extend(opbytes + struct.pack("<i", target - end))
def emit(b): code.extend(b)
# Ruido: el mismo patrón de inicio pero hacia OTRA dirección (fuerza a extender la firma)
ripmov(b"\x48\x8B\x05", DATA_RVA + 0x80); emit(b"\x48\x85\xC0\x74\x05\xC3")
emit(b"\x90" * 8)
# Referencia 1: mov rax,[rip+X]; test rax,rax; je +5; call rel32; ret
ripmov(b"\x48\x8B\x05", TARGET); emit(b"\x48\x85\xC0\x74\x05\xE8\x10\x00\x00\x00\x8B\x48\x18\xC3")
emit(b"\xCC" * 16)
# Referencia 2: lea rcx,[rip+X]; mov edx,0x238; call rel32
ripmov(b"\x48\x8D\x0D", TARGET); emit(b"\xBA\x38\x02\x00\x00\xE8\x00\x01\x00\x00\xC3")
emit(b"\xCC" * 32)
# Referencia 3: cmp qword ptr [rip+X],0 (inmediato de 1 byte tras el disp)
rva = TEXT_RVA + len(code); end = rva + 8
emit(b"\x48\x83\x3D" + struct.pack("<i", TARGET - end) + b"\x00\x0F\x84\x20\x00\x00\x00")
code.extend(b"\xCC" * (ALIGN - len(code) % ALIGN))
data = bytearray(ALIGN)

def sect(name, vsize, rva, rawsize, rawptr, ch):
    return struct.pack("<8sIIIIIIHHI", name, vsize, rva, rawsize, rawptr, 0, 0, 0, 0, ch)
hdr = bytearray(ALIGN)
struct.pack_into("<2s58xI", hdr, 0, b"MZ", 0x80)
off = 0x80
struct.pack_into("<4sHHIIIHH", hdr, off, b"PE\0\0", 0x8664, 2, 0, 0, 0, 240, 0x22)
opt = off + 24
struct.pack_into("<HBBIIIII", hdr, opt, 0x20B, 14, 0, len(code), len(data), 0, TEXT_RVA, TEXT_RVA)
struct.pack_into("<QIIHHHHHHIIIIHHQQQQII", hdr, opt + 24, IMAGE_BASE, 0x1000, ALIGN, 6, 0, 0, 0, 6, 0, 0,
                 0x3000, ALIGN, 0, 3, 0x8160, 0x100000, 0x1000, 0x100000, 0x1000, 0, 16)
st = opt + 240
hdr[st:st+40] = sect(b".text", len(code), TEXT_RVA, len(code), ALIGN, 0x60000020)
hdr[st+40:st+80] = sect(b".data", len(data), DATA_RVA, len(data), ALIGN + len(code), 0xC0000040)
open(sys.argv[1], "wb").write(hdr + code + data)
print(f"PE de prueba escrito: {sys.argv[1]}  (TARGET RVA = 0x{TARGET:X})")
