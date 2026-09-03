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
