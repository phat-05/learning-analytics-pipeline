from config import TRANSFORM_STEPS


def transform_table(connection, sql_script):
    """
    Biến đổi, tổng hợp dữ liệu vào các bảng vùng mart.
    """
    row_count = None
    with connection.cursor() as cursor:
        cursor.execute(sql_script)

        while True:
            if cursor.description is not None:
                result = cursor.fetchone()
                if result is not None:
                    row_count = result[0]

            if not cursor.nextset():
                break

    if row_count is None:
        raise RuntimeError("Không nhận được kết quả đối chiếu mart")

    if row_count == 0:
        raise RuntimeError(f"Đối chiếu thất bại: đã transform {row_count} dòng vào mart.")

    return row_count


def transform_all_tables(connection):
    """
    Biến đổi, tổng hợp dữ liệu vào tất cả các bảng vùng mart.
    """
    for table_name, sql_file in TRANSFORM_STEPS:
        print("-" * 60)
        print(f"Đang biến đổi dữ liệu vào bảng mart.{table_name} ...")

        sql_script = sql_file.read_text(encoding="utf-8")
        row_count = transform_table(connection, sql_script)

        print(f"Biến đổi dữ liệu vào {table_name} thành công!")
        print(f"Số bản ghi đã biến đổi vào mart: {row_count}")
