#include "chardata.hexpat"
import std.math;
import std.mem;

#pragma pattern_limit 9999999
#pragma allow_edits

u64 base = 0x0;
CharData chardata @ base;
u64 file_start;

u16 checksum;

for (u8 i = 0, i < 32, i += 1) {
    file_start = addressof(chardata.files[i]);
    checksum = std::math::accumulate(
        file_start,
        file_start + CKSUM_SIZE,
        1,
        0,
        std::math::AccumulateOperation::Add,
        std::mem::Endian::Little
    );
    chardata.files[i].checksum = checksum;
}