# 🎓 IELTS Vision - Hệ Thống Học Tiếng Anh Thông Minh Tích Hợp AI Vision & FastAPI

Ứng dụng học từ vựng và luyện thi 4 kỹ năng IELTS chuẩn quốc tế, kết hợp nhận diện vật thể AI on-device/server-side qua **YOLOv8**, trợ lý chấm điểm & sinh nội dung **Local Ollama LLM** (Qwen 2.5 / Phi-3 / Llama 3), giao diện đa nền tảng **Flutter**, tầng backend trung tâm **FastAPI** và lưu trữ đồng bộ đám mây **Supabase Cloud**.

---

## 🌟 Tính Năng Nổi Bật Mới (Nhánh `feature/updateBEskils`)

### 1. 🔐 Xác Thực & Bảo Mật Nâng Cao
- **Đăng ký & Đăng nhập**: Hỗ trợ JWT Token bảo mật 24 giờ.
- **Xác thực khuôn mặt (Face Auth)**: Đăng nhập nhanh bằng sinh trắc học khuôn mặt.
- **Quên mật khẩu & OTP qua Email**: Gửi mã OTP bảo mật 6 số qua Gmail SMTP để khôi phục mật khẩu hoặc xác thực tài khoản.
- **Cấu hình Server IP động**: Chỉnh sửa địa chỉ IP server backend trực tiếp từ dialog trên màn hình Login (thuận tiện test trên thiết bị thật cùng mạng Wi-Fi/LAN).

### 2. 👁️ AI Vision & Camera Scan Từ Vựng
- **Nhận diện vật thể YOLOv8**: Hỗ trợ 82 lớp đối tượng chuẩn COCO, nhận diện real-time.
- **Deep Scan & Object Tracker**: Quét chuyên sâu qua Ollama Vision để sinh từ vựng ngữ cảnh, bám vết đối tượng thời gian thực (`ObjectTracker`).
- **Từ điển tương tác**: Xem phiên âm IPA, định nghĩa, ví dụ câu, từ đồng nghĩa/trái nghĩa và lưu nhanh vào Sổ tay từ vựng.

### 3. 📚 Học Từ Vựng Thông Minh (Vocab Learning)
- Học theo các cấp độ chuẩn CEFR (A1 -> C2).
- AI sinh Flashcard thông minh kèm bài tập đặt câu.
- Tự động đánh giá ngữ pháp và cách dùng từ trong câu người học đặt qua Ollama Qwen 2.5.
- Bài kiểm tra trắc nghiệm (Quiz) củng cố kiến thức và tính điểm độ thuần thục (Mastery level).

### 4. ✍️ Luyện Thi 4 Kỹ Năng IELTS & Chấm Điểm AI
- **IELTS Writing Practice**:
  - Hỗ trợ cả **Task 1** (với biểu đồ động `DynamicIeltsChartWidget`: Cột, Đường, Tròn) và **Task 2** (nghị luận xã hội).
  - **AI Grading Engine**: Tự động chấm điểm và đánh giá chuẩn 4 tiêu chí chấm thi IELTS:
    1. *Task Achievement / Task Response (TR)*
    2. *Coherence & Cohesion (CC)*
    3. *Lexical Resource (LR)*
    4. *Grammatical Range & Accuracy (GRA)*
  - Dự đoán Overall Band Score, chỉ ra điểm mạnh, điểm cần cải thiện và gợi ý bài viết mẫu đạt Band 8.0+.
- **Lịch sử Chấm Điểm AI (AI Grading History)**: Xem lại chi tiết từng lần nộp bài, điểm số 4 tiêu chí và lời khuyên của AI.
- **IELTS Reading & Listening Practice**:
  - Giao diện làm bài trực quan, tích hợp trình phát audio cho bài nghe.
  - Chấm điểm tức thì, xem giải thích chi tiết từng câu hỏi hỗ trợ bởi AI (`explainAnswer`).

### 5. 📝 Hệ Thống Ghi Chú Học Tập Thông Minh (Smart Notes System)
- **Tạo ghi chú theo ngữ cảnh**: Nút ghi chú nhanh (`QuickNoteFab`, `NoteButton`) tích hợp xuyên suốt các màn hình: Reading, Listening, Writing, Speaking, Học từ vựng và bảng giải thích AI.
- **Quản lý ghi chú linh hoạt**: Lọc ghi chú theo kỹ năng, gắn thẻ tags, tìm kiếm nội dung, ghim (pin) các ghi chú quan trọng.
- **Offline-First & Đồng bộ đám mây (Cloud Sync)**: Lưu trữ tức thì vào SQLite cục bộ và tự động đồng bộ 2 chiều lên Supabase (`NoteSyncService`).
- **Xuất dữ liệu (Export Notes)**: Dễ dàng xuất ghi chú ra định dạng Text / Markdown (`NoteExportService`) để lưu trữ hoặc ôn tập.
- **Bộ kiểm thử toàn diện**: Bộ test suite từ P0 đến P4 kiểm thử toàn bộ luồng tạo, cập nhật, xóa, đồng bộ và giao diện ghi chú.

### 6. 🛠️ Cổng Quản Trị Toàn Diện (Admin Web Dashboard)
- Giao diện Web SPA tích hợp tại `http://127.0.0.1:8000/admin/`.
- Thống kê Dashboard KPIs (tổng người học, số bài thi đã chấm, tỉ lệ hoàn thành).
- Quản lý kho bài học 4 kỹ năng IELTS (Tạo, sửa, xóa bài tập, soạn câu hỏi).
- Tích hợp công cụ upload ảnh biểu đồ Task 1 tự động lên **Supabase Storage** (với cơ chế Fallback lưu cục bộ nếu mất mạng).
- Quản lý từ vựng và 82 nhãn YOLOv8.
- Quản lý tài khoản học viên và theo dõi nhật ký chấm điểm AI Grading Logs.

---

## 📋 Yêu Cầu Hệ Thống

- **Hệ điều hành**: Windows 10/11, macOS, hoặc Linux.
- **Python**: Phiên bản 3.10 trở lên.
- **Flutter SDK**: Phiên bản 3.19 trở lên (kèm Dart SDK).
- **Ollama**: Đã cài đặt [Ollama](https://ollama.ai/) để chạy các mô hình AI cục bộ (tùy chọn nhưng khuyến nghị để sử dụng AI Grading).
- **Thiết bị chạy Flutter**: Máy ảo Android/iOS, thiết bị thật qua cáp USB/Wi-Fi, hoặc Windows Desktop.

---

## 🚀 Hướng Dẫn Cài Đặt & Khởi Chạy

### Bước 1: Khởi Động & Cấu Hình Ollama AI (Local LLM)

Tải và cài đặt Ollama từ [ollama.ai](https://ollama.ai/). Sau đó mở Terminal và tải các model cần thiết:

```bash
# Model dùng cho chấm điểm Writing & sinh từ vựng (Khuyến nghị Qwen 2.5 7B hoặc 14B)
ollama pull qwen2.5:7b

# (Tùy chọn) Model Vision dùng cho Deep Scan ảnh
ollama pull llava-phi3:latest
```

Đảm bảo tiến trình Ollama đang chạy tại cổng mặc định `http://localhost:11434`.

---

### Bước 2: Cài Đặt & Khởi Chạy Backend FastAPI

1. Di chuyển vào thư mục backend và tạo môi trường ảo Python:
   ```bash
   cd backend
   python -m venv venv
   
   # Trên Windows (PowerShell):
   .\venv\Scripts\Activate.ps1
   # Trên macOS / Linux:
   source venv/bin/activate
   ```

2. Cài đặt các thư viện phụ thuộc:
   ```bash
   pip install -r requirements.txt
   ```

3. Cấu hình biến môi trường:
   Sao chép file `.env.example` thành `.env` và điền các thông số phù hợp:
   ```bash
   cp .env.example .env
   ```
   *Các thông số chính trong `.env`:*
   ```ini
   DATABASE_URL="sqlite:///./ielts_vision_backend.db"
   # Hoặc kết nối Supabase PostgreSQL:
   # DATABASE_URL="postgresql://postgres.[REF]:[PASSWORD]@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres"

   SUPABASE_URL="https://your-project.supabase.co"
   SUPABASE_ANON_KEY="your-anon-key"
   SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

   # Cấu hình Ollama Local
   OLLAMA_BASE_URL="http://localhost:11434"
   OLLAMA_VOCAB_MODEL="qwen2.5:latest"
   OLLAMA_GRADING_MODEL="qwen2.5:7b"

   # Cấu hình Email gửi OTP qua Gmail SMTP
   SMTP_HOST="smtp.gmail.com"
   SMTP_PORT=465
   SMTP_USER="your-email@gmail.com"
   SMTP_PASSWORD="your-app-password"  # Mật khẩu ứng dụng Google App Password
   ```

4. Khởi động Backend Server:
   ```bash
   python run.py
   ```
   - **API Base URL**: `http://127.0.0.1:8000`
   - **Tài liệu Swagger API**: `http://127.0.0.1:8000/api/v1/docs`
   - **Admin Web Dashboard**: `http://127.0.0.1:8000/admin/`

---

### Bước 3: Cài Đặt & Khởi Chạy Frontend Flutter

1. Mở cửa sổ Terminal mới tại thư mục gốc của dự án (`d:\AppHocTiengAnh`).
2. Tải các gói thư viện Flutter:
   ```bash
   flutter pub get
   ```
3. Cấu hình địa chỉ IP máy chủ Backend:
   - Nếu chạy trên **Android Emulator**, IP mặc định kết nối tới máy chủ host là `10.0.2.2:8000`.
   - Nếu chạy trên **Windows Desktop**, IP là `127.0.0.1:8000`.
   - Nếu chạy trên **Thiết bị thật (Android/iOS qua Wi-Fi)**:
     - Kiểm tra IP mạng LAN của máy tính chạy server (ví dụ: `192.168.1.65`).
     - Có thể sửa tại `lib/core/network/api_endpoints.dart` (biến `serverHost`), hoặc nhấn vào icon **Cấu hình máy chủ** ⚙️ ngay trên góc phải màn hình Đăng nhập của ứng dụng để đổi IP mà không cần build lại.
4. Chạy ứng dụng Flutter:
   ```bash
   # Chạy trên thiết bị kết nối mặc định
   flutter run
   
   # Hoặc chỉ định thiết bị cụ thể:
   flutter run -d windows
   flutter run -d chrome
   flutter run -d <device-id>
   ```

---

## 📖 Hướng Dẫn Sử Dụng Chi Tiết (User Guide)

### 1. Tài Khoản Đăng Nhập Mặc Định

| Vai trò | Tên đăng nhập | Mật khẩu | Chức năng chính |
| :--- | :--- | :--- | :--- |
| **Quản trị viên (Admin)** | `admin` | `password123` | Quản trị toàn hệ thống, quản lý đề thi, upload biểu đồ, giám sát logs AI |
| **Học viên (Learner)** | `learner` | `password123` | Quét AI Camera, học từ vựng, luyện 4 kỹ năng IELTS, chấm điểm AI |

---

### 2. Dành Cho Học Viên (Learner)

#### A. Đăng Ký, Đăng Nhập & Bảo Mật
- **Đăng ký tài khoản mới**: Nhấn "Đăng ký", nhập họ tên, email, tên đăng nhập và mật khẩu. Hệ thống sẽ gửi mã xác thực OTP 6 chữ số đến email để kích hoạt.
- **Đăng nhập khuôn mặt (Face Auth)**: Sau khi đăng nhập lần đầu, bạn có thể thiết lập khuôn mặt trong phần Cài đặt tài khoản để đăng nhập nhanh chóng bằng camera.
- **Quên mật khẩu**: Nhấn "Quên mật khẩu?", nhập email đã đăng ký để nhận mã OTP và tạo mật khẩu mới.

#### B. Quét Nhận Diện Vật Thể Bằng AI Camera
1. Chọn tab **Camera Scan** từ màn hình chính.
2. Hướng camera vào đồ vật xung quanh (ví dụ: chai nước, máy tính, sách, điện thoại).
3. Ứng dụng sẽ hiển thị khung nhận diện (Bounding Box) và tên từ vựng tiếng Anh tương ứng.
4. Nhấn nút **Deep Scan** để sử dụng Ollama Vision phân tích sâu ngữ cảnh bức ảnh.
5. Nhấn vào thẻ từ vựng để mở bảng chi tiết (nghe phát âm, xem ví dụ, ghi chú vào **Sổ tay từ vựng**).

#### C. Luyện Viết IELTS Writing & Chấm Điểm AI
1. Vào mục **Kỹ năng (Skills)** -> Chọn **IELTS Writing**.
2. Chọn bài thi theo nhu cầu:
   - **Task 1**: Xem đề bài và biểu đồ trực quan (Cột, Đường, Tròn) hiển thị sống động.
   - **Task 2**: Xem câu hỏi thảo luận / nghị luận.
3. Nhập bài làm vào khung soạn thảo (có bộ đếm số từ tự động).
4. Nhấn **Nộp bài & Chấm điểm bằng AI**.
5. Đợi hệ thống xử lý qua Ollama LLM, bảng kết quả trả về sẽ hiển thị:
   - Điểm Overall Band Score dự đoán.
   - Điểm chi tiết 4 tiêu chí: TR, CC, LR, GRA.
   - Lời nhận xét phân tích ưu điểm, nhược điểm, lỗi ngữ pháp cụ thể và bài viết tham khảo Band 8.0+.
6. Truy cập **Lịch sử chấm điểm AI** để xem lại toàn bộ các bài viết đã nộp.

#### D. Luyện Đọc & Luyện Nghe (Reading & Listening)
1. Chọn bài học Reading hoặc Listening mong muốn.
2. Với bài Nghe: Bấm nút Play/Pause để nghe file audio của bài thi.
3. Đọc đoạn văn và trả lời các câu hỏi trắc nghiệm / điền từ.
4. Bấm nộp bài để xem điểm số ngay lập tức. Bấm **Giải thích AI** để xem phân tích chi tiết vì sao đáp án đó là chính xác.

---

### 3. Dành Cho Quản Trị Viên (Admin)

Truy cập trang Quản trị tại trình duyệt web: `http://127.0.0.1:8000/admin/` (Đăng nhập với tài khoản `admin` / `password123`).

1. **Dashboard KPIs**: Theo dõi biểu đồ số lượng người dùng mới, số bài thi đã hoàn thành, tổng lượt chấm điểm AI theo ngày/tuần.
2. **Quản Lý Bài Học Kỹ Năng (Skills Management)**:
   - Thêm bài tập mới cho Writing, Reading, Listening, Speaking.
   - Đối với bài Writing Task 1: Hỗ trợ upload ảnh đề bài (lưu trữ trực tiếp lên Supabase Storage) hoặc cấu hình dữ liệu biểu đồ JSON động.
   - Soạn câu hỏi trắc nghiệm, đáp án chuẩn, và đoạn audio mẫu.
3. **Quản Lý Từ Vựng & Nhãn YOLOv8**:
   - Quản lý danh sách 82 nhãn nhận diện.
   - Tùy chỉnh bản dịch tiếng Việt, phiên âm IPA, từ đồng nghĩa và câu ví dụ của từng nhãn.
4. **Giám Sát AI Grading Logs**:
   - Theo dõi các yêu cầu chấm điểm gửi tới Ollama LLM.
   - Xem thời gian phản hồi (latency), số token sinh ra, và điểm số đánh giá.

---

## 🔧 Xử Lý Sự Cố Thường Gặp (Troubleshooting)

1. **Ứng dụng Flutter báo lỗi "Không thể kết nối đến máy chủ"**:
   - Đảm bảo Backend FastAPI đang chạy (`python run.py`).
   - Kiểm tra xem máy tính và điện thoại có kết nối **cùng một mạng Wi-Fi** hay không.
   - Kiểm tra Windows Firewall: Cho phép cổng `8000` nhận kết nối Inbound (hoặc tắt tạm thời Firewall để kiểm tra).
   - Bấm biểu tượng ⚙️ trên màn hình đăng nhập Flutter để cập nhật đúng IP máy tính.

2. **Chấm điểm AI Writing phản hồi chậm hoặc bị lỗi Timeout**:
   - Kiểm tra tiến trình Ollama đã được khởi động chưa (`ollama list`).
   - Đảm bảo máy tính có đủ dung lượng RAM/VRAM để chạy model `qwen2.5:7b` (khuyến nghị tối thiểu 8GB RAM).
   - Nếu máy cấu hình yếu, có thể đổi sang model nhẹ hơn trong `.env`:
     ```ini
     OLLAMA_GRADING_MODEL="qwen2.5:3b"
     ```

3. **Không nhận được email mã OTP**:
   - Đảm bảo bạn đã tạo **Mật khẩu ứng dụng (App Password)** trong phần bảo mật 2 lớp của tài khoản Google, không dùng mật khẩu Gmail thông thường.
   - Điền chính xác `SMTP_USER` và `SMTP_PASSWORD` vào file `.env`.

---

## 🛠️ Cấu Trúc Thư Mục Dự Án

```
AppHocTiengAnh/
├── backend/
│   ├── app/
│   │   ├── api/v1/endpoints/    # RESTful API Endpoints (Auth, Skills, AI Grading, Vision, Vocab)
│   │   ├── core/                # Cấu hình hệ thống, Security JWT, Supabase client
│   │   ├── db/                  # Database session & models
│   │   ├── models/              # SQLAlchemy Database Models
│   │   ├── schemas/             # Pydantic Schemas validation
│   │   ├── services/            # Tầng xử lý nghiệp vụ (AI Grading, Ollama, Email OTP, Skills)
│   │   └── static_admin/        # Giao diện Web SPA Quản trị viên (HTML/CSS/JS)
│   ├── scripts/                 # Scripts kiểm thử, hiệu chuẩn prompt AI, seed dữ liệu
│   ├── requirements.txt         # Thư viện Python phụ thuộc
│   └── run.py                   # Script khởi chạy Backend
├── lib/
│   ├── core/                    # Network endpoints, Database SQLite cục bộ, YOLO Vision Parser
│   ├── data/                    # Models & Repositories kết nối API Backend
│   └── presentation/
│       ├── auth/                # Màn hình & Provider Đăng nhập, Đăng ký, OTP, Face Auth
│       └── learner/             # Màn hình Luyện 4 kỹ năng, AI Camera Scan, Biểu đồ Writing, Lịch sử AI
├── pubspec.yaml                 # Cấu hình gói thư viện Flutter
└── README.md                    # Tài liệu hướng dẫn sử dụng & triển khai
```

---

## 📄 Bản Quyền & Giấy Phép
Dự án được phát triển phục vụ mục đích học tập và nghiên cứu công nghệ giáo dục thông minh (EdTech) tích hợp AI Vision và LLM.
Mọi đóng góp (Pull Requests) xin gửi về nhánh `feature/updateBEskils` hoặc `main`.
