# Notes

# Building with nix

Ensure the iso you have is:
    - named `mm.iso`
    - matches the md5 `946d0aeb90772efd9105b0f785b2c7ec`

Then run `nix-store --add-fixed sha256 mm.iso`

## Differences between Japanese and Chinese version

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



## Index
PDATA/DATA0.BIN and DATA2.BIN appear to be some kind of index file describing the contents of the bigger DATA1.BIN and DATA3.BIN respectively

Each entry is 12 bytes long, and denotes a file entry

The first 4 bytes are a CRC-like hash of the filename of the file entry (see the gen_crc command for implementation).
See below for known hashes

The middle 4 bytes are the offset into the big data file (DATA0 is the index for DATA1)
Multiply this value by 2048 bytes to get the start of each entry

The last 4 bytes are the size of the file in bytes.

### Known hashes

See `data0_hashes.csv`

To update this:
1. compile and enable the patches in the `debug-patches` folder
1. play the game in pcsx2 until you load the menu/file you're looking for
    - ensure the log window is open
1. save the log file
1. run `cat <logfile> | dos2unix | grep -E '\.gz$' | uniq | ssmm-patcher update-hash-list data0_hashes.csv`

## DATA1
Each file in DATA1 is a gzip compressed file with file names like `gz/xxx.gz`.


The beginning of each file appears to have a header of some sort

- 1 byte: file type??? (seems to always be 1)
- 4 bytes: buff_size (appears to be the length of the header/main content?)
    - If we jump to the end of the buff there is sometimes a string containing part of the file name?

Nearish the end of each file there appear to be file names preceded by pointers or something?

The code makes reference to a bunch of `tar/xxx.tar.gz` files with similar file names to their `gz/` counterparts, but these files do not appear to be anywhere in the game data other than the ps2 library files `package/mod310.tar.gz`.
They are likely in older/debug versions of the game?

### File Structure

Many files are loaded by a function at `0x0061d340` (currently dubbed `DO_A_LOT_OF_STUFF_WITH_OFFSETS`).
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




## Known issues