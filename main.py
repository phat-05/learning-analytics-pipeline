"""

"""
import argparse

from learning_analytics.config import DATA_QUALITY_STEPS
from learning_analytics.database import get_connection, initialize_database
from learning_analytics.loader import load_raw_snapshot, reset_pipeline_tables
from learning_analytics.data_quality import validate_and_load_table


def init_db():
    """
    Khởi tạo cấu trúc các schema và table.
    """
    try:
        print("="*60)
        print("Đang khởi tạo cơ sở dữ liệu ...")
        initialize_database()
        print("Khởi tạo cơ sở dữ liệu thành công!")

    except Exception as error:
        print(f"\nThất bại tại bước: khởi tạo cấu trúc cơ sở dữ liệu")
        print(f"Lỗi: {error}")
        raise SystemExit(1)


def run_data_pipeline():
    """
    Thay snapshot và xử lý dữ liệu trong một transaction.
    """
    print("=" * 60)
    print("Đang chạy pipeline dữ liệu ...")
    print("-"*60)
    curr_step = "Đặt lại toàn bộ dữ liệu cũ"

    try:
        with (get_connection() as connection):
            print("Đang đặt lại toàn bộ dữ liệu cũ ...")
            reset_pipeline_tables(connection)
            print("Đặt lại toàn bộ dữ liệu cũ thành công!")

            print("-" * 60)
            curr_step = "Load csv vào raw"
            print("Đang load dữ liệu từ file csv vào vùng raw ...")
            load_raw_snapshot(connection)
            print("Load dữ liệu từ file csv vào vùng raw thành công!")

            for table_name, sql_file in DATA_QUALITY_STEPS:
                print("-" * 60)
                curr_step = f"Kiểm tra và load raw.{table_name}"
                print(f"Đang kiểm tra và load raw.{table_name} ...")

                sql_script = sql_file.read_text(encoding="utf-8")
                _, clean_count, quarantine_count = (
                    validate_and_load_table(connection, sql_script)
                )

                print(f"Xử lý {table_name} thành công!")
                print(f"Số bản ghi đã load vào clean: {clean_count}")
                print(
                    "Số bản ghi đã load vào quarantine: "
                    f"{quarantine_count}"
                )

        print("-" * 60)
        print("Pipeline xử lý dữ liệu hoàn tất!")
        print("=" * 60)

    except Exception as error:
        print(f"\nPipeline dữ liệu thất bại tại bước: {curr_step}")
        print(f"Lỗi: {error}")
        raise SystemExit(1)


def run_all():
    """
    Chạy tuần tự các bước cần thiết.
    """
    init_db()
    run_data_pipeline()


def main():
    parser = argparse.ArgumentParser(
        description="Pipeline phân tích dữ liệu học tập"
    )

    commands = parser.add_subparsers(
        dest="command",
        required=True,
    )

    init_command = commands.add_parser(
        "init-db",
        help="Khởi tạo cấu trúc cơ sở dữ liệu",
    )
    init_command.set_defaults(handler=init_db)

    load_command = commands.add_parser(
        "run-pipeline",
        help="Chạy pipeline xử lý dữ liệu",
    )
    load_command.set_defaults(handler=run_data_pipeline)

    all_command = commands.add_parser(
        "run-all",
        help="Chạy tuần tự tất cả các bước",
    )
    all_command.set_defaults(handler=run_all)

    args = parser.parse_args()
    args.handler()


if __name__ == "__main__":
    main()
