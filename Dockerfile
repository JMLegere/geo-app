FROM instrumentisto/flutter:3.41.3 AS build
ARG BUILD_COMMIT_SHA=""
ARG SUPABASE_URL=""
ARG SUPABASE_ANON_KEY=""
ARG ENCOUNTER_ENGINE_MODE="legacy"
ARG ENCOUNTER_ENGINE_V3_CLIENT_VERIFIED_WRITES="false"
ARG CACHEBUST=v3-rebuild
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN rm -rf build/
RUN printf '%s' "$BUILD_COMMIT_SHA" | grep -Eq '^[0-9a-f]{40}$' && \
    SHORT=$(printf '%.7s' "$BUILD_COMMIT_SHA"); \
    BUILD_TS="$(TZ=America/Halifax date +%Y-%m-%d-%H%M)-${SHORT}" && \
    test -n "$SUPABASE_URL" && \
    test -n "$SUPABASE_ANON_KEY" && \
    flutter build web \
    "--dart-define=SUPABASE_URL=$SUPABASE_URL" \
    "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    "--dart-define=ENCOUNTER_ENGINE_MODE=$ENCOUNTER_ENGINE_MODE" \
    "--dart-define=ENCOUNTER_ENGINE_V3_CLIENT_VERIFIED_WRITES=$ENCOUNTER_ENGINE_V3_CLIENT_VERIFIED_WRITES" \
    "--dart-define=DEPLOYMENT_ENVIRONMENT=prod" \
    "--dart-define=DESKTOP_CONTROLS_AVAILABLE=true" \
    "--dart-define=DESKTOP_CONTROLS_DEFAULT=true" \
    "--dart-define=BUILD_TIMESTAMP=$BUILD_TS" \
    "--dart-define=APP_VERSION=$BUILD_COMMIT_SHA" && \
    sh tool/package_web_release_assets.sh build/web "$BUILD_COMMIT_SHA"

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
