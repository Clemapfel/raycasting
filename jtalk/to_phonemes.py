import sys
from g2p_en import G2p
import threading
import queue
import os
from enum import Enum
from dataclasses import dataclass

THREAD_COUNT = 3

class MessageType(Enum):
    TRANSLATE = 1
    TRANSLATE_RESPONSE = 2
    SHUTDOWN = 3
    SHUTDOWN_RESPONSE = 4

@dataclass
class Message:
    type: MessageType
    argument_index: int | None = None
    to_translate: str | None = None
    translation: list[str] | None = None

@dataclass
class Worker:
    thread: threading.Thread
    main_to_worker: queue.Queue
    worker_to_main: queue.Queue

def thread_main(main_to_worker, worker_to_main):
    g2p = G2p()
    shutdown_active = False
    while True:
        if main_to_worker.empty() and shutdown_active:
            break

        message = main_to_worker.get(block=True)
        match message.type:
            case MessageType.TRANSLATE:
                worker_to_main.put(Message(
                    type=MessageType.TRANSLATE_RESPONSE,
                    argument_index=message.argument_index,
                    to_translate=message.to_translate,
                    translation=g2p(message.to_translate),
                ))
            case MessageType.SHUTDOWN:
                shutdown_active = True
            case _:
                raise AssertionError(f"In thread_main: unhandled message type {message.type}")

    worker_to_main.put(Message(type=MessageType.SHUTDOWN_RESPONSE))

def text_to_phonemes_lua(phonemes):
    return "{ " + ", ".join(f'"{phoneme}"' for phoneme in phonemes) + " }"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <string1> <string2> ...")
        sys.exit(1)

    arguments = sys.argv[1:]
    n_tasks = len(arguments)
    worker_to_main = queue.Queue()
    workers = []

    # distribute tasks round robin

    for _ in range(min(n_tasks, THREAD_COUNT)):
        main_to_worker = queue.Queue()
        worker = Worker(
            thread=threading.Thread(target=thread_main, args=(main_to_worker, worker_to_main)),
            main_to_worker=main_to_worker,
            worker_to_main=worker_to_main,
        )
        worker.thread.start()
        workers.append(worker)

    for index, text in enumerate(arguments):
        workers[index % len(workers)].main_to_worker.put(Message(
            type=MessageType.TRANSLATE,
            argument_index=index,
            to_translate=text,
        ))

    # wait for translations

    translations = [None] * n_tasks # presize
    n_translated = 0
    n_shutdown = 0

    while n_translated < n_tasks:
        message = worker_to_main.get(block=True)
        match message.type:
            case MessageType.TRANSLATE_RESPONSE:
                translations[message.argument_index] = message.translation
                n_translated += 1
            case _:
                raise AssertionError(f"In main: unhandled message type {message.type}")

    # safe shutdown

    for worker in workers:
        worker.main_to_worker.put(Message(
            type=MessageType.SHUTDOWN
        ))

    for worker in workers:
        worker.thread.join()

    print("return " + ", ".join(text_to_phonemes_lua(phonemes) for phonemes in translations))