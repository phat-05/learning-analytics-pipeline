WITH student_week_grid AS (
    SELECT
        dsmp.student_module_presentation_id,
        dsmp.id_student,
        dmp.module_presentation_id,
        dw.week_id,
        dw.week_no,
        LEAST(
            dw.end_day,
            dmp.module_presentation_length
        ) AS week_end_day_exclusive
    FROM mart.dim_student_module_presentation dsmp
    JOIN mart.dim_module_presentation dmp
        ON dmp.module_presentation_id = dsmp.module_presentation_id
    JOIN mart.dim_week dw
        ON dw.start_day < dmp.module_presentation_length
    WHERE
        (
            dsmp.date_registration IS NULL
            OR dsmp.date_registration < LEAST(
                dw.end_day,
                dmp.module_presentation_length
            )
        )
        AND (
            dsmp.date_unregistration IS NULL
            OR dsmp.date_unregistration >= LEAST(
                dw.end_day,
                dmp.module_presentation_length
            )
        )
),
vle_events AS (
    SELECT
        dsmp.student_module_presentation_id,
        sv.date AS click_date,
        FLOOR(sv.date / 7.0)::INTEGER + 1 AS event_week_no,
        sv.id_site,
        v.activity_type,
        sv.sum_click
    FROM mart.dim_student_module_presentation dsmp
    JOIN mart.dim_module_presentation dmp
        ON dmp.module_presentation_id = dsmp.module_presentation_id
    JOIN clean.student_vle sv
        ON sv.id_student = dsmp.id_student
        AND sv.code_module = dmp.code_module
        AND sv.code_presentation = dmp.code_presentation
    JOIN clean.vle v
        ON v.id_site = sv.id_site
        AND v.code_module = sv.code_module
        AND v.code_presentation = sv.code_presentation
    WHERE sv.date < dmp.module_presentation_length
),
vle_week AS (
    SELECT
        ve.student_module_presentation_id,
        GREATEST(ve.event_week_no, 2) AS week_no,
        COALESCE(
            SUM(ve.sum_click) FILTER (
                WHERE ve.event_week_no >= 2
            ),
            0
        )::BIGINT AS click_count_week,
        SUM(ve.sum_click)::BIGINT AS click_count_added,
        (
            COUNT(DISTINCT ve.click_date) FILTER (
                WHERE ve.event_week_no >= 2
            )
        )::INTEGER AS active_day_count_week,
        COUNT(DISTINCT ve.click_date)::INTEGER AS active_day_count_added
    FROM vle_events ve
    GROUP BY
        ve.student_module_presentation_id,
        GREATEST(ve.event_week_no, 2)
),
site_added_week AS (
    SELECT
        first_site.student_module_presentation_id,
        first_site.first_week_no AS week_no,
        COUNT(*)::INTEGER AS site_count_added
    FROM (
        SELECT
            ve.student_module_presentation_id,
            ve.id_site,
            GREATEST(MIN(ve.event_week_no), 2) AS first_week_no
        FROM vle_events ve
        GROUP BY
            ve.student_module_presentation_id,
            ve.id_site
    ) first_site
    GROUP BY
        first_site.student_module_presentation_id,
        first_site.first_week_no
),
activity_type_added_week AS (
    SELECT
        first_activity_type.student_module_presentation_id,
        first_activity_type.first_week_no AS week_no,
        COUNT(*)::INTEGER AS activity_type_count_added
    FROM (
        SELECT
            ve.student_module_presentation_id,
            ve.activity_type,
            GREATEST(MIN(ve.event_week_no), 2) AS first_week_no
        FROM vle_events ve
        GROUP BY
            ve.student_module_presentation_id,
            ve.activity_type
    ) first_activity_type
    GROUP BY
        first_activity_type.student_module_presentation_id,
        first_activity_type.first_week_no
),
coursework_submission_week AS (
    SELECT
        dsmp.student_module_presentation_id,
        GREATEST(
            FLOOR(sa.date_submitted / 7.0)::INTEGER + 1,
            2
        ) AS week_no,
        (
            COUNT(*) FILTER (
                WHERE FLOOR(sa.date_submitted / 7.0)::INTEGER + 1 >= 2
            )
        )::INTEGER AS coursework_submitted_count_week,
        COUNT(*)::INTEGER AS coursework_submitted_count_added,
        (
            COUNT(*) FILTER (
                WHERE sa.date_submitted > da.due_date
            )
        )::INTEGER AS coursework_late_count_added
    FROM mart.dim_student_module_presentation dsmp
    JOIN mart.dim_module_presentation dmp
        ON dmp.module_presentation_id = dsmp.module_presentation_id
    JOIN mart.dim_assessments da
        ON da.module_presentation_id = dsmp.module_presentation_id
    JOIN clean.student_assessment sa
        ON sa.id_assessment = da.assessment_no
        AND sa.id_student = dsmp.id_student
    WHERE
        da.assessment_type IN ('TMA', 'CMA')
        AND sa.is_banked = 0
        AND sa.date_submitted < dmp.module_presentation_length
    GROUP BY
        dsmp.student_module_presentation_id,
        GREATEST(
            FLOOR(sa.date_submitted / 7.0)::INTEGER + 1,
            2
        )
),
coursework_due_overdue AS (
    SELECT
        swg.student_module_presentation_id,
        swg.week_id,
        (
            COUNT(da.assessment_id) FILTER (
                WHERE da.due_date < swg.week_end_day_exclusive
            )
        )::INTEGER AS coursework_due_count_to_week,
        (
            COUNT(da.assessment_id) FILTER (
                WHERE
                    da.due_date < swg.week_end_day_exclusive
                    AND (
                        sa.id_assessment IS NULL
                        OR (
                            sa.is_banked = 0
                            AND sa.date_submitted >= swg.week_end_day_exclusive
                        )
                    )
            )
        )::INTEGER AS coursework_overdue_count_to_week
    FROM student_week_grid swg
    LEFT JOIN mart.dim_assessments da
        ON da.module_presentation_id = swg.module_presentation_id
        AND da.assessment_type IN ('TMA', 'CMA')
    LEFT JOIN clean.student_assessment sa
        ON sa.id_assessment = da.assessment_no
        AND sa.id_student = swg.id_student
    GROUP BY
        swg.student_module_presentation_id,
        swg.week_id
)
INSERT INTO mart.fact_student_module_presentation_week (
    student_module_presentation_id,
    week_id,
    click_count_week,
    click_count_to_week,
    active_day_count_week,
    active_day_count_to_week,
    site_count_to_week,
    activity_type_count_to_week,
    coursework_due_count_to_week,
    coursework_submitted_count_week,
    coursework_submitted_count_to_week,
    coursework_late_count_to_week,
    coursework_overdue_count_to_week
)
SELECT
    swg.student_module_presentation_id,
    swg.week_id,
    COALESCE(vw.click_count_week, 0) AS click_count_week,
    SUM(
        COALESCE(vw.click_count_added, 0)
    ) OVER (
        PARTITION BY swg.student_module_presentation_id
        ORDER BY swg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::BIGINT AS click_count_to_week,
    COALESCE(vw.active_day_count_week, 0) AS active_day_count_week,
    SUM(
        COALESCE(vw.active_day_count_added, 0)
    ) OVER (
        PARTITION BY swg.student_module_presentation_id
        ORDER BY swg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::INTEGER AS active_day_count_to_week,
    SUM(
        COALESCE(saw.site_count_added, 0)
    ) OVER (
        PARTITION BY swg.student_module_presentation_id
        ORDER BY swg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::INTEGER AS site_count_to_week,
    SUM(
        COALESCE(ataw.activity_type_count_added, 0)
    ) OVER (
        PARTITION BY swg.student_module_presentation_id
        ORDER BY swg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::INTEGER AS activity_type_count_to_week,
    COALESCE(
        cdo.coursework_due_count_to_week,
        0
    ) AS coursework_due_count_to_week,
    COALESCE(
        csw.coursework_submitted_count_week,
        0
    ) AS coursework_submitted_count_week,
    SUM(
        COALESCE(csw.coursework_submitted_count_added, 0)
    ) OVER (
        PARTITION BY swg.student_module_presentation_id
        ORDER BY swg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::INTEGER AS coursework_submitted_count_to_week,
    SUM(
        COALESCE(csw.coursework_late_count_added, 0)
    ) OVER (
        PARTITION BY swg.student_module_presentation_id
        ORDER BY swg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::INTEGER AS coursework_late_count_to_week,
    COALESCE(
        cdo.coursework_overdue_count_to_week,
        0
    ) AS coursework_overdue_count_to_week
FROM student_week_grid swg
LEFT JOIN vle_week vw
    ON vw.student_module_presentation_id = swg.student_module_presentation_id
    AND vw.week_no = swg.week_no
LEFT JOIN site_added_week saw
    ON saw.student_module_presentation_id = swg.student_module_presentation_id
    AND saw.week_no = swg.week_no
LEFT JOIN activity_type_added_week ataw
    ON ataw.student_module_presentation_id = swg.student_module_presentation_id
    AND ataw.week_no = swg.week_no
LEFT JOIN coursework_submission_week csw
    ON csw.student_module_presentation_id = swg.student_module_presentation_id
    AND csw.week_no = swg.week_no
LEFT JOIN coursework_due_overdue cdo
    ON cdo.student_module_presentation_id = swg.student_module_presentation_id
    AND cdo.week_id = swg.week_id;

SELECT COUNT(*)
FROM mart.fact_student_module_presentation_week;
