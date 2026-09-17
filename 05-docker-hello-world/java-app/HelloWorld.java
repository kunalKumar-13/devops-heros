import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

/**
 * Minimal Hello World web server using the JDK's built-in HTTP server,
 * so the image needs no external build tool or dependency.
 */
public class HelloWorld {

    private static final String PAGE = """
            <!doctype html>
            <html>
              <head><title>Java Hello World</title></head>
              <body style="font-family: system-ui, sans-serif; text-align: center; padding-top: 80px;">
                <h1>Hello World from Java</h1>
                <p>Served by the JDK HttpServer inside a Docker container.</p>
              </body>
            </html>
            """;

    public static void main(String[] args) throws IOException {
        int port = 8080;
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", port), 0);
        server.createContext("/", exchange -> {
            byte[] body = PAGE.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "text/html; charset=utf-8");
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(body);
            }
        });
        server.setExecutor(null);
        server.start();
        System.out.println("Java app listening on port " + port);
    }
}
