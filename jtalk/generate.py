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
EXPORT_EMOTIONS = [ Emotion.NORMAL , Emotion.HAPPY, Emotion.SAD, Emotion.ANGRY, Emotion.BASHFUL ]
EXPORT_GENDERS = [ Gender.FEMALE , Gender.MALE ]
EXPORT_SPEED = 1
EXPORT_FORMAT = Format.WAV

THREAD_COUNT = 4

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
    engine_path: str | None = None
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
                convert(temp_path, output_path)
            finally:
                if os.path.isfile(temp_path):
                    os.remove(temp_path)

        print("[rt] wrote to `" + output_path + "` using `" + engine_path + "`")
        return True

    except Exception as error:
        print("[rt] export failed: " + str(error))
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
                success = export(message.engine_path, message.text, message.output_path)
                worker_to_main.put(Message(
                    type=MessageType.EXPORT_RESPONSE,
                    engine_path=message.engine_path,
                    text=message.text,
                    output_path=message.output_path,
                    success=success,
                ))
            case MessageType.SHUTDOWN:
                shutdown_active = True
            case _:
                raise AssertionError(f"In thread_main: unhandled message type {message.type}")

    worker_to_main.put(Message(type=MessageType.SHUTDOWN_RESPONSE))

# -------------------------------------- #

phonemes = {
    "A": "ア", "I": "イ", "U": "ウ", "E": "エ", "O": "オ",

    "AA": "アー", "II": "イー", "UU": "ウー", "EE": "エー", "OO": "オー",

    "KA": "カ", "KI": "キ", "KU": "ク", "KE": "ケ", "KO": "コ",
    "GA": "ガ", "GI": "ギ", "GU": "グ", "GE": "ゲ", "GO": "ゴ",

    "SA": "サ", "SI": "シ", "SU": "ス", "SE": "セ", "SO": "ソ",
    "ZA": "ザ", "ZI": "ジ", "ZU": "ズ", "ZE": "ゼ", "ZO": "ゾ",

    "TA": "タ", "TI": "ティ", "TU": "トゥ", "TE": "テ", "TO": "ト",
    "DA": "ダ", "DI": "ディ", "DU": "ドゥ", "DE": "デ", "DO": "ド",

    "NA": "ナ", "NI": "ニ", "NU": "ヌ", "NE": "ネ", "NO": "ノ",

    "HA": "ハ", "HI": "ヒ", "HU": "フ", "HE": "ヘ", "HO": "ホ",

    "BA": "バ", "BI": "ビ", "BU": "ブ", "BE": "ベ", "BO": "ボ",
    "PA": "パ", "PI": "ピ", "PU": "プ", "PE": "ペ", "PO": "ポ",

    "MA": "マ", "MI": "ミ", "MU": "ム", "ME": "メ", "MO": "モ",

    "YA": "ヤ", "YU": "ユ", "YO": "ヨ",

    "RA": "ラ", "RI": "リ", "RU": "ル", "RE": "レ", "RO": "ロ",

    "WA": "ワ", "WI": "ウィ", "WE": "ウェ", "WO": "ウォ",

    "SHA": "シャ", "SHI": "シ", "SHU": "シュ", "SHE": "シェ", "SHO": "ショ",
    "JA": "ジャ", "JI": "ジ", "JU": "ジュ", "JE": "ジェ", "JO": "ジョ",

    "CHA": "チャ", "CHI": "チ", "CHU": "チュ", "CHE": "チェ", "CHO": "チョ",

    "TSA": "ツァ", "TSI": "ツィ", "TSU": "ツ", "TSE": "ツェ", "TSO": "ツォ",

    "FA": "ファ", "FI": "フィ", "FU": "フゥ", "FE": "フェ", "FO": "フォ",

    "VA": "ヴァ", "VI": "ヴィ", "VU": "ヴ", "VE": "ヴェ", "VO": "ヴォ",

    "THA": "タ", "THI": "ティ", "THU": "トゥ", "THE": "デ", "THO": "ド",

    "TYU": "テュ", "DYU": "デュ", "KW": "クヮ", "GW": "グヮ",

    "N": "ン",
    "Q": "ッ",
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
    export_prefix_path.mkdir(exist_ok = True)

    # build taks list
    tasks = []
    syllable_list = set()

    for gender in EXPORT_GENDERS:
        for emotion in EXPORT_EMOTIONS:
            engine = engines[gender][emotion]
            if engine is not None:
                path = export_prefix_path / gender / emotion
                path.mkdir(parents=True, exist_ok=True) # pre allocate folders in main

                for romaji, japanese in phonemes.items():
                    filename = path / (romaji + "." + EXPORT_FORMAT)
                    tasks.append((engine, japanese, filename.as_posix()))
                    syllable_list.add(romaji)

    n_tasks = len(tasks)
    worker_to_main = queue.Queue()
    workers = []

    for _ in range(min(n_tasks, THREAD_COUNT)):
        main_to_worker = queue.Queue()
        worker = Worker(
            thread=threading.Thread(target=thread_main, args=(main_to_worker, worker_to_main)),
            main_to_worker=main_to_worker,
            worker_to_main=worker_to_main,
        )
        worker.thread.start()
        workers.append(worker)

    # distribute tasks round robin
    for index, (engine_path, text, output_path) in enumerate(tasks):
        workers[index % len(workers)].main_to_worker.put(Message(
            type=MessageType.EXPORT,
            engine_path=engine_path,
            text=text,
            output_path=output_path,
        ))

    # collect responses
    n_completed = 0
    while n_completed < n_tasks:
        message = worker_to_main.get(block=True)
        match message.type:
            case MessageType.EXPORT_RESPONSE:
                n_completed += 1
            case _:
                raise AssertionError(f"In main: unhandled message type {message.type}")

    # shutdown
    for worker in workers:
        worker.main_to_worker.put(Message(type=MessageType.SHUTDOWN))

    for worker in workers:
        worker.thread.join()

    # write syllable list
    syllable_list_path = Path(EXPORT_PREFIX) / SYLLABLE_LIST_FILENAME
    syllable_list_path.unlink(missing_ok=True)

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