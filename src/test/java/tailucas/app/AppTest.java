package tailucas.app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.atomic.AtomicReference;

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
