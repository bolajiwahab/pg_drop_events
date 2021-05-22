/* pg_drop_events--1.0.sql */
-- complain if script is sourced in psql, rather than via CREATE EXTENSION

\echo Use "CREATE EXTENSION pg_drop_events" to load this file. \quit

DO $$
DECLARE pg_version int;
BEGIN
    pg_version := setting::int FROM pg_settings WHERE name = 'server_version_num';

    IF pg_version < 130000 THEN
    CREATE TABLE pg_drop_events (
        pid             int,
        username        text,
        query           text,
        xact_id         bigint,
        wal_position    pg_lsn,
        object_name     text,
        object_type     text,
        time            timestamp with time zone
    );
    ELSE 
        CREATE TABLE pg_drop_events (
        pid             int,
        username        text,
        query           text,
        xact_id         xid8,
        wal_position    pg_lsn,
        object_name     text,
        object_type     text,
        time            timestamp with time zone
    );
    END IF;
  END;
$$;

GRANT SELECT ON pg_drop_events TO public;

DO $$
DECLARE pg_version int;
BEGIN
    pg_version := setting::int FROM pg_settings WHERE name = 'server_version_num';

    IF pg_version < 100000 THEN
        CREATE OR REPLACE FUNCTION pg_drop_events()
          RETURNS event_trigger AS $LD$
        DECLARE 
            tbd record;
        BEGIN
            FOR tbd IN
                SELECT o.object_type, o.object_identity
                  FROM pg_event_trigger_dropped_objects() o 
                 WHERE NOT o.is_temporary
                   AND o.classid = 'pg_catalog.pg_class'::regclass::oid
                   AND o.object_type = ANY ('{table,table column}')
            LOOP
                RAISE NOTICE '% % dropped by transaction %.', tbd.object_type, tbd.object_identity, txid_current();
    
                INSERT INTO pg_drop_events(pid, username, query, xact_id, wal_position, object_name, object_type, xact_start)
                SELECT pg_backend_pid()
                     , session_user
                     , current_query()
                     , txid_current()
                     , pg_current_xlog_location()
                     , tbd.object_identity
                     , tbd.object_type
                     , now();
            END LOOP;
        END;
        $LD$ LANGUAGE plpgsql;
    ELSIF pg_version >= 130000 THEN
        CREATE OR REPLACE FUNCTION pg_drop_events()
          RETURNS event_trigger AS $LD$
        DECLARE 
            tbd record;
        BEGIN
            FOR tbd IN
                SELECT o.object_type, o.object_identity
                  FROM pg_event_trigger_dropped_objects() o 
                 WHERE NOT o.is_temporary
                   AND o.classid = 'pg_catalog.pg_class'::regclass::oid
                   AND o.object_type = ANY ('{table,table column}')
            LOOP
                RAISE NOTICE '% % dropped by transaction %.', tbd.object_type, tbd.object_identity, pg_current_xact_id();
    
                INSERT INTO pg_drop_events(pid, username, query, xact_id, wal_position, object_name, object_type, xact_start)
                SELECT pg_backend_pid()
                     , session_user
                     , current_query()
                     , pg_current_xact_id()
                     , pg_current_wal_lsn()
                     , tbd.object_identity
                     , tbd.object_type
                     , now();
            END LOOP;
        END;
        $LD$ LANGUAGE plpgsql;
    ELSE      
        CREATE OR REPLACE FUNCTION pg_drop_events()
          RETURNS event_trigger AS $LD$
        DECLARE 
            tbd record;
        BEGIN
            FOR tbd IN
                SELECT o.object_type, o.object_identity
                  FROM pg_event_trigger_dropped_objects() o 
                 WHERE NOT o.is_temporary
                   AND o.classid = 'pg_catalog.pg_class'::regclass::oid
                   AND o.object_type = ANY ('{table,table column}')
            LOOP
                RAISE NOTICE '% % dropped by transaction %.', tbd.object_type, tbd.object_identity, txid_current();
    
                INSERT INTO pg_drop_events(pid, username, query, xact_id, wal_position, object_name, object_type, xact_start)
                SELECT pg_backend_pid()
                     , session_user
                     , current_query()
                     , txid_current()
                     , pg_current_wal_lsn()
                     , tbd.object_identity
                     , tbd.object_type
                     , now();
            END LOOP;
        END;
        $LD$ LANGUAGE plpgsql;
    END IF;
END;
$$;

DROP EVENT TRIGGER IF EXISTS ZZZ_pg_drop_events;

CREATE EVENT TRIGGER ZZZ_pg_drop_events ON sql_drop
    EXECUTE PROCEDURE pg_drop_events();

COMMENT ON FUNCTION pg_drop_events() IS 'logs transaction ids of drop table, drop column statements to aid point in time recovery.';
