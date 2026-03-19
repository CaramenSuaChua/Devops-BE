# --- Stage 1: Build (Giữ nguyên) ---
FROM maven:3.8.3-openjdk-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src/ ./src/
RUN mvn clean install -DskipTests

# --- Stage 2: Production (SỬA LỖI Ở ĐÂY) ---
# Thay openjdk:17-alpine bằng eclipse-temurin:17-jre-alpine
FROM eclipse-temurin:17-jre-alpine AS production
ARG BUILD_DATE

# Thiết lập Timezone & User (Giống bản cũ của bạn nhưng chạy trên Temurin)
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime && \
    echo "Asia/Ho_Chi_Minh" > /etc/timezone && \
    addgroup -S spring && adduser -S spring -G spring

WORKDIR /app

# Ghi thông tin build
RUN echo "Build Time: $BUILD_DATE" > build_info.txt

# Copy file JAR từ stage build
# Lưu ý: /app/target/... là đường dẫn mặc định của Maven
COPY --from=build /app/target/spring-boot-ecommerce-0.0.1-SNAPSHOT.jar ./app.jar

# Phân quyền và chuyển user
RUN chown -R spring:spring /app
USER spring

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
