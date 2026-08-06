package tailucas.app;

import java.io.File;
import java.io.IOException;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.ini4j.Ini;

public class App 
{
    private static Logger log = LoggerFactory.getLogger(App.class);

    private static void registerShutdownHook() {
        final Thread mainThread = Thread.currentThread();
        Runtime.getRuntime().addShutdownHook(new Thread("shutdown hook") {
            public void run() {
                try {
                    log.atInfo().setMessage("Shutdown hook triggered").log();
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
        registerShutdownHook();
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
