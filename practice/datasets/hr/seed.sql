INSERT INTO departments (id, name, location) VALUES
  (1,'Engineering','Pune'),(2,'Sales','Austin'),(3,'Marketing','Leeds'),(4,'Finance','Berlin'),
  (5,'HR','Pune'),(6,'Support','Austin'),(7,'Legal','Berlin'),(8,'Research','Osaka'),(9,'Facilities','Pune');  -- 9 has no employees

-- 1 CEO, 2-6 VPs (report to 1), 7-30 directors (report to a VP), 31-250 staff (report to a director)
INSERT INTO employees (id, name, job_title, manager_id, dept_id, salary, hire_date, commission)
SELECT g,
       (ARRAY['Aarav','Maya','Liam','Sofia','Noah','Zara','Ethan','Mei','Omar','Lena','Ravi','Chloe'])[1 + g % 12] || ' ' ||
       (ARRAY['Sharma','Garcia','Smith','Chen','Okafor','Muller','Rossi','Kim','Patel','Silva'])[1 + (g * 3) % 10] || ' ' || g,
       CASE WHEN g = 1 THEN 'CEO' WHEN g <= 6 THEN 'VP' WHEN g <= 30 THEN 'Director'
            ELSE (ARRAY['Analyst','Engineer','Associate','Specialist'])[1 + g % 4] END,
       CASE WHEN g = 1 THEN NULL WHEN g <= 6 THEN 1 WHEN g <= 30 THEN 2 + g % 5 ELSE 7 + g % 24 END,
       1 + g % 8,
       CASE WHEN g = 1 THEN 300000 WHEN g <= 6 THEN 200000 + g * 1000 WHEN g <= 30 THEN 120000 + g * 700
            WHEN g % 125 = 0 THEN 100000          -- exactly on a band edge (salary-band questions)
            WHEN g % 40 = 0 THEN 60000            -- exactly on a band edge (g = 40, 80, ... are all in department 1: salary ties)
            WHEN g % 50 = 0 THEN 60000            -- exactly on a band edge
            ELSE 40000 + (g * 913) % 60000 END,
       DATE '2015-01-01' + (g * 29 % 3300),
       CASE WHEN g % 9 = 0 AND g > 30 THEN (g * 17) % 5000 END
FROM generate_series(1, 250) g;

-- two or three raises per person (every 3rd employee has just one entry)
INSERT INTO salary_history (emp_id, effective_date, salary)
SELECT e.id, e.hire_date + k * 365, round(e.salary * (0.80 + k * 0.10), 2)
FROM employees e
CROSS JOIN LATERAL generate_series(0, CASE WHEN e.id % 3 = 0 THEN 0 ELSE 2 END) k;

INSERT INTO projects (id, name, dept_id, start_date, end_date)
SELECT g, 'Project ' || (ARRAY['Atlas','Borealis','Cobalt','Delta','Ember','Falcon','Gemini','Helix','Ion','Juno','Kite','Lumen'])[g],
       1 + g % 8, DATE '2021-01-01' + g * 90,
       CASE WHEN g % 3 = 0 THEN NULL ELSE DATE '2021-01-01' + g * 90 + 200 END
FROM generate_series(1, 12) g;

INSERT INTO project_assignments (project_id, emp_id, role, hours)
SELECT DISTINCT ON (p, e) p, e, (ARRAY['lead','dev','analyst','reviewer'])[1 + (p + e) % 4], 20 + (p * e) % 180
FROM generate_series(1, 12) p
CROSS JOIN LATERAL (SELECT 31 + (p * 11 + k * 7) % 200 AS e FROM generate_series(1, 14) k) x(e)
ORDER BY p, e;
