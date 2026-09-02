"""
Đọc dữ liệu CSV nguồn để chuyển sang các bước xử lý tiếp theo.
"""
from psycopg import sql

from learning_analytics.config import SOURCE_DATA_DIR, SOURCE_FILES_TEMPLATE, RAW_TABLE_BY_FILE
from learning_analytics.validators import validate_source_files

def reset_pipeline_tables(connection):
    """
    Làm rỗng dữ liệu của snapshot pipeline hiện tại.
    """
    tables = sql.SQL(", ").join(
        sql.Identifier(schema_name, table_name)
        for schema_name in ("raw", "clean", "quarantine")
        for table_name in RAW_TABLE_BY_FILE.values()
    )

    query = sql.SQL(
        "TRUNCATE TABLE {} RESTART IDENTITY"
    ).format(tables)

    with connection.cursor() as cursor:
        cursor.execute(query)

def copy_source_file_to_raw(connection, file_name):
    """
    Nạp một file CSV nguồn vào bảng raw tương ứng.
    """
    file_path = SOURCE_DATA_DIR / file_name
    table_name = RAW_TABLE_BY_FILE[file_name]
    columns = SOURCE_FILES_TEMPLATE[file_name]

    column_names = sql.SQL(", ").join(
        sql.Identifier(column) for column in columns
    )

    copy_query = sql.SQL(
        "COPY {} ({}) FROM STDIN "
        "WITH (FORMAT CSV, HEADER TRUE, NULL '', FORCE_NULL ({}))"
    ).format(
        sql.Identifier("raw", table_name),
        column_names,
        column_names,
    )

    with file_path.open("rb") as source_file:
        with connection.cursor() as cursor:
            with cursor.copy(copy_query) as copy:
                while block := source_file.read(1024 * 1024):
                    copy.write(block)

def load_raw_snapshot(connection):
    """
    Thay toàn bộ snapshot raw bằng bảy file CSV nguồn.
    """
    validate_source_files()

    for file_name in SOURCE_FILES_TEMPLATE:
        copy_source_file_to_raw(connection, file_name)