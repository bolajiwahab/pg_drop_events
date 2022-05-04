EXTENSION   = pg_drop_events
EXTVERSION  = 0.1
DATA        = $(filter-out $(DATA_built), $(wildcard *--*.sql))
DOCS         = $(wildcard doc/*.md)
TESTS        = $(wildcard test/sql/*.sql)
PGFILEDESC  = "$(EXTENSION) - logs transaction ids of drop table, drop column, drop materialized view statements to aid point in time recovery"

define CONTROL_FILE_CONTENT
# pg_drop_events extension
comment = '$(EXTENSION) - logs transaction ids of drop table, drop column, drop materialized view statements to aid point in time recovery'
default_version = '$(EXTVERSION)'
relocatable = false
schema = 'public'
requires = 'plpgsql'\n
endef

define EXT_PREFIX
/* pg_drop_events/$(EXTENSION)--$(EXTVERSION).sql */

-- complain if script is sourced in psql, rather than via create extension
\\echo Use "CREATE EXTENSION $(EXTENSION) VERSION '$(EXTVERSION)'" to load this file. \\quit\n
endef

export CONTROL_FILE_CONTENT
export EXT_PREFIX

OBJECTS = src/pg_drop_events.sql
REGRESS      = $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS = --inputdir=test

DATA_built = $(CONTROL_FILE_NAME) $(EXTENSION)--$(EXTVERSION).sql
CONTROL_FILE_NAME := $(addsuffix .control, $(EXTENSION))

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

ifdef VERBOSE
ARGS="--verbose"
endif

$(EXTENSION)--$(EXTVERSION).sql: $(OBJECTS)
	@printf -- "$$EXT_PREFIX" > $@
	cat $^ >> $@

$(CONTROL_FILE_NAME):
	@printf -- "$$CONTROL_FILE_CONTENT" > $@
