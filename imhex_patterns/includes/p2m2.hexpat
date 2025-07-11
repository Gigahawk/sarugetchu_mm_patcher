bitfield BitButtonsUp {
    select: 1;
    l3: 1;
    r3: 1;
    start: 1;
    idk4: 1;
    idk5: 1;
    idk6: 1;
    idk7: 1;
};

struct Frame {
    BitButtonsUp buttons;
    u8 idk07;
    u8 r_x;
    u8 r_y;
    u8 l_x;
    u8 l_y;
    u8 dpad_right;
    u8 dpad_left;
    u8 dpad_up;
    u8 dpad_down;
    u8 triangle;
    u8 circle;
    u8 cross;
    u8 square;
    u8 l1;
    u8 r1;
    u8 l2;
    u8 r2;
    u8 idk24;
    u8 idk25;
    u8 idk26;
    u8 idk27;
    u8 idk28;
    u8 idk29;
    u8 idk30;
    u8 idk31;
    u8 idk32;
    u8 idk33;
    u8 idk34;
    u8 idk35;
    u8 idk36;
    u8 idk01;
    u8 idk02;
    u8 idk03;
    u8 idk04;
    u8 idk05;
};

struct P2M2 {
    u8 idk1;
    char pcsx2_version[50];
    char author[255];
    char game_name[255];
    u64 num_frames;
    u8 idk2[1];
    // Seems to always be an extra empty frame?
    Frame null_frame;
    Frame frames[num_frames];
};
