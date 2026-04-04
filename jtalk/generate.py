from enum import Enum
from subprocess import DEVNULL

class Emotion(str, Enum):
    ANGRY = "angry"
    BASHFUL = "bashful"
    HAPPY = "happy"
    NORMAL = "normal"
    SAD = "sad"

class Gender(str, Enum):
    MALE = "takumi",
    FEMALE = "mei"
    
class Format(str, Enum):
    WAV = "wav",
    OGG = "ogg"

EXPORT_PREFIX = "export"
SYLLABLE_LIST_FILENAME = "phonemes_jp.txt"
EXPORT_EMOTIONS = [ Emotion.NORMAL ]
EXPORT_GENDERS = [ Gender.FEMALE, Gender.MALE ]
EXPORT_SPEED = 2
EXPORT_FORMAT = Format.WAV

# -------------------------------------- #

import pyopenjtalk
from pyopenjtalk import HTSEngine
from scipy.io import wavfile
from pathlib import Path
import shutil

import subprocess
import numpy as np
import os
import time

def convert(wav_path, ogg_path):
    return subprocess.run(
        ["ffmpeg", "-y", "-i", wav_path, ogg_path],
        check = True,
        stdout=DEVNULL,
        stderr=DEVNULL
    )

def export(engine_path, text, output_path):
    if engine_path is None or not os.path.isfile(engine_path):
        print("[rt] unable to use engine at `" + str(engine_path) + "`")
        return False

    try:
        engine = HTSEngine(engine_path.encode("utf-8"))
        engine.set_speed(EXPORT_SPEED)
        waveform = engine.synthesize(pyopenjtalk.extract_fullcontext(text))

        if EXPORT_FORMAT == Format.WAV:
            wavfile.write(output_path, engine.get_sampling_frequency(), waveform.astype(np.int16))
        else:
            temp_path = output_path + ".temp.wav"
            try:
                wavfile.write(temp_path, engine.get_sampling_frequency(), waveform.astype(np.int16))
                if os.path.isfile(output_path):
                    os.remove(output_path)

                convert(temp_path, output_path)
            finally:
                if os.path.isfile(temp_path):
                    os.remove(temp_path)

        print("[rt] wrote to `" + output_path + "` using `" + engine_path + "`")
        return True

    except Exception as error:
        print("[rt] export failed: " + str(error))
        return False

phonemes = {
    # Vowels
    "a": "ア", "i": "イ", "u": "ウ", "e": "エ", "o": "オ",

    # Long vowels
    "aa": "アア", "ii": "イイ", "uu": "ウウ", "ee": "えい", "oo": "オオ",

    # K-row
    "ka": "カ", "ki": "キ", "ku": "ク", "ke": "ケ", "ko": "コ",
    # G-row
    "ga": "ガ", "gi": "ギ", "gu": "グ", "ge": "ゲ", "go": "ゴ",
    # S-row
    "sa": "サ", "si": "シ", "su": "ス", "se": "セ", "so": "ソ",
    # Z-row
    "za": "ザ", "zi": "ジ", "zu": "ズ", "ze": "ゼ", "zo": "ゾ",
    # T-row
    "ta": "タ", "ti": "チ", "tu": "ツ", "te": "テ", "to": "ト",
    # D-row
    "da": "ダ", "di": "ディ", "du": "ヅ", "de": "デ", "do": "ド",
    # N-row
    "na": "ナ", "ni": "ニ", "nu": "ヌ", "ne": "ネ", "no": "ノ",
    # H-row
    "ha": "ハ", "hi": "ヒ", "hu": "フ", "he": "ヘ", "ho": "ホ",
    # B-row
    "ba": "バ", "bi": "ビ", "bu": "ぶ", "be": "ベ", "bo": "ボ",
    # P-row
    "pa": "パ", "pi": "ピ", "pu": "プ", "pe": "ペ", "po": "ポ",
    # M-row
    "ma": "マ", "mi": "ミ", "mu": "ム", "me": "メ", "mo": "モ",
    # Y-row
    "ya": "ヤ", "yu": "ユ", "yo": "ヨ",
    # R-row
    "ra": "ラ", "ri": "リ", "ru": "ル", "re": "レ", "ro": "ロ",
    # W-row
    "wa": "ワ", "wo": "ヲ",

    # Palatalized — K
    "kya": "キャ", "kyu": "キュ", "kyo": "キョ",
    # Palatalized — G
    "gya": "ギャ", "gyu": "ギュ", "gyo": "ギョ",
    # Palatalized — SH
    "sha": "シャ", "shi": "シ", "shu": "シュ", "she": "シェ", "sho": "ショ",
    # Palatalized — J
    "ja": "ジャ", "ji": "ジ", "ju": "ジュ", "je": "ジェ", "jo": "ジョ",
    # Palatalized — CH
    "cha": "チャ", "chi": "チ", "chu": "チュ", "che": "チェ", "cho": "チョ",
    # Palatalized — TS
    "tsa": "ツァ", "tsi": "ツィ", "tsu": "ツ", "tse": "ツェ", "tso": "ツォ",
    # Palatalized — N
    "nya": "ニャー", "nyu": "ニュ", "nyo": "ニョ",
    # Palatalized — H
    "hya": "ヒャ", "hyu": "ヒュ", "hyo": "ヒョ",
    # Palatalized — F
    "fa": "ファ", "fi": "フィ", "fu": "フ", "fe": "フェ", "fo": "フォ",
    # Palatalized — B
    "bya": "ビャ", "byu": "ビュ", "byo": "ビョ",
    # Palatalized — P
    "pya": "ピャ", "pyu": "ピュ", "pyo": "ピョ",
    # Palatalized — M
    "mya": "ミャ", "myu": "ミュ", "myo": "ミョ",
    # Palatalized — R
    "rya": "リャ", "ryu": "リュ", "ryo": "リョ",

    # V-row (foreign loans)
    "va": "ヴァ", "vi": "ヴィ", "vu": "ヴ", "ve": "ヴェ", "vo": "ヴォ",

    # Foreign stops on /t/ and /d/
    "thi": "ティ", "tyu": "テュ", "dyu": "デュ",

    # Moraic nasal and geminate
    "n": "ン",
}

# manual exclude
for exclude in [
    "nya", # sounds like "na"
    "ro",  # sounds like "ryo"
    "si",  # sounds like "shi"
    "ti",  # sounds like "chi"
    "tu",  # sounds like "tsu"
    "va",  # sounds like "va"
    "zi",  # sounds like "ji"
]:
    phonemes.pop(exclude)

def main():
    engines = {}
    engines[Gender.MALE] = {}
    engines[Gender.FEMALE] = {}

    mei_prefix = "./mmda_agents/Voice/mei/mei"
    for emotion in Emotion:
        path = Path(mei_prefix + "_" + emotion + ".htsvoice")
        engines[Gender.FEMALE][emotion] = path.as_posix()

    takumi_prefix = "./mmda_agents/Voice/takumi/takumi"
    for emotion in Emotion:
        path = Path(takumi_prefix + "_" + emotion + ".htsvoice")
        engines[Gender.MALE][emotion] = path.as_posix()

    assert(engines[Gender.MALE][Emotion.NORMAL] is not None and engines[Gender.FEMALE][Emotion.NORMAL] is not None)

    export_prefix_path = Path(EXPORT_PREFIX)

    if export_prefix_path.exists():
        shutil.rmtree(export_prefix_path)

    export_prefix_path.mkdir(exist_ok = True)

    syllable_list = set()

    for gender in EXPORT_GENDERS:
        for emotion in EXPORT_EMOTIONS:
            engine = engines[gender][emotion]
            if engine is not None:
                path = export_prefix_path / gender / emotion
                path.mkdir(parents = True, exist_ok = True)

                for romaji, japanese in phonemes.items():
                    filename = path / (romaji + "." + EXPORT_FORMAT)
                    export(engine, japanese, filename.as_posix())

                    syllable_list.add(romaji)

    syllable_list_path = Path(EXPORT_PREFIX) / (SYLLABLE_LIST_FILENAME)
    syllable_list_path.unlink(missing_ok = True) # delete if already exists

    with open(syllable_list_path, "w") as file:
        file.writelines(element + "\n" for element in sorted(syllable_list))

    print("[rt] wrote syllable list to `" + syllable_list_path.as_posix() + "`")

# ---

if __name__ == "__main__":
    before = time.time()
    try:
        main()
    except Exception as error:
        print("[rt] script failed with " + str(error))
        export_path = Path(EXPORT_PREFIX)
        if export_path.exists():
            shutil.rmtree(export_path)

    duration = time.time() - before
    print(f"done (took {duration:.4f}s)")