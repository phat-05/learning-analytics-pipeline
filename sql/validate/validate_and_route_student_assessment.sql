DROP TABLE IF EXISTS pg_temp.student_assessment_validation;

CREATE TEMP TABLE student_assessment_validation AS
WITH prepared_student_assessment AS (
    SELECT
        source_row_number,

        id_assessment AS raw_id_assessment,
        id_student AS raw_id_student,
        date_submitted AS raw_date_submitted,
        is_banked AS raw_is_banked,
        score AS raw_score,

        NULLIF(BTRIM(id_assessment), '') AS id_assessment_text,
        NULLIF(BTRIM(id_student), '') AS id_student_text,
        NULLIF(BTRIM(date_submitted), '') AS submitted_date_text,
        NULLIF(BTRIM(is_banked), '') AS is_banked_text,
        NULLIF(BTRIM(score), '') AS score_text
    FROM raw.student_assessment
),

parsed_student_assessment AS (
    SELECT
        *,
        id_assessment_text ~ '^[+-]?[0-9]+$'
            AS id_assessment_is_integer,
        id_student_text ~ '^[+-]?[0-9]+$'
            AS id_student_is_integer,
        submitted_date_text ~ '^[+-]?[0-9]+$'
            AS submitted_date_is_integer,
        is_banked_text ~ '^[+-]?[0-9]+$'
            AS is_banked_is_integer,
        score_text ~ '^[+-]?[0-9]+(\.[0-9]{1,2})?$'
            AS score_is_numeric,

        CASE
            WHEN id_assessment_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(id_assessment_text, '+-')) <= 19
            THEN id_assessment_text::NUMERIC
        END AS parsed_id_assessment,

        CASE
            WHEN id_student_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(id_student_text, '+-')) <= 19
            THEN id_student_text::NUMERIC
        END AS parsed_id_student,

        CASE
            WHEN submitted_date_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(submitted_date_text, '+-')) <= 10
            THEN submitted_date_text::NUMERIC
        END AS parsed_submitted_date,

        CASE
            WHEN is_banked_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(is_banked_text, '+-')) <= 5
            THEN is_banked_text::NUMERIC
        END AS parsed_is_banked,

        CASE
            WHEN score_text ~ '^[+-]?[0-9]+(\.[0-9]{1,2})?$'
                 AND LENGTH(LTRIM(score_text, '+-')) <= 20
            THEN score_text::NUMERIC
        END AS parsed_score
    FROM prepared_student_assessment
)

SELECT
    *,
    CASE
        WHEN parsed_id_assessment BETWEEN
            -9223372036854775808 AND 9223372036854775807
        THEN parsed_id_assessment::BIGINT
    END AS typed_id_assessment,
    CASE
        WHEN parsed_id_student BETWEEN
            -9223372036854775808 AND 9223372036854775807
        THEN parsed_id_student::BIGINT
    END AS typed_id_student,
    TO_JSONB(ARRAY_REMOVE(ARRAY[
        CASE
            WHEN id_assessment_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_assessment',
                'code', 'REQUIRED',
                'message', 'Ma bai danh gia khong duoc de trong'
            )
            WHEN NOT id_assessment_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_assessment',
                'code', 'INVALID_INTEGER',
                'message', 'Ma bai danh gia phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(id_assessment_text, '+-')) > 19
                 OR parsed_id_assessment NOT BETWEEN
                    -9223372036854775808 AND 9223372036854775807
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_assessment',
                'code', 'BIGINT_OUT_OF_RANGE',
                'message', 'Ma bai danh gia nam ngoai pham vi BIGINT'
            )
            WHEN parsed_id_assessment <= 0
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_assessment',
                'code', 'NOT_POSITIVE',
                'message', 'Ma bai danh gia phai lon hon 0'
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
            WHEN submitted_date_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'date_submitted',
                'code', 'REQUIRED',
                'message', 'Ngay nop bai khong duoc de trong'
            )
            WHEN NOT submitted_date_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'date_submitted',
                'code', 'INVALID_INTEGER',
                'message', 'Ngay nop bai phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(submitted_date_text, '+-')) > 10
                 OR parsed_submitted_date NOT BETWEEN
                    -2147483648 AND 2147483647
            THEN JSONB_BUILD_OBJECT(
                'column', 'date_submitted',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'Ngay nop bai nam ngoai pham vi INTEGER'
            )
        END,

        CASE
            WHEN is_banked_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'is_banked',
                'code', 'REQUIRED',
                'message', 'Trang thai bao luu khong duoc de trong'
            )
            WHEN NOT is_banked_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'is_banked',
                'code', 'INVALID_INTEGER',
                'message', 'Trang thai bao luu phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(is_banked_text, '+-')) > 5
                 OR parsed_is_banked NOT BETWEEN -32768 AND 32767
            THEN JSONB_BUILD_OBJECT(
                'column', 'is_banked',
                'code', 'SMALLINT_OUT_OF_RANGE',
                'message', 'Trang thai bao luu nam ngoai pham vi SMALLINT'
            )
            WHEN parsed_is_banked NOT IN (0, 1)
            THEN JSONB_BUILD_OBJECT(
                'column', 'is_banked',
                'code', 'INVALID_VALUE',
                'message', 'Trang thai bao luu chi nhan 0 hoac 1'
            )
        END,

        CASE
            WHEN score_text IS NOT NULL
                 AND NOT score_is_numeric
            THEN JSONB_BUILD_OBJECT(
                'column', 'score',
                'code', 'INVALID_DECIMAL',
                'message', 'Diem phai la so co toi da 2 chu so thap phan'
            )
            WHEN score_is_numeric
                 AND (
                    LENGTH(LTRIM(score_text, '+-')) > 20
                    OR parsed_score NOT BETWEEN 0 AND 100
                 )
            THEN JSONB_BUILD_OBJECT(
                'column', 'score',
                'code', 'OUT_OF_RANGE',
                'message', 'Diem phai nam trong khoang tu 0 den 100'
            )
        END
    ]::JSONB[], NULL)) AS error_details,
    JSONB_BUILD_ARRAY(
        parsed_submitted_date,
        parsed_is_banked,
        parsed_score
    ) AS row_signature,
    NULL::JSONB AS first_row_signature,
    NULL::BIGINT AS valid_row_rank
FROM parsed_student_assessment;

CREATE UNIQUE INDEX student_assessment_validation_source_row_idx
    ON student_assessment_validation (source_row_number);

ANALYZE student_assessment_validation;

UPDATE student_assessment_validation AS result
SET error_details = result.error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'id_assessment',
        'code', 'ASSESSMENT_NOT_FOUND',
        'message', 'Bai danh gia khong ton tai trong clean.assessments'
    )
)
WHERE JSONB_ARRAY_LENGTH(result.error_details) = 0
  AND NOT EXISTS (
      SELECT 1
      FROM clean.assessments AS assessment
      WHERE assessment.id_assessment = result.typed_id_assessment
  );

UPDATE student_assessment_validation AS result
SET error_details = result.error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'id_assessment, id_student',
        'code', 'STUDENT_NOT_FOUND_FOR_ASSESSMENT',
        'message', 'Sinh vien khong thuoc hoc phan cua bai danh gia'
    )
)
WHERE JSONB_ARRAY_LENGTH(result.error_details) = 0
  AND NOT EXISTS (
      SELECT 1
      FROM clean.assessments AS assessment
      JOIN clean.student_info AS student
        ON student.code_module = assessment.code_module
       AND student.code_presentation = assessment.code_presentation
       AND student.id_student = result.typed_id_student
      WHERE assessment.id_assessment = result.typed_id_assessment
  );

WITH ranked_valid_results AS (
    SELECT
        source_row_number,
        ROW_NUMBER() OVER (
            PARTITION BY typed_id_assessment, typed_id_student
            ORDER BY source_row_number
        ) AS valid_row_rank,
        FIRST_VALUE(row_signature) OVER (
            PARTITION BY typed_id_assessment, typed_id_student
            ORDER BY source_row_number
        ) AS first_row_signature
    FROM student_assessment_validation
    WHERE JSONB_ARRAY_LENGTH(error_details) = 0
)

UPDATE student_assessment_validation AS result
SET valid_row_rank = ranked.valid_row_rank,
    first_row_signature = ranked.first_row_signature
FROM ranked_valid_results AS ranked
WHERE result.source_row_number = ranked.source_row_number;

UPDATE student_assessment_validation
SET error_details = error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'id_assessment, id_student',
        'code', CASE
            WHEN row_signature = first_row_signature
            THEN 'EXACT_DUPLICATE'
            ELSE 'CONFLICTING_DUPLICATE'
        END,
        'message', CASE
            WHEN row_signature = first_row_signature
            THEN 'Dong trung hoan toan voi dong hop le dau tien'
            ELSE 'Cung khoa ket qua nhung thong tin khong nhat quan'
        END
    )
)
WHERE valid_row_rank > 1;

INSERT INTO quarantine.student_assessment (
    source_file,
    source_row_number,
    id_assessment,
    id_student,
    date_submitted,
    is_banked,
    score,
    error_details
)
SELECT
    'studentAssessment.csv',
    source_row_number,
    raw_id_assessment,
    raw_id_student,
    raw_date_submitted,
    raw_is_banked,
    raw_score,
    error_details
FROM student_assessment_validation
WHERE JSONB_ARRAY_LENGTH(error_details) > 0;

-- Score giu NULL neu nguon khong cung cap.
INSERT INTO clean.student_assessment (
    id_assessment,
    id_student,
    date_submitted,
    is_banked,
    score
)
SELECT
    typed_id_assessment,
    typed_id_student,
    parsed_submitted_date::INTEGER,
    parsed_is_banked::SMALLINT,
    parsed_score::NUMERIC(5, 2)
FROM student_assessment_validation
WHERE JSONB_ARRAY_LENGTH(error_details) = 0;

DROP TABLE student_assessment_validation;

-- Ket qua cuoi cung duoc Python doc de kiem tra doi soat.
WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.student_assessment) AS raw_count,
        (SELECT COUNT(*) FROM clean.student_assessment) AS clean_count,
        (SELECT COUNT(*) FROM quarantine.student_assessment)
            AS quarantine_count
)
SELECT
    raw_count,
    clean_count,
    quarantine_count,
    raw_count = clean_count + quarantine_count AS is_reconciled
FROM row_counts;
