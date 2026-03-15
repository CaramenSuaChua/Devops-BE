# ## build stage ##
# FROM maven:3.8.3-openjdk-17 as build

# WORKDIR ./src
# COPY . .

# RUN mvn install -DskipTests=true

# ## run stage ##     --spring.config.location=/run/src/main/resources/application.properties
# # FROM openjdk:17-alpine
# FROM eclipse-temurin:17-jre-alpine

# RUN unlink /etc/localtime;ln -s  /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
# COPY --from=build src/target/spring-boot-ecommerce-0.0.1-SNAPSHOT.jar /run/spring-boot-ecommerce-0.0.1-SNAPSHOT.jar

# EXPOSE 8080                                                                                                                                      
# ENTRYPOINT java -jar /run/spring-boot-ecommerce-0.0.1-SNAPSHOT.jar --spring.config.location=/run/src/main/resources/application.properties



















## STAGE 1: Build stage ##
FROM maven:3.8.3-openjdk-17-slim AS build

# Thiết lập thư mục làm việc trong container build
WORKDIR /app

# Copy file pom.xml và tải dependencies trước để tận dụng Docker Cache
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy toàn bộ mã nguồn và thực hiện build file JAR
COPY src ./src
RUN mvn package -DskipTests=true

## STAGE 2: Run stage ## 
FROM eclipse-temurin:17-jre-alpine

ARG BUILD_DATE

# 1. Tạo Group và User mới (non-root)
# -D: không tạo password, -G: gán vào group
RUN addgroup -S springgroup && adduser -S springuser -G springgroup

# 2. Thiết lập thời gian và thông tin build
RUN echo "Build Time: $BUILD_DATE" > /build_info.txt \
    && apk add --no-cache tzdata \
    && cp /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime \
    && echo "Asia/Ho_Chi_Minh" > /etc/timezone

# Thiết lập thư mục chạy ứng dụng
WORKDIR /run

# 3. Copy file JAR và tạo thư mục config
COPY --from=build /app/target/*.jar app.jar
RUN mkdir -p /run/config

# 4. QUAN TRỌNG: Cấp quyền sở hữu thư mục /run cho springuser
RUN chown -R springuser:springgroup /run

# 5. Chuyển sang sử dụng User thường thay vì root
USER springuser

EXPOSE 8080

# Chạy ứng dụng Java
ENTRYPOINT ["java", "-jar", "app.jar", "--spring.config.location=optional:classpath:/,optional:file:/run/src/main/resources/application.properties"]
