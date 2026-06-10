# ── Stage 1: use build arg to stamp the version into nginx.conf ───────────
FROM nginx:alpine

ARG APP_VERSION=dev
LABEL org.opencontainers.image.version="${APP_VERSION}"

# Replace placeholder in nginx.conf with real version at build time
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN sed -i "s/APP_VERSION/${APP_VERSION}/g" /etc/nginx/conf.d/default.conf

# Copy static files
COPY src/ /usr/share/nginx/html/

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
