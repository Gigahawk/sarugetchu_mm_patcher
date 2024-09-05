# Notes

# Building with nix

Ensure the iso you have is:
    - named `mm.iso`
    - matches the md5 `946d0aeb90772efd9105b0f785b2c7ec`

Then run `nix-store --add-fixed sha256 mm.iso`

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
Each file in DATA1 is a gzip compressed file.

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

### Kanji Encodings

There's a lot of kanji, quite hard to figure out the encodings for all of them.
It appears the each row in the kanji keyboard is actually stored inside DATA1 in order, best to update the encoding list one row at a time.

There appear to be some kanji not available through the keyboard?
Maybe the devs just got lazy and didn't feel like organizing them all

The kanji table appears to be banked, The 95Dx range of entries appear to represent some rarely used punctuation in most contexts, but in some (special attacks?) they map to some kanji

## PSS Cutscenes

Cutscenes are stored inside the `RAW/MPEG`.
They use Sony's weird proprietary extensions to MPEG2 and need to be demuxed properly.
There is currently a demuxer written python under `mux.py` but it is unbearably slow and will probably have to be rewritten in C or something to get something usable.

> We're using ssmm-demux to demux and ps2str to remux




## Known issues