SELECT
    f.student_week_id as module_presentation_student_week_id,
    dsmp.id_student,
    dmp.code_module,
    dmp.code_presentation,
    dw.week_no,
    dsmp.gender,
    dsmp.region,
    dsmp.highest_education,
    dsmp.imd_band,
    dsmp.age_band,
    dsmp.disability,
    dsmp.num_of_prev_attempts,
    dsmp.studied_credits,
    f.click_count_week,
    f.click_count_to_week,
    f.active_day_count_week,
    f.active_day_count_to_week,
    f.site_count_to_week,
    f.activity_type_count_to_week,
    f.coursework_due_count_to_week,
    f.coursework_submitted_count_week,
    f.coursework_submitted_count_to_week,
    f.coursework_late_count_to_week,
    f.coursework_overdue_count_to_week,
    dsmp.final_result

FROM mart.fact_student_module_presentation_week f
JOIN mart.dim_student_module_presentation dsmp
    ON dsmp.student_module_presentation_id
       = f.student_module_presentation_id
JOIN mart.dim_module_presentation dmp
    ON dmp.module_presentation_id
       = dsmp.module_presentation_id
JOIN mart.dim_week dw
    ON dw.week_id = f.week_id

--Những presentation được dùng cho huấn luyện
WHERE dmp.code_presentation IN (
    '2013B',
    '2013J',
    '2014B'
)
AND dsmp.final_result IN (
    'Fail',
    'Pass',
    'Distinction'
)