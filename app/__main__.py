#!/usr/bin/env python
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
    cronitor_token: f'opitem:"cronitor" opfield:.password' = None  # type: ignore
builtins.creds_config = CredsConfig()

from pylib import app_config, \
    creds, \
    device_name, \
    device_name_base, \
    log, \
    log_handler, \
    threads

from pylib.datetime import is_list, \
    make_timestamp, \
    make_unix_timestamp, \
    parse_datetime, \
    ISO_DATE_FORMAT
from pylib.process import SignalHandler
from pylib.rabbit import MQConnection, ZMQListener
from pylib.threads import thread_nanny, die, bye
from pylib.app import AppThread, ZmqRelay
from pylib.zmq import zmq_term, Closable
from pylib.handler import exception_handler


URL_WORKER_APP = 'inproc://app-worker'


class DataReader(AppThread, Closable):

    def __init__(self):
        AppThread.__init__(self, name=self.__class__.__name__)
        Closable.__init__(self)

        self.processor = self.get_socket(zmq.PUSH)  # type: ignore

        self._prefix = 'time'

    def get_data(self):
        timestamp = make_timestamp(make_string=True)
        return f'{self._prefix}: {timestamp}'

    def run(self):
        self.processor.connect(URL_WORKER_APP)
        with exception_handler(closable=self):
            while not threads.shutting_down:
                data = self.get_data()
                log.debug(f'Data is {data}')
                threads.interruptable_sleep.wait(60)


class EventProcessor(AppThread, Closable):

    def __init__(self):
        AppThread.__init__(self, name=self.__class__.__name__)
        Closable.__init__(self, connect_url=URL_WORKER_APP)

    # noinspection PyBroadException
    def run(self):
        with exception_handler(closable=self, and_raise=False, shutdown_on_error=True):
            while not threads.shutting_down:
                event = self.socket.recv_pyobj()
                log.debug(event)


def main():
    log.setLevel(logging.INFO)
    # ensure proper signal handling; must be main thread
    signal_handler = SignalHandler()
    event_processor = EventProcessor()
    data_reader = DataReader()
    nanny = threading.Thread(
        name='nanny',
        target=thread_nanny,
        args=(signal_handler,),
        daemon=True)
    # startup completed
    # back to INFO logging
    log.setLevel(logging.INFO)
    try:
        log.info(f'Working directory is [{os.getcwd()}]. Starting {APP_NAME} threads...')
        event_processor.start()
        data_reader.start()
        # start thread nanny
        nanny.start()
        env_vars = list(os.environ)
        env_vars.sort()
        log.info(f'Startup complete with {len(env_vars)} environment variables visible: {env_vars}.')
        # hang around until something goes wrong
        threads.interruptable_sleep.wait()
        raise RuntimeWarning("Shutting down...")
    except(KeyboardInterrupt, RuntimeWarning, ContextTerminated) as e:
        log.warning(str(e))
        threads.shutting_down = True
        threads.interruptable_sleep.set()
    finally:
        zmq_term()
    bye()


if __name__ == "__main__":
    main()