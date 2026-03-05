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
EXPOSE 8080
