# Notes

## Index
PDATA/DATA0.BIN and DATA2.BIN appear to be some kind of index file describing the contents of the bigger DATA1.BIN and DATA3.BIN respectively

Each entry is 12 bytes long, and denotes a file entry

The first 4 bytes are a CRC-like hash of the filename of the file entry (see the gen_crc command for implementation).
See below for known hashes

The middle 4 bytes are the offset into the big data file (DATA0 is the index for DATA1)
Multiply this value by 2048 bytes to get the start of each entry

The last 4 bytes are the size of the file in bytes.

### Known hashes

```
1F A8 A5 BF: package/mod310.tar.gz
B0 FF CA DB: gz/system.gz
5D 55 E9 BE: gz/system_bd.gz
00 94 05 49: gz/menu_common.gz
05 F7 CA E8: gz/menu_title.gz
3C 6C F6 0B: gz/menu_vs.gz
```



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

## Known issues