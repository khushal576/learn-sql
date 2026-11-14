INSERT INTO teachers (id, name, subject) VALUES
  (1,'Ms. Rao','Math'),(2,'Mr. Klein','Science'),(3,'Ms. Okoye','Languages'),(4,'Mr. Tanaka','Arts'),
  (5,'Ms. Silva','Math'),(6,'Mr. Novak','Science'),(7,'Ms. Haddad','Languages'),(8,'Mr. Brooks','Sports'),
  (9,'Ms. Kim','Arts'),(10,'Mr. Alvarez','Math'),(11,'Ms. Dubois','Sports'),(12,'Mr. Patel','Science');   -- 11 and 12 teach nothing

INSERT INTO courses (id, title, teacher_id, credits)
SELECT g,
       (ARRAY['Algebra','Biology','Chemistry','Drama','English','Geometry','History','Music'])[1 + g % 8] || ' ' ||
       (ARRAY['I','II','III'])[1 + (g / 8) % 3],
       CASE WHEN g IN (23, 24) THEN NULL ELSE 1 + (g - 1) % 10 END,
       1 + g % 4
FROM generate_series(1, 24) g;

INSERT INTO students (id, name, grade, city, joined)
SELECT g,
       (ARRAY['Aarav','Maya','Liam','Sofia','Noah','Zara','Ethan','Mei','Omar','Lena','Ravi','Chloe','Jon','Ana','Kofi','Yuki'])[1 + g % 16] || ' ' ||
       (ARRAY['Sharma','Garcia','Smith','Chen','Okafor','Muller','Rossi','Kim','Patel','Silva','Novak'])[1 + (g * 7) % 11],
       9 + g % 4,
       CASE WHEN g % 29 = 0 THEN NULL ELSE (ARRAY['Pune','Austin','Leeds','Berlin','Recife','Osaka'])[1 + g % 6] END,
       DATE '2021-09-01' + (g * 13 % 700)
FROM generate_series(1, 300) g;

-- students 291-300 never enrol in anything; each other student takes 3-6 courses
INSERT INTO enrollments (student_id, course_id, enrolled_on, status)
SELECT s, 1 + (s * 7 + k * 5) % 24,
       DATE '2024-01-10' + (s + k) % 30,
       CASE WHEN (s + k) % 11 = 0 THEN 'dropped' WHEN (s + k) % 3 = 0 THEN 'completed' ELSE 'active' END
FROM generate_series(1, 290) s CROSS JOIN LATERAL generate_series(0, 2 + s % 4) k;

INSERT INTO scores (id, student_id, course_id, exam, score, taken_on)
SELECT row_number() OVER (ORDER BY student_id, course_id, exam), student_id, course_id, exam, score, taken_on
FROM (
  SELECT student_id, course_id, 'midterm' AS exam, 35 + (student_id * 31 + course_id * 17) % 66 AS score, enrolled_on + 40 AS taken_on
  FROM enrollments WHERE status <> 'dropped'
  UNION ALL
  SELECT student_id, course_id, 'final', 30 + (student_id * 13 + course_id * 29) % 71, enrolled_on + 90
  FROM enrollments WHERE status = 'completed'
) x;

INSERT INTO grade_bands (letter, min_score, max_score) VALUES
  ('A', 90, 101), ('B', 80, 90), ('C', 70, 80), ('D', 60, 70), ('F', 0, 60);
