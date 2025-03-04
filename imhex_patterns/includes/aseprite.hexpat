import std.mem;
import std.io;

fn as_hex(u128 value) {
    return std::format("{:X}", value);
};

using DWORD = u32;
using WORD = u16;
using BYTE = u8;
using SHORT = s16;
// TODO: do this properly
using FIXED = s32;


struct STRING {
    WORD length;
    char string[length];
};

enum ColorDepth : WORD {
    RGBA = 32,
    GRAYSCALE = 16,
    INDEXED = 8,
};

struct PixelRGBA {
    BYTE r;
    BYTE g;
    BYTE b;
    BYTE a;
};

struct PixelIndexed {
    BYTE idx;
};

struct PIXEL<auto color_depth> {
    match(color_depth) {
        (ColorDepth::RGBA): PixelRGBA px;
        (ColorDepth::INDEXED): PixelIndexed px;
    }
};

enum ChunkType : WORD {
    OLD_PALETTE1 = 0x0004,
    OLD_PALETTE2 = 0x0011,
    LAYER = 0x2004,
    CEL = 0x2005,
    COLOR_PROFILE = 0x2007,
    PALETTE = 0x2019,
};

bitfield LayerChunkFlags {
    visible: 1;
    editable: 1;
    lock_movement: 1;
    background: 1;
    prefer_linked_cels: 1;
    group_display_collapsed: 1;
    reference: 1;
    reserved: 16 - 7;
};

enum LayerChunkType : WORD {
    NORMAL = 0,
    GROUP = 1,
    TILEMAP = 2,
};

struct LayerChunk {
    LayerChunkFlags flags;
    LayerChunkType type;
    WORD child_level;
    WORD default_px_width; // ignored?
    WORD default_px_height; // ignored?
    // TODO: enum
    WORD blend_mode;
    BYTE opacity;
    BYTE reserved[3];
    STRING name;
    if (type == LayerChunkType::TILEMAP) {
        DWORD tileset_index;
    }
};

enum CelChunkType : WORD {
    RAW = 0,
    LINKED = 1,
    COMPRESSED_IMG = 2,
    COMPRESSED_TILEMAP = 3,
};

union CelChunkRawPixels<auto width, auto height> {
    // TODO: support different color types
    PIXEL<ColorDepth::INDEXED> pixels[width*height];
    BYTE data[width*height];
};



struct CelChunk<auto chunk_size> {
    WORD layer_idx;
    SHORT x_pos;
    SHORT y_pos;
    BYTE opacity_level;
    CelChunkType type;
    SHORT z_index;
    BYTE reserved[5];
    // TODO: handle cel data
    if (type == CelChunkType::RAW) {
        WORD width;
        WORD height;
        CelChunkRawPixels<width, height> data;
    } else if (type == CelChunkType::COMPRESSED_IMG) {
        WORD width;
        WORD height;
        BYTE data[chunk_size - 26];
    }
};

enum ColorProfileType : WORD {
    NONE = 0,
    SRGB = 1,
    ICC = 2,
};

struct ColorProfileChunk {
    ColorProfileType type;
    WORD flags;
    FIXED gamma;
    BYTE reserved[8];
    if (type == ColorProfileType::ICC) {
        DWORD icc_size;
        BYTE icc_data[icc_size];
    }
};

bitfield PaletteEntryFlags {
    has_name: 1;
    reserved: 15;
};

struct PaletteEntry {
    PaletteEntryFlags flags;
    BYTE red;
    BYTE green;
    BYTE blue;
    BYTE alpha;
    if (flags.has_name) {
        STRING color_name;
    }
};

struct PaletteChunk {
    DWORD palette_size;
    DWORD start_idx;
    DWORD end_idx;
    BYTE reserved[8];
    PaletteEntry entries[end_idx - start_idx + 1];
};

struct AsepriteFrameChunk {
    DWORD chunk_size;
    ChunkType chunk_type;
    match (chunk_type) {
        (ChunkType::LAYER): LayerChunk data;
        (ChunkType::CEL): CelChunk<chunk_size> data;
        (ChunkType::COLOR_PROFILE): ColorProfileChunk data;
        (ChunkType::PALETTE): PaletteChunk data;
        //(_): error();
    }

};

struct AsepriteFrame {
    DWORD frame_size;
    WORD magic_number [[format("as_hex")]];
    WORD num_chunks_old;
    WORD frame_duration;
    BYTE reserved[2];
    DWORD num_chunks_new;

    if (num_chunks_new != 0) {
        AsepriteFrameChunk chunks[num_chunks_new];
    } else {
        AsepriteFrameChunk chunks[num_chunks_old];
    }
};

bitfield AsepriteHeaderFlags {
    layer_opacity_valid: 1;
    reserved: 31;
};



struct AsepriteHeader {
    DWORD file_size;
    WORD magic_number [[format("as_hex")]];
    WORD frames;
    WORD px_width;
    WORD px_height;
    WORD color_depth;
    AsepriteHeaderFlags flags;
    WORD speed;
    DWORD zero1;
    DWORD zero2;
    BYTE transparent_color_idx;
    BYTE ignore[3];
    WORD num_colors;
    BYTE pixel_width;
    BYTE pixel_height;
    SHORT grid_x;
    SHORT grid_y;
    WORD grid_width;
    WORD grid_height;
    BYTE reserved[84];
};

struct Aseprite {
    AsepriteHeader header;
    AsepriteFrame frames;

};