DROP TABLE IF EXISTS pg_temp.vle_validation;
CREATE TEMP TABLE vle_validation AS
WITH prepared_vle AS (
    SELECT
        source_row_number,

        id_site AS raw_id_site,
        code_module AS raw_code_module,
        code_presentation AS raw_code_presentation,
        activity_type AS raw_activity_type,
        week_from AS raw_week_from,
        week_to AS raw_week_to,

        NULLIF(BTRIM(id_site), '') AS id_site_text,
        NULLIF(BTRIM(code_module), '') AS clean_code_module,
        NULLIF(BTRIM(code_presentation), '') AS clean_code_presentation,
        NULLIF(BTRIM(activity_type), '') AS clean_activity_type,
        NULLIF(BTRIM(week_from), '') AS week_from_text,
        NULLIF(BTRIM(week_to), '') AS week_to_text
    FROM raw.vle
),

parsed_vle AS (
    SELECT
        *,
        id_site_text ~ '^[+-]?[0-9]+$' AS id_site_is_integer,
        week_from_text ~ '^[+-]?[0-9]+$' AS week_from_is_integer,
        week_to_text ~ '^[+-]?[0-9]+$' AS week_to_is_integer,

        CASE
            WHEN id_site_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(id_site_text, '+-')) <= 19
            THEN id_site_text::NUMERIC
        END AS parsed_id_site,

        CASE
            WHEN week_from_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(week_from_text, '+-')) <= 10
            THEN week_from_text::NUMERIC
        END AS parsed_week_from,

        CASE
            WHEN week_to_text ~ '^[+-]?[0-9]+$'
                 AND LENGTH(LTRIM(week_to_text, '+-')) <= 10
            THEN week_to_text::NUMERIC
        END AS parsed_week_to
    FROM prepared_vle
)

SELECT
    *,
    TO_JSONB(ARRAY_REMOVE(ARRAY[
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
            WHEN clean_activity_type IS NULL
            THEN JSONB_BUILD_OBJECT(
                'column', 'activity_type',
                'code', 'REQUIRED',
                'message', 'Loai tai nguyen khong duoc de trong'
            )
            WHEN clean_activity_type NOT IN (
                'dataplus',
                'dualpane',
                'externalquiz',
                'folder',
                'forumng',
                'glossary',
                'homepage',
                'htmlactivity',
                'oucollaborate',
                'oucontent',
                'ouelluminate',
                'ouwiki',
                'page',
                'questionnaire',
                'quiz',
                'repeatactivity',
                'resource',
                'sharedsubpage',
                'subpage',
                'url'
            )
            THEN JSONB_BUILD_OBJECT(
                'column', 'activity_type',
                'code', 'INVALID_VALUE',
                'message', 'Loai tai nguyen khong thuoc danh muc OULAD'
            )
        END,

        CASE
            WHEN week_from_text IS NOT NULL
                 AND NOT week_from_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'week_from',
                'code', 'INVALID_INTEGER',
                'message', 'Tuan bat dau phai la so nguyen'
            )
            WHEN week_from_is_integer
                 AND (
                    LENGTH(LTRIM(week_from_text, '+-')) > 10
                    OR parsed_week_from NOT BETWEEN
                        -2147483648 AND 2147483647
                 )
            THEN JSONB_BUILD_OBJECT(
                'column', 'week_from',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'Tuan bat dau nam ngoai pham vi INTEGER'
            )
        END,

        CASE
            WHEN week_to_text IS NOT NULL
                 AND NOT week_to_is_integer
            THEN JSONB_BUILD_OBJECT(
                'column', 'week_to',
                'code', 'INVALID_INTEGER',
                'message', 'Tuan ket thuc phai la so nguyen'
            )
            WHEN week_to_is_integer
                 AND (
                    LENGTH(LTRIM(week_to_text, '+-')) > 10
                    OR parsed_week_to NOT BETWEEN
                        -2147483648 AND 2147483647
                 )
            THEN JSONB_BUILD_OBJECT(
                'column', 'week_to',
                'code', 'INTEGER_OUT_OF_RANGE',
                'message', 'Tuan ket thuc nam ngoai pham vi INTEGER'
            )
        END,

        CASE
            WHEN (week_from_text IS NULL AND week_to_text IS NOT NULL)
              OR (week_from_text IS NOT NULL AND week_to_text IS NULL)
            THEN JSONB_BUILD_OBJECT(
                'column', 'week_from, week_to',
                'code', 'INCOMPLETE_WEEK_RANGE',
                'message', 'Khoang tuan phai co ca diem dau va diem cuoi'
            )
            WHEN parsed_week_from BETWEEN -2147483648 AND 2147483647
             AND parsed_week_to BETWEEN -2147483648 AND 2147483647
             AND parsed_week_to < parsed_week_from
            THEN JSONB_BUILD_OBJECT(
                'column', 'week_from, week_to',
                'code', 'INVALID_WEEK_ORDER',
                'message', 'Tuan ket thuc khong duoc truoc tuan bat dau'
            )
        END
    ]::JSONB[], NULL)) AS error_details,
    JSONB_BUILD_ARRAY(
        clean_code_module,
        clean_code_presentation,
        clean_activity_type,
        parsed_week_from,
        parsed_week_to
    ) AS row_signature,
    NULL::JSONB AS first_row_signature,
    NULL::BIGINT AS valid_row_rank
FROM parsed_vle;

CREATE UNIQUE INDEX vle_validation_source_row_idx
    ON vle_validation (source_row_number);

ANALYZE vle_validation;

UPDATE vle_validation AS resource
SET error_details = resource.error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'code_module, code_presentation',
        'code', 'COURSE_NOT_FOUND',
        'message', 'Hoc phan khong ton tai trong clean.courses'
    )
)
WHERE JSONB_ARRAY_LENGTH(resource.error_details) = 0
  AND NOT EXISTS (
      SELECT 1
      FROM clean.courses AS course
      WHERE course.code_module = resource.clean_code_module
        AND course.code_presentation = resource.clean_code_presentation
  );

WITH ranked_valid_resources AS (
    SELECT
        source_row_number,
        ROW_NUMBER() OVER (
            PARTITION BY parsed_id_site
            ORDER BY source_row_number
        ) AS valid_row_rank,
        FIRST_VALUE(row_signature) OVER (
            PARTITION BY parsed_id_site
            ORDER BY source_row_number
        ) AS first_row_signature
    FROM vle_validation
    WHERE JSONB_ARRAY_LENGTH(error_details) = 0
)

UPDATE vle_validation AS resource
SET valid_row_rank = ranked.valid_row_rank,
    first_row_signature = ranked.first_row_signature
FROM ranked_valid_resources AS ranked
WHERE resource.source_row_number = ranked.source_row_number;

UPDATE vle_validation
SET error_details = error_details || JSONB_BUILD_ARRAY(
    JSONB_BUILD_OBJECT(
        'column', 'id_site',
        'code', CASE
            WHEN row_signature = first_row_signature
            THEN 'EXACT_DUPLICATE'
            ELSE 'CONFLICTING_DUPLICATE'
        END,
        'message', CASE
            WHEN row_signature = first_row_signature
            THEN 'Dong trung hoan toan voi dong hop le dau tien'
            ELSE 'Cung id_site nhung thong tin khong nhat quan'
        END
    )
)
WHERE valid_row_rank > 1;

INSERT INTO quarantine.vle (
    source_file,
    source_row_number,
    id_site,
    code_module,
    code_presentation,
    activity_type,
    week_from,
    week_to,
    error_details
)
SELECT
    'vle.csv',
    source_row_number,
    raw_id_site,
    raw_code_module,
    raw_code_presentation,
    raw_activity_type,
    raw_week_from,
    raw_week_to,
    error_details
FROM vle_validation
WHERE JSONB_ARRAY_LENGTH(error_details) > 0;

INSERT INTO clean.vle (
    id_site,
    code_module,
    code_presentation,
    activity_type,
    week_from,
    week_to
)
SELECT
    parsed_id_site::BIGINT,
    clean_code_module,
    clean_code_presentation,
    clean_activity_type,
    parsed_week_from::INTEGER,
    parsed_week_to::INTEGER
FROM vle_validation
WHERE JSONB_ARRAY_LENGTH(error_details) = 0;

DROP TABLE vle_validation;

WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.vle) AS raw_count,
        (SELECT COUNT(*) FROM clean.vle) AS clean_count,
        (SELECT COUNT(*) FROM quarantine.vle) AS quarantine_count
)
SELECT
    raw_count,
    clean_count,
    quarantine_count,
    raw_count = clean_count + quarantine_count AS is_reconciled
FROM row_counts;
