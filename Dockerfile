FROM instrumentisto/flutter:3.41 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web \
    --dart-define=SUPABASE_URL=https://bfaczcsrpfcbijoaeckb.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=sb_publishable__YSJ0cAnZ91SpxX1nlRjtQ_VaTxp2yf

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Cache-bust main.dart.js reference in index.html (Flutter doesn't hash it)
RUN BUILD_HASH=$(md5sum /usr/share/nginx/html/main.dart.js | cut -c1-8) && \
    sed -i "s|main\.dart\.js|main.dart.js?v=${BUILD_HASH}|g" /usr/share/nginx/html/index.html
EXPOSE 8080
