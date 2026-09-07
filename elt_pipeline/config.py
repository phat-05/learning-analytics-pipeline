"""
Đọc cấu hình kết nối Postgres và đường dẫn dữ liệu từ file .env,
cung cấp các hằng số dùng chung cho toàn bộ package elt_pipeline.
"""
import os
import re
from pathlib import Path
from dotenv import load_dotenv

# thư mục gốc của project
BASE_DIR = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------------------------
# kiểm tra và nhập database url
load_dotenv(BASE_DIR / ".env")

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")

_url_required = {
    "DB_USER": DB_USER,
    "DB_PASSWORD": DB_PASSWORD,
    "DB_HOST": DB_HOST,
    "DB_PORT": DB_PORT,
    "DB_NAME": DB_NAME,
}

_missing = [key for key, val in _url_required.items() if not val]
if _missing:
    raise ValueError(f"Thiếu biến môi trường trong .env: {', '.join(_missing)}")

DATABASE_URL = "postgresql://{}:{}@{}:{}/{}".format(
    DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME
)


# ---------------------------------------------------------------------------------------------
# kiểm tra và đọc các file SQL
SQL_DIR = BASE_DIR / "sql"

def require_sql_file(parent ,file_name):
    """
    Trả về đường dẫn file SQL sau khi kiểm tra.
    """
    file_path = SQL_DIR / parent / file_name

    if not file_path.is_file():
        raise FileNotFoundError(
            f"Không tìm thấy file SQL: {file_path}"
        )

    if not file_path.read_text(encoding="utf-8").strip():
        raise ValueError(f"File {file_name} đang trống!")

    return file_path


INIT_SQL_FILE = require_sql_file("init", "init_db.sql")

VALIDATE_AND_ROUTE_STEPS = (
    ("courses", require_sql_file("validate", "validate_and_route_courses.sql")),
    (
        "student_info",
        require_sql_file("validate", "validate_and_route_student_info.sql"),
    ),
    (
        "student_registration",
        require_sql_file("validate", "validate_and_route_student_registration.sql"),
    ),
    (
        "assessments",
        require_sql_file("validate", "validate_and_route_assessments.sql"),
    ),
    (
        "student_assessment",
        require_sql_file("validate", "validate_and_route_student_assessment.sql"),
    ),
    ("vle", require_sql_file("validate", "validate_and_route_vle.sql")),
    (
        "student_vle",
        require_sql_file("validate", "validate_and_route_student_vle.sql"),
    ),
)

TRANSFORM_STEPS = (
    (
        "dim_module_presentation",
        require_sql_file("transform", "transform_to_dim_module_presentation.sql")
    ),
    (
        "dim_week",
        require_sql_file("transform","transform_to_dim_week.sql")
    ),
    (
        "dim_assessments",
        require_sql_file("transform","transform_to_dim_assessments.sql")
    ),
    (
        "dim_student_module_presentation",
        require_sql_file("transform","transform_to_dim_student_module_presentation.sql")
    ),
    (
        "fact_module_presentation_activity_type_week",
        require_sql_file("transform","transform_to_fact_module_presentation_activity_type_week.sql")
    ),
    (
        "fact_module_presentation_assessments_week",
        require_sql_file("transform","transform_to_fact_module_presentation_assessments_week.sql")
    ),
    (
        "fact_student_module_presentation_week",
        require_sql_file("transform","transform_to_fact_student_module_presentation_week.sql")
    )
)


# ---------------------------------------------------------------------------------------------
# kiểm tra thư mục dữ liệu nguồn OULAD
SOURCE_DATA_DIR = BASE_DIR / "data" / "raw"

if not SOURCE_DATA_DIR.exists():
    raise FileNotFoundError(
        f"Không tìm thấy thư mục dữ liệu nguồn: {SOURCE_DATA_DIR}"
    )

if not SOURCE_DATA_DIR.is_dir():
    raise NotADirectoryError(
        f"Đường dẫn dữ liệu nguồn không phải thư mục: {SOURCE_DATA_DIR}"
    )


# ---------------------------------------------------------------------------------------------
# cấu trúc các file CSV nguồn, dùng để kiểm tra các file csv có đủ và đúng tên, đúng cột
SOURCE_FILES_TEMPLATE = {
    "courses.csv": [
        "code_module",
        "code_presentation",
        "module_presentation_length",
    ],
    "studentInfo.csv": [
        "code_module",
        "code_presentation",
        "id_student",
        "gender",
        "region",
        "highest_education",
        "imd_band",
        "age_band",
        "num_of_prev_attempts",
        "studied_credits",
        "disability",
        "final_result",
    ],
    "studentRegistration.csv": [
        "code_module",
        "code_presentation",
        "id_student",
        "date_registration",
        "date_unregistration",
    ],
    "assessments.csv": [
        "code_module",
        "code_presentation",
        "id_assessment",
        "assessment_type",
        "date",
        "weight",
    ],
    "studentAssessment.csv": [
        "id_assessment",
        "id_student",
        "date_submitted",
        "is_banked",
        "score",
    ],
    "vle.csv": [
        "id_site",
        "code_module",
        "code_presentation",
        "activity_type",
        "week_from",
        "week_to",
    ],
    "studentVle.csv": [
        "code_module",
        "code_presentation",
        "id_student",
        "id_site",
        "date",
        "sum_click",
    ],
}

if not SOURCE_FILES_TEMPLATE:
    raise ValueError("Thiếu cấu hình 'SOURCE_FILES_TEMPLATE' trong config!")


# ---------------------------------------------------------------------------------------------
# dict map từ tên file csv sang tên bảng trong schema raw
RAW_TABLE_BY_FILE = {
    "courses.csv": "courses",
    "studentInfo.csv": "student_info",
    "studentRegistration.csv": "student_registration",
    "assessments.csv": "assessments",
    "studentAssessment.csv": "student_assessment",
    "vle.csv": "vle",
    "studentVle.csv": "student_vle",
}

if not RAW_TABLE_BY_FILE:
    raise ValueError("Thiếu cấu hình 'RAW_TABLE_BY_FILE' trong config!")


# ---------------------------------------------------------------------------------------------
# thư mục lưu logs
LOG_DIR = BASE_DIR / "logs"
