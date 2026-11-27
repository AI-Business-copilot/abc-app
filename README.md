# ABC App

Ứng dụng Flutter dùng chung Supabase/API `abc-backend`. Hai mục **Mua hàng (F03)** và **Bán hàng (F04)** đối chiếu với API/pages purchases/sales trong `abc-frontend` và routes/services backend. Kho, Cảnh báo, Kiểm kê, Lô & Hủy vẫn truy cập được; tab đã mở giữ trạng thái khi chuyển mục.

## Chạy ứng dụng

```powershell
cd abc-app
flutter pub get
flutter run

# Điện thoại thật: thay IP/domain backend, giữ hậu tố /api.
flutter run --dart-define=API_BASE_URL=http://192.168.1.40:5000/api
```

Backend chạy theo README `abc-backend`. Mặc định: Android emulator `http://10.0.2.2:5000/api`; Web/desktop/iOS simulator `http://localhost:5000/api`. Đặt `API_BASE_URL` cho mọi nền tảng nếu cần. Không có override thì Android có thể thử LAN cho GET; GET thành công mới chuyển host cho các request sau. Request ghi không tự gửi lại khi lỗi mạng.

Đăng nhập bằng tài khoản hiện có. Token/cửa hàng dùng chung `ApiClient`. Backend xác thực lại membership, quyền, người thao tác và trạng thái chứng từ.

## F03 — Mua hàng & thanh toán NCC

| Chức năng | Truy cập |
| --- | --- |
| Tìm, phân trang, lọc NCC; tạo/sửa hồ sơ, ngừng hợp tác | Mua hàng → Nhà cung cấp |
| Tra mã số thuế lấy tên/địa chỉ | Form NCC → Tra cứu |
| Danh mục cung cấp, lịch sử nhập, mở phiếu gần nhất | Chi tiết NCC → Danh mục & lịch sử |
| Giá chào, mã/tên hàng NCC, tối thiểu, bội số, thời gian giao, ưu tiên, ghi chú; ngừng/kích hoạt cung cấp | Danh mục NCC → Chọn SKU |
| Nhập .xlsx/CSV, ánh xạ cột, xem lỗi từng dòng, xác nhận digest | Danh mục NCC → Nhập Excel / CSV |
| Đặt mua từ SKU của NCC, ngày đặt/giao, giá thỏa thuận | Tạo đơn hoặc chọn nhiều SKU từ danh mục NCC |
| Sửa đơn chưa nhận, xác nhận DRAFT, hủy chưa nhận, đóng phần thiếu | Chi tiết đơn đặt mua |
| Nhận nhiều đợt/một phần, chia SKU theo lô, NSX/HSD, trả ngay hoặc nợ | Chi tiết đơn → Kiểm đếm & nhận hàng |
| Preview token có hạn, kiểm tra tiền hàng/đã trả/nợ rồi confirm | Màn nhận hàng |
| Phiếu, dòng hàng/lô, lịch sử kho và các khoản chi | Phiếu nhận → Chi tiết |
| Trả thêm/trả hết, gửi tổng đã trả cho API | Chi tiết phiếu → Thanh toán thêm NCC |
| Sửa lượng/giá kèm snapshot cũ | Chi tiết phiếu → Sửa phiếu |
| Preview/apply công nợ tính lại từ chứng từ | Chi tiết NCC → Đối chiếu công nợ |
| Xem/mở ca của mình | Ca thanh toán |

Đọc cần `inventory.read` + `finance.read`. Ghi thêm `inventory.receive`; sửa phiếu thêm `inventory.adjust`; nhập danh mục thêm `products.manage`.

Nhận hàng preview → confirm cần `PURCHASE_DRAFT_SECRET` ở backend. Tra mã số thuế cần `CASSO_APP_ID`/`CASSO_APP_SECRET` trên server; vẫn nhập hồ sơ thủ công được. Nhập danh mục tối đa 5 MB/500 dòng, giữ cùng file/mapping/digest khi confirm. App không tự chạy migration/seed.

## F04 — Bán hàng tại quầy

1. Mở/lấy ca của mình tại **Ca & In** hoặc màn bán hàng.
2. Chọn SKU theo tên/SKU/mã vạch; lọc danh mục/còn tồn, xem lô; quét camera trên nền tảng hỗ trợ.
3. Sửa lượng, chọn/tạo khách hoặc bán khách vãng lai.
4. **Kiểm tra giá & khuyến mãi**. Đổi giỏ hàng làm preview mất hiệu lực, cần kiểm tra lại.
5. Tạo đơn, kiểm tra tổng chính thức. Nếu tổng đổi, app báo kiểm tra trước khi thu tiền; giữ đơn nháp để xử lý tiếp.
6. Tiền mặt tính tiền thừa; chuyển khoản có mã giao dịch tùy chọn. Xác nhận đã nhận đủ trước khi hoàn tất. Đơn giảm 100% không cần nhập tiền khách đưa.
7. Xem thanh toán, phân bổ FEFO, ledger và in/in lại hóa đơn từ đơn hoàn tất.

Đọc cần `orders.read`. Tạo khách/mở ca/tạo đơn/thu tiền/hủy thêm `orders.create`. Chọn SKU/xem lô thêm `inventory.read`. Chỉ người tạo đơn thao tác thanh toán/hủy nháp trong ca gốc đang mở; backend xác thực lại.

Giá, khuyến mãi, tồn tốt, FEFO và tiền do backend quyết định. Nháp không giữ chỗ/trừ kho. Chuyển khoản xác nhận thủ công. Đổi/trả/hoàn tiền thuộc F05/F06; quản lý chương trình khuyến mãi và đóng ca thuộc module riêng.

In khổ 58/80 mm qua hộp thoại hệ thống, có tùy chọn mở in một lần sau thanh toán và in lại thủ công. Lần đầu cần mạng tải phông tiếng Việt. Gọi lệnh in không chứng minh giấy đã in; kiểm tra máy in thực tế. In lỗi không thanh toán lại.

## Mất kết nối và kiểm tra

Khóa nút ghi khi xử lý. Confirm nhận hàng/tạo đơn/thanh toán mất kết nối cần tra cứu kết quả hoặc tải lại chứng từ trước khi thử tiếp; không retry ghi tự động. Tiền dùng `BigInt` theo đơn vị 1/100, giữ số thập phân chính xác.

```powershell
flutter test
dart analyze lib/features/commerce lib/features/purchases lib/features/sales lib/features/home/home_screen.dart test/commerce_test.dart
flutter build web
flutter build apk --debug
```

`test/commerce_test.dart` kiểm tra tiền/giới hạn, nhận một phần/chia lô, trả thêm NCC, payload API/multipart/snapshot, mất kết nối, chống gửi trùng, giỏ hàng/khuyến mãi và quyền. Chạy cùng test model F07/F08 hiện có. Test dùng mock, chưa thay cho kiểm tra Supabase/PostgreSQL, thiết bị và máy in thật.

Trên DB thử: NCC/danh mục → PO → nhận hai đợt/chia lô → trả thêm → đối chiếu kho/nợ; tiếp theo bán tiền mặt/chuyển khoản/giảm 100% → đối chiếu đơn/tồn/payment/ledger. Thử rớt mạng sau confirm rồi tải lại để bảo đảm không ghi hai lần. Kiểm tra chọn file, camera và in 58/80 mm trên thiết bị đích.

## Kết quả kiểm tra 23/11/2026

- Flutter: 52 test đạt (31 test commerce mới và 21 test model hiện có).
- Backend liên quan: 91 test nghiệp vụ và 4 test Swagger F03/F04 đạt; TypeScript `tsc --noEmit` đạt.
- Analyzer không có lỗi/cảnh báo trong phần code mới. Toàn app còn 6 lint mức info có sẵn trong màn sản phẩm và `main.dart`.
- Build Web thành công; Android Dart bundle debug biên dịch thành công.
- Chưa có APK: tải Gradle 8.14 bị connection reset; thử Gradle có sẵn ở chế độ offline thiếu plugin Kotlin DSL. Cần hoàn tất tải build dependencies rồi chạy lại `flutter build apk --debug`.
- Chưa kiểm thử giao dịch trên DB thật, camera/chọn file native hoặc máy in thật.
