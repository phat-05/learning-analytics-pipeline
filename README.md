# Learning Analytics Pipeline

Pipeline batch xử lý dữ liệu OULAD, xây dựng kho dữ liệu PostgreSQL và dự báo nguy cơ sinh viên không đạt học phần. Kết quả dự báo được lưu vào PostgreSQL để Power BI sử dụng.

## Luồng xử lý

```text
OULAD CSV
   ↓
raw
   ↓
kiểm tra chất lượng
   ├── clean
   └── quarantine
          ↓
         mart
          ↓
mô hình Machine Learning
          ↓
prediction
          ↓
Power BI
```

## Cấu trúc chính

```text
learning-analytics-pipeline/
├── data/raw/                       # Bảy file CSV của OULAD
├── elt_pipeline/                   # Nạp, kiểm tra và biến đổi dữ liệu
├── ml_pipeline/                    # Đọc dữ liệu mart và dự báo
├── models/final_model.joblib       # Mô hình đã huấn luyện
├── notebook/ml_analytics.ipynb     # Notebook thử nghiệm và tạo mô hình
├── power_bi/dashboard.pbix         # Bảng điều khiển chung
├── sql/                            # Chứa các script SQL
├── .env                            # Chứa cấu hình môi trường
├── main.py                         # File thực thi của hệ thống
└── requirements.txt                # Các thư viện cần thiết
```

## Yêu cầu

- Python 3.14.4
- PostgreSQL
- Power BI Desktop nếu cần xem dashboard

## 1. Tải dự án

```powershell
git clone https://github.com/phat-05/learning-analytics-pipeline.git
cd learning-analytics-pipeline
```

Nếu không dùng Git, tải và giải nén dự án rồi mở PowerShell tại thư mục `learning-analytics-pipeline`.

## 2. Tạo môi trường Python

```powershell
py -3.14 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Nếu PowerShell chặn lệnh kích hoạt, có thể chạy:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

## 3. Tạo cơ sở dữ liệu PostgreSQL

Tạo một database rỗng bằng pgAdmin hoặc lệnh:

```powershell
createdb -U postgres learning_analytics
```

Lệnh `init-db` của dự án chỉ tạo schema và bảng bên trong database đã tồn tại; nó không tự tạo database.

Tài khoản PostgreSQL cần có quyền tạo schema, tạo bảng, đọc, ghi và truncate bảng trong database này.

## 4. Cấu hình kết nối

Tạo file `.env` trong thư mục gốc của dự án:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=learning_analytics
DB_USER=your_username
DB_PASSWORD=your_password
```

## 5. Chuẩn bị dữ liệu OULAD

Tải bộ dữ liệu từ [trang OULAD của The Open University](https://analyse.kmi.open.ac.uk/open_dataset).

Giải nén và đặt đúng bảy file sau vào `data/raw/`:

```text
data/raw/
├── assessments.csv
├── courses.csv
├── studentAssessment.csv
├── studentInfo.csv
├── studentRegistration.csv
├── studentVle.csv
└── vle.csv
```

Tên file và thứ tự cột phải giữ nguyên. Pipeline sẽ dừng nếu thiếu file, có file CSV dư hoặc header không đúng.

OULAD được The Open University công bố theo giấy phép CC BY 4.0. Khi sử dụng cho nghiên cứu hoặc báo cáo, cần ghi nguồn dữ liệu.

## 6. Kiểm tra mô hình

Đảm bảo file sau tồn tại:

```text
models/final_model.joblib
```

CLI hiện chỉ tải mô hình này để dự báo, không có lệnh huấn luyện mô hình.

## 7. Chạy lần đầu

Nên chạy từng bước để dễ xác định lỗi.

### Bước 1: Tạo schema và bảng

```powershell
python main.py init-db
```

Lệnh này tạo các schema:

```text
raw
clean
quarantine
mart
prediction
```

`CREATE TABLE IF NOT EXISTS` không tự cập nhật cấu trúc của bảng cũ. Khi cài lần đầu, nên dùng database rỗng.

### Bước 2: Chạy pipeline dữ liệu

```powershell
python main.py run-pipeline
```

Pipeline sẽ:

1. Kiểm tra bảy file CSV.
2. Làm rỗng dữ liệu cũ.
3. Nạp CSV vào `raw`.
4. Phân loại dữ liệu vào `clean` hoặc `quarantine`.
5. Tổng hợp dữ liệu theo tuần vào `mart`.
6. Kiểm tra dữ liệu đầu vào dự báo.

> Cảnh báo: lệnh này thay toàn bộ snapshot hiện tại trong `raw`, `clean`, `quarantine`, `mart` và xóa kết quả `prediction` cũ.

>Lưu ý: Quá trình có thể mất vài phút tùy theo cấu hình máy tính. Không nên dừng quá trình giữa chừng. 
>Nếu xảy ra lỗi trước khi quá trình hoàn tất, các thay đổi cơ sở dữ liệu trong lần chạy sẽ được rollback.

### Bước 3: Chạy dự báo

```powershell
python main.py predict
```

Lệnh này:

1. Đọc dữ liệu presentation `2014J` từ mart.
2. Tải `models/final_model.joblib`.
3. Tính xác suất `Fail` và ba yếu tố SHAP nổi bật.
4. Ghi kết quả vào schema `prediction`.

> Mỗi lần chạy `predict`, các kết quả dự báo cũ sẽ bị thay thế.

>Lưu ý: Quá trình có thể mất vài phút tùy theo cấu hình máy tính. Không nên dừng quá trình giữa chừng. 
>Nếu xảy ra lỗi trước khi quá trình hoàn tất, các thay đổi cơ sở dữ liệu trong lần chạy sẽ được rollback.

## 8. Chạy toàn bộ bằng một lệnh

Sau khi đã kiểm tra cấu hình, dữ liệu và mô hình:

```powershell
python main.py run-all
```

Lệnh này chạy tuần tự:

```text
init-db → run-pipeline → predict
```

## 9. Các lệnh CLI

| Lệnh | Chức năng |
|---|---|
| `python main.py init-db` | Tạo schema và bảng |
| `python main.py run-pipeline` | Nạp và biến đổi toàn bộ dữ liệu |
| `python main.py predict` | Dự báo presentation `2014J` |
| `python main.py run-all` | Chạy toàn bộ quy trình |

Có thể xem trợ giúp bằng:

```powershell
python main.py --help
```

## 10. Huấn luyện lại mô hình

Quy trình huấn luyện nằm trong:

```text
notebook/ml_analytics.ipynb
```

Cách chạy:

1. Hoàn thành `init-db` và `run-pipeline`.
2. Mở notebook bằng VS Code hoặc IDE hỗ trợ Jupyter.
3. Chọn kernel Python từ `.venv`.
4. Chạy notebook theo thứ tự từ đầu đến cuối.
5. Kiểm tra kết quả trước khi chạy cell lưu artifact.

> Cell lưu artifact sẽ ghi đè `models/final_model.joblib`. Không chạy lại nếu chưa muốn thay mô hình đang dùng.

Notebook có phần tích hợp W&B nhưng lời gọi ghi log hiện đang bị tắt. Chỉ cần đăng nhập W&B nếu chủ động bật lại phần này.

## 11. Mở dashboard Power BI

Sau khi chạy dự báo:

1. Mở `power_bi/dashboard.pbix`.
2. Cập nhật kết nối PostgreSQL theo database trong `.env`.
3. Nhập thông tin xác thực nếu Power BI yêu cầu.
4. Chọn Refresh.
5. Dùng bộ lọc `week_no` để xem dự báo theo tuần.

Nếu dashboard không có dữ liệu, kiểm tra schema `prediction` đã có kết quả từ lệnh `predict` hay chưa.

## 12. Một số lỗi thường gặp

### Thiếu biến môi trường

```text
Thiếu biến môi trường trong .env
```

Kiểm tra file `.env` có đủ năm biến `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` và `DB_PASSWORD`.

### Không kết nối được PostgreSQL

Kiểm tra:

- PostgreSQL đang chạy;
- database đã được tạo;
- host và port đúng;
- tên đăng nhập và mật khẩu đúng.

### Thiếu dữ liệu nguồn

Kiểm tra đủ bảy CSV trong `data/raw/` và không đổi tên file.

### Không tìm thấy mô hình

Kiểm tra:

```text
models/final_model.joblib
```

### Lỗi khi tải mô hình

Đảm bảo đang dùng Python 3.14.4 và đúng phiên bản các thư viện trong `requirements.txt`. Artifact `joblib` có thể không tương thích khi thay đổi phiên bản Python hoặc scikit-learn.

## Giấy phép

Mã nguồn của dự án được phát hành theo giấy phép MIT.

Dữ liệu OULAD thuộc The Open University và được công bố theo giấy phép CC BY 4.0.