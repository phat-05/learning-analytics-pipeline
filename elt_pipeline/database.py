"""

"""
import psycopg
from psycopg import sql
from elt_pipeline.config import DATABASE_URL, INIT_SQL_FILE, RAW_TABLE_BY_FILE


def get_connection():
    """
    Tạo và trả về kết nối đến PostgreSQL.
    """
    return psycopg.connect(DATABASE_URL)


def test_connection():
    """
    Kiểm tra kết nối và trả về tên cơ sở dữ liệu hiện tại.
    """
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT current_database()")
            return cursor.fetchone()[0]


def initialize_database():
    """
    Tạo các schema và bảng bền vững của pipeline.
    """
    sql_script = INIT_SQL_FILE.read_text(encoding="utf-8")

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(sql_script)


def reset_database(connection):
    """
    Làm rỗng dữ liệu của các vùng trong database hiện tại.
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
