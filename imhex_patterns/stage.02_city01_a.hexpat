#include "typedefs.hexpat"

le u32 *header: u32 @ 0x00000001;

le PixelData pixel_datas[40] @ 0x000A7C07;


ImgFile font_gf @ 0x000BCC38;

le u32 idk_resource_len @ 0x000A9885;
IdkResource idk[idk_resource_len] @ 0x000A9889;


le u32 idk_resource_meta_len @ 0x000B0B46;
le u32 idK_resource_meta_start_addr @ 0x000B0B4A [[format("as_hex")]];
IdkResource *start : u32 @ 0x000B0B4A;

//IdkResource2 idk2 @ 0x000ADCBB;