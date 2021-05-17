EXTENSION = pg_drop_events
DATA = pg_drop_events--1.0.sql
PGFILEDESC = "pg_drop_events - logs transaction ids of drop table, drop column statements to aid point in time recovery"
REGRESS = basic pg_drop_events
PG_CONFIG = /usr/lib/postgresql/9.5/bin/pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
