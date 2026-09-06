def validate_and_load_table(connection, sql_script):
    """
    Kiểm tra bảng và nạp sang clean hoặc quarantine.
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