CREATE TABLE customers (
  id      int PRIMARY KEY,
  name    text NOT NULL,
  city    text,                                  -- NULL for some customers
  segment text NOT NULL CHECK (segment IN ('retail', 'premium', 'business')),
  joined  date NOT NULL
);
CREATE TABLE accounts (
  id              int PRIMARY KEY,
  customer_id     int NOT NULL REFERENCES customers (id),
  type            text NOT NULL CHECK (type IN ('checking', 'savings', 'credit')),
  opened_on       date NOT NULL,
  status          text NOT NULL CHECK (status IN ('open', 'closed')),
  overdraft_limit numeric(10,2) NOT NULL DEFAULT 0
);
-- amount is SIGNED: money in is positive, money out is negative. Several rows of one account share a tx_date.
CREATE TABLE transactions (
  id         int PRIMARY KEY,
  account_id int NOT NULL REFERENCES accounts (id),
  tx_date    date NOT NULL,
  kind       text NOT NULL CHECK (kind IN ('deposit', 'withdrawal', 'purchase', 'fee', 'interest')),
  amount     numeric(12,2) NOT NULL,
  merchant   text                                -- only for purchases
);
CREATE TABLE loans (
  id          int PRIMARY KEY,
  customer_id int NOT NULL REFERENCES customers (id),
  principal   numeric(12,2) NOT NULL,
  annual_rate numeric(5,2) NOT NULL,
  start_date  date NOT NULL,
  term_months int NOT NULL,
  status      text NOT NULL CHECK (status IN ('active', 'paid', 'defaulted'))
);
CREATE INDEX ON accounts (customer_id);
CREATE INDEX ON transactions (account_id, tx_date);
CREATE INDEX ON loans (customer_id);
