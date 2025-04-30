import std.mem;
import std.io;
fn as_hex(u16 value) {
    return std::format("{:X}", value);
};

#define CKSUM_SIZE 48

struct ProgressDateTime {
    u8 year;
    u8 month;
    u8 day;
    u8 hour;
    u8 minute;
    u8 second;
};

enum OptionSound: u8 {
    MONO = 0,
    STEREO = 1,
    DOLBY_PRO_LOGIC_2 = 2,
};

struct ProgressOptions {
    OptionSound sound;
    bool vibration;
    u8 sound_effect_vol;
    u8 bgm_vol;
};

struct ProgressFile {
    u8 idk_data1[8];
    ProgressDateTime date_time;
    ProgressOptions options;
    u8 idk_data2[1];
    u8 episode_kakeru_progress_idx;
    u8 idk_data3[3];
    u8 episode_specter_progress_idx;
    u8 idk_data4[24];
    u16 checksum [[format("as_hex")]];
    u8 idk_data5[6];
};

struct Progress {
    ProgressFile files[4];
};