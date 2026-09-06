DROP TABLE IF EXISTS pg_temp.student_registration_validation;

-- Chuan hoa chuoi va giu lai gia tri nguon de dua vao quarantine khi can.
CREATE TEMP TABLE student_registration_validation AS
WITH prepared_student_registration AS (
    SELECT
        source_row_number,

        code_module AS raw_code_module,
        code_presentation AS raw_code_presentation,
        id_student AS raw_id_student,
        date_registration AS raw_date_registration,
        date_unregistration AS raw_date_unregistration,

        NULLIF(BTRIM(code_module), '') AS clean_code_module,
        NULLIF(BTRIM(code_presentation), '') AS clean_code_presentation,
        NULLIF(BTRIM(id_student), '') AS id_student_text,
        NULLIF(BTRIM(date_registration), '') AS registration_date_text,
        NULLIF(BTRIM(date_unregistration), '') AS unregistration_date_text
    FROM raw.student_registration
),

-- Chi ep kieu khi chuoi co dang so nguyen va co do dai an toan.
parsed_student_registration AS (
    SELECT
        *,
        id_student_text ~ '^[+-]?[0-9]+$'
            AS id_student_is_integer,
        registration_date_text ~ '^[+-]?[0-9]+$'
            AS registration_date_is_integer,
        unregistration_date_text ~ '^[+-]?[0-9]+$'
            AS unregistration_date_is_integer,

        CASE
            WHEN id_student_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(id_student_text, '+-')) <= 19
            THEN id_student_text::NUMERIC
        END AS parsed_id_student,

        CASE
            WHEN registration_date_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(registration_date_text, '+-')) <= 10
            THEN registration_date_text::NUMERIC
        END AS parsed_registration_date,

        CASE
            WHEN unregistration_date_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(unregistration_date_text, '+-')) <= 10
            THEN unregistration_date_text::NUMERIC
        END AS parsed_unregistration_date
    FROM prepared_student_registration
)

-- Ngay dang ky va ngay huy dang ky duoc phep NULL va duoc phep am.
SELECT
    *,
    CASE
        WHEN parsed_id_student BETWEEN
            -9223372036854775808 AND 9223372036854775807
        THEN parsed_id_student::BIGINT
    END AS typed_id_student,
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
            WHEN registration_date_text IS NOT NULL
                 AND NOT registration_date_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'date_registration',
                'code', 'INVALID_INTEGER',
                'message', 'Ngay dang ky phai la so nguyen'
            )
            WHEN registration_date_is_integer
                 AND (
                    LENGTH(LTRIM(registration_date_text, '+-')) > 10
                    OR parsed_registration_date NOT BETWEEN
                        -2147483648 AND 2147483647
                 )
            THEN JSONB_BUILD_OBJECT(
                'column', 'date_registration',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'Ngay dang ky nam ngoai pham vi INTEGER'
            )
        END,

        CASE
            WHEN unregistration_date_text IS NOT NULL
                 AND NOT unregistration_date_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'date_unregistration',
                'code', 'INVALID_INTEGER',
                'message', 'Ngay huy dang ky phai la so nguyen'
            )
            WHEN unregistration_date_is_integer
                 AND (
                    LENGTH(LTRIM(unregistration_date_text, '+-')) > 10
                    OR parsed_unregistration_date NOT BETWEEN
                        -2147483648 AND 2147483647
                 )
            THEN JSONB_BUILD_OBJECT(
                'column', 'date_unregistration',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'Ngay huy dang ky nam ngoai pham vi INTEGER'
            )
        END,

        CASE
            WHEN parsed_registration_date BETWEEN
                    -2147483648 AND 2147483647
             AND parsed_unregistration_date BETWEEN
                    -2147483648 AND 2147483647
             AND parsed_unregistration_date < parsed_registration_date
            THEN JSONB_BUILD_OBJECT(
                'column', 'date_registration, date_unregistration',
                'code', 'INVALID_DATE_ORDER',
                'message', 'Ngay huy dang ky khong duoc truoc ngay dang ky'
            )
        END
    ]::JSONB[], NULL)) AS error_details,
    JSONB_BUILD_ARRAY(
        parsed_registration_date,
        parsed_unregistration_date
    ) AS row_signature,
    NULL::JSONB AS first_row_signature,
    NULL::BIGINT AS valid_row_rank
FROM parsed_student_registration;

CREATE UNIQUE INDEX student_registration_validation_source_row_idx
    ON student_registration_validation (source_row_number);

ANALYZE student_registration_validation;

-- Khoa ngoai nay dong thoi xac nhan module-presentation cua sinh vien.
UPDATE student_registration_validation AS registration
SET error_details = registration.error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'code_module, code_presentation, id_student',
        'code', 'STUDENT_NOT_FOUND',
        'message', 'Sinh vien khong ton tai trong clean.student_info'
    )
)
WHERE JSONB_ARRAY_LENGTH(registration.error_details) = 0
  AND NOT EXISTS (
      SELECT 1
      FROM clean.student_info AS student
      WHERE student.code_module = registration.clean_code_module
        AND student.code_presentation = registration.clean_code_presentation
        AND student.id_student = registration.typed_id_student
  );

-- Giu dong hop le dau tien cua moi khoa dang ky hoc.
WITH ranked_valid_registrations AS (
    SELECT
        source_row_number,
        ROW_NUMBER() OVER (
            PARTITION BY
                clean_code_module,
                clean_code_presentation,
                typed_id_student
            ORDER BY source_row_number
        ) AS valid_row_rank,
        FIRST_VALUE(row_signature) OVER (
            PARTITION BY
                clean_code_module,
                clean_code_presentation,
                typed_id_student
            ORDER BY source_row_number
        ) AS first_row_signature
    FROM student_registration_validation
    WHERE JSONB_ARRAY_LENGTH(error_details) = 0
)

UPDATE student_registration_validation AS registration
SET valid_row_rank = ranked.valid_row_rank,
    first_row_signature = ranked.first_row_signature
FROM ranked_valid_registrations AS ranked
WHERE registration.source_row_number = ranked.source_row_number;

UPDATE student_registration_validation
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
            ELSE 'Cung khoa dang ky nhung thong tin khong nhat quan'
        END
    )
)
WHERE valid_row_rank > 1;

-- Dung gia tri goc khi luu dong loi.
INSERT INTO quarantine.student_registration (
    source_file,
    source_row_number,
    code_module,
    code_presentation,
    id_student,
    date_registration,
    date_unregistration,
    error_details
)
SELECT
    'studentRegistration.csv',
    source_row_number,
    raw_code_module,
    raw_code_presentation,
    raw_id_student,
    raw_date_registration,
    raw_date_unregistration,
    error_details
FROM student_registration_validation
WHERE JSONB_ARRAY_LENGTH(error_details) > 0;

-- Hai cot ngay giu NULL neu nguon khong cung cap.
INSERT INTO clean.student_registration (
    code_module,
    code_presentation,
    id_student,
    date_registration,
    date_unregistration
)
SELECT
    clean_code_module,
    clean_code_presentation,
    typed_id_student,
    parsed_registration_date::INTEGER,
    parsed_unregistration_date::INTEGER
FROM student_registration_validation
WHERE JSONB_ARRAY_LENGTH(error_details) = 0;

DROP TABLE student_registration_validation;

-- Ket qua cuoi cung duoc Python doc de kiem tra doi soat.
WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.student_registration) AS raw_count,
        (SELECT COUNT(*) FROM clean.student_registration) AS clean_count,
        (SELECT COUNT(*) FROM quarantine.student_registration)
            AS quarantine_count
)
SELECT
    raw_count,
    clean_count,
    quarantine_count,
    raw_count = clean_count + quarantine_count AS is_reconciled
FROM row_counts;
