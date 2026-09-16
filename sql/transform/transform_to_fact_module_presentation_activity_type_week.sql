WITH activity_type_student_site_week AS (
    SELECT
        dmp.module_presentation_id,
        v.activity_type,
        sv.id_student,
        sv.id_site,
        FLOOR(sv.date / 7.0)::INTEGER + 1 AS week_no,
        SUM(sv.sum_click)::BIGINT AS student_site_click_count
    FROM clean.student_vle sv
    JOIN clean.vle v
        ON v.id_site = sv.id_site
        AND v.code_module = sv.code_module
        AND v.code_presentation = sv.code_presentation
    JOIN mart.dim_module_presentation dmp
        ON dmp.code_module = sv.code_module
        AND dmp.code_presentation = sv.code_presentation
    WHERE sv.date < dmp.module_presentation_length
    GROUP BY
        dmp.module_presentation_id,
        v.activity_type,
        sv.id_student,
        sv.id_site,
        FLOOR(sv.date / 7.0)::INTEGER + 1
),
activity_type_student_week AS (
    SELECT
        atssw.module_presentation_id,
        atssw.activity_type,
        atssw.id_student,
        atssw.week_no,
        SUM(atssw.student_site_click_count)::BIGINT AS student_click_count
    FROM activity_type_student_site_week atssw
    GROUP BY
        atssw.module_presentation_id,
        atssw.activity_type,
        atssw.id_student,
        atssw.week_no
),
activity_type_week AS (
    SELECT
        atsw.module_presentation_id,
        atsw.activity_type,
        atsw.week_no,
        SUM(atsw.student_click_count)::BIGINT AS click_count_week,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY atsw.student_click_count::DOUBLE PRECISION
        )::NUMERIC(12, 2) AS median_student_click_count_week,
        COUNT(*)::BIGINT AS active_student_count_week
    FROM activity_type_student_week atsw
    WHERE atsw.week_no >= 2
    GROUP BY
        atsw.module_presentation_id,
        atsw.activity_type,
        atsw.week_no
),
activity_type_site_week AS (
    SELECT
        atssw.module_presentation_id,
        atssw.activity_type,
        atssw.week_no,
        COUNT(DISTINCT atssw.id_site)::INTEGER AS accessed_site_count_week
    FROM activity_type_student_site_week atssw
    WHERE atssw.week_no >= 2
    GROUP BY
        atssw.module_presentation_id,
        atssw.activity_type,
        atssw.week_no
),
activity_type_click_added_week AS (
    SELECT
        atsw.module_presentation_id,
        atsw.activity_type,
        GREATEST(atsw.week_no, 2) AS week_no,
        SUM(atsw.student_click_count)::BIGINT AS click_added
    FROM activity_type_student_week atsw
    GROUP BY
        atsw.module_presentation_id,
        atsw.activity_type,
        GREATEST(atsw.week_no, 2)
),
activity_type_week_grid AS (
    SELECT DISTINCT
        dmp.module_presentation_id,
        v.activity_type,
        dw.week_id,
        dw.week_no
    FROM mart.dim_module_presentation dmp
    JOIN clean.vle v
        ON v.code_module = dmp.code_module
        AND v.code_presentation = dmp.code_presentation
    JOIN mart.dim_week dw
        ON dw.start_day < dmp.module_presentation_length
)
INSERT INTO mart.fact_module_presentation_activity_type_week (
    module_presentation_id,
    week_id,
    activity_type,
    click_count_week,
    click_count_to_week,
    median_student_click_count_week,
    active_student_count_week,
    accessed_site_count_week
)
SELECT
    atwg.module_presentation_id,
    atwg.week_id,
    atwg.activity_type,
    COALESCE(atw.click_count_week, 0),
    SUM(COALESCE(atcaw.click_added, 0)) OVER (
        PARTITION BY
            atwg.module_presentation_id,
            atwg.activity_type
        ORDER BY atwg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::BIGINT,
    atw.median_student_click_count_week,
    COALESCE(atw.active_student_count_week, 0),
    COALESCE(atsite.accessed_site_count_week, 0)
FROM activity_type_week_grid atwg
LEFT JOIN activity_type_week atw
    ON atw.module_presentation_id = atwg.module_presentation_id
    AND atw.activity_type = atwg.activity_type
    AND atw.week_no = atwg.week_no
LEFT JOIN activity_type_click_added_week atcaw
    ON atcaw.module_presentation_id = atwg.module_presentation_id
    AND atcaw.activity_type = atwg.activity_type
    AND atcaw.week_no = atwg.week_no
LEFT JOIN activity_type_site_week atsite
    ON atsite.module_presentation_id = atwg.module_presentation_id
    AND atsite.activity_type = atwg.activity_type
    AND atsite.week_no = atwg.week_no;

SELECT COUNT(*)
FROM mart.fact_module_presentation_activity_type_week;
