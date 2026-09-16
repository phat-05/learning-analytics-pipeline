import pandas as pd
from config import GET_TRAIN_DATA_FILE, GET_PREDICT_DATA_FILE
from elt_pipeline.mart_validation import validate_mart_data, validate_train_data


def _get_data(connection, sql_script):
    with connection.cursor() as cursor:
        #TODO(Kiểm tra tính khả dụng của mart trước khi lấy dữ liệu huấn luyện hoặc dự đoán)

        cursor.execute(sql_script)

        columns = [column.name for column in cursor.description]

        df = pd.DataFrame.from_records(cursor, columns=columns)

        validate_mart_data(df)

        return df


def get_train_data(connection):
    sql_script = GET_TRAIN_DATA_FILE.read_text(encoding="utf-8")

    df = _get_data(connection, sql_script)

    validate_train_data(df)

    return df


def get_predict_data(connection):
    sql_script = GET_PREDICT_DATA_FILE.read_text(encoding="utf-8")

    return _get_data(connection, sql_script)
