#include "typedefs.hexpat"

#pragma pattern_limit 9999999

u64 base = 0x0;
File file @ base;

u64 size = sizeof(file);
str size_str out;
size_str = as_hex(size + 0x0076CC00);