# Sarugetchu Million Monkeys Patcher

This repo contains code to patch the Japanese release of Sarugetchu Million Monkeys for English readers.

## Status

This translation is functionally 100% complete, but has not been thoroughly tested.

## Usage

Ensure the iso you have is:
- named `mm.iso`
- matches the md5 `946d0aeb90772efd9105b0f785b2c7ec`

### Windows

See [here](win/README.md)

### Linux/WSL

> macOS might work too, but I've never tried

1. Install [nix](https://nixos.org/download/) and [enable flakes](https://nixos.wiki/wiki/flakes#Other_Distros.2C_without_Home-Manager)
2. Put the source `.iso` into the nix store with `nix-store --add-fixed sha256 mm.iso`
3. Clone this repo
    - Ensure Git LFS is enabled
4. Build the patched `.iso` with `nix build .#iso-patched`
    - The patched file will be in the nix store at `result/iso/mm_patched.iso`, copy it into your local filesystem for use with an emulator, burn to disk, etc.
    - If using a recent version of nix you should be able to directly build the repo without cloning with `nix build --refresh 'git+https://github.com/Gigahawk/sarugetchu_mm_patcher.git?lfs=1#iso-patched'`
    - This will take absolutely forever, see [Design Issues](#getting-started)

### Emulation Settings

While this project aims to make the game playable at the PS2's native resolution, it's recommended to emulate the game at a higher resolution to get cleaner text rendering.

# Contributing

## Documentation

Preliminary work on translating the official guide book is happening in [doc](doc)
> If you have a scanned copy of the guide book/would be willing to help translate it please get in touch

## Struct Documentation

ImHex pattern files defining game structs are in [imhex_patterns](imhex_patterns)

## Testing

If you find issues (game crashes, untranslated text, garbage text, etc.) please open an issue with screenshots/steps to reproduce.
> Note: do not submit savestates, they are not compatible between different versions of the patch. Please submit PCSX2 compatible memory cards if the issue requires some progress to recreate.

## Cutscenes

See [subs](subs), these are just standard `.ass` and `.srt` files that can be edited in any standard editor

## Text

Basically every string in the game should have a valid translation in [strings.yaml](strings.yaml).
I've tried to make sure that all of the ones you will most likely see during gameplay are good, but a lot of the lines at the bottom are AI generated with very little oversight.

## Textures

Some minimal translation of existing textures has been done.
Textures must be in the `.aseprite` format, you can run `nix build .#data-textures-extracted` to dump all textures from the game, or `.#data-fonts-extracted` for the font textures.
Open an issue if there is a specific texture you want to edit and can't figure out how to extract it.

# Licensing

> Disclaimer: This project is an unofficial fan translation patcher.
> This project contains only original code and translation data.
> It is not affiliated with or endorsed by Sony or the original developers.
> No copyrighted game data is included or distributed.
> Users must provide their own legally obtained copy of the game.

- All original code in this repository is licensed under GPL 3.0 (see LICENSE).
    - [PS2Textures](https://github.com/leeao/PS2Textures) was written by [leeao](https://github.com/leeao)
- The translation file is licensed under CC-BY-SA 4.0 (see LICENSE_strings)
- Custom texture and subtitle files are licensed under CC-BY-SA 4.0 (see `textures/LICENSE_textures` and `subs/LICENSE_subs` respectively)


# FAQ

## Why not just provide a `.ups` patch file?

I'm not a lawyer, but I want to minimize the risk of distributing IP that I do not have the rights to.

# Appendix

## Design Issues

In hindsight I made a lot of bad design decisions throughout the development process, including but not limited to
- Using nix to handle build dependencies in theory allows for really fast build cycles; only packages with changes get rebuilt. But by writing nearly every custom tool from extraction to patching and repacking in the same package, any change to the tool results in a nearly from scratch rebuild of the entire project, which takes forever
- Using Imhex seemed really convenient at first, but being limited to just dumping the entire analysis as a `.json` is really unfortunate, generating these files takes up most of the build time. Katai probably would have been a better choice, especially since they apparently directly support reserialization now.
- Using nix means no native Windows support, and the provided VM workaround is unbelievably cursed
- The Chinese release would have had some benefits for patching, but can't replace the Japanese one entirely and it doesn't seem worth it to require both copies
    - The English characters look nicer in the Chinese release
    - The Chinese release contains a `CO00.PSS` without the Japanese subtitles, so it would have been better looking to sub that version

## Play Through

I have been doing a playthrough of the game as the translation has developed.

### Episode Kakeru

https://www.youtube.com/playlist?list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka

0. https://www.youtube.com/watch?v=nkVN55UtkYA&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=1
    - 1st Tokyo Teleport level
    - Cutscene: ST00K, Japanese subtitles
1. https://www.youtube.com/watch?v=62uarj5kDWA&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=2
    - Text width reduced for better English rendering
    - File select menu
    - Character edit menu
    - VS. Mode
    - Options
    - Loadout select
    - VS Mode result
    - 1st Tokyo Teleport level again (with English cutscene subtitles)
2. https://www.youtube.com/watch?v=V8f7AuBwIV0&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=3
    - 1st Shinjuku level
3. https://www.youtube.com/watch?v=tRtm5_9MOz4&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=4
    - 1st Akihabara level
    - Cutscene: ST01
4. https://www.youtube.com/watch?v=wFtZcO1o-10&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=5
    - Texture patching demo (`Press START Button`)
    - 1st Metro level
5. https://www.youtube.com/watch?v=kczVU501pik&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=6
    - 1st Tokyo level
6. https://www.youtube.com/watch?v=_lxjCUQ1lIc&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=7
    - 1st Container Terminal level
    - `CATCH POINTS` and `COMBO CATCH` textures patched
7. https://www.youtube.com/watch?v=N9njty7Jo7c&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=8
    - 1st Industrial Complex level
    - Cutscene: ST02
8. https://www.youtube.com/watch?v=t7qTcOoUyYo&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=9
    - 1st Yacht Harbor level
9. https://www.youtube.com/watch?v=hk_xXk2y_bg&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=10
    - Intro cutscenes subbed (ADxx)
    - 1st Stadium level
    - `CATCH` banner texture patched
10. https://www.youtube.com/watch?v=-j_cxkmtS6g&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=11
    - Character edit menu
        - Chip lab
    - 2nd Stadium level
11. https://www.youtube.com/watch?v=iYZZixDajiQ&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=12
    - Teleporter Room level
    - Invincibility patch
12. https://www.youtube.com/watch?v=ck8f74kn8yU&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=13
    - Equipment Hangar level
    - G-Hangar level
    - Cargo Elevator level
13. https://www.youtube.com/watch?v=tpvLXWiq8Xg&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=14
    - 1st Bridge level
    - Cutscene: ST04K, ST05K
14. https://www.youtube.com/watch?v=7s2WsYs83ME&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=15
    - 2nd Bridge level
    - Cutscene: ST06
15. https://www.youtube.com/watch?v=Sh-UmprxqjI&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=16
    - V.R. Space 01 level
    - Cutscene: ST07K
    - V.R. Space 02 level
    - V.R. Space 03 level
    - V.R. Space 04 level
    - Cutscene: ST09K
    - Per cutscene subtitle styling
16. https://www.youtube.com/watch?v=X5Tqyause6Q&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=17
    - 2nd Stadium level
    - 2nd Yacht Harbor level
    - 2nd Industrial Complex level
    - Cutscene: ST10K
17. https://www.youtube.com/watch?v=MavvGpOq53w&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=18
    - 2nd Container Terminal level
    - Cutscene: ST11K
    - 2nd Tokyo level
    - 2nd Metro level
    - 2nd Akihabara level
18. https://www.youtube.com/watch?v=zbYwchsWgas&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=19
    - 2nd Shinjuku level
    - Cutscene: ST12
    - 2nd Tokyo Teleport level
    - Odaiba level
19. https://www.youtube.com/watch?v=aT6QqEOCO2E&list=PLO1x50nsk5Ve35ubyChvh9KaQ5zIijaka&index=20
    - Crash Site level
    - Cutscene: LAST
    - Cutscene: ST13 (no subtitles)
    - Credits (untranslated)

### Colosseum

20. https://www.youtube.com/watch?v=vKp4OzyF390
    - Colosseum cutscenes
    - Most Japanese text textures patched
    - Colosseum victory screen
    - Credits

### Episode Specter

https://www.youtube.com/playlist?list=PLO1x50nsk5Ve1f4e1qOFWp_3Axgr0oYPH

21. https://www.youtube.com/watch?v=2IUCe0wZihA&list=PLO1x50nsk5Ve1f4e1qOFWp_3Axgr0oYPH&index=1
    - Chip Synthesis for Specter
    - 1st Tokyo Teleport level
    - Cutscene: ST00S
    - 1st Shinjuku level
    - 1st Akihabara level
    - Cutscene: ST01

## Old Notes

Some old notes taken during development

### 60 FPS

Originally discovered by Crash https://www.youtube.com/watch?v=jSNfejSktSQ

Default (unpatched) FPS

- VS Mode:
    - Colosseum (`50_k1`): 60
    - Metro (`52_metro`): 30
    - Warehouse District (`53_bay`): 30
    - Training Room (`54_UFO`): 30
    - Yacht Harbor (`55_park`): 30
    - Gulf Coast (`56_daiba`): 30
    - V.R. Space (`58_UFO2`): 30
- Story Mode:
    - Tokyo Teleport (`01_boss01_gori01`): 30
    - Shinjuku (`02_city01_a`): 30
    - Akihabara (`03_city02_a`): 30
    - Metro (`04_metro01_a`): 30
    - Tokyo (`05_boss02_boss`): 30
    - Container Terminal (`06_bay01_a`): 30
    - Industrial Complex (`07_bay02_a`): 30
    - Yacht Harbor (`08_park01_a`): 30
    - Stadium (`09_stadium_a`): 30
    - Stadium (`10_boss03_fly`): 30
    - Teleporter Room (`11_hangar01_a`): 30
    - Equipment Hangar (`12_hangar02_a`): 30
    - G-Hangar (`13_boss04_gori02`): 30
    - Cargo Elevator (`14_elevator_a`): 30
    - Bridge (`15_kakeru_spector`): 30
    - Bridge (`16_kakeru_goritron`): 30
    - V.R. Space 01 (`17_city01_vr`): 30
    - V.R. Space 02 (`18_bay01_vr`): 30
    - V.R. Space 03 (`19_park01_vr`): 30
    - V.R. Space 04 (`20_boss07_grid`): 30
    - Stadium (`21_stadium_b`): 30
    - Yacht Harbor (`22_park01_b`): 30
    - Industrial Complex (`23_bay02_b`): 30
    - Container Terminal (`24_bay01_b`): 30
    - Tokyo (`25_boss08_boss`): 30
    - Metro (`26_metro01_b`): 30
    - Akihabara (`27_city02_b`): 30
    - Shinjuku (`28_city01_b`): 30
    - Tokyo Teleport (`29_boss09_boss`): 30
    - Odaiba (`30_daiba02_b`): 30
    - Crash Site (`31_boss10_boss`): 30


### Credits

#### Params Storage
Credits params appear to be stored in strings?
Best guess at order:

white text R int 128
white text G int 128
white text B int 128

indent width? float 300.0

font height? float 18.0

idk int 10

yellow text B int 64
yellow text G int 128
yellow text R int 128

idk int 10

idk float 2.0

string "credit_s"

idk float 2.0

yellow text B int 64
yellow text G int 128
yellow text R int 128

idk int 10

string "credit_k"

idk int 10

string "credit_c"

idk float 2.0

idk float 300.0

probably tab width int 27

probably tab width int 54

idk float 0.5

idk int 10

#### Params from debugger

From colosseum credit load (floats return to FPR f00 register)

- credit.caption_b/g/r: yellow text
- credit.post_b/g/r: yellow text
- credit.text_b/g/r: white text
- credit.%s.image_num: 10
- credit.indent_post: 27
- credit.indent_text: 54
- credit.font_height: 18.0
- credit.line_space: 0.5
- credit.scroll_time: 300.0
- credit.bg_total_time: 300.0


### Damage

When damage is applied, `do_damage?FUN_00154a60` gets called

- a0 seems to be a pointer to the target being damaged?
- a1 is not constant? seems to be a pointer to the object causing the damage

HP is read at 00154ca4, then if it's zero `idk_trigger_death?FUN_00161b90` is called.
Stubbing this function out results in regular entities being unable to die.
Mounts and bosses still appear to die.
There is another function that doesn't seem to be called `idk_trigger_death?FUN_003f3758` forcing this to be called seems to cause HP to drop to zero for the target.


### HP Info

- `FUN_003f3798` returns the current HP for the passed in character (entity?)
    - The first arg is a pointer, if you subtract 0xB0 from this pointer you get the player ID i think?
    - it can be called by:
        - `idk_hp_bar_thing?FUN_00291a90`
        - `idk_not_check_death?FUN_003babc0`
        - `idk_some_hp_thing?FUN_001662c0`
        - `idk_some_hp_thing?FUN_0039d478`
        - `idk_bot_shell_hp_thing?FUN_0039db58`
        - `idk_maybe_check_death?FUN_00394700`
        - `idk_bot_parent_hp_thing?FUN_003979a8`
        - `idk_bot_parent_hp_thing?FUN_003990b0`

### Differences between Japanese and Chinese version

- Videos are different, mostly subtitled
- Code is different, appears to be a newer revision or something?
- All of DATA2 and DATA3 are identical, likely these contain 3d models etc. that don't change with language
- A lot of DATA0 and DATA1 is different, likely these are things that contain text/images of text
    - Some files are identical:
        - `00ff15d2`: probably an unused `stage.51_XXX_bd.gz`
        - `1fa8a5bf`: `package/mod310.tar.gz`
        - `57ff733f`: no clue, maybe stage 59 bd?
        - `63f4d7b2`: probably an unused `stage.57_XXX_bd.gz`
        - `9560bc50`: `gz/stage.55_park_bd.gz`
        - `b0ffcadb`: `system.gz`
        - `b3534589`: no clue, probably a story related stage (non bd, maybe unused?)
    - Some files are only present in the japanese version:
        - `9315b91a`: no clue,
        - `70dbb91a`: no clue, immediately follows `9315b91a`

### Index
PDATA/DATA0.BIN and DATA2.BIN appear to be some kind of index file describing the contents of the bigger DATA1.BIN and DATA3.BIN respectively

Each entry is 12 bytes long, and denotes a file entry

The first 4 bytes are a CRC-like hash of the filename of the file entry (see the gen_crc command for implementation).
See below for known hashes

The middle 4 bytes are the offset into the big data file (DATA0 is the index for DATA1)
Multiply this value by 2048 bytes to get the start of each entry

The last 4 bytes are the size of the file in bytes.

### Known hashes

See `dataX_hashes.csv`

To update this:
1. compile and enable the patches in the `debug-patches` folder
1. play the game in pcsx2 until you load the menu/file you're looking for
    - ensure the log window is open
1. save the log file
1. run `cat <logfile> | dos2unix | grep -E '\.gz$' | uniq | ssmm-patcher update-hash-list data0_hashes.csv`

### DATA1
Each file in DATA1 is a gzip compressed file with file names like `gz/xxx.gz`.


The beginning of each file appears to have a header of some sort

- 1 byte: file type??? (seems to always be 1)
- 4 bytes: buff_size (appears to be the length of the header/main content?)
    - If we jump to the end of the buff there is sometimes a string containing part of the file name?

Nearish the end of each file there appear to be file names preceded by pointers or something?

The code makes reference to a bunch of `tar/xxx.tar.gz` files with similar file names to their `gz/` counterparts, but these files do not appear to be anywhere in the game data other than the ps2 library files `package/mod310.tar.gz`.
They are likely in older/debug versions of the game?

### File Structure

Many files are loaded by a function at `0x0061d340` (currently dubbed `DO_A_LOT_OF_STUFF_WITH_OFFSETS` in the decomp).
When this function is called, the file to be loaded should be logged to serial (if debug logging patch has been enabled), and the file should have been loaded to `0x0076CC00` in memory.
The first parameter (register `a0`) contains a pointer to a struct.
The first 4 bytes of the struct is just a pointer to the start of the data (should be `0x0076CC00`).
The next 4 bytes is a seek pointer into the data, when the function is first called this should be identical to the start pointer.

### Strings
Some files contain strings, this game uses a custom 2 byte text encoding (probably) between 0x889F to 0x95FF inclusive.
> many strings appear in multiple files, but it seems that most (all?) appear in `00940549/menu_common`, and so far only patching that file seems to be sufficient for the menus, there may be significant performance uplifts in patching speed by limiting the number of files we try to patch.

> It seems like patching a string with increased file size causes gameplay to not load (menus are fine), likely some offset gets moved that causes a crash
> EDIT: there's a `menu_common/icon.bimg` entry in the `menu_common` file  that contains an 0x001A4A29 that needs to be patched to point to the same place after the file size changes

> there appear to be duplicates in the encoding table, need to check whether these duplicates are ever used anywhere, significant performance uplifts are possible by removing unused ones from our encoding table, or otherwise providing a mechanism to specify which encoding to use on a per string basis
> EDIT: these are likely not valid, they don't appear to be used anywhere, likely these indices are not used and some random glyphs get shown


Strings appear to be terminated with a single null byte
Furigana is supported, with single byte 0x5B being used to indicate the start and 0x5D used to indicate the end

There is an 8 byte long structure prior to the start of the string, the first 4 bytes appear to be some monotonically increasing index or ID, for some reason it seems to increase by 0x61 every time.
The second 4 bytes are the length of the string in bytes, not including the null byte (this is probably used by the code to allocate space to render the text onscreen, setting the string to something longer without updating this value causes the game to not start)

#### Files Known to Contain Strings

- `game_result.story`
- `game_result.vs`
- `menu_common`
- `menu_story.xxx`
- `menu_vs`
- `stage.01_boss01_gori01`
- `stage.02_city01_a`
- `stage.03_city02_a`
- `stage.04_metro01_a`
- `stage.05_boss02_boss`
- `stage.06_bay01_a`
- `stage.07_bay02_a`
- `stage.08_park01_a`
- `stage.09_stadium_a`
- `stage.10_boss03_fly`
- `stage.11_hangar01_a`
- `stage.12_hangar02_a`
- `stage.13_boss04_gori02`
- `stage.14_elevator_a`
- `stage.15_kakeru_spector`
- `stage.50_k1`
- `stage.51_city`
- `stage.52_metro`
- `stage.53_bay`
- `stage.54_UFO`
- `stage.55_park`
- `stage.56_daiba`
- `stage.57_k1death`
- `stage.58_UFO2`
- `stage.60_k1`
- `stage.60_k1death`
- `victory.xxx`







### Encodings

It turns out this game uses a bunch of unique nonstandard text encodings.
Most of them use the same/very similar ones, but some use ones that are completely different (such as the pause menu)

It's possible that the headers of some of the files stores which encoding to use, but for now I'm just manually deriving them.

#### Kanji

There's a lot of kanji, quite hard to figure out the encodings for all of them.
It appears the each row in the kanji keyboard is actually stored inside DATA1 in order, best to update the encoding list one row at a time.

There appear to be some kanji not available through the keyboard?
Maybe the devs just got lazy and didn't feel like organizing them all

## PSS Cutscenes

Cutscenes are stored inside the `RAW/MPEG`.
They use Sony's weird proprietary extensions to MPEG2 and need to be demuxed properly.
There is currently a demuxer written python under `mux.py` but it is unbearably slow and will probably have to be rewritten in C or something to get something usable.

> We're using ssmm-demux to demux and ps2str to remux

## Level Sequence

### Episode Kakeru

01. Cutscene: `ST00K`
02. `01_boss01_gori01`
03. `02_city01_a`
04. `03_city02_a`
05. Cutscene: `ST01`
06. `04_metro01_a`
07. `05_boss02_boss`
08. `06_bay01_a`
09. `07_bay02_a`
10. Cutscene: `ST02`
11. `08_park01_a`
12. `09_stadium_a`


## Known issues