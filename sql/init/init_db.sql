BEGIN;

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS clean;
CREATE SCHEMA IF NOT EXISTS quarantine;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS prediction;

CREATE TABLE IF NOT EXISTS raw.courses (
    code_module                TEXT,
    code_presentation          TEXT,
    module_presentation_length TEXT,
    source_row_number          BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 2)
);

CREATE TABLE IF NOT EXISTS raw.student_info (
    code_module          TEXT,
    code_presentation    TEXT,
    id_student           TEXT,
    gender               TEXT,
    region               TEXT,
    highest_education    TEXT,
    imd_band             TEXT,
    age_band             TEXT,
    num_of_prev_attempts TEXT,
    studied_credits      TEXT,
    disability           TEXT,
    final_result         TEXT,
    source_row_number    BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 2)
);

CREATE TABLE IF NOT EXISTS raw.student_registration (
    code_module         TEXT,
    code_presentation   TEXT,
    id_student          TEXT,
    date_registration   TEXT,
    date_unregistration TEXT,
    source_row_number   BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 2)
);

CREATE TABLE IF NOT EXISTS raw.assessments (
    code_module       TEXT,
    code_presentation TEXT,
    id_assessment     TEXT,
    assessment_type   TEXT,
    date              TEXT,
    weight            TEXT,
    source_row_number BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 2)
);

CREATE TABLE IF NOT EXISTS raw.student_assessment (
    id_assessment     TEXT,
    id_student        TEXT,
    date_submitted    TEXT,
    is_banked         TEXT,
    score             TEXT,
    source_row_number BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 2)
);

CREATE TABLE IF NOT EXISTS raw.vle (
    id_site           TEXT,
    code_module       TEXT,
    code_presentation TEXT,
    activity_type     TEXT,
    week_from         TEXT,
    week_to           TEXT,
    source_row_number BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 2)
);

CREATE TABLE IF NOT EXISTS raw.student_vle (
    code_module       TEXT,
    code_presentation TEXT,
    id_student        TEXT,
    id_site           TEXT,
    date              TEXT,
    sum_click         TEXT,
    source_row_number BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 2)
);

CREATE TABLE IF NOT EXISTS clean.courses (
    code_module                VARCHAR(3) NOT NULL,
    code_presentation          VARCHAR(5) NOT NULL,
    module_presentation_length INTEGER NOT NULL,

    CONSTRAINT pk_clean_courses



        PRIMARY KEY (code_module, code_presentation)
);

CREATE TABLE IF NOT EXISTS clean.student_info (
    code_module          VARCHAR(3) NOT NULL,
    code_presentation    VARCHAR(5) NOT NULL,
    id_student           BIGINT NOT NULL,
    gender               VARCHAR(1) NOT NULL,
    region               TEXT NOT NULL,
    highest_education    TEXT NOT NULL,
    imd_band             VARCHAR(7),
    age_band             VARCHAR(5) NOT NULL,
    num_of_prev_attempts INTEGER NOT NULL,
    studied_credits      INTEGER NOT NULL,
    disability           VARCHAR(1) NOT NULL,
    final_result         VARCHAR(11) NOT NULL,

    CONSTRAINT pk_clean_student_info
        PRIMARY KEY (
            code_module,
            code_presentation,
            id_student
        ),

    CONSTRAINT fk_clean_student_info_courses
        FOREIGN KEY (
            code_module,
            code_presentation
        )
        REFERENCES clean.courses (
            code_module,
            code_presentation
        )
);

CREATE TABLE IF NOT EXISTS clean.student_registration (
    code_module         VARCHAR(3) NOT NULL,
    code_presentation   VARCHAR(5) NOT NULL,
    id_student          BIGINT NOT NULL,
    date_registration   INTEGER,
    date_unregistration INTEGER,

    CONSTRAINT pk_clean_student_registration
        PRIMARY KEY (
            code_module,
            code_presentation,
            id_student
        ),

    CONSTRAINT fk_clean_student_registration_student
        FOREIGN KEY (
            code_module,
            code_presentation,
            id_student
        )
        REFERENCES clean.student_info (
            code_module,
            code_presentation,
            id_student
        )
);

CREATE TABLE IF NOT EXISTS clean.assessments (
    code_module       VARCHAR(3) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    id_assessment     BIGINT NOT NULL,
    assessment_type   VARCHAR(4) NOT NULL,
    date              INTEGER,
    weight            NUMERIC(5, 2) NOT NULL,

    CONSTRAINT pk_clean_assessments
        PRIMARY KEY (id_assessment),

    CONSTRAINT fk_clean_assessments_courses
        FOREIGN KEY (
            code_module,
            code_presentation
        )
        REFERENCES clean.courses (
            code_module,
            code_presentation
        )
);

CREATE TABLE IF NOT EXISTS clean.student_assessment (
    id_assessment  BIGINT NOT NULL,
    id_student     BIGINT NOT NULL,
    date_submitted INTEGER NOT NULL,
    is_banked      SMALLINT NOT NULL,
    score          NUMERIC(5, 2),

    CONSTRAINT pk_clean_student_assessment
        PRIMARY KEY (id_assessment, id_student),

    CONSTRAINT fk_clean_student_assessment_assessment
        FOREIGN KEY (id_assessment)
        REFERENCES clean.assessments (id_assessment)
);

CREATE TABLE IF NOT EXISTS clean.vle (
    id_site           BIGINT NOT NULL,
    code_module       VARCHAR(3) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    activity_type     TEXT NOT NULL,
    week_from         INTEGER,
    week_to           INTEGER,

    CONSTRAINT pk_clean_vle
        PRIMARY KEY (id_site),

    CONSTRAINT fk_clean_vle_courses
        FOREIGN KEY (
            code_module,
            code_presentation
        )
        REFERENCES clean.courses (
            code_module,
            code_presentation
        )
);

CREATE TABLE IF NOT EXISTS clean.student_vle (
    student_vle_id    BIGINT GENERATED ALWAYS AS IDENTITY,
    code_module       VARCHAR(3) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    id_student        BIGINT NOT NULL,
    id_site           BIGINT NOT NULL,
    date              INTEGER NOT NULL,
    sum_click         INTEGER NOT NULL,

    CONSTRAINT pk_clean_student_vle
        PRIMARY KEY (student_vle_id),

    CONSTRAINT fk_clean_student_vle_student
        FOREIGN KEY (
            code_module,
            code_presentation,
            id_student
        )
        REFERENCES clean.student_info (
            code_module,
            code_presentation,
            id_student
        ),

    CONSTRAINT fk_clean_student_vle_site
        FOREIGN KEY (id_site)
        REFERENCES clean.vle (id_site)
);

CREATE TABLE IF NOT EXISTS quarantine.courses (
    source_file       TEXT NOT NULL,
    source_row_number BIGINT NOT NULL,

    code_module                TEXT,
    code_presentation          TEXT,
    module_presentation_length TEXT,

    error_details JSONB NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_quarantine_courses
        PRIMARY KEY (source_file, source_row_number)
);

CREATE TABLE IF NOT EXISTS quarantine.student_info (
    source_file       TEXT NOT NULL,
    source_row_number BIGINT NOT NULL,

    code_module          TEXT,
    code_presentation    TEXT,
    id_student           TEXT,
    gender               TEXT,
    region               TEXT,
    highest_education    TEXT,
    imd_band             TEXT,
    age_band             TEXT,
    num_of_prev_attempts TEXT,
    studied_credits      TEXT,
    disability           TEXT,
    final_result         TEXT,

    error_details JSONB NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_quarantine_student_info
        PRIMARY KEY (source_file, source_row_number)
);

CREATE TABLE IF NOT EXISTS quarantine.student_registration (
    source_file       TEXT NOT NULL,
    source_row_number BIGINT NOT NULL,

    code_module         TEXT,
    code_presentation   TEXT,
    id_student          TEXT,
    date_registration   TEXT,
    date_unregistration TEXT,

    error_details JSONB NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_quarantine_student_registration
        PRIMARY KEY (source_file, source_row_number)
);

CREATE TABLE IF NOT EXISTS quarantine.assessments (
    source_file       TEXT NOT NULL,
    source_row_number BIGINT NOT NULL,

    code_module       TEXT,
    code_presentation TEXT,
    id_assessment     TEXT,
    assessment_type   TEXT,
    date              TEXT,
    weight            TEXT,

    error_details JSONB NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_quarantine_assessments
        PRIMARY KEY (source_file, source_row_number)
);

CREATE TABLE IF NOT EXISTS quarantine.student_assessment (
    source_file       TEXT NOT NULL,
    source_row_number BIGINT NOT NULL,

    id_assessment  TEXT,
    id_student     TEXT,
    date_submitted TEXT,
    is_banked      TEXT,
    score          TEXT,

    error_details JSONB NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_quarantine_student_assessment
        PRIMARY KEY (source_file, source_row_number)
);

CREATE TABLE IF NOT EXISTS quarantine.vle (
    source_file       TEXT NOT NULL,
    source_row_number BIGINT NOT NULL,

    id_site           TEXT,
    code_module       TEXT,
    code_presentation TEXT,
    activity_type     TEXT,
    week_from         TEXT,
    week_to           TEXT,

    error_details JSONB NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_quarantine_vle
        PRIMARY KEY (source_file, source_row_number)
);

CREATE TABLE IF NOT EXISTS quarantine.student_vle (
    source_file       TEXT NOT NULL,
    source_row_number BIGINT NOT NULL,

    code_module       TEXT,
    code_presentation TEXT,
    id_student        TEXT,
    id_site           TEXT,
    date              TEXT,
    sum_click         TEXT,

    error_details JSONB NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_quarantine_student_vle
        PRIMARY KEY (source_file, source_row_number)
);

CREATE TABLE IF NOT EXISTS mart.dim_week (
    week_id     SMALLINT GENERATED ALWAYS AS IDENTITY,
    week_no     SMALLINT NOT NULL,
    start_day   INTEGER NOT NULL,
    end_day     INTEGER NOT NULL,

    CONSTRAINT pk_mart_dim_week
        PRIMARY KEY (week_id),

    CONSTRAINT uq_mart_dim_week
        UNIQUE (week_no)
);

CREATE TABLE IF NOT EXISTS mart.dim_module_presentation (
    module_presentation_id      INTEGER GENERATED ALWAYS AS IDENTITY,
    code_module                 VARCHAR(5) NOT NULL,
    code_presentation           VARCHAR(5) NOT NULL,
    module_presentation_length  INTEGER NOT NULL,

    CONSTRAINT pk_mart_dim_module_presentation
        PRIMARY KEY (module_presentation_id),

    CONSTRAINT uq_mart_dim_module_presentation
        UNIQUE (code_module, code_presentation)
);

CREATE TABLE IF NOT EXISTS mart.dim_assessments (
    assessment_id           BIGINT GENERATED ALWAYS AS IDENTITY,
    assessment_no           BIGINT NOT NULL,
    module_presentation_id  INTEGER NOT NULL,
    assessment_type         VARCHAR(4) NOT NULL,
    due_date                INTEGER NULL,
    weight                  NUMERIC(5,2) NOT NULL,
    effective_due_week      INTEGER NOT NULL,

    CONSTRAINT pk_mart_dim_assessments
        PRIMARY KEY (assessment_id),

    CONSTRAINT uq_mart_dim_assessments
        UNIQUE (assessment_no),

    CONSTRAINT fk_mart_dim_assessments_dim_module_presentation
        FOREIGN KEY (module_presentation_id)
        REFERENCES mart.dim_module_presentation (module_presentation_id)
);

CREATE TABLE IF NOT EXISTS mart.dim_student_module_presentation (
    student_module_presentation_id  BIGINT GENERATED ALWAYS AS IDENTITY,
    id_student                      BIGINT NOT NULL,
    module_presentation_id          INTEGER NOT NULL,
    gender                          VARCHAR(1) NOT NULL,
    region                          TEXT NOT NULL,
    highest_education               TEXT NOT NULL,
    imd_band                        VARCHAR(7) NULL,
    age_band                        VARCHAR(5) NOT NULL,
    disability                      VARCHAR(1) NOT NULL,
    num_of_prev_attempts            INTEGER NOT NULL,
    studied_credits                 INTEGER NOT NULL,
    date_registration               INTEGER NULL,
    date_unregistration             INTEGER NULL,
    final_result                    VARCHAR(11) NOT NULL,

    CONSTRAINT pk_mart_dim_student_module_presentation
        PRIMARY KEY (student_module_presentation_id),

    CONSTRAINT uq_mart_dim_student_module_presentation
        UNIQUE (id_student, module_presentation_id),

    CONSTRAINT fk_mart_dim_student_module_presentation_dim_module_presentation
        FOREIGN KEY (module_presentation_id)
        REFERENCES mart.dim_module_presentation (module_presentation_id)
);

CREATE TABLE IF NOT EXISTS mart.fact_module_presentation_assessments_week (
    assessments_week_id                             BIGINT GENERATED ALWAYS AS IDENTITY,
    assessment_id                                   BIGINT NOT NULL,
    week_id                                         SMALLINT NOT NULL,
    submitted_student_count_week                    BIGINT NOT NULL,
    submitted_student_count_to_week                 BIGINT NOT NULL,
    late_student_count_week                         BIGINT NOT NULL,
    late_student_count_to_week                      BIGINT NOT NULL,
    overdue_unsubmitted_student_count_at_week_end   BIGINT NOT NULL,

    CONSTRAINT pk_mart_fact_module_presentation_assessments_week
        PRIMARY KEY (assessments_week_id),

    CONSTRAINT uq_mart_assessments_week
        UNIQUE (assessment_id, week_id),

    CONSTRAINT fk_mart_fact_module_presentation_assessments_week_dim_assessments
        FOREIGN KEY (assessment_id)
        REFERENCES mart.dim_assessments (assessment_id),

    CONSTRAINT fk_mart_fact_module_presentation_assessments_week_dim_week
        FOREIGN KEY (week_id)
        REFERENCES mart.dim_week (week_id)
);

CREATE TABLE IF NOT EXISTS mart.fact_module_presentation_activity_type_week (
    activity_type_week_id           INTEGER GENERATED ALWAYS AS IDENTITY,
    module_presentation_id          INTEGER NOT NULL,
    week_id                         SMALLINT NOT NULL,
    activity_type                   TEXT NOT NULL,
    click_count_week                BIGINT NOT NULL,
    click_count_to_week             BIGINT NOT NULL,
    median_student_click_count_week NUMERIC(12, 2) NULL,
    active_student_count_week       BIGINT NOT NULL,
    accessed_site_count_week        INTEGER NOT NULL,

    CONSTRAINT pk_mart_fact_module_presentation_activity_type_week
        PRIMARY KEY (activity_type_week_id),

    CONSTRAINT uq_mart_activity_type_week
        UNIQUE (module_presentation_id, activity_type, week_id),

    CONSTRAINT fk_mart_fact_module_presentation_activity_type_week_dim_module_presentation
        FOREIGN KEY (module_presentation_id)
        REFERENCES mart.dim_module_presentation (module_presentation_id),

    CONSTRAINT fk_mart_fact_module_presentation_activity_type_week_dim_week
        FOREIGN KEY (week_id)
        REFERENCES mart.dim_week (week_id)
);

CREATE TABLE IF NOT EXISTS mart.fact_student_module_presentation_week (
    student_week_id                     BIGINT GENERATED ALWAYS AS IDENTITY,
    student_module_presentation_id      BIGINT NOT NULL,
    week_id                             SMALLINT NOT NULL,
    click_count_week                    BIGINT NOT NULL,
    click_count_to_week                 BIGINT NOT NULL,
    active_day_count_week               INTEGER NOT NULL,
    active_day_count_to_week            INTEGER NOT NULL,
    site_count_to_week                  INTEGER NOT NULL,
    activity_type_count_to_week         INTEGER NOT NULL,
    coursework_due_count_to_week        INTEGER NOT NULL,
    coursework_submitted_count_week     INTEGER NOT NULL,
    coursework_submitted_count_to_week	INTEGER NOT NULL,
    coursework_late_count_to_week       INTEGER NOT NULL,
    coursework_overdue_count_to_week    INTEGER NOT NULL,

    CONSTRAINT pk_mart_fact_student_module_presentation_week
        PRIMARY KEY (student_week_id),

    CONSTRAINT uq_mart_student_week
        UNIQUE (student_module_presentation_id, week_id),

    CONSTRAINT fk_mart_fact_student_module_presentation_week_dim_student_module_presentation
        FOREIGN KEY (student_module_presentation_id)
        REFERENCES mart.dim_student_module_presentation (student_module_presentation_id),

    CONSTRAINT fk_mart_fact_student_module_presentation_week_dim_week
        FOREIGN KEY (week_id)
        REFERENCES mart.dim_week (week_id)
);

COMMIT;
