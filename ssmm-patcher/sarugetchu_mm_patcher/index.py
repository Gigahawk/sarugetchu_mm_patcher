from dataclasses import dataclass

class IndexEntry:
    name: bytes
    _address: bytes
    _size: bytes

    def __init__(
            self,
            name: bytes,
            address: int | bytes,
            size: int | bytes
        ):
        self.name = name
        self._address = self._val_to_byte(address)
        self._size = self._val_to_byte(size)

    @property
    def name_str(self) -> str:
        return self.name.hex()

    @property
    def address(self) -> int:
        return int.from_bytes(self._address, "little")

    @property
    def size(self) -> int:
        return int.from_bytes(self._size, "little")

    @staticmethod
    def _val_to_byte(val: int | bytes) -> bytes:
        if isinstance(val, bytes):
            return val
        return val.to_bytes(4, "little")

    @classmethod
    def from_bytes(cls, b: bytes):
        if len(b) != 12:
            raise ValueError(
                f"Incorrect entry length {len(b)}: {b}"
            )
        return cls(
            name=b[0:4],
            address=b[4:8],
            size=b[8:12],
        )

    @property
    def bin(self) -> bytes:
        return self.name + self._address + self._size

    def __repr__(self):
        return (
            f"IndexEntry(name={self.name_str}, "
            f"address={self.address}, "
            f"size={self.size})"
        )

def get_index_list(data: bytes) -> list[IndexEntry]:
    return [
        IndexEntry.from_bytes(data[idx:idx+12])
        for idx in range(0, len(data), 12)
    ]

def index_list_to_bin(index_list: list[IndexEntry]) -> bytes:
    return b''.join(i.bin for i in index_list)
