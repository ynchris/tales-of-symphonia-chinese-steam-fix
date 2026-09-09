"""Adapt the verified 3DM v2 font-dimension hook to this Steam build."""
import hashlib
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('destination', type=Path)
args = parser.parse_args()
source = args.source
destination = args.destination
data = bytearray(source.read_bytes())
assert hashlib.sha256(data).hexdigest() == '23ccfd1f9924d53b5ea6b297f171aad434a5d71c23caf75273a60c4ed7d5a1ca'
# PE RVA 0x29dc: add eax, 0xc8, immediately after push callback 0x100023c0.
# Old match+0xc8 points at LEA EBX,[EDX+EAX]. In the supported newer build,
# the same instruction is match+0xca, after FSTP [ESP+0x28].
assert data[0x1dd7:0x1de2] == bytes.fromhex('68c023001005c800000050')
data[0x1ddd] = 0xca
destination.write_bytes(data)
print(destination, hashlib.sha256(data).hexdigest())
