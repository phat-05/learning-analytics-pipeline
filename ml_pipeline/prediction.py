import joblib as jb
import numpy as np
import pandas as pd
from config import MODELS_DIR
import shap
from psycopg import sql

def get_model(model_name):
    return jb.load(MODELS_DIR / f"{model_name}.joblib")

def model_predict(artifact, predict_df):
    model = artifact["model"]
    threshold = artifact["threshold"]
    preprocessor = model.named_steps["preprocessor"]

    all_prob = model.predict_proba(predict_df)[:, 1]
    df_processed = preprocessor.transform(predict_df)
    feature_names = artifact["metadata"]["processed_features"]

    explainer = shap.Explainer(
        model.named_steps["model"],
        artifact["shap_background"],
        feature_names=feature_names
    )

    shap_values = explainer(
        df_processed,
        check_additivity=False,
    )

    top_3 = np.argsort(-np.abs(shap_values.values), axis=1)[:, :3]

    def explain_row(i):
        factors = {}

        for j in top_3[i]:
            group, name = feature_names[j].split("__", 1)

            value = (
                int(df_processed[i, j])
                if group == "categorical" or name.startswith("missingindicator_")
                else predict_df.iloc[i][name]
            )

            factors[name] = {
                "value": None if pd.isna(value) else value,
                "contribution": round(float(shap_values.values[i, j]), 4)
            }

        return factors

    result_df = predict_df.copy()
    result_df["probability_fail"] = all_prob
    result_df["prediction"] = np.where(all_prob >= threshold, "Fail", "Not Fail")
    result_df["top_3_factors"] = [
        explain_row(i) for i in range(len(predict_df))
    ]

    return result_df

def truncate_prediction(connection):
    with connection.cursor() as cursor:
        cursor.execute("""
                       TRUNCATE TABLE
                           prediction.prediction_contribution,
                prediction.student_week_prediction
            RESTART IDENTITY;
                       """)


def save_prediction(connection, result_df):
    inserted_count = 0
    with connection.cursor() as cur:
        truncate_prediction(connection)

        for _, row in result_df.iterrows():
            insert_prediction_query = sql.SQL(
                """
                INSERT INTO prediction.student_week_prediction
                    (module_presentation_student_week_id, risk_probability, predict_result)
                VALUES (%s, %s, %s) RETURNING prediction_id
                """
            )

            cur.execute(insert_prediction_query, (
                row['module_presentation_student_week_id'],
                row['probability_fail'],
                row['prediction'],
            ))

            prediction_id = cur.fetchone()[0]

            contribution_rows = [
                (
                    prediction_id,
                    rank,
                    k,
                    str(v['value']) if v['value'] is not None else None,
                    float(v['contribution'])
                )
                for rank, (k, v) in enumerate(row['top_3_factors'].items(), start=1)
            ]

            insert_contribution_query = sql.SQL(
                """
                INSERT INTO prediction.prediction_contribution
                      (prediction_id, factor_rank, factor_name, factor_value, shap_value)
                VALUES (%s, %s, %s, %s, %s)
                """
            )

            cur.executemany(insert_contribution_query, contribution_rows)

            inserted_count += 1

        connection.commit()

    return inserted_count