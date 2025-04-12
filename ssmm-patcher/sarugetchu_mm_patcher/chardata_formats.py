from io import SEEK_SET, BytesIO
from enum import IntEnum

import construct as cs
from construct_editor.core.custom import (
    add_custom_adapter, AdapterObjEditorType,
)

from sarugetchu_mm_patcher.encoding import (
    EncodingTranslator, BYTES_TO_CHAR_DEFAULT
)

class _CharType(IntEnum):
    KAKERU = 0
    PROFESSOR = 1
    NATSUMI = 2
    CHARU = 3
    HARUKA = 4
    # Saru/Pipotron Team has multiple members, but save
    # files seem to always use the first value.
    # If you edit the save to be another value,
    # they show up as the default selected when loading
    # from VS mode
    SARU_TEAM_KI = 5
    SARU_TEAM_AKAI = 6
    SARU_TEAM_AOI = 7
    SARU_TEAM_KURO = 8
    SARU_TEAM_MIDORI = 9
    SARU_TEAM_MIZU = 10
    PIPOTRON_TEAM_RED = 11
    PIPOTRON_TEAM_BLUE = 12
    PIPOTRON_TEAM_YELLOW = 13
    HIROKI = 14
    SPECTER = 15
    DARK_HIROKI = 16
    DARK_SPECTER = 17
    PIPOTRON_G = 18
    LEGEND = 19
    VOLCANO = 20
    VIRUS_CHARU = 21
    # Character edit screen can load this and shows a T-posing monkey army
    # grunt with no eyes, attempting to access Modify Equipment crashes
    # the game
    INVALID1 = 22
    # Immediately causes game to crash when attempting to read
    INVALID2 = 23
    # Seems to be the default value for a blank file.
    # Setting an existing file to this value causes weird behavior, so it's
    # not the only thing determining whether a file has been created.
    #  - Crash when attempting to load character in char edit
    #  - Doesn't show up in VS. mode
    #  - "This character cannot be selected in story mode" if selected in story mode
    NO_CHAR = 24
    # Values beyond this seem to just cause crashes
CharType = cs.Enum(cs.Byte, _CharType)


class _ChipType(IntEnum):
    MAGNESIUM = 0
    GERMANIUM = 1
    COBALT = 2
    CADMIUM = 3
    ZIRCONIUM = 4
    NOBELLIUM = 5
    TELLURIUM = 6
    NIOBIUM = 7
    NEODYMIUM = 8
    ASTATINE = 9
    ERBIUM = 10
    XENON = 11
    BISMUTH = 12
    FERMIUM = 13
    PROMETHIUM = 14
    BERYLLIUM = 15
    HOLMIUM = 16
    RUTHENIUM = 17

    END_MARKER = 0xFF
ChipType = cs.Enum(cs.Byte, _ChipType)

class TextAdapter(cs.Adapter):
    # Save files always use the default encoding
    _translator = EncodingTranslator(encoding=BYTES_TO_CHAR_DEFAULT)

    def __init__(self, subcon: cs.Bytes, *args, **kwargs):
        super().__init__(subcon, *args, **kwargs)
        self.text_byte_len = subcon.length

    def _decode(self, obj, context, path):
        return self._translator.bytes_to_string(obj)
    def _encode(self, obj, context, path):
        bytes_ = self._translator.string_to_bytes(obj)[0]
        len_diff = self.text_byte_len - len(bytes_)
        if len_diff > 0:
            bytes_ += bytes(len_diff)
        else:
            # Truncate to max length
            bytes_ = bytes_[:self.text_byte_len]
        return bytes_

add_custom_adapter(
    type_str="EncodedString",
    obj_editor_type=AdapterObjEditorType.String,
    adapter=TextAdapter
)

Loadout = cs.Struct(
    "triangle_gadget_idx" / cs.Byte,
    "circle_gadget_idx" / cs.Byte,
    "cross_gadget_idx" / cs.Byte,
    "square_gadget_idx" / cs.Byte,
    "backpack_gadget_idx" / cs.Byte,
)

def _get_costume_name(ctx) -> str:
    # TODO: actually document all the names
    char_type = ctx.char_type.title()
    costume_idx = ctx.equipped_costume_idx
    return f"{char_type}_costume_{costume_idx}"

def _get_gadget_name(ctx) -> str:
    # TODO: actually document all gadgets
    char_type = ctx._.char_type.title()
    gadget_idx = ctx.item_type_idx
    return f"{char_type}_gadget_{gadget_idx}"

# TODO: figure out computed for this?
GadgetSlots = cs.Struct(
    "slot_alpha" / cs.Byte,
    "slot_beta" / cs.Byte,
    "slot.gamma" / cs.Byte,
)

Gadget = cs.Struct(
    "gadget_name" / TextAdapter(cs.Bytes(9*2)),
    "idk_data1" / cs.Bytes(2),
    # TODO: use switch
    "item_type_idx" / cs.Byte,
    "item_type_name" / cs.Computed(_get_gadget_name),
    "slots" / GadgetSlots,
    # Default items can't be deleted when inventory is full
    "default" / cs.Flag,
)

SummonUnlocked = cs.BitStruct(
    "MONTA" / cs.Flag,
    "HATTORI_MONZO" / cs.Flag,
    "TUTANCHIMP" / cs.Flag,
    "MONKEY_PINK" / cs.Flag,
    "SAMUI" / cs.Flag,
    "MONKI_SAN" / cs.Flag,
    "EDISON" / cs.Flag,
    "MONKEY_RED" / cs.Flag,
    "AFRO" / cs.Flag,
    "PUMPKIN" / cs.Flag,
    "SALUS_MONKEY" / cs.Flag,
    "MIYAMOTO" / cs.Flag,
    "WAKKIE" / cs.Flag,
    "PIERRE" / cs.Flag,
    "JUN" / cs.Flag,
    "SUZUKI" / cs.Flag,
    "RICKY" / cs.Flag,
    "TORO" / cs.Flag,
    "unknown" / cs.Padding(6),
)

SaruBookStatus = cs.BitStruct(
    "NEW_UNSEEN" / cs.Flag,
    "NEW_SEEN" / cs.Flag,
    "CAUGHT"/ cs.Flag,
    "unknown" / cs.Padding(5)
)

CharFileStatus = cs.BitStruct(
    "unknown1" / cs.Padding(1),
    "file_exists" / cs.Flag,
    "unknown2" / cs.Flag,
    "unknown3" / cs.Padding(5)
)

def _calculate_checksum(ctx):
    io: BytesIO = ctx._io
    # HACK: save and restore io pointer
    orig_pos = io.tell()
    io.seek(0, SEEK_SET)
    # For some reason checksum calculation doesn't include all bytes
    file_bytes = io.read(2860)
    io.seek(orig_pos, SEEK_SET)
    out = sum(file_bytes, start=0)
    out &= 0xFFFF
    return out

CharFile = cs.Struct(
    "idk_header" / cs.Bytes(8),
    "char_type" / CharType,
    "char_name" / TextAdapter(cs.Bytes(9*2)),
    "char_null_term" / cs.Byte,
    "idk_data1" / cs.Byte,
    "story_loadout" / Loadout,
    "idk_data2" / cs.Bytes(8),
    "vs_loadout" / Loadout,
    "idk_data3" / cs.Bytes(8),
    # TODO: use switch
    "equipped_costume_idx" / cs.Byte,
    "equipped_costume_name" / cs.Computed(_get_costume_name),
    "gadgets" / cs.Array(101, Gadget),
    "powerup_parts" / cs.Array(99, cs.Byte),
    "chips" / cs.Array(99, ChipType),
    "idk_data4" / cs.Byte,
    "unlocked_summons" / SummonUnlocked,
    "idk_data5" / cs.Byte,
    # TODO: use switch
    "unlocked_costumes" / cs.Bytes(2),
    "idk_data6" / cs.Bytes(2),
    "saru_book" / cs.Array(0x4C, SaruBookStatus),
    "checksum" / cs.Rebuild(cs.ByteSwapped(cs.Bytes(2)), _calculate_checksum),
    "char_status" / CharFileStatus,
    "idk_data7" / cs.Byte
)

CharData = cs.Struct(
    "files" / cs.Array(32, CharFile)
)