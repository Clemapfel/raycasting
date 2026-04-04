import sys
from g2p_en import G2p


def text_to_phonemes_lua(text):
    g2p = G2p()
    phonemes = g2p(text)
    lua_table = "{ " + ", ".join(f'"{phoneme}"' for phoneme in phonemes) + " }"
    return lua_table


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <string1> <string2> ...")
        sys.exit(1)

    input_texts = sys.argv[1:]
    lua_tables = [text_to_phonemes_lua(text) for text in input_texts]

    lua_result = "return " + ", ".join(lua_tables)

    print(lua_result)
