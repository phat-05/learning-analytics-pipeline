"""

"""
import argparse
from time import perf_counter
from colorama import Fore, Style, just_fix_windows_console
from elt_pipeline.database import get_connection, initialize_database, reset_database
from elt_pipeline.raw_validation import validate_and_route_all_tables
from elt_pipeline.extraction import extract_and_load_all_source_file_to_raw
from elt_pipeline.transformation import transform_all_tables
from elt_pipeline.source_validation import validate_source_files
from ml_pipeline.data_serving import get_train_data, get_predict_data
from ml_pipeline.prediction import get_model, model_predict, save_prediction


LINE_WIDTH = 64


def _print_header(title):
    print()
    print(f"{Fore.CYAN}{Style.BRIGHT}{'=' * LINE_WIDTH}")
    print(title.center(LINE_WIDTH))
    print(f"{'=' * LINE_WIDTH}{Style.RESET_ALL}")


def _start_step(number, total, label):
    print(
        f"{Fore.CYAN}{Style.BRIGHT}[{number}/{total}]{Style.RESET_ALL} "
        f"{label} ..."
    )
    return perf_counter()


def _finish_step(label, started_at):
    elapsed = perf_counter() - started_at
    print(
        f"{Fore.GREEN}{Style.BRIGHT}[OK]{Style.RESET_ALL} "
        f"{label} ({elapsed:.2f}s)"
    )


def _print_complete(message, started_at):
    elapsed = perf_counter() - started_at
    print(f"{Fore.GREEN}{Style.BRIGHT}{'-' * LINE_WIDTH}")
    print(f"{message} - Tổng thời gian: {elapsed:.2f}s")
    print(f"{'-' * LINE_WIDTH}{Style.RESET_ALL}")


def _print_failure(step, error):
    print(f"\n{Fore.RED}{Style.BRIGHT}[THẤT BẠI]{Style.RESET_ALL} {step}")
    print(f"{Fore.RED}Lỗi: {error}{Style.RESET_ALL}")


def init_db():
    """
    Khởi tạo cấu trúc các schema và table.
    """
    _print_header("KHỞI TẠO CƠ SỞ DỮ LIỆU")
    started_at = perf_counter()
    step = "Khởi tạo cấu trúc cơ sở dữ liệu"

    try:
        step_started_at = _start_step(1, 1, step)
        initialize_database()
        _finish_step(step, step_started_at)
        _print_complete("KHỞI TẠO CƠ SỞ DỮ LIỆU HOÀN TẤT", started_at)

    except Exception as error:
        _print_failure(step, error)
        raise SystemExit(1)


def run_data_pipeline():
    """
    Thay snapshot và xử lý dữ liệu trong một transaction.
    """
    _print_header("LEARNING ANALYTICS - DATA PIPELINE")
    started_at = perf_counter()
    curr_step = "Kiểm tra file CSV nguồn"

    try:
        step_started_at = _start_step(1, 6, curr_step)
        validate_source_files()
        _finish_step(curr_step, step_started_at)

        with (get_connection() as connection):
            curr_step = "Đặt lại toàn bộ dữ liệu cũ"
            step_started_at = _start_step(2, 6, curr_step)
            reset_database(connection)
            _finish_step(curr_step, step_started_at)

            curr_step = "Extract CSV vào raw"
            step_started_at = _start_step(3, 6, curr_step)
            extract_and_load_all_source_file_to_raw(connection)
            _finish_step(curr_step, step_started_at)

            curr_step = "Kiểm tra chất lượng dữ liệu"
            step_started_at = _start_step(4, 6, curr_step)
            validate_and_route_all_tables(connection)
            _finish_step(curr_step, step_started_at)

            curr_step = "Tổng hợp dữ liệu vào data warehouse"
            step_started_at = _start_step(5, 6, curr_step)
            transform_all_tables(connection)
            _finish_step(curr_step, step_started_at)

            curr_step = "Kiểm tra dữ liệu mart"
            step_started_at = _start_step(6, 6, curr_step)
            # get_train_data(connection)
            get_predict_data(connection)
            _finish_step(curr_step, step_started_at)

        _print_complete("PIPELINE DỮ LIỆU HOÀN TẤT", started_at)

    except Exception as error:
        _print_failure(curr_step, error)
        raise SystemExit(1)


def predict():
    _print_header("DỰ ĐOÁN NGUY CƠ FAIL")
    started_at = perf_counter()
    curr_step = "Đọc và kiểm tra dữ liệu mart"

    try:
        with get_connection() as connection:
            step_started_at = _start_step(1, 4, curr_step)
            predict_df = get_predict_data(connection)
            _finish_step(curr_step, step_started_at)

            curr_step = "Tải mô hình"
            step_started_at = _start_step(2, 4, curr_step)
            model = get_model('final_model')
            _finish_step(curr_step, step_started_at)

            curr_step = "Dự đoán và tính SHAP"
            step_started_at = _start_step(3, 4, curr_step)
            result_df = model_predict(model, predict_df)
            print()
            _finish_step(curr_step, step_started_at)

            curr_step = "Lưu kết quả prediction"
            step_started_at = _start_step(4, 4, curr_step)
            row_count = save_prediction(connection, result_df)
            _finish_step(curr_step, step_started_at)

        print(f"Đã lưu {row_count:,} bản ghi dự đoán.")
        _print_complete("DỰ ĐOÁN HOÀN TẤT", started_at)

    except Exception as error:
        _print_failure(curr_step, error)
        raise SystemExit(1)

def run_all():
    """
    Chạy tuần tự các bước cần thiết.
    """
    _print_header("CHẠY TOÀN BỘ LEARNING ANALYTICS PIPELINE")
    started_at = perf_counter()

    init_db()
    run_data_pipeline()
    predict()

    _print_complete("TOÀN BỘ QUY TRÌNH HOÀN TẤT", started_at)


def main():
    just_fix_windows_console()

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
        "predict",
        help="Dự đoán kết quả",
    )
    all_command.set_defaults(handler=predict)

    all_command = commands.add_parser(
        "run-all",
        help="Chạy tuần tự tất cả các bước",
    )
    all_command.set_defaults(handler=run_all)

    args = parser.parse_args()
    args.handler()


if __name__ == "__main__":
    main()
