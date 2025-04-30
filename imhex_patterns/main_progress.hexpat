#include "progress.hexpat"
import std.math;
import std.mem;

#pragma pattern_limit 9999999
#pragma allow_edits

u64 base = 0x0;
Progress progress @ base;

u64 file_start;
u16 checksum;

for (u8 i = 0, i < 4, i += 1) {
    file_start = addressof(progress.files[i]);
    checksum = std::math::accumulate(
        file_start,
        file_start + CKSUM_SIZE,
        1,
        0,
        std::math::AccumulateOperation::Add,
        std::mem::Endian::Little
    );
    progress.files[i].checksum = checksum;
}