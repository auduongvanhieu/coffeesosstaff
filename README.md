# CoffeeSOS Staff

Flutter app dành cho nhân viên quán (POS). Một codebase chạy trên **web**, **Android** và **iOS**;
layout tự thích ứng giữa tablet ngang (1280x800) và điện thoại (390x844).

## Chạy

```bash
flutter pub get
flutter run -d chrome                 # web
flutter run -d <android-device-id>    # Android
flutter run -d <ios-device-id>        # iOS
```

Mặc định gọi API tại `https://dev.coffeesos.online/api/v1`. Trỏ sang backend local:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080/api/v1 \
  --dart-define=WS_URL=ws://localhost:8080/ws
```

## Build

```bash
flutter build web --release --dart-define=API_BASE_URL=https://dev.coffeesos.online/api/v1
flutter build apk --release
flutter build ipa --release
```

## Cấu trúc

```
lib/
  main.dart                 # entry, ProviderScope
  app/                      # MaterialApp.router + GoRouter (redirect theo auth)
  core/
    config/                 # AppConfig (dart-define)
    theme/                  # brand tokens terracotta, Be Vietnam Pro
    layout/                 # Breakpoints, AdaptiveLayout (phone/tablet)
    network/                # Dio client + Bearer token + chuẩn hoá lỗi httpx
    storage/                # TokenStorage (shared_preferences)
  features/
    auth/                   # login, /auth/me, AuthController (Riverpod)
    pos/                    # StoreMenu model, /pos/menu, PosHomePage
```

State: `flutter_riverpod` 3. Routing: `go_router`. HTTP: `dio`. Realtime (sắp tới): `web_socket_channel` tới `/ws`.

## Backend contract đang dùng

| Method | Path | Ghi chú |
|---|---|---|
| POST | `/auth/login` | `{email, password}` → `{accessToken, expiresAt, user}` |
| GET | `/auth/me` | khôi phục session từ token đã lưu |
| GET | `/pos/menu` | header `X-Store-ID` khi user quản lý nhiều store |

## Deploy

Web được phục vụ tại https://dev.coffeesos.online/staff/ từ `/var/www/dev.coffeesos.online/staff` trên `hector_vps`:

```bash
./scripts/deploy.sh        # flutter build web --base-href /staff/ rồi rsync build/web/
```

Block nginx cho `/staff/` nằm ở `deploy/nginx/staff.conf`; file site đầy đủ ở repo backend `deploy/nginx/dev.coffeesos.online.conf`.
