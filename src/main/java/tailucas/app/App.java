package tailucas.app;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;
import io.opentelemetry.sdk.OpenTelemetrySdk;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.apache.logging.log4j.core.config.plugins.util.PluginManager;
import org.ini4j.Ini;

public class App 
{
    static {
        // shaded jars cannot merge Log4j2Plugins.dat reliably; register the
        // plugin packages explicitly before the first logger is created
        PluginManager.addPackages(List.of(
            "io.opentelemetry.instrumentation.log4j.appender.v2_17",
            "org.apache.logging.log4j.layout.template.json"));
    }
    private static Logger log = LoggerFactory.getLogger(App.class);

    private static void registerShutdownHook(final OpenTelemetrySdk otel) {
        final Thread mainThread = Thread.currentThread();
        Runtime.getRuntime().addShutdownHook(new Thread("shutdown hook") {
            public void run() {
                try {
                    log.atInfo().setMessage("Shutdown hook triggered").log();
                    // flushes and terminates the telemetry pipelines
                    otel.close();
                    mainThread.join();
                } catch (InterruptedException ex) {
                    log.atError().setMessage("Interrupted while waiting for main thread").setCause(ex).log();
                }
            }
        });
    }

    public static void main( String[] args )
    {
        Thread.currentThread().setName("main");
        final OpenTelemetrySdk otel = OtelSupport.init();
        registerShutdownHook(otel);
        // one of each signal, matching the Python demo (see app/__main__.py)
        String appName = System.getenv("APP_NAME");
        if (appName == null || appName.isBlank()) {
            appName = App.class.getName();
        }
        final Tracer tracer = otel.getTracer(appName);
        final Meter meter = otel.getMeter(appName);
        final LongCounter demoCounter = meter.counterBuilder("demo_events")
            .setDescription("Demo events emitted to the OTEL collector")
            .setUnit("{events}")
            .build();
        final Span span = tracer.spanBuilder("otel-demo-startup")
            .setAttribute("app.name", appName)
            .startSpan();
        try (Scope scope = span.makeCurrent()) {
            log.atInfo().setMessage("OTEL demo log record")
                .addKeyValue("otel_endpoint", System.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
                .log();
            demoCounter.add(1, Attributes.of(AttributeKey.stringKey("event.type"), "startup"));
        } finally {
            span.end();
        }
        final Locale locale = Locale.getDefault();
        log.atInfo().setMessage("Locale")
            .addKeyValue("language", locale.getLanguage())
            .addKeyValue("country", locale.getCountry())
            .log();
        final Map<String, String> envVars = System.getenv();
        log.atInfo().setMessage("Environment variables")
            .addKeyValue("env_var_keys", envVars.keySet())
            .log();
        log.atInfo().setMessage("Java runtime")
            .addKeyValue("java_version", Runtime.version().toString())
            .log();
        Set<Thread> threadSet = Thread.getAllStackTraces().keySet();
        for (Thread thread : threadSet) {
            log.atInfo().setMessage("Thread")
                .addKeyValue("thread_name", thread.getName())
                .addKeyValue("daemon", thread.isDaemon())
                .log();
        }
        log.atInfo().setMessage("Working directory")
            .addKeyValue("work_dir", System.getProperty("user.dir"))
            .log();
        try {
            Ini appConfig = new Ini(new File("./app.conf"));
            log.atInfo().setMessage("App Device Name")
                .addKeyValue("device_name", appConfig.get("app", "device_name"))
                .log();
        } catch (IOException e) {
            log.atError().setMessage("Cannot read application configuration").setCause(e).log();
        }
        try {
            Thread.sleep(2*1000);
        } catch (InterruptedException e) {
            log.atError().setMessage("Interrupted during sleep").setCause(e).log();
        }
    }
}
