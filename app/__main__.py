#!/usr/bin/env python
import locale
import logging.handlers
import os
import threading
import zmq
from zmq.error import ContextTerminated

# setup builtins used by pylib init
import builtins

builtins.SENTRY_EXTRAS = []
from . import APP_NAME


class CredsConfig:
    sentry_dsn: f'opitem:"Sentry" opfield:{APP_NAME}.dsn' = None  # type: ignore
    cronitor_token: 'opitem:"cronitor" opfield:.password' = None  # type: ignore


builtins.creds_config = CredsConfig()

from tailucas_pylib import log, threads

from tailucas_pylib.datetime import make_timestamp
from tailucas_pylib.process import SignalHandler
from tailucas_pylib.threads import thread_nanny, die, bye
from tailucas_pylib.app import AppThread, ZmqRelay
from tailucas_pylib.zmq import zmq_term
from tailucas_pylib.handler import exception_handler


URL_WORKER_APP = "inproc://app-worker"
URL_WORKER_RELAY = "inproc://app-relay"


class DataReader(AppThread):
    def __init__(self):
        AppThread.__init__(self, name=self.__class__.__name__)
        self._prefix = "time"

    def get_data(self):
        timestamp = make_timestamp(make_string=True)
        return f"{self._prefix}: {timestamp}"

    def run(self):
        with exception_handler(
            connect_url=URL_WORKER_RELAY,
            socket_type=zmq.PUSH,
            and_raise=True,
            shutdown_on_error=True,
        ) as socket:
            while not threads.shutting_down:
                data = self.get_data()
                log.info(f"Source {data=}")
                socket.send_pyobj(data)
                threads.interruptable_sleep.wait(2)


class DataRelay(ZmqRelay):
    def __init__(self, source_zmq_url, sink_zmq_url):
        super().__init__(
            name=self.__class__.__name__,
            source_zmq_url=source_zmq_url,
            sink_zmq_url=sink_zmq_url,
        )

    def process_message(self, sink_socket):
        data = self.socket.recv_pyobj()
        log.info(f"Relay {data=}")
        sink_socket.send_pyobj(data)


class EventProcessor(AppThread):
    def __init__(self, zmq_url):
        AppThread.__init__(self, name=self.__class__.__name__)
        self._zmq_url = zmq_url

    # noinspection PyBroadException
    def run(self):
        with exception_handler(
            connect_url=self._zmq_url,
            socket_type=zmq.PULL,
            and_raise=True,
            shutdown_on_error=True
        ) as socket:
            log.info(f'Sink socket started for {self._zmq_url}.')
            while not threads.shutting_down:
                data = socket.recv_pyobj()
                log.info(f"Sink {data=}")


def main():
    log.info(f"Log level is set to {logging.getLevelName(log.getEffectiveLevel())}")
    log.info(f"Locale is set to {locale.getlocale()}.")
    # ensure proper signal handling; must be main thread
    signal_handler = SignalHandler()
    event_processor = EventProcessor(zmq_url=URL_WORKER_APP)
    data_relay = DataRelay(source_zmq_url=URL_WORKER_RELAY, sink_zmq_url=URL_WORKER_APP)
    data_reader = DataReader()
    nanny = threading.Thread(
        name="nanny", target=thread_nanny, args=(signal_handler,), daemon=True
    )
    try:
        log.info(
            f"Working directory is [{os.getcwd()}]. Starting {APP_NAME} threads..."
        )
        event_processor.start()
        data_relay.start()
        data_reader.start()
        # start thread nanny
        nanny.start()
        env_vars = list(os.environ)
        env_vars.sort()
        log.info(
            f"Startup complete with {len(env_vars)} environment variables visible: {env_vars}."
        )
        threads.interruptable_sleep.wait()
    finally:
        die()
        zmq_term()
    bye()


if __name__ == "__main__":
    main()
