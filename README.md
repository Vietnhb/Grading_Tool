# Lecturer Grading Tool

Lecturer Grading Tool là một ứng dụng Desktop được xây dựng bằng Flutter nhằm hỗ trợ giảng viên chấm thi (ví dụ: môn PMG201c) một cách tự động, trực quan và hiệu quả, kết hợp sức mạnh của trí tuệ nhân tạo (AI).

## 🌟 Các tính năng nổi bật
- **Chấm điểm bằng AI (AI Batch Grading)**: Tự động đánh giá bài làm của sinh viên dựa trên Rubric (tiêu chí chấm điểm) và đưa ra đề xuất điểm số cùng nhận xét chi tiết. Hỗ trợ chấm hàng loạt giúp tiết kiệm tối đa thời gian.
- **Trích xuất Rubric tự động**: Ứng dụng tự động đọc và phân tích các tiêu chí chấm điểm từ file Hướng dẫn chấm thi định dạng Word (`.docx`).
- **Hỗ trợ OCR Đề thi**: Tự động đọc chữ từ hình ảnh đề bài (OCR) để cung cấp ngữ cảnh đầy đủ, giúp AI chấm chính xác hơn.
- **Đồng bộ trực tiếp với Excel**: Đọc danh sách sinh viên từ file Excel (`.xlsx`) và tự động lưu điểm cũng như nhận xét vào đúng các cột tương ứng sau khi giảng viên chốt điểm.
- **Giao diện làm việc chia đôi**: Tối ưu cho màn hình Desktop. Một bên hiển thị bài làm của sinh viên và đề thi, một bên là bảng điều khiển (Grading Panel) để chấm điểm thủ công hoặc xem đề xuất của AI.
- **Lịch sử AI Audit Log**: Lưu lại chi tiết lịch sử (log) quá trình suy luận và chấm điểm của AI, hỗ trợ rà soát lại kết quả.
- **Chuyển đổi thư mục nhanh**: Hỗ trợ chuyển qua lại giữa các gói bài thi (Exam Packages) chỉ với một thao tác bấm.

## 📂 Cấu trúc một gói bài thi (Exam Package) tiêu chuẩn
Để ứng dụng có thể đọc được dữ liệu, bạn cần chuẩn bị một thư mục thư mục chứa bài thi bao gồm các thành phần sau:
- **File nhập điểm (Excel - `.xlsx`)**: Chứa danh sách sinh viên.
- **Thư mục `Student_Solutions`**: Chứa toàn bộ các bài làm (source code, text, ...) của sinh viên.
- **File Hướng dẫn chấm (Word - `.docx`)**: Chứa chi tiết Rubric phân bổ điểm số.
- **Hình ảnh đề thi (`.png`, `.jpg`, v.v.)**: Hình ảnh đề bài.

## ⚙️ Hướng dẫn Cài đặt & Chạy ứng dụng

### Yêu cầu hệ thống
- Máy tính đã cài đặt [Flutter SDK](https://flutter.dev/docs/get-started/install) hỗ trợ phát triển ứng dụng Desktop (Windows/macOS).
- Bạn cần chuẩn bị sẵn API Key từ [OpenRouter](https://openrouter.ai/) để sử dụng tính năng chấm điểm tự động.

### Khởi chạy dự án
1. Clone repository về máy:
   ```bash
   git clone https://github.com/Vietnhb/Grading_Tool.git
   cd Grading_Tool
   ```
2. Cài đặt các thư viện phụ thuộc:
   ```bash
   flutter pub get
   ```
3. Chạy ứng dụng trên máy của bạn:
   ```bash
   flutter run -d windows # Dành cho Windows
   # hoặc: flutter run -d macos # Dành cho macOS
   ```

## 🚀 Các bước sử dụng cơ bản
1. Khởi động ứng dụng. Tại màn hình chính, **kéo thả** (Drag & Drop) thư mục bài thi (Exam Package) vào giao diện.
2. Ứng dụng sẽ tự động phân tích cấu trúc, nhận diện Rubric và tải danh sách sinh viên.
3. Nhấp vào nút **Cài đặt AI** (biểu tượng chìa khóa góc trên bên phải) để dán OpenRouter API Key của bạn.
4. Lựa chọn sinh viên cần chấm hoặc sử dụng tính năng **Run AI grading / Batch Grading** để công cụ tự động chấm toàn bộ lớp.
5. Giảng viên kiểm tra lại điểm, điều chỉnh (nếu có) và ứng dụng sẽ tự động lưu điểm số/nhận xét thẳng vào file Excel.
6. Khi hoàn thành, nhấn nút **Change Folder** ở thanh trên cùng để chuyển sang gói bài thi của lớp khác.
