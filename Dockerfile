



## STAGE 1: Build stage ##
FROM maven:3.8.3-openjdk-17-slim AS build

# Thiết lập thư mục làm việc trong container build
WORKDIR /app

# Chỉ copy file config để tận dụng Docker Cache cho node_modules
COPY package.json package-lock.json ./
RUN npm install --force

# # --- Stage 2: Test (Chỉ chạy khi PR) ---
# FROM base AS test
# COPY . .
# RUN npm run test -- --watch=false --browsers=ChromeHeadless || echo "No tests defined"

# --- Stage 3: Build (Biên dịch Angular) ---
FROM base AS build
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

# Copy kết quả build từ stage trước
COPY --from=build /app/dist/angular-ecommerce /usr/share/nginx/html

# Chuyển sang user nginx để pass Trivy Config scan
USER nginx

EXPOSE 80
ENTRYPOINT ["nginx", "-g", "daemon off;"]
