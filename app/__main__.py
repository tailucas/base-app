#!/usr/bin/env python
import asyncio
import locale
import logging
import os
import threading
import time
from dataclasses import dataclass, field

import zmq
from opentelemetry import metrics, trace
from opentelemetry.baggage import get_all, get_baggage, set_baggage
from opentelemetry.context import Context, get_current
from opentelemetry.propagate import extract, inject
from opentelemetry.trace import SpanKind
from tailucas_pylib import APP_NAME, DEVICE_NAME, log
from tailucas_pylib.app import AppThread, ZmqRelay
from tailucas_pylib.creds import Creds
from tailucas_pylib.datetime import make_iso_timestamp
from tailucas_pylib.handler import exception_handler
from tailucas_pylib.process import SignalHandler
from tailucas_pylib.threads import (
    bye,
    die,
    interruptable_sleep,
    shutting_down,
    thread_nanny,
)
from tailucas_pylib.tracing import record_exception
from tailucas_pylib.zmq import URL_WORKER_APP, URL_WORKER_RELAY, zmq_term


@dataclass
class PipelineMessage:
    """ZMQ pipeline payload; trace_context carries W3C trace context between stages."""

    data: str
    trace_context: dict[str, str] = field(default_factory=dict)


_in_flight_counter: metrics.UpDownCounter | None = None


def _get_in_flight_counter() -> metrics.UpDownCounter:
    # lazy singleton: created after the meter provider is configured,
    # and safely NoOp when OTEL is disabled
    global _in_flight_counter
    if _in_flight_counter is None:
        _in_flight_counter = metrics.get_meter(APP_NAME).create_up_down_counter(
            name="zmq_messages_in_flight",
            description="Messages sent but not yet processed",
            unit="{messages}",
        )
    return _in_flight_counter


def _inject_with_baggage(carrier: dict[str, str], source_ctx: Context) -> None:
    # inject() serializes the given context, which must contain the active span
    # (for traceparent) plus any baggage from the source context
    ctx = get_current()
    for key, value in get_all(context=source_ctx).items():
        ctx = set_baggage(key, value, context=ctx)
    inject(carrier, context=ctx)


class DataReader(AppThread):
    def __init__(self):
        AppThread.__init__(self, name=self.__class__.__name__)
        self._prefix = "time"
        self._tracer = trace.get_tracer(APP_NAME)

    def get_data(self):
        timestamp = make_iso_timestamp()
        return f"{self._prefix}: {timestamp}"

    def run(self):
        with exception_handler(
            connect_url=URL_WORKER_RELAY,
            socket_type=zmq.PUSH,
            and_raise=True,
            shutdown_on_error=True,
        ) as socket:
            while not shutting_down:
                # root span of the pipeline trace; context travels with the message
                with self._tracer.start_as_current_span(
                    "data.generate",
                    kind=SpanKind.PRODUCER,
                    attributes={"messaging.system": "zmq"},
                ):
                    try:
                        msg = PipelineMessage(data=self.get_data())
                        _inject_with_baggage(
                            msg.trace_context,
                            set_baggage("device.name", DEVICE_NAME or APP_NAME),
                        )
                        log.info("Source data generated", extra={"data": msg.data})
                        socket.send_pyobj(msg)
                        _get_in_flight_counter().add(1)
                    except Exception as e:
                        record_exception(e)
                        raise
                interruptable_sleep.wait(2)


class DataRelay(ZmqRelay):
    def __init__(self, source_zmq_url, sink_zmq_url):
        super().__init__(
            name=self.__class__.__name__,
            source_zmq_url=source_zmq_url,
            sink_zmq_url=sink_zmq_url,
        )
        self._tracer = trace.get_tracer(APP_NAME)

    def process_message(self, sink_socket):
        msg = self.socket.recv_pyobj()
        ctx = extract(msg.trace_context)
        # continue the incoming trace, then hand a refreshed context downstream
        with self._tracer.start_as_current_span(
            "data.relay",
            context=ctx,
            attributes={"messaging.system": "zmq"},
        ) as span:
            try:
                device_name = get_baggage("device.name", context=ctx)
                if device_name:
                    span.set_attribute("device.name", str(device_name))
                log.info("Relay data received", extra={"data": msg.data})
                msg.trace_context = {}
                _inject_with_baggage(msg.trace_context, ctx)
                sink_socket.send_pyobj(msg)
            except Exception as e:
                record_exception(e)
                raise


class EventProcessor(AppThread):
    def __init__(self, zmq_url):
        AppThread.__init__(self, name=self.__class__.__name__)
        self._zmq_url = zmq_url
        self._tracer = trace.get_tracer(APP_NAME)
        self._recv_histogram = metrics.get_meter(APP_NAME).create_histogram(
            name="zmq_recv_duration_seconds",
            description="Time spent blocked in socket.recv_pyobj()",
            unit="s",
        )

    # noinspection PyBroadException
    def run(self):
        with exception_handler(
            connect_url=self._zmq_url,
            socket_type=zmq.PULL,
            and_raise=True,
            shutdown_on_error=True,
        ) as socket:
            log.info("Sink socket started", extra={"zmq_url": self._zmq_url})
            while not shutting_down:
                start = time.perf_counter()
                msg = socket.recv_pyobj()
                self._recv_histogram.record(time.perf_counter() - start)
                _get_in_flight_counter().add(-1)
                ctx = extract(msg.trace_context)
                # final span of the pipeline trace started by DataReader
                with self._tracer.start_as_current_span(
                    "data.process",
                    context=ctx,
                    kind=SpanKind.CONSUMER,
                    attributes={"messaging.system": "zmq"},
                ) as span:
                    try:
                        device_name = get_baggage("device.name", context=ctx)
                        if device_name:
                            span.set_attribute("device.name", str(device_name))
                        span.set_attribute("app.data", msg.data)
                        log.info("Sink data received", extra={"data": msg.data})
                    except Exception as e:
                        record_exception(e)
                        raise


async def main():
    log.info(
        "Log level configured",
        extra={"log_level": logging.getLevelName(log.getEffectiveLevel())},
    )
    log.info("Locale configured", extra={"locale": locale.getlocale()})
    try:
        creds = Creds()
        creds.validate_creds()
    except AssertionError:
        log.exception("Cannot set up Sentry instrumentation.")
        bye()
    log.info("Installing signal handler and starting application threads...")
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
            "Starting application threads",
            extra={"app_name": APP_NAME, "working_directory": os.getcwd()},
        )
        event_processor.start()
        data_relay.start()
        data_reader.start()
        # start thread nanny
        nanny.start()
        env_vars = list(os.environ)
        env_vars.sort()
        log.setLevel(logging.INFO)
        log.info(
            "Startup complete",
            extra={"env_var_count": len(env_vars), "env_vars": env_vars},
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
