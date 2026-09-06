INSERT INTO mart.dim_assessments (
	assessment_no,
	module_presentation_id,
    assessment_type,
    due_date,
    weight,
    effective_due_week
)
SELECT
	a.id_assessment AS assessment_no,
	dmp.module_presentation_id,
	a.assessment_type,
	a.date as due_date,
	a.weight,
	CASE
		WHEN a.date IS NOT NULL
		THEN FLOOR(a.date / 7.0) + 1
		WHEN a.date IS NULL AND a.assessment_type = 'Exam'
		THEN CEIL(dmp.module_presentation_length / 7.0)
		ELSE NULL
	END::INTEGER AS effective_due_week
FROM mart.dim_module_presentation dmp
JOIN clean.assessments a
    ON dmp.code_module = a.code_module
    AND dmp.code_presentation = a.code_presentation;

SELECT COUNT(*) FROM mart.dim_assessments