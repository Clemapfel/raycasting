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
EXPORT_GENDERS = [ Gender.FEMALE ] #, Gender.MALE ]
EXPORT_SPEED = 1
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
    "A":   "ア", "E":   "エ", "I":   "イ", "O":   "オ", "U":   "ウ",
    "AU":  "アウ", "AI":  "アイ", "EI":  "エイ", "OU":  "オウ",
    "II":  "イイ", "UU":  "ウウ", "OI":  "オイ",
    "BI":  "ビ", "BO":  "ボ", "BU":  "ブ", "BA":  "バ", "BE":  "ベ", "BAU": "バウ", "BAI": "バイ", "BEI": "ベイ", "BOU": "ボウ", "BII": "ビイ", "BUU": "ブウ", "BOI": "ボイ",
    "DA":  "ダ", "DE":  "デ", "DI":  "ディ", "DO":  "ド", "DU":  "ドゥ", "DAU": "ダウ", "DAI": "ダイ", "DEI": "デイ", "DOU": "ドウ", "DII": "ディイ", "DUU": "ドゥウ", "DOI": "ドイ",
    "FA":  "ファ", "FE":  "フェ", "FI":  "フィ", "FO":  "フォ", "FU":  "フ", "FAU": "ファウ", "FAI": "ファイ", "FEI": "フェイ", "FOU": "フォウ", "FII": "フィイ", "FUU": "フウ", "FOI": "フォイ",
    "GA":  "ガ", "GE":  "ゲ", "GI":  "ギ", "GO":  "ゴ", "GU":  "グ", "GAU": "ガウ", "GAI": "ガイ", "GEI": "ゲイ", "GOU": "ゴウ", "GII": "ギイ", "GUU": "グウ", "GOI": "ゴイ",
    "HA":  "ハ", "HE":  "ヘ", "HI":  "ヒ", "HO":  "ホ", "HU":  "フ", "HAU": "ハウ", "HAI": "ハイ", "HEI": "ヘイ", "HOU": "ホウ", "HII": "ヒイ", "HUU": "フウ", "HOI": "ホイ",
    "JA":  "ジャ", "JE":  "ジェ", "JI":  "ジ", "JO":  "ジョ", "JU":  "ジュ", "JAU": "ジャウ", "JAI": "ジャイ", "JEI": "ジェイ", "JOU": "ジョウ", "JII": "ジイ", "JUU": "ジュウ", "JOI": "ジョイ",
    "KA":  "カ", "KE":  "ケ", "KI":  "キ", "KO":  "コ", "KU":  "ク", "KAU": "カウ", "KAI": "カイ", "KEI": "ケイ", "KOU": "コウ", "KII": "キイ", "KUU": "クウ", "KOI": "コイ",
    "MA":  "マ", "ME":  "メ", "MI":  "ミ", "MO":  "モ", "MU":  "ム", "MAU": "マウ", "MAI": "マイ", "MEI": "メイ", "MOU": "モウ", "MII": "ミイ", "MUU": "ムウ", "MOI": "モイ",
    "NA":  "ナ", "NE":  "ネ", "NI":  "ニ", "NO":  "ノ", "NU":  "ヌ", "NAU": "ナウ", "NAI": "ナイ", "NEI": "ネイ", "NOU": "ノウ", "NII": "ニイ", "NUU": "ヌウ", "NOI": "ノイ",
    "PA":  "パ", "PE":  "ペ", "PI":  "ピ", "PO":  "ポ", "PU":  "プ", "PAU": "パウ", "PAI": "パイ", "PEI": "ペイ", "POU": "ポウ", "PII": "ピイ", "PUU": "プウ", "POI": "ポイ",
    "RA":  "ラ", "RE":  "レ", "RI":  "リ", "RO":  "ロ", "RU":  "ル", "RAU": "ラウ", "RAI": "ライ", "REI": "レイ", "ROU": "ロウ", "RII": "リイ", "RUU": "ルウ", "ROI": "ロイ",
    "SA":  "サ", "SE":  "セ", "SI":  "スィ", "SO":  "ソ", "SU":  "ス", "SAU": "サウ", "SAI": "サイ", "SEI": "セイ", "SOU": "ソウ", "SII": "スィイ", "SUU": "スウ", "SOI": "ソイ",
    "SHA": "シャ", "SHE": "シェ", "SHI": "シ", "SHO": "ショ", "SHU": "シュ", "SHAU": "シャウ", "SHAI": "シャイ", "SHEI": "シェイ", "SHOU": "ショウ", "SHII": "シイ", "SHUU": "シュウ", "SHOI": "ショイ",
    "TA":  "タ", "TE":  "テ", "TI":  "ティ", "TO":  "ト", "TU":  "トゥ", "TAU": "タウ", "TAI": "タイ", "TEI": "テイ", "TOU": "トウ", "TII": "ティイ", "TUU": "トゥウ", "TOI": "トイ",
    "VA":  "ヴァ", "VE":  "ヴェ", "VI":  "ヴィ", "VO":  "ヴォ", "VU":  "ヴ", "VAU": "ヴァウ", "VAI": "ヴァイ", "VEI": "ヴェイ", "VOU": "ヴォウ", "VII": "ヴィイ", "VUU": "ヴウ", "VOI": "ヴォイ",
    "WA":  "ワ", "WE":  "ウェ", "WI":  "ウィ", "WO":  "ヲ", "WU":  "ウ", "WAU": "ワウ", "WAI": "ワイ", "WEI": "ウェイ", "WOU": "ウォウ", "WII": "ウィイ", "WUU": "ウウ", "WOI": "ウォイ",
    "YA":  "ヤ", "YE":  "イェ", "YI":  "イイ", "YO":  "ヨ", "YU":  "ユ", "YAU": "ヤウ", "YAI": "ヤイ", "YEI": "イェイ", "YOU": "ヨウ", "YII": "イイ", "YUU": "ユウ", "YOI": "ヨイ",
    "ZA":  "ザ", "ZE":  "ゼ", "ZI":  "ズィ", "ZO":  "ゾ", "ZU":  "ズ", "ZAU": "ザウ", "ZAI": "ザイ", "ZEI": "ゼイ", "ZOU": "ゾウ", "ZII": "ズィイ", "ZUU": "ズウ", "ZOI": "ゾイ",
    "N": "ン"
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

    elongation_mark = "ー"
    elongation_postfix = "_long"
    question_mark = "？"
    question_postfix = "_q"

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
                    for should_elongate in [True, False]:
                        for should_question in [True, False]:
                            japanese_copy = japanese # deep copy, 'japanese' is by reference
                            romaji_copy = romaji
                            if should_elongate:
                                japanese_copy += elongation_mark
                                romaji_copy += elongation_postfix

                            if should_question:
                                japanese_copy += question_mark
                                romaji_copy += question_postfix


                            filename = path / (romaji_copy + "." + EXPORT_FORMAT)
                            tasks.append((engine, japanese_copy, filename.as_posix()))
                            syllable_list.add(romaji_copy)

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

    return n_completed

# ---

if __name__ == "__main__":
    if True:
        before = time.time()
        file_count = 0
        try:
            file_count = main()
        except Exception as error:
            print("[rt] script failed with " + str(error))
            export_path = Path(EXPORT_PREFIX)
            if export_path.exists():
                shutil.rmtree(export_path)

        duration = time.time() - before
        print(f"done. (wrote {file_count} files in {duration:.4f}s)")
    else:
        import sys
        export("./mmda_agents/Voice/mei/mei_normal.htsvoice", sys.argv[1], "test.wav")
