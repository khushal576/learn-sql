-- REGION TREE: world > country > state > city. One root (parent_id IS NULL). Exactly 4 levels (depth 1..4); hubs sit only in cities.
CREATE TABLE regions (
  id        int PRIMARY KEY,
  name      text NOT NULL,
  parent_id int REFERENCES regions (id)          -- NULL only for the single root 'World'
);
CREATE TABLE hubs (
  id        int PRIMARY KEY,
  name      text NOT NULL,
  region_id int NOT NULL REFERENCES regions (id), -- always a city-level region
  kind      text NOT NULL CHECK (kind IN ('main', 'sorting', 'depot', 'pickup'))  -- hub 1 is the only 'main' hub
);
-- DIRECTED GRAPH over hubs. On purpose:
--  * some two-way roads are stored as TWO rows (a->b and b->a), others are one-way (one row);
--  * CYCLES exist: 4->5->6->4, 6->17->18->19->6 and 22->23->24->25->22 (a recursive walk without cycle protection never ends);
--  * several different paths with different totals between the same hubs (e.g. 1 -> 4, 1 -> 9);
--  * hubs 29 and 30 are UNREACHABLE from the main hub 1 (they only link to each other and one-way back to hub 1).
CREATE TABLE routes (
  from_hub int NOT NULL REFERENCES hubs (id),
  to_hub   int NOT NULL REFERENCES hubs (id),
  km       int NOT NULL CHECK (km > 0),
  PRIMARY KEY (from_hub, to_hub)
);
-- NESTED PACKAGING: pallet (root, parent_id NULL) > carton > (carton >) item. Cartons can sit inside cartons, so depth is 3 or 4.
-- weight_kg is the node's OWN weight (tare for pallets/cartons); the total weight of a pallet needs recursion.
CREATE TABLE package_units (
  id        int PRIMARY KEY,
  parent_id int REFERENCES package_units (id),
  kind      text NOT NULL CHECK (kind IN ('pallet', 'carton', 'item')),
  weight_kg numeric(8,2) NOT NULL
);
-- SUPERVISOR HIERARCHY: 3 levels. Driver 1 is the single top supervisor (supervisor_id NULL).
CREATE TABLE drivers (
  id            int PRIMARY KEY,
  name          text NOT NULL,
  supervisor_id int REFERENCES drivers (id),
  hub_id        int NOT NULL REFERENCES hubs (id),
  hired_on      date NOT NULL
);
-- trips over 2024. fare is NULL for every cancelled trip (and only for those). from_hub <> to_hub always.
CREATE TABLE trips (
  id         int PRIMARY KEY,
  driver_id  int NOT NULL REFERENCES drivers (id),
  from_hub   int NOT NULL REFERENCES hubs (id),
  to_hub     int NOT NULL REFERENCES hubs (id),
  started_at timestamp NOT NULL,
  km         int NOT NULL,
  fare       numeric(10,2),
  status     text NOT NULL CHECK (status IN ('done', 'cancelled', 'delayed'))
);
CREATE INDEX ON regions (parent_id);
CREATE INDEX ON routes (to_hub);
CREATE INDEX ON package_units (parent_id);
CREATE INDEX ON drivers (supervisor_id);
CREATE INDEX ON trips (driver_id);
CREATE INDEX ON trips (started_at);
