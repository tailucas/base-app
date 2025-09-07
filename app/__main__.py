#!/usr/bin/env python
import asyncio
import locale
import logging
import os
import threading
import zmq

from tailucas_pylib.config import log, APP_NAME, app_config, creds
from tailucas_pylib.datetime import make_timestamp
from tailucas_pylib.process import SignalHandler
from tailucas_pylib.threads import thread_nanny, die, bye, shutting_down, interruptable_sleep, trigger_exception
from tailucas_pylib.app import AppThread, ZmqRelay
from tailucas_pylib.zmq import zmq_term, URL_WORKER_APP, URL_WORKER_RELAY
from tailucas_pylib.handler import exception_handler

import sentry_sdk
from sentry_sdk.integrations.asyncio import AsyncioIntegration
from sentry_sdk.integrations.sys_exit import SysExitIntegration


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
            while not shutting_down:
                data = self.get_data()
                log.info(f"Source {data=}")
                socket.send_pyobj(data)
                interruptable_sleep.wait(2)


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
            while not shutting_down:
                data = socket.recv_pyobj()
                log.info(f"Sink {data=}")


async def main():
    log.info(f"Log level is set to {logging.getLevelName(log.getEffectiveLevel())}")
    log.info(f"Locale is set to {locale.getlocale()}.")
    try:
        # sentry instrumentation
        sentry_dsn_creds_path = app_config.get("creds", "sentry_dsn").replace('__APP_NAME__', APP_NAME)
        log.info(f'Loading Sentry.io DSN from creds path {sentry_dsn_creds_path}...')
        sentry_dsn = creds.get_creds(sentry_dsn_creds_path)
        sentry_sdk.init(
            dsn=sentry_dsn,
            integrations=[
                AsyncioIntegration(),
                SysExitIntegration(capture_successful_exits=True)
            ],
            send_default_pii=True
        )
    except AssertionError as e:
        log.exception(f'Cannot set up Sentry instrumentation.')
        trigger_exception = e
        bye()
    log.info(f'Installing signal handler and starting application threads...')
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
        interruptable_sleep.wait()
    except KeyboardInterrupt:
        # important to handle explicitly to prevent main thread death
        pass
    finally:
        die()
        zmq_term()
    bye()


if __name__ == "__main__":
    asyncio.run(main())
