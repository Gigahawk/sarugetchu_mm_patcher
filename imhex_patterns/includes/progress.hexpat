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

struct ProgressMission {
    u8 idk1;
    u8 completed_levels;
    bool all_completed;
    // Seems to be set by default, cleared when a level is completed but
    // doesn't seem to do anything either way
    bool new;
};

struct ProgressFile {
    u8 idk_data1[8];
    ProgressDateTime date_time;
    ProgressOptions options;
    // Setting the story mode `all_completed` flags to true adds a crown to its
    // respsective section of the save file
    ProgressMission episode_kakeru_progress;
    ProgressMission episode_specter_progress;
    // Setting all tournament `all_completed` flags to true adds a crown to the
    // colosseum section of the save file
    ProgressMission world_tournament_progress;
    ProgressMission legend_tournament_progress;
    ProgressMission devils_tournament_progress;
    u8 idk_data7[10];
    u16 checksum [[format("as_hex")]];
    u8 idk_data8[6];
};

struct Progress {
    ProgressFile files[4];
};