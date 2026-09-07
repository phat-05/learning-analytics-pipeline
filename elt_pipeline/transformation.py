from elt_pipeline.config import TRANSFORM_STEPS


def transform_table(connection, sql_script):
    """
    Biến đổi, tổng hợp dữ liệu vào các bảng vùng mart.
    """
    row_count = None
    with connection.cursor() as cursor:
        cursor.execute(sql_script)

        row_count = cursor.fetchone()[0]

    if not row_count:
        raise RuntimeError(
            "Đối soát thất bại: "
            f"đã transform {row_count} dòng vào mart."
        )
    return row_count


def transform_all_tables(connection):
    """
    Biến đổi, tổng hợp dữ liệu vào tất cả các bảng vùng mart.
    """
    for table_name, sql_file in TRANSFORM_STEPS:
        print("-" * 60)
        print(f"Đang kiểm tra và load raw.{table_name} ...")

        sql_script = sql_file.read_text(encoding="utf-8")
        row_count = transform_table(connection, sql_script)

        print(f"Biến đổi dữ liệu vào {table_name} thành công!")
        print(f"Số bản ghi đã biến đổi vào mart: {row_count}")