import std.mem;
import std.io;

fn as_hex(u16 value) {
    return std::format("{:X}", value);
};

enum CharType: u8 {
    KAKERU = 0,
    PROFESSOR = 1,
    NATSUMI = 2,
    CHARU = 3,
    HELGA = 4,
    // Saru/Pipotron Team has multiple members, but save
    // files seem to always use the first value.
    // If you edit the save to be another value,
    // they show up as the default selected when loading
    // from VS mode
    SARU_TEAM_KI = 5,
    SARU_TEAM_AKAI = 6,
    SARU_TEAM_AOI = 7,
    SARU_TEAM_KURO = 8,
    SARU_TEAM_MIDORI = 9,
    SARU_TEAM_MIZU = 10,
    PIPOTRON_TEAM_RED = 11,
    PIPOTRON_TEAM_BLUE = 12,
    PIPOTRON_TEAM_YELLOW = 13,
    HIROKI = 14,
    SPECTER = 15,
    DARK_HIROKI = 16,
    DARK_SPECTER = 17,
    PIPOTRON_G = 18,
    LEGEND = 19,
    VOLCANO = 20,
    VIRUS_CHARU = 21,
    // Character edit screen can load this and shows a T-posing monkey army
    // grunt with no eyes, attempting to access Modify Equipment crashes
    //the game
    INVALID1 = 22,
    // Immediately causes game to crash when attempting to read
    INVALID2 = 23,
    // Seems to be the default value for a blank file.
    // Setting an existing file to this value causes weird behavior, so it's
    // not the only thing determining whether a file has been created.
    //  - Crash when attempting to load character in char edit
    //  - Doesn't show up in VS. mode
    //  - "This character cannot be selected in story mode" if selected in story mode
    NO_CHAR = 24,
    // Values beyond this seem to just cause crashes
};

struct CharFile {
    u8 idk_header[8];
    CharType char_type;
    u16 char_name[9] [[format("as_hex")]];
    u8 char_null_term;
    u8 idk_data[0xAC4];
    u16 unlocked_costumes;
    u8 idk_data2[0x4E];
    u16 checksum [[format("as_hex")]];
    u8 idk_data3[2];
};

struct CharData {
    CharFile files[32];
};