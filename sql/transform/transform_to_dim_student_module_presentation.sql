INSERT INTO mart.dim_student_module_presentation (
    id_student,
    module_presentation_id,
    gender,
    region,
    highest_education,
    imd_band,
    age_band,
    disability,
    num_of_prev_attempts,
    studied_credits,
    date_registration,
    date_unregistration,
    final_result
)
SELECT
    si.id_student,
    dmp.module_presentation_id,
    si.gender,
    si.region,
    si.highest_education,
    si.imd_band,
    si.age_band,
    si.disability,
    si.num_of_prev_attempts,
    si.studied_credits,
    sr.date_registration,
    sr.date_unregistration,
    si.final_result
FROM mart.dim_module_presentation dmp
JOIN clean.student_info si
    ON dmp.code_module = si.code_module
    AND dmp.code_presentation = si.code_presentation
LEFT JOIN clean.student_registration sr
    ON si.id_student = sr.id_student
    AND si.code_module = sr.code_module
    AND si.code_presentation = sr.code_presentation;

SELECT COUNT(*) FROM mart.dim_student_module_presentation;
