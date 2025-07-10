# Input Recordings

PCSX2 input recordings to automatically get to certain points in the game without needing savestates.

- `colosseum_credits.p2m2`: Get to the Devils Tournament completion screen before credits roll
    - Requires a save file with Colosseum Mode completed in Slot 1, File 1 (use `save_files/story.ps2`)
    - Requires `player_1_immortal` cheat enabled
    - Slow, doesn't do any inputs, just waits for time to timeout
        - While RNG seed is consistent when `Manually set Real-Time Clock` is set, it seems that modifying any game files causes the RNG seed to change, meaning it won't be possible to have a TAS to beat Colosseum Mode that is consistent during development