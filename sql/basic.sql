CREATE EXTENSION pg_drop_events;
SELECT pg_sleep(.5);
SELECT 1;
DROP EXTENSION pg_drop_events;
