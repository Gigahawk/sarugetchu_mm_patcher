# ImHex Patterns

These are ImHex files defining some game structures:

- `includes/typedefs.hexpat`: format of the resource files found in `DATA1`
- `includes/chardata.hexpat`: format for the character save files
- `includes/progress.hexpat`: format for the progress save files

## Using as a save editor

These files can be used with ImHex to act as a rudimentary save editor:

> Important: ensure PCSX2 is not running with your memory card loaded while making changes

> Warning: make backups, I take no responsibility if this corrupts your save file

1. Ensure your save file is stored on a [Folder Memory Card](https://pcsx2.net/docs/post/memcards#folder-memory-card)
2. Install [ImHex](https://imhex.werwolv.net/)
3. Add this folder (`imhex_patterns`) to your [`Folders` search path](https://docs.werwolv.net/imhex/misc/settings#categories)
4. Open your `chardata` or `progress` file in ImHex
5. Right click the [Pattern Editor](https://docs.werwolv.net/imhex/views/pattern-editor) window and select `Import pattern File`, then import `main_chardata.hexpat` or `main_progress.hexpat`
6. Edit your file properties in the [Pattern Data](https://docs.werwolv.net/imhex/views/pattern-data) window
7. When you're done with your changes, click the play button in the bottom of the Pattern Editor window to recalculate the file checksums, then save the file with `File > Save`
    - Optional: save a project file with `File > Project > Save Project As...` to avoid reimporting everything every time you want to make edits

