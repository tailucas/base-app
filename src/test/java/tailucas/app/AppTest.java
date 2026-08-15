package tailucas.app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import com.sun.net.httpserver.HttpServer;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.sdk.OpenTelemetrySdk;

import org.ini4j.Ini;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Unit tests for {@link App}: exercises the INI configuration handling
 * that the application entry point relies on. Config is mocked with
 * temporary fixtures so the tests never depend on physical files that
 * may be absent at build time (e.g. during container image builds).
 */
public class AppTest
{
    /**
     * Smoke test: the entry point must handle a missing ./app.conf
     * gracefully and complete without throwing. Runs on a dedicated
     * thread because App registers a shutdown hook that joins the
     * calling thread, which must be allowed to die before JVM exit.
     */
    @Test
    public void mainRunsWithoutThrowing() throws InterruptedException
    {
        // keep telemetry a no-op so the test does not reach for a collector
        System.setProperty("otel.sdk.disabled", "true");
        try {
            final AtomicReference<Throwable> failure = new AtomicReference<>();
            Thread appThread = new Thread(() -> {
                try {
                    App.main(new String[]{});
                } catch (Throwable t) {
                    failure.set(t);
                }
            }, "app-main");
            appThread.start();
            appThread.join(30_000);
            assertFalse(appThread.isAlive(), "App.main should complete within 30s");
            assertNull(failure.get(), "App.main threw");
        } finally {
            System.clearProperty("otel.sdk.disabled");
            GlobalOpenTelemetry.resetForTest();
        }
    }

    /**
     * Default behaviour: with telemetry enabled, the auto-configured SDK
     * produces recording spans with a valid trace context.
     */
    @Test
    public void otelSdkBuildsAndRecordsByDefault()
    {
        // keep the SDK recording but prevent it from reaching for a collector:
        // a default OTLP exporter would attempt to connect to localhost:4317
        System.setProperty("otel.traces.exporter", "none");
        System.setProperty("otel.metrics.exporter", "none");
        System.setProperty("otel.logs.exporter", "none");
        try {
            final OpenTelemetrySdk sdk = OtelSupport.init();
            try {
                final Span span = sdk.getTracer("test").spanBuilder("probe").startSpan();
                try {
                    assertTrue(span.getSpanContext().isValid(), "span context must be valid");
                    assertTrue(span.isRecording(), "span must be recording when SDK is enabled");
                } finally {
                    span.end();
                }
            } finally {
                sdk.close();
                GlobalOpenTelemetry.resetForTest();
            }
        } finally {
            System.clearProperty("otel.traces.exporter");
            System.clearProperty("otel.metrics.exporter");
            System.clearProperty("otel.logs.exporter");
        }
    }

    /**
     * The standard OTEL_SDK_DISABLED kill-switch must suppress export:
     * nothing may leave the JVM, even though spans are still created.
     */
    @Test
    public void otelSdkDisabledSuppressesExport() throws IOException, InterruptedException
    {
        final HttpServer server = startCountingServer();
        setExporterProperties(server);
        System.setProperty("otel.sdk.disabled", "true");
        try {
            final OpenTelemetrySdk sdk = OtelSupport.init();
            try {
                sdk.getTracer("test").spanBuilder("probe").startSpan().end();
                sdk.getSdkTracerProvider().forceFlush();
                Thread.sleep(500);
                assertEquals(0, EXPORT_CALLS.get(), "disabled SDK must not export");
            } finally {
                sdk.close();
            }
        } finally {
            clearExporterProperties();
            System.clearProperty("otel.sdk.disabled");
            GlobalOpenTelemetry.resetForTest();
            server.stop(0);
        }
    }

    /**
     * Positive control for the export path: with the SDK enabled and the
     * endpoint pointed at a local listener, a completed span is exported.
     */
    @Test
    public void otelSdkExportsWhenEnabled() throws IOException, InterruptedException
    {
        final HttpServer server = startCountingServer();
        setExporterProperties(server);
        try {
            final OpenTelemetrySdk sdk = OtelSupport.init();
            try {
                sdk.getTracer("test").spanBuilder("probe").startSpan().end();
                sdk.getSdkTracerProvider().forceFlush();
                final long deadline = System.currentTimeMillis() + 3_000;
                while (System.currentTimeMillis() < deadline && EXPORT_CALLS.get() == 0) {
                    Thread.sleep(50);
                }
                assertTrue(EXPORT_CALLS.get() > 0, "enabled SDK must export completed spans");
            } finally {
                sdk.close();
            }
        } finally {
            clearExporterProperties();
            GlobalOpenTelemetry.resetForTest();
            server.stop(0);
        }
    }

    private static final AtomicInteger EXPORT_CALLS = new AtomicInteger();

    private static HttpServer startCountingServer() throws IOException
    {
        EXPORT_CALLS.set(0);
        final HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/traces", exchange -> {
            EXPORT_CALLS.incrementAndGet();
            exchange.getRequestBody().readAllBytes();
            exchange.sendResponseHeaders(200, 0);
            exchange.close();
        });
        server.start();
        return server;
    }

    private static void setExporterProperties(final HttpServer server)
    {
        System.setProperty("otel.exporter.otlp.protocol", "http/protobuf");
        System.setProperty("otel.exporter.otlp.endpoint",
            "http://127.0.0.1:" + server.getAddress().getPort());
        System.setProperty("otel.bsp.schedule.delay", "100");
        // only exercise the trace export path; the metrics/logs exporters would
        // otherwise POST to the local listener and fail with a 404
        System.setProperty("otel.metrics.exporter", "none");
        System.setProperty("otel.logs.exporter", "none");
    }

    private static void clearExporterProperties()
    {
        System.clearProperty("otel.exporter.otlp.protocol");
        System.clearProperty("otel.exporter.otlp.endpoint");
        System.clearProperty("otel.bsp.schedule.delay");
        System.clearProperty("otel.metrics.exporter");
        System.clearProperty("otel.logs.exporter");
    }

    /**
     * App.main reads app.device_name from an ini4j config; verify that a
     * config shaped like the shipped app.conf (including env-substitution
     * placeholders) parses and yields a usable value.
     */
    @Test
    public void appConfigShapeYieldsDeviceName(@TempDir Path tempDir) throws IOException
    {
        Path iniFile = tempDir.resolve("app.conf");
        Files.writeString(iniFile, String.join("\n",
            "[app]",
            "device_name=%(DEVICE_NAME)s",
            "cronitor_monitor_key=%(CRONITOR_MONITOR_KEY)s",
            "[creds]",
            "cronitor=Cronitor/password",
            "sentry_dsn=Sentry/__APP_NAME__/dsn",
            ""));

        Ini appConfig = new Ini(iniFile.toFile());
        String deviceName = appConfig.get("app", "device_name");
        assertNotNull(deviceName, "app.device_name must be defined");
        assertFalse(deviceName.isBlank(), "app.device_name must not be blank");
    }

    /**
     * Verify the ini4j lookup semantics App depends on: present keys return
     * their values, absent sections/keys return null instead of throwing.
     */
    @Test
    public void iniLookupMatchesAppUsage(@TempDir Path tempDir) throws IOException
    {
        Path iniFile = tempDir.resolve("app.conf");
        Files.writeString(iniFile, "[app]\ndevice_name=test-device\n");

        Ini appConfig = new Ini(iniFile.toFile());
        assertEquals("test-device", appConfig.get("app", "device_name"));
        assertNull(appConfig.get("app", "missing_key"));
        assertNull(appConfig.get("missing_section", "device_name"));
    }
}
