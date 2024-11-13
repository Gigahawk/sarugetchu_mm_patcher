#include "typedefs.hexpat"

u64 base = 0x0;
File file @ base;

u64 size = sizeof(file);
str size_str out;
size_str = as_hex(size + 0x0076CC00);

//le u32 num_pixel_datas @ base + 0x000D6337;
//le PixelData pixel_datas[num_pixel_datas] @ base + 0x000D633B;

//ImgFile font_gf @ base +  0x000FD1C9;

//le u32 idk_resource_len @ 0x000D9A7C;
//IdkResource idk[idk_resource_len] @ 0x000D9A80;


//le u32 num_joints @ base + 0x000E68F5;
//Joint joints[num_joints] @ base + 0xE68F9;