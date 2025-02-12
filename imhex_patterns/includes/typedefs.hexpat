import std.mem;
import std.io;

fn as_hex(u128 value) {
    return std::format("{:X}", value);
};

struct MaybeString {
    // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
    le u32 str_len [[format("as_hex")]];
    if (str_len != 0) {
        char string[str_len + 1];
    }
};

struct PixelData {
    le u32 idk1;
    le u16 idk2;
    le u16 width;
    le u16 height;
    le u24 num_imgs;
    le u32 *data: u32;
};
struct ImgMetaEntry {
    le PixelData *data: u32;
    le u16 width;
    le u16 height;
    le u32 idk1;
    le u32 idk2;
};
struct ImgMeta {
    le u32 type_len;
    char type[type_len + 1];
    le u32 num_entries;
    ImgMetaEntry entries[num_entries];
    u8 _null;
};

struct ImgSubFile {
    le ImgMeta *metadata: u32;
    le u32 idk1;
    le u32 fname_len;
    char fname[fname_len + 1];
};

struct ImgSubFilePadded{
    le u32 idk;
    ImgSubFile img_sub_file;
};

union ImgSubFilePtr {
    le u32 nullptr;
    if (nullptr != 0) {
        le ImgSubFile *ptr: u32;
    }
} [[inline]];

struct ImgFile {
    le u32 fname_len;
    char fname[fname_len + 1];
    le u8 width;
    le u8 height;
    le u32 num_entries;
    le ImgSubFilePtr entries[num_entries];
};

struct TextureFile {
    // load_font_resource?FUN_0061fad8
        le u16 num_textures;
        le u16 idk1;
        MaybeString file_name;
        le u8 prob_width;
        le u8 prob_height;
        le u32 num_subfile_ptrs;
        // Code seems to always assume 2 or 0 pointers?
        if (num_subfile_ptrs == 2) {
            le ImgSubFilePtr subfile_ptrs[2];
        } else if (num_subfile_ptrs == 0) {

        } else {
            assert(false, "Check load_font_resource?FUN_0061fad8");
        }
};

struct IdkSubResource {
    le u16 idk09 [[format("as_hex")]];
    le u16 idk10 [[format("as_hex")]];
    le u32 idk11 [[format("as_hex")]];
    le u32 idk12 [[format("as_hex")]];
    le u32 idk13 [[format("as_hex")]];
    le u32 idk14 [[format("as_hex")]];
    le u32 idk15 [[format("as_hex")]];
    le u32 idk16 [[format("as_hex")]];
    le u32 idk17 [[format("as_hex")]];
    le u32 *idk18_prob_ptr: u32;
    le u32 *idk19_prob_ptr: u32;
};
struct IdkResource {
    le u32 maybe_first_in_list;
    le u32 idk01 [[format("as_hex")]];
    le u16 idk02 [[format("as_hex")]];
    le u16 num_sub_resources [[format("as_hex")]];
    le u16 idk04 [[format("as_hex")]];
    le u16 idk05_1 [[format("as_hex")]];
    le u16 idk05_2 [[format("as_hex")]];
    le u32 idk06 [[format("as_hex")]];
    le u16 idk07 [[format("as_hex")]];
    le ImgSubFilePtr subfile;
    // This seems wrong
    if (num_sub_resources == 1) {
        le u16 idk08 [[format("as_hex")]];
    }
    IdkSubResource sub_resources[num_sub_resources];
    le u32 shader_len;
    if (shader_len > 0) {
        char shader[shader_len + 1];
    }
    le u32 type_len;
    char type[type_len + 1];
};



struct Idk2 {
    le u32 idk1;
    le u16 idk2;
    le u16 idk3;
    le u8 idk4[0x10];
    le u8 idk5[0x10];
    le u8 idk6[0x10];
    le u32 idk7;
    le u32 idk8;
    le u32 idk_ptr_arr_len;
    le u32 idk_ptrs[idk_ptr_arr_len];
};

struct SubJoint {
    le u32 name_len;
    char name[name_len + 1];
    le u16 idk[5];
};

struct Joint {
    le u32 name_len;
    char name[name_len + 1];
    le u32 subname_len;
    if (subname_len > 0) {
        char subname[subname_len + 1];
    }
    le u32 num_subjoints;
    SubJoint subjoints[num_subjoints];
    le u16 idk2[12];
};


struct JointClass0Subclass4 {
    le u32 idk1;
    le u32 idk2;
    le u32 idk3;
    le u32 idk4;
    le u32 idk5;
};

struct JointClass0 {
    le u32 sub_class_id;
    if (sub_class_id == 3) {
        le u32 idk1;
        le u32 idk2;
        le u32 idk3;
        // TODO: i think theres a loop/array here
        assert(false, "joint class 0 subclass 3 not implemented");
    } else if (sub_class_id == 2) {
        le u32 idk1;
        le u32 idk2;
        le u32 idk3;
        le u32 idk4;
        le u32 idk5;
    } else if (sub_class_id == 4) {
        le u32 idk1;
        le u32 idk2;
        le u32 data_len;
        JointClass0Subclass4 data[data_len];
    } else {
        assert(false, "Unknown joint class 0 subclass id");
    }
    le u32 idk_end;
    MaybeString maybe_string;
};

struct JointClass1 {
    le u32 ptr1;
};

struct Joint2 {
    // rendernodeinterfacep_instantiate
    le u32 class_id;
    if (class_id == 0) {
        MaybeString maybe_name;
        le u32 joint_data_len;
        JointClass0 idk_joint_data[joint_data_len];
        u8 maybe_end;
        if (maybe_end != 0) {
            le u32 some_ptr;
        }
    } else if (class_id == 1) {
        MaybeString maybe_name;
        le u32 joint_data_len;
        JointClass1 idk_joint_data[joint_data_len];
    } else {
        assert(false, "Unknown class id");
    }
};

struct Joint3SubData {
    MaybeString maybe_string1;
    MaybeString maybe_string2;
};

struct Joint3Data {
    MaybeString name;
    le u32 idk_len;

};

struct Joint3 {
    le u32 ptrs_len;
    le u32 ptrs[ptrs_len];
    le u32 ptr2;
    le u32 data_len;
    Joint3Data data[data_len];

};

struct EncodedString {
    le u32 id;
    le u32 str_len;
    le u8 string[str_len + 1];
};

struct JointMotionSubData {
    le u32 idk1;
    le u32 idk2;

};

struct JointMotionData {
    MaybeString name;
    le u32 idk1;
    le u32 idk2;
    le u32 sub_data_len;
    JointMotionSubData data[sub_data_len];

};

struct JointMotion {
    MaybeString name;
    le u32 data_len;
    JointMotionData data[data_len];
};

struct Camera {
    MaybeString name;
    le u32 idk1;
    le u16 idk2[13];
    le u32 idk3;
    le u32 idk4;
    le u16 idk5;
    le u16 idk6;
};

struct ModelJointMeta {
    MaybeString name1;
    MaybeString id;
};

struct ModelJoint {
    MaybeString name;
    MaybeString type;
    le u32 idk1[9];
    le u32 len_joint_meta;
    ModelJointMeta joint_meta[len_joint_meta];
    le u32 idk3;
    if (idk3 != 0) {
        assert(false, "check load_model_joint?FUN_0062e5a0");
    }
};

struct Model {
    MaybeString name;
    le u32 num_joints;
    ModelJoint joints[num_joints];
};

struct Collision {
    MaybeString name;
    le u32 idk1[5];
    le u8 idk2[0x10];
};

struct SoundPath {
    // Seems to point to base of sound path array?
    le u32 base_ptr;
    MaybeString path;
    le u32 idk1;
    le u32 idk2;

};

struct Collision2 {
    MaybeString name;
    le u32 idk1;
    if (idk1 != 0) {
        le u32 idk2;
    }
};


struct SubFile {
    u8 data_present;
    if (data_present != 0) {
        le u32 data_size [[format("as_hex")]];
        u8 data[data_size];
    }
};

struct TextureFactory {
    // texturefactory_instantiate
        // copy_file_base
            SubFile data;
        le u32 pixel_data_len [[format("as_hex")]];
        le u32 img_meta_len [[format("as_hex")]];
        le u32 img_subfile_len [[format("as_hex")]];
        PixelData pixel_data[pixel_data_len];
        ImgMeta img_meta[img_meta_len];
        ImgSubFilePadded img_sub_files[img_subfile_len];
};


struct File {
// DO_A_LOT_OF_STUFF_WITH_OFFSETS
    // copy_file_base
        SubFile data1;


    // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
        MaybeString idk_maybe_string;

    // renderdata_instantiate
        // copy_file_base
            SubFile renderdata;
        // texturefactory_instantiate
            TextureFactory texturefactory;
        le u32 idk_res_len [[format("as_hex")]];
        IdkResource idk_resources[idk_res_len];
        // parse_joints?
            le u32 joints_len;
            Joint joints[joints_len];
        le u32 idk2_len [[format("as_hex")]];
        Idk2 idk2s[idk2_len];
        le u32 joints2_len [[format("as_hex")]];
        Joint2 joints2[joints2_len];
        le u32 idk3_len [[format("as_hex")]];
        if (idk3_len != 0) {
            assert(false, "Check FUN_0062ba50");
        }
        le u32 maybe_ptr1;

    // load_joints3?
        le u32 joints3_len [[format("as_hex")]];
        Joint3 joints3[joints3_len];

    // EVENTUALLY_EVENTUALLY_DO_SMTH_WITH_STRING
        le u32 num_strs;
        EncodedString strings[num_strs];

    // parse_joint_anim_data?
        le u32 joint_motion_len [[format("as_hex")]];
        JointMotion joint_motions[joint_motion_len];

    // idk?FUN_0062dbb0
        le u32 idk4_len;
        if (idk4_len != 0) {
            assert(false, "Check idk?FUN_0062dbb0");
        }

    // load_cameras?FUN_0062dce8
        le u32 cameras_len;
        Camera cameras[cameras_len];

    // load_model?FUN_0062e400
        le u32 num_models1;
        Model models1[num_models1];

    // load_model?FUN_0062e400
        le u32 num_models2;
        Model models2[num_models2];

    // load_collisions???FUN_0061de38
        le u32 num_colissions;
        Collision collisions[num_colissions];

    // idk?FUN_0061e050
        le u32 idk5_len;
        if (idk5_len != 0) {
            assert(false, "Check idk?FUN_0061e050");
        }

    // idk?FUN_0062b1d8
        SubFile data2;
        TextureFactory texturefactory2;
        le u32 idk6_len;
        if (idk6_len != 0) {
            assert(false, "Check idk?FUN_0062b1d8");
        }

    // idk?FUN_0062b690
        le u32 idk7_len;
        if (idk7_len != 0) {
            assert(false, "Check idk?FUN_0062b690");
        }

    // idk?FUN_0062e160
        le u32 idk8_len;
        if (idk8_len != 0) {
            assert(false, "Check idk?FUN_0062e160");
        }

    // idk?FUN_0061e450
        le u32 idk9_len;
        if (idk9_len != 0) {
            assert(false, "Check idk?FUN_0061e450");
        }

    // idk?FUN_0061ebf8
        le u32 idk10_len;
        if (idk10_len != 0) {
            assert(false, "Check idk?FUN_0061ebf8");
        }

    // idk?FUN_0061d9a0
        le u32 idk11_len;
        if (idk11_len != 0) {
            assert(false, "Check idk?FUN_0061d9a0");
        }

    // load_sound_paths?FUN_0061dbc0
        le u32 num_sound_paths;
        SoundPath sound_paths[num_sound_paths];

    // idk?FUN_0061ed40
        le u32 idk12;
        if (idk12 != 0) {
            le u32 idk13;
        }
        le u32 idk14_len;
        MaybeString idk14_strings[idk14_len];

    // load_other_colission_thing?FUN_0061efa0
        le u32 colission2_len;
        Collision2 collisions2[colission2_len];

    // idk?FUN_0061e8c0
        le u32 idk15_len;
        if (idk15_len != 0) {
            assert(false, "Check idk?FUN_0061e8c0");
        }

    // idk?FUN_0061f348
        le u32 idk16_len;
        if (idk16_len != 0) {
            assert(false, "Check idk?FUN_0061f348");
        }

    // idk?FUN_0061f990
        le u32 idk17_len;
        if (idk17_len != 0) {
            assert(false, "Check idk?FUN_0061f990");
        }

    // idk?FUN_0061f6d0
        le u32 idk18_len;
        if (idk18_len != 0) {
            assert(false, "Check idk?FUN_0061f6d0");
        }

    // idk?FUN_006205e0
        le u32 idk19_exists;
        if (idk19_exists != 0) {
            // idk?FUN_00620678
                le u8 idk20[0x10];
                le u8 idk21[0x10];
                le u8 idk22[0x10];
                le u32 idk23_exists;
                if (idk23_exists != 0) {
                    le u32 idk24;
                    // transform_FUN_0050dd68
                }
                le u32 idk25;
                if (idk25 != 0) {
                    le u32 idk26;
                    // transform_FUN_0050dd68
                }
        }

    // idk?FUN_00620350
        le u16 idk27;
        le u16 idk28;
        if (idk27 != 0) {
            assert(false, "Check idk?FUN_00620350");
        }
        if (idk28 != 0) {
            assert(false, "Check idk?FUN_00620350");
        }

    // idk?FUN_00629c18
        le u32 idk29;
        if (idk29 != 0) {
            assert(false, "Check idk?FUN_00629c18");
        }

    // idk_font_resource_loader?FUN_0061fca8
        le u32 idk30_res_len;
        TextureFile texture_files[idk30_res_len];



};