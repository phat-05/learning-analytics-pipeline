DROP TABLE IF EXISTS pg_temp.assessments_validation;

CREATE TEMP TABLE assessments_validation AS
WITH prepared_assessments AS (
    SELECT
        source_row_number,

        code_module AS raw_code_module,
        code_presentation AS raw_code_presentation,
        id_assessment AS raw_id_assessment,
        assessment_type AS raw_assessment_type,
        date AS raw_date,
        weight AS raw_weight,

        NULLIF(BTRIM(code_module), '') AS clean_code_module,
        NULLIF(BTRIM(code_presentation), '') AS clean_code_presentation,
        NULLIF(BTRIM(id_assessment), '') AS id_assessment_text,
        NULLIF(BTRIM(assessment_type), '') AS clean_assessment_type,
        NULLIF(BTRIM(date), '') AS date_text,
        NULLIF(BTRIM(weight), '') AS weight_text
    FROM raw.assessments
),

parsed_assessments AS (
    SELECT
        *,
        id_assessment_text ~ '^[+-]?[0-9]+$'
            AS id_assessment_is_integer,
        date_text ~ '^[+-]?[0-9]+$'
            AS date_is_integer,
        weight_text ~ '^[+-]?[0-9]+(\.[0-9]{1,2})?$'
            AS weight_is_numeric,

        CASE
            WHEN id_assessment_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(id_assessment_text, '+-')) <= 19
            THEN id_assessment_text::NUMERIC
        END AS parsed_id_assessment,

        CASE
            WHEN date_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(date_text, '+-')) <= 10
            THEN date_text::NUMERIC
        END AS parsed_date,

        CASE
            WHEN weight_text ~ '^[+-]?[0-9]+(\.[0-9]{1,2})?$'
                 AND LENGTH(LTRIM(weight_text, '+-')) <= 20
            THEN weight_text::NUMERIC
        END AS parsed_weight
    FROM prepared_assessments
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
            WHEN clean_assessment_type IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'assessment_type',
                'code', 'REQUIRED',
                'message', 'Loai bai danh gia khong duoc de trong'
            )
            WHEN clean_assessment_type NOT IN ('CMA', 'TMA', 'Exam')
            THEN JSONB_BUILD_OBJECT(
                'column', 'assessment_type',
                'code', 'INVALID_VALUE',
                'message', 'Loai bai danh gia chi nhan CMA, TMA hoac Exam'
            )
        END,

        CASE
            WHEN date_text IS NULL
                 AND clean_assessment_type IN ('CMA', 'TMA')
            THEN JSONB_BUILD_OBJECT(
                'column', 'date',
                'code', 'REQUIRED_FOR_COURSEWORK',
                'message', 'CMA va TMA phai co ngay het han'
            )
            WHEN date_text IS NOT NULL
                 AND NOT date_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'date',
                'code', 'INVALID_INTEGER',
                'message', 'Ngay het han phai la so nguyen'
            )
            WHEN date_is_integer
                 AND (
                    LENGTH(LTRIM(date_text, '+-')) > 10
                    OR parsed_date NOT BETWEEN
                        -2147483648 AND 2147483647
                 )
            THEN JSONB_BUILD_OBJECT(
                'column', 'date',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'Ngay het han nam ngoai pham vi INTEGER'
            )
            WHEN parsed_date < 0
            THEN JSONB_BUILD_OBJECT(
                'column', 'date',
                'code', 'NEGATIVE',
                'message', 'Ngay het han khong duoc am'
            )
        END,

        CASE
            WHEN weight_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'weight',
                'code', 'REQUIRED',
                'message', 'Trong so khong duoc de trong'
            )
            WHEN NOT weight_is_numeric
            THEN JSONB_BUILD_OBJECT(
                'column', 'weight',
                'code', 'INVALID_DECIMAL',
                'message', 'Trong so phai la so co toi da 2 chu so thap phan'
            )
            WHEN LENGTH(LTRIM(weight_text, '+-')) > 20
                 OR parsed_weight NOT BETWEEN 0 AND 100
            THEN JSONB_BUILD_OBJECT(
                'column', 'weight',
                'code', 'OUT_OF_RANGE',
                'message', 'Trong so phai nam trong khoang tu 0 den 100'
            )
        END
    ]::JSONB[], NULL)) AS error_details,
    JSONB_BUILD_ARRAY(
        clean_code_module,
        clean_code_presentation,
        clean_assessment_type,
        parsed_date,
        parsed_weight
    ) AS row_signature,
    NULL::JSONB AS first_row_signature,
    NULL::BIGINT AS valid_row_rank
FROM parsed_assessments;

CREATE UNIQUE INDEX assessments_validation_source_row_idx
    ON assessments_validation (source_row_number);

ANALYZE assessments_validation;

UPDATE assessments_validation AS assessment
SET error_details = assessment.error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'code_module, code_presentation',
        'code', 'COURSE_NOT_FOUND',
        'message', 'Hoc phan khong ton tai trong clean.courses'
    )
)
WHERE JSONB_ARRAY_LENGTH(assessment.error_details) = 0
  AND NOT EXISTS (
      SELECT 1
      FROM clean.courses AS course
      WHERE course.code_module = assessment.clean_code_module
        AND course.code_presentation = assessment.clean_code_presentation
  );

WITH ranked_valid_assessments AS (
    SELECT
        source_row_number,
        ROW_NUMBER() OVER (
            PARTITION BY parsed_id_assessment
            ORDER BY source_row_number
        ) AS valid_row_rank,
        FIRST_VALUE(row_signature) OVER (
            PARTITION BY parsed_id_assessment
            ORDER BY source_row_number
        ) AS first_row_signature
    FROM assessments_validation
    WHERE JSONB_ARRAY_LENGTH(error_details) = 0
)

UPDATE assessments_validation AS assessment
SET valid_row_rank = ranked.valid_row_rank,
    first_row_signature = ranked.first_row_signature
FROM ranked_valid_assessments AS ranked
WHERE assessment.source_row_number = ranked.source_row_number;

UPDATE assessments_validation
SET error_details = error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'id_assessment',
        'code', CASE
            WHEN row_signature = first_row_signature
            THEN 'EXACT_DUPLICATE'
            ELSE 'CONFLICTING_DUPLICATE'
        END,
        'message', CASE
            WHEN row_signature = first_row_signature
            THEN 'Dong trung hoan toan voi dong hop le dau tien'
            ELSE 'Cung id_assessment nhung thong tin khong nhat quan'
        END
    )
)
WHERE valid_row_rank > 1;

INSERT INTO quarantine.assessments (
    source_file,
    source_row_number,
    code_module,
    code_presentation,
    id_assessment,
    assessment_type,
    date,
    weight,
    error_details
)
SELECT
    'assessments.csv',
    source_row_number,
    raw_code_module,
    raw_code_presentation,
    raw_id_assessment,
    raw_assessment_type,
    raw_date,
    raw_weight,
    error_details
FROM assessments_validation
WHERE JSONB_ARRAY_LENGTH(error_details) > 0;

INSERT INTO clean.assessments (
    code_module,
    code_presentation,
    id_assessment,
    assessment_type,
    date,
    weight
)
SELECT
    clean_code_module,
    clean_code_presentation,
    parsed_id_assessment::BIGINT,
    clean_assessment_type,
    parsed_date::INTEGER,
    parsed_weight::NUMERIC(5, 2)
FROM assessments_validation
WHERE JSONB_ARRAY_LENGTH(error_details) = 0;

DROP TABLE assessments_validation;

WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.assessments) AS raw_count,
        (SELECT COUNT(*) FROM clean.assessments) AS clean_count,
        (SELECT COUNT(*) FROM quarantine.assessments) AS quarantine_count
)
SELECT
    raw_count,
    clean_count,
    quarantine_count,
    raw_count = clean_count + quarantine_count AS is_reconciled
FROM row_counts;
