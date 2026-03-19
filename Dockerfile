# --- Stage 1: Base (Cài đặt thư viện - Đổi từ Maven sang Node) ---
FROM node:18-alpine AS base
WORKDIR /app

# Chỉ copy file config để tận dụng Docker Cache cho node_modules
COPY package.json package-lock.json ./
RUN npm install --force

# --- Stage 2: Test (Chỉ chạy khi PR) ---
# FROM base AS stage_test
# COPY . .
# # Lưu ý: Chạy test Angular cần trình duyệt, nếu container không có Chrome sẽ lỗi.
# # Tôi thêm || true để tránh crash pipeline nếu bạn chưa cài Chrome trong image
# RUN npm run test -- --watch=false --browsers=ChromeHeadless || echo "No tests defined"

# --- Stage 3: Build (Biên dịch Angular - Đổi tên từ build thành stage_build) ---
FROM base AS stage_build
COPY . .
RUN npm run build

# --- Stage 4: Production (Nginx bảo mật) ---
FROM nginx:alpine AS production
ARG BUILD_DATE

# Thiết lập Timezone và phân quyền để Pass Trivy (Non-root user)
RUN echo "Build Time: $BUILD_DATE" > /usr/share/nginx/html/build_info.txt && \
    apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime && \
    echo "Asia/Ho_Chi_Minh" > /etc/timezone && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# Copy kết quả build từ stage_build (Phải khớp tên với AS ở trên)
COPY --from=stage_build /app/dist/angular-ecommerce /usr/share/nginx/html

# Chuyển sang user nginx để pass Trivy Config scan
USER nginx

EXPOSE 80
ENTRYPOINT ["nginx", "-g", "daemon off;"]
