from pprint import pprint
from enum import Enum, auto


from sarugetchu_mm_patcher.encoding import bytes_to_char

with open("00940549", "rb") as f:
    data = f.read()

class States(Enum):
    IDLE = auto()
    STRING_BEGIN = auto()

strings: list[tuple[int, bytes]] = []

def inspect_string(start_idx, end_idx):
    # Some strings are randomly allocated an extra byte?
    global strings
    max_over = 5
    alloc_length = int.from_bytes(
        data[start_idx-4:start_idx],
        byteorder="little"
    )
    str_length = end_idx - start_idx
    if str_length <= alloc_length <= (str_length + max_over):
        string = data[start_idx-8:end_idx+1]
        strings.append(
            (start_idx, string)
        )

def print_strings():
    global strings
    for idx, string in strings:
        string_id = string[0:4]
        string_len_bytes = string[4:8]
        alloc_len = int.from_bytes(
            string_len_bytes,
            byteorder="little"
        )
        actual_length = len(string) - 9
        print(
            f"\"Found string at {hex(idx)} with id {string_id.hex(' ')}; "
            f"allocation_length {alloc_len} ({string_len_bytes.hex(' ')}); "
            f"actual length {actual_length}\""
        )
        if alloc_len > actual_length:
            print("ALLOC BIGGER THAN STRING LEN")
        i = 8
        tokens: list[bytes] = []
        while i < len(string) - 1:
            byte = string[i:i+1]
            token = string[i:i+2]
            if token in bytes_to_char:
                tokens.append(token)
                i += 2
                continue
            tokens.append(byte)
            i += 1
        # Japanese chars print with non deterministic len, use libreoffice for justification
        for token in tokens:
            print(f'"{token.hex().upper()}",', end="")
        print("")
        for token in tokens:
            char = bytes_to_char[token]
            if char == "\n":
                print('"\\n",', end="")
            else:
                print(f'"{char}",', end="")
        print("")

def main():
    global strings
    state = States.IDLE

    idx = 0
    string_start_idx = None

    while idx < len(data):
        byte = data[idx:idx+1]
        token = data[idx:idx+2]
        if state == States.IDLE:
            # Presumably a string never starts with furigana?
            if token in bytes_to_char:
                state = States.STRING_BEGIN
                string_start_idx = idx
                idx += 2
                continue
        if state == States.STRING_BEGIN:
            if token in bytes_to_char:
                idx += 2
                continue
            # Furigana markers
            if byte in bytes_to_char:
                idx += 1
                continue
            if byte == b"\x00":
                # Found end of string
                inspect_string(string_start_idx, idx)
            state = States.IDLE
        idx += 1

    strings.sort(key=lambda s: len(s[1]), reverse=True)

    print_strings()


if __name__ == "__main__":
    main()