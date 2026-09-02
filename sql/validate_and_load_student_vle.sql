DROP TABLE IF EXISTS pg_temp.student_vle_validation;
DROP TABLE IF EXISTS pg_temp.student_vle_errors;

-- Chuan hoa va ep kieu raw mot lan, sau do dung lai ket qua o cac buoc sau.
CREATE TEMP TABLE student_vle_validation AS
WITH prepared_student_vle AS (
    SELECT
        source_row_number,
        NULLIF(BTRIM(code_module), '') AS clean_code_module,
        NULLIF(BTRIM(code_presentation), '') AS clean_code_presentation,
        NULLIF(BTRIM(id_student), '') AS id_student_text,
        NULLIF(BTRIM(id_site), '') AS id_site_text,
        NULLIF(BTRIM(date), '') AS date_text,
        NULLIF(BTRIM(sum_click), '') AS sum_click_text
    FROM raw.student_vle
),

parsed_student_vle AS (
    SELECT
        *,
        id_student_text ~ '^[+-]?[0-9]+$'
            AS id_student_is_integer,
        id_site_text ~ '^[+-]?[0-9]+$'
            AS id_site_is_integer,
        date_text ~ '^[+-]?[0-9]+$'
            AS date_is_integer,
        sum_click_text ~ '^[+-]?[0-9]+$'
            AS sum_click_is_integer,

        CASE
            WHEN id_student_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(id_student_text, '+-')) <= 19
            THEN id_student_text::NUMERIC
        END AS parsed_id_student,

        CASE
            WHEN id_site_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(id_site_text, '+-')) <= 19
            THEN id_site_text::NUMERIC
        END AS parsed_id_site,

        CASE
            WHEN date_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(date_text, '+-')) <= 10
            THEN date_text::NUMERIC
        END AS parsed_date,

        CASE
            WHEN sum_click_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(sum_click_text, '+-')) <= 10
            THEN sum_click_text::NUMERIC
        END AS parsed_sum_click
    FROM prepared_student_vle
)

SELECT
    source_row_number,
    clean_code_module,
    clean_code_presentation,
    CASE
        WHEN parsed_id_student BETWEEN
            -9223372036854775808 AND 9223372036854775807
        THEN parsed_id_student::BIGINT
    END AS typed_id_student,
    CASE
        WHEN parsed_id_site BETWEEN
            -9223372036854775808 AND 9223372036854775807
        THEN parsed_id_site::BIGINT
    END AS typed_id_site,
    CASE
        WHEN parsed_date BETWEEN -2147483648 AND 2147483647
        THEN parsed_date::INTEGER
    END AS typed_date,
    CASE
        WHEN parsed_sum_click BETWEEN -2147483648 AND 2147483647
        THEN parsed_sum_click::INTEGER
    END AS typed_sum_click,
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
            WHEN id_site_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_site',
                'code', 'REQUIRED',
                'message', 'Ma tai nguyen khong duoc de trong'
            )
            WHEN NOT id_site_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_site',
                'code', 'INVALID_INTEGER',
                'message', 'Ma tai nguyen phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(id_site_text, '+-')) > 19
                 OR parsed_id_site NOT BETWEEN
                    -9223372036854775808 AND 9223372036854775807
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_site',
                'code', 'BIGINT_OUT_OF_RANGE',
                'message', 'Ma tai nguyen nam ngoai pham vi BIGINT'
            )
            WHEN parsed_id_site <= 0
            THEN JSONB_BUILD_OBJECT(
                'column', 'id_site',
                'code', 'NOT_POSITIVE',
                'message', 'Ma tai nguyen phai lon hon 0'
            )
        END,

        CASE
            WHEN date_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'date',
                'code', 'REQUIRED',
                'message', 'Ngay tuong tac khong duoc de trong'
            )
            WHEN NOT date_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'date',
                'code', 'INVALID_INTEGER',
                'message', 'Ngay tuong tac phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(date_text, '+-')) > 10
                 OR parsed_date NOT BETWEEN -2147483648 AND 2147483647
            THEN JSONB_BUILD_OBJECT(
                'column', 'date',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'Ngay tuong tac nam ngoai pham vi INTEGER'
            )
        END,

        CASE
            WHEN sum_click_text IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'sum_click',
                'code', 'REQUIRED',
                'message', 'So luot nhap khong duoc de trong'
            )
            WHEN NOT sum_click_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'sum_click',
                'code', 'INVALID_INTEGER',
                'message', 'So luot nhap phai la so nguyen'
            )
            WHEN LENGTH(LTRIM(sum_click_text, '+-')) > 10
                 OR parsed_sum_click NOT BETWEEN
                    -2147483648 AND 2147483647
            THEN JSONB_BUILD_OBJECT(
                'column', 'sum_click',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'So luot nhap nam ngoai pham vi INTEGER'
            )
            WHEN parsed_sum_click <= 0
            THEN JSONB_BUILD_OBJECT(
                'column', 'sum_click',
                'code', 'NOT_POSITIVE',
                'message', 'So luot nhap phai lon hon 0'
            )
        END
    ]::JSONB[], NULL)) AS error_details
FROM parsed_student_vle;

ANALYZE student_vle_validation;

-- Bang nay chi luu cac dong loi, khong sao chep toan bo du lieu lan nua.
CREATE TEMP TABLE student_vle_errors (
    source_row_number BIGINT PRIMARY KEY,
    error_details JSONB NOT NULL
);

INSERT INTO student_vle_errors (source_row_number, error_details)
SELECT source_row_number, error_details
FROM student_vle_validation
WHERE JSONB_ARRAY_LENGTH(error_details) > 0;

-- Dung JOIN voi cac khoa da co index thay cho truy van con cho tung dong.
WITH reference_validation AS (
    SELECT
        validation.source_row_number,
        TO_JSONB(ARRAY_REMOVE(ARRAY[
            CASE
                WHEN student.id_student IS NULL
                THEN JSONB_BUILD_OBJECT(
                    'column',
                    'code_module, code_presentation, id_student',
                    'code', 'STUDENT_NOT_FOUND',
                    'message',
                    'Sinh vien khong ton tai trong clean.student_info'
                )
            END,
            CASE
                WHEN resource.id_site IS NULL
                THEN JSONB_BUILD_OBJECT(
                    'column', 'id_site, code_module, code_presentation',
                    'code', 'SITE_NOT_FOUND',
                    'message', 'Tai nguyen khong thuoc hoc phan da khai bao'
                )
            END
        ]::JSONB[], NULL)) AS error_details
    FROM student_vle_validation AS validation
    LEFT JOIN clean.student_info AS student
      ON student.code_module = validation.clean_code_module
     AND student.code_presentation = validation.clean_code_presentation
     AND student.id_student = validation.typed_id_student
    LEFT JOIN clean.vle AS resource
      ON resource.id_site = validation.typed_id_site
     AND resource.code_module = validation.clean_code_module
     AND resource.code_presentation = validation.clean_code_presentation
    WHERE JSONB_ARRAY_LENGTH(validation.error_details) = 0
)

INSERT INTO student_vle_errors (source_row_number, error_details)
SELECT source_row_number, error_details
FROM reference_validation
WHERE JSONB_ARRAY_LENGTH(error_details) > 0;

-- Chi sap xep mot lan de giu dong dau va danh dau cac ban sao phia sau.
WITH ranked_exact_rows AS (
    SELECT
        validation.source_row_number,
        ROW_NUMBER() OVER (
            PARTITION BY
                validation.clean_code_module,
                validation.clean_code_presentation,
                validation.typed_id_student,
                validation.typed_id_site,
                validation.typed_date,
                validation.typed_sum_click
            ORDER BY validation.source_row_number
        ) AS exact_row_rank
    FROM student_vle_validation AS validation
    WHERE NOT EXISTS (
        SELECT 1
        FROM student_vle_errors AS error
        WHERE error.source_row_number = validation.source_row_number
    )
)

INSERT INTO student_vle_errors (source_row_number, error_details)
SELECT
    source_row_number,
    JSONB_BUILD_ARRAY(JSONB_BUILD_OBJECT(
        'column',
        'code_module, code_presentation, id_student, id_site, date, sum_click',
        'code', 'EXACT_DUPLICATE',
        'message', 'Dong trung hoan toan voi dong hop le dau tien'
    ))
FROM ranked_exact_rows
WHERE exact_row_rank > 1;

ANALYZE student_vle_errors;

-- Quarantine van lay gia tri goc tu raw de bao toan kha nang truy nguoc.
INSERT INTO quarantine.student_vle (
    source_file,
    source_row_number,
    code_module,
    code_presentation,
    id_student,
    id_site,
    date,
    sum_click,
    error_details
)
SELECT
    'studentVle.csv',
    raw_row.source_row_number,
    raw_row.code_module,
    raw_row.code_presentation,
    raw_row.id_student,
    raw_row.id_site,
    raw_row.date,
    raw_row.sum_click,
    error.error_details
FROM raw.student_vle AS raw_row
JOIN student_vle_errors AS error
  ON error.source_row_number = raw_row.source_row_number;

-- Cung dinh danh nhung sum_click khac nhau van duoc giu de mart tong hop.
INSERT INTO clean.student_vle (
    code_module,
    code_presentation,
    id_student,
    id_site,
    date,
    sum_click
)
SELECT
    validation.clean_code_module,
    validation.clean_code_presentation,
    validation.typed_id_student,
    validation.typed_id_site,
    validation.typed_date,
    validation.typed_sum_click
FROM student_vle_validation AS validation
WHERE NOT EXISTS (
    SELECT 1
    FROM student_vle_errors AS error
    WHERE error.source_row_number = validation.source_row_number
);

DROP TABLE student_vle_errors;
DROP TABLE student_vle_validation;

-- Ket qua cuoi cung duoc Python doc de kiem tra doi soat.
WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.student_vle) AS raw_count,
        (SELECT COUNT(*) FROM clean.student_vle) AS clean_count,
        (SELECT COUNT(*) FROM quarantine.student_vle) AS quarantine_count
)
SELECT
    raw_count,
    clean_count,
    quarantine_count,
    raw_count = clean_count + quarantine_count AS is_reconciled
FROM row_counts;
