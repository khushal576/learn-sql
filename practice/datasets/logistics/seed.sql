-- regions: 1 World; 2-5 countries; 6-17 states (3 per country); 18-60 cities (spread over the 12 states)
INSERT INTO regions (id, name, parent_id)
SELECT g,
       CASE WHEN g = 1 THEN 'World'
            WHEN g <= 5  THEN (ARRAY['Aldoria','Borland','Cantera','Dunmark'])[g - 1]
            WHEN g <= 17 THEN (ARRAY['North','Central','South'])[1 + (g - 6) % 3] || ' ' || (ARRAY['Aldoria','Borland','Cantera','Dunmark'])[1 + (g - 6) / 3]
            ELSE (ARRAY['Port','Fort','Lake','Mount','Glen','Bay'])[1 + g % 6] || ' ' || (ARRAY['Arden','Brook','Carrow','Dale','Elm','Fenn','Garth'])[1 + (g * 3) % 7] || ' ' || g END,
       CASE WHEN g = 1 THEN NULL
            WHEN g <= 5  THEN 1
            WHEN g <= 17 THEN 2 + (g - 6) / 3
            ELSE 6 + (g - 18) % 12 END
FROM generate_series(1, 60) g;

-- 30 hubs, each in a different city (7 is coprime with 43 so the cities never repeat)
INSERT INTO hubs (id, name, region_id, kind)
SELECT g, 'Hub ' || g, 18 + (g * 7) % 43,
       CASE WHEN g = 1 THEN 'main' WHEN g % 5 = 0 THEN 'sorting' WHEN g % 2 = 0 THEN 'depot' ELSE 'pickup' END
FROM generate_series(1, 30) g;

INSERT INTO routes (from_hub, to_hub, km) VALUES
  -- two-way roads (both directions stored)
  (1,2,120),(2,1,120),(1,3,90),(3,1,90),(1,4,200),(4,1,200),(2,7,60),(7,2,60),(3,8,75),(8,3,75),
  (7,8,40),(8,7,40),(8,9,55),(9,8,55),(9,10,80),(10,9,80),(10,11,35),(11,10,35),(1,12,150),(12,1,150),
  (12,13,70),(13,12,70),(13,14,45),(14,13,45),(14,15,90),(15,14,90),(20,21,50),(21,20,50),(29,30,40),(30,29,40),
  -- one-way roads, including the cycle 4->5->6->4 and the longer cycles
  (4,5,60),(5,6,70),(6,4,80),(2,4,130),(8,4,95),(4,16,110),
  (6,17,65),(17,18,40),(18,19,55),(19,6,90),(19,20,50),
  (15,16,60),(16,22,100),(22,23,45),(23,24,60),(24,25,30),(25,22,70),
  (11,15,120),(10,26,85),(26,27,50),(27,28,65),(5,28,140),
  (29,1,300);  -- unreachable hub 29 can still drive INTO the network

-- packaging: 1-8 pallets; 9-48 cartons on pallets; 49-72 cartons inside those cartons; 73-300 items in cartons
INSERT INTO package_units (id, parent_id, kind, weight_kg)
SELECT g,
       CASE WHEN g <= 8  THEN NULL
            WHEN g <= 48 THEN 1 + (g - 9) % 8
            WHEN g <= 72 THEN 9 + ((g - 49) * 7) % 40
            ELSE 9 + (g * 5) % 64 END,
       CASE WHEN g <= 8 THEN 'pallet' WHEN g <= 72 THEN 'carton' ELSE 'item' END,
       CASE WHEN g <= 8  THEN 20 + g
            WHEN g <= 72 THEN round((0.4 + (g % 7) * 0.15)::numeric, 2)
            ELSE round((0.1 + (g % 13) * 0.35)::numeric, 2) END
FROM generate_series(1, 300) g;

-- drivers: 1 top; 2-6 report to 1; 7-40 report to one of 2-6
INSERT INTO drivers (id, name, supervisor_id, hub_id, hired_on)
SELECT g,
       (ARRAY['Aarav','Maya','Liam','Sofia','Noah','Zara','Ethan','Mei','Omar','Lena','Ravi','Chloe'])[1 + g % 12] || ' ' ||
       (ARRAY['Sharma','Garcia','Smith','Chen','Okafor','Muller','Rossi','Kim','Patel'])[1 + (g * 5) % 9],
       CASE WHEN g = 1 THEN NULL WHEN g <= 6 THEN 1 ELSE 2 + g % 5 END,
       1 + (g * 3) % 28,
       DATE '2015-01-01' + (g * 97 % 3000)
FROM generate_series(1, 40) g;

-- 3000 trips: every 17th cancelled (fare NULL), every 11th (not cancelled) delayed
INSERT INTO trips (id, driver_id, from_hub, to_hub, started_at, km, fare, status)
SELECT g, 1 + (g * 7) % 40, 1 + (g * 3) % 30, 1 + (g * 3 + 1 + g % 28) % 30,
       TIMESTAMP '2024-01-01' + ((g * 173) % 366) * INTERVAL '1 day' + ((g * 37) % 1440) * INTERVAL '1 minute',
       20 + (g * 53) % 480,
       CASE WHEN g % 17 = 0 THEN NULL ELSE round((15 + (20 + (g * 53) % 480) * 0.9 + (g % 9) * 2.5)::numeric, 2) END,
       CASE WHEN g % 17 = 0 THEN 'cancelled' WHEN g % 11 = 0 THEN 'delayed' ELSE 'done' END
FROM generate_series(1, 3000) g;
