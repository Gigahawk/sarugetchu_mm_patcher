import string
from typing import Any
from math import ceil
import hashlib
from pprint import PrettyPrinter

from PIL import Image

class HexPrettyPrinter(PrettyPrinter):
    def format(self, obj, context, maxlevels, level):
        if isinstance(obj, int):
            return f"0x{obj:X}", True, False
        return super().format(obj, context, maxlevels, level)

def md5(fname) -> str:
    hash_md5 = hashlib.md5()
    with open(fname, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def blocks_required(data: bytes | int, block_size: int=2048) -> int:
    """Calculate the blocks required to store data"""
    if isinstance(data, (bytes, bytearray)):
        size = len(data)
    if isinstance(data, int):
        size = data
    return ceil(size/block_size)

def pad(data: bytes, block_size: int=2048) -> bytes:
    num_blocks = blocks_required(data, block_size=block_size)
    total_size = num_blocks*block_size
    pad_len = total_size - len(data)
    data += bytes(pad_len)
    return data

def patch_offsets(
        file: bytearray,
        size_diff: int,
    ) -> bytearray:
    targets = [
        b"menu_common/icon.bimg",
        b"work/sound_data/midi/SGMM_02.bdm",
        b"work/sound_data/midi/SGMM_02.hd",
        b"work/sound_data/midi/SGMM_02.mid",
        b"work/sound_data/sadpcm/BGM/SGMM_01_gradius.sts"
        b"work/sound_data/sadpcm/BGM/SGMM_21.sts"
        b"work/sound_data/sadpcm/BGM/SGMM_26.sts"
        b"work/sound_data/sadpcm/BGM/SGMM_27.sts"
        b"work/sound_data/sadpcm/BGM/SGMM_28.sts"
    ]
    for target in targets:
        try:
            target_start_idx = file.index(target)
        except:
            continue
        offset_start_idx = target_start_idx - 8
        offset = int.from_bytes(
            file[offset_start_idx:offset_start_idx + 4],
            byteorder="little"
        )
        new_offset = offset + size_diff
        file[offset_start_idx:offset_start_idx + 4] = new_offset.to_bytes(
            length=4, byteorder="little"
        )
    return file

def gen_packinfo_hash(pack_path: str) -> bytes:
    crc = 0
    for c in pack_path:
        crc = (crc * 0x25) + ord(c)
        crc &= 0xFFFFFFFF
    crc = crc.to_bytes(length=4, byteorder="little")
    return crc

def find_strings(
        data: bytes,
        target: str | bytes,
        allowed: str | bytes=string.printable.encode("utf-8")
) -> list[dict[str,Any]]:
    if isinstance(target, str):
        target = target.encode()
    found = []
    start = 0
    while (idx := data.find(target, start)) != -1:
        start = idx + 1
        string_end = data.find(b"\x00", idx)
        if string_end == -1:
            raise ValueError(
                f"End of string not found from offset {hex(idx)}"
            )
        # Seek backwards in data and look for first (non allowed byte)
        _mark = idx
        while data[_mark] in allowed:
            _mark -= 1
        string_start = _mark + 1
        _mark -= 3
        strlen = int.from_bytes(data[_mark:_mark+4], byteorder="little")
        if strlen != string_end - string_start:
            # String length doesn't match, not a valid string
            continue
        found.append({
            "start": string_start,
            "end": string_end,
            "len": strlen,
            "value": data[string_start:string_end]
        })
    return found

def parse_img_struct(data: bytes, start: int):
    img_struct = {}
    _ptr = start
    img_struct_type_strlen = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    _ptr += 4
    img_struct["type"] = data[_ptr:_ptr + img_struct_type_strlen]
    # skip over null termination
    _ptr += img_struct_type_strlen + 1
    # TODO: no idea what this is, seems to always be 2?
    img_struct["idk1"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    _ptr += 4
    img_struct["px_data_struct_addr"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    _ptr += 4
    img_struct["px_data_width"] = int.from_bytes(
        data[_ptr:_ptr + 2],
        byteorder="little"
    )
    _ptr += 2
    img_struct["px_data_height"] = int.from_bytes(
        data[_ptr:_ptr + 2],
        byteorder="little"
    )
    _ptr += 2
    # TODO: no idea what these are
    img_struct["idk2"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    _ptr += 4
    img_struct["idk3"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    _ptr += 4
    img_struct["plt_data_struct_addr"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    _ptr += 4
    img_struct["plt_data_width"] = int.from_bytes(
        data[_ptr:_ptr + 2],
        byteorder="little"
    )
    _ptr += 2
    img_struct["plt_data_height"] = int.from_bytes(
        data[_ptr:_ptr + 2],
        byteorder="little"
    )
    _ptr += 2
    img_struct["idk4"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    _ptr += 4
    img_struct["idk5"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    #_ptr += 4
    return img_struct

def parse_pixel_data_struct(data: bytes, start: int):
    px_data_struct = {}
    _ptr = start
    px_data_struct["idk1"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    _ptr += 4
    px_data_struct["idk2"] = int.from_bytes(
        data[_ptr:_ptr + 2],
        byteorder="little"
    )
    _ptr += 2
    px_data_struct["width"] = int.from_bytes(
        data[_ptr:_ptr + 2],
        byteorder="little"
    )
    _ptr += 2
    px_data_struct["height"] = int.from_bytes(
        data[_ptr:_ptr + 2],
        byteorder="little"
    )
    _ptr += 2
    px_data_struct["num_imgs"] = int.from_bytes(
        data[_ptr:_ptr + 3],
        byteorder="little"
    )
    _ptr += 3
    px_data_struct["data_addr"] = int.from_bytes(
        data[_ptr:_ptr + 4],
        byteorder="little"
    )
    #_ptr += 4
    return px_data_struct

def dump_image(
    data: bytes,
    px_start: int,
    plt_start: int,
    width: int,
    height: int
) -> Image:
    img = Image.new("RGBA", (width, height))
    for y in range(height):
        for x in range(width):
            px_idx = y*width + x

            # TODO: not all images are 4bpp, need to figure out how
            # this is controlled
            byte_idx = px_idx // 2
            px_bits = data[px_start + byte_idx]
            if px_idx % 2:
                px_bits = px_bits >> 4
            else:
                px_bits = px_bits & 0xF

            r, g, b, a = data[plt_start + px_bits*4:plt_start + px_bits*4 + 4]
            a *= 2
            if a > 255:
                a = 255
            img.putpixel((x, y), (r, g, b, a))
    return img
