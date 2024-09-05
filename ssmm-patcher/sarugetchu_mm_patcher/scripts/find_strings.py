from googletrans import Translator, LANGCODES
import yaml
import re
from pprint import pprint
from enum import Enum, auto


from sarugetchu_mm_patcher.encoding import bytes_to_char


class States(Enum):
    IDLE = auto()
    STRING_BEGIN = auto()

class StringFinder:
    def __init__(self, name):
        self.name = name
        with open(name, "rb") as f:
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
        with open(f"strings_{self.name}.csv", "w") as f:
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
                    f.write(f'"{bytes_to_char[token]}",')
                f.write("\n")

    def has_unknown_tokens(self, tokens: list[bytes]) -> bool:
        return any([bytes_to_char[t] == "??" for t in tokens])

    def count_unknown_strings(
            self,
            strings: list[tuple[int, bytes, int, int, list[bytes], str]]
        ):
        # Count tokens in case some real strings have ?? as text
        num_unknown = 0
        for _, _, _, _, tokens, _ in strings:
            if self.has_unknown_tokens(tokens):
                num_unknown += 1
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
            with open(f"strings_{self.name}.yaml", "r") as f:
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
            translated = translator.translate(
                trans_string,
                src="ja",
                dest="en"
            )
            print(translated.text)
            translations[string]["english"] = translated.text

        dump = yaml.dump(translations, allow_unicode=True)
        with open(f"strings_{self.name}.yaml", "w") as f:
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

    def tokenize_string(self, string: bytes) -> list[bytes]:
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
            tokens = self.tokenize_string(string)
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

def main():
    files = [
        "2f62887b",
        "3c6cf60b",
        "5c272d50",
        "87f51e0c",
        "95d0e0fc",
        "00940549",
        "aa6f7a50",
    ]
    for f in files:
        sf = StringFinder(f)
        sf.main()


if __name__ == "__main__":
    main()