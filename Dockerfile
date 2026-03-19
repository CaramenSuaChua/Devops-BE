# --- Stage 1: Build Stage (Dùng Maven để đóng gói file JAR) ---
FROM maven:3.8.3-openjdk-17 AS build
WORKDIR /app

# Thay vì COPY . ., liệt kê cụ thể để tránh lỗi bảo mật DS002 của Trivy
COPY pom.xml .
COPY src/ ./src/

# Chạy lệnh build (Install) và bỏ qua Test để nhanh hơn
RUN mvn clean install -DskipTests

# --- Stage 2: Run Stage (Image thực thi siêu nhẹ) ---
FROM openjdk:17-alpine AS production
ARG BUILD_DATE

# 1. Thiết lập Timezone Hồ Chí Minh và tạo User Non-root để bảo mật
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime && \
    echo "Asia/Ho_Chi_Minh" > /etc/timezone && \
    # Tạo user 'spring' để chạy ứng dụng (Pass Trivy Scan)
    addgroup -S spring && adduser -S spring -G spring && \
    # Ghi lại thông tin build
    echo "Build Time: $BUILD_DATE" > /app/build_info.txt

WORKDIR /app

# 2. Copy file JAR từ stage build sang (Đảm bảo đường dẫn nguồn /app/target/...)
# Chúng ta đổi tên file đích thành app.jar cho ngắn gọn và bảo mật
COPY --from=build /app/target/spring-boot-ecommerce-0.0.1-SNAPSHOT.jar ./app.jar

# 3. Phân quyền cho user thường
RUN chown -R spring:spring /app
USER spring

EXPOSE 8080

# Sử dụng mảng [] cho ENTRYPOINT để quản lý tín hiệu tốt hơn
ENTRYPOINT ["java", "-jar", "app.jar"]
