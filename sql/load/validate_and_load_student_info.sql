DROP TABLE IF EXISTS pg_temp.student_info_validation;

CREATE TEMP TABLE student_info_validation AS
WITH prepared_student_info AS (
    SELECT
        source_row_number,

        code_module AS raw_code_module,
        code_presentation AS raw_code_presentation,
        id_student AS raw_id_student,
        gender AS raw_gender,
        region AS raw_region,
        highest_education AS raw_highest_education,
        imd_band AS raw_imd_band,
        age_band AS raw_age_band,
        num_of_prev_attempts AS raw_num_of_prev_attempts,
        studied_credits AS raw_studied_credits,
        disability AS raw_disability,
        final_result AS raw_final_result,

        NULLIF(BTRIM(code_module), '') AS clean_code_module,
        NULLIF(BTRIM(code_presentation), '') AS clean_code_presentation,
        NULLIF(BTRIM(id_student), '') AS id_student_text,
        NULLIF(BTRIM(gender), '') AS clean_gender,
        NULLIF(BTRIM(region), '') AS clean_region,
        NULLIF(BTRIM(highest_education), '') AS clean_highest_education,
        CASE
            WHEN NULLIF(BTRIM(imd_band), '') = '10-20'
            THEN '10-20%'
            ELSE NULLIF(BTRIM(imd_band), '')
        END AS clean_imd_band,
        NULLIF(BTRIM(age_band), '') AS clean_age_band,
        NULLIF(BTRIM(num_of_prev_attempts), '') AS prev_attempts_text,
        NULLIF(BTRIM(studied_credits), '') AS studied_credits_text,
        NULLIF(BTRIM(disability), '') AS clean_disability,
        NULLIF(BTRIM(final_result), '') AS clean_final_result
    FROM raw.student_info
),

parsed_student_info AS (
    SELECT
        *,
        id_student_text ~ '^[+-]?[0-9]+$' AS id_student_is_integer,
        prev_attempts_text ~ '^[+-]?[0-9]+$'
            AS prev_attempts_is_integer,
        studied_credits_text ~ '^[+-]?[0-9]+$'
            AS studied_credits_is_integer,

        CASE
            WHEN id_student_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(id_student_text, '+-')) <= 19
            THEN id_student_text::NUMERIC
        END AS parsed_id_student,

        CASE
            WHEN prev_attempts_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(prev_attempts_text, '+-')) <= 10
            THEN prev_attempts_text::NUMERIC
        END AS parsed_prev_attempts,

        CASE
            WHEN studied_credits_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(studied_credits_text, '+-')) <= 10
            THEN studied_credits_text::NUMERIC
        END AS parsed_studied_credits
    FROM prepared_student_info
)

SELECT
    *,
    TO_JSONB(ARRAY_REMOVE(ARRAY[
        CASE
            WHEN clean_code_module IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'code_module',
                'code', 'REQUIRED',
                'message', 'Ma hoc phan khong duoc de trong'
            )
            WHEN LENGTH(clean_code_module) > 3
            THEN JSONB_BUILD_OBJECT(
                'column', 'code_module',
                'code', 'TOO_LONG',
                'message', 'Ma hoc phan dai qua 3 ky tu'
            )
        END,

        CASE
            WHEN clean_code_presentation IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'code_presentation',
                'code', 'REQUIRED',
                'message', 'Ma lan mo hoc phan khong duoc de trong'
            )
            WHEN LENGTH(clean_code_presentation) > 5
            THEN JSONB_BUILD_OBJECT(
                'column', 'code_presentation',
                'code', 'TOO_LONG',
                'message', 'Ma lan mo hoc phan dai qua 5 ky tu'
            )
        END,

        CASE
            WHEN id_student_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_student',
                'code', 'REQUIRED',
                'message', 'Ma sinh vien khong duoc de trong'
            )
            WHEN NOT id_student_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_student',
                'code', 'INVALID_INTEGER',
                'message', 'Ma sinh vien phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(id_student_text, '+-')) > 19
                 OR parsed_id_student NOT BETWEEN
                    -9223372036854775808 AND 9223372036854775807
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_student',
                'code', 'BIGINT_OUT_OF_RANGE',
                'message', 'Ma sinh vien nam ngoai pham vi BIGINT'
            )
            WHEN parsed_id_student <= 0
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_student',
                'code', 'NOT_POSITIVE',
                'message', 'Ma sinh vien phai lon hon 0'
            )
        END,

        CASE
            WHEN clean_gender IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'gender',
                'code', 'REQUIRED',
                'message', 'Gioi tinh khong duoc de trong'
            )
            WHEN clean_gender NOT IN ('F', 'M')
            THEN JSONB_BUILD_OBJECT(
                'column', 'gender',
                'code', 'INVALID_VALUE',
                'message', 'Gioi tinh chi nhan F hoac M'
            )
        END,

        CASE
            WHEN clean_region IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'region',
                'code', 'REQUIRED',
                'message', 'Khu vuc khong duoc de trong'
            )
            WHEN clean_region NOT IN (
                'East Anglian Region',
                'East Midlands Region',
                'Ireland',
                'London Region',
                'North Region',
                'North Western Region',
                'Scotland',
                'South East Region',
                'South Region',
                'South West Region',
                'Wales',
                'West Midlands Region',
                'Yorkshire Region'
            )
            THEN JSONB_BUILD_OBJECT(
                'column', 'region',
                'code', 'INVALID_VALUE',
                'message', 'Khu vuc khong thuoc danh muc OULAD'
            )
        END,

        CASE
            WHEN clean_highest_education IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'highest_education',
                'code', 'REQUIRED',
                'message', 'Trinh do hoc van khong duoc de trong'
            )
            WHEN clean_highest_education NOT IN (
                'No Formal quals',
                'Lower Than A Level',
                'A Level or Equivalent',
                'HE Qualification',
                'Post Graduate Qualification'
            )
            THEN JSONB_BUILD_OBJECT(
                'column', 'highest_education',
                'code', 'INVALID_VALUE',
                'message', 'Trinh do hoc van khong thuoc danh muc OULAD'
            )
        END,

        CASE
            WHEN clean_imd_band IS NOT NULL
                 AND clean_imd_band NOT IN (
                    '0-10%',
                    '10-20%',
                    '20-30%',
                    '30-40%',
                    '40-50%',
                    '50-60%',
                    '60-70%',
                    '70-80%',
                    '80-90%',
                    '90-100%'
                 )
            THEN JSONB_BUILD_OBJECT(
                'column', 'imd_band',
                'code', 'INVALID_VALUE',
                'message', 'Nhom IMD khong thuoc danh muc OULAD'
            )
        END,

        CASE
            WHEN clean_age_band IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'age_band',
                'code', 'REQUIRED',
                'message', 'Nhom tuoi khong duoc de trong'
            )
            WHEN clean_age_band NOT IN ('0-35', '35-55', '55<=')
            THEN JSONB_BUILD_OBJECT(
                'column', 'age_band',
                'code', 'INVALID_VALUE',
                'message', 'Nhom tuoi khong thuoc danh muc OULAD'
            )
        END,

        CASE
            WHEN prev_attempts_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'num_of_prev_attempts',
                'code', 'REQUIRED',
                'message', 'So lan hoc truoc khong duoc de trong'
            )
            WHEN NOT prev_attempts_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'num_of_prev_attempts',
                'code', 'INVALID_INTEGER',
                'message', 'So lan hoc truoc phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(prev_attempts_text, '+-')) > 10
                 OR parsed_prev_attempts NOT BETWEEN
                    -2147483648 AND 2147483647
            THEN JSONB_BUILD_OBJECT(
                'column', 'num_of_prev_attempts',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'So lan hoc truoc nam ngoai pham vi INTEGER'
            )
            WHEN parsed_prev_attempts < 0
            THEN JSONB_BUILD_OBJECT(
                'column', 'num_of_prev_attempts',
                'code', 'NEGATIVE',
                'message', 'So lan hoc truoc khong duoc am'
            )
        END,

        CASE
            WHEN studied_credits_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'studied_credits',
                'code', 'REQUIRED',
                'message', 'So tin chi theo hoc khong duoc de trong'
            )
            WHEN NOT studied_credits_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'studied_credits',
                'code', 'INVALID_INTEGER',
                'message', 'So tin chi theo hoc phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(studied_credits_text, '+-')) > 10
                 OR parsed_studied_credits NOT BETWEEN
                    -2147483648 AND 2147483647
            THEN JSONB_BUILD_OBJECT(
                'column', 'studied_credits',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'So tin chi theo hoc nam ngoai pham vi INTEGER'
            )
            WHEN parsed_studied_credits <= 0
            THEN JSONB_BUILD_OBJECT(
                'column', 'studied_credits',
                'code', 'NOT_POSITIVE',
                'message', 'So tin chi theo hoc phai lon hon 0'
            )
        END,

        CASE
            WHEN clean_disability IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'disability',
                'code', 'REQUIRED',
                'message', 'Thong tin khuyet tat khong duoc de trong'
            )
            WHEN clean_disability NOT IN ('N', 'Y')
            THEN JSONB_BUILD_OBJECT(
                'column', 'disability',
                'code', 'INVALID_VALUE',
                'message', 'Thong tin khuyet tat chi nhan N hoac Y'
            )
        END,

        CASE
            WHEN clean_final_result IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'final_result',
                'code', 'REQUIRED',
                'message', 'Ket qua cuoi ky khong duoc de trong'
            )
            WHEN clean_final_result NOT IN (
                'Distinction',
                'Pass',
                'Fail',
                'Withdrawn'
            )
            THEN JSONB_BUILD_OBJECT(
                'column', 'final_result',
                'code', 'INVALID_VALUE',
                'message', 'Ket qua cuoi ky khong thuoc danh muc OULAD'
            )
        END
    ]::JSONB[], NULL)) AS error_details,
    JSONB_BUILD_ARRAY(
        clean_gender,
        clean_region,
        clean_highest_education,
        clean_imd_band,
        clean_age_band,
        parsed_prev_attempts,
        parsed_studied_credits,
        clean_disability,
        clean_final_result
    ) AS row_signature,
    NULL::JSONB AS first_row_signature,
    NULL::BIGINT AS valid_row_rank
FROM parsed_student_info;

CREATE UNIQUE INDEX student_info_validation_source_row_idx
    ON student_info_validation (source_row_number);

ANALYZE student_info_validation;

UPDATE student_info_validation AS student
SET error_details = student.error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'code_module, code_presentation',
        'code', 'COURSE_NOT_FOUND',
        'message', 'Hoc phan khong ton tai trong clean.courses'
    )
)
WHERE JSONB_ARRAY_LENGTH(error_details) = 0
  AND NOT EXISTS (
      SELECT 1
      FROM clean.courses AS course
      WHERE course.code_module = student.clean_code_module
        AND course.code_presentation = student.clean_code_presentation
  );

WITH ranked_valid_students AS (
    SELECT
        source_row_number,
        ROW_NUMBER() OVER (
            PARTITION BY
                clean_code_module,
                clean_code_presentation,
                parsed_id_student
            ORDER BY source_row_number
        ) AS valid_row_rank,
        FIRST_VALUE(row_signature) OVER (
            PARTITION BY
                clean_code_module,
                clean_code_presentation,
                parsed_id_student
            ORDER BY source_row_number
        ) AS first_row_signature
    FROM student_info_validation
    WHERE JSONB_ARRAY_LENGTH(error_details) = 0
)

UPDATE student_info_validation AS student
SET valid_row_rank = ranked.valid_row_rank,
    first_row_signature = ranked.first_row_signature
FROM ranked_valid_students AS ranked
WHERE student.source_row_number = ranked.source_row_number;

UPDATE student_info_validation
SET error_details = error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'code_module, code_presentation, id_student',
        'code', CASE
            WHEN row_signature = first_row_signature
            THEN 'EXACT_DUPLICATE'
            ELSE 'CONFLICTING_DUPLICATE'
        END,
        'message', CASE
            WHEN row_signature = first_row_signature
            THEN 'Dong trung hoan toan voi dong hop le dau tien'
            ELSE 'Cung khoa sinh vien nhung thong tin khong nhat quan'
        END
    )
)
WHERE valid_row_rank > 1;

INSERT INTO quarantine.student_info (
    source_file,
    source_row_number,
    code_module,
    code_presentation,
    id_student,
    gender,
    region,
    highest_education,
    imd_band,
    age_band,
    num_of_prev_attempts,
    studied_credits,
    disability,
    final_result,
    error_details
)
SELECT
    'studentInfo.csv',
    source_row_number,
    raw_code_module,
    raw_code_presentation,
    raw_id_student,
    raw_gender,
    raw_region,
    raw_highest_education,
    raw_imd_band,
    raw_age_band,
    raw_num_of_prev_attempts,
    raw_studied_credits,
    raw_disability,
    raw_final_result,
    error_details
FROM student_info_validation
WHERE JSONB_ARRAY_LENGTH(error_details) > 0;

INSERT INTO clean.student_info (
    code_module,
    code_presentation,
    id_student,
    gender,
    region,
    highest_education,
    imd_band,
    age_band,
    num_of_prev_attempts,
    studied_credits,
    disability,
    final_result
)
SELECT
    clean_code_module,
    clean_code_presentation,
    parsed_id_student::BIGINT,
    clean_gender,
    clean_region,
    clean_highest_education,
    clean_imd_band,
    clean_age_band,
    parsed_prev_attempts::INTEGER,
    parsed_studied_credits::INTEGER,
    clean_disability,
    clean_final_result
FROM student_info_validation
WHERE JSONB_ARRAY_LENGTH(error_details) = 0;

DROP TABLE student_info_validation;

WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.student_info) AS raw_count,
        (SELECT COUNT(*) FROM clean.student_info) AS clean_count,
        (SELECT COUNT(*) FROM quarantine.student_info) AS quarantine_count
)
SELECT
    raw_count,
    clean_count,
    quarantine_count,
    raw_count = clean_count + quarantine_count AS is_reconciled
FROM row_counts;
