"""

"""
import argparse
import pandas as pd
from time import perf_counter
from elt_pipeline.database import get_connection, initialize_database, reset_database
from elt_pipeline.raw_validation import validate_and_route_all_tables
from elt_pipeline.extraction import extract_and_load_all_source_file_to_raw
from elt_pipeline.transformation import transform_all_tables
from ml_pipeline.data_serving import get_train_data


def run_timed_step(step_name, action, *args):
    started_at = perf_counter()
    try:
        return action(*args)
    finally:
        print(f"Thời gian {step_name}: {perf_counter() - started_at:.2f} giây")


def init_db():
    """
    Khởi tạo cấu trúc các schema và table.
    """
    try:
        print("="*60)
        print("Đang khởi tạo cơ sở dữ liệu ...")
        run_timed_step("khởi tạo cơ sở dữ liệu", initialize_database)
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
    pipeline_started_at = perf_counter()

    try:
        with (get_connection() as connection):
            print("Đang đặt lại toàn bộ dữ liệu cũ ...")
            run_timed_step("đặt lại dữ liệu", reset_database, connection)
            print("Đặt lại toàn bộ dữ liệu cũ thành công!")

            print("-" * 60)
            curr_step = "Extract CSV vào raw"
            print("Đang extract dữ liệu từ file CSV vào vùng raw ...")
            run_timed_step(
                "extract CSV vào raw",
                extract_and_load_all_source_file_to_raw,
                connection,
            )
            print("Extract dữ liệu từ file CSV vào vùng raw thành công!")

            curr_step = "Kiểm tra chất lượng dữ liệu"
            print("-" * 60)
            print("Đang kiểm tra chất lượng dữ liệu ...")
            run_timed_step(
                "kiểm tra chất lượng dữ liệu",
                validate_and_route_all_tables,
                connection,
            )
            print("Kiểm tra chất lượng dữ liệu thành công!")

            print("-" * 60)
            curr_step = "Tổng hợp dữ liệu vào data warehouse"
            print("Đang tổng hợp dữ liệu vào data warehouse ...")
            run_timed_step(
                "tổng hợp dữ liệu vào data warehouse",
                transform_all_tables,
                connection,
            )
            print("Tổng hợp dữ liệu vào data warehouse thành công!")

        print("-" * 60)
        print("Pipeline xử lý dữ liệu hoàn tất!")
        print("=" * 60)

    except Exception as error:
        print(f"\nPipeline dữ liệu thất bại tại bước: {curr_step}")
        print(f"Lỗi: {error}")
        raise SystemExit(1)

    finally:
        print(f"Tổng thời gian pipeline: {perf_counter() - pipeline_started_at:.2f} giây")


def train_model():
    ...

def predict():
    ...


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
        "train-model",
        help="Huấn luyện mô hình",
    )
    all_command.set_defaults(handler=train_model)

    all_command = commands.add_parser(
        "run-all",
        help="Chạy tuần tự tất cả các bước",
    )
    all_command.set_defaults(handler=run_all)

    args = parser.parse_args()
    args.handler()


if __name__ == "__main__":
    main()
