FROM instrumentisto/flutter:3.41 AS build
ARG RAILWAY_GIT_COMMIT_SHA=""
ARG SUPABASE_URL=""
ARG SUPABASE_ANON_KEY=""
ARG CACHEBUST=v3-rebuild
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN rm -rf build/
RUN SHORT=$(printf '%.7s' "$RAILWAY_GIT_COMMIT_SHA"); \
    SHORT=${SHORT:-$(git -C /app rev-parse --short HEAD 2>/dev/null || echo "local")}; \
    BUILD_TS="$(TZ=America/Halifax date +%Y-%m-%d-%H%M)-${SHORT}" && \
    test -n "$SUPABASE_URL" && \
    test -n "$SUPABASE_ANON_KEY" && \
    flutter build web \
    "--dart-define=SUPABASE_URL=$SUPABASE_URL" \
    "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    "--dart-define=BUILD_TIMESTAMP=$BUILD_TS" \
    "--dart-define=APP_VERSION=$BUILD_TS"

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN BUILD_HASH=$(md5sum /usr/share/nginx/html/main.dart.js | cut -c1-8) && \
    sed -i "s|main\.dart\.js|main.dart.js?v=${BUILD_HASH}|g" /usr/share/nginx/html/flutter_bootstrap.js
EXPOSE 8080
