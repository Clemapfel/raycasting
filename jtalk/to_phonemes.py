import sys
from g2p_en import G2p

def to_phoneme_lua_table(text):
    g2p = G2p()
    phonemes = g2p(text)
    lua_table = "{ " + ", ".join(f'"{phoneme}"' for phoneme in phonemes) + " }"
    return lua_table


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("return error(\"In to_phonemes.py: failed to convert input, is it a string or list of strings?\")")
        sys.exit(1)

    input_text = " ".join(sys.argv[1:])
    lua_result = to_phoneme_lua_table(input_text)
    print(f"return {lua_result}")
