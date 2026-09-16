"""
Các hàm kiểm tra dữ liệu trong quá trình pipeline xử lý.
"""
import csv
from config import SOURCE_DATA_DIR, SOURCE_FILES_TEMPLATE


def validate_source_files():
    """
    Kiểm tra đủ file CSV nguồn và đúng thứ tự cột.
    """
    _validate_source_file_names()

    for file_name, expected_columns in SOURCE_FILES_TEMPLATE.items():
        _validate_csv_header(file_name, expected_columns)


def _validate_source_file_names():
    """
    Kiểm tra tập tên file CSV thực tế khớp cấu hình.
    """
    actual_files = {
        file_path.name
        for file_path in SOURCE_DATA_DIR.glob("*.csv")
    }
    expected_files = set(SOURCE_FILES_TEMPLATE)

    missing_files = sorted(expected_files - actual_files)
    unexpected_files = sorted(actual_files - expected_files)

    errors = []

    if missing_files:
        errors.append(f"Thiếu file CSV nguồn: {missing_files}")

    if unexpected_files:
        errors.append(f"File CSV nguồn chưa được khai báo: {unexpected_files}")

    if errors:
        raise ValueError(". ".join(errors))


def _validate_csv_header(file_name, expected_columns):
    """
    Kiểm tra header của một file CSV khớp cấu hình.
    """
    file_path = SOURCE_DATA_DIR / file_name

    with file_path.open(mode="r",encoding="utf-8-sig",newline="",) as csv_file:
        actual_columns = next(csv.reader(csv_file), None)

    if actual_columns is None:
        raise ValueError(f"File CSV rỗng: {file_name}")

    if actual_columns != expected_columns:
        raise ValueError(
            f"Sai cấu trúc cột của file {file_name}. "
            f"Cột yêu cầu: {expected_columns}. "
            f"Cột thực tế: {actual_columns}"
        )