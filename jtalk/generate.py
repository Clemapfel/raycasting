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
EXPORT_EMOTIONS = [ Emotion.ANGRY, Emotion.BASHFUL, Emotion.NORMAL, Emotion.SAD ]
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
    "A": "ア", "I": "イ", "U": "ウ", "E": "エ", "O": "オ",

    # Long vowels
    "AA": "アア", "II": "イイ", "UU": "ウウ", "EE": "えい", "OO": "オオ",

    # K-row
    "KA": "カ", "KI": "キ", "KU": "ク", "KE": "ケ", "KO": "コ",
    # G-row
    "GA": "ガ", "GI": "ギ", "GU": "グ", "GE": "ゲ", "GO": "ゴ",
    # S-row
    "SA": "サ", "SI": "シ", "SU": "ス", "SE": "セ", "SO": "ソ",
    # Z-row
    "ZA": "ザ", "ZI": "ジ", "ZU": "ズ", "ZE": "ゼ", "ZO": "ゾ",
    # T-row
    "TA": "タ", "TI": "チ", "TU": "ツ", "TE": "テ", "TO": "ト",
    # D-row
    "DA": "ダ", "DI": "ディ", "DU": "ヅ", "DE": "デ", "DO": "ド",
    # N-row
    "NA": "ナ", "NI": "ニ", "NU": "ヌ", "NE": "ネ", "NO": "ノ",
    # H-row
    "HA": "ハ", "HI": "ヒ", "HU": "フ", "HE": "ヘ", "HO": "ホ",
    # B-row
    "BA": "バ", "BI": "ビ", "BU": "ぶ", "BE": "ベ", "BO": "ボ",
    # P-row
    "PA": "パ", "PI": "ピ", "PU": "プ", "PE": "ペ", "PO": "ポ",
    # M-row
    "MA": "マ", "MI": "ミ", "MU": "ム", "ME": "メ", "MO": "モ",
    # Y-row
    "YA": "ヤ", "YU": "ユ", "YO": "ヨ",
    # R-row
    "RA": "ラ", "RI": "リ", "RU": "ル", "RE": "レ", "RO": "ロ",
    # W-row
    "WA": "ワ", "WO": "ヲ",

    # Palatalized — K
    "KYA": "キャ", "KYU": "キュ", "KYO": "キョ",
    # Palatalized — G
    "GYA": "ギャ", "GYU": "ギュ", "GYO": "ギョ",
    # Palatalized — SH
    "SHA": "シャ", "SHI": "シ", "SHU": "シュ", "SHE": "シェ", "SHO": "ショ",
    # Palatalized — J
    "JA": "ジャ", "JI": "ジ", "JU": "ジュ", "JE": "ジェ", "JO": "ジョ",
    # Palatalized — CH
    "CHA": "チャ", "CHI": "チ", "CHU": "チュ", "CHE": "チェ", "CHO": "チョ",
    # Palatalized — TS
    "TSA": "ツァ", "TSI": "ツィ", "TSU": "ツ", "TSE": "ツェ", "TSO": "ツォ",
    # Palatalized — N
    "NYA": "ニャー", "NYU": "ニュ", "NYO": "ニョ",
    # Palatalized — H
    "HYA": "ヒャ", "HYU": "ヒュ", "HYO": "ヒョ",
    # Palatalized — F
    "FA": "ファ", "FI": "フィ", "FU": "フ", "FE": "フェ", "FO": "フォ",
    # Palatalized — B
    "BYA": "ビャ", "BYU": "ビュ", "BYO": "ビョ",
    # Palatalized — P
    "PYA": "ピャ", "PYU": "ピュ", "PYO": "ピョ",
    # Palatalized — M
    "MYA": "ミャ", "MYU": "ミュ", "MYO": "ミョ",
    # Palatalized — R
    "RYA": "リャ", "RYU": "リュ", "RYO": "リョ",

    # V-row (foreign loans)
    "VA": "ヴァ", "VI": "ヴィ", "VU": "ヴ", "VE": "ヴェ", "VO": "ヴォ",

    # Foreign stops on /t/ and /d/
    "THI": "ティ", "TYU": "テュ", "DYU": "デュ",

    # Moraic nasal and geminate
    "N": "ン",
}

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