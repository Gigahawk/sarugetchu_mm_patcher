from googletrans import Translator, LANGCODES
import yaml
import re
from pprint import pprint
from enum import Enum, auto


from sarugetchu_mm_patcher.encoding import bytes_to_char

with open("00940549", "rb") as f:
    data = f.read()

class States(Enum):
    IDLE = auto()
    STRING_BEGIN = auto()


def inspect_string(start_idx, end_idx) -> tuple[int, bytes]:
    # Some strings are randomly allocated an extra byte?
    # Allow for allocation size to be greater than the string length
    max_over = 5
    alloc_length = int.from_bytes(
        data[start_idx-4:start_idx],
        byteorder="little"
    )
    str_length = end_idx - start_idx
    if str_length <= alloc_length <= (str_length + max_over):
        string = data[start_idx-8:end_idx+1]
        return start_idx, string

def build_csv(strings: list[tuple[int, bytes, int, int, list[bytes], str]]):
    with open("strings.csv", "w") as f:
        for idx, id, alloc_len, actual_len, tokens, string in strings:
            f.write(
                f"\"Found string at {hex(idx)} with id {id.hex(' ')}; "
                f"allocation_length {alloc_len}; "
                f"actual length {actual_len}\"\n"
            )
            if alloc_len > actual_len:
                f.write("ALLOC BIGGER THAN STRING LEN\n")
            # Japanese chars print with non deterministic len, use libreoffice for justification
            for token in tokens:
                f.write(f'"{token.hex().upper()}",')
            f.write("\n")
            for char in string:
                f.write(f'"{char}",')
            f.write("\n")

def has_unknown_tokens(tokens: list[bytes]) -> bool:
    return any([bytes_to_char[t] == "??" for t in tokens])

def count_unknown_strings(
        strings: list[tuple[int, bytes, int, int, list[bytes], str]]
    ):
    # Count tokens in case some real strings have ?? as text
    num_unknown = 0
    for _, _, _, _, tokens, _ in strings:
        if has_unknown_tokens(tokens):
            num_unknown += 1
    print(f"Total strings: {len(strings)}")
    print(
        "Strings with unencoded char: "
        f"{num_unknown} ({num_unknown/len(strings)*100}%)"
    )

def build_translation_doc(
        strings: list[tuple[int, bytes, int, int, list[bytes], str]]
    ):
    print("Generating translations")
    translator = Translator()
    try:
        with open("strings.yaml", "r") as f:
            translations = yaml.safe_load(f)
    except FileNotFoundError:
        translations = {}

    for _, _, _, _, tokens, string in strings:
        if has_unknown_tokens(tokens):
            print("Skipping string with unknown tokens:")
            print(string)
            continue
        if string in translations:
            print("Skipping string already in translations:")
            print(string)
            print(translations[string])
            continue
        if not string.strip():
            print(f"Skipping blank string {repr(string)}")
            continue
        print("Translating string:")
        print(string)
        # Remove furigana for translation
        trans_string = re.sub(r"<.+>", "", string)
        translated = translator.translate(
            trans_string,
            src="ja",
            dest="en"
        )
        print(translated.text)
        translations[string] = {
            "english": translated.text
        }
        dump = yaml.dump(translations, allow_unicode=True)
        with open("strings.yaml", "w") as f:
            f.write(dump)



def find_string_locs() -> list[tuple[int, bytes]]:
    state = States.IDLE
    strings = []
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
                string = inspect_string(string_start_idx, idx)
                if string is not None:
                    strings.append(string)
            state = States.IDLE
        idx += 1

    #strings.sort(key=lambda s: len(s[1]), reverse=True)
    return strings

def tokenize_string(string: bytes) -> list[bytes]:
    idx = 0
    out = []
    while idx < len(string):
        byte = string[idx:idx+1]
        token = string[idx:idx+2]

        if token in bytes_to_char:
            out.append(token)
            idx += 2
            continue
        if byte in bytes_to_char:
            out.append(byte)
            idx += 1
            continue
        raise ValueError(
            f"Got invalid byte or token {byte}, {token}"
        )
    return out

def stringify_tokens(tokens: list[bytes]) -> str:
    return "".join(bytes_to_char[t] for t in tokens)


def extract_strings(
        string_locs: list[tuple[int, bytes]]
    ) -> list[tuple[int, bytes, int, int, list[bytes], str]]:
    strings = []
    for idx, string_bytes in string_locs:
        string_id = string_bytes[0:4]
        string_len_bytes = string_bytes[4:8]
        alloc_len = int.from_bytes(
            string_len_bytes,
            byteorder="little"
        )
        string = string_bytes[8:-1]
        actual_len = len(string)
        tokens = tokenize_string(string)
        stringified_string = stringify_tokens(tokens)
        strings.append((
            idx, string_id, alloc_len, actual_len, tokens, stringified_string
        ))
    return strings

def main():
    string_locs = find_string_locs()

    strings = extract_strings(string_locs)

    build_csv(strings)

    count_unknown_strings(strings)

    build_translation_doc(strings)




if __name__ == "__main__":
    main()