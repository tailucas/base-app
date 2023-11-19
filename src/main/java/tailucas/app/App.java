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
                    log.info("triggered");
                    mainThread.join();
                } catch (InterruptedException ex) {
                    log.error(ex.getMessage(), ex);
                }
            }
        });
    }

    public static void main( String[] args )
    {
        Thread.currentThread().setName("main");
        registerShutdownHook();
        final Locale locale = Locale.getDefault();
        log.info("Locale: {} {}", locale.getLanguage(), locale.getCountry());
        final Map<String, String> envVars = System.getenv();
        log.info("Environment variable keys: {}", envVars.keySet());
        log.info( "Java runtime: " + Runtime.version().toString() );
        Set<Thread> threadSet = Thread.getAllStackTraces().keySet();
        for (Thread thread : threadSet) {
            log.info("{} daemon? {}", thread.getName(), thread.isDaemon());
        }
        log.info("Working directory: " + System.getProperty("user.dir"));
        try {
            Ini appConfig = new Ini(new File("./app.conf"));
            log.info("App Device Name: " + appConfig.get("app", "device_name"));
        } catch (IOException e) {
            log.error(e.getMessage(), e);
        }
        try {
            Thread.sleep(2*1000);
        } catch (InterruptedException e) {
            log.error(e.getMessage(), e);
        }
    }
}
