-- E-commerce shop. Loaded into its own schema (search_path is set by the loader), so no schema prefixes here.
CREATE TABLE customers (
  id          int PRIMARY KEY,
  name        text NOT NULL,
  email       text NOT NULL UNIQUE,
  country     text NOT NULL,
  city        text,                       -- NULL for some customers on purpose
  segment     text NOT NULL CHECK (segment IN ('consumer', 'corporate', 'home_office')),
  signup_date date NOT NULL
);
CREATE TABLE categories (
  id        int PRIMARY KEY,
  name      text NOT NULL,
  parent_id int REFERENCES categories (id)   -- NULL = top level (a tree: use a recursive CTE)
);
CREATE TABLE products (
  id          int PRIMARY KEY,
  name        text NOT NULL,
  category_id int NOT NULL REFERENCES categories (id),
  price       numeric(10,2) NOT NULL,
  cost        numeric(10,2) NOT NULL,
  active      boolean NOT NULL DEFAULT true,
  created_at  date NOT NULL
);
CREATE TABLE orders (
  id           int PRIMARY KEY,
  customer_id  int NOT NULL REFERENCES customers (id),
  order_date   date NOT NULL,
  status       text NOT NULL CHECK (status IN ('placed', 'shipped', 'delivered', 'cancelled', 'returned')),
  shipped_date date                         -- NULL until shipped
);
CREATE TABLE order_items (
  order_id   int NOT NULL REFERENCES orders (id),
  line_no    int NOT NULL,
  product_id int NOT NULL REFERENCES products (id),
  quantity   int NOT NULL,
  unit_price numeric(10,2) NOT NULL,        -- the price paid (can differ from products.price)
  PRIMARY KEY (order_id, line_no)
);
CREATE TABLE payments (
  id       int PRIMARY KEY,
  order_id int NOT NULL REFERENCES orders (id),
  method   text NOT NULL,
  amount   numeric(12,2) NOT NULL,
  paid_at  timestamp NOT NULL
);
CREATE TABLE reviews (
  id          int PRIMARY KEY,
  product_id  int NOT NULL REFERENCES products (id),
  customer_id int NOT NULL REFERENCES customers (id),
  rating      int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at  date NOT NULL,
  body        text                          -- NULL when the customer left only a rating
);
CREATE INDEX ON orders (customer_id);
CREATE INDEX ON orders (order_date);
CREATE INDEX ON order_items (product_id);
CREATE INDEX ON reviews (product_id);
