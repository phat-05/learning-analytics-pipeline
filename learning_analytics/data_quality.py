def validate_and_load_table(connection, sql_script):
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