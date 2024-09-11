from sarugetchu_mm_patcher.encoding import EncodingTranslator

encoder = EncodingTranslator()

num_entries = len(encoder.bytes_to_char)

num_filled = sum(
    [
        0 if c == "??" else 1
        for c in encoder.bytes_to_char.values()
    ]
)
print(f"Total entries: {num_entries}")
print(f"Total filled: {num_filled} ({num_filled/num_entries*100}%)")
