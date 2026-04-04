FROM instrumentisto/flutter:3.41 AS build
ARG RAILWAY_GIT_COMMIT_SHA=""
ARG CACHEBUST=v3-rebuild
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN rm -rf build/
RUN SHORT=$(printf '%.7s' "$RAILWAY_GIT_COMMIT_SHA"); \
    BUILD_TS="v3 $(date -u +%Y-%m-%d-%H%M)${SHORT:+-$SHORT}" && \
    flutter build web \
    --dart-define=SUPABASE_URL=https://bfaczcsrpfcbijoaeckb.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmYWN6Y3NycGZjYmlqb2FlY2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NzE3ODYsImV4cCI6MjA4ODE0Nzc4Nn0.hyjp1NRiteavWfBnch1LpRARtiN5lvpP0PztbRwqPJ8 \
    "--dart-define=BUILD_TIMESTAMP=$BUILD_TS" \
    "--dart-define=APP_VERSION=$BUILD_TS"

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN BUILD_HASH=$(md5sum /usr/share/nginx/html/main.dart.js | cut -c1-8) && \
    sed -i "s|main\.dart\.js|main.dart.js?v=${BUILD_HASH}|g" /usr/share/nginx/html/flutter_bootstrap.js
EXPOSE 8080
