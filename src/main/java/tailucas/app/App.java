package tailucas.app;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.util.List;
import java.util.Set;

import org.apache.logging.log4j.Level;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.core.Appender;
import org.apache.logging.log4j.core.Filter;
import org.apache.logging.log4j.core.LoggerContext;
import org.apache.logging.log4j.core.appender.FileAppender;
import org.apache.logging.log4j.core.config.Configuration;
import org.apache.logging.log4j.core.config.LoggerConfig;
import org.zeromq.ZMQ;

import com.sanctionco.opconnect.OPConnectClient;
import com.sanctionco.opconnect.OPConnectClientBuilder;
import com.sanctionco.opconnect.model.Vault;

import org.zeromq.ZContext;
import org.zeromq.SocketType;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Hello world!
 *
 */
public class App 
{
    private static void registerShutdownHook() {
        final Thread mainThread = Thread.currentThread();
        Runtime.getRuntime().addShutdownHook(new Thread() {
            public void run() {
                try {
                    System.out.println("Shutdown");
                    mainThread.join();
                } catch (InterruptedException ex) {
                    System.out.println(ex);
                }
            }
        });
    }

    public static String opRequest(String httpMethod) {
        final String opServerAddr = System.getenv("OP_CONNECT_SERVER");
        final String opToken = System.getenv("OP_CONNECT_TOKEN");
        System.out.println("OP server is " + opServerAddr);
        String response = null;
        try {
            HttpURLConnection.setFollowRedirects(false);
            URL url = URI.create(opServerAddr+httpMethod).toURL();
            HttpURLConnection con = (HttpURLConnection) url.openConnection();
            con.setRequestMethod("GET");
            con.setRequestProperty("Authorization", "Bearer " + opToken);
            con.setRequestProperty("Content-type", "application/json");
            con.setConnectTimeout(1000);
            con.setReadTimeout(1000);
            int status = con.getResponseCode();
            System.out.println("1p response: " + status);
            InputStreamReader sRx = null;
            if (status > 299) {
                sRx = new InputStreamReader(con.getErrorStream());
            } else {
                sRx = new InputStreamReader(con.getInputStream());
            }
            BufferedReader in = new BufferedReader(sRx);
            String inputLine;
            StringBuffer content = new StringBuffer();
            while ((inputLine = in.readLine()) != null) {
                content.append(inputLine);
            }
            response = content.toString();
            System.out.println(response);
            in.close();
            con.disconnect();
        } catch (MalformedURLException e) {
            System.err.println(e);
        } catch (IOException e) {
            System.err.println(e);
        }
        return response;
    }

    private static final Logger logger = LogManager.getLogger(App.class);
    public static void main( String[] args )
    {
        //registerShutdownHook();
        /*
        String opHealth = opRequest("/health");
        JSONObject health = new JSONObject(opHealth);
        System.out.println(health);
        String opVaults = opRequest("/v1/vaults");
        JSONArray vaults = new JSONArray(opVaults);
        for (int i=0; i<vaults.length(); i++) {
            JSONObject vault = vaults.getJSONObject(i);
            System.out.println(vault.getString("id"));
        }
        */

        final String opServerAddr = System.getenv("OP_CONNECT_SERVER");
        final String opToken = System.getenv("OP_CONNECT_TOKEN");

        OPConnectClient client = OPConnectClientBuilder.builder()
            .withEndpoint(opServerAddr)
            .withAccessToken(opToken)
            .build();
        List<Vault> vaults = client.listVaults().join();
        System.out.println(vaults);
        client.close();

        final String javaVersion = Runtime.version().toString();
        ZContext context = new ZContext();
        ZMQ.Socket socket = context.createSocket(SocketType.PUSH);
        System.out.println( "Hello (print) " + javaVersion );
        logger.trace("Hello (trace) {} ", javaVersion);
        logger.debug("Hello (debug) {} ", javaVersion);
        logger.info("Hello (info) {} ", javaVersion);
        logger.error("Hello? (error) {}", javaVersion);
        logger.fatal("Hello?! (fatal) {}", javaVersion);
        final Level defaultLevel = LogManager.getRootLogger().getLevel();
        System.out.println("Current log level is: " + defaultLevel);
        System.out.println("Changing log level for file appender...");
        final LoggerContext ctx = (LoggerContext) LogManager.getContext(false);
        final Configuration config = ctx.getConfiguration();
        LoggerConfig rootLoggerConfig = config.getLoggers().get("");
        System.out.println("Config is: " + rootLoggerConfig);
        final FileAppender appender = (FileAppender) rootLoggerConfig.getAppenders().get("file");
        System.out.println("Appender is: " + appender);
        final Filter filter = appender.getFilter();
        System.out.println("Filter is " + filter);
        System.out.println("Adding appender with no filter...");
        appender.removeFilter(filter);
        logger.debug("Hello (DEBUG (should see)) {} ", javaVersion);
        appender.addFilter(filter);
        logger.debug("Hello (DEBUG (should NOT see)) {} ", javaVersion);
        context.close();
        Set<Thread> threadSet = Thread.getAllStackTraces().keySet();
        for (Thread thread : threadSet) {
            System.out.println("Thread: " + thread + " daemon? " + thread.isDaemon());
        }
    }
}
