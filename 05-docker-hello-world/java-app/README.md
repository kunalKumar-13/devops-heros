# Java Hello World (JDK HttpServer)

A Hello World web server built on the JDK's own `com.sun.net.httpserver.HttpServer`,
so the image needs no Maven, Gradle or third-party dependency.

| File | Purpose |
|---|---|
| `HelloWorld.java` | the server, listening on port 8080 |
| `Dockerfile` | two stages: compile with the **JDK**, run on the **JRE** |

**Dockerfile notes:** this is already a small multi-stage build — `eclipse-temurin:21-jdk`
compiles the class, and only the compiled output is copied into
`eclipse-temurin:21-jre`, so the compiler never ships in the final image.

## Build and run

```bash
cd java-app
docker build -t hello-java .
docker run -d --name java-hello -p 8180:8080 hello-java
```

Then open **http://localhost:8180**

## Real build and run output

```console
kunal@kunal-devops:~/devops-homework/05-docker-hello-world/java-app$ cat Dockerfile
# ---- build stage: compile the class with a full JDK ----
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY HelloWorld.java ./
RUN javac -d /out HelloWorld.java

# ---- run stage: ship only the compiled class on a JRE ----
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /out ./

EXPOSE 8080

CMD ["java", "HelloWorld"]

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/java-app$ docker build -t hello-java .
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon  7.168kB

Step 1/9 : FROM eclipse-temurin:21-jdk AS build
21-jdk: Pulling from library/eclipse-temurin
c3f3f88309df: Pulling fs layer
0ae32d51e549: Pulling fs layer
ed8299a102e9: Pulling fs layer
baffb41879ca: Pulling fs layer
ff9661c3ca29: Pulling fs layer
50914c2b24a1: Pulling fs layer
ff9661c3ca29: Download complete
0ae32d51e549: Download complete
50914c2b24a1: Download complete
c6cd40608b2e: Download complete
c3f3f88309df: Download complete
993450fd8f14: Download complete
ed8299a102e9: Download complete
50914c2b24a1: Pull complete
ed8299a102e9: Pull complete
c3f3f88309df: Pull complete
baffb41879ca: Download complete
ff9661c3ca29: Pull complete
0ae32d51e549: Pull complete
baffb41879ca: Pull complete
Digest: sha256:85f00967bcc624fc19fa9c2cf124ea426a5363898e267141726f31f358c2e14b
Status: Downloaded newer image for eclipse-temurin:21-jdk
 ---> 85f00967bcc6
Step 2/9 : WORKDIR /src
 ---> Running in 52c604cd394a
 ---> Removed intermediate container 52c604cd394a
 ---> 6e880288ca14
Step 3/9 : COPY HelloWorld.java ./
 ---> ea42171d1378
Step 4/9 : RUN javac -d /out HelloWorld.java
 ---> Running in ecb6665b731e
 ---> Removed intermediate container ecb6665b731e
 ---> 1b3b78fbd9c2
Step 5/9 : FROM eclipse-temurin:21-jre
21-jre: Pulling from library/eclipse-temurin
ef4fb6794bcf: Pulling fs layer
2d4fe310559d: Pulling fs layer
f412f7e21d80: Pulling fs layer
b6bdfedf7f6d: Pulling fs layer
ef4fb6794bcf: Download complete
f412f7e21d80: Download complete
19322d9fcdaf: Download complete
b6bdfedf7f6d: Download complete
b6bdfedf7f6d: Pull complete
af63669e338c: Download complete
2d4fe310559d: Download complete
2d4fe310559d: Pull complete
ef4fb6794bcf: Pull complete
f412f7e21d80: Pull complete
Digest: sha256:7a65df4b22d2de92d4e04056e884f3b9122d70b21e2847fd66084278bd0ce037
Status: Downloaded newer image for eclipse-temurin:21-jre
 ---> 7a65df4b22d2
Step 6/9 : WORKDIR /app
 ---> Running in 2e033515286a
 ---> Removed intermediate container 2e033515286a
 ---> 85d881d099d2
Step 7/9 : COPY --from=build /out ./
 ---> fc71a2439c00
Step 8/9 : EXPOSE 8080
 ---> Running in 5cdc965d09ee
 ---> Removed intermediate container 5cdc965d09ee
 ---> 71c58c4a548f
Step 9/9 : CMD ["java", "HelloWorld"]
 ---> Running in 00a0765e51d0
 ---> Removed intermediate container 00a0765e51d0
 ---> fed993be3872
Successfully built fed993be3872
Successfully tagged hello-java:latest

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/java-app$ docker run -d --name java-hello -p 8180:8080 hello-java
060fa82a28ce3b3567beb9fb8b9a4526479fb7f7c7db8aa9af607886c09c467a

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/java-app$ docker ps --filter name=java-hello --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
NAMES        IMAGE        STATUS         PORTS
java-hello   hello-java   Up 4 seconds   0.0.0.0:8180->8080/tcp, [::]:8180->8080/tcp
```

## Screenshot

![Java Hello World (JDK HttpServer)](../screenshots/java-app.png)
