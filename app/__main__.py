#!/usr/bin/env python
import locale
import logging.handlers
import os
import threading
import zmq
from zmq.error import ContextTerminated, Again

# setup builtins used by pylib init
import builtins
builtins.SENTRY_EXTRAS = []
from . import APP_NAME
class CredsConfig:
    sentry_dsn: f'opitem:"Sentry" opfield:{APP_NAME}.dsn' = None  # type: ignore
    cronitor_token: f'opitem:"cronitor" opfield:.password' = None  # type: ignore
builtins.creds_config = CredsConfig()

from pylib import (
    app_config,
    creds,
    device_name,
    device_name_base,
    log,
    log_handler,
)

from pylib.datetime import is_list, \
    make_timestamp, \
    make_unix_timestamp, \
    parse_datetime, \
    ISO_DATE_FORMAT
from pylib.process import SignalHandler
from pylib.rabbit import MQConnection, ZMQListener
from pylib.threads import (
    thread_nanny,
    die,
    bye,
    interruptable_sleep,
    shutting_down
)
from pylib.app import AppThread, ZmqRelay
from pylib.zmq import zmq_term, Closable
from pylib.handler import exception_handler


URL_WORKER_APP = 'inproc://app-worker'
URL_WORKER_RELAY = 'inproc://app-relay'

class DataReader(AppThread):

    def __init__(self):
        AppThread.__init__(self, name=self.__class__.__name__)
        self._prefix = 'time'

    def get_data(self):
        timestamp = make_timestamp(make_string=True)
        return f'{self._prefix}: {timestamp}'

    def run(self):
        with exception_handler(connect_url=URL_WORKER_RELAY, socket_type=zmq.PUSH, and_raise=True, shutdown_on_error=True) as socket:
            while not shutting_down:
                data = self.get_data()
                log.info(f'{data=}')
                socket.send_pyobj(data)
                interruptable_sleep.wait(2)


class DataRelay(ZmqRelay):

    def __init__(self, source_zmq_url, sink_zmq_url):
        super().__init__(
            name=self.__class__.__name__,
            source_zmq_url=source_zmq_url,
            sink_zmq_url=sink_zmq_url)

    def process_message(self, sink_socket):
        data = self.socket.recv_pyobj()
        log.info(f'{data=}')
        sink_socket.send_pyobj(data)


class EventProcessor(AppThread):

    def __init__(self):
        AppThread.__init__(self, name=self.__class__.__name__)

    # noinspection PyBroadException
    def run(self):
        with exception_handler(connect_url=URL_WORKER_APP, socket_type=zmq.PULL, and_raise=True, shutdown_on_error=True) as socket:
            while not shutting_down:
                event = socket.recv_pyobj()
                log.info(f'{event=}')


def main():
    log.setLevel(logging.DEBUG)
    log.info(f'Locale is set to {locale.getlocale()}.')
    # ensure proper signal handling; must be main thread
    signal_handler = SignalHandler()
    event_processor = EventProcessor()
    data_relay = DataRelay(
        source_zmq_url=URL_WORKER_RELAY,
        sink_zmq_url=URL_WORKER_APP)
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
        data_relay.start()
        data_reader.start()
        # start thread nanny
        nanny.start()
        env_vars = list(os.environ)
        env_vars.sort()
        log.info(f'Startup complete with {len(env_vars)} environment variables visible: {env_vars}.')
        # hang around until something goes wrong
        interruptable_sleep.wait()
        raise RuntimeWarning("Shutting down...")
    except(KeyboardInterrupt, RuntimeWarning, ContextTerminated) as e:
        log.warning(str(e))
        die()
    finally:
        zmq_term()
    bye()


if __name__ == "__main__":
    main()