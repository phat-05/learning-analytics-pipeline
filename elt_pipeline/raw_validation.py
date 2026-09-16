from config import VALIDATE_AND_ROUTE_STEPS


def validate_and_route_table(connection, sql_script):
    """
    Kiểm tra bảng và nạp sang clean hoặc quarantine.
    """
    reconciliation = None

    with connection.cursor() as cursor:
        cursor.execute(sql_script)

        while True:
            if cursor.description is not None:
                reconciliation = cursor.fetchone()

            if not cursor.nextset():
                break

    if reconciliation is None:
        raise RuntimeError(
            "Không nhận được kết quả đối soát"
        )

    raw_count, clean_count, quarantine_count, is_reconciled = reconciliation

    if not is_reconciled:
        raise RuntimeError(
            "Đối soát thất bại: "
            f"raw={raw_count}, "
            f"clean={clean_count}, "
            f"quarantine={quarantine_count}"
        )

    return raw_count, clean_count, quarantine_count

def validate_and_route_all_tables(connection):
    """
    Kiểm tra bảng và nạp sang clean hoặc quarantine.
    """
    for table_name, sql_file in VALIDATE_AND_ROUTE_STEPS:
        print("-" * 60)
        print(f"Đang kiểm tra và xử lý bảng raw.{table_name} ...")

        sql_script = sql_file.read_text(encoding="utf-8")
        _, clean_count, quarantine_count = (
            validate_and_route_table(connection, sql_script)
        )

        print(f"Xử lý bảng {table_name} thành công!")
        print(f"Số bản ghi đã load vào clean: {clean_count}")
        print(f"Số bản ghi đã load vào quarantine: {quarantine_count}")