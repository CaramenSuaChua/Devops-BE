FROM node:18-alpine AS base
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install --force

# --- Stage 2: Build (Dùng lệnh COPY an toàn hơn) ---
FROM base AS stage_build
# Nhờ .dockerignore, lệnh này sẽ không copy node_modules hay .git
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
