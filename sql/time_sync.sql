CREATE OR REPLACE FUNCTION ensure_time_and_activity()
  RETURNS void AS
$$
---- Check the timestamp from last commit transaction and compare it with current time
---- Should not be more than 5 minutes since we ensure activity every 5 minutes
DECLARE p_last_commit_timestamp timestamp with time zone := timestamp FROM pg_last_committed_xact();
        p_datname text := current_database();
        p_maintenance_db text := datname FROM pg_database WHERE datname <> current_database() AND datname <> 'template0' LIMIT 1;
BEGIN
    IF p_last_commit_timestamp > now() THEN
        RAISE NOTICE 'Setting the database % to read-only to prevent future transactions from using current timestamp % which appears to be behind', p_datname, now();
        RAISE LOG 'Setting the database % to read-only to prevent future transactions from using current timestamp % which appears to be behind', p_datname, now();
        EXECUTE 'ALTER DATABASE ' || p_datname || ' SET default_transaction_read_only TO on';
        --- transactions that started before the host time change will maintain the old time as the time from now() and current_timestamp
        --- is the time when the transaction started
        --- at this point new sessions won't be able to write to the database but open sessions/transactions will still be able to
        --- close all opened sessions
        PERFORM pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = p_datname AND pid <> pg_backend_pid();
        RAISE NOTICE 'Adjust the host machine time accordingly and execute this query in % database: ALTER DATABASE % SET default_transaction_read_only TO off', p_maintenance_db, p_datname;
        RAISE LOG 'Adjust the host machine time accordingly and execute this query in % database: ALTER DATABASE % SET default_transaction_read_only TO off', p_maintenance_db, p_datname; 
    END IF;
END;
$$
LANGUAGE plpgsql;
