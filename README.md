# 👻 GhostTouch - Zero-Trace Photo Eraser & AI Wiper (Native iOS)

Ứng dụng Native iOS (**SwiftUI + Accelerate + CoreImage**) chuyên biệt cho việc **Tẩy xóa chi tiết thừa trong ảnh** (người lạ, vật thể, logo, watermark, chữ, mụn/khuyết điểm) với khả năng **Triệt tiêu 100% mọi dấu vết chỉnh sửa & Dấu ấn AI**, giúp ảnh trông như ảnh chụp gốc tự nhiên từ camera, không thể phát hiện qua metadata hay các công cụ soi ảnh pháp chứng.

---

## 🌟 Điểm Đột Phá: "Không Dấu Vết Của Phần Mềm Hay AI"

Hầu hết các phần mềm chỉnh sửa (Photoshop, Snapseed, Meitu, PicsArt) hoặc AI Inpainting đều để lại 2 loại dấu vết:
1. **Dấu vết số trong Metadata**: `Software: Adobe Photoshop`, `CreatorTool`, `History: derived from...`, thẻ định danh bản quyền AI `C2PA / Content Credentials`, `SynthID`.
2. **Dấu vết quang học trong Pixel**: Vùng bù đắp thường bị láng mịn bất thường (Plastic/Smooth artifact), mất đi hạt nhiễu cảm biến ISO tự nhiên (Camera Sensor Noise), khiến các thuật toán phân tích ELA (Error Level Analysis) hoặc thợ soi ảnh phát hiện ngay lập tức.

**GhostTouch giải quyết triệt để cả 2 vấn đề trên:**

### 1. 🧹 Smart Eraser (Cọ Tẩy Ma Thuật Trên Thiết Bị - On-Device)
- **Fast Patch Diffusion**: Thuật toán lan truyền vi mép Navier-Stokes / Telea, xử lý tức thì (<0.1s) cho nốt ruồi, mụn, chữ ký, văn bản, vết xước nhỏ.
- **Texture Transfer & Synthesis**: Phân tích và sao chép hoa văn bề mặt lân cận cho người qua đường, dây điện, cột đèn, vật thể lớn.
- **Smooth Canvas**: Cọ vẽ mượt mà, hỗ trợ phóng to thu nhỏ 2 ngón tay (Pinch to Zoom 1x - 6x) và hiển thị con trỏ kích thước cọ trực quan.

### 2. 🔬 Tái Tạo Hạt Cảm Biến Máy Ảnh (Sensor Noise Injector)
- Thuật toán độc quyền tự động đo đạc độ lệch chuẩn hạt nhiễu ISO của các pixel ảnh gốc xung quanh vùng tẩy xóa.
- Bơm bù lớp vi hạt cảm biến tự nhiên (Micro-Grain) lên chính xác vùng đã inpaint.
- Triệt tiêu hoàn toàn cảm giác "bết láng vô lý", tạo sự đồng nhất quang học 100% giữa vùng tẩy và toàn bộ bức ảnh.

### 3. 🛡️ Triệt Tiêu Siêu Dữ Liệu & Bản Quyền AI (Zero-Trace Sanitizer)
- Tước bỏ 100% thẻ `C2PA / Content Credentials`, `SynthID`, `Adobe Firefly`, `DALL-E`, `Midjourney markers`.
- Xóa sạch lịch sử chỉnh sửa `Photoshop History`, `DocumentID`, thông số máy tính `HostComputer`.
- Tùy chọn 2 chế độ xuất ảnh:
  - **Clean Slate (Xóa Trắng Tuyệt Đối)**: 0 Byte metadata theo dõi, hoàn toàn vô danh.
  - **Apple Camouflage (Ngụy Trang Camera Apple Thật)**: Tự tạo thông số EXIF chuẩn như chụp thẳng từ Camera iPhone (Apple iPhone 15 Pro, f/1.78, 24mm, ISO 50, Apple Camera App, sRGB IEC61966-2.1) - không ai có thể biết ảnh đã qua phần mềm thứ ba.

### 4. 🔍 Bộ Soi Dấu Vết Trực Quan (Forensic Inspector & ELA Viewer)
- Tích hợp sẵn bộ phân tích mức nén **Error Level Analysis (ELA)** ngay trong app để bạn tự kiểm tra xem vùng tẩy xóa đã hoàn toàn tàng hình chưa trước khi lưu hoặc chia sẻ.
- Trình kiểm tra bảo mật siêu dữ liệu: Báo cáo trạng thái an toàn số theo thời gian thực.

### 5. ↔️ So Sánh Trước & Sau Tương Tác (Interactive Split Slider)
- Thanh trượt phân cách màn hình Before / After giúp quan sát chi tiết độ tự nhiên sau khi tẩy.

---

## 🏗️ Cấu Trúc Dự Án Native iOS (SwiftUI + XcodeGen)

```
GhostTouch_iOS/
├── .github/workflows/
│   └── build-ipa.yml             # Workflow GitHub Actions tự động build .ipa ARM64
├── project.yml                   # Cấu hình dự án chuẩn XcodeGen
├── scripts/
│   └── patch_package.py          # Patch tương thích Swift 6.2 & iOS SDK
└── GhostTouch/
    ├── App.swift                 # Điểm khởi chạy ứng dụng
    ├── Info.plist                # Khai báo quyền Camera & Thư viện ảnh
    ├── GhostTouch.entitlements   # Entitlements hỗ trợ Sideload & TrollStore
    ├── Assets.xcassets/          # App Icon Holographic Neon & Tài nguyên
    └── Sources/
        ├── Models/               # EraserConfig, EditHistory, ForensicsReport
        ├── Services/             # InpaintingEngine, SensorNoiseInjector, ZeroTraceSanitizer, ForensicAnalyzer
        ├── Views/                # CanvasEditorView, BrushControlBar, CompareView, ForensicInspectorView, ExportShareSheet
        └── Helpers/              # Color+Theme, UIImage+Extensions
```

---

## 🚀 Biên Dịch & Đóng Gói Tự Động Thành File `.ipa`

Dự án được cấu hình sẵn **GitHub Actions CI/CD** chạy trên máy chủ Apple Silicon (`macos-15`), tự động build ra file `GhostTouch-ZeroTrace.ipa` chuẩn kiến trúc **ARM64 Physical Device** (dành cho iPhone thật, không bị crash như simulator):

1. **Đẩy mã nguồn lên GitHub Repository của bạn:**
   ```bash
   git init
   git add .
   git commit -m "Initial commit GhostTouch iOS"
   git remote add origin https://github.com/Bundev-Coder/GhostTouch.git
   git branch -M main
   git push -u origin main
   ```
2. **GitHub Actions sẽ tự động kích hoạt:**
   - Cài đặt `xcodegen`
   - Tạo `GhostTouch.xcodeproj`
   - Biên dịch với cờ `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
   - Đóng gói file `.ipa` và tạo **GitHub Release** có link tải trực tiếp 1-click.

3. **Cài đặt vào iPhone thật (Không cần tài khoản $99):**
   - **TrollStore** (nếu máy có hỗ trợ TrollStore): Cài vĩnh viễn không cần ký lại.
   - **Sideloadly / AltStore / Scarlet / ESign**: Nạp trực tiếp qua máy tính hoặc chứng chỉ cá nhân miễn phí.
