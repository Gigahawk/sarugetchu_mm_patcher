from collections.abc import Buffer
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

class TrackedByteArray(bytearray):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._changes: list[tuple[int, int, int]]= []

    def __setitem__(self, key, value):
        if isinstance(key, slice):
            # TODO: what happens on negatives?
            old_len = key.stop - key.start
            new_len = len(value)
            if old_len != new_len:
                self._changes.append((
                    key.start,
                    old_len,
                    new_len,
                ))
        super().__setitem__(key, value)

    def find_all(
        self,
        sub: Buffer,
        start: int=0,
        end: int | None = None
    ) -> list[int]:
        out = []
        if end is None:
            end = len(self)
        while True:
            idx = self.find(sub, start, end)
            if idx == -1:
                break
            out.append(idx)
            start = idx + len(sub)
            if start >= end:
                break
        return out

    def replace_in_place(self, old: Buffer, new: Buffer, count: int=-1):
        if not old:
            raise ValueError(f"Cannot match nil substring {old}")
        idx = 0
        new_len = len(new)
        old_len = len(old)
        len_diff = new_len - old_len
        idxs = self.find_all(old)
        curr_count = 0
        for idx in idxs:
            if count == 0:
                break
            idx += curr_count*len_diff
            if self[idx:idx + old_len] == old:
                self[idx:idx + old_len] = new
                idx += new_len
                curr_count += 1
                count -= 1
            else:
                idx += 1

    def get_new_index(self, orig_idx: int) -> int:
        for oidx, olen, nlen in self._changes:
            if orig_idx <= oidx:
                # TODO: is this correct? this should probably be a continue
                return orig_idx
            if nlen > olen and orig_idx < oidx + olen:
                return orig_idx
            len_diff = nlen - olen
            new_idx = orig_idx + len_diff
            if len_diff < 0 and orig_idx <= oidx - len_diff:
                raise ValueError(
                    f"Original idx {hex(orig_idx)} refers to "
                    f"deleted space near {hex(new_idx)}"
                )
            orig_idx = new_idx
        return orig_idx

def patch_file_offsets(
    file: TrackedByteArray,
) -> bytearray:
    targets = [
        b"menu_common/icon.bimg",
        b"work/sound_data/midi/SGMM_02.bdm",
        b"work/sound_data/midi/SGMM_02.hd",
        b"work/sound_data/midi/SGMM_02.mid",
        b"work/sound_data/sadpcm/BGM/SGMM_01_gradius.sts",
        b"work/sound_data/sadpcm/BGM/SGMM_21.sts",
        b"work/sound_data/sadpcm/BGM/SGMM_26.sts",
        b"work/sound_data/sadpcm/BGM/SGMM_27.sts",
        b"work/sound_data/sadpcm/BGM/SGMM_28.sts",
        b"work/sound_data/sadpcm/BGM/SGMM_31.sts",
        b"work/sound_data/sadpcm/BGM/SGMM_37.sts",
        b"work/sound_data/sadpcm/JINGLE/Congratulations.sts",
        b"work/sound_data/sadpcm/JINGLE/Congratulations_Victory.sts",
        b"work/sound_data/sadpcm/JINGLE/Miss_kakeru.sts",
        b"work/sound_data/sadpcm/JINGLE/Winner_taisenmode.sts",
        b"work/sound_data/sadpcm/JINGLE/You_Lose.sts",
        b"work/sound_data/se/PC_kakeru.hd",
        b"work/sound_data/se/PC_kakeru.sed",
        b"work/sound_data/se/ST01.hd",
        b"work/sound_data/se/ST01.sed",
        b"work/sound_data/se/ST02.hd",
        b"work/sound_data/se/ST02.sed",
        b"work/sound_data/se/ST012.hd",
        b"work/sound_data/se/ST012.sed",
        b"work/sound_data/se/ST022.hd",
        b"work/sound_data/se/ST022.sed",
        b"work/sound_data/se/ST50.hd",
        b"work/sound_data/se/ST50.sed",
        b"work/sound_data/se/ST53.hd",
        b"work/sound_data/se/ST53.sed",
        b"work/sound_data/se/vehicle.hd",
        b"work/sound_data/se/vehicle.sed",
        b"work/sound_data/se/mecha.hd",
        b"work/sound_data/se/mecha.sed",
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
        new_offset = file.get_new_index(offset)
        print(
            f"Patching file offset for {target} from "
            f"{hex(offset)} to {hex(new_offset)}"
        )
        file[offset_start_idx:offset_start_idx + 4] = new_offset.to_bytes(
            length=4, byteorder="little"
        )
    return file

def patch_img_struct_offsets(
    file: bytearray,
    orig_offsets: dict[int, int],
) -> bytearray:
    names = [
        b"boss_smoke"
    ]
    for name in entity_names:
        found = find_strings(file, name)
        for entry in found:
            for offset in [0x5, 0x15]:
                addr_offset: int = entry["end"] + offset
                addr = int.from_bytes(
                    file[addr_offset:addr_offset + 4],
                    byteorder="little"
                )
                try:
                    orig_offset = orig_offsets[addr]
                except:
                    continue
                new_addr = addr + (addr_offset - orig_offset)
                diff = new_addr - addr
                print(
                    f"Patching {entry['value']} address from "
                    f"{hex(addr)} to {hex(new_addr)} "
                    f"(diff {hex(diff)})"
                )
                file[addr_offset:addr_offset + 4] = new_addr.to_bytes(
                    4, "little"
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


class ImgExtractor:
    def __init__(self, data: bytes, fname: str):
        self.data = data
        string_data = find_strings(self.data, fname)[0]
        img_struct_addr_idx = string_data["start"] - 0xC
        self.img_struct_addr = int.from_bytes(
            self.data[img_struct_addr_idx:img_struct_addr_idx + 4],
            byteorder="little"
        )
        self.img_struct = parse_img_struct(self.data, self.img_struct_addr)
        self.px_data_struct = parse_pixel_data_struct(
            self.data, self.img_struct["px_data_struct_addr"]
        )
        self.plt_data_struct = parse_pixel_data_struct(
            self.data, self.img_struct["plt_data_struct_addr"]
        )

    @property
    def num_imgs(self) -> int:
        return self.px_data_struct["num_imgs"]

    def _px_start(self, idx: int) -> int:
        # TODO: only support 4bpp for now
        px_start = (
            self.px_data_struct["data_addr"]
            + (
                idx
                *self.px_data_struct["width"]
                *self.px_data_struct["height"]
                /2
            )
            # Random garbage at the end???
            + idx*8
        )
        if int(px_start) != px_start:
            raise ValueError(f"Got px_start {px_start}")
        px_start = int(px_start)
        return px_start

    def get_image(self, idx: int) -> Image:
        if idx >= self.num_imgs:
            raise ValueError(
                f"Only {self.num_imgs} available, {idx} is not a valid index"
            )
        px_start = self._px_start(idx)
        img = dump_image(
            self.data,
            px_start,
            self.plt_data_struct["data_addr"],
            self.px_data_struct["width"],
            self.px_data_struct["height"],
        )
        return img

    def get_pixel_bytes(self, idx: int) -> bytes:
        if idx >= self.num_imgs:
            raise ValueError(
                f"Only {self.num_imgs} available, {idx} is not a valid index"
            )
        px_start = self._px_start(idx)
        px_end = int(
            px_start
            + (
                self.px_data_struct["width"]
                *self.px_data_struct["height"]
                /2
            )
        )
        return self.data[px_start:px_end]

    def shrink_pixel_bytes(self, data: bytes, ratio: float) -> bytes:
        width = self.px_data_struct["width"]
        height = self.px_data_struct["height"]
        pixels = []
        for y in range(height):
            for x in range(width):
                row_idx = int(x*ratio)
                if row_idx >= width:
                    pixels.append(0)
                    continue
                src_px_idx = y*width + row_idx
                # TODO: not all images are 4bpp, need to figure out how
                # this is controlled
                src_byte_idx = src_px_idx // 2
                src_px_bits = data[src_byte_idx]
                if src_px_idx % 2:
                    src_px_bits = src_px_bits >> 4
                else:
                    src_px_bits = src_px_bits & 0xF
                pixels.append(src_px_bits)
        # Ensure pixel list length is even
        if len(pixels) % 2:
            pixels.append(0)
        new_bytes = []
        for i in range(0, len(pixels), 2):
            new_bytes.append(
                pixels[i + 1] << 4 | pixels[i]
            )
        return bytes(new_bytes)

    def overwrite_pixel_bytes(self, idx: int, pxl_data: bytes):
        px_start = self._px_start(idx)
        # Allow writing to data
        if not isinstance(self.data, bytearray):
            self.data = bytearray(self.data)
        self.data[px_start:px_start + len(pxl_data)] = pxl_data


