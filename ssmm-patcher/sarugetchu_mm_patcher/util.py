from dataclasses import dataclass
from collections.abc import Buffer
import string
from typing import Any, Pattern
from math import ceil
import hashlib
from pprint import PrettyPrinter
from bitstring import Bits

from PIL import Image

import sarugetchu_mm_patcher.PS2Textures.PS2Textures as ps2tex

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

@dataclass(frozen=True)
class ImhexPtr:
    # Offset where this pointer is found
    file_offset: int
    # Address the pointer is pointing to
    target: int

class ImhexPtrFinder:
    def __init__(self, imhex_analysis: dict):
        self.data = imhex_analysis
        self.ptrs: list[ImhexPtr] = []
        self.parse()
        self.ptrs = list(set(self.ptrs))

    def parse(self, start=None):
        if start is None:
            start = self.data
        if isinstance(start, dict):
            if "__type" in start.keys():
                if start["__type"].endswith("Ptr") and "ptr" in start.keys():
                    self.ptrs.append(
                        ImhexPtr(
                            file_offset=int(start["__address"]),
                            target=start["nullptr"]
                        )
                    )
            for obj in start.values():
                self.parse(start=obj)
        elif isinstance(start, list):
            for obj in start:
                self.parse(start=obj)

def find_img_subfile(root: dict, pattern: Pattern[str]) -> dict:
    if isinstance(root, dict):
        if root.get("__type") == "ImgSubFile":
            name = root["fname"]["string"]
            #print(f"Found img subfile with name {name}")
            if pattern.search(name):
                return root
    else:
        return None
    for val in root.values():
        if isinstance(val, dict):
            if out := find_img_subfile(val, pattern):
                return out
        elif isinstance(val, list):
            for obj in val:
                if out := find_img_subfile(obj, pattern):
                    return out
    return None


def patch_file_offsets(
    file: TrackedByteArray,
    imhex_analysis: dict
) -> bytearray:

    ptrs = ImhexPtrFinder(imhex_analysis).ptrs

    for ptr in ptrs:
        file_offset_orig = ptr.file_offset
        file_offset_new = file.get_new_index(file_offset_orig)
        _file_offset_msg = (
            f"orig: {hex(file_offset_orig)}, "
            f"new: {hex(file_offset_new)}"
        )

        # Target address should not have changed yet, sanity check it matches
        # the original
        target_orig = int.from_bytes(
            file[file_offset_new:file_offset_new + 4],
            byteorder="little"
        )
        if target_orig != ptr.target:
            raise ValueError(
                f"Pointer at file offset {_file_offset_msg} "
                f"should be {hex(ptr.target)} but is actually {hex(target_orig)}"
            )
        new_target = file.get_new_index(target_orig)
        if new_target == target_orig:
            continue
        print(
            f"Patching pointer at file offset {_file_offset_msg}, "
            f"from {hex(target_orig)} to {hex(new_target)}"
        )
        file[file_offset_new:file_offset_new + 4] = new_target.to_bytes(
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

def palette_to_list(plt: Image) -> list[int]:
    out = []
    for y in range(plt.height):
        for x in range(plt.width):
            out += plt.getpixel((x, y))
    return out


def unswizzle_palette(pixels: list, block_size=8):
    if (len(pixels) % block_size) != 0:
        import pdb;pdb.set_trace()
        raise ValueError(
            f"Cannot unswizzle with block size {block_size}, "
            f"pixel list is of invalid length {len(pixels)}"
        )
    blocks = []
    num_blocks = len(pixels) // block_size
    idx = 0
    for blk_idx in range(num_blocks):
        blk = []
        for _ in range(block_size):
            blk.append(pixels[idx])
            idx += 1
        blocks.append(blk)
    if num_blocks > 2:
        for blk_idx in range(num_blocks):
            if (blk_idx - 1) % 4 == 0:
                blocks[blk_idx], blocks[blk_idx + 1] = (
                    blocks[blk_idx + 1], blocks[blk_idx]
                )
    out = []
    for blk in blocks:
        for px in blk:
            out.append(px)
    return out



def px_data_to_imgs(data: dict, unswizzle_plt: bool=False):
    _bpp_mode_to_bpp = {
        0: 32,
        3: 8,
        4: 4,
    }
    data = data["data"]["ptr"]["*(ptr)"]
    num_imgs = data["num_imgs"]
    width = data["width"]
    height = data["height"]
    pixels_per_img = width*height
    if "idk_data_ptr" in data:
        px_buf = bytes(data["idk_data_ptr"]["ptr"]["*(ptr)"])
    else:
        print("TODO: support in line images")
        import pdb;pdb.set_trace()
    bpp = _bpp_mode_to_bpp[data["psm_flags"]["bpp_mode"]]
    swizzled = data["psm_flags"]["swizzled"]
    if swizzled:
        if bpp == 4:
            rrw = width // 2
            rrh = height // 4
            gs_buf = ps2tex.writeTexPSMCT32(0, rrw // 64, 0, 0, rrw, rrh, px_buf)
            px_buf = ps2tex.readTexPSMT4(0, width // 64, 0, 0, width, height, gs_buf)
        if bpp == 8:
            rrw = width // 2
            rrh = height // 2
            gs_buf = ps2tex.writeTexPSMCT32(0, rrw // 64, 0, 0, rrw, rrh, px_buf)
            px_buf = ps2tex.readTexPSMT8(0, width // 64, 0, 0, width, height, gs_buf)

    px_buf_bits = Bits(bytes=px_buf)

    # Random garbage at the end of the image?
    bits_per_image = pixels_per_img*bpp + 8*8
    img_pxs = []
    img_bins = []
    for img_idx in range(num_imgs):
        pixels = []
        img_base = img_idx*bits_per_image
        for px_idx in range(pixels_per_img):
            base = img_base + px_idx*bpp
            pixels.append(px_buf_bits[base:base+bpp])

        # Need to unswizzle the pixels?
        if bpp == 4:
            pixels[::2], pixels[1::2] = pixels[1::2], pixels[::2]
        if unswizzle_plt and bpp == 32:
            pixels = unswizzle_palette(pixels)

        img_pxs.append(pixels)
        img_bin = sum(pixels, start=Bits(0)).tobytes()
        img_bins.append(img_bin)
    return img_pxs, img_bins

def img_buf_to_pillow(px_img, width, height, plt_img=None) -> Image:
    _unpack_fmt = ",".join(4*["uint:8"])
    img = Image.new("RGBA", (width, height))
    for idx, px in enumerate(px_img):
        x = idx % width
        y = idx // width
        if plt_img:
            try:
                plt_idx = px.uintle
            except ValueError:
                plt_idx = px.uint
            r, g, b, a = plt_img[plt_idx].unpack(_unpack_fmt)
        else:
            r, g, b, a = px.unpack(_unpack_fmt)
        # PS2 alpha channel only goes to 0x80
        a *= 2
        if a > 255:
            a = 255
        color = (r, g, b, a)
        img.putpixel((x, y), color)
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


