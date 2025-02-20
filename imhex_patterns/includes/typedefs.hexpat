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
    // idk_load_pixel_data?FUN_0062ee20
        le u32 idk_img_layers;
        le u16 idk2;
        le u16 width;
        le u16 height;
        le u16 num_imgs;
        le u8 data_inline;
        if (data_inline == 0) {
            le u32 *idk_data_ptr: u32;
        } else {
            le u8 idk_data[idk_img_layers*num_imgs*0x10];
        }
};
struct ImgMetaEntry {
    // idk_load_img_meta_entry?FUN_0062efc8
        le PixelData *data: u32;
        le u16 width;
        le u16 height;
        le u32 idk1;
        le u32 idk2;
};
struct ImgMeta {
    // idk_load_image_meta?FUN_0062f100
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString type;

        le u32 num_entries;

        // idk_load_img_meta_entry?FUN_0062efc8 called in a loop
            ImgMetaEntry entries[num_entries];

        u8 idk1;
};

struct ImgSubFile {
    // idk_load_img_subfile?FUN_0062f298
        le ImgMeta *metadata: u32;
        le u16 idk1;
        le u16 idk2;
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString fname;
};

struct ImgSubFile2 {
    // idk_load_img_subfile2?FUN_0062f350
        le ImgMeta *metadata: u32;

        le u16 idk1;
        le u16 idk2;
        le u16 idk3;
        le u16 idk4;
        le u16 idk5;
        le u16 idk6;
        le u16 idk7;
        le u16 idk8;
        le u16 idk9;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString fname;

};

struct ImgSubFilePadded{
    // texturefactory_instantiate_FUN_0062f4a8 (last loop)
        le u32 class_id;
        if (class_id == 0) {
            // idk_load_img_subfile?FUN_0062f298
                ImgSubFile img_sub_file;
        } else if (class_id == 1) {
            // idk_load_img_subfile2?FUN_0062f350
                ImgSubFile2 img_sub_file2;
        } else {
            std::print(class_id);
            assert(false, "Invalid class id");
        }
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

union JointClass0Subclass3Ptr {
    le u32 nullptr;
    if (nullptr != 0) {
        le u32 *ptr: u32;
    }
} [[inline]];

struct JointClass0Subclass3Pair {
    le u32 idk1;
    le u32 idk2;
};

struct JointClass0Subclass3 {
    // idk_load_joint_class0_subclass3?FUN_0062cf58
        le u32 idk1;
        le u32 idk2;
        le u32 idk3_len;
        JointClass0Subclass3Ptr idk_ptr[idk3_len];
        le u32 idk4_len;
        JointClass0Subclass3Pair idk_pairs[idk4_len];
};

struct JointClass0 {
    // idk_load_joint_class0_thing?FUN_0062cd20
        le u32 sub_class_id;
        if (sub_class_id == 3) {
            // idk_load_joint_class0_subclass3?FUN_0062cf58
                JointClass0Subclass3 data;
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
    // rendernodeinterfacep_instantiate_FUN_0062c288
    le u32 class_id;
    if (class_id == 0) {
        // parse_joint_class_0_FUN_0062c500
            // PRIOR_TO_LOADING_SOMETHING_IMPORTANT 5x
                MaybeString maybe_name;
            // idk_load_joint_class0_things?FUN_0062c3f0
                le u32 joint_data_len;
                // idk_load_joint_class0_thing?FUN_0062cd20 called in a loop
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

struct idk_joint_name_thing_FUN_00632f28_data {
    // idk_joint_name_thing?FUN_00632f28 (first loop)
    // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
        MaybeString name1;
    // idk_joint_name?FUN_00633120
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name2;
};

struct idk_joint_name_thing_FUN_00632f28 {
    // idk_joint_name_thing?FUN_00632f28
        le u32 idk1_len;
        idk_joint_name_thing_FUN_00632f28_data data[idk1_len];
};

struct Joint3SubData {
    // load_joint3_data?FUN_00632ce8 (first loop)
    // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
        MaybeString name;
    // idk_joint_name_thing?FUN_00632f28
        idk_joint_name_thing_FUN_00632f28 data;

};

struct Joint3Data {
    // load_joint3_data?FUN_00632ce8
        le u32 data_len;
        Joint3SubData data[data_len];
};

union Joint3Ptr {
    le u32 nullptr;
    if (nullptr != 0) {
        le u32 *ptr: u32;
    }
} [[inline]];

struct Joint3 {
    // load_joint3_thing?FUN_0062de20
        le u32 ptrs_len;
        Joint3Ptr ptrs[ptrs_len];
        le u32 *ptr2: u32;
        // load_joint3_data?FUN_00632ce8
            Joint3Data data;

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
    // texturefactory_instantiate_FUN_0062f4a8
        // copy_file_base
            SubFile data;
        le u32 pixel_data_len [[format("as_hex")]];
        le u32 img_meta_len [[format("as_hex")]];
        le u32 img_subfile_len [[format("as_hex")]];
        // idk_load_pixel_data?FUN_0062ee20 called in a loop
            PixelData pixel_data[pixel_data_len];
        // idk_load_image_meta?FUN_0062f100 called in a loop
            ImgMeta img_meta[img_meta_len];
        ImgSubFilePadded img_sub_files[img_subfile_len];

};

struct idk_FUN_006280b0 {
    // idk?FUN_00627e58
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT 5x
            MaybeString mbs1;
            MaybeString mbs2;
            MaybeString mbs3;
            MaybeString mbs4;
            MaybeString mbs5;
        le u32 idk1;
        if (idk1 != 0) {
            assert(false, "Check idk?FUN_00627e58");
        }
};

struct idk_FUN_005d2450 {
    // idk?FUN_005d2450
        le u32 idk1_len;
        if (idk1_len != 0) {
            le u32 idk2[idk1_len];
        }
};

struct idk_FUN_00626a20 {
    // idk?FUN_00626a20
        le u32 idk1;
        // idk?FUN_005d2450
            idk_FUN_005d2450 idk2;
};

struct idk_FUN_00626a90 {
    // idk?FUN_00626a90
        le u32 idk1;
        le u32 idk2;
        le u32 idk3;
        // idk?FUN_005d2450
            idk_FUN_005d2450 idk4;
};

struct idk_music_FUN_0062ab70 {
    // idk_music?FUN_0062ab70
        le u8 idk01;
        le u8 idk02;
        le u8 idk03;
        le u8 idk04;

        le u16 idk05;
        le u16 idk06;
        le u16 idk07;
        le u16 idk08;

        le u32 idk09;
        le u32 idk10;
        le u32 idk11;
        le u32 idk12;
        le u32 idk13;
        le u32 idk14;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x11
        MaybeString mbs[11];


};

struct idk_particle_FUN_0062b7c0 {
    // idk_particle?FUN_0062b7c0
        le u32 idk1;
        le u16 idk2;
        le u16 idk3;
        le u64 idk4;
        le u64 idk5;
        le u64 idk6;
        le u8 idk7;
        le u8 idk8;
        le u32 idk9;
};

struct idk_particle_FUN_0062b908 {
    // idk_particle?FUN_0062b908
        le u16 idk1;
        le u32 idk2;
        le u32 idk3;
        le u16 idk4;
        le u32 idk5[3];
        // TODO: THIS IS PROBABLY NOT ALWAYS 1
        idk_particle_FUN_0062b7c0 idk6[1];
};

struct idk_particle_FUN_0062c708 {
    // idk_particle?FUN_0062c708
        // idk_particle?FUN_0062b908
            idk_particle_FUN_0062b908 idk1;

        le u32 idk2;

        // transform_FUN_0050dd68

        le u32 idk3;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name2;



};

struct idk_particles_FUN_0062b1d8_data {
    // idk_particles?FUN_0062b1d8 (first loop)
    // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
        MaybeString name;
    // idk_particle?FUN_0062c708
        idk_particle_FUN_0062c708 data;
};

struct idk_particle_thing_FUN_0062b3f0 {
    // idk_particle_thing?FUN_0062b3f0
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name2;
        le u32 idk01;
        le u32 idk02;

        le u8 idk03;

        le u8 idk04[0x10];

        le u32 idk05;
        le u32 idk06;
        le u32 idk07;
        le u32 idk08;
        le u32 idk09;
        le u32 idk10;
        le u32 idk11;
        le u32 idk12;

        le u8 idk13[0x10];
        le u8 idk14[0x10];
        le u8 idk15[0x10];

        le u32 idk16;
        le u32 idk17;
        le u32 idk18;
        le u32 idk19;
        le u32 idk20;
        le u32 idk21;

        le u16 idk22;
        le u16 idk23;

        le u8 idk24;
};

struct idk_FUN_0061e178 {
    // idk?FUN_0061e178
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name;
        le u32 idk1_len;
        le u32 idk2[idk1_len];
        le u32 idk3;
        le u32 idk4;

};

struct idk_FUN_0061e2f8 {
    // idk?FUN_0061e2f8
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name;
        le u32 idk1;
        // idk?FUN_0061e178 called in a loop
            idk_FUN_0061e178 idk2[idk1];

};

struct idk_FUN_0061e598 {
    // idk?FUN_0061e598
        le u32 idk1;
        if (idk1 != 0) {
            le u32 idk2;
        }
};

struct idk_FUN_0061e638 {
    // idk?FUN_0061e638
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name;
        le u32 idk1_len;
        // idk?FUN_0061e598 called in a loop
            idk_FUN_0061e598 idk2[idk1_len];

};

struct idk_FUN_0061e768 {
    // idk?FUN_0061e768
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name;
        le u32 idk1_len;
        // idk?FUN_0061e638 called in a loop
            idk_FUN_0061e638 idk2[idk1_len];


};


struct idk_FUN_0061f0d8 {
    // idk?FUN_0061f0d8
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x4
            MaybeString name1;
            MaybeString name2;
            MaybeString name3;
            MaybeString name4;

        le u32 idk1;

        // transform_FUN_0050dd68

        le u32 idk2;
        le u32 idk3;
        le u32 idk4;
};

struct idk_FUN_0061f1f0 {
    // idk?FUN_0061f1f0
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name;
        le u32 idk1_len;
        // idk?FUN_0061f0d8 called in a loop
            idk_FUN_0061f0d8 data[idk1_len];

};


struct idk_FUN_0061f850 {
    // idk?FUN_0061f850
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name;
        le u32 idk1_len;
        le u32 idk_data[idk1_len];
};

using trapdatabase_instantiater_FUN_00630e88;

struct idk_FUN_00631d00_data {
    // idk?FUN_00631d00 (first loop)
        le u8 idk_ptr_exists;
        if (idk_ptr_exists == 0) {
            trapdatabase_instantiater_FUN_00630e88 ptr_data;
        } else {
            le u32 *idk_ptr: u32;
        }

};

struct idk_FUN_00631d00 {
    // idk?FUN_00631d00
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name;
        le u32 idk1;
        le u32 idk2;
        le u32 idk3;
        idk_FUN_00631d00_data idk_data[idk3];

};

struct idk_FUN_00631e90 {
    // idk?FUN_00631e90
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;

        le u8 idk01;
        le u8 idk02;
        le u8 idk03;

        le u32 idk04;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name2;

        le u8 idk05;
        le u8 idk06;
        le u8 idk07;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name3;

        le u8 idk08;

        le u32 idk09;
        le u32 idk10;
        le u32 idk11;

};

struct idk_FUN_00632120 {
    // idk?FUN_00632120
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;

        le u32 idk1;
};

struct idk_FUN_006321b8 {
    // idk?FUN_006321b8
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;

        le u8 idk1;
};

struct idk_FUN_00632250 {
    // idk?FUN_00632250
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x2
            MaybeString name1;
            MaybeString name2;

};

struct idk_FUN_00632438 {
    // idk?FUN_00632438
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;
};

struct idk_FUN_006324a0 {
    // idk?FUN_006324a0
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;

        le u32 idk1;
        le u32 idk2;
};

struct idk_FUN_006325d0 {
    // idk?FUN_006325d0
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;

        le u32 idk1;
};

struct idk_FUN_00632668 {
    // idk?FUN_00632668
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
            MaybeString name1;

        le u32 idk1;
        le u32 idk2;
        le u32 idk3;

};

struct idk_FUN_00632760 {
    // idk?FUN_00632760
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x2
            MaybeString name1;
            MaybeString name2;

        le u8 idk1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x4
            MaybeString name3;
            MaybeString name4;
            MaybeString name5;
            MaybeString name6;
};

struct idk_FUN_00632890 {
    // idk?FUN_00632890
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x2
            MaybeString name1;
            MaybeString name2;
};

struct idk_FUN_00632ae0 {
    // idk?FUN_00632ae0
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x2
            MaybeString name1;
            MaybeString name2;

        le u32 idk1;
};

struct idk_FUN_00632b98 {
    // idk?FUN_00632b98
        // idk?FUN_00631d00
            idk_FUN_00631d00 data1;

        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x2
            MaybeString name1;
            MaybeString name2;

        le u32 idk1;
};


struct trapdatabase_instantiater_FUN_00630e88 {
    // trapdatabase_instantiater?FUN_00630e88
        le u32 class_id;
        if (class_id == 0) {
            // idk?FUN_00631e90
                idk_FUN_00631e90 data0;
        } else if (class_id == 1) {
            // idk?FUN_00632120
                idk_FUN_00632120 data1;
        } else if (class_id == 2) {
            // idk?FUN_006321b8
                idk_FUN_006321b8 data2;
        } else if (class_id == 3) {
            // idk?FUN_00632250
                idk_FUN_00632250 data3;

        } else if (class_id == 6) {
            // idk?FUN_00632438
                idk_FUN_00632438 data6;
        } else if (class_id == 7) {
            // idk?FUN_006324a0
                idk_FUN_006324a0 data7;
        } else if (class_id == 9) {
            // idk?FUN_006325d0
                idk_FUN_006325d0 data9;
        } else if (class_id == 10) { // 0xa
            // idk?FUN_00632668
                idk_FUN_00632668 data10;
        } else if (class_id == 11) { // 0xb
            // idk?FUN_00632760
                idk_FUN_00632760 data11;
        } else if (class_id == 12) { // 0xc
            // idk?FUN_00632890
                idk_FUN_00632890 data12;
        } else if (class_id == 16) { // 0x10
            // idk?FUN_00632ae0
                idk_FUN_00632ae0 data16;
        } else if (class_id == 17) { // 0x11
            // idk?FUN_00632b98
                idk_FUN_00632b98 data17;
        } else {
            std::print(class_id);
            assert(false, "Invalid class ID");
        }
};

struct idk_FUN_00620120_data {
    // idk?FUN_00620120 (first loop)
        le u8 idk_ptr_exists;
        if (idk_ptr_exists == 0) {
            // trapdatabase_instantiater?FUN_00630e88
                trapdatabase_instantiater_FUN_00630e88 data;

        } else {
            le u32 idk1;
        }
};

struct idk_joints_FUN_0062ba50_data {
    // idk_joints?FUN_0062ba50 (first loop)
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x2
            MaybeString joint1;
            MaybeString joint2;
};

struct idk_joints_FUN_0062ba50 {
    // idk_joints?FUN_0062ba50
        le u32 idk_len;
        idk_joints_FUN_0062ba50_data data[idk_len];
};

struct idk_FUN_0062d8f8 {
    // idk?FUN_0062d8f8
        // PRIOR_TO_LOADING_SOMETHING_IMPORTANT x2
            MaybeString name;

        le u32 idk01;

        le u16 idk02;
        le u16 idk03;
        le u16 idk04;
        le u16 idk05;
        le u16 idk06;
        le u16 idk07;
        le u16 idk08;
        le u16 idk09;
        le u16 idk10;
        le u16 idk11;
        le u16 idk12;
        le u16 idk13;
        le u16 idk14;

        le u32 idk15;
};

struct File {
// DO_A_LOT_OF_STUFF_WITH_OFFSETS
    // copy_file_base
        SubFile data1;


    // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
        MaybeString idk_maybe_string;

    // renderdata_instantiate_FUN_0062bc80
        // copy_file_base
            SubFile renderdata;
        // texturefactory_instantiate_FUN_0062f4a8
            TextureFactory texturefactory;
        le u32 idk_res_len [[format("as_hex")]];
        IdkResource idk_resources[idk_res_len];
        // parse_joints?
            le u32 joints_len;
            Joint joints[joints_len];
        le u32 idk2_len [[format("as_hex")]];
        Idk2 idk2s[idk2_len];
        le u32 joints2_len [[format("as_hex")]];
        // rendernodeinterfacep_instantiate_FUN_0062c288 called in a loop
            Joint2 joints2[joints2_len];
        // idk_joints?FUN_0062ba50
            idk_joints_FUN_0062ba50 idk_joints;
        le u32 maybe_ptr1;

    // load_joint3_things?FUN_0062df88
        le u32 joints3_len [[format("as_hex")]];
        // load_joint3_thing?FUN_0062de20 called in a loop
            Joint3 joints3[joints3_len];

    // EVENTUALLY_EVENTUALLY_DO_SMTH_WITH_STRING
        le u32 num_strs;
        EncodedString strings[num_strs];

    // parse_joint_anim_data?
        le u32 joint_motion_len [[format("as_hex")]];
        JointMotion joint_motions[joint_motion_len];

    // idk?FUN_0062dbb0
        le u32 idk4_len;
        // idk?FUN_0062d8f8 called in a loop
            idk_FUN_0062d8f8 idk4_data[idk4_len];

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

    // idk_particles?FUN_0062b1d8
        // copy_file_base
            SubFile data2;
        // texturefactory_instantiate_FUN_0062f4a8
            TextureFactory texturefactory2;
        le u32 idk6_len;
        idk_particles_FUN_0062b1d8_data data[idk6_len];

    // idk?FUN_0062b690
        le u32 idk7_len;
        // idk_particle_thing?FUN_0062b3f0 called in a loop
            idk_particle_thing_FUN_0062b3f0 idk7_data[idk7_len];

    // idk?FUN_0062e160
        le u32 idk8_len;
        if (idk8_len != 0) {
            assert(false, "Check idk?FUN_0062e160");
        }

    // idk?FUN_0061e450
        le u32 idk9_len;
        // idk?FUN_0061e2f8 called in a loop
            idk_FUN_0061e2f8 idk9_data[idk9_len];

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
        // idk?FUN_0061e768 called in a loop
            idk_FUN_0061e768 idk15_data[idk15_len];

    // idk?FUN_0061f348
        le u32 idk16_len;
        // idk?FUN_0061f1f0 called in a loop
            idk_FUN_0061f1f0 idk16_data[idk16_len];

    // idk?FUN_0061f990
        le u32 idk17_len;
        // idk?FUN_0061f850 called in a loop
            idk_FUN_0061f850 idk17_data[idk17_len];

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

    // load_font_resource_array?FUN_0061fca8
        le u32 idk30_res_len;
        TextureFile texture_files[idk30_res_len];

    // idk?FUN_0062afa8
        le u32 idk31;
        if (idk31 != 0) {
            assert(false, "Check idk?FUN_0062afa8");
        }

    // idk?FUN_00622278
        le u32 idk32;
        if (idk32 != 0) {
            assert(false, "Check idk?FUN_00622278");
        }

    // idk?FUN_00627538
        le u32 idk33;
        if (idk33 != 0) {
            assert(false, "Check idk?FUN_00627538");
        }

    // idk?FUN_006280b0
        le u32 idk34_len;
        // idk?FUN_00627e58 called in loop
        idk_FUN_006280b0 idk35[idk34_len];

    // idk_data_inspector?FUN_00621b80
        le u32 tnum;
        if (tnum != 0) {
            assert(false, "Check idk_data_inspector?FUN_00621b80");
        }

    // idk?FUN_00628988
        le u32 idk36;
        if (idk36 != 0) {
            assert(false, "Check idk?FUN_00628988");
        }
        le u32 idk37;
        if (idk37 != 0) {
            assert(false, "Check idk?FUN_00628988");
        }

    // idk?FUN_0061fd68
        le u32 idk38;
        if (idk38 != 0) {
            assert(false, "Check idk?FUN_0061fd68");
        }

    // idk?FUN_00620120
        le u32 idk39_len;
        idk_FUN_00620120_data idk39_data[idk39_len];

    // idk?FUN_006256f0
        le u32 idk40;
        if (idk40 != 0) {
            assert(false, "Check idk?FUN_006256f0");
        }

    // idk?FUN_006259c8
        le u32 idk41;
        if (idk41 != 0) {
            assert(false, "Check idk?FUN_006259c8");
        }

    // idk?FUN_00625ca0
        le u32 idk42;
        if (idk42 != 0) {
            assert(false, "Check idk?FUN_00625ca0");
        }

    // idk?FUN_00625f80
        le u32 idk43;
        if (idk43 != 0) {
            assert(false, "Check idk?FUN_00625f80");
        }

    // idk?FUN_00626298
        le u32 idk44;
        if (idk44 != 0) {
            assert(false, "Check idk?FUN_00626298");
        }

    // idk?FUN_006266a8
        le u32 idk45;
        if (idk45 != 0) {
            assert(false, "Check idk?FUN_006266a8");
        }

    // idk?FUN_00627a08
        le u32 idk46;
        if (idk46 != 0) {
            assert(false, "Check idk?FUN_00627a08");
        }

    // idk?FUN_00624bb8
        le u32 idk47;
        if (idk47 != 0) {
            assert(false, "Check idk?FUN_00624bb8");
        }
        le u32 idk48;
        if (idk48 != 0) {
            assert(false, "Check idk?FUN_00624bb8");
        }
        le u32 idk49;
        if (idk49 != 0) {
            assert(false, "Check idk?FUN_00624bb8");
        }

    // idk?FUN_0062a570
        // idk?FUN_0062a130
            // PRIOR_TO_LOADING_SOMETHING_IMPORTANT
                MaybeString idk_mbs1;
            le u32 idk50;
            if (idk50 != 0) {
                assert(false, "Check idk?FUN_0062a130");
            }
            le u32 idk51;
            if (idk51 != 0) {
                assert(false, "Check idk?FUN_0062a130");
            }
            le u32 idk52;
            le u32 idk53;
            // idk?FUN_005d2450
                idk_FUN_005d2450 idk54;

    // idk?FUN_00626b30
        le u32 idk55_len;
        // idk?FUN_00626a20 called in a loop
            idk_FUN_00626a20 idk56[idk55_len];
        le u32 idk57_len;
        // idk?FUN_00626a90 called in a loop
            idk_FUN_00626a90 idk58[idk57_len];
        le u32 idk59;

    // idk?FUN_0062a908
        le u32 idk60;
        if (idk60 != 0) {
            assert(false, "Check idk?FUN_0062a908");
        }

    // idk?FUN_00620298
        le u32 idk61_fsize;
        // copy_to_buffer
            le u8 idk_phz_collision_file[idk61_fsize];

    // idk?FUN_00620440
        le u32 idk62;
        if (idk62 != 0) {
            assert(false, "Check idk?FUN_00620440");
        }

    // idk?FUN_0061ff50
        le u32 idk63;
        if (idk63 != 0) {
            assert(false, "Check idk?FUN_0061ff50");
        }

    // idk?FUN_00621f70
        le u32 idk64;
        if (idk64 != 0) {
            assert(false, "Check idk?FUN_00621f70");
        }
        // idk?FUN_006268c0
            le u32 idk65;
            if (idk65 != 0) {
                assert(false, "Check idk?FUN_006268c0");
            }

    // idk?FUN_00625318
        le u32 idk66;
        if (idk66 != 0) {
            assert(false, "Check idk?FUN_00625318");
        }

    // idk?FUN_00620968
        le u32 idk67;
        le u32 idk_load_masterarray;
        if (idk_load_masterarray != 0) {
            assert(false, "Check idk?FUN_00620968");
        }
        le u32 idk68;
        if (idk68 != 0) {
            le u32 idk69;
            // transform_FUN_0050dd68
        }

    // idk?FUN_00620ad8
        le u8 idk70;
        if (idk70 != 0) {
            // idk_music?FUN_0062ab70
            idk_music_FUN_0062ab70 idk_music;
        }

    // idk?FUN_00623f68
        le u32 idk71;
        if (idk71 != 0) {
            assert(false, "Check idk?FUN_00623f68");
        }

    // idk?FUN_00623598
        // idk?FUN_006225b8
            le u32 idk72;
            if (idk72 != 0) {
                assert(false, "Check idk?FUN_006225b8");
            }
        // idk?FUN_00622790
            // idk?FUN_005d2450
                idk_FUN_005d2450 idk73;
        // idk?FUN_00622840
            le u32 idk74;
            if (idk74 != 0) {
                assert(false, "Check idk?FUN_00622840");
            }
        // idk?FUN_00622a80
            // idk?FUN_005d2450
                idk_FUN_005d2450 idk75;
        // idk?FUN_00622d48
            le u32 idk76;
            if (idk76 != 0) {
                assert(false, "Check idk?FUN_00622d48");
            }
        // idk?FUN_00623020
            le u32 idk77;
            if (idk77 != 0) {
                assert(false, "Check idk?FUN_00623020");
            }
        // idk?FUN_00623360
            le u32 idk78;
            if (idk78 != 0) {
                assert(false, "Check idk?FUN_00623360");
            }

    // idk?FUN_00621a20
        le u8 idk79;
        if (idk79 != 0) {
            assert(false, "Check idk?FUN_00621a20");
        }

    // idk?FUN_006243f8
        le u32 idk80;
        if (idk80 != 0) {
            assert(false, "Check idk?FUN_006243f8");
        }

    // idk?FUN_00628f28
        le u32 idk81;
        if (idk81 != 0) {
            assert(false, "Check idk?FUN_00628f28");
        }

    // idk?FUN_00620d80
        le u8 idk82;
        if (idk82 != 0) {
            assert(false, "Check idk?FUN_00620d80");
        }
        le u8 idk82_2;
        if (idk82_2 != 0) {
            assert(false, "Check idk?FUN_00620d80");
        }

    // idk?FUN_00620e60
        le u8 idk83;
        if (idk83 != 0) {
            assert(false, "Check idk?FUN_00620e60");
        }

    // idk_camera?FUN_00620f50
        le u8 idk84;
        if (idk84 != 0) {
            assert(false, "Check idk_camera?FUN_00620f50");
        }

    // idk?FUN_006211d0
        le u32 idk85;
        if (idk85 != 0) {
            assert(false, "Check idk?FUN_006211d0");
        }

    // idk?FUN_00621600
        le u32 idk86;
        if (idk86 != 0) {
            assert(false, "Check idk?FUN_00621600");
        }

    // idk?FUN_00621808
        le u32 idk87;
        if (idk87 != 0) {
            assert(false, "Check idk?FUN_00621808");
        }

    // idk?FUN_00629758
        le u32 idk88;
        if (idk88 != 0) {
            assert(false, "Check idk?FUN_00629758");
        }

    // idk?FUN_00621ab0
        le u8 idk89;
        if (idk89 != 0) {
            assert(false, "Check idk?FUN_00621ab0");
        }
};