package tailucas.app;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.instrumentation.log4j.appender.v2_17.OpenTelemetryAppender;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.autoconfigure.AutoConfiguredOpenTelemetrySdk;
import io.opentelemetry.sdk.resources.Resource;
import java.util.HashMap;
import java.util.Map;

/**
 * OpenTelemetry SDK bootstrap driven entirely by the standard OTEL_* environment
 * variables (OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_PROTOCOL,
 * OTEL_SERVICE_NAME, OTEL_RESOURCE_ATTRIBUTES, OTEL_SDK_DISABLED, ...).
 * See .clinerules/observability.md for the project conventions.
 */
final class OtelSupport {

    private OtelSupport() {}

    /**
     * Builds the SDK from the environment and registers it globally (required by
     * the log4j2 OpenTelemetry appender). When OTEL_SDK_DISABLED=true the result
     * is a no-op SDK, so callers never branch on configuration.
     */
    static OpenTelemetrySdk init() {
        final OpenTelemetrySdk sdk = AutoConfiguredOpenTelemetrySdk.builder()
            // demo-friendly metric cadence; standard env/sysprops still win
            .addPropertiesCustomizer(config -> {
                final Map<String, String> customized = new HashMap<>();
                if (config.getString("otel.metric.export.interval") == null) {
                    customized.put("otel.metric.export.interval", "10000");
                }
                return customized;
            })
            // identity comes from OTEL_SERVICE_NAME / OTEL_RESOURCE_ATTRIBUTES; only
            // add the instance id (an explicit service.name would override the env)
            .addResourceCustomizer((resource, config) -> resource.merge(
                Resource.create(Attributes.of(
                    AttributeKey.stringKey("service.instance.id"), appName()))))
            .build()
            .getOpenTelemetrySdk();
        GlobalOpenTelemetry.set(sdk);
        // wire the log4j2 appender (queued events are replayed on install)
        OpenTelemetryAppender.install(sdk);
        return sdk;
    }

    private static String appName() {
        String name = System.getenv("DEVICE_NAME");
        if (name == null || name.isBlank()) {
            name = System.getenv("APP_NAME");
        }
        return (name == null || name.isBlank()) ? "unknown" : name;
    }
}
