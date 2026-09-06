INSERT INTO mart.dim_week (
    week_no,
    start_day,
    end_day
)
SELECT week_no, 7 * (week_no - 1), 7 * week_no
FROM GENERATE_SERIES(
        2,
        (
            SELECT CEIL(MAX(module_presentation_length) / 7.0) ::INTEGER
            FROM mart.dim_module_presentation
        )
    ) AS weeks(week_no);

SELECT COUNT(*) FROM mart.dim_week;
