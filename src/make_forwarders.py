import argparse
import struct

import pefile


def align(value: int, alignment: int) -> int:
    return (value + alignment - 1) & ~(alignment - 1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Replace wrapper exports with native PE forwarders.")
    parser.add_argument("source")
    parser.add_argument("destination")
    args = parser.parse_args()

    data = bytearray(open(args.source, "rb").read())
    pe = pefile.PE(data=bytes(data))
    export_dir = pe.OPTIONAL_HEADER.DATA_DIRECTORY[0]
    export_section = pe.get_section_by_rva(export_dir.VirtualAddress)
    next_rva = align(export_dir.VirtualAddress + export_dir.Size, 16)
    section_end_rva = export_section.VirtualAddress + export_section.SizeOfRawData

    for symbol in pe.DIRECTORY_ENTRY_EXPORT.symbols:
        name = symbol.name.decode("ascii")
        forwarder = f"steam_api.{name}".encode("ascii") + b"\0"
        if next_rva + len(forwarder) > section_end_rva:
            raise RuntimeError("Not enough room in export section for forwarder strings")
        raw_offset = export_section.PointerToRawData + (next_rva - export_section.VirtualAddress)
        if any(data[raw_offset : raw_offset + len(forwarder)]):
            raise RuntimeError(f"Forwarder storage is not empty at RVA 0x{next_rva:X}")
        data[raw_offset : raw_offset + len(forwarder)] = forwarder
        struct.pack_into("<I", data, symbol.address_offset, next_rva)
        next_rva += len(forwarder)

    new_export_size = next_rva - export_dir.VirtualAddress
    struct.pack_into("<I", data, export_dir.get_field_absolute_offset("Size"), new_export_size)
    required_virtual_size = next_rva - export_section.VirtualAddress
    if required_virtual_size > export_section.Misc_VirtualSize:
        struct.pack_into("<I", data, export_section.get_file_offset() + 8, required_virtual_size)

    with open(args.destination, "wb") as output:
        output.write(data)


if __name__ == "__main__":
    main()
