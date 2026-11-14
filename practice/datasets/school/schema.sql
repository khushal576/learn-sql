CREATE TABLE teachers (
  id      int PRIMARY KEY,
  name    text NOT NULL,
  subject text NOT NULL
);
CREATE TABLE courses (
  id         int PRIMARY KEY,
  title      text NOT NULL,
  teacher_id int REFERENCES teachers (id),   -- NULL = no teacher assigned yet (watch out with NOT IN)
  credits    int NOT NULL
);
CREATE TABLE students (
  id     int PRIMARY KEY,
  name   text NOT NULL,
  grade  int NOT NULL,                       -- school year 9-12
  city   text,                               -- NULL for some students
  joined date NOT NULL
);
CREATE TABLE enrollments (
  student_id  int NOT NULL REFERENCES students (id),
  course_id   int NOT NULL REFERENCES courses (id),
  enrolled_on date NOT NULL,
  status      text NOT NULL CHECK (status IN ('active', 'completed', 'dropped')),
  PRIMARY KEY (student_id, course_id)
);
CREATE TABLE scores (
  id         int PRIMARY KEY,
  student_id int NOT NULL,
  course_id  int NOT NULL,
  exam       text NOT NULL CHECK (exam IN ('midterm', 'final')),
  score      int NOT NULL,                   -- 0-100
  taken_on   date NOT NULL,
  UNIQUE (student_id, course_id, exam),
  FOREIGN KEY (student_id, course_id) REFERENCES enrollments (student_id, course_id)
);
-- letter grade per score range: min_score is INCLUSIVE, max_score is EXCLUSIVE (so A runs up to 101: a 100 is an A)
CREATE TABLE grade_bands (
  letter    text PRIMARY KEY,
  min_score int NOT NULL,
  max_score int NOT NULL
);
CREATE INDEX ON enrollments (course_id);
CREATE INDEX ON scores (course_id);
