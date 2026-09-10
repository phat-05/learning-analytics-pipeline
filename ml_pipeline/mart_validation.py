from config import MODEL_FEATURES


def _none_validate(df):
    if df is None:
        raise ValueError("Chưa nhận được dữ liệu từ mart!")


def _count_validate(df):
    if len(df) == 0:
        raise ValueError("Dữ liệu rỗng! DataFrame không có bản ghi nào!")


def _structure_validate(df):
    if len(df.columns) != len(MODEL_FEATURES):
        raise ValueError(
            f"Số lượng cột không khớp: Expected {len(MODEL_FEATURES)}, "
            f"Actual {len(df.columns)}"
        )

    for col in MODEL_FEATURES.keys():
        if col not in df.columns:
            raise KeyError(f"DataFrame thiếu cột {col}!")


def _null_validate(df):
    for col in df.columns:
        if df[col].isnull().sum() > 0 and col != "imd_band":
            raise ValueError(f"Cột {col} chứa giá trị null!")


def _dtype_validate(df):
    for col, expected_dtype in MODEL_FEATURES.items():
        if df[col].dtype != expected_dtype:
            raise TypeError(
                f"Kiểu dữ liệu cột {col} không khớp: Expected {expected_dtype}, "
                f"Actual {df[col].dtype}"
            )


def _duplicates_validate(df):
    duplicates = df[['code_presentation', 'code_module', 'id_student', 'week_no']].duplicated().sum()
    if duplicates > 0:
        raise ValueError(f"Có {duplicates} dòng trùng grain!")


def _numeric_valiadate(df):
    if (df['week_no'] < 2).sum() > 0:
        raise ValueError(f"Có {(df['week_no'] < 2).sum()} giá trị nhỏ hơn 2 trong week_no!")

    for num in df.select_dtypes(include="number").columns.tolist():
        if (df[num] < 0).sum() > 0:
            raise ValueError(f"Có {(df[num] < 0).sum()} giá trị âm trong cột {num}!")


def _valid_count_validate(df):
    pairs = [
        ("click_count_week", "click_count_to_week"),
        ("active_day_count_week", "active_day_count_to_week"),
        ("coursework_submitted_count_week", "coursework_submitted_count_to_week"),
    ]

    for weekly, cumulative in pairs:
        count = (df[weekly] > df[cumulative]).sum()
        if count > 0:
            raise ValueError(f"{weekly} > {cumulative}: {count} dòng")


def validate_mart_data(df):
    _none_validate(df)
    _count_validate(df)
    _structure_validate(df)
    _null_validate(df)
    _dtype_validate(df)
    _duplicates_validate(df)
    _numeric_valiadate(df)
    _valid_count_validate(df)