WITH valid_student_assessments AS (
    SELECT
        da.assessment_id,
        sa.id_student,
        FLOOR(sa.date_submitted / 7.0)::INTEGER + 1 AS week_no,
        sa.date_submitted > da.due_date AS is_late
    FROM clean.student_assessment sa
    JOIN mart.dim_assessments da
        ON da.assessment_no = sa.id_assessment
    JOIN mart.dim_module_presentation dmp
        ON dmp.module_presentation_id = da.module_presentation_id
    WHERE
        sa.is_banked = 0
        AND da.assessment_type IN ('TMA', 'CMA')
        AND sa.date_submitted < dmp.module_presentation_length
),
submission_week AS (
    SELECT
        vsa.assessment_id,
        GREATEST(vsa.week_no, 2) AS week_no,
        COUNT(*) FILTER (
            WHERE vsa.week_no >= 2
        )::BIGINT AS submitted_student_count_week,
        COUNT(*)::BIGINT AS submitted_student_count_added,
        COUNT(*) FILTER (
            WHERE vsa.week_no >= 2
                AND vsa.is_late
        )::BIGINT AS late_student_count_week,
        COUNT(*) FILTER (
            WHERE vsa.is_late
        )::BIGINT AS late_student_count_added
    FROM valid_student_assessments vsa
    GROUP BY
        vsa.assessment_id,
        GREATEST(vsa.week_no, 2)
),
assessment_week_grid AS (
    SELECT
        da.module_presentation_id,
        da.assessment_id,
        da.assessment_no,
        da.due_date,
        dw.week_id,
        dw.week_no,
        LEAST(
            dw.end_day,
            dmp.module_presentation_length
        ) AS week_end_day_exclusive
    FROM mart.dim_assessments da
    JOIN mart.dim_module_presentation dmp
        ON dmp.module_presentation_id = da.module_presentation_id
    JOIN mart.dim_week dw
        ON dw.start_day < dmp.module_presentation_length
    WHERE da.assessment_type IN ('TMA', 'CMA')
),
overdue_week AS (
    SELECT
        awg.assessment_id,
        awg.week_id,
        COUNT(*)::BIGINT AS overdue_unsubmitted_student_count_at_week_end
    FROM assessment_week_grid awg
    JOIN mart.dim_student_module_presentation dsmp
        ON dsmp.module_presentation_id = awg.module_presentation_id
        AND (
            dsmp.date_registration IS NULL
            OR dsmp.date_registration < awg.week_end_day_exclusive
        )
        AND (
            dsmp.date_unregistration IS NULL
            OR dsmp.date_unregistration >= awg.week_end_day_exclusive
        )
    LEFT JOIN clean.student_assessment sa
        ON sa.id_assessment = awg.assessment_no
        AND sa.id_student = dsmp.id_student
        AND (
            sa.is_banked = 1
            OR sa.date_submitted < awg.week_end_day_exclusive
        )
    WHERE
        awg.due_date < awg.week_end_day_exclusive
        AND sa.id_assessment IS NULL
    GROUP BY
        awg.assessment_id,
        awg.week_id
)
INSERT INTO mart.fact_module_presentation_assessments_week (
    assessment_id,
    week_id,
    submitted_student_count_week,
    submitted_student_count_to_week,
    late_student_count_week,
    late_student_count_to_week,
    overdue_unsubmitted_student_count_at_week_end
)
SELECT
    awg.assessment_id,
    awg.week_id,
    COALESCE(
        sw.submitted_student_count_week,
        0
    ) AS submitted_student_count_week,
    SUM(
        COALESCE(sw.submitted_student_count_added, 0)
    ) OVER (
        PARTITION BY awg.assessment_id
        ORDER BY awg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::BIGINT AS submitted_student_count_to_week,
    COALESCE(
        sw.late_student_count_week,
        0
    ) AS late_student_count_week,
    SUM(
        COALESCE(sw.late_student_count_added, 0)
    ) OVER (
        PARTITION BY awg.assessment_id
        ORDER BY awg.week_no
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::BIGINT AS late_student_count_to_week,
    COALESCE(
        ow.overdue_unsubmitted_student_count_at_week_end,
        0
    ) AS overdue_unsubmitted_student_count_at_week_end
FROM assessment_week_grid awg
LEFT JOIN submission_week sw
    ON sw.assessment_id = awg.assessment_id
    AND sw.week_no = awg.week_no
LEFT JOIN overdue_week ow
    ON ow.assessment_id = awg.assessment_id
    AND ow.week_id = awg.week_id;

SELECT COUNT(*)
FROM mart.fact_module_presentation_assessments_week;
