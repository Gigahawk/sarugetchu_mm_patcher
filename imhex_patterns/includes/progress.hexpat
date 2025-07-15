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

bitfield PasswordUnlocks {
    monkey_kakeru: 1;
    network_password: 1;
    haruka: 1;
    pipotron_team: 1;
    hiroki: 1;
    dark_hiroki: 1;
    dark_specter: 1;
    volcano: 1;
    legend: 1;
    virus_charu: 1;
    i_feel_love: 1;
    story_difficulty_select: 1;
    kintaro_set: 1;
    koro_dragon_set: 1;
    idk14: 1;
    idk15: 1;
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
    u8 idk_data7[2];
    PasswordUnlocks unlocks;
    u8 idk_data8[6];
    u16 checksum [[format("as_hex")]];
    u8 idk_data9[6];
};

struct Progress {
    ProgressFile files[4];
};