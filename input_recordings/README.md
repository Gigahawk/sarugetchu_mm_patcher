# Input Recordings

PCSX2 input recordings to automatically get to certain points in the game without needing savestates.

- `colosseum_credits.p2m2`: Get to the Devils Tournament completion screen before credits roll
    - Requires a save file with Colosseum Mode completed in slot 1 (use `save_files/story.ps2`)
    - Requires `player_1_immortal` cheat enabled
    - Slow, doesn't do any inputs, just waits for time to timeout
    - TODO: use `Manually Set Real-Time Clock` to have deterministic character behavior for faster run time?