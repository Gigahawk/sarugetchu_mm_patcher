#include "chardata.hexpat"
import std.math;
import std.mem;

#pragma pattern_limit 9999999

u65 base = 0x0;
CharData chardata @ base;
u64 file_start;


struct Tuple {
    u8 a;
    u8 b;
};
union U16ToTuple {
    u16 val;
    Tuple tuple;
};

U16ToTuple checksum;

for (u8 i = 0, i < 32, i += 1) {
    file_start = addressof(chardata.files[i]);
    checksum.val = std::math::accumulate(
        file_start,
        file_start + CKSUM_SIZE,
        1,
        0,
        std::math::AccumulateOperation::Add,
        std::mem::Endian::Little
    );
    std::print("File {} hash: {:02X} {:02X}", i, checksum.tuple.a, checksum.tuple.b);
}