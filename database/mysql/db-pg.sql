CREATE SCHEMA IF NOT EXISTS zafira;

DROP FUNCTION IF EXISTS update_timestamp();
CREATE FUNCTION update_timestamp() RETURNS trigger AS $update_timestamp$
    BEGIN
        NEW.modified_at := current_timestamp;
        RETURN NEW;
    END;
$update_timestamp$ LANGUAGE plpgsql;

DROP TABLE IF EXISTS USERS;
CREATE TABLE USERS (
  ID SERIAL,
  USERNAME VARCHAR(100) NOT NULL,
  EMAIL VARCHAR(100) NULL,
  FIRST_NAME VARCHAR(100) NULL,
  LAST_NAME VARCHAR(100) NULL,
  MODIFIED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CREATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ID));
CREATE UNIQUE INDEX USERNAME_UNIQUE ON USERS (USERNAME);
CREATE TRIGGER update_timestamp_users BEFORE INSERT OR UPDATE ON USERS
    FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


DROP TABLE IF EXISTS TEST_SUITES;
CREATE TABLE IF NOT EXISTS TEST_SUITES (
  ID SERIAL,
  NAME VARCHAR(200) NOT NULL,
  DESCRIPTION TEXT NULL,
  FILE_NAME VARCHAR(255) NOT NULL DEFAULT '',
  USER_ID INT NOT NULL,
  MODIFIED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CREATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ID),
  CONSTRAINT fk_TEST_SUITES_USERS1
    FOREIGN KEY (USER_ID)
    REFERENCES USERS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);
CREATE UNIQUE INDEX NAME_FILE_USER_UNIQUE ON TEST_SUITES (NAME, FILE_NAME, USER_ID);
CREATE INDEX FK_TEST_SUITE_USER_ASC ON TEST_SUITES (USER_ID);
CREATE TRIGGER update_timestamp_test_suits BEFORE INSERT OR UPDATE ON TEST_SUITES
    FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

DROP TABLE IF EXISTS TEST_CASES;
CREATE TABLE IF NOT EXISTS TEST_CASES (
  ID SERIAL,
  TEST_CLASS VARCHAR(255) NOT NULL,
  TEST_METHOD VARCHAR(100) NOT NULL,
  INFO TEXT NULL,
  TEST_SUITE_ID INT NOT NULL,
  USER_ID INT NOT NULL,
  MODIFIED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CREATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ID),  
  CONSTRAINT fk_TEST_CASE_TEST_SUITE1
    FOREIGN KEY (TEST_SUITE_ID)
    REFERENCES TEST_SUITES (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_TEST_CASES_USERS1
    FOREIGN KEY (USER_ID)
    REFERENCES USERS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);
CREATE INDEX FK_TEST_CASE_SUITE_ASC ON TEST_CASES (TEST_SUITE_ID);
CREATE INDEX FK_TEST_CASE_USER_ASC ON TEST_CASES (USER_ID);
CREATE TRIGGER update_timestamp_test_cases BEFORE INSERT OR UPDATE ON TEST_CASES
    FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


DROP TABLE IF EXISTS WORK_ITEMS;
CREATE TABLE IF NOT EXISTS WORK_ITEMS (
  ID SERIAL,
  JIRA_ID VARCHAR(45) NOT NULL,
  MODIFIED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CREATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ID));
CREATE UNIQUE INDEX JIRA_ID_UNIQUE ON WORK_ITEMS (JIRA_ID);
CREATE TRIGGER update_timestamp_work_items BEFORE INSERT OR UPDATE ON WORK_ITEMS
    FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


DROP TABLE IF EXISTS JOBS;
CREATE TABLE IF NOT EXISTS JOBS (
  ID SERIAL,
  USER_ID INT NULL,
  NAME VARCHAR(100) NOT NULL,
  JOB_URL VARCHAR(255) NOT NULL,
  JENKINS_HOST VARCHAR(255) NULL,
  MODIFIED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CREATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ID),
  CONSTRAINT fk_JOBS_USERS1
    FOREIGN KEY (USER_ID)
    REFERENCES USERS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);
CREATE UNIQUE INDEX JOB_URL_UNIQUE ON JOBS (JOB_URL);
CREATE INDEX fk_JOBS_USERS1_idx ON JOBS (USER_ID);
CREATE TRIGGER update_timestamp_jobs BEFORE INSERT OR UPDATE ON JOBS FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


DROP TABLE IF EXISTS TEST_RUNS;
CREATE TABLE IF NOT EXISTS TEST_RUNS (
  ID SERIAL,
  USER_ID INT,
  TEST_SUITE_ID INT NOT NULL,
  STATUS VARCHAR(20) NOT NULL,
  SCM_URL VARCHAR(255) NULL,
  SCM_BRANCH VARCHAR(100) NULL,
  SCM_COMMIT VARCHAR(100) NULL,
  CONFIG_XML TEXT NULL,
  WORK_ITEM_ID INT NULL,
  JOB_ID INT NOT NULL,
  BUILD_NUMBER INT NOT NULL,
  STARTED_BY VARCHAR(45) NULL,
  UPSTREAM_JOB_ID INT  NULL,
  UPSTREAM_JOB_BUILD_NUMBER INT NULL,
  MODIFIED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CREATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ID),
  CONSTRAINT fk_TEST_RESULTS_USERS1
    FOREIGN KEY (USER_ID)
    REFERENCES USERS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_TEST_RESULTS_TEST_SUITES1
    FOREIGN KEY (TEST_SUITE_ID)
    REFERENCES TEST_SUITES (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_TEST_RUNS_WORK_ITEMS1
    FOREIGN KEY (WORK_ITEM_ID)
    REFERENCES WORK_ITEMS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_TEST_RUNS_JOBS1
    FOREIGN KEY (JOB_ID)
    REFERENCES JOBS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_TEST_RUNS_JOBS2
    FOREIGN KEY (UPSTREAM_JOB_ID)
    REFERENCES JOBS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);  
CREATE INDEX FK_TEST_RUN_USER_ASC ON TEST_RUNS (USER_ID);
CREATE INDEX FK_TEST_RUN_TEST_SUITE_ASC ON TEST_RUNS (TEST_SUITE_ID);
CREATE INDEX fk_TEST_RUNS_WORK_ITEMS1_idx ON TEST_RUNS (WORK_ITEM_ID);
CREATE INDEX fk_TEST_RUNS_JOBS1_idx ON TEST_RUNS (JOB_ID);
CREATE INDEX fk_TEST_RUNS_JOBS2_idx ON TEST_RUNS (UPSTREAM_JOB_ID);
CREATE TRIGGER update_timestamp_test_runs BEFORE INSERT OR UPDATE ON TEST_RUNS FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

DROP TABLE IF EXISTS TESTS;
CREATE TABLE IF NOT EXISTS TESTS (
  ID SERIAL,
  NAME VARCHAR(255) NOT NULL,
  STATUS VARCHAR(10) NOT NULL,
  TEST_ARGS TEXT NULL,
  TEST_RUN_ID INT NOT NULL,
  TEST_CASE_ID INT NOT NULL,
  MESSAGE TEXT NULL,
  START_TIME TIMESTAMP NULL,
  FINISH_TIME TIMESTAMP NULL,
  DEMO_URL TEXT NULL,
  LOG_URL TEXT NULL,
  RETRY INT NOT NULL DEFAULT 0,
  MODIFIED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CREATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ID),
  CONSTRAINT fk_TESTS_TEST_RUNS1
    FOREIGN KEY (TEST_RUN_ID)
    REFERENCES TEST_RUNS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_TESTS_TEST_CASES1
    FOREIGN KEY (TEST_CASE_ID)
    REFERENCES TEST_CASES (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);
CREATE INDEX fk_TESTS_TEST_RUNS1_idx ON  TESTS (TEST_RUN_ID);
CREATE INDEX fk_TESTS_TEST_CASES1_idx ON  TESTS (TEST_CASE_ID);
CREATE TRIGGER update_timestamp_tests BEFORE INSERT OR UPDATE ON TESTS FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

DROP TABLE IF EXISTS TEST_WORK_ITEMS;
CREATE TABLE IF NOT EXISTS TEST_WORK_ITEMS (
  ID SERIAL,
  TEST_ID INT NOT NULL,
  WORK_ITEM_ID INT NOT NULL,
  MODIFIED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CREATED_AT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ID),
  CONSTRAINT fk_TEST_WORK_ITEMS_TESTS1
    FOREIGN KEY (TEST_ID)
    REFERENCES TESTS (ID)
    ON DELETE NO CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT fk_TEST_WORK_ITEMS_WORK_ITEMS1
    FOREIGN KEY (WORK_ITEM_ID)
    REFERENCES WORK_ITEMS (ID)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION);
CREATE INDEX fk_TEST_WORK_ITEMS_TESTS1_idx ON  TEST_WORK_ITEMS (TEST_ID);
CREATE INDEX fk_TEST_WORK_ITEMS_WORK_ITEMS1_idx ON  TEST_WORK_ITEMS (WORK_ITEM_ID);
CREATE TRIGGER update_timestamp_test_work_items BEFORE INSERT OR UPDATE ON TEST_WORK_ITEMS FOR EACH ROW EXECUTE PROCEDURE update_timestamp();



