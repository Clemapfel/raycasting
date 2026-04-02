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
SYLLABLE_LIST_FILENAME = "syllables.txt"
EXPORT_EMOTIONS = [ Emotion.NORMAL ]
EXPORT_GENDERS = [ Gender.FEMALE ]
EXPORT_FORMAT = Format.OGG

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
        engine.set_speed(0.8)
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


def main():
    # load engines

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

    # syllables

    syllables = {
        # vowels
        "a": "ア", "i": "イ", "u": "ウ", "e": "エ", "o": "オ",

        # K
        "ka": "カ", "ki": "キ", "ku": "ク", "ke": "ケ", "ko": "コ",

        # S
        "sa": "サ", "shi": "シ", "su": "ス", "se": "セ", "so": "ソ",

        # T
        "ta": "タ", "chi": "チ", "tsu": "ツ", "te": "テ", "to": "ト",

        # N
        "na": "ナ", "ni": "ニ", "nu": "ヌ", "ne": "ネ", "no": "ノ",

        # H
        "ha": "ハ", "hi": "ヒ", "fu": "フ", "he": "ヘ", "ho": "ホ",

        # M
        "ma": "マ", "mi": "ミ", "mu": "ム", "me": "メ", "mo": "モ",

        # Y
        "ya": "ヤ", "yu": "ユ", "yo": "ヨ",

        # R
        "ra": "ラ", "ri": "リ", "ru": "ル", "re": "レ", "ro": "ロ",

        # W
        "wa": "ワ", "wi": "ヰ", "we": "ヱ", "wo": "ヲ",

        # N (syllabic nasal)
        "n": "ン",

        # G (voiced K)
        "ga": "ガ", "gi": "ギ", "gu": "グ", "ge": "ゲ", "go": "ゴ",

        # Z (voiced S)
        "za": "ザ", "ji": "ジ", "zu": "ズ", "ze": "ゼ", "zo": "ゾ",

        # D (voiced T)
        "da": "ダ", "di": "ヂ", "du": "ヅ", "de": "デ", "do": "ド",

        # B (voiced H)
        "ba": "バ", "bi": "ビ", "bu": "ブ", "be": "ベ", "bo": "ボ",

        # P (semi-voiced H)
        "pa": "パ", "pi": "ピ", "pu": "プ", "pe": "ペ", "po": "ポ",

        # KY (palatalized K)
        "kya": "キャ", "kyu": "キュ", "kyo": "キョ",

        # SH (palatalized S)
        "sha": "シャ", "shu": "シュ", "sho": "ショ",

        # CH (palatalized T)
        "cha": "チャ", "chu": "チュ", "cho": "チョ",

        # NY (palatalized N)
        "nya": "ニャ", "nyu": "ニュ", "nyo": "ニョ",

        # HY (palatalized H)
        "hya": "ヒャ", "hyu": "ヒュ", "hyo": "ヒョ",

        # MY (palatalized M)
        "mya": "ミャ", "myu": "ミュ", "myo": "ミョ",

        # RY (palatalized R)
        "rya": "リャ", "ryu": "リュ", "ryo": "リョ",

        # GY (palatalized G)
        "gya": "ギャ", "gyu": "ギュ", "gyo": "ギョ",

        # JY (palatalized J)
        "ja": "ジャ", "ju": "ジュ", "jo": "ジョ",

        # BY (palatalized B)
        "bya": "ビャ", "byu": "ビュ", "byo": "ビョ",

        # PY (palatalized P)
        "pya": "ピャ", "pyu": "ピュ", "pyo": "ピョ",

        # DY (palatalized D, archaic)
        "dya": "ヂャ", "dyu": "ヂュ", "dyo": "ヂョ",

        # foreign sounds
        "fa": "ファ", "fi": "フィ", "fe": "フェ", "fo": "フォ",
        "va": "ヴァ", "vi": "ヴィ", "vu": "ヴ", "ve": "ヴェ", "vo": "ヴォ",
        "ti": "ティ", "tu": "トゥ", #"di2": "ディ", "du2": "ドゥ",
        "tsa": "ツァ", "tsi": "ツィ", "tse": "ツェ", "tso": "ツォ",
        "she": "シェ", "je": "ジェ", "che": "チェ",
        #"wi2": "ウィ", "we2": "ウェ", "wo2": "ウォ",
    }

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

                for romaji, japanese in syllables.items():
                    filename = path / (romaji + "." + EXPORT_FORMAT)
                    export(engine, japanese, filename.as_posix())

                    syllable_list.add(romaji)

    syllable_list_path = Path(EXPORT_PREFIX) / (SYLLABLE_LIST_FILENAME)
    syllable_list_path.unlink(missing_ok = True) # delete if already exists

    with open(syllable_list_path, "w") as file:
        file.writelines(element + "\n" for element in sorted(syllable_list))

    print("[rt] wrote syllable list to `" + syllable_list_path.as_posix() + "`")

###

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