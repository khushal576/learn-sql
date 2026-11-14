CREATE TABLE departments (
  id       int PRIMARY KEY,
  name     text NOT NULL,
  location text NOT NULL
);
CREATE TABLE employees (
  id         int PRIMARY KEY,
  name       text NOT NULL,
  job_title  text NOT NULL,
  manager_id int REFERENCES employees (id),   -- NULL only for the CEO (a tree: use a recursive CTE)
  dept_id    int NOT NULL REFERENCES departments (id),
  salary     numeric(10,2) NOT NULL,
  hire_date  date NOT NULL,
  commission numeric(10,2)                    -- NULL for most people
);
CREATE TABLE salary_history (
  emp_id         int NOT NULL REFERENCES employees (id),
  effective_date date NOT NULL,
  salary         numeric(10,2) NOT NULL,
  PRIMARY KEY (emp_id, effective_date)
);
CREATE TABLE projects (
  id         int PRIMARY KEY,
  name       text NOT NULL,
  dept_id    int NOT NULL REFERENCES departments (id),
  start_date date NOT NULL,
  end_date   date                             -- NULL = still running
);
CREATE TABLE project_assignments (
  project_id int NOT NULL REFERENCES projects (id),
  emp_id     int NOT NULL REFERENCES employees (id),
  role       text NOT NULL,
  hours      int NOT NULL,
  PRIMARY KEY (project_id, emp_id)
);
