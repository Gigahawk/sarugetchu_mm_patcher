from bitstring import Bits

import sarugetchu_mm_patcher.util as util

class AsepriteDumper:
    MAGIC_NUMBER = 0xA5E0
    FRAME_MAGIC_NUMBER = 0xF1FA

    def __init__(
        self, width: int, height: int,
        palette_pxs: list[Bits], img_pxs: list[Bits]
    ):
        self.width = width
        self.height = height
        self.colors = self.unpack_palette_colors(palette_pxs)
        self.pixels = self.unpack_img_idxs(img_pxs)

    def unpack_palette_colors(
        self, palette_pxs: list[Bits]
    ) -> list[tuple[int, int, int, int]]:
        colors = []
        for color in palette_pxs:
            r, g, b, a = util.unpack_pixel(color)
            # PS2 alpha channel only goes to 0x80
            a *= 2
            if a > 255:
                a = 255
            colors.append((r, g, b, a))
        return colors

    def unpack_img_idxs(
        self, image_pxs: list[Bits]
    ) -> list[int]:
        return [px.uint for px in image_pxs]

    @property
    def palette_entries(self) -> bytes:
        out = b""
        for r, g, b, a in self.colors:
            # Flags, set to zero
            out += (0).to_bytes(2, "little")

            out += (r).to_bytes(1, "little")
            out += (g).to_bytes(1, "little")
            out += (b).to_bytes(1, "little")
            out += (a).to_bytes(1, "little")
        return out

    @property
    def image_entries(self) -> bytes:
        out = b""
        for idx in self.pixels:
            out += (idx).to_bytes(1, "little")
        return out

    @property
    def file(self) -> bytes:
        out = b""
        out += self.header
        out += self.frame
        out = self._set_data_size(out)
        return out

    @property
    def transparent_color_idx(self) -> int:
        trans_idx = 0
        min_alpha = 255
        for idx, (_, _, _, a) in enumerate(self.colors):
            if a < min_alpha:
                min_alpha = a
                trans_idx = idx
        return trans_idx

    @property
    def num_colors(self) -> int:
        return len(self.colors)

    @property
    def header(self) -> bytes:
        out = b""

        # File size
        out += (0).to_bytes(4, "little")
        out += (self.MAGIC_NUMBER).to_bytes(2, "little")
        # Number of frames, only one 1 supported for now
        out += (1).to_bytes(2, "little")

        out += (self.width).to_bytes(2, "little")
        out += (self.height).to_bytes(2, "little")

        # Color depth, only 8bpp indexed supported for now
        out += (8).to_bytes(2, "little")

        # Flags, set 1st bit to indicate a valid layer opacity?
        out += (0b1).to_bytes(4, "little")

        # Speed, pretty sure this is unused but necessary?
        out += (100).to_bytes(2, "little")

        # Reserved, always zero
        out += (0).to_bytes(8, "little")

        out += (self.transparent_color_idx).to_bytes(1, "little")

        # Reserved, set to zero
        out += (0).to_bytes(3, "little")

        out += (self.num_colors).to_bytes(2, "little")

        # Pixel width/height, why would this not always be 1?
        out += (1).to_bytes(1, "little")
        out += (1).to_bytes(1, "little")

        # Grid params, no idea what this means, aren't pixels already in a grid?
        # Grid X/Y
        out += (0).to_bytes(2, "little")
        out += (0).to_bytes(2, "little")
        # Grid width/height
        out += (16).to_bytes(2, "little")
        out += (16).to_bytes(2, "little")

        # Reserved, set to zero
        out += (0).to_bytes(84, "little")

        return out

    @property
    def frame(self) -> bytes:
        # For now there should always be 4 chunks in a frame
        _num_chunks = 4
        out = b""

        # Frame size, calculate later
        out += (0).to_bytes(4, "little")
        out += (self.FRAME_MAGIC_NUMBER).to_bytes(2, "little")

        # Old chunk count, probably not used but doesn't hurt to set
        out += (_num_chunks).to_bytes(2, "little")

        # Frame duration, we don't care about this so set to default of 100
        out += (100).to_bytes(2, "little")

        # Reserved, set to zero
        out += (0).to_bytes(2, "little")

        # Chunk count
        out += (_num_chunks).to_bytes(4, "little")

        out += self.chunks

        out = self._set_data_size(out)

        return out

    @property
    def chunks(self) -> bytes:
        out = b""
        out += self.color_profile_chunk
        out += self.palette_chunk
        out += self.layer_chunk
        out += self.cel_chunk
        return out

    @property
    def color_profile_chunk(self) -> bytes:
        _chunk_id = 0x2007
        out = b""

        # Chunk size, calculate this at the end
        out += (0).to_bytes(4, "little")
        out += (_chunk_id).to_bytes(2, "little")

        # Color Profile Type, always sRGB = 1
        out += (1).to_bytes(2, "little")

        # Flags, nothing needs to be set
        out += (0).to_bytes(2, "little")

        # Fixed point gamma, but we can just set this to zero
        out += (0).to_bytes(4, "little")

        # Reserved, set to zero
        out += (0).to_bytes(8, "little")

        out = self._set_data_size(out)

        return out


    @property
    def palette_chunk(self) -> bytes:
        _chunk_id = 0x2019
        out = b""

        # Chunk size, calculate this at the end
        out += (0).to_bytes(4, "little")
        out += (_chunk_id).to_bytes(2, "little")

        # Palette size
        out += (self.num_colors).to_bytes(4, "little")
        # Start idx
        out += (0).to_bytes(4, "little")
        # End idx
        out += (self.num_colors - 1).to_bytes(4, "little")

        # Reserved, set to zero
        out += (0).to_bytes(8, "little")

        out += self.palette_entries

        out = self._set_data_size(out)

        return out

    @property
    def layer_chunk(self) -> bytes:
        _chunk_id = 0x2004
        out = b""

        # Chunk size, calculate this at the end
        out += (0).to_bytes(4, "little")
        out += (_chunk_id).to_bytes(2, "little")

        # Flags, first 2 bits are visible and editable
        out += (0b11).to_bytes(2, "little")

        # Layer type, we always use normal (0)
        out += (0).to_bytes(2, "little")

        # Child level, something to do with layer hierarchy but we only have
        # one layer, set to zero
        out += (0).to_bytes(2, "little")

        # Default pixel width/height? no idea what this means, set to zero
        out += (0).to_bytes(2, "little")
        out += (0).to_bytes(2, "little")

        # Blend mode, we always use normal (0)
        out += (0).to_bytes(2, "little")

        # Opacity, set this to the max
        out += (255).to_bytes(1, "little")

        # Reserved, set to zero
        out += (0).to_bytes(3, "little")

        # Name
        out += self._get_length_encoded_str("Layer 1")

        out = self._set_data_size(out)
        return out

    @property
    def cel_chunk(self) -> bytes:
        _chunk_id = 0x2005
        out = b""

        # Chunk size, calculate this at the end
        out += (0).to_bytes(4, "little")
        out += (_chunk_id).to_bytes(2, "little")

        # Layer index, we only have one so always zero
        out += (0).to_bytes(2, "little")

        # X/Y pos, idk what this is, set to zero for now
        out += (0).to_bytes(2, "little")
        out += (0).to_bytes(2, "little")

        # Opacity, set to max
        out += (255).to_bytes(1, "little")

        # Image type, for convenience always set to raw data (0)
        out += (0).to_bytes(2, "little")

        # Z index, idk what this means, set to zero
        out += (0).to_bytes(2, "little")

        # Reserved, set to zero
        out += (0).to_bytes(5, "little")

        # Raw image data
        # Width/Height
        out += (self.width).to_bytes(2, "little")
        out += (self.height).to_bytes(2, "little")
        out += self.image_entries

        out = self._set_data_size(out)
        return out

    def _set_data_size(self, chunk_bin: bytes) -> bytes:
        chunk_size = len(chunk_bin)
        chunk_bin = bytearray(chunk_bin)
        chunk_bin[0:4] = (chunk_size).to_bytes(4, "little")
        return bytes(chunk_bin)

    def _get_length_encoded_str(self, string: str) -> bytes:
        strlen = len(string)
        out = b""

        out += (strlen).to_bytes(2, "little")
        out += string.encode(encoding="utf-8")
        return out













