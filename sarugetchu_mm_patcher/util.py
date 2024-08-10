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
