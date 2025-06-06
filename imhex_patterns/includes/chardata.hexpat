import std.mem;
import std.io;

fn as_hex(u16 value) {
    return std::format("{:X}", value);
};

// For some reason the checksum calculation skips the last 4 bytes
#define CKSUM_SIZE 2860

struct TextChar {
    u16 value;
} [[sealed, format("textchar_to_char")]];

fn int_to_textchar(u8 value) {
    match (value) {
        (1): return 0x9F88;
        (2): return 0xA088;
        (3): return 0xA188;
        (4): return 0xA288;
        (5): return 0xA388;
        (6): return 0xA488;
        (7): return 0xA588;
        (8): return 0xA688;
        (9): return 0xA788;
        (0): return 0xA888;
        (_): return 0xA888;
    }
};

fn textchar_to_char(TextChar tc) {
    match (tc.value) {
        // Numerics
        (0x9F88): return "1";
        (0xA088): return "2";
        (0xA188): return "3";
        (0xA288): return "4";
        (0xA388): return "5";
        (0xA488): return "6";
        (0xA588): return "7";
        (0xA688): return "8";
        (0xA788): return "9";
        (0xA888): return "0";

        // Capital letters
        (0xA988): return "A";
        (0xAA88): return "B";
        (0xAB88): return "C";
        (0xAC88): return "D";
        (0xAD88): return "E";
        (0xAE88): return "F";
        (0xAF88): return "G";
        (0xB088): return "H";
        (0xB188): return "I";
        (0xB288): return "J";
        (0xB388): return "K";
        (0xB488): return "L";
        (0xB588): return "M";
        (0xB688): return "N";
        (0xB788): return "O";
        (0xB888): return "P";
        (0xB988): return "Q";
        (0xBA88): return "R";
        (0xBB88): return "S";
        (0xBC88): return "T";
        (0xBD88): return "U";
        (0xBE88): return "V";
        (0xBF88): return "W";
        (0xC088): return "X";
        (0xC188): return "Y";
        (0xC288): return "Z";

        // Lowercase letters
        (0xC388): return "a";
        (0xC488): return "b";
        (0xC588): return "c";
        (0xC688): return "d";
        (0xC788): return "e";
        (0xC888): return "f";
        (0xC988): return "g";
        (0xCA88): return "h";
        (0xCB88): return "i";
        (0xCC88): return "j";
        (0xCD88): return "k";
        (0xCE88): return "l";
        (0xCF88): return "m";
        (0xD088): return "n";
        (0xD188): return "o";
        (0xD288): return "p";
        (0xD388): return "q";
        (0xD488): return "r";
        (0xD588): return "s";
        (0xD688): return "t";
        (0xD788): return "u";
        (0xD888): return "v";
        (0xD988): return "w";
        (0xDA88): return "x";
        (0xDB88): return "y";
        (0xDC88): return "z";

        // Kana
        (0xDD88): return "あ";
        (0xDE88): return "い";
        (0xDF88): return "う";
        (0xE088): return "え";
        (0xE188): return "お";
        (0xE288): return "か";
        (0xE388): return "き";
        (0xE488): return "く";
        (0xE588): return "け";
        (0xE688): return "こ";
        (0xE788): return "さ";
        (0xE888): return "し";
        (0xE988): return "す";
        (0xEA88): return "せ";
        (0xEB88): return "そ";
        (0xEC88): return "た";
        (0xED88): return "ち";
        (0xEE88): return "つ";
        (0xEF88): return "て";
        (0xF088): return "と";
        (0xF188): return "な";
        (0xF288): return "に";
        (0xF388): return "ぬ";
        (0xF488): return "ね";
        (0xF588): return "の";
        (0xF688): return "は";
        (0xF788): return "ひ";
        (0xF888): return "ふ";
        (0xF988): return "へ";
        (0xFA88): return "ほ";
        (0xFB88): return "ま";
        (0xFC88): return "み";

        (0x4089): return "む";
        (0x4189): return "め";
        (0x4289): return "も";
        (0x4389): return "や";
        (0x4489): return "ゆ";
        (0x4589): return "よ";
        (0x4689): return "ら";
        (0x4789): return "り";
        (0x4889): return "る";
        (0x4989): return "れ";
        (0x4A89): return "ろ";
        (0x4B89): return "わ";
        (0x4C89): return "を";
        (0x4D89): return "ん";
        (0x4E89): return "ー";
        (0x4F89): return "、";
        (0x5089): return "。";
        (0x5189): return "ぁ";
        (0x5289): return "ぃ";
        (0x5389): return "ぅ";
        (0x5489): return "ぇ";
        (0x5589): return "ぉ";
        (0x5689): return "が";
        (0x5789): return "ぎ";
        (0x5889): return "ぐ";
        (0x5989): return "げ";
        (0x5A89): return "ご";
        (0x5B89): return "ざ";
        (0x5C89): return "じ";
        (0x5D89): return "ず";
        (0x5E89): return "ぜ";
        (0x5F89): return "ぞ";
        (0x6089): return "だ";
        (0x6189): return "ぢ";
        (0x6289): return "づ";
        (0x6389): return "で";
        (0x6489): return "ど";
        (0x6589): return "っ";
        (0x6689): return "ば";
        (0x6789): return "び";
        (0x6889): return "ぶ";
        (0x6989): return "べ";
        (0x6A89): return "ぼ";
        (0x6B89): return "ぱ";
        (0x6C89): return "ぴ";
        (0x6D89): return "ぷ";
        (0x6E89): return "ぺ";
        (0x6F89): return "ぽ";
        (0x7089): return "ゃ";
        (0x7189): return "ゅ";
        (0x7289): return "ょ";
        (0x7389): return "ゎ";
        //#b"\x89\x74": "　",
        (0x7489): return " ";
        (0x7589): return "ァ";
        (0x7689): return "ア";
        (0x7789): return "ィ";
        (0x7889): return "イ";
        (0x7989): return "ゥ";
        (0x7A89): return "ウ";
        (0x7B89): return "ェ";
        (0x7C89): return "エ";
        (0x7D89): return "ォ";
        (0x7E89): return "オ";
        //# Not a valid token? Prints as ル but probably just a glitch related
        //# to forcing the game to parse an invalid token
        //#b"\x89\x7F": "??",
        (0x8089): return "カ";
        (0x8189): return "ガ";
        (0x8289): return "キ";
        (0x8389): return "ギ";
        (0x8489): return "ク";
        (0x8589): return "グ";
        (0x8689): return "ケ";
        (0x8789): return "ゲ";
        (0x8889): return "コ";
        (0x8989): return "ゴ";
        (0x8A89): return "サ";
        (0x8B89): return "ザ";
        (0x8C89): return "シ";
        (0x8D89): return "ジ";
        (0x8E89): return "ス";
        (0x8F89): return "ズ";
        (0x9089): return "セ";
        (0x9189): return "ゼ";
        (0x9289): return "ソ";
        (0x9389): return "ゾ";
        (0x9489): return "タ";
        (0x9589): return "ダ";
        (0x9689): return "チ";
        (0x9789): return "ヂ";
        (0x9889): return "ッ";
        (0x9989): return "ツ";
        (0x9A89): return "ヅ";
        (0x9B89): return "テ";
        (0x9C89): return "デ";
        (0x9D89): return "ト";
        (0x9E89): return "ド";
        (0x9F89): return "ナ";
        (0xA089): return "ニ";
        (0xA189): return "ヌ";
        (0xA289): return "ネ";
        (0xA389): return "ノ";
        (0xA489): return "ハ";
        (0xA589): return "バ";
        (0xA689): return "パ";
        (0xA789): return "ヒ";
        (0xA889): return "ビ";
        (0xA989): return "ピ";
        (0xAA89): return "フ";
        (0xAB89): return "ブ";
        (0xAC89): return "プ";
        (0xAD89): return "ヘ";
        (0xAE89): return "ベ";
        (0xAF89): return "ペ";
        (0xB089): return "ホ";
        (0xB189): return "ボ";
        (0xB289): return "ポ";
        (0xB389): return "マ";
        (0xB489): return "ミ";
        (0xB589): return "ム";
        (0xB689): return "メ";
        (0xB789): return "モ";
        (0xB889): return "ャ";
        (0xB989): return "ヤ";
        (0xBA89): return "ュ";
        (0xBB89): return "ユ";
        (0xBC89): return "ョ";
        (0xBD89): return "ヨ";
        (0xBE89): return "ラ";
        (0xBF89): return "リ";
        (0xC089): return "ル";
        (0xC189): return "レ";
        (0xC289): return "ロ";
        (0xC389): return "ヮ";
        (0xC489): return "ワ";
        (0xC589): return "ヲ";
        (0xC689): return "ン";
        (0xC789): return "ヴ";
        (0xC889): return "ヵ";
        (0xC989): return "ヶ";

        // Punctuation and special chars
        // Playstation button symbols, no real match with Unicode
        // but these should be pretty close
        (0xCA89): return "○";
        (0xCB89): return "Χ";
        (0xCC89): return "□";
        (0xCD89): return "△";
        (0xCE89): return "!";
        (0xCF89): return "?";
        (0xD089): return "(";
        (0xD189): return ")";
        (0xD289): return "*";
        (0xD389): return "+";
        (0xD489): return "-";
        (0xD589): return "&";
        (0xD689): return "@";
        (0xD789): return "⋅";
        (0xD889): return ".";
        (0xD989): return ":";
        (0xDA89): return "^";
        (0xDB89): return "_";
        (0xDC89): return "ω";
        (0xDD89): return "Д";
        (0xDE89): return "∀";
        (0xDF89): return "⊃";
        (0xE089): return "♂";
        (0xE189): return "♀";
        (0xE289): return "♪";
        // Not sure which of these is correct
        //b"\x89\xE3": "~",
        (0xE389): return "〜";
        (0xE489): return "➝";

        (0x0000): return "\\x00";

        (_): return std::format("?? ({:04X})", tc.value);
    }
};

enum CharType: u8 {
    KAKERU = 0,
    PROFESSOR = 1,
    NATSUMI = 2,
    CHARU = 3,
    HARUKA = 4,
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

enum ChipType: u8 {
    MAGNESIUM = 0,
    GERMANIUM = 1,
    COBALT = 2,
    CADMIUM = 3,
    ZIRCONIUM = 4,
    NOBELLIUM = 5,
    TELLURIUM = 6,
    NIOBIUM = 7,
    NEODYMIUM = 8,
    ASTATINE = 9,
    ERBIUM = 10,
    XENON = 11,
    BISMUTH = 12,
    FERMIUM = 13,
    PROMETHIUM = 14,
    BERYLLIUM = 15,
    HOLMIUM = 16,
    RUTHENIUM = 17,

    END_MARKER = 0xFF,
};

enum KakeruCostume: u8 {
    DEFAULT = 0,
    LIGHT_ARMOR_A = 1,
    LIGHT_ARMOR_B = 2,
    HEAVY_ARMOR = 3,
    MILITARY_SET = 4,
    DARK_FASHION = 5,
    SECOND_FASHION = 6,
    HISTORICAL_ARMOR = 7,
    SAMURAI_SET = 8,
    BUSINESSMAN_SET = 9,
    GUNMAN_SET = 10,
    DANCER_SET = 11,
    EMPTY = 12,
    TORO_COSTUME = 13,
    SARU_KAKERU_A = 14,
    SARU_KAKERU_B = 15,
};

enum KakeruGadget: u8 {
    GET_NET = 0,
    MECHA_BO = 1,
    BIG_BO = 2,
    W_MECHA_BO = 3,
    KIKO_BO = 4,
    LASER_GUN = 5,
    MACHINE_GUN = 6,  // Yellow Gun
    SHOTGUN = 7,  // Red Gun
    VERNIER = 8,
    DASH_BOOTS = 9,
    ATTACK_BOOTS = 10,  // Yellow Boots
    WARP_BOOTS = 11,  // Red Boots
    B_LAUNCHER = 12,
    H_LAUNCHER = 13,
    MEGA_LAUNCHER = 14,
    REMOTE_BOMB = 15,
    KILLER_BEE = 16,
    SATELLITE_LASER = 17,
    BACKPACK = 18,
    LIGHT_TANK = 19,
    MEDIUM_TANK = 20,
    // Blue "SP" icon, seems to be an invalid mount, character model
    // doesn't show and the preview image is just the current screen rendered
    // picture in picture style
    UNKNOWN1 = 21,
    LIGHT_MECH = 22,
    MEDIUM_MECH = 23,
    // Seems to be another invalid mount, has the light mech icon but is
    // otherwise identical to UNKNOWN1
    UNKNOWN2 = 24,
    // These ones all have the GET_NET icon, character model shows but not
    // carrying anything. Preview image is current screen.
    UNKNOWN3 = 25,
    UNKNOWN4 = 26,
    UNKNOWN5 = 27,
    UNKNOWN6 = 28,
    // Same as above, but has the LASER_GUN icon
    UNKNOWN6 = 29,
    // Values beyond here crash the game if you select them in character edit
};


enum ProfessorCostume: u8 {
    DEFAULT = 0,
    LIGHT_ARMOR_A = 1,
    LIGHT_ARMOR_B = 2,
    HEAVY_ARMOR = 3,
    MILITARY_SET = 4,
    DARK_FASHION = 5,
    SECOND_FASHION = 6,
    HISTORICAL_ARMOR = 7,
    LORD_SET = 8,
    SANTA_SET = 9,
    SHERIFF_SET = 10,
    DETECTIVE_SET = 11,
    EMPTY = 12,
    TORO_COSTUME = 13,
    INVALID1 = 14,
    INVALID2 = 15,
};

enum ProfessorGadget: u8 {
    GET_NET = 0,
    MECHA_HAMMER = 1,
    THORN_HAMMER = 2,
    SAW_HAMMER = 3,
    LASER_GUN = 4,
    MACHINE_GUN = 5,  // Yellow Gun
    SHOTGUN = 6,  // Red Gun
    VERNIER = 7,
    DASH_BOOSTER = 8,
    ATTACK_BOOSTER = 9,  // Yellow Boots
    WARP_BOOSTER = 10,  // Red Boots
    B_LAUNCHER = 11,
    H_LAUNCHER = 12,
    MEGA_LAUNCHER = 13,
    GIGA_LAUNCHER = 14,
    REMOTE_BOMB = 15,
    KILLER_BEE = 16,
    SATELLITE_LASER = 17,
    BACKPACK = 18,
    LIGHT_TANK = 19,
    MEDIUM_TANK = 20,
    // Blue "SP" icon, seems to be an invalid mount, character model
    // doesn't show and the preview image is just the current screen rendered
    // picture in picture style
    UNKNOWN1 = 21,
    LIGHT_MECH = 22,
    MEDIUM_MECH = 23,
    // Seems to be another invalid mount, has the light mech icon but is
    // otherwise identical to UNKNOWN1
    UNKNOWN2 = 24,
    // This one has the REMOTE_BOMB logo, character model is rendered but small
    UNKNOWN3 = 25,
    // These ones all have the GET_NET icon, character model shows but not
    // carrying anything. Preview image is current screen.
    UNKNOWN4 = 26,
    UNKNOWN5 = 27,
    UNKNOWN6 = 28,
    // Same as above, but has the LASER_GUN icon
    UNKNOWN6 = 29,
    // Values beyond here crash the game if you select them in character edit
};



enum NatsumiCostume: u8 {
    DEFAULT = 0,
    LIGHT_ARMOR_A = 1,
    LIGHT_ARMOR_B = 2,
    HEAVY_ARMOR = 3,
    MILITARY_SET = 4,
    DARK_FASHION = 5,
    SECOND_FASHION = 6,
    HISTORICAL_ARMOR = 7,
    NINJA_SET = 8,
    REINDEER_SET = 9,
    COWGIRL_SET = 10,
    RED_JERSEY_SET = 11,
    EMPTY = 12,
    TORO_COSTUME = 13,
    INVALID1 = 14,
    INVALID2 = 15,
};

enum NatsumiGadget: u8 {
    GET_NET = 0,
    MECHA_ROD = 1,
    W_ROD = 2,
    LASER_GUN = 3,
    MACHINE_GUN = 4,  // Yellow Gun
    SHOTGUN = 5,  // Red Gun
    W_LASER = 6,
    VERNIER = 7,
    DASH_BOOTS = 8,
    ATTACK_BOOTS = 9,  // Yellow Boots
    WARP_BOOTS = 10,  // Red Boots
    B_LAUNCHER = 11,
    H_LAUNCHER = 12,
    MEGA_LAUNCHER = 13,
    GIGA_LAUNCHER = 14,
    REMOTE_BOMB = 15,
    KILLER_BEE = 16,
    SATELLITE_LASER = 17,
    BACKPACK = 18,
    LIGHT_TANK = 19,
    MEDIUM_TANK = 20,
    // Blue "SP" icon, seems to be an invalid mount, character model
    // doesn't show and the preview image is just the current screen rendered
    // picture in picture style
    UNKNOWN1 = 21,
    LIGHT_MECH = 22,
    MEDIUM_MECH = 23,
    UNKNOWN2 = 24,
    UNKNOWN3 = 25,
    UNKNOWN4 = 26,
    UNKNOWN5 = 27,
    UNKNOWN6 = 28,
    UNKNOWN6 = 29,
};


enum CharuCostume: u8 {
    DEFAULT = 0,
    LIGHT_ARMOR_A = 1,
    LIGHT_ARMOR_B = 2,
    HEAVY_ARMOR = 3,
    MILITARY_SET = 4,
    DARK_FASHION = 5,
    SECOND_FASHION = 6,
    HISTORICAL_ARMOR = 7,
    TOWN_GIRL_SET = 8,
    SHEEP_SET = 9,
    DEVIL_SET = 10,
    MAGICAL_GIRL_SET = 11,
    EMPTY = 12,
    TORO_COSTUME = 13,
    INVALID1 = 14,
    INVALID2 = 15,
};

enum CharuGadget: u8 {
    GET_NET = 0,
    MAGIC_WAND = 1,
    MECHA_BO = 2,
    ARM_SHOT = 3,
    LASER_GUN = 4,
    MACHINE_GUN = 5,  // Yellow Gun
    SHOTGUN = 6,  // Red Gun
    VERNIER = 7,
    DASH_BOOTS = 8,
    ATTACK_BOOTS = 9,  // Yellow Boots
    WARP_BOOTS = 10,  // Red Boots
    B_LAUNCHER = 11,
    H_LAUNCHER = 12,
    MEGA_LAUNCHER = 13,
    REMOTE_BOMB = 14,
    KILLER_BEE = 15,
    SATELLITE_LASER = 16,
    BACKPACK = 17,
    LIGHT_TANK = 18,
    MEDIUM_TANK = 19,
    // Blue "SP" icon, seems to be an invalid mount, character model
    // doesn't show and the preview image is just the current screen rendered
    // picture in picture style
    UNKNOWN1 = 20,
    LIGHT_MECH = 21,
    MEDIUM_MECH = 22,
    UNKNOWN2 = 23,
    UNKNOWN3 = 24,
    UNKNOWN4 = 25,
    UNKNOWN5 = 26,
    UNKNOWN6 = 27,
    UNKNOWN6 = 28,
};

enum HarukaCostume: u8 {
    DEFAULT = 0,
    LIGHT_ARMOR_A = 1,
    LIGHT_ARMOR_B = 2,
    HEAVY_ARMOR = 3,
    MILITARY_SET = 4,
    DARK_FASHION = 5,
    SECOND_FASHION = 6,
    HISTORICAL_ARMOR = 7,
    HUNTER_SET = 8,
    RACCOON_SET = 9,
    POLICE_SET = 10,
    ANGEL_SET = 11,
    EMPTY = 12,
    TORO_COSTUME = 13,
    INVALID1 = 14,
    INVALID2 = 15,
};

// Can't create or edit gadgets on this character,
// research based on story mode
enum HarukaGadget: u8 {
    GET_NET = 0,
    MECHA_BO = 1,
    LASER_GUN = 2,
    MACHINE_GUN = 3,  // Yellow Gun
    // SHOTGUN = 4,  // not supported on this character?
    // Best guess, idx 4 also doesn't show up so not sure which one it is
    VERNIER = 5,
    DASH_BOOTS = 6,
    ATTACK_BOOTS = 7,  // Yellow Boots
    HOMING_ARROW = 8,
    REMOTE_BOMB = 9,
    KILLER_BEE = 10,
    SATELLITE_LASER = 11,
    LIGHT_TANK = 12,
    MEDIUM_TANK = 13,
    //UNKNOWN1 = 14,
    LIGHT_MECH = 15,
    MEDIUM_MECH = 16,
};


enum SaruTeamCostume: u8 {
    DEFAULT = 0,
    LIGHT_ARMOR = 1,
    MIDDLE_ARMOR = 2,
    HEAVY_ARMOR = 3,
    MILITARY_SET = 4,
    DARK_FASHION = 5,
    SECOND_FASHION = 6,
    HISTORICAL_ARMOR = 7,
    SHINOBI_SET = 8,
    AMAZON_SET = 9,
    POLICE_SET = 10,
    HEAVY_METAL_SET = 11,
    EMPTY = 12,
    TORO_COSTUME = 13,
    KORO_DRAGON_SET = 14,
    KINTARO_SET = 15,
};

enum SaruTeamGadget: u8 {
    GET_NET = 0,
    MECHA_BO = 1,
    BIG_BO = 2,
    W_HAMMER = 3,
    W_DRILL = 4,
    LASER_GUN = 5,
    MACHINE_GUN = 6,  // Yellow Gun
    SHOTGUN = 7,  // Red Gun
    VERNIER = 8,
    DASH_BOOTS = 9,
    ATTACK_BOOTS = 10,  // Yellow Boots
    WARP_BOOTS = 11,  // Red Boots
    B_LAUNCHER = 12,
    H_LAUNCHER = 13,
    MEGA_LAUNCHER = 14,
    REMOTE_BOMB = 15,
    KILLER_BEE = 16,
    SATELLITE_LASER = 17,
    BACKPACK = 18,
    LIGHT_TANK = 19,
    MEDIUM_TANK = 20,
    // Blue "SP" icon, seems to be an invalid mount, character model
    // doesn't show and the preview image is just the current screen rendered
    // picture in picture style
    UNKNOWN1 = 21,
    LIGHT_MECH = 22,
    MEDIUM_MECH = 23,
    UNKNOWN2 = 24,
    UNKNOWN3 = 25,
    UNKNOWN4 = 26,
    UNKNOWN5 = 27,
    UNKNOWN6 = 28,
    UNKNOWN6 = 29,
};

enum PipotronTeamCostume: u8 {
    BLACK_FUR = 0,
    PURPLE_FUR = 1,
    BLUE_FUR = 2,
    WHITE_FUR = 3,
    EMPTY1 = 4,
    EMPTY2 = 5,
    EMPTY3 = 6,
    EMPTY4 = 7,
    EMPTY5 = 8,
    EMPTY6 = 9,
    EMPTY7 = 10,
    EMPTY8 = 11,
    EMPTY9 = 12,
    TORO_COSTUME = 13,
    INVALID1 = 14,
    INVALID2 = 15,
};

// Can't create or edit gadgets on this character,
// research based on story mode
enum PipotronTeamGadget: u8 {
    GET_NET = 0,
    TRON_CHAIN = 1,
    LASER_GUN = 2,
    SHOTGUN = 3,  // Yellow Gun
    VERNIER = 4,
    DASH_HOOP = 5,
    WARP_HOOP = 6,  // Red Boots
    REMOTE_BOMB = 7,
    LIGHT_TANK = 9,
    MEDIUM_TANK = 10,
    //UNKNOWN1 = 11,
    LIGHT_MECH = 12,
    MEDIUM_MECH = 13,
};


enum HirokiCostume: u8 {
    BLUE_JACKET = 0,
    RED_JACKET = 1,
    YELLOW_JACKET = 2,
    WHITE_JACKET = 3,
    EMPTY1 = 4,
    EMPTY2 = 5,
    EMPTY3 = 6,
    EMPTY4 = 7,
    EMPTY5 = 8,
    EMPTY6 = 9,
    EMPTY7 = 10,
    EMPTY8 = 11,
    EMPTY9 = 12,
    TORO_COSTUME = 13,
    INVALID1 = 14,
    INVALID2 = 15,
};

enum SpecterCostume: u8 {
    DEFAULT = 0,
    LIGHT_ARMOR = 1,
    MIDDLE_ARMOR = 2,
    HEAVY_ARMOR = 3,
    MILITARY_SET = 4,
    DARK_FASHION = 5,
    SECOND_FASHION = 6,
    HISTORICAL_ARMOR = 7,
    SHINOBI_SET = 8,
    TIGER_SET = 9,
    AGENT_SET = 10,
    CARMEN_SET = 11,
    EMPTY = 12,
    TORO_COSTUME = 13,
    INVALID1 = 14,
    INVALID2 = 15,
};

enum DarkHirokiCostume: u8 {
    DARK_HAIR = 0,
    GOLD_HAIR = 1,
    GREEN_HAIR = 2,
    PURPLE_HAIR = 3,
    INVALID1 = 4,
    INVALID2 = 5,
    INVALID3 = 6,
    INVALID4 = 7,
    INVALID5 = 8,
    INVALID6 = 9,
    INVALID7 = 10,
    INVALID8 = 11,
    INVALID9 = 12,
    INVALID10 = 13,
    INVALID11 = 14,
    INVALID12 = 15,
};

enum DarkSpecterCostume: u8 {
    DARK_STYLE = 0,
    PURPLE_STYLE = 1,
    BLUE_STYLE = 2,
    WHITE_STYLE = 3,
    INVALID1 = 4,
    INVALID2 = 5,
    INVALID3 = 6,
    INVALID4 = 7,
    INVALID5 = 8,
    INVALID6 = 9,
    INVALID7 = 10,
    INVALID8 = 11,
    INVALID9 = 12,
    INVALID10 = 13,
    INVALID11 = 14,
    INVALID12 = 15,
};

enum PipotronGCostume: u8 {
    WHITE_BODY = 0,
    YELLOW_BODY = 1,
    RED_BODY = 2,
    BLACK_BODY = 3,
    INVALID1 = 4,
    INVALID2 = 5,
    INVALID3 = 6,
    INVALID4 = 7,
    INVALID5 = 8,
    INVALID6 = 9,
    INVALID7 = 10,
    INVALID8 = 11,
    INVALID9 = 12,
    INVALID10 = 13,
    INVALID11 = 14,
    INVALID12 = 15,
};

enum LegendCostume: u8 {
    BLACK_ROBE = 0,
    YELLOW_ROBE = 1,
    BLUE_ROBE = 2,
    WHITE_ROBE = 3,
    INVALID1 = 4,
    INVALID2 = 5,
    INVALID3 = 6,
    INVALID4 = 7,
    INVALID5 = 8,
    INVALID6 = 9,
    INVALID7 = 10,
    INVALID8 = 11,
    INVALID9 = 12,
    INVALID10 = 13,
    INVALID11 = 14,
    INVALID12 = 15,
};

enum VolcanoCostume: u8 {
    RED_ARMOR = 0,
    GREEN_ARMOR = 1,
    BLUE_ARMOR = 2,
    WHITE_ARMOR = 3,
    INVALID1 = 4,
    INVALID2 = 5,
    INVALID3 = 6,
    INVALID4 = 7,
    INVALID5 = 8,
    INVALID6 = 9,
    INVALID7 = 10,
    INVALID8 = 11,
    INVALID9 = 12,
    INVALID10 = 13,
    INVALID11 = 14,
    INVALID12 = 15,
};

enum VirusCharuCostume: u8 {
    GREEN_STYLE = 0,
    PURPLE_STYLE = 1,
    BLUE_STYLE = 2,
    WHITE_STYLE = 3,
    INVALID1 = 4,
    INVALID2 = 5,
    INVALID3 = 6,
    INVALID4 = 7,
    INVALID5 = 8,
    INVALID6 = 9,
    INVALID7 = 10,
    INVALID8 = 11,
    INVALID9 = 12,
    INVALID10 = 13,
    INVALID11 = 14,
    INVALID12 = 15,
};


bitfield SaruBookStatus {
    new_unseen: 1;
    new_seen: 1;
    caught: 1;
    unknown: 5;
};

bitfield SummonUnlocked {
    monta: 1;
    hattori_monzo: 1;
    tutanchimp: 1;
    monkey_pink: 1;
    samui: 1;
    monki_san: 1;
    edison: 1;
    monkey_red: 1;
    afro: 1;
    pumpkin: 1;
    salus_monkey: 1;
    miyamoto: 1;
    wakkie: 1;
    pierre: 1;
    jun: 1;
    suzuki: 1;
    ricky: 1;
    toro: 1;
    unknown: 6;
};

struct Gadget<auto char_type> {
    TextChar gadget_name[9];
    u8 idkdata1[2];
    match(char_type) {
        (CharType::KAKERU): KakeruGadget item_type;
        (CharType::PROFESSOR): ProfessorGadget item_type;
        (CharType::NATSUMI): NatsumiGadget item_type;
        (CharType::CHARU): CharuGadget item_type;
        (CharType::HARUKA): HarukaGadget item_type;
        (CharType::SARU_TEAM_KI): SaruTeamGadget item_type;
        (CharType::SARU_TEAM_AKAI): SaruTeamGadget item_type;
        (CharType::SARU_TEAM_AOI): SaruTeamGadget item_type;
        (CharType::SARU_TEAM_KURO): SaruTeamGadget item_type;
        (CharType::SARU_TEAM_MIDORI): SaruTeamGadget item_type;
        (CharType::SARU_TEAM_MIZU): SaruTeamGadget item_type;
        (CharType::PIPOTRON_TEAM_RED): PipotronTeamGadget item_type;
        (CharType::PIPOTRON_TEAM_BLUE): PipotronTeamGadget item_type;
        (CharType::PIPOTRON_TEAM_YELLOW): PipotronTeamGadget item_type;
        (CharType::HIROKI): u8 item_type;
        (CharType::SPECTER): u8 item_type;
        (CharType::DARK_HIROKI): u8 item_type;
        (CharType::DARK_SPECTER): u8 item_type;
        (CharType::PIPOTRON_G): u8 item_type;
        (CharType::LEGEND): u8 item_type;
        (CharType::VOLCANO): u8 item_type;
        (CharType::VIRUS_CHARU): u8 item_type;
        (CharType::INVALID1): u8 item_type;
        (CharType::INVALID2): u8 item_type;
        (CharType::NO_CHAR): u8 item_type;
        (_): u8 item_type;
    }
    u8 slots[3];
    // Prevents deletion when inventory is full
    u8 default_item;
};

bitfield CharFileStatus {
    idk1: 1;
    // Always set on created files
    file_exists: 1;
    // This is sometimes set?
    idk2: 1;
    idk3: 5;
};

struct Loadout {
    u8 triangle_gadget_idx;
    u8 circle_gadget_idx;
    u8 cross_gadget_idx;
    u8 square_gadget_idx;
    u8 backpack_gadget_idx;
};

struct CharFile {
    // Doesn't seem to do anything? Character still
    // seems to load as normal even when all set to zero
    u8 idk_header[8];
    CharType char_type;
    TextChar char_name[9];
    u8 char_null_term;
    u8 idk_data1;
    Loadout story_loadout;
    u8 idk_data2[8];
    Loadout vs_loadout;
    u8 idk_data3[8];
    match (char_type) {
        (CharType::KAKERU): KakeruCostume equipped_costume;
        (CharType::PROFESSOR): ProfessorCostume equipped_costume;
        (CharType::NATSUMI): NatsumiCostume equipped_costume;
        (CharType::CHARU): CharuCostume equipped_costume;
        (CharType::HARUKA): HarukaCostume equipped_costume;
        (CharType::SARU_TEAM_KI): SaruTeamCostume equipped_costume;
        (CharType::SARU_TEAM_AKAI): SaruTeamCostume equipped_costume;
        (CharType::SARU_TEAM_AOI): SaruTeamCostume equipped_costume;
        (CharType::SARU_TEAM_KURO): SaruTeamCostume equipped_costume;
        (CharType::SARU_TEAM_MIDORI): SaruTeamCostume equipped_costume;
        (CharType::SARU_TEAM_MIZU): SaruTeamCostume equipped_costume;
        (CharType::PIPOTRON_TEAM_RED): PipotronTeamCostume equipped_costume;
        (CharType::PIPOTRON_TEAM_BLUE): PipotronTeamCostume equipped_costume;
        (CharType::PIPOTRON_TEAM_YELLOW): PipotronTeamCostume equipped_costume;
        (CharType::HIROKI): HirokiCostume equipped_costume;
        (CharType::SPECTER): SpecterCostume equipped_costume;
        (CharType::DARK_HIROKI): DarkHirokiCostume equipped_costume;
        (CharType::DARK_SPECTER): DarkSpecterCostume equipped_costume;
        (CharType::PIPOTRON_G): PipotronGCostume equipped_costume;
        (CharType::LEGEND): LegendCostume equipped_costume;
        (CharType::VIRUS_CHARU): VirusCharuCostume equipped_costume;
        (_): u8 equipped_costume;
    }
    // Game limits you to 99 but manually editing in the last 2 seems to work
    // fine
    Gadget<char_type> gadgets[101];
    // TODO: figure out the different types
    u8 powerup_parts_inventory[99];
    ChipType chip_inventory[99];
    u8 idk_data4;
    SummonUnlocked summoning_capsules;
    u8 idk_data5;
    u16 unlocked_costumes;
    u8 idk_data6[0x2];
    SaruBookStatus saru_book[0x4C];
    // All bytes prior to this except the last 4 are in this checksum
    // for some reason.
    // If both checksum and status are zero, file is not read
    // (shows up as free slot). If checksum is wrong or only status is zero,
    // file shows up as corrupted.
    u16 checksum [[format("as_hex")]];
    CharFileStatus status;
    u8 idk_data7;
};


struct CharData {
    CharFile files[32];
};