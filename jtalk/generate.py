
from enum import Enum
from subprocess import DEVNULL
from random import getrandbits
import pyopenjtalk
from pyopenjtalk import HTSEngine
from scipy.io import wavfile
from pathlib import Path
import shutil
import subprocess
import threading
import queue
import numpy as np
import os
import time
from dataclasses import dataclass

# Usage:
#
# 1. Generate all gender and emotion combinations:
#   python generate.py "all"
#
# 2. Generate all emotions for a specific gender:
#   python generate.py "gender" "<takumi / mei>"
#
# 3. Generate all genders for a specific emotion:
#   python generate.py "emotion" "<normal / happy / sad / angry / bashful>"
#
# 4. Generate bulk phonemes for one gender and emotion:
#   python generate.py "single" "<takumi / mei>" "<normal / happy / sad / angry / bashful>"
#
# 5. Generate a single specific sentence to a file:
#   python generate.py "file" "<sentence>" "<output_path.wav>" "<takumi / mei>" "<normal / happy / sad / angry / bashful>"
#

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
EXPORT_EMOTIONS = [ Emotion.NORMAL , Emotion.HAPPY, Emotion.SAD, Emotion.ANGRY, Emotion.BASHFUL ]
EXPORT_GENDERS = [ Gender.MALE , Gender.FEMALE ]

base_speed_male = 3.0
base_speed_female = 2.2
EXPORT_SPEED = {
    (Gender.MALE,   Emotion.NORMAL  ): 1.0 * base_speed_male,
    (Gender.MALE,   Emotion.HAPPY   ): 1.0 * base_speed_male,
    (Gender.MALE,   Emotion.SAD     ): 1.0 * base_speed_male,
    (Gender.MALE,   Emotion.ANGRY   ): 1.0 * base_speed_male,
    (Gender.MALE,   Emotion.BASHFUL ): 1.0 * base_speed_male,

    (Gender.FEMALE, Emotion.NORMAL  ): 1.0 * base_speed_female,
    (Gender.FEMALE, Emotion.HAPPY   ): 1.0 * base_speed_female,
    (Gender.FEMALE, Emotion.SAD     ): 1.0 * base_speed_female,
    (Gender.FEMALE, Emotion.ANGRY   ): 1.0 * base_speed_female,
    (Gender.FEMALE, Emotion.BASHFUL ): 1.0 * base_speed_female,
}

semitone = 1 / 12
base_pitch_male = 1 + 2 * semitone
base_pitch_female = 1
EXPORT_PITCH = {
    (Gender.MALE,   Emotion.NORMAL  ): 1.0 * base_pitch_male,
    (Gender.MALE,   Emotion.HAPPY   ): 1.0 * base_pitch_male,
    (Gender.MALE,   Emotion.SAD     ): 1.0 * base_pitch_male,
    (Gender.MALE,   Emotion.ANGRY   ): 1.0 * base_pitch_male,
    (Gender.MALE,   Emotion.BASHFUL ): 1.0 * base_pitch_male,

    (Gender.FEMALE, Emotion.NORMAL  ): 1.0 * base_pitch_female - semitone,
    (Gender.FEMALE, Emotion.HAPPY   ): 1.0 * base_pitch_female,
    (Gender.FEMALE, Emotion.SAD     ): 1.0 * base_pitch_female,
    (Gender.FEMALE, Emotion.ANGRY   ): 1.0 * base_pitch_female,
    (Gender.FEMALE, Emotion.BASHFUL ): 1.0 * base_pitch_female,
}
EXPORT_FORMAT = Format.WAV

THREAD_COUNT = 3

# -------------------------------------- #

import pyopenjtalk
from pyopenjtalk import HTSEngine
from scipy.io import wavfile
from pathlib import Path
import shutil

import subprocess
import threading
import queue
import numpy as np
import os
import time
from dataclasses import dataclass

# -------------------------------------- #

class MessageType(Enum):
    EXPORT = 1
    EXPORT_RESPONSE = 2
    SHUTDOWN = 3
    SHUTDOWN_RESPONSE = 4

@dataclass
class Message:
    type: MessageType
    gender: Gender = Gender.FEMALE
    emotion: Emotion = Emotion.NORMAL
    thread_id: int = -1
    text: str | None = None
    output_path: str | None = None
    success: bool | None = None

@dataclass
class Worker:
    thread: threading.Thread
    main_to_worker: queue.Queue
    worker_to_main: queue.Queue

# -------------------------------------- #

def convert(wav_path, ogg_path):
    return subprocess.run(
        ["ffmpeg", "-y", "-i", wav_path, ogg_path],
        check = True,
        stdout=DEVNULL,
        stderr=DEVNULL
    )

def gender_emotion_to_engine_path(gender : Gender, emotion : Emotion):
    mei_prefix = "./mmda_agents/Voice/mei/mei"
    takumi_prefix = "./mmda_agents/Voice/takumi/takumi"

    gender_prefix = ""
    if gender == Gender.MALE:
        gender_prefix = takumi_prefix
    elif gender == Gender.FEMALE:
        gender_prefix = mei_prefix
    else:
        raise Exception(f"In generate.py: unhandled gender {gender}")

    return Path(gender_prefix + "_" + emotion + ".htsvoice").as_posix()

def initialize_engine_cache(thread_ids):
    cache = [None] * (max(thread_ids) + 1)

    for thread_id in thread_ids:
        engines = {}
        for gender in Gender:
            for emotion in Emotion:
                engine_path = gender_emotion_to_engine_path(gender, emotion)

                try:
                    engine = HTSEngine(engine_path.encode("utf-8"))
                except Exception:
                    engine = HTSEngine(gender_emotion_to_engine_path(gender, Emotion.NORMAL).encode("utf-8"))

                engine.set_speed(EXPORT_SPEED[(gender, emotion)])
                engine.add_half_tone((EXPORT_PITCH[(gender, emotion)] - 1) * 12)
                engines[engine_path] = engine

        cache[thread_id] = engines

    return cache

thread_id_to_engine_cache = initialize_engine_cache([i for i in range(0, THREAD_COUNT)])

def export(thread_id : int, gender : Gender, emotion : Emotion, text : str, output_path : Path):
    engine_path = gender_emotion_to_engine_path(gender, emotion)

    try:
        cache = thread_id_to_engine_cache[thread_id]
        engine = cache[engine_path]
        waveform = engine.synthesize(pyopenjtalk.extract_fullcontext(text))

        if EXPORT_FORMAT == Format.WAV:
            wavfile.write(output_path, engine.get_sampling_frequency(), waveform.astype(np.int16))
        else:
            temp_path = output_path / (tostring(random.getrandbits(32)) + ".temp.wav")
            try:
                wavfile.write(temp_path, engine.get_sampling_frequency(), waveform.astype(np.int16))
                convert(temp_path, output_path)
            finally:
                if os.path.isfile(temp_path):
                    os.remove(temp_path)

        return True

    except Exception as error:
        print(f"[rt] export failed for thread {thread_id}: {error}")
        return False

# -------------------------------------- #

def thread_main(main_to_worker, worker_to_main):
    shutdown_active = False
    while True:
        if main_to_worker.empty() and shutdown_active:
            break

        message = main_to_worker.get(block=True)
        match message.type:
            case MessageType.EXPORT:
                success = export(message.thread_id, message.gender, message.emotion, message.text, message.output_path)
                worker_to_main.put(Message(
                    type=MessageType.EXPORT_RESPONSE,
                    gender=gender,
                    emotion=emotion,
                    text=message.text,
                    thread_id=message.thread_id,
                    output_path=message.output_path,
                    success=success,
                ))
            case MessageType.SHUTDOWN:
                shutdown_active = True
            case _:
                raise AssertionError(f"[rt] In thread_main: unhandled message type {message.type}")

    worker_to_main.put(Message(type=MessageType.SHUTDOWN_RESPONSE))

# -------------------------------------- #

file_postfix_expansion = {
    "" : lambda t: f"{t}。{t}。",
    "_q" : lambda t: f"{t}？{t}？",
    "_long": lambda t: f"{t}ー。{t}ー",
    "_long_q": lambda t: f"{t}ー？{t}ー？"
}

phonemes = {
    "A": "ア", "E": "エ", "I": "イ", "O": "オ", "U": "ウ",
    "AU": "アウ", "AI": "アイ", "EI": "エイ", "OU": "オウ",
    "II": "イイ", "UU": "ウウ", "OI": "オイ",
    "BI": "ビ", "BO": "ボ", "BU": "ブ", "BA": "バ", "BE": "ベ",
    "BAU": "バウ", "BAI": "バイ", "BEI": "ベイ", "BOU": "ボウ", "BII": "ビイ", "BUU": "ブウ", "BOI": "ボイ",
    "DA": "ダ", "DE": "デ", "DI": "ディ", "DO": "ド", "DU": "ドゥ",
    "DAU": "ダウ", "DAI": "ダイ", "DEI": "デイ", "DOU": "ドウ", "DII": "ディイ", "DUU": "ドゥウ", "DOI": "ドイ",
    "FA": "ファ", "FE": "フェ", "FI": "フィ", "FO": "フォ", "FU": "フ",
    "FAU": "ファウ", "FAI": "ファイ", "FEI": "フェイ", "FOU": "フォウ", "FII": "フィイ", "FUU": "フウ", "FOI": "フォイ",
    "GA": "ガ", "GE": "ゲ", "GI": "ギ", "GO": "ゴ", "GU": "グ",
    "GAU": "ガウ", "GAI": "ガイ", "GEI": "ゲイ", "GOU": "ボウ", "GII": "ギイ", "GUU": "グウ", "GOI": "ゴイ",
    "HA": "ハ", "HE": "ヘ", "HI": "ヒ", "HO": "ホ", "HU": "フ",
    "HAU": "ハウ", "HAI": "ハイ", "HEI": "ヘイ", "HOU": "ホウ", "HII": "ヒイ", "HUU": "フウ", "HOI": "ホイ",
    "JA": "ジャ", "JE": "ジェ", "JI": "ジ", "JO": "ジョ", "JU": "ジュ",
    "JAU": "ジャウ", "JAI": "ジャイ", "JEI": "ジェイ", "JOU": "ジョウ", "JII": "ジイ", "JUU": "ジュウ", "JOI": "ジョイ",
    "KA": "カ", "KE": "ケ", "KI": "キ", "KO": "コ", "KU": "ク",
    "KAU": "カウ", "KAI": "カイ", "KEI": "ケイ", "KOU": "コウ", "KII": "キイ", "KUU": "クウ", "KOI": "コイ",
    "MA": "マ", "ME": "メ", "MI": "ミ", "MO": "モ", "MU": "ム",
    "MAU": "マウ", "MAI": "マイ", "MEI": "メイ", "MOU": "モウ", "MII": "ミイ", "MUU": "ムウ", "MOI": "モイ",
    "NA": "ナ", "NE": "ネ", "NI": "ニ", "NO": "ノ", "NU": "ヌ",
    "NAU": "ナウ", "NAI": "ナイ", "NEI": "ネイ", "NOU": "ノウ", "NII": "ニイ", "NUU": "ヌウ", "NOI": "ノイ",
    "PA": "パ", "PE": "ペ", "PI": "ピ", "PO": "ポ", "PU": "プ",
    "PAU": "パウ", "PAI": "パイ", "PEI": "ペイ", "POU": "ポウ", "PII": "ピイ", "PUU": "プウ", "POI": "ポイ",
    "RA": "ラ", "RE": "レ", "RI": "リ", "RO": "ロ", "RU": "ル",
    "RAU": "ラウ", "RAI": "ライ", "REI": "レイ", "ROU": "ロウ", "RII": "リイ", "RUU": "ルウ", "ROI": "ロイ",
    "SA": "サ", "SE": "セ", "SI": "スィ", "SO": "ソ", "SU": "ス",
    "SAU": "サウ", "SAI": "サイ", "SEI": "セイ", "SOU": "ソウ", "SII": "スィイ", "SUU": "スウ", "SOI": "ソイ",
    "SHA": "シャ", "SHE": "シェ", "SHI": "シ", "SHO": "ショ", "SHU": "シュ",
    "SHAU": "シャウ", "SHAI": "シャイ", "SHEI": "シェイ", "SHOU": "ショウ", "SHII": "シイ", "SHUU": "シュウ", "SHOI": "ショイ",
    "TA": "タ", "TE": "テ", "TI": "ティ", "TO": "ト", "TU": "トゥ",
    "TAU": "タウ", "TAI": "タイ", "TEI": "テイ", "TOU": "トウ", "TII": "ティイ", "TUU": "トゥウ", "TOI": "トイ",
    "VA": "ヴァ", "VE": "ヴェ", "VI": "ヴィ", "VO": "ヴォ", "VU": "ヴ",
    "VAU": "ヴァウ", "VAI": "ヴァイ", "VEI": "ヴェイ", "VOU": "ヴォウ", "VII": "ヴィイ", "VUU": "ヴウ", "VOI": "ヴォイ",
    "WA": "ワ", "WE": "ウェ", "WI": "ウィ", "WO": "ヲ", "WU": "ウ",
    "WAU": "ワウ", "WAI": "ワイ", "WEI": "ウェイ", "WOU": "ウォウ", "WII": "ウィイ", "WUU": "ウウ", "WOI": "ウォイ",
    "YA": "ヤ", "YE": "イェ", "YI": "イイ", "YO": "ヨ", "YU": "ユ",
    "YAU": "ヤウ", "YAI": "ヤイ", "YEI": "イェイ", "YOU": "ヨウ", "YII": "イイ", "YUU": "ユウ", "YOI": "ヨイ",
    "ZA": "ザ", "ZE": "ゼ", "ZI": "ズィ", "ZO": "ゾ", "ZU": "ズ",
    "ZAU": "ザウ", "ZAI": "ザイ", "ZEI": "ゼイ", "ZOU": "ゾウ", "ZII": "ズィイ", "ZUU": "ズウ", "ZOI": "ゾイ",
    "N": "ン",
}

def main(gender : Gender, emotion : Emotion):
    engine = gender_emotion_to_engine_path(gender, emotion)
    if not Path(engine).exists():
        return 0

    export_prefix_path = Path(EXPORT_PREFIX)

    # build taks list
    tasks = []
    syllable_list = set()

    if engine is not None:
        path = export_prefix_path / gender / emotion
        path.mkdir(parents=True, exist_ok=True) # pre allocate folders in main

        for romaji, japanese in phonemes.items():
            for should_elongate in [True, False]:
                for should_question in [True, False]:
                    for postfix, expansion in file_postfix_expansion.items():
                        japanese_copy = japanese # deep copy, 'japanese' is by reference
                        romaji_copy = romaji

                        romaji_copy += postfix
                        japanese_copy = expansion(japanese_copy)

                        filename = path / (romaji_copy + "." + EXPORT_FORMAT)
                        tasks.append((gender, emotion, japanese_copy, filename.as_posix()))
                        syllable_list.add(romaji)

    n_tasks = len(tasks)
    worker_to_main = queue.Queue()
    workers = []
    thread_ids = [i for i in range(0, THREAD_COUNT)]

    # start threads
    for thread_id in thread_ids:
        main_to_worker = queue.Queue()
        worker = Worker(
            thread=threading.Thread(target=thread_main, args=(main_to_worker, worker_to_main)),
            main_to_worker=main_to_worker,
            worker_to_main=worker_to_main,
        )
        worker.thread.start()
        workers.append(worker)

    # distribute tasks round robin
    for index, (gender, emotion, text, output_path) in enumerate(tasks):
        thread_id = index % len(thread_ids)
        workers[thread_id].main_to_worker.put(Message(
            type=MessageType.EXPORT,
            gender=gender,
            emotion=emotion,
            text=text,
            output_path=output_path,
            thread_id=thread_id
        ))

    n_completed = 0
    print_step = max(1, n_tasks // 100)

    while n_completed < n_tasks:
        message = worker_to_main.get(block=True)
        match message.type:
            case MessageType.EXPORT_RESPONSE:
                n_completed += 1
                if message.success and (n_completed % print_step == 0):
                    percent = (n_completed / n_tasks) * 100
                    print(f"[rt][{message.thread_id}] {gender}_{emotion}:\t{n_completed:>4} / {n_tasks:>4} ({percent:.0f}%)")
            case _:
                raise AssertionError(f"[rt] In main: unhandled message type {message.type}")

    # shutdown
    for i in range(len(workers)):
        worker = workers[i]
        worker.main_to_worker.put(Message(
            type=MessageType.SHUTDOWN,
            thread_id=i
        ))

    for worker in workers:
        worker.thread.join()

    return n_completed

# ---

class Mode(str, Enum):
    ALL_GENDERS_ALL_EMOTIONS = "all",
    ONE_GENDER_ALL_EMOTIONS = "gender",
    ALL_GENDERS_ONE_EMOTION = "emotion"
    ONE_GENDER_ONE_EMOTION = "single"
    SINGLE = "file",

if __name__ == "__main__":
    import sys

    Path(EXPORT_PREFIX).mkdir(exist_ok = True)

    before = time.time()

    mode = sys.argv[1]
    assert(mode in [item for item in Mode])

    if mode == Mode.ONE_GENDER_ONE_EMOTION:
        #generate: write emotion and gender
        file_count = 0
        try:
            gender = sys.argv[2]
            emotion = sys.argv[3]
            file_count = main(gender, emotion)
        except Exception as error:
            file_count = 0

        if file_count > 0:
            print(f"[rt] succesfully wrote `{file_count}` files for `{gender}/{emotion}`")
        else:
            print(f"[rt] failed to write files for `{gender}/{emotion}`")

    # dispatch: dispatch subprocesses, this is faster than a shared threadpool
    elif mode == Mode.ALL_GENDERS_ALL_EMOTIONS:
        processes = []
        for gender in EXPORT_GENDERS:
            for emotion in EXPORT_EMOTIONS:
                processes.append(subprocess.Popen(
                    [sys.executable, __file__, Mode.ONE_GENDER_ONE_EMOTION, gender, emotion]
                ))

        for process in processes:
            process.wait()

    elif mode == Mode.ALL_GENDERS_ONE_EMOTION:
        processes = []
        emotion = sys.argv[2]
        for gender in EXPORT_GENDERS:
            processes.append(subprocess.Popen(
                [sys.executable, __file__, Mode.ONE_GENDER_ONE_EMOTION, gender, emotion]
            ))

        for process in processes:
            process.wait()

    elif mode == Mode.ONE_GENDER_ALL_EMOTIONS:
        processes = []
        gender = sys.argv[2]
        for emotion in EXPORT_EMOTIONS:
            processes.append(subprocess.Popen(
                [sys.executable, __file__, Mode.ONE_GENDER_ONE_EMOTION, gender, emotion]
            ))

        for process in processes:
            process.wait()

    # render single sentencte
    elif mode == Mode.SINGLE:
        _, _, text, path, gender, emotion = (sys.argv)[:6]

        export(0, gender, emotion, text, Path(path))
        print(f"[rt] wrote to `{path}`")

    print(f"[rt] done. Took {time.time() - before:.4f}s)")
