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

## Màn hình (theo Figma "POS Quán Cafe - Nhân viên")

| Route | Tablet | Điện thoại |
|---|---|---|
| `/login` | Đăng nhập email lần đầu để gắn máy với cửa hàng | như tablet |
| `/pin` | 01 Đăng nhập: bàn phím PIN 4 số (demo `1234`) | M1 |
| `/` | 02 Order chính: rail trái, tìm món, Bàn/Mang đi, danh mục, lưới 4 cột, panel Đơn hàng | M2: lưới 2 cột + thanh "n món · tổng · Xem đơn" |
| `/cart` | — | M3 Giỏ hàng |
| `/payment/:orderId` | 03 Thanh toán: Tiền mặt / VietQR / MoMo / ZaloPay, tiền thừa, mã VietQR thật | M4 |
| `/app-orders` | 04 Đơn từ app: Chờ xác nhận / Đang pha / Sẵn sàng / Hôm nay, cập nhật realtime qua WebSocket | M5 |
| `/sold-out` | Hết món: bật tắt món ở cấp cửa hàng | như tablet |
| `/shift` | Kết ca: avatar nhân viên (bấm để đổi ảnh), doanh thu, số đơn theo phương thức/nguồn, đăng xuất | như tablet |

Luồng đơn: chọn món (sheet chọn size/đá/đường/topping, ghi chú) → gắn khách tích điểm theo SĐT →
mã giảm giá → **Lưu đơn** (giữ đơn, chưa thu tiền) hoặc **Thanh toán** → xác nhận → đơn chuyển "Đang pha".
Giá do server tính lại từ menu; client chỉ ước tính để hiển thị.

## Cấu trúc

```
lib/
  main.dart                 # entry, ProviderScope (SharedPreferences override)
  app/                      # MaterialApp.router + GoRouter (redirect theo auth + device)
  core/
    config/                 # AppConfig (dart-define)
    theme/                  # brand tokens terracotta, Be Vietnam Pro
    layout/                 # Breakpoints (840px), AdaptiveLayout
    network/                # Dio client + Bearer token + chuẩn hoá lỗi httpx (tiếng Việt)
    storage/                # TokenStorage, DeviceContext (store gắn với máy)
    utils/                  # formatVnd
    widgets/                # BrandLogo
  features/
    auth/                   # login email, PIN, /auth/me, AuthController
    pos/
      domain/               # StoreMenu, Cart, Order, Customer, Promotion
      data/                 # MenuRepository, OrderRepository, realtime (WS)
      application/          # CartController, AppOrdersController
      presentation/         # PosShell (rail / bottom nav) + các trang ở bảng trên
```

State: `flutter_riverpod` 3. Routing: `go_router`. HTTP: `dio`. Realtime: `web_socket_channel` tới `/ws`.

## Backend contract đang dùng

Toàn bộ API ở `CoffeeSOSBE/docs/pos-api.md`. Tóm tắt:

| Method | Path | Ghi chú |
|---|---|---|
| POST | `/auth/login`, `/auth/pin-login` | `{email, password}` / `{storeId, pin}` → `{accessToken, expiresAt, user}` |
| GET | `/auth/me` | khôi phục session, kèm `brandName`, `storeName` |
| GET | `/pos/menu`, `/pos/store` | menu + thông tin ngân hàng VietQR |
| PATCH | `/pos/menu/items/:id/availability` | hết món ở cấp cửa hàng |
| GET/POST | `/pos/customers/lookup?phone=`, `/pos/customers` | khách tích điểm |
| GET | `/pos/promotions/:code` | mã giảm giá |
| POST/PUT | `/pos/orders`, `/pos/orders/:id` | tạo / sửa đơn đang mở |
| POST | `/pos/orders/:id/pay` | thanh toán |
| GET/PATCH | `/pos/orders`, `/pos/orders/:id/status`, `/pos/orders/summary` | đơn từ app, kết ca |
| WS | `/ws?token=` | `order.created`, `order.updated`, `menu.item.availability` |

## Deploy

Web được phục vụ tại https://dev.coffeesos.online/staff/ từ `/var/www/dev.coffeesos.online/staff` trên `hector_vps`:

```bash
./scripts/deploy.sh        # flutter build web --base-href /staff/ rồi rsync build/web/
```

Block nginx cho `/staff/` nằm ở `deploy/nginx/staff.conf`; file site đầy đủ ở repo backend `deploy/nginx/dev.coffeesos.online.conf`.
