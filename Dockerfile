
# Build
FROM gradle:jdk11 as build
COPY --chown=gradle:gradle . /home/gradle/project
WORKDIR /home/gradle/project
RUN ./gradlew build -x test bootjar --no-daemon

# Extract Layers from Application
FROM adoptopenjdk/openjdk11:alpine-jre as backend
WORKDIR application
COPY --from=build /home/gradle/project/build/libs/*.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

# Package Lean Application
FROM adoptopenjdk/openjdk11:alpine-jre
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
WORKDIR application
## NOTE: Shekhar added 'RUN true' after COPY command due to a bug which makes docker build on linux
## fail most of the time with "failed to export image: failed to create image: failed to get layer" message
## More info: https://github.com/moby/moby/issues/37965
## https://github.com/darkmattercoder/qt-build/commit/dc07f2cf8e9062ad3ea6ff63c482fc1ed5a2668d
COPY --from=backend application/dependencies/ ./
RUN true
COPY --from=backend application/spring-boot-loader/ ./
RUN true
COPY --from=backend application/snapshot-dependencies/ ./
RUN true
COPY --from=backend application/application/ ./
RUN true
EXPOSE 8080
ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
