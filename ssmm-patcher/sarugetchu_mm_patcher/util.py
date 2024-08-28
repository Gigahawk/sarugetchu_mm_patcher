from math import ceil
import hashlib

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