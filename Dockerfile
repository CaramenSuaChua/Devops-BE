
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

# Gộp tất cả lệnh RUN chuẩn bị môi trường vào làm 1 để giảm Layer
RUN addgroup -S springgroup && adduser -S springuser -G springgroup && \
    echo "Build Time: $BUILD_DATE" > /build_info.txt && \
    apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime && \
    echo "Asia/Ho_Chi_Minh" > /etc/timezone

# Thiết lập thư mục chạy ứng dụng
WORKDIR /run

# Copy file JAR và cấp quyền luôn trong lúc copy hoặc bằng lệnh RUN gộp
COPY --from=build /app/target/*.jar app.jar

# Tạo thư mục config và phân quyền cho user non-root
RUN mkdir -p /run/config && \
    chown -R springuser:springgroup /run

# Chuyển sang user thường để pass Trivy
USER springuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar", "--spring.config.location=optional:classpath:/,optional:file:/run/src/main/resources/application.properties"]
