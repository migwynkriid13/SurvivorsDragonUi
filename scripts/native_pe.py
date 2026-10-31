"""Shared PE32+ byte reads for authoring tools; never load or execute a client.

Callers verify their own executable fingerprint before constructing this view.
Build-specific offsets, instruction checks and catalog selection stay with them.
"""

import struct


class PeImage:
    def __init__(self, raw):
        self.raw = raw
        pe = self.number(0x3C, "I")
        optional = pe + 24
        if raw[:2] != b"MZ" or raw[pe:pe + 4] != b"PE\0\0" or self.number(optional, "H") != 0x20B:
            raise ValueError("Expected the pinned PE32+ executable")
        base = self.number(optional + 24)
        section_table = optional + self.number(pe + 20, "H")
        self.sections = []
        for index in range(self.number(pe + 6, "H")):
            at = section_table + index * 40
            rva = self.number(at + 12, "I")
            size = self.number(at + 16, "I")
            offset = self.number(at + 20, "I")
            self.sections.append((base + rva, offset, size))

    def number(self, at, kind="Q"):
        encoding = "<" + kind
        if at < 0 or at + struct.calcsize(encoding) > len(self.raw):
            raise ValueError("Native field extends beyond the PE file")
        return struct.unpack_from(encoding, self.raw, at)[0]

    def offset(self, address, length=1):
        if length < 0:
            raise ValueError("Native read length must be nonnegative")
        for base, offset, size in self.sections:
            if base <= address < base + size and length <= base + size - address:
                start = offset + address - base
                if start + length > len(self.raw):
                    raise ValueError("Native read extends beyond the PE file")
                return start
        raise ValueError("Native span is outside a file-backed PE section")

    def read(self, address, length):
        start = self.offset(address, length)
        return self.raw[start:start + length]
