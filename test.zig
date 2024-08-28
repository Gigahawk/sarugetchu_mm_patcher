const std = @import("std");
const file = std.fs.File;

const UnpackerError = error{
    IndexFileInvalidLength,
    IndexFileInvalidReadLength,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("Usage: {s} INDEX DATA\n", .{args[0]});
    }

    const index_name = args[1];
    const data_name = args[2];

    const cwd = std.fs.cwd();

    const index_file = try cwd.openFile(index_name, .{ .mode = file.OpenMode.read_only });
    defer index_file.close();
    const data_file = try cwd.openFile(data_name, .{ .mode = file.OpenMode.read_only });
    defer data_file.close();

    try index_file.seekFromEnd(0);

    const index_len = try index_file.getPos();
    if (index_len % 12 != 0) {
        std.debug.print("Size of index is {d}, which is not a multiple of 12\n", .{index_len});
        return UnpackerError.IndexFileInvalidLength;
    }

    try index_file.seekTo(0);

    var index_buf: [12]u8 = undefined;
    var name_buf: [32]u8 = undefined;
    var file_hash: u32 = undefined;
    //var block_offset_bytes: [4]u8 = undefined;
    var block_offset: u32 = undefined;
    //var file_size_bytes: [4]u8 = undefined;
    var file_size: u32 = undefined;
    var index_entry: u32 = 0;
    while (try index_file.getPos() < index_len) {
        const index_bytes_read = try index_file.read(&index_buf);
        if (index_bytes_read != 12) {
            std.debug.print("Expected 12 bytes read from index but only got {d}", .{index_bytes_read});
            return UnpackerError.IndexFileInvalidReadLength;
        }
        file_hash = std.mem.readInt(u32, index_buf[0..4]);
        block_offset = std.mem.readInt(u32, index_buf[4..8], .little);
        file_size = std.mem.readInt(u32, index_buf[8..12], .little);
        _ = try std.fmt.bufPrint(&name_buf, "{d}_{X:0>8}.gz", .{ index_entry, file_hash });
        std.debug.print("Found file {s} at offset {d} with size {d}\n", .{ name_buf, block_offset, file_size });

        index_entry += 1;
    }
}
