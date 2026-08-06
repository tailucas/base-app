---
paths:
  - "app/**"
  - "src/**"
  - "internal/**"
  - "rapp/**"
  - "rlib/**"
  - "pom.xml"
---

# Structured Logging Standard (base-app)

All runtimes in this project log in **structured** style: a static event
message plus key/value fields. Interpolated log messages (f-strings,
`%`-placeholders, `{}` placeholders, string concatenation) are prohibited.

## Python (`app/`)

The logger comes from the shared library:

```python
from tailucas_pylib import log

log.info("Sink socket started", extra={"zmq_url": self._zmq_url})
log.info(
    "Startup complete",
    extra={"env_var_count": len(env_vars), "env_vars": env_vars},
)
```

Rules:

1. Static message describing the event; all data in `extra` as a dict with
   `snake_case` keys.
2. Never `log.info(f"... {var}")`, `log.info("%s", var)`,
   `log.info("{}...".format(var))`, or message concatenation.
3. Exceptions: `log.exception("Static message", extra={...})` or
   `exc_info=True`.
4. Never log secrets (use masked hints or `*_set` booleans).
5. Output is JSON (python-json-logger) via pylib: stdout below ERROR, stderr
   from ERROR up; `SYSLOG_ADDRESS` routes INFO+ to syslog when configured.

## Java (`src/`)

Use the SLF4J 2.x **fluent logging API** backed by Log4j2 with
`JsonTemplateLayout` (Logstash JSON event layout), configured in
`src/main/resources/log4j2.xml`:

```java
log.atInfo().setMessage("App Device Name")
    .addKeyValue("device_name", appConfig.get("app", "device_name"))
    .log();

log.atError().setMessage("Cannot read application configuration").setCause(e).log();
```

Rules:

1. Always `log.at<Level>().setMessage(...).addKeyValue(...).log()`; chain one
   `addKeyValue` per field. Exceptions use `.setCause(e)`.
2. Never `log.info("Locale: {} {}", a, b)`, `log.info("Java runtime: " + v)`,
   or any message built with interpolation/concatenation.
3. Conditional logging uses the builder's level check, e.g.
   `log.atDebug().setMessage(...).log()` only when enabled; prefer
   `log.isEnabledForLevel(Level.DEBUG)` guards for expensive field assembly.
4. `log4j2.xml` uses `JsonTemplateLayout` with
   `classpath:LogstashJsonEventLayoutV1.json` on the Console appender; root
   level comes from `${env:LOG_LEVEL:-INFO}`. The Syslog appender snippet is
   opt-in (uncomment + define `SYSLOG_HOST`).
5. Dependencies: `log4j-core`, `log4j-slf4j2-impl`,
   `log4j-layout-template-json` (pinned via `log4j.version` in `pom.xml`) with
   `slf4j-api`. Do not reintroduce `slf4j-simple`.

## Go (`internal/`)

Use the standard library `log/slog` with structured attributes:

```go
slog.Info("hello", "component", "main")
```

Avoid `fmt.Println` for anything operational.

## Rust (`rapp/`, `rlib/`)

For operational logging, use a structured facade (`tracing` or `log` with a
JSON emitter) rather than `println!`. Demo output may use `println!` only
where no logging semantics are intended.

## Levels

| Level | Use |
|---|---|
| DEBUG | internal state, per-message tracing |
| INFO | lifecycle and business events |
| WARNING | recoverable problems, retries, degraded mode |
| ERROR | failures needing attention |
| CRITICAL | reserved |
