DROP TABLE IF EXISTS pg_temp.courses_validation;
CREATE TEMP TABLE courses_validation AS
WITH prepared_courses AS (
    SELECT
        source_row_number,
        code_module AS raw_code_module,
        code_presentation AS raw_code_presentation,
        module_presentation_length AS raw_module_length,

        NULLIF(BTRIM(code_module), '') AS clean_code_module,
        NULLIF(BTRIM(code_presentation), '') AS clean_code_presentation,
        NULLIF(BTRIM(module_presentation_length), '') AS module_length_text
    FROM raw.courses
),

parsed_courses AS (
    SELECT
        *,
        module_length_text ~ '^[+-]?[0-9]+$' AS module_length_is_integer,
        CASE
            WHEN module_length_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(module_length_text, '+-')) <= 10
            THEN module_length_text::BIGINT
        END AS parsed_module_length
    FROM prepared_courses
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
        END,
        CASE
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
        END,
        CASE
            WHEN LENGTH(clean_code_presentation) > 5
            THEN JSONB_BUILD_OBJECT(
                'column', 'code_presentation',
                'code', 'TOO_LONG',
                'message', 'Ma lan mo hoc phan dai qua 5 ky tu'
            )
        END,
        CASE
            WHEN module_length_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'module_presentation_length',
                'code', 'REQUIRED',
                'message', 'Thoi luong hoc phan khong duoc de trong'
            )
        END,
        CASE
            WHEN module_length_text IS NOT NULL
                 AND NOT module_length_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'module_presentation_length',
                'code', 'INVALID_INTEGER',
                'message', 'Thoi luong hoc phan phai la so nguyen'
            )
        END,
        CASE
            WHEN module_length_is_integer
                 AND (
                     LENGTH(LTRIM(module_length_text, '+-')) > 10
                     OR parsed_module_length NOT BETWEEN -2147483648 AND 2147483647
                 )
            THEN JSONB_BUILD_OBJECT(
                'column', 'module_presentation_length',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'Thoi luong hoc phan nam ngoai pham vi INTEGER'
            )
        END,
        CASE
            WHEN parsed_module_length BETWEEN -2147483648 AND 2147483647
                 AND parsed_module_length <= 0
            THEN JSONB_BUILD_OBJECT(
                'column', 'module_presentation_length',
                'code', 'NOT_POSITIVE',
                'message', 'Thoi luong hoc phan phai lon hon 0'
            )
        END
    ]::JSONB[], NULL)) AS error_details,

    NULL::BIGINT AS valid_row_rank,
    NULL::BIGINT AS first_valid_module_length
FROM parsed_courses;

CREATE UNIQUE INDEX courses_validation_source_row_idx
    ON courses_validation (source_row_number);

ANALYZE courses_validation;

WITH ranked_valid_courses AS (
    SELECT
        source_row_number,
        ROW_NUMBER() OVER (
            PARTITION BY clean_code_module, clean_code_presentation
            ORDER BY source_row_number
        ) AS valid_row_rank,
        FIRST_VALUE(parsed_module_length) OVER (
            PARTITION BY clean_code_module, clean_code_presentation
            ORDER BY source_row_number
        ) AS first_valid_module_length
    FROM courses_validation
    WHERE JSONB_ARRAY_LENGTH(error_details) = 0
)

UPDATE courses_validation AS course
SET valid_row_rank = ranked.valid_row_rank,
    first_valid_module_length = ranked.first_valid_module_length
FROM ranked_valid_courses AS ranked
WHERE course.source_row_number = ranked.source_row_number;

UPDATE courses_validation
SET error_details = error_details || JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT(
    'column', 'code_module, code_presentation',
    'code', CASE
        WHEN parsed_module_length = first_valid_module_length
        THEN 'EXACT_DUPLICATE'
        ELSE 'CONFLICTING_DUPLICATE'
    END,
    'message', CASE
        WHEN parsed_module_length = first_valid_module_length
        THEN 'Dong trung hoan toan voi dong hop le dau tien'
        ELSE 'Cung khoa nhung thoi luong khac dong hop le dau tien'
    END
))
WHERE valid_row_rank > 1;

INSERT INTO quarantine.courses (
    source_file,
    source_row_number,
    code_module,
    code_presentation,
    module_presentation_length,
    error_details
)
SELECT
    'courses.csv',
    source_row_number,
    raw_code_module,
    raw_code_presentation,
    raw_module_length,
    error_details
FROM courses_validation
WHERE JSONB_ARRAY_LENGTH(error_details) > 0;

INSERT INTO clean.courses (
    code_module,
    code_presentation,
    module_presentation_length
)
SELECT
    clean_code_module,
    clean_code_presentation,
    parsed_module_length::INTEGER
FROM courses_validation
WHERE JSONB_ARRAY_LENGTH(error_details) = 0;

DROP TABLE courses_validation;

WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.courses) AS raw_count,
        (SELECT COUNT(*) FROM clean.courses) AS clean_count,
        (SELECT COUNT(*) FROM quarantine.courses) AS quarantine_count
)
SELECT
    raw_count,
    clean_count,
    quarantine_count,
    raw_count = clean_count + quarantine_count AS is_reconciled
FROM row_counts;
