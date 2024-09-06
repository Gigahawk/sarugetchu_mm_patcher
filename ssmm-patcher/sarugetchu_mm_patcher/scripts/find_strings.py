from enum import Enum, auto
import re
from pprint import pprint
from pathlib import Path
from multiprocessing import Pool

from googletrans import Translator, LANGCODES
import yaml
from httpcore._exceptions import ConnectTimeout


from sarugetchu_mm_patcher.encoding import (
    bytes_to_char, is_kanji, tokens_to_string,
    tokenize_string
)


class States(Enum):
    IDLE = auto()
    STRING_BEGIN = auto()

class StringFinder:
    def __init__(self, path: Path):
        self.path = path
        with open(path, "rb") as f:
            self.data = f.read()



    def inspect_string(self, start_idx, end_idx) -> tuple[int, bytes]:
        # Some strings are randomly allocated an extra byte?
        # Allow for allocation size to be greater than the string length
        max_over = 5
        alloc_length = int.from_bytes(
            self.data[start_idx-4:start_idx],
            byteorder="little"
        )
        str_length = end_idx - start_idx
        if str_length <= alloc_length <= (str_length + max_over):
            string = self.data[start_idx-8:end_idx+1]
            return start_idx, string

    def build_csv(self, strings: list[tuple[int, bytes, int, int, list[bytes], str]]):
        with open(f"strings/strings_{self.path.name}.csv", "w") as f:
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
                for token in tokens:
                    char = bytes_to_char[token]
                    if char in ["\n", "\f"]:
                        f.write(f'"{repr(char).strip("'")}",')
                    else:
                        f.write(f'"{char}",')
                f.write("\n")

    def has_unknown_tokens(self, tokens: list[bytes]) -> bool:
        return any([bytes_to_char[t] == "??" for t in tokens])

    def count_unknown_strings(
            self,
            strings: list[tuple[int, bytes, int, int, list[bytes], str]]
        ):
        # Count tokens in case some real strings have ?? as text
        num_unknown = 0
        for _, _, _, _, tokens, string in strings:
            if self.has_unknown_tokens(tokens):
                num_unknown += 1
                if b"\x5B" in tokens:
                    print("Found string with unknown token containing furigana:")
                    print(string)
                    curr_kanji_tokens = []
                    for token in tokens:
                        if is_kanji(token):
                            curr_kanji_tokens.append(token)
                        elif curr_kanji_tokens and token != b"\x5D":
                            curr_kanji_tokens.append(token)
                        elif curr_kanji_tokens and token == b"\x5D":
                            curr_kanji_tokens.append(token)
                            if self.has_unknown_tokens(curr_kanji_tokens):
                                print(tokens_to_string(curr_kanji_tokens))
                                print(" ".join(t.hex() for t in curr_kanji_tokens))
                            curr_kanji_tokens = []
                        else:
                            curr_kanji_tokens = []

        print(f"Total strings: {len(strings)}")
        if len(strings) != 0:
            print(
                "Strings with unencoded char: "
                f"{num_unknown} ({num_unknown/len(strings)*100}%)"
            )

    def build_translation_doc(
            self,
            strings: list[tuple[int, bytes, int, int, list[bytes], str]]
        ):
        print("Generating translations")
        translator = Translator()
        try:
            with open(f"strings/strings_{self.path.name}.yaml", "r") as f:
                translations = yaml.safe_load(f)
        except FileNotFoundError:
            translations = {}

        for idx, id, _, _, tokens, string in strings:
            curr_dict = translations.get(string, {})
            curr_dict[hex(idx)] = id.hex()
            translations[string] = curr_dict
            if self.has_unknown_tokens(tokens):
                print("Skipping string with unknown tokens:")
                print(string)
                continue
            if "english" in curr_dict:
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
            try:
                translated = translator.translate(
                    trans_string,
                    src="ja",
                    dest="en"
                )
                print(translated.text)
                translations[string]["english"] = translated.text
            except ConnectTimeout:
                print(
                    "Failed to connect to google translate, likely being rate limited"
                )

        dump = yaml.dump(translations, allow_unicode=True, default_style='"')
        with open(f"strings/strings_{self.path.name}.yaml", "w") as f:
            f.write(dump)

    def find_index_spacing(
            self,
            strings: list[tuple[int, bytes, int, int, list[bytes], str]]
        ):
        last_idx = 0
        last_len = 0
        last_id = 0
        for idx, id, _, actual_len, _, _ in strings:
            id_int = int.from_bytes(id, byteorder="little")
            idx_diff = idx - last_idx
            id_diff = id_int - last_id
            len_extra = last_len + 9
            print(
                f"String at idx {idx} ({hex(idx)}), difference: {idx_diff}, "
                f"last_len + 9: {len_extra}, match {len_extra == idx_diff}, "
                f"id: {id.hex()} ({hex(id_int)}), "
                f"id difference: {id_diff} ({hex(id_diff)}), "
            )
            last_idx = idx
            last_len = actual_len
            last_id = id_int

    def find_string_locs(self) -> list[tuple[int, bytes]]:
        state = States.IDLE
        strings = []
        idx = 0
        string_start_idx = None

        while idx < len(self.data):
            byte = self.data[idx:idx+1]
            token = self.data[idx:idx+2]
            #if idx >= 0x28C44A:
            #if idx >= 0x28c58c:
            #    print(state)
            #    print(hex(idx))
            #    print(byte.hex())
            #    print(token.hex())
            #    import pdb;pdb.set_trace()
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
                    string = self.inspect_string(string_start_idx, idx)
                    if string is not None:
                        strings.append(string)
                state = States.IDLE
            idx += 1

        #strings.sort(key=lambda s: len(s[1]), reverse=True)
        return strings

    def stringify_tokens(self, tokens: list[bytes]) -> str:
        return "".join(bytes_to_char[t] for t in tokens)


    def extract_strings(
            self,
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
            stringified_string = self.stringify_tokens(tokens)
            strings.append((
                idx, string_id, alloc_len, actual_len, tokens, stringified_string
            ))
        return strings

    def main(self):
        string_locs = self.find_string_locs()

        strings = self.extract_strings(string_locs)

        self.build_csv(strings)

        self.count_unknown_strings(strings)

        self.build_translation_doc(strings)

        self.find_index_spacing(strings)

def run_stringfinder(fpath: Path):
    sf = StringFinder(fpath)
    sf.main()

def main():
    #files = [
    #    #"2f62887b",  # gz/stage.01_boss01_gori01_bd.gz
    #    #"3c6cf60b",
    #    #"5c272d50",  # gz/game_common.story.gz
    #    "87f51e0c",  # gz/menu_story.01_boss01_gori01.gz
    #    #"95d0e0fc",  # gz/boss.01_boss01_gori01.gz
    #    #"00940549",  # gz/menu_common.gz
    #    #"aa6f7a50",  # gz/stage.01_boss01_gori01.gz
    #]
    path = Path("result/DATA1")

    fpaths = [f for f in path.glob("**/*") if f.is_file()]
    with Pool(256) as p:
        p.map(run_stringfinder, fpaths)



    #for f in path.glob("**/*"):
    #    if not f.is_file():
    #        continue
    #    sf = StringFinder(f)
    #    sf.main()


if __name__ == "__main__":
    main()