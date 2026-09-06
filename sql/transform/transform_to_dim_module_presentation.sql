INSERT INTO mart.dim_module_presentation (
    code_module,
    code_presentation,
    module_presentation_length
)
SELECT
    code_module,
    code_presentation,
    module_presentation_length
FROM clean.courses;

SELECT COUNT(*) FROM mart.dim_module_presentation;