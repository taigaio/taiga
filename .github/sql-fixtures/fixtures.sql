PGDMP  	        5                z            taiga    12.3 (Debian 12.3-1.pgdg100+1)    13.6 ,   y           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            z           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            {           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            |           1262    3594395    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false            �           1247    3599770    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false            �           1247    3599761    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            �           1255    3595541    array_distinct(anyarray)    FUNCTION     �   CREATE FUNCTION public.array_distinct(anyarray) RETURNS anyarray
    LANGUAGE sql
    AS $_$
              SELECT ARRAY(SELECT DISTINCT unnest($1))
            $_$;
 /   DROP FUNCTION public.array_distinct(anyarray);
       public          taiga    false            �           1255    3595963 '   clean_key_in_custom_attributes_values()    FUNCTION     �  CREATE FUNCTION public.clean_key_in_custom_attributes_values() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                       DECLARE
                               key text;
                               project_id int;
                               object_id int;
                               attribute text;
                               tablename text;
                               custom_attributes_tablename text;
                         BEGIN
                               key := OLD.id::text;
                               project_id := OLD.project_id;
                               attribute := TG_ARGV[0]::text;
                               tablename := TG_ARGV[1]::text;
                               custom_attributes_tablename := TG_ARGV[2]::text;

                               EXECUTE 'UPDATE ' || quote_ident(custom_attributes_tablename) || '
                                           SET attributes_values = json_object_delete_keys(attributes_values, ' || quote_literal(key) || ')
                                          FROM ' || quote_ident(tablename) || '
                                         WHERE ' || quote_ident(tablename) || '.project_id = ' || project_id || '
                                           AND ' || quote_ident(custom_attributes_tablename) || '.' || quote_ident(attribute) || ' = ' || quote_ident(tablename) || '.id';
                               RETURN NULL;
                           END; $$;
 >   DROP FUNCTION public.clean_key_in_custom_attributes_values();
       public          taiga    false            �           1255    3595511 !   inmutable_array_to_string(text[])    FUNCTION     �   CREATE FUNCTION public.inmutable_array_to_string(text[]) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$SELECT array_to_string($1, ' ', '')$_$;
 8   DROP FUNCTION public.inmutable_array_to_string(text[]);
       public          taiga    false            �           1255    3595962 %   json_object_delete_keys(json, text[])    FUNCTION     �  CREATE FUNCTION public.json_object_delete_keys(json json, VARIADIC keys_to_delete text[]) RETURNS json
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
                   SELECT COALESCE ((SELECT ('{' || string_agg(to_json("key") || ':' || "value", ',') || '}')
                                       FROM json_each("json")
                                      WHERE "key" <> ALL ("keys_to_delete")),
                                    '{}')::json $$;
 Y   DROP FUNCTION public.json_object_delete_keys(json json, VARIADIC keys_to_delete text[]);
       public          taiga    false            �           1255    3596087 &   json_object_delete_keys(jsonb, text[])    FUNCTION     �  CREATE FUNCTION public.json_object_delete_keys(json jsonb, VARIADIC keys_to_delete text[]) RETURNS jsonb
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
                   SELECT COALESCE ((SELECT ('{' || string_agg(to_json("key") || ':' || "value", ',') || '}')
                                       FROM jsonb_each("json")
                                      WHERE "key" <> ALL ("keys_to_delete")),
                                    '{}')::text::jsonb $$;
 Z   DROP FUNCTION public.json_object_delete_keys(json jsonb, VARIADIC keys_to_delete text[]);
       public          taiga    false            �           1255    3599835 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	job_id bigint;
BEGIN
    INSERT INTO procrastinate_jobs (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    VALUES (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    RETURNING id INTO job_id;

    RETURN job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone);
       public          taiga    false            �           1255    3599852 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, queue_name, defer_timestamp)
        VALUES (_task_name, _queue_name, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                ('{"timestamp": ' || _defer_timestamp || '}')::jsonb,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.queue_name = _queue_name
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint);
       public          taiga    false            �           1255    3599836 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, periodic_id, defer_timestamp)
        VALUES (_task_name, _periodic_id, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                _args,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.periodic_id = _periodic_id
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb);
       public          taiga    false            _           1259    3599787    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
    id bigint NOT NULL,
    queue_name character varying(128) NOT NULL,
    task_name character varying(128) NOT NULL,
    lock text,
    queueing_lock text,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    status public.procrastinate_job_status DEFAULT 'todo'::public.procrastinate_job_status NOT NULL,
    scheduled_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL
);
 &   DROP TABLE public.procrastinate_jobs;
       public         heap    taiga    false    1182    1182            �           1255    3599837 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
	found_jobs procrastinate_jobs;
BEGIN
    WITH candidate AS (
        SELECT jobs.*
            FROM procrastinate_jobs AS jobs
            WHERE
                -- reject the job if its lock has earlier jobs
                NOT EXISTS (
                    SELECT 1
                        FROM procrastinate_jobs AS earlier_jobs
                        WHERE
                            jobs.lock IS NOT NULL
                            AND earlier_jobs.lock = jobs.lock
                            AND earlier_jobs.status IN ('todo', 'doing')
                            AND earlier_jobs.id < jobs.id)
                AND jobs.status = 'todo'
                AND (target_queue_names IS NULL OR jobs.queue_name = ANY( target_queue_names ))
                AND (jobs.scheduled_at IS NULL OR jobs.scheduled_at <= now())
            ORDER BY jobs.id ASC LIMIT 1
            FOR UPDATE OF jobs SKIP LOCKED
    )
    UPDATE procrastinate_jobs
        SET status = 'doing'
        FROM candidate
        WHERE procrastinate_jobs.id = candidate.id
        RETURNING procrastinate_jobs.* INTO found_jobs;

	RETURN found_jobs;
END;
$$;
 V   DROP FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]);
       public          taiga    false    351            �           1255    3599851 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1
    WHERE id = job_id;
END;
$$;
 k   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status);
       public          taiga    false    1182            �           1255    3599850 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1,
        scheduled_at = COALESCE(next_scheduled_at, scheduled_at)
    WHERE id = job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone);
       public          taiga    false    1182            �           1255    3599838 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    IF end_status NOT IN ('succeeded', 'failed') THEN
        RAISE 'End status should be either "succeeded" or "failed" (job id: %)', job_id;
    END IF;
    IF delete_job THEN
        DELETE FROM procrastinate_jobs
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    ELSE
        UPDATE procrastinate_jobs
        SET status = end_status,
            attempts =
                CASE
                    WHEN status = 'doing' THEN attempts + 1
                    ELSE attempts
                END
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    END IF;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" or "todo" status (job id: %)', job_id;
    END IF;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean);
       public          taiga    false    1182            �           1255    3599840    procrastinate_notify_queue()    FUNCTION     
  CREATE FUNCTION public.procrastinate_notify_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	PERFORM pg_notify('procrastinate_queue#' || NEW.queue_name, NEW.task_name);
	PERFORM pg_notify('procrastinate_any_queue', NEW.task_name);
	RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.procrastinate_notify_queue();
       public          taiga    false            �           1255    3599839 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    UPDATE procrastinate_jobs
    SET status = 'todo',
        attempts = attempts + 1,
        scheduled_at = retry_at
    WHERE id = job_id AND status = 'doing'
    RETURNING id INTO _job_id;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" status (job id: %)', job_id;
    END IF;
END;
$$;
 a   DROP FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone);
       public          taiga    false            �           1255    3599843 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false            �           1255    3599841 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            �           1255    3599842 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH t AS (
        SELECT CASE
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND NEW.status = 'doing'::procrastinate_job_status
                THEN 'started'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'todo'::procrastinate_job_status
                THEN 'deferred_for_retry'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'failed'::procrastinate_job_status
                THEN 'failed'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'succeeded'::procrastinate_job_status
                THEN 'succeeded'::procrastinate_job_event_type
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND (
                    NEW.status = 'failed'::procrastinate_job_status
                    OR NEW.status = 'succeeded'::procrastinate_job_status
                )
                THEN 'cancelled'::procrastinate_job_event_type
            ELSE NULL
        END as event_type
    )
    INSERT INTO procrastinate_events(job_id, type)
        SELECT NEW.id, t.event_type
        FROM t
        WHERE t.event_type IS NOT NULL;
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_update();
       public          taiga    false            �           1255    3599844 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_periodic_defers
    SET job_id = NULL
    WHERE job_id = OLD.id;
    RETURN OLD;
END;
$$;
 =   DROP FUNCTION public.procrastinate_unlink_periodic_defers();
       public          taiga    false            �           1255    3595539    reduce_dim(anyarray)    FUNCTION     �  CREATE FUNCTION public.reduce_dim(anyarray) RETURNS SETOF anyarray
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
            DECLARE
                s $1%TYPE;
            BEGIN
                IF $1 = '{}' THEN
                	RETURN;
                END IF;
                FOREACH s SLICE 1 IN ARRAY $1 LOOP
                    RETURN NEXT s;
                END LOOP;
                RETURN;
            END;
            $_$;
 +   DROP FUNCTION public.reduce_dim(anyarray);
       public          taiga    false            �           1255    3595542    update_project_tags_colors()    FUNCTION     �  CREATE FUNCTION public.update_project_tags_colors() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            DECLARE
            	tags text[];
            	project_tags_colors text[];
            	tag_color text[];
            	project_tags text[];
            	tag text;
            	project_id integer;
            BEGIN
            	tags := NEW.tags::text[];
            	project_id := NEW.project_id::integer;
            	project_tags := '{}';

            	-- Read project tags_colors into project_tags_colors
            	SELECT projects_project.tags_colors INTO project_tags_colors
                FROM projects_project
                WHERE id = project_id;

            	-- Extract just the project tags to project_tags_colors
                IF project_tags_colors != ARRAY[]::text[] THEN
                    FOREACH tag_color SLICE 1 in ARRAY project_tags_colors
                    LOOP
                        project_tags := array_append(project_tags, tag_color[1]);
                    END LOOP;
                END IF;

            	-- Add to project_tags_colors the new tags
                IF tags IS NOT NULL THEN
                    FOREACH tag in ARRAY tags
                    LOOP
                        IF tag != ALL(project_tags) THEN
                            project_tags_colors := array_cat(project_tags_colors,
                                                             ARRAY[ARRAY[tag, NULL]]);
                        END IF;
                    END LOOP;
                END IF;

            	-- Save the result in the tags_colors column
                UPDATE projects_project
                SET tags_colors = project_tags_colors
                WHERE id = project_id;

            	RETURN NULL;
            END; $$;
 3   DROP FUNCTION public.update_project_tags_colors();
       public          taiga    false            �           1255    3595540    array_agg_mult(anyarray) 	   AGGREGATE     w   CREATE AGGREGATE public.array_agg_mult(anyarray) (
    SFUNC = array_cat,
    STYPE = anyarray,
    INITCOND = '{}'
);
 0   DROP AGGREGATE public.array_agg_mult(anyarray);
       public          taiga    false            �           3600    3595439    english_stem_nostop    TEXT SEARCH DICTIONARY     {   CREATE TEXT SEARCH DICTIONARY public.english_stem_nostop (
    TEMPLATE = pg_catalog.snowball,
    language = 'english' );
 8   DROP TEXT SEARCH DICTIONARY public.english_stem_nostop;
       public          taiga    false            	           3602    3595440    english_nostop    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.english_nostop (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR asciiword WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR word WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR hword_part WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR hword_asciipart WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR asciihword WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR hword WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR uint WITH simple;
 6   DROP TEXT SEARCH CONFIGURATION public.english_nostop;
       public          taiga    false    2288            �            1259    3594704    attachments_attachment    TABLE     �  CREATE TABLE public.attachments_attachment (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    attached_file character varying(500),
    is_deprecated boolean NOT NULL,
    description text NOT NULL,
    "order" integer NOT NULL,
    content_type_id integer NOT NULL,
    owner_id bigint,
    project_id bigint NOT NULL,
    name character varying(500) NOT NULL,
    size integer,
    sha1 character varying(40) NOT NULL,
    from_comment boolean NOT NULL,
    CONSTRAINT attachments_attachment_object_id_check CHECK ((object_id >= 0))
);
 *   DROP TABLE public.attachments_attachment;
       public         heap    taiga    false            �            1259    3594750    attachments_attachment_id_seq    SEQUENCE     �   CREATE SEQUENCE public.attachments_attachment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.attachments_attachment_id_seq;
       public          taiga    false    220            }           0    0    attachments_attachment_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.attachments_attachment_id_seq OWNED BY public.attachments_attachment.id;
          public          taiga    false    221            �            1259    3594763 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    3594761    auth_group_id_seq    SEQUENCE     �   CREATE SEQUENCE public.auth_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.auth_group_id_seq;
       public          taiga    false    225            ~           0    0    auth_group_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.auth_group_id_seq OWNED BY public.auth_group.id;
          public          taiga    false    224            �            1259    3594773    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    3594771    auth_group_permissions_id_seq    SEQUENCE     �   CREATE SEQUENCE public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.auth_group_permissions_id_seq;
       public          taiga    false    227                       0    0    auth_group_permissions_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.auth_group_permissions_id_seq OWNED BY public.auth_group_permissions.id;
          public          taiga    false    226            �            1259    3594755    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    3594753    auth_permission_id_seq    SEQUENCE     �   CREATE SEQUENCE public.auth_permission_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.auth_permission_id_seq;
       public          taiga    false    223            �           0    0    auth_permission_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.auth_permission_id_seq OWNED BY public.auth_permission.id;
          public          taiga    false    222            �            1259    3595627    contact_contactentry    TABLE     �   CREATE TABLE public.contact_contactentry (
    id bigint NOT NULL,
    comment text NOT NULL,
    created_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    user_id bigint NOT NULL
);
 (   DROP TABLE public.contact_contactentry;
       public         heap    taiga    false            �            1259    3595660    contact_contactentry_id_seq    SEQUENCE     �   CREATE SEQUENCE public.contact_contactentry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.contact_contactentry_id_seq;
       public          taiga    false    245            �           0    0    contact_contactentry_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.contact_contactentry_id_seq OWNED BY public.contact_contactentry.id;
          public          taiga    false    246                       1259    3595978 %   custom_attributes_epiccustomattribute    TABLE     ~  CREATE TABLE public.custom_attributes_epiccustomattribute (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    description text NOT NULL,
    type character varying(16) NOT NULL,
    "order" bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    extra jsonb
);
 9   DROP TABLE public.custom_attributes_epiccustomattribute;
       public         heap    taiga    false                       1259    3596100 ,   custom_attributes_epiccustomattribute_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_epiccustomattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 C   DROP SEQUENCE public.custom_attributes_epiccustomattribute_id_seq;
       public          taiga    false    258            �           0    0 ,   custom_attributes_epiccustomattribute_id_seq    SEQUENCE OWNED BY     }   ALTER SEQUENCE public.custom_attributes_epiccustomattribute_id_seq OWNED BY public.custom_attributes_epiccustomattribute.id;
          public          taiga    false    260                       1259    3595989 ,   custom_attributes_epiccustomattributesvalues    TABLE     �   CREATE TABLE public.custom_attributes_epiccustomattributesvalues (
    id bigint NOT NULL,
    version integer NOT NULL,
    attributes_values jsonb NOT NULL,
    epic_id bigint NOT NULL
);
 @   DROP TABLE public.custom_attributes_epiccustomattributesvalues;
       public         heap    taiga    false                       1259    3596115 3   custom_attributes_epiccustomattributesvalues_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_epiccustomattributesvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.custom_attributes_epiccustomattributesvalues_id_seq;
       public          taiga    false    259            �           0    0 3   custom_attributes_epiccustomattributesvalues_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_epiccustomattributesvalues_id_seq OWNED BY public.custom_attributes_epiccustomattributesvalues.id;
          public          taiga    false    261            �            1259    3595853 &   custom_attributes_issuecustomattribute    TABLE       CREATE TABLE public.custom_attributes_issuecustomattribute (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    description text NOT NULL,
    "order" bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    type character varying(16) NOT NULL,
    extra jsonb
);
 :   DROP TABLE public.custom_attributes_issuecustomattribute;
       public         heap    taiga    false                       1259    3596130 -   custom_attributes_issuecustomattribute_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_issuecustomattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.custom_attributes_issuecustomattribute_id_seq;
       public          taiga    false    252            �           0    0 -   custom_attributes_issuecustomattribute_id_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.custom_attributes_issuecustomattribute_id_seq OWNED BY public.custom_attributes_issuecustomattribute.id;
          public          taiga    false    262            �            1259    3595910 -   custom_attributes_issuecustomattributesvalues    TABLE     �   CREATE TABLE public.custom_attributes_issuecustomattributesvalues (
    id bigint NOT NULL,
    version integer NOT NULL,
    attributes_values jsonb NOT NULL,
    issue_id bigint NOT NULL
);
 A   DROP TABLE public.custom_attributes_issuecustomattributesvalues;
       public         heap    taiga    false                       1259    3596145 4   custom_attributes_issuecustomattributesvalues_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_issuecustomattributesvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 K   DROP SEQUENCE public.custom_attributes_issuecustomattributesvalues_id_seq;
       public          taiga    false    255            �           0    0 4   custom_attributes_issuecustomattributesvalues_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_issuecustomattributesvalues_id_seq OWNED BY public.custom_attributes_issuecustomattributesvalues.id;
          public          taiga    false    263            �            1259    3595864 %   custom_attributes_taskcustomattribute    TABLE     ~  CREATE TABLE public.custom_attributes_taskcustomattribute (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    description text NOT NULL,
    "order" bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    type character varying(16) NOT NULL,
    extra jsonb
);
 9   DROP TABLE public.custom_attributes_taskcustomattribute;
       public         heap    taiga    false                       1259    3596160 ,   custom_attributes_taskcustomattribute_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_taskcustomattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 C   DROP SEQUENCE public.custom_attributes_taskcustomattribute_id_seq;
       public          taiga    false    253            �           0    0 ,   custom_attributes_taskcustomattribute_id_seq    SEQUENCE OWNED BY     }   ALTER SEQUENCE public.custom_attributes_taskcustomattribute_id_seq OWNED BY public.custom_attributes_taskcustomattribute.id;
          public          taiga    false    264                        1259    3595923 ,   custom_attributes_taskcustomattributesvalues    TABLE     �   CREATE TABLE public.custom_attributes_taskcustomattributesvalues (
    id bigint NOT NULL,
    version integer NOT NULL,
    attributes_values jsonb NOT NULL,
    task_id bigint NOT NULL
);
 @   DROP TABLE public.custom_attributes_taskcustomattributesvalues;
       public         heap    taiga    false            	           1259    3596175 3   custom_attributes_taskcustomattributesvalues_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_taskcustomattributesvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.custom_attributes_taskcustomattributesvalues_id_seq;
       public          taiga    false    256            �           0    0 3   custom_attributes_taskcustomattributesvalues_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_taskcustomattributesvalues_id_seq OWNED BY public.custom_attributes_taskcustomattributesvalues.id;
          public          taiga    false    265            �            1259    3595875 *   custom_attributes_userstorycustomattribute    TABLE     �  CREATE TABLE public.custom_attributes_userstorycustomattribute (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    description text NOT NULL,
    "order" bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    type character varying(16) NOT NULL,
    extra jsonb
);
 >   DROP TABLE public.custom_attributes_userstorycustomattribute;
       public         heap    taiga    false            
           1259    3596190 1   custom_attributes_userstorycustomattribute_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_userstorycustomattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 H   DROP SEQUENCE public.custom_attributes_userstorycustomattribute_id_seq;
       public          taiga    false    254            �           0    0 1   custom_attributes_userstorycustomattribute_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_userstorycustomattribute_id_seq OWNED BY public.custom_attributes_userstorycustomattribute.id;
          public          taiga    false    266                       1259    3595936 1   custom_attributes_userstorycustomattributesvalues    TABLE     �   CREATE TABLE public.custom_attributes_userstorycustomattributesvalues (
    id bigint NOT NULL,
    version integer NOT NULL,
    attributes_values jsonb NOT NULL,
    user_story_id bigint NOT NULL
);
 E   DROP TABLE public.custom_attributes_userstorycustomattributesvalues;
       public         heap    taiga    false                       1259    3596205 8   custom_attributes_userstorycustomattributesvalues_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_userstorycustomattributesvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 O   DROP SEQUENCE public.custom_attributes_userstorycustomattributesvalues_id_seq;
       public          taiga    false    257            �           0    0 8   custom_attributes_userstorycustomattributesvalues_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_userstorycustomattributesvalues_id_seq OWNED BY public.custom_attributes_userstorycustomattributesvalues.id;
          public          taiga    false    267            �            1259    3594433    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id bigint NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap    taiga    false            �            1259    3594431    django_admin_log_id_seq    SEQUENCE     �   CREATE SEQUENCE public.django_admin_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.django_admin_log_id_seq;
       public          taiga    false    208            �           0    0    django_admin_log_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.django_admin_log_id_seq OWNED BY public.django_admin_log.id;
          public          taiga    false    207            �            1259    3594409    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    3594407    django_content_type_id_seq    SEQUENCE     �   CREATE SEQUENCE public.django_content_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.django_content_type_id_seq;
       public          taiga    false    205            �           0    0    django_content_type_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.django_content_type_id_seq OWNED BY public.django_content_type.id;
          public          taiga    false    204            �            1259    3594398    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    3594396    django_migrations_id_seq    SEQUENCE     �   CREATE SEQUENCE public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.django_migrations_id_seq;
       public          taiga    false    203            �           0    0    django_migrations_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.django_migrations_id_seq OWNED BY public.django_migrations.id;
          public          taiga    false    202            ;           1259    3598324    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false                       1259    3596208    djmail_message    TABLE     �  CREATE TABLE public.djmail_message (
    uuid character varying(40) NOT NULL,
    from_email character varying(1024) NOT NULL,
    to_email text NOT NULL,
    body_text text NOT NULL,
    body_html text NOT NULL,
    subject character varying(1024) NOT NULL,
    data text NOT NULL,
    retry_count smallint NOT NULL,
    status smallint NOT NULL,
    priority smallint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    sent_at timestamp with time zone,
    exception text NOT NULL
);
 "   DROP TABLE public.djmail_message;
       public         heap    taiga    false                       1259    3596219    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false                       1259    3596217    easy_thumbnails_source_id_seq    SEQUENCE     �   CREATE SEQUENCE public.easy_thumbnails_source_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.easy_thumbnails_source_id_seq;
       public          taiga    false    270            �           0    0    easy_thumbnails_source_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.easy_thumbnails_source_id_seq OWNED BY public.easy_thumbnails_source.id;
          public          taiga    false    269                       1259    3596227    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false                       1259    3596225     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   CREATE SEQUENCE public.easy_thumbnails_thumbnail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.easy_thumbnails_thumbnail_id_seq;
       public          taiga    false    272            �           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.easy_thumbnails_thumbnail_id_seq OWNED BY public.easy_thumbnails_thumbnail.id;
          public          taiga    false    271                       1259    3596253 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false                       1259    3596251 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE     �   CREATE SEQUENCE public.easy_thumbnails_thumbnaildimensions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.easy_thumbnails_thumbnaildimensions_id_seq;
       public          taiga    false    274            �           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE OWNED BY     y   ALTER SEQUENCE public.easy_thumbnails_thumbnaildimensions_id_seq OWNED BY public.easy_thumbnails_thumbnaildimensions.id;
          public          taiga    false    273            �            1259    3595794 
   epics_epic    TABLE     ~  CREATE TABLE public.epics_epic (
    id bigint NOT NULL,
    tags text[],
    version integer NOT NULL,
    is_blocked boolean NOT NULL,
    blocked_note text NOT NULL,
    ref bigint,
    epics_order bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    subject text NOT NULL,
    description text NOT NULL,
    client_requirement boolean NOT NULL,
    team_requirement boolean NOT NULL,
    assigned_to_id bigint,
    owner_id bigint,
    project_id bigint NOT NULL,
    status_id bigint,
    color character varying(32) NOT NULL,
    external_reference text[]
);
    DROP TABLE public.epics_epic;
       public         heap    taiga    false                       1259    3596304    epics_epic_id_seq    SEQUENCE     z   CREATE SEQUENCE public.epics_epic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.epics_epic_id_seq;
       public          taiga    false    250            �           0    0    epics_epic_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.epics_epic_id_seq OWNED BY public.epics_epic.id;
          public          taiga    false    275            �            1259    3595805    epics_relateduserstory    TABLE     �   CREATE TABLE public.epics_relateduserstory (
    id bigint NOT NULL,
    "order" bigint NOT NULL,
    epic_id bigint NOT NULL,
    user_story_id bigint NOT NULL
);
 *   DROP TABLE public.epics_relateduserstory;
       public         heap    taiga    false                       1259    3596349    epics_relateduserstory_id_seq    SEQUENCE     �   CREATE SEQUENCE public.epics_relateduserstory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.epics_relateduserstory_id_seq;
       public          taiga    false    251            �           0    0    epics_relateduserstory_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.epics_relateduserstory_id_seq OWNED BY public.epics_relateduserstory.id;
          public          taiga    false    276                       1259    3596352    external_apps_application    TABLE     �   CREATE TABLE public.external_apps_application (
    id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    icon_url text,
    web character varying(255),
    description text,
    next_url text NOT NULL
);
 -   DROP TABLE public.external_apps_application;
       public         heap    taiga    false                       1259    3596362    external_apps_applicationtoken    TABLE     
  CREATE TABLE public.external_apps_applicationtoken (
    id bigint NOT NULL,
    auth_code character varying(255),
    token character varying(255),
    state character varying(255),
    application_id character varying(255) NOT NULL,
    user_id bigint NOT NULL
);
 2   DROP TABLE public.external_apps_applicationtoken;
       public         heap    taiga    false                       1259    3596401 %   external_apps_applicationtoken_id_seq    SEQUENCE     �   CREATE SEQUENCE public.external_apps_applicationtoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.external_apps_applicationtoken_id_seq;
       public          taiga    false    278            �           0    0 %   external_apps_applicationtoken_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.external_apps_applicationtoken_id_seq OWNED BY public.external_apps_applicationtoken.id;
          public          taiga    false    279                       1259    3596406    feedback_feedbackentry    TABLE     �   CREATE TABLE public.feedback_feedbackentry (
    id bigint NOT NULL,
    full_name character varying(256) NOT NULL,
    email character varying(255) NOT NULL,
    comment text NOT NULL,
    created_date timestamp with time zone NOT NULL
);
 *   DROP TABLE public.feedback_feedbackentry;
       public         heap    taiga    false                       1259    3596425    feedback_feedbackentry_id_seq    SEQUENCE     �   CREATE SEQUENCE public.feedback_feedbackentry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.feedback_feedbackentry_id_seq;
       public          taiga    false    280            �           0    0    feedback_feedbackentry_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.feedback_feedbackentry_id_seq OWNED BY public.feedback_feedbackentry.id;
          public          taiga    false    281            �            1259    3595756    history_historyentry    TABLE     .  CREATE TABLE public.history_historyentry (
    id character varying(255) NOT NULL,
    "user" jsonb,
    created_at timestamp with time zone,
    type smallint,
    is_snapshot boolean,
    key character varying(255),
    diff jsonb,
    snapshot jsonb,
    "values" jsonb,
    comment text,
    comment_html text,
    delete_comment_date timestamp with time zone,
    delete_comment_user jsonb,
    is_hidden boolean,
    comment_versions jsonb,
    edit_comment_date timestamp with time zone,
    project_id bigint NOT NULL,
    values_diff_cache jsonb
);
 (   DROP TABLE public.history_historyentry;
       public         heap    taiga    false            �            1259    3594874    issues_issue    TABLE     �  CREATE TABLE public.issues_issue (
    id bigint NOT NULL,
    tags text[],
    version integer NOT NULL,
    is_blocked boolean NOT NULL,
    blocked_note text NOT NULL,
    ref bigint,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    finished_date timestamp with time zone,
    subject text NOT NULL,
    description text NOT NULL,
    assigned_to_id bigint,
    milestone_id bigint,
    owner_id bigint,
    priority_id bigint,
    project_id bigint NOT NULL,
    severity_id bigint,
    status_id bigint,
    type_id bigint,
    external_reference text[],
    due_date date,
    due_date_reason text NOT NULL
);
     DROP TABLE public.issues_issue;
       public         heap    taiga    false                       1259    3596459    issues_issue_id_seq    SEQUENCE     |   CREATE SEQUENCE public.issues_issue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.issues_issue_id_seq;
       public          taiga    false    229            �           0    0    issues_issue_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.issues_issue_id_seq OWNED BY public.issues_issue.id;
          public          taiga    false    282            �            1259    3595445 
   likes_like    TABLE       CREATE TABLE public.likes_like (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    created_date timestamp with time zone NOT NULL,
    content_type_id integer NOT NULL,
    user_id bigint NOT NULL,
    CONSTRAINT likes_like_object_id_check CHECK ((object_id >= 0))
);
    DROP TABLE public.likes_like;
       public         heap    taiga    false                       1259    3596509    likes_like_id_seq    SEQUENCE     z   CREATE SEQUENCE public.likes_like_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.likes_like_id_seq;
       public          taiga    false    243            �           0    0    likes_like_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.likes_like_id_seq OWNED BY public.likes_like.id;
          public          taiga    false    283            �            1259    3594823    milestones_milestone    TABLE     &  CREATE TABLE public.milestones_milestone (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    estimated_start date NOT NULL,
    estimated_finish date NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    closed boolean NOT NULL,
    disponibility double precision,
    "order" smallint NOT NULL,
    owner_id bigint,
    project_id bigint NOT NULL,
    CONSTRAINT milestones_milestone_order_check CHECK (("order" >= 0))
);
 (   DROP TABLE public.milestones_milestone;
       public         heap    taiga    false                       1259    3596527    milestones_milestone_id_seq    SEQUENCE     �   CREATE SEQUENCE public.milestones_milestone_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.milestones_milestone_id_seq;
       public          taiga    false    228            �           0    0    milestones_milestone_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.milestones_milestone_id_seq OWNED BY public.milestones_milestone.id;
          public          taiga    false    284            �            1259    3595129 '   notifications_historychangenotification    TABLE     S  CREATE TABLE public.notifications_historychangenotification (
    id bigint NOT NULL,
    key character varying(255) NOT NULL,
    created_datetime timestamp with time zone NOT NULL,
    updated_datetime timestamp with time zone NOT NULL,
    history_type smallint NOT NULL,
    owner_id bigint NOT NULL,
    project_id bigint NOT NULL
);
 ;   DROP TABLE public.notifications_historychangenotification;
       public         heap    taiga    false            �            1259    3595137 7   notifications_historychangenotification_history_entries    TABLE     �   CREATE TABLE public.notifications_historychangenotification_history_entries (
    id bigint NOT NULL,
    historychangenotification_id bigint NOT NULL,
    historyentry_id character varying(255) NOT NULL
);
 K   DROP TABLE public.notifications_historychangenotification_history_entries;
       public         heap    taiga    false            �            1259    3595135 >   notifications_historychangenotification_history_entries_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_historychangenotification_history_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 U   DROP SEQUENCE public.notifications_historychangenotification_history_entries_id_seq;
       public          taiga    false    235            �           0    0 >   notifications_historychangenotification_history_entries_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.notifications_historychangenotification_history_entries_id_seq OWNED BY public.notifications_historychangenotification_history_entries.id;
          public          taiga    false    234                       1259    3596623 .   notifications_historychangenotification_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_historychangenotification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 E   DROP SEQUENCE public.notifications_historychangenotification_id_seq;
       public          taiga    false    233            �           0    0 .   notifications_historychangenotification_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.notifications_historychangenotification_id_seq OWNED BY public.notifications_historychangenotification.id;
          public          taiga    false    286            �            1259    3595145 4   notifications_historychangenotification_notify_users    TABLE     �   CREATE TABLE public.notifications_historychangenotification_notify_users (
    id bigint NOT NULL,
    historychangenotification_id bigint NOT NULL,
    user_id bigint NOT NULL
);
 H   DROP TABLE public.notifications_historychangenotification_notify_users;
       public         heap    taiga    false            �            1259    3595143 ;   notifications_historychangenotification_notify_users_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_historychangenotification_notify_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 R   DROP SEQUENCE public.notifications_historychangenotification_notify_users_id_seq;
       public          taiga    false    237            �           0    0 ;   notifications_historychangenotification_notify_users_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.notifications_historychangenotification_notify_users_id_seq OWNED BY public.notifications_historychangenotification_notify_users.id;
          public          taiga    false    236            �            1259    3595086    notifications_notifypolicy    TABLE     a  CREATE TABLE public.notifications_notifypolicy (
    id bigint NOT NULL,
    notify_level smallint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    user_id bigint NOT NULL,
    live_notify_level smallint NOT NULL,
    web_notify_level boolean NOT NULL
);
 .   DROP TABLE public.notifications_notifypolicy;
       public         heap    taiga    false                       1259    3596657 !   notifications_notifypolicy_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_notifypolicy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE public.notifications_notifypolicy_id_seq;
       public          taiga    false    232            �           0    0 !   notifications_notifypolicy_id_seq    SEQUENCE OWNED BY     g   ALTER SEQUENCE public.notifications_notifypolicy_id_seq OWNED BY public.notifications_notifypolicy.id;
          public          taiga    false    287            �            1259    3595196    notifications_watched    TABLE     L  CREATE TABLE public.notifications_watched (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    created_date timestamp with time zone NOT NULL,
    content_type_id integer NOT NULL,
    user_id bigint NOT NULL,
    project_id bigint NOT NULL,
    CONSTRAINT notifications_watched_object_id_check CHECK ((object_id >= 0))
);
 )   DROP TABLE public.notifications_watched;
       public         heap    taiga    false                        1259    3596671    notifications_watched_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_watched_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.notifications_watched_id_seq;
       public          taiga    false    238            �           0    0    notifications_watched_id_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.notifications_watched_id_seq OWNED BY public.notifications_watched.id;
          public          taiga    false    288                       1259    3596595    notifications_webnotification    TABLE     P  CREATE TABLE public.notifications_webnotification (
    id bigint NOT NULL,
    created timestamp with time zone NOT NULL,
    read timestamp with time zone,
    event_type integer NOT NULL,
    data jsonb NOT NULL,
    user_id bigint NOT NULL,
    CONSTRAINT notifications_webnotification_event_type_check CHECK ((event_type >= 0))
);
 1   DROP TABLE public.notifications_webnotification;
       public         heap    taiga    false            !           1259    3596686 $   notifications_webnotification_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_webnotification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.notifications_webnotification_id_seq;
       public          taiga    false    285            �           0    0 $   notifications_webnotification_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.notifications_webnotification_id_seq OWNED BY public.notifications_webnotification.id;
          public          taiga    false    289            c           1259    3599817    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    1185            b           1259    3599815    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    355            �           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    354            ^           1259    3599785    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    351            �           0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    350            a           1259    3599801    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            `           1259    3599799 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    353            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    352            �            1259    3595553    projects_epicstatus    TABLE        CREATE TABLE public.projects_epicstatus (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    "order" integer NOT NULL,
    is_closed boolean NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL
);
 '   DROP TABLE public.projects_epicstatus;
       public         heap    taiga    false            (           1259    3596833    projects_epicstatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_epicstatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.projects_epicstatus_id_seq;
       public          taiga    false    244            �           0    0    projects_epicstatus_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.projects_epicstatus_id_seq OWNED BY public.projects_epicstatus.id;
          public          taiga    false    296            #           1259    3596714    projects_issueduedate    TABLE       CREATE TABLE public.projects_issueduedate (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    by_default boolean NOT NULL,
    color character varying(20) NOT NULL,
    days_to_due integer,
    project_id bigint NOT NULL
);
 )   DROP TABLE public.projects_issueduedate;
       public         heap    taiga    false            )           1259    3596905    projects_issueduedate_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_issueduedate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.projects_issueduedate_id_seq;
       public          taiga    false    291            �           0    0    projects_issueduedate_id_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.projects_issueduedate_id_seq OWNED BY public.projects_issueduedate.id;
          public          taiga    false    297            �            1259    3594523    projects_issuestatus    TABLE     !  CREATE TABLE public.projects_issuestatus (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    is_closed boolean NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL,
    slug character varying(255) NOT NULL
);
 (   DROP TABLE public.projects_issuestatus;
       public         heap    taiga    false            *           1259    3596923    projects_issuestatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_issuestatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.projects_issuestatus_id_seq;
       public          taiga    false    212            �           0    0    projects_issuestatus_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.projects_issuestatus_id_seq OWNED BY public.projects_issuestatus.id;
          public          taiga    false    298            �            1259    3594531    projects_issuetype    TABLE     �   CREATE TABLE public.projects_issuetype (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL
);
 &   DROP TABLE public.projects_issuetype;
       public         heap    taiga    false            +           1259    3596999    projects_issuetype_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_issuetype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.projects_issuetype_id_seq;
       public          taiga    false    213            �           0    0    projects_issuetype_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.projects_issuetype_id_seq OWNED BY public.projects_issuetype.id;
          public          taiga    false    299            �            1259    3594470    projects_membership    TABLE     �  CREATE TABLE public.projects_membership (
    id bigint NOT NULL,
    is_admin boolean NOT NULL,
    email character varying(255),
    created_at timestamp with time zone NOT NULL,
    token character varying(60),
    user_id bigint,
    project_id bigint NOT NULL,
    role_id bigint NOT NULL,
    invited_by_id bigint,
    invitation_extra_text text,
    user_order bigint NOT NULL
);
 '   DROP TABLE public.projects_membership;
       public         heap    taiga    false            ,           1259    3597081    projects_membership_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_membership_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.projects_membership_id_seq;
       public          taiga    false    210            �           0    0    projects_membership_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.projects_membership_id_seq OWNED BY public.projects_membership.id;
          public          taiga    false    300            �            1259    3594539    projects_points    TABLE     �   CREATE TABLE public.projects_points (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    value double precision,
    project_id bigint NOT NULL
);
 #   DROP TABLE public.projects_points;
       public         heap    taiga    false            -           1259    3597093    projects_points_id_seq    SEQUENCE        CREATE SEQUENCE public.projects_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.projects_points_id_seq;
       public          taiga    false    214            �           0    0    projects_points_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.projects_points_id_seq OWNED BY public.projects_points.id;
          public          taiga    false    301            �            1259    3594547    projects_priority    TABLE     �   CREATE TABLE public.projects_priority (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL
);
 %   DROP TABLE public.projects_priority;
       public         heap    taiga    false            .           1259    3597161    projects_priority_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_priority_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.projects_priority_id_seq;
       public          taiga    false    215            �           0    0    projects_priority_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.projects_priority_id_seq OWNED BY public.projects_priority.id;
          public          taiga    false    302            �            1259    3594478    projects_project    TABLE     .  CREATE TABLE public.projects_project (
    id bigint NOT NULL,
    tags text[],
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    description text,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    total_milestones integer,
    total_story_points double precision,
    is_backlog_activated boolean NOT NULL,
    is_kanban_activated boolean NOT NULL,
    is_wiki_activated boolean NOT NULL,
    is_issues_activated boolean NOT NULL,
    videoconferences character varying(250),
    videoconferences_extra_data character varying(250),
    anon_permissions text[],
    public_permissions text[],
    is_private boolean NOT NULL,
    tags_colors text[],
    owner_id bigint,
    creation_template_id bigint,
    default_issue_status_id bigint,
    default_issue_type_id bigint,
    default_points_id bigint,
    default_priority_id bigint,
    default_severity_id bigint,
    default_task_status_id bigint,
    default_us_status_id bigint,
    issues_csv_uuid character varying(32),
    tasks_csv_uuid character varying(32),
    userstories_csv_uuid character varying(32),
    is_featured boolean NOT NULL,
    is_looking_for_people boolean NOT NULL,
    total_activity integer NOT NULL,
    total_activity_last_month integer NOT NULL,
    total_activity_last_week integer NOT NULL,
    total_activity_last_year integer NOT NULL,
    total_fans integer NOT NULL,
    total_fans_last_month integer NOT NULL,
    total_fans_last_week integer NOT NULL,
    total_fans_last_year integer NOT NULL,
    totals_updated_datetime timestamp with time zone NOT NULL,
    logo character varying(500),
    looking_for_people_note text NOT NULL,
    blocked_code character varying(255),
    transfer_token character varying(255),
    is_epics_activated boolean NOT NULL,
    default_epic_status_id bigint,
    epics_csv_uuid character varying(32),
    is_contact_activated boolean NOT NULL,
    default_swimlane_id bigint,
    workspace_id bigint,
    color integer NOT NULL,
    workspace_member_permissions text[],
    CONSTRAINT projects_project_total_activity_check CHECK ((total_activity >= 0)),
    CONSTRAINT projects_project_total_activity_last_month_check CHECK ((total_activity_last_month >= 0)),
    CONSTRAINT projects_project_total_activity_last_week_check CHECK ((total_activity_last_week >= 0)),
    CONSTRAINT projects_project_total_activity_last_year_check CHECK ((total_activity_last_year >= 0)),
    CONSTRAINT projects_project_total_fans_check CHECK ((total_fans >= 0)),
    CONSTRAINT projects_project_total_fans_last_month_check CHECK ((total_fans_last_month >= 0)),
    CONSTRAINT projects_project_total_fans_last_week_check CHECK ((total_fans_last_week >= 0)),
    CONSTRAINT projects_project_total_fans_last_year_check CHECK ((total_fans_last_year >= 0))
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            /           1259    3597272    projects_project_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.projects_project_id_seq;
       public          taiga    false    211            �           0    0    projects_project_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.projects_project_id_seq OWNED BY public.projects_project.id;
          public          taiga    false    303            �            1259    3595370    projects_projectmodulesconfig    TABLE     �   CREATE TABLE public.projects_projectmodulesconfig (
    id bigint NOT NULL,
    config jsonb,
    project_id bigint NOT NULL
);
 1   DROP TABLE public.projects_projectmodulesconfig;
       public         heap    taiga    false            0           1259    3597864 $   projects_projectmodulesconfig_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_projectmodulesconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.projects_projectmodulesconfig_id_seq;
       public          taiga    false    241            �           0    0 $   projects_projectmodulesconfig_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.projects_projectmodulesconfig_id_seq OWNED BY public.projects_projectmodulesconfig.id;
          public          taiga    false    304            �            1259    3594555    projects_projecttemplate    TABLE       CREATE TABLE public.projects_projecttemplate (
    id bigint NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    description text NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    is_backlog_activated boolean NOT NULL,
    is_kanban_activated boolean NOT NULL,
    is_wiki_activated boolean NOT NULL,
    is_issues_activated boolean NOT NULL,
    videoconferences character varying(250),
    videoconferences_extra_data character varying(250),
    default_options jsonb,
    us_statuses jsonb,
    points jsonb,
    task_statuses jsonb,
    issue_statuses jsonb,
    issue_types jsonb,
    priorities jsonb,
    severities jsonb,
    roles jsonb,
    "order" bigint NOT NULL,
    epic_statuses jsonb,
    is_epics_activated boolean NOT NULL,
    is_contact_activated boolean NOT NULL,
    epic_custom_attributes jsonb,
    is_looking_for_people boolean NOT NULL,
    issue_custom_attributes jsonb,
    looking_for_people_note text NOT NULL,
    tags text[],
    tags_colors text[],
    task_custom_attributes jsonb,
    us_custom_attributes jsonb,
    issue_duedates jsonb,
    task_duedates jsonb,
    us_duedates jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    taiga    false            1           1259    3597879    projects_projecttemplate_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_projecttemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.projects_projecttemplate_id_seq;
       public          taiga    false    216            �           0    0    projects_projecttemplate_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.projects_projecttemplate_id_seq OWNED BY public.projects_projecttemplate.id;
          public          taiga    false    305            �            1259    3594568    projects_severity    TABLE     �   CREATE TABLE public.projects_severity (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL
);
 %   DROP TABLE public.projects_severity;
       public         heap    taiga    false            2           1259    3597937    projects_severity_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_severity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.projects_severity_id_seq;
       public          taiga    false    217            �           0    0    projects_severity_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.projects_severity_id_seq OWNED BY public.projects_severity.id;
          public          taiga    false    306            &           1259    3596764    projects_swimlane    TABLE     �   CREATE TABLE public.projects_swimlane (
    id bigint NOT NULL,
    name text NOT NULL,
    "order" bigint NOT NULL,
    project_id bigint NOT NULL
);
 %   DROP TABLE public.projects_swimlane;
       public         heap    taiga    false            3           1259    3598016    projects_swimlane_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_swimlane_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.projects_swimlane_id_seq;
       public          taiga    false    294            �           0    0    projects_swimlane_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.projects_swimlane_id_seq OWNED BY public.projects_swimlane.id;
          public          taiga    false    307            '           1259    3596781     projects_swimlaneuserstorystatus    TABLE     �   CREATE TABLE public.projects_swimlaneuserstorystatus (
    id bigint NOT NULL,
    wip_limit integer,
    status_id bigint NOT NULL,
    swimlane_id bigint NOT NULL
);
 4   DROP TABLE public.projects_swimlaneuserstorystatus;
       public         heap    taiga    false            4           1259    3598086 '   projects_swimlaneuserstorystatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_swimlaneuserstorystatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 >   DROP SEQUENCE public.projects_swimlaneuserstorystatus_id_seq;
       public          taiga    false    295            �           0    0 '   projects_swimlaneuserstorystatus_id_seq    SEQUENCE OWNED BY     s   ALTER SEQUENCE public.projects_swimlaneuserstorystatus_id_seq OWNED BY public.projects_swimlaneuserstorystatus.id;
          public          taiga    false    308            $           1259    3596722    projects_taskduedate    TABLE       CREATE TABLE public.projects_taskduedate (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    by_default boolean NOT NULL,
    color character varying(20) NOT NULL,
    days_to_due integer,
    project_id bigint NOT NULL
);
 (   DROP TABLE public.projects_taskduedate;
       public         heap    taiga    false            5           1259    3598098    projects_taskduedate_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_taskduedate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.projects_taskduedate_id_seq;
       public          taiga    false    292            �           0    0    projects_taskduedate_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.projects_taskduedate_id_seq OWNED BY public.projects_taskduedate.id;
          public          taiga    false    309            �            1259    3594576    projects_taskstatus    TABLE        CREATE TABLE public.projects_taskstatus (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    is_closed boolean NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL,
    slug character varying(255) NOT NULL
);
 '   DROP TABLE public.projects_taskstatus;
       public         heap    taiga    false            6           1259    3598116    projects_taskstatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_taskstatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.projects_taskstatus_id_seq;
       public          taiga    false    218            �           0    0    projects_taskstatus_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.projects_taskstatus_id_seq OWNED BY public.projects_taskstatus.id;
          public          taiga    false    310            %           1259    3596730    projects_userstoryduedate    TABLE       CREATE TABLE public.projects_userstoryduedate (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    by_default boolean NOT NULL,
    color character varying(20) NOT NULL,
    days_to_due integer,
    project_id bigint NOT NULL
);
 -   DROP TABLE public.projects_userstoryduedate;
       public         heap    taiga    false            7           1259    3598190     projects_userstoryduedate_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_userstoryduedate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.projects_userstoryduedate_id_seq;
       public          taiga    false    293            �           0    0     projects_userstoryduedate_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.projects_userstoryduedate_id_seq OWNED BY public.projects_userstoryduedate.id;
          public          taiga    false    311            �            1259    3594584    projects_userstorystatus    TABLE     ^  CREATE TABLE public.projects_userstorystatus (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    is_closed boolean NOT NULL,
    color character varying(20) NOT NULL,
    wip_limit integer,
    project_id bigint NOT NULL,
    slug character varying(255) NOT NULL,
    is_archived boolean NOT NULL
);
 ,   DROP TABLE public.projects_userstorystatus;
       public         heap    taiga    false            8           1259    3598208    projects_userstorystatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_userstorystatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.projects_userstorystatus_id_seq;
       public          taiga    false    219            �           0    0    projects_userstorystatus_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.projects_userstorystatus_id_seq OWNED BY public.projects_userstorystatus.id;
          public          taiga    false    312            d           1259    3599863    references_project1    SEQUENCE     |   CREATE SEQUENCE public.references_project1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project1;
       public          taiga    false            m           1259    3599881    references_project10    SEQUENCE     }   CREATE SEQUENCE public.references_project10
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project10;
       public          taiga    false            n           1259    3599883    references_project11    SEQUENCE     }   CREATE SEQUENCE public.references_project11
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project11;
       public          taiga    false            o           1259    3599885    references_project12    SEQUENCE     }   CREATE SEQUENCE public.references_project12
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project12;
       public          taiga    false            p           1259    3599887    references_project13    SEQUENCE     }   CREATE SEQUENCE public.references_project13
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project13;
       public          taiga    false            q           1259    3599889    references_project14    SEQUENCE     }   CREATE SEQUENCE public.references_project14
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project14;
       public          taiga    false            r           1259    3599891    references_project15    SEQUENCE     }   CREATE SEQUENCE public.references_project15
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project15;
       public          taiga    false            s           1259    3599893    references_project16    SEQUENCE     }   CREATE SEQUENCE public.references_project16
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project16;
       public          taiga    false            t           1259    3599895    references_project17    SEQUENCE     }   CREATE SEQUENCE public.references_project17
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project17;
       public          taiga    false            u           1259    3599897    references_project18    SEQUENCE     }   CREATE SEQUENCE public.references_project18
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project18;
       public          taiga    false            v           1259    3599899    references_project19    SEQUENCE     }   CREATE SEQUENCE public.references_project19
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project19;
       public          taiga    false            e           1259    3599865    references_project2    SEQUENCE     |   CREATE SEQUENCE public.references_project2
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project2;
       public          taiga    false            w           1259    3599901    references_project20    SEQUENCE     }   CREATE SEQUENCE public.references_project20
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project20;
       public          taiga    false            x           1259    3599903    references_project21    SEQUENCE     }   CREATE SEQUENCE public.references_project21
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project21;
       public          taiga    false            y           1259    3599905    references_project22    SEQUENCE     }   CREATE SEQUENCE public.references_project22
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project22;
       public          taiga    false            z           1259    3599907    references_project23    SEQUENCE     }   CREATE SEQUENCE public.references_project23
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project23;
       public          taiga    false            {           1259    3599909    references_project24    SEQUENCE     }   CREATE SEQUENCE public.references_project24
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project24;
       public          taiga    false            |           1259    3599911    references_project25    SEQUENCE     }   CREATE SEQUENCE public.references_project25
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project25;
       public          taiga    false            }           1259    3599913    references_project26    SEQUENCE     }   CREATE SEQUENCE public.references_project26
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project26;
       public          taiga    false            ~           1259    3599915    references_project27    SEQUENCE     }   CREATE SEQUENCE public.references_project27
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project27;
       public          taiga    false                       1259    3599917    references_project28    SEQUENCE     }   CREATE SEQUENCE public.references_project28
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project28;
       public          taiga    false            �           1259    3599919    references_project29    SEQUENCE     }   CREATE SEQUENCE public.references_project29
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project29;
       public          taiga    false            f           1259    3599867    references_project3    SEQUENCE     |   CREATE SEQUENCE public.references_project3
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project3;
       public          taiga    false            �           1259    3599921    references_project30    SEQUENCE     }   CREATE SEQUENCE public.references_project30
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project30;
       public          taiga    false            �           1259    3599923    references_project31    SEQUENCE     }   CREATE SEQUENCE public.references_project31
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project31;
       public          taiga    false            �           1259    3599925    references_project32    SEQUENCE     }   CREATE SEQUENCE public.references_project32
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project32;
       public          taiga    false            �           1259    3599927    references_project33    SEQUENCE     }   CREATE SEQUENCE public.references_project33
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project33;
       public          taiga    false            �           1259    3599929    references_project34    SEQUENCE     }   CREATE SEQUENCE public.references_project34
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project34;
       public          taiga    false            �           1259    3599931    references_project35    SEQUENCE     }   CREATE SEQUENCE public.references_project35
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project35;
       public          taiga    false            �           1259    3599933    references_project36    SEQUENCE     }   CREATE SEQUENCE public.references_project36
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project36;
       public          taiga    false            �           1259    3599935    references_project37    SEQUENCE     }   CREATE SEQUENCE public.references_project37
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project37;
       public          taiga    false            �           1259    3599937    references_project38    SEQUENCE     }   CREATE SEQUENCE public.references_project38
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project38;
       public          taiga    false            �           1259    3599939    references_project39    SEQUENCE     }   CREATE SEQUENCE public.references_project39
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project39;
       public          taiga    false            g           1259    3599869    references_project4    SEQUENCE     |   CREATE SEQUENCE public.references_project4
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project4;
       public          taiga    false            �           1259    3599941    references_project40    SEQUENCE     }   CREATE SEQUENCE public.references_project40
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project40;
       public          taiga    false            �           1259    3599943    references_project41    SEQUENCE     }   CREATE SEQUENCE public.references_project41
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project41;
       public          taiga    false            �           1259    3599945    references_project42    SEQUENCE     }   CREATE SEQUENCE public.references_project42
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project42;
       public          taiga    false            �           1259    3599947    references_project43    SEQUENCE     }   CREATE SEQUENCE public.references_project43
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project43;
       public          taiga    false            �           1259    3599949    references_project44    SEQUENCE     }   CREATE SEQUENCE public.references_project44
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project44;
       public          taiga    false            �           1259    3599951    references_project45    SEQUENCE     }   CREATE SEQUENCE public.references_project45
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project45;
       public          taiga    false            h           1259    3599871    references_project5    SEQUENCE     |   CREATE SEQUENCE public.references_project5
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project5;
       public          taiga    false            i           1259    3599873    references_project6    SEQUENCE     |   CREATE SEQUENCE public.references_project6
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project6;
       public          taiga    false            j           1259    3599875    references_project7    SEQUENCE     |   CREATE SEQUENCE public.references_project7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project7;
       public          taiga    false            k           1259    3599877    references_project8    SEQUENCE     |   CREATE SEQUENCE public.references_project8
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project8;
       public          taiga    false            l           1259    3599879    references_project9    SEQUENCE     |   CREATE SEQUENCE public.references_project9
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project9;
       public          taiga    false            9           1259    3598290    references_reference    TABLE     D  CREATE TABLE public.references_reference (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    ref bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    content_type_id integer NOT NULL,
    project_id bigint NOT NULL,
    CONSTRAINT references_reference_object_id_check CHECK ((object_id >= 0))
);
 (   DROP TABLE public.references_reference;
       public         heap    taiga    false            :           1259    3598321    references_reference_id_seq    SEQUENCE     �   CREATE SEQUENCE public.references_reference_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.references_reference_id_seq;
       public          taiga    false    313            �           0    0    references_reference_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.references_reference_id_seq OWNED BY public.references_reference.id;
          public          taiga    false    314            <           1259    3598336    settings_userprojectsettings    TABLE       CREATE TABLE public.settings_userprojectsettings (
    id bigint NOT NULL,
    homepage smallint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    user_id bigint NOT NULL
);
 0   DROP TABLE public.settings_userprojectsettings;
       public         heap    taiga    false            =           1259    3598366 #   settings_userprojectsettings_id_seq    SEQUENCE     �   CREATE SEQUENCE public.settings_userprojectsettings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.settings_userprojectsettings_id_seq;
       public          taiga    false    316            �           0    0 #   settings_userprojectsettings_id_seq    SEQUENCE OWNED BY     k   ALTER SEQUENCE public.settings_userprojectsettings_id_seq OWNED BY public.settings_userprojectsettings.id;
          public          taiga    false    317            �            1259    3595225 
   tasks_task    TABLE     �  CREATE TABLE public.tasks_task (
    id bigint NOT NULL,
    tags text[],
    version integer NOT NULL,
    is_blocked boolean NOT NULL,
    blocked_note text NOT NULL,
    ref bigint,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    finished_date timestamp with time zone,
    subject text NOT NULL,
    description text NOT NULL,
    is_iocaine boolean NOT NULL,
    assigned_to_id bigint,
    milestone_id bigint,
    owner_id bigint,
    project_id bigint NOT NULL,
    status_id bigint,
    user_story_id bigint,
    taskboard_order bigint NOT NULL,
    us_order bigint NOT NULL,
    external_reference text[],
    due_date date,
    due_date_reason text NOT NULL
);
    DROP TABLE public.tasks_task;
       public         heap    taiga    false            >           1259    3598415    tasks_task_id_seq    SEQUENCE     z   CREATE SEQUENCE public.tasks_task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.tasks_task_id_seq;
       public          taiga    false    239            �           0    0    tasks_task_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.tasks_task_id_seq OWNED BY public.tasks_task.id;
          public          taiga    false    318            ?           1259    3598437    telemetry_instancetelemetry    TABLE     �   CREATE TABLE public.telemetry_instancetelemetry (
    id bigint NOT NULL,
    instance_id character varying(100) NOT NULL,
    created_at timestamp with time zone NOT NULL
);
 /   DROP TABLE public.telemetry_instancetelemetry;
       public         heap    taiga    false            @           1259    3598450 "   telemetry_instancetelemetry_id_seq    SEQUENCE     �   CREATE SEQUENCE public.telemetry_instancetelemetry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.telemetry_instancetelemetry_id_seq;
       public          taiga    false    319            �           0    0 "   telemetry_instancetelemetry_id_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public.telemetry_instancetelemetry_id_seq OWNED BY public.telemetry_instancetelemetry.id;
          public          taiga    false    320            �            1259    3595395    timeline_timeline    TABLE     �  CREATE TABLE public.timeline_timeline (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    namespace character varying(250) NOT NULL,
    event_type character varying(250) NOT NULL,
    project_id bigint,
    data jsonb NOT NULL,
    data_content_type_id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    content_type_id integer NOT NULL,
    CONSTRAINT timeline_timeline_object_id_check CHECK ((object_id >= 0))
);
 %   DROP TABLE public.timeline_timeline;
       public         heap    taiga    false            A           1259    3598493    timeline_timeline_id_seq    SEQUENCE     �   CREATE SEQUENCE public.timeline_timeline_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.timeline_timeline_id_seq;
       public          taiga    false    242            �           0    0    timeline_timeline_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.timeline_timeline_id_seq OWNED BY public.timeline_timeline.id;
          public          taiga    false    321            E           1259    3598511    token_denylist_denylistedtoken    TABLE     �   CREATE TABLE public.token_denylist_denylistedtoken (
    id bigint NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id bigint NOT NULL
);
 2   DROP TABLE public.token_denylist_denylistedtoken;
       public         heap    taiga    false            D           1259    3598509 %   token_denylist_denylistedtoken_id_seq    SEQUENCE     �   CREATE SEQUENCE public.token_denylist_denylistedtoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.token_denylist_denylistedtoken_id_seq;
       public          taiga    false    325            �           0    0 %   token_denylist_denylistedtoken_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.token_denylist_denylistedtoken_id_seq OWNED BY public.token_denylist_denylistedtoken.id;
          public          taiga    false    324            C           1259    3598498    token_denylist_outstandingtoken    TABLE       CREATE TABLE public.token_denylist_outstandingtoken (
    id bigint NOT NULL,
    jti character varying(255) NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    user_id bigint
);
 3   DROP TABLE public.token_denylist_outstandingtoken;
       public         heap    taiga    false            B           1259    3598496 &   token_denylist_outstandingtoken_id_seq    SEQUENCE     �   CREATE SEQUENCE public.token_denylist_outstandingtoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.token_denylist_outstandingtoken_id_seq;
       public          taiga    false    323            �           0    0 &   token_denylist_outstandingtoken_id_seq    SEQUENCE OWNED BY     q   ALTER SEQUENCE public.token_denylist_outstandingtoken_id_seq OWNED BY public.token_denylist_outstandingtoken.id;
          public          taiga    false    322            �            1259    3595302    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id bigint NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb NOT NULL,
    user_id bigint NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            G           1259    3598588    users_authdata_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.users_authdata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.users_authdata_id_seq;
       public          taiga    false    240            �           0    0    users_authdata_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE public.users_authdata_id_seq OWNED BY public.users_authdata.id;
          public          taiga    false    327            �            1259    3594457 
   users_role    TABLE       CREATE TABLE public.users_role (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" integer NOT NULL,
    computable boolean NOT NULL,
    project_id bigint,
    is_admin boolean NOT NULL
);
    DROP TABLE public.users_role;
       public         heap    taiga    false            H           1259    3598605    users_role_id_seq    SEQUENCE     z   CREATE SEQUENCE public.users_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.users_role_id_seq;
       public          taiga    false    209            �           0    0    users_role_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.users_role_id_seq OWNED BY public.users_role.id;
          public          taiga    false    328            �            1259    3594419 
   users_user    TABLE     �  CREATE TABLE public.users_user (
    id bigint NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    full_name character varying(256) NOT NULL,
    color character varying(9) NOT NULL,
    bio text NOT NULL,
    photo character varying(500),
    date_joined timestamp with time zone NOT NULL,
    lang character varying(20),
    timezone character varying(20),
    colorize_tags boolean NOT NULL,
    token character varying(200),
    email_token character varying(200),
    new_email character varying(254),
    is_system boolean NOT NULL,
    theme character varying(100),
    max_private_projects integer,
    max_public_projects integer,
    max_memberships_private_projects integer,
    max_memberships_public_projects integer,
    uuid character varying(32) NOT NULL,
    accepted_terms boolean NOT NULL,
    read_new_terms boolean NOT NULL,
    verified_email boolean NOT NULL,
    is_staff boolean NOT NULL,
    date_cancelled timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            I           1259    3598660    users_user_id_seq    SEQUENCE     z   CREATE SEQUENCE public.users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.users_user_id_seq;
       public          taiga    false    206            �           0    0    users_user_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users_user.id;
          public          taiga    false    329            F           1259    3598555    users_workspacerole    TABLE       CREATE TABLE public.users_workspacerole (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" integer NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id bigint NOT NULL
);
 '   DROP TABLE public.users_workspacerole;
       public         heap    taiga    false            J           1259    3599181    users_workspacerole_id_seq    SEQUENCE     �   CREATE SEQUENCE public.users_workspacerole_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.users_workspacerole_id_seq;
       public          taiga    false    326            �           0    0    users_workspacerole_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.users_workspacerole_id_seq OWNED BY public.users_workspacerole.id;
          public          taiga    false    330            K           1259    3599186    userstorage_storageentry    TABLE     
  CREATE TABLE public.userstorage_storageentry (
    id bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    key character varying(255) NOT NULL,
    value jsonb,
    owner_id bigint NOT NULL
);
 ,   DROP TABLE public.userstorage_storageentry;
       public         heap    taiga    false            L           1259    3599224    userstorage_storageentry_id_seq    SEQUENCE     �   CREATE SEQUENCE public.userstorage_storageentry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.userstorage_storageentry_id_seq;
       public          taiga    false    331            �           0    0    userstorage_storageentry_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.userstorage_storageentry_id_seq OWNED BY public.userstorage_storageentry.id;
          public          taiga    false    332            �            1259    3594956    userstories_rolepoints    TABLE     �   CREATE TABLE public.userstories_rolepoints (
    id bigint NOT NULL,
    points_id bigint,
    role_id bigint NOT NULL,
    user_story_id bigint NOT NULL
);
 *   DROP TABLE public.userstories_rolepoints;
       public         heap    taiga    false            O           1259    3599315    userstories_rolepoints_id_seq    SEQUENCE     �   CREATE SEQUENCE public.userstories_rolepoints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.userstories_rolepoints_id_seq;
       public          taiga    false    230            �           0    0    userstories_rolepoints_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.userstories_rolepoints_id_seq OWNED BY public.userstories_rolepoints.id;
          public          taiga    false    335            �            1259    3594964    userstories_userstory    TABLE     �  CREATE TABLE public.userstories_userstory (
    id bigint NOT NULL,
    tags text[],
    version integer NOT NULL,
    is_blocked boolean NOT NULL,
    blocked_note text NOT NULL,
    ref bigint,
    is_closed boolean NOT NULL,
    backlog_order bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    finish_date timestamp with time zone,
    subject text NOT NULL,
    description text NOT NULL,
    client_requirement boolean NOT NULL,
    team_requirement boolean NOT NULL,
    assigned_to_id bigint,
    generated_from_issue_id bigint,
    milestone_id bigint,
    owner_id bigint,
    project_id bigint NOT NULL,
    status_id bigint,
    sprint_order bigint NOT NULL,
    kanban_order bigint NOT NULL,
    external_reference text[],
    tribe_gig text,
    due_date date,
    due_date_reason text NOT NULL,
    generated_from_task_id bigint,
    from_task_ref text,
    swimlane_id bigint
);
 )   DROP TABLE public.userstories_userstory;
       public         heap    taiga    false            N           1259    3599272 $   userstories_userstory_assigned_users    TABLE     �   CREATE TABLE public.userstories_userstory_assigned_users (
    id bigint NOT NULL,
    userstory_id bigint NOT NULL,
    user_id bigint NOT NULL
);
 8   DROP TABLE public.userstories_userstory_assigned_users;
       public         heap    taiga    false            M           1259    3599270 +   userstories_userstory_assigned_users_id_seq    SEQUENCE     �   CREATE SEQUENCE public.userstories_userstory_assigned_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 B   DROP SEQUENCE public.userstories_userstory_assigned_users_id_seq;
       public          taiga    false    334            �           0    0 +   userstories_userstory_assigned_users_id_seq    SEQUENCE OWNED BY     {   ALTER SEQUENCE public.userstories_userstory_assigned_users_id_seq OWNED BY public.userstories_userstory_assigned_users.id;
          public          taiga    false    333            P           1259    3599337    userstories_userstory_id_seq    SEQUENCE     �   CREATE SEQUENCE public.userstories_userstory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.userstories_userstory_id_seq;
       public          taiga    false    231            �           0    0    userstories_userstory_id_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.userstories_userstory_id_seq OWNED BY public.userstories_userstory.id;
          public          taiga    false    336            Q           1259    3599420 
   votes_vote    TABLE       CREATE TABLE public.votes_vote (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    content_type_id integer NOT NULL,
    user_id bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    CONSTRAINT votes_vote_object_id_check CHECK ((object_id >= 0))
);
    DROP TABLE public.votes_vote;
       public         heap    taiga    false            S           1259    3599470    votes_vote_id_seq    SEQUENCE     z   CREATE SEQUENCE public.votes_vote_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.votes_vote_id_seq;
       public          taiga    false    337            �           0    0    votes_vote_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.votes_vote_id_seq OWNED BY public.votes_vote.id;
          public          taiga    false    339            R           1259    3599429    votes_votes    TABLE        CREATE TABLE public.votes_votes (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    count integer NOT NULL,
    content_type_id integer NOT NULL,
    CONSTRAINT votes_votes_count_check CHECK ((count >= 0)),
    CONSTRAINT votes_votes_object_id_check CHECK ((object_id >= 0))
);
    DROP TABLE public.votes_votes;
       public         heap    taiga    false            T           1259    3599482    votes_votes_id_seq    SEQUENCE     {   CREATE SEQUENCE public.votes_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.votes_votes_id_seq;
       public          taiga    false    338            �           0    0    votes_votes_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.votes_votes_id_seq OWNED BY public.votes_votes.id;
          public          taiga    false    340            U           1259    3599487    webhooks_webhook    TABLE     �   CREATE TABLE public.webhooks_webhook (
    id bigint NOT NULL,
    url character varying(200) NOT NULL,
    key text NOT NULL,
    project_id bigint NOT NULL,
    name character varying(250) NOT NULL
);
 $   DROP TABLE public.webhooks_webhook;
       public         heap    taiga    false            W           1259    3599543    webhooks_webhook_id_seq    SEQUENCE     �   CREATE SEQUENCE public.webhooks_webhook_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.webhooks_webhook_id_seq;
       public          taiga    false    341            �           0    0    webhooks_webhook_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.webhooks_webhook_id_seq OWNED BY public.webhooks_webhook.id;
          public          taiga    false    343            V           1259    3599498    webhooks_webhooklog    TABLE     �  CREATE TABLE public.webhooks_webhooklog (
    id bigint NOT NULL,
    url character varying(200) NOT NULL,
    status integer NOT NULL,
    request_data jsonb NOT NULL,
    response_data text NOT NULL,
    webhook_id bigint NOT NULL,
    created timestamp with time zone NOT NULL,
    duration double precision NOT NULL,
    request_headers jsonb NOT NULL,
    response_headers jsonb NOT NULL
);
 '   DROP TABLE public.webhooks_webhooklog;
       public         heap    taiga    false            X           1259    3599571    webhooks_webhooklog_id_seq    SEQUENCE     �   CREATE SEQUENCE public.webhooks_webhooklog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.webhooks_webhooklog_id_seq;
       public          taiga    false    342            �           0    0    webhooks_webhooklog_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.webhooks_webhooklog_id_seq OWNED BY public.webhooks_webhooklog.id;
          public          taiga    false    344            �            1259    3595665    wiki_wikilink    TABLE     �   CREATE TABLE public.wiki_wikilink (
    id bigint NOT NULL,
    title character varying(500) NOT NULL,
    href character varying(500) NOT NULL,
    "order" bigint NOT NULL,
    project_id bigint NOT NULL
);
 !   DROP TABLE public.wiki_wikilink;
       public         heap    taiga    false            Y           1259    3599599    wiki_wikilink_id_seq    SEQUENCE     }   CREATE SEQUENCE public.wiki_wikilink_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.wiki_wikilink_id_seq;
       public          taiga    false    247            �           0    0    wiki_wikilink_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.wiki_wikilink_id_seq OWNED BY public.wiki_wikilink.id;
          public          taiga    false    345            �            1259    3595677    wiki_wikipage    TABLE     \  CREATE TABLE public.wiki_wikipage (
    id bigint NOT NULL,
    version integer NOT NULL,
    slug character varying(500) NOT NULL,
    content text NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    last_modifier_id bigint,
    owner_id bigint,
    project_id bigint NOT NULL
);
 !   DROP TABLE public.wiki_wikipage;
       public         heap    taiga    false            Z           1259    3599618    wiki_wikipage_id_seq    SEQUENCE     }   CREATE SEQUENCE public.wiki_wikipage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.wiki_wikipage_id_seq;
       public          taiga    false    248            �           0    0    wiki_wikipage_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.wiki_wikipage_id_seq OWNED BY public.wiki_wikipage.id;
          public          taiga    false    346            "           1259    3596691    workspaces_workspace    TABLE     S  CREATE TABLE public.workspaces_workspace (
    id bigint NOT NULL,
    name character varying(40) NOT NULL,
    slug character varying(250),
    color integer NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    owner_id bigint NOT NULL,
    is_premium boolean NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false            \           1259    3599662    workspaces_workspace_id_seq    SEQUENCE     �   CREATE SEQUENCE public.workspaces_workspace_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.workspaces_workspace_id_seq;
       public          taiga    false    290            �           0    0    workspaces_workspace_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.workspaces_workspace_id_seq OWNED BY public.workspaces_workspace.id;
          public          taiga    false    348            [           1259    3599623    workspaces_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_workspacemembership (
    id bigint NOT NULL,
    user_id bigint,
    workspace_id bigint NOT NULL,
    workspace_role_id bigint NOT NULL
);
 2   DROP TABLE public.workspaces_workspacemembership;
       public         heap    taiga    false            ]           1259    3599757 %   workspaces_workspacemembership_id_seq    SEQUENCE     �   CREATE SEQUENCE public.workspaces_workspacemembership_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.workspaces_workspacemembership_id_seq;
       public          taiga    false    347            �           0    0 %   workspaces_workspacemembership_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.workspaces_workspacemembership_id_seq OWNED BY public.workspaces_workspacemembership.id;
          public          taiga    false    349            `           2604    3594752    attachments_attachment id    DEFAULT     �   ALTER TABLE ONLY public.attachments_attachment ALTER COLUMN id SET DEFAULT nextval('public.attachments_attachment_id_seq'::regclass);
 H   ALTER TABLE public.attachments_attachment ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    221    220            c           2604    3594766    auth_group id    DEFAULT     n   ALTER TABLE ONLY public.auth_group ALTER COLUMN id SET DEFAULT nextval('public.auth_group_id_seq'::regclass);
 <   ALTER TABLE public.auth_group ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    225    224    225            d           2604    3594776    auth_group_permissions id    DEFAULT     �   ALTER TABLE ONLY public.auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('public.auth_group_permissions_id_seq'::regclass);
 H   ALTER TABLE public.auth_group_permissions ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    226    227    227            b           2604    3594758    auth_permission id    DEFAULT     x   ALTER TABLE ONLY public.auth_permission ALTER COLUMN id SET DEFAULT nextval('public.auth_permission_id_seq'::regclass);
 A   ALTER TABLE public.auth_permission ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    222    223    223            x           2604    3595662    contact_contactentry id    DEFAULT     �   ALTER TABLE ONLY public.contact_contactentry ALTER COLUMN id SET DEFAULT nextval('public.contact_contactentry_id_seq'::regclass);
 F   ALTER TABLE public.contact_contactentry ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    246    245            �           2604    3596102 (   custom_attributes_epiccustomattribute id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_epiccustomattribute_id_seq'::regclass);
 W   ALTER TABLE public.custom_attributes_epiccustomattribute ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    260    258            �           2604    3596117 /   custom_attributes_epiccustomattributesvalues id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_epiccustomattributesvalues_id_seq'::regclass);
 ^   ALTER TABLE public.custom_attributes_epiccustomattributesvalues ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    261    259            }           2604    3596132 )   custom_attributes_issuecustomattribute id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_issuecustomattribute_id_seq'::regclass);
 X   ALTER TABLE public.custom_attributes_issuecustomattribute ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    262    252            �           2604    3596147 0   custom_attributes_issuecustomattributesvalues id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_issuecustomattributesvalues_id_seq'::regclass);
 _   ALTER TABLE public.custom_attributes_issuecustomattributesvalues ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    263    255            ~           2604    3596162 (   custom_attributes_taskcustomattribute id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_taskcustomattribute_id_seq'::regclass);
 W   ALTER TABLE public.custom_attributes_taskcustomattribute ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    264    253            �           2604    3596177 /   custom_attributes_taskcustomattributesvalues id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_taskcustomattributesvalues_id_seq'::regclass);
 ^   ALTER TABLE public.custom_attributes_taskcustomattributesvalues ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    265    256                       2604    3596192 -   custom_attributes_userstorycustomattribute id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_userstorycustomattribute_id_seq'::regclass);
 \   ALTER TABLE public.custom_attributes_userstorycustomattribute ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    266    254            �           2604    3596207 4   custom_attributes_userstorycustomattributesvalues id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_userstorycustomattributesvalues_id_seq'::regclass);
 c   ALTER TABLE public.custom_attributes_userstorycustomattributesvalues ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    267    257            K           2604    3594436    django_admin_log id    DEFAULT     z   ALTER TABLE ONLY public.django_admin_log ALTER COLUMN id SET DEFAULT nextval('public.django_admin_log_id_seq'::regclass);
 B   ALTER TABLE public.django_admin_log ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    207    208    208            I           2604    3594412    django_content_type id    DEFAULT     �   ALTER TABLE ONLY public.django_content_type ALTER COLUMN id SET DEFAULT nextval('public.django_content_type_id_seq'::regclass);
 E   ALTER TABLE public.django_content_type ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    205    204    205            H           2604    3594401    django_migrations id    DEFAULT     |   ALTER TABLE ONLY public.django_migrations ALTER COLUMN id SET DEFAULT nextval('public.django_migrations_id_seq'::regclass);
 C   ALTER TABLE public.django_migrations ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    202    203    203            �           2604    3596222    easy_thumbnails_source id    DEFAULT     �   ALTER TABLE ONLY public.easy_thumbnails_source ALTER COLUMN id SET DEFAULT nextval('public.easy_thumbnails_source_id_seq'::regclass);
 H   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    270    269    270            �           2604    3596230    easy_thumbnails_thumbnail id    DEFAULT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail ALTER COLUMN id SET DEFAULT nextval('public.easy_thumbnails_thumbnail_id_seq'::regclass);
 K   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    272    271    272            �           2604    3596256 &   easy_thumbnails_thumbnaildimensions id    DEFAULT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id SET DEFAULT nextval('public.easy_thumbnails_thumbnaildimensions_id_seq'::regclass);
 U   ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    274    273    274            {           2604    3596306    epics_epic id    DEFAULT     n   ALTER TABLE ONLY public.epics_epic ALTER COLUMN id SET DEFAULT nextval('public.epics_epic_id_seq'::regclass);
 <   ALTER TABLE public.epics_epic ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    275    250            |           2604    3596351    epics_relateduserstory id    DEFAULT     �   ALTER TABLE ONLY public.epics_relateduserstory ALTER COLUMN id SET DEFAULT nextval('public.epics_relateduserstory_id_seq'::regclass);
 H   ALTER TABLE public.epics_relateduserstory ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    276    251            �           2604    3596403 !   external_apps_applicationtoken id    DEFAULT     �   ALTER TABLE ONLY public.external_apps_applicationtoken ALTER COLUMN id SET DEFAULT nextval('public.external_apps_applicationtoken_id_seq'::regclass);
 P   ALTER TABLE public.external_apps_applicationtoken ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    279    278            �           2604    3596427    feedback_feedbackentry id    DEFAULT     �   ALTER TABLE ONLY public.feedback_feedbackentry ALTER COLUMN id SET DEFAULT nextval('public.feedback_feedbackentry_id_seq'::regclass);
 H   ALTER TABLE public.feedback_feedbackentry ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    281    280            g           2604    3596461    issues_issue id    DEFAULT     r   ALTER TABLE ONLY public.issues_issue ALTER COLUMN id SET DEFAULT nextval('public.issues_issue_id_seq'::regclass);
 >   ALTER TABLE public.issues_issue ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    282    229            u           2604    3596511    likes_like id    DEFAULT     n   ALTER TABLE ONLY public.likes_like ALTER COLUMN id SET DEFAULT nextval('public.likes_like_id_seq'::regclass);
 <   ALTER TABLE public.likes_like ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    283    243            e           2604    3596529    milestones_milestone id    DEFAULT     �   ALTER TABLE ONLY public.milestones_milestone ALTER COLUMN id SET DEFAULT nextval('public.milestones_milestone_id_seq'::regclass);
 F   ALTER TABLE public.milestones_milestone ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    284    228            k           2604    3596625 *   notifications_historychangenotification id    DEFAULT     �   ALTER TABLE ONLY public.notifications_historychangenotification ALTER COLUMN id SET DEFAULT nextval('public.notifications_historychangenotification_id_seq'::regclass);
 Y   ALTER TABLE public.notifications_historychangenotification ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    286    233            l           2604    3595140 :   notifications_historychangenotification_history_entries id    DEFAULT     �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries ALTER COLUMN id SET DEFAULT nextval('public.notifications_historychangenotification_history_entries_id_seq'::regclass);
 i   ALTER TABLE public.notifications_historychangenotification_history_entries ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    234    235    235            m           2604    3595148 7   notifications_historychangenotification_notify_users id    DEFAULT     �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users ALTER COLUMN id SET DEFAULT nextval('public.notifications_historychangenotification_notify_users_id_seq'::regclass);
 f   ALTER TABLE public.notifications_historychangenotification_notify_users ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    236    237    237            j           2604    3596659    notifications_notifypolicy id    DEFAULT     �   ALTER TABLE ONLY public.notifications_notifypolicy ALTER COLUMN id SET DEFAULT nextval('public.notifications_notifypolicy_id_seq'::regclass);
 L   ALTER TABLE public.notifications_notifypolicy ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    287    232            n           2604    3596673    notifications_watched id    DEFAULT     �   ALTER TABLE ONLY public.notifications_watched ALTER COLUMN id SET DEFAULT nextval('public.notifications_watched_id_seq'::regclass);
 G   ALTER TABLE public.notifications_watched ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    288    238            �           2604    3596688     notifications_webnotification id    DEFAULT     �   ALTER TABLE ONLY public.notifications_webnotification ALTER COLUMN id SET DEFAULT nextval('public.notifications_webnotification_id_seq'::regclass);
 O   ALTER TABLE public.notifications_webnotification ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    289    285            �           2604    3599820    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    354    355    355            �           2604    3599790    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    350    351    351            �           2604    3599804     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    353    352    353            w           2604    3596835    projects_epicstatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_epicstatus ALTER COLUMN id SET DEFAULT nextval('public.projects_epicstatus_id_seq'::regclass);
 E   ALTER TABLE public.projects_epicstatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    296    244            �           2604    3596907    projects_issueduedate id    DEFAULT     �   ALTER TABLE ONLY public.projects_issueduedate ALTER COLUMN id SET DEFAULT nextval('public.projects_issueduedate_id_seq'::regclass);
 G   ALTER TABLE public.projects_issueduedate ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    297    291            X           2604    3596925    projects_issuestatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_issuestatus ALTER COLUMN id SET DEFAULT nextval('public.projects_issuestatus_id_seq'::regclass);
 F   ALTER TABLE public.projects_issuestatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    298    212            Y           2604    3597001    projects_issuetype id    DEFAULT     ~   ALTER TABLE ONLY public.projects_issuetype ALTER COLUMN id SET DEFAULT nextval('public.projects_issuetype_id_seq'::regclass);
 D   ALTER TABLE public.projects_issuetype ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    299    213            N           2604    3597083    projects_membership id    DEFAULT     �   ALTER TABLE ONLY public.projects_membership ALTER COLUMN id SET DEFAULT nextval('public.projects_membership_id_seq'::regclass);
 E   ALTER TABLE public.projects_membership ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    300    210            Z           2604    3597095    projects_points id    DEFAULT     x   ALTER TABLE ONLY public.projects_points ALTER COLUMN id SET DEFAULT nextval('public.projects_points_id_seq'::regclass);
 A   ALTER TABLE public.projects_points ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    301    214            [           2604    3597163    projects_priority id    DEFAULT     |   ALTER TABLE ONLY public.projects_priority ALTER COLUMN id SET DEFAULT nextval('public.projects_priority_id_seq'::regclass);
 C   ALTER TABLE public.projects_priority ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    302    215            O           2604    3597274    projects_project id    DEFAULT     z   ALTER TABLE ONLY public.projects_project ALTER COLUMN id SET DEFAULT nextval('public.projects_project_id_seq'::regclass);
 B   ALTER TABLE public.projects_project ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    303    211            r           2604    3597866     projects_projectmodulesconfig id    DEFAULT     �   ALTER TABLE ONLY public.projects_projectmodulesconfig ALTER COLUMN id SET DEFAULT nextval('public.projects_projectmodulesconfig_id_seq'::regclass);
 O   ALTER TABLE public.projects_projectmodulesconfig ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    304    241            \           2604    3597881    projects_projecttemplate id    DEFAULT     �   ALTER TABLE ONLY public.projects_projecttemplate ALTER COLUMN id SET DEFAULT nextval('public.projects_projecttemplate_id_seq'::regclass);
 J   ALTER TABLE public.projects_projecttemplate ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    305    216            ]           2604    3597939    projects_severity id    DEFAULT     |   ALTER TABLE ONLY public.projects_severity ALTER COLUMN id SET DEFAULT nextval('public.projects_severity_id_seq'::regclass);
 C   ALTER TABLE public.projects_severity ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    306    217            �           2604    3598018    projects_swimlane id    DEFAULT     |   ALTER TABLE ONLY public.projects_swimlane ALTER COLUMN id SET DEFAULT nextval('public.projects_swimlane_id_seq'::regclass);
 C   ALTER TABLE public.projects_swimlane ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    307    294            �           2604    3598088 #   projects_swimlaneuserstorystatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus ALTER COLUMN id SET DEFAULT nextval('public.projects_swimlaneuserstorystatus_id_seq'::regclass);
 R   ALTER TABLE public.projects_swimlaneuserstorystatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    308    295            �           2604    3598100    projects_taskduedate id    DEFAULT     �   ALTER TABLE ONLY public.projects_taskduedate ALTER COLUMN id SET DEFAULT nextval('public.projects_taskduedate_id_seq'::regclass);
 F   ALTER TABLE public.projects_taskduedate ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    309    292            ^           2604    3598118    projects_taskstatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_taskstatus ALTER COLUMN id SET DEFAULT nextval('public.projects_taskstatus_id_seq'::regclass);
 E   ALTER TABLE public.projects_taskstatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    310    218            �           2604    3598192    projects_userstoryduedate id    DEFAULT     �   ALTER TABLE ONLY public.projects_userstoryduedate ALTER COLUMN id SET DEFAULT nextval('public.projects_userstoryduedate_id_seq'::regclass);
 K   ALTER TABLE public.projects_userstoryduedate ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    311    293            _           2604    3598210    projects_userstorystatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_userstorystatus ALTER COLUMN id SET DEFAULT nextval('public.projects_userstorystatus_id_seq'::regclass);
 J   ALTER TABLE public.projects_userstorystatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    312    219            �           2604    3598323    references_reference id    DEFAULT     �   ALTER TABLE ONLY public.references_reference ALTER COLUMN id SET DEFAULT nextval('public.references_reference_id_seq'::regclass);
 F   ALTER TABLE public.references_reference ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    314    313            �           2604    3598368    settings_userprojectsettings id    DEFAULT     �   ALTER TABLE ONLY public.settings_userprojectsettings ALTER COLUMN id SET DEFAULT nextval('public.settings_userprojectsettings_id_seq'::regclass);
 N   ALTER TABLE public.settings_userprojectsettings ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    317    316            p           2604    3598417    tasks_task id    DEFAULT     n   ALTER TABLE ONLY public.tasks_task ALTER COLUMN id SET DEFAULT nextval('public.tasks_task_id_seq'::regclass);
 <   ALTER TABLE public.tasks_task ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    318    239            �           2604    3598452    telemetry_instancetelemetry id    DEFAULT     �   ALTER TABLE ONLY public.telemetry_instancetelemetry ALTER COLUMN id SET DEFAULT nextval('public.telemetry_instancetelemetry_id_seq'::regclass);
 M   ALTER TABLE public.telemetry_instancetelemetry ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    320    319            s           2604    3598495    timeline_timeline id    DEFAULT     |   ALTER TABLE ONLY public.timeline_timeline ALTER COLUMN id SET DEFAULT nextval('public.timeline_timeline_id_seq'::regclass);
 C   ALTER TABLE public.timeline_timeline ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    321    242            �           2604    3598514 !   token_denylist_denylistedtoken id    DEFAULT     �   ALTER TABLE ONLY public.token_denylist_denylistedtoken ALTER COLUMN id SET DEFAULT nextval('public.token_denylist_denylistedtoken_id_seq'::regclass);
 P   ALTER TABLE public.token_denylist_denylistedtoken ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    325    324    325            �           2604    3598501 "   token_denylist_outstandingtoken id    DEFAULT     �   ALTER TABLE ONLY public.token_denylist_outstandingtoken ALTER COLUMN id SET DEFAULT nextval('public.token_denylist_outstandingtoken_id_seq'::regclass);
 Q   ALTER TABLE public.token_denylist_outstandingtoken ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    322    323    323            q           2604    3598590    users_authdata id    DEFAULT     v   ALTER TABLE ONLY public.users_authdata ALTER COLUMN id SET DEFAULT nextval('public.users_authdata_id_seq'::regclass);
 @   ALTER TABLE public.users_authdata ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    327    240            M           2604    3598607    users_role id    DEFAULT     n   ALTER TABLE ONLY public.users_role ALTER COLUMN id SET DEFAULT nextval('public.users_role_id_seq'::regclass);
 <   ALTER TABLE public.users_role ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    328    209            J           2604    3598662    users_user id    DEFAULT     n   ALTER TABLE ONLY public.users_user ALTER COLUMN id SET DEFAULT nextval('public.users_user_id_seq'::regclass);
 <   ALTER TABLE public.users_user ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    329    206            �           2604    3599183    users_workspacerole id    DEFAULT     �   ALTER TABLE ONLY public.users_workspacerole ALTER COLUMN id SET DEFAULT nextval('public.users_workspacerole_id_seq'::regclass);
 E   ALTER TABLE public.users_workspacerole ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    330    326            �           2604    3599226    userstorage_storageentry id    DEFAULT     �   ALTER TABLE ONLY public.userstorage_storageentry ALTER COLUMN id SET DEFAULT nextval('public.userstorage_storageentry_id_seq'::regclass);
 J   ALTER TABLE public.userstorage_storageentry ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    332    331            h           2604    3599317    userstories_rolepoints id    DEFAULT     �   ALTER TABLE ONLY public.userstories_rolepoints ALTER COLUMN id SET DEFAULT nextval('public.userstories_rolepoints_id_seq'::regclass);
 H   ALTER TABLE public.userstories_rolepoints ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    335    230            i           2604    3599339    userstories_userstory id    DEFAULT     �   ALTER TABLE ONLY public.userstories_userstory ALTER COLUMN id SET DEFAULT nextval('public.userstories_userstory_id_seq'::regclass);
 G   ALTER TABLE public.userstories_userstory ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    336    231            �           2604    3599275 '   userstories_userstory_assigned_users id    DEFAULT     �   ALTER TABLE ONLY public.userstories_userstory_assigned_users ALTER COLUMN id SET DEFAULT nextval('public.userstories_userstory_assigned_users_id_seq'::regclass);
 V   ALTER TABLE public.userstories_userstory_assigned_users ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    333    334    334            �           2604    3599472    votes_vote id    DEFAULT     n   ALTER TABLE ONLY public.votes_vote ALTER COLUMN id SET DEFAULT nextval('public.votes_vote_id_seq'::regclass);
 <   ALTER TABLE public.votes_vote ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    339    337            �           2604    3599484    votes_votes id    DEFAULT     p   ALTER TABLE ONLY public.votes_votes ALTER COLUMN id SET DEFAULT nextval('public.votes_votes_id_seq'::regclass);
 =   ALTER TABLE public.votes_votes ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    340    338            �           2604    3599545    webhooks_webhook id    DEFAULT     z   ALTER TABLE ONLY public.webhooks_webhook ALTER COLUMN id SET DEFAULT nextval('public.webhooks_webhook_id_seq'::regclass);
 B   ALTER TABLE public.webhooks_webhook ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    343    341            �           2604    3599573    webhooks_webhooklog id    DEFAULT     �   ALTER TABLE ONLY public.webhooks_webhooklog ALTER COLUMN id SET DEFAULT nextval('public.webhooks_webhooklog_id_seq'::regclass);
 E   ALTER TABLE public.webhooks_webhooklog ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    344    342            y           2604    3599601    wiki_wikilink id    DEFAULT     t   ALTER TABLE ONLY public.wiki_wikilink ALTER COLUMN id SET DEFAULT nextval('public.wiki_wikilink_id_seq'::regclass);
 ?   ALTER TABLE public.wiki_wikilink ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    345    247            z           2604    3599620    wiki_wikipage id    DEFAULT     t   ALTER TABLE ONLY public.wiki_wikipage ALTER COLUMN id SET DEFAULT nextval('public.wiki_wikipage_id_seq'::regclass);
 ?   ALTER TABLE public.wiki_wikipage ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    346    248            �           2604    3599664    workspaces_workspace id    DEFAULT     �   ALTER TABLE ONLY public.workspaces_workspace ALTER COLUMN id SET DEFAULT nextval('public.workspaces_workspace_id_seq'::regclass);
 F   ALTER TABLE public.workspaces_workspace ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    348    290            �           2604    3599759 !   workspaces_workspacemembership id    DEFAULT     �   ALTER TABLE ONLY public.workspaces_workspacemembership ALTER COLUMN id SET DEFAULT nextval('public.workspaces_workspacemembership_id_seq'::regclass);
 P   ALTER TABLE public.workspaces_workspacemembership ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    349    347            �          0    3594704    attachments_attachment 
   TABLE DATA           �   COPY public.attachments_attachment (id, object_id, created_date, modified_date, attached_file, is_deprecated, description, "order", content_type_id, owner_id, project_id, name, size, sha1, from_comment) FROM stdin;
    public          taiga    false    220   �V      �          0    3594763 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    225   W      �          0    3594773    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    227   /W      �          0    3594755    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    223   LW      �          0    3595627    contact_contactentry 
   TABLE DATA           ^   COPY public.contact_contactentry (id, comment, created_date, project_id, user_id) FROM stdin;
    public          taiga    false    245   Yb      �          0    3595978 %   custom_attributes_epiccustomattribute 
   TABLE DATA           �   COPY public.custom_attributes_epiccustomattribute (id, name, description, type, "order", created_date, modified_date, project_id, extra) FROM stdin;
    public          taiga    false    258   vb      �          0    3595989 ,   custom_attributes_epiccustomattributesvalues 
   TABLE DATA           o   COPY public.custom_attributes_epiccustomattributesvalues (id, version, attributes_values, epic_id) FROM stdin;
    public          taiga    false    259   �b      �          0    3595853 &   custom_attributes_issuecustomattribute 
   TABLE DATA           �   COPY public.custom_attributes_issuecustomattribute (id, name, description, "order", created_date, modified_date, project_id, type, extra) FROM stdin;
    public          taiga    false    252   �b      �          0    3595910 -   custom_attributes_issuecustomattributesvalues 
   TABLE DATA           q   COPY public.custom_attributes_issuecustomattributesvalues (id, version, attributes_values, issue_id) FROM stdin;
    public          taiga    false    255   �b      �          0    3595864 %   custom_attributes_taskcustomattribute 
   TABLE DATA           �   COPY public.custom_attributes_taskcustomattribute (id, name, description, "order", created_date, modified_date, project_id, type, extra) FROM stdin;
    public          taiga    false    253   �b      �          0    3595923 ,   custom_attributes_taskcustomattributesvalues 
   TABLE DATA           o   COPY public.custom_attributes_taskcustomattributesvalues (id, version, attributes_values, task_id) FROM stdin;
    public          taiga    false    256   c      �          0    3595875 *   custom_attributes_userstorycustomattribute 
   TABLE DATA           �   COPY public.custom_attributes_userstorycustomattribute (id, name, description, "order", created_date, modified_date, project_id, type, extra) FROM stdin;
    public          taiga    false    254   $c      �          0    3595936 1   custom_attributes_userstorycustomattributesvalues 
   TABLE DATA           z   COPY public.custom_attributes_userstorycustomattributesvalues (id, version, attributes_values, user_story_id) FROM stdin;
    public          taiga    false    257   Ac      �          0    3594433    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    208   ^c      �          0    3594409    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    205   {c      �          0    3594398    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    203   +f      !          0    3598324    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    315   {      �          0    3596208    djmail_message 
   TABLE DATA           �   COPY public.djmail_message (uuid, from_email, to_email, body_text, body_html, subject, data, retry_count, status, priority, created_at, sent_at, exception) FROM stdin;
    public          taiga    false    268   ){      �          0    3596219    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    270   F{      �          0    3596227    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    272   c{      �          0    3596253 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    274   �{      �          0    3595794 
   epics_epic 
   TABLE DATA             COPY public.epics_epic (id, tags, version, is_blocked, blocked_note, ref, epics_order, created_date, modified_date, subject, description, client_requirement, team_requirement, assigned_to_id, owner_id, project_id, status_id, color, external_reference) FROM stdin;
    public          taiga    false    250   �{      �          0    3595805    epics_relateduserstory 
   TABLE DATA           U   COPY public.epics_relateduserstory (id, "order", epic_id, user_story_id) FROM stdin;
    public          taiga    false    251   �{      �          0    3596352    external_apps_application 
   TABLE DATA           c   COPY public.external_apps_application (id, name, icon_url, web, description, next_url) FROM stdin;
    public          taiga    false    277   �{      �          0    3596362    external_apps_applicationtoken 
   TABLE DATA           n   COPY public.external_apps_applicationtoken (id, auth_code, token, state, application_id, user_id) FROM stdin;
    public          taiga    false    278   �{      �          0    3596406    feedback_feedbackentry 
   TABLE DATA           ]   COPY public.feedback_feedbackentry (id, full_name, email, comment, created_date) FROM stdin;
    public          taiga    false    280   |      �          0    3595756    history_historyentry 
   TABLE DATA             COPY public.history_historyentry (id, "user", created_at, type, is_snapshot, key, diff, snapshot, "values", comment, comment_html, delete_comment_date, delete_comment_user, is_hidden, comment_versions, edit_comment_date, project_id, values_diff_cache) FROM stdin;
    public          taiga    false    249   .|      �          0    3594874    issues_issue 
   TABLE DATA           +  COPY public.issues_issue (id, tags, version, is_blocked, blocked_note, ref, created_date, modified_date, finished_date, subject, description, assigned_to_id, milestone_id, owner_id, priority_id, project_id, severity_id, status_id, type_id, external_reference, due_date, due_date_reason) FROM stdin;
    public          taiga    false    229   K|      �          0    3595445 
   likes_like 
   TABLE DATA           [   COPY public.likes_like (id, object_id, created_date, content_type_id, user_id) FROM stdin;
    public          taiga    false    243   h|      �          0    3594823    milestones_milestone 
   TABLE DATA           �   COPY public.milestones_milestone (id, name, slug, estimated_start, estimated_finish, created_date, modified_date, closed, disponibility, "order", owner_id, project_id) FROM stdin;
    public          taiga    false    228   �|      �          0    3595129 '   notifications_historychangenotification 
   TABLE DATA           �   COPY public.notifications_historychangenotification (id, key, created_datetime, updated_datetime, history_type, owner_id, project_id) FROM stdin;
    public          taiga    false    233   �|      �          0    3595137 7   notifications_historychangenotification_history_entries 
   TABLE DATA           �   COPY public.notifications_historychangenotification_history_entries (id, historychangenotification_id, historyentry_id) FROM stdin;
    public          taiga    false    235   �|      �          0    3595145 4   notifications_historychangenotification_notify_users 
   TABLE DATA           y   COPY public.notifications_historychangenotification_notify_users (id, historychangenotification_id, user_id) FROM stdin;
    public          taiga    false    237   �|      �          0    3595086    notifications_notifypolicy 
   TABLE DATA           �   COPY public.notifications_notifypolicy (id, notify_level, created_at, modified_at, project_id, user_id, live_notify_level, web_notify_level) FROM stdin;
    public          taiga    false    232   �|      �          0    3595196    notifications_watched 
   TABLE DATA           r   COPY public.notifications_watched (id, object_id, created_date, content_type_id, user_id, project_id) FROM stdin;
    public          taiga    false    238   �                0    3596595    notifications_webnotification 
   TABLE DATA           e   COPY public.notifications_webnotification (id, created, read, event_type, data, user_id) FROM stdin;
    public          taiga    false    285   #�      I          0    3599817    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    355   @�      E          0    3599787    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    351   ]�      G          0    3599801    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    353   z�      �          0    3595553    projects_epicstatus 
   TABLE DATA           d   COPY public.projects_epicstatus (id, name, slug, "order", is_closed, color, project_id) FROM stdin;
    public          taiga    false    244   ��      	          0    3596714    projects_issueduedate 
   TABLE DATA           n   COPY public.projects_issueduedate (id, name, "order", by_default, color, days_to_due, project_id) FROM stdin;
    public          taiga    false    291   7�      �          0    3594523    projects_issuestatus 
   TABLE DATA           e   COPY public.projects_issuestatus (id, name, "order", is_closed, color, project_id, slug) FROM stdin;
    public          taiga    false    212   s�      �          0    3594531    projects_issuetype 
   TABLE DATA           R   COPY public.projects_issuetype (id, name, "order", color, project_id) FROM stdin;
    public          taiga    false    213   ��      �          0    3594470    projects_membership 
   TABLE DATA           �   COPY public.projects_membership (id, is_admin, email, created_at, token, user_id, project_id, role_id, invited_by_id, invitation_extra_text, user_order) FROM stdin;
    public          taiga    false    210   D�      �          0    3594539    projects_points 
   TABLE DATA           O   COPY public.projects_points (id, name, "order", value, project_id) FROM stdin;
    public          taiga    false    214   �      �          0    3594547    projects_priority 
   TABLE DATA           Q   COPY public.projects_priority (id, name, "order", color, project_id) FROM stdin;
    public          taiga    false    215   ��      �          0    3594478    projects_project 
   TABLE DATA             COPY public.projects_project (id, tags, name, slug, description, created_date, modified_date, total_milestones, total_story_points, is_backlog_activated, is_kanban_activated, is_wiki_activated, is_issues_activated, videoconferences, videoconferences_extra_data, anon_permissions, public_permissions, is_private, tags_colors, owner_id, creation_template_id, default_issue_status_id, default_issue_type_id, default_points_id, default_priority_id, default_severity_id, default_task_status_id, default_us_status_id, issues_csv_uuid, tasks_csv_uuid, userstories_csv_uuid, is_featured, is_looking_for_people, total_activity, total_activity_last_month, total_activity_last_week, total_activity_last_year, total_fans, total_fans_last_month, total_fans_last_week, total_fans_last_year, totals_updated_datetime, logo, looking_for_people_note, blocked_code, transfer_token, is_epics_activated, default_epic_status_id, epics_csv_uuid, is_contact_activated, default_swimlane_id, workspace_id, color, workspace_member_permissions) FROM stdin;
    public          taiga    false    211   ߧ      �          0    3595370    projects_projectmodulesconfig 
   TABLE DATA           O   COPY public.projects_projectmodulesconfig (id, config, project_id) FROM stdin;
    public          taiga    false    241   m�      �          0    3594555    projects_projecttemplate 
   TABLE DATA           �  COPY public.projects_projecttemplate (id, name, slug, description, created_date, modified_date, default_owner_role, is_backlog_activated, is_kanban_activated, is_wiki_activated, is_issues_activated, videoconferences, videoconferences_extra_data, default_options, us_statuses, points, task_statuses, issue_statuses, issue_types, priorities, severities, roles, "order", epic_statuses, is_epics_activated, is_contact_activated, epic_custom_attributes, is_looking_for_people, issue_custom_attributes, looking_for_people_note, tags, tags_colors, task_custom_attributes, us_custom_attributes, issue_duedates, task_duedates, us_duedates) FROM stdin;
    public          taiga    false    216   ��      �          0    3594568    projects_severity 
   TABLE DATA           Q   COPY public.projects_severity (id, name, "order", color, project_id) FROM stdin;
    public          taiga    false    217   8�                0    3596764    projects_swimlane 
   TABLE DATA           J   COPY public.projects_swimlane (id, name, "order", project_id) FROM stdin;
    public          taiga    false    294   a�                0    3596781     projects_swimlaneuserstorystatus 
   TABLE DATA           a   COPY public.projects_swimlaneuserstorystatus (id, wip_limit, status_id, swimlane_id) FROM stdin;
    public          taiga    false    295   ~�      
          0    3596722    projects_taskduedate 
   TABLE DATA           m   COPY public.projects_taskduedate (id, name, "order", by_default, color, days_to_due, project_id) FROM stdin;
    public          taiga    false    292   ��      �          0    3594576    projects_taskstatus 
   TABLE DATA           d   COPY public.projects_taskstatus (id, name, "order", is_closed, color, project_id, slug) FROM stdin;
    public          taiga    false    218   ��                0    3596730    projects_userstoryduedate 
   TABLE DATA           r   COPY public.projects_userstoryduedate (id, name, "order", by_default, color, days_to_due, project_id) FROM stdin;
    public          taiga    false    293   ��      �          0    3594584    projects_userstorystatus 
   TABLE DATA           �   COPY public.projects_userstorystatus (id, name, "order", is_closed, color, wip_limit, project_id, slug, is_archived) FROM stdin;
    public          taiga    false    219   �                0    3598290    references_reference 
   TABLE DATA           k   COPY public.references_reference (id, object_id, ref, created_at, content_type_id, project_id) FROM stdin;
    public          taiga    false    313   a�      "          0    3598336    settings_userprojectsettings 
   TABLE DATA           r   COPY public.settings_userprojectsettings (id, homepage, created_at, modified_at, project_id, user_id) FROM stdin;
    public          taiga    false    316   ~�      �          0    3595225 
   tasks_task 
   TABLE DATA           <  COPY public.tasks_task (id, tags, version, is_blocked, blocked_note, ref, created_date, modified_date, finished_date, subject, description, is_iocaine, assigned_to_id, milestone_id, owner_id, project_id, status_id, user_story_id, taskboard_order, us_order, external_reference, due_date, due_date_reason) FROM stdin;
    public          taiga    false    239   ��      %          0    3598437    telemetry_instancetelemetry 
   TABLE DATA           R   COPY public.telemetry_instancetelemetry (id, instance_id, created_at) FROM stdin;
    public          taiga    false    319   ��      �          0    3595395    timeline_timeline 
   TABLE DATA           �   COPY public.timeline_timeline (id, object_id, namespace, event_type, project_id, data, data_content_type_id, created, content_type_id) FROM stdin;
    public          taiga    false    242   ��      +          0    3598511    token_denylist_denylistedtoken 
   TABLE DATA           U   COPY public.token_denylist_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    325   J�      )          0    3598498    token_denylist_outstandingtoken 
   TABLE DATA           j   COPY public.token_denylist_outstandingtoken (id, jti, token, created_at, expires_at, user_id) FROM stdin;
    public          taiga    false    323   g�      �          0    3595302    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    240   ��      �          0    3594457 
   users_role 
   TABLE DATA           l   COPY public.users_role (id, name, slug, permissions, "order", computable, project_id, is_admin) FROM stdin;
    public          taiga    false    209   ��      �          0    3594419 
   users_user 
   TABLE DATA           �  COPY public.users_user (id, password, last_login, is_superuser, username, email, is_active, full_name, color, bio, photo, date_joined, lang, timezone, colorize_tags, token, email_token, new_email, is_system, theme, max_private_projects, max_public_projects, max_memberships_private_projects, max_memberships_public_projects, uuid, accepted_terms, read_new_terms, verified_email, is_staff, date_cancelled) FROM stdin;
    public          taiga    false    206   k�      ,          0    3598555    users_workspacerole 
   TABLE DATA           k   COPY public.users_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    326   ��      1          0    3599186    userstorage_storageentry 
   TABLE DATA           i   COPY public.userstorage_storageentry (id, created_date, modified_date, key, value, owner_id) FROM stdin;
    public          taiga    false    331    �      �          0    3594956    userstories_rolepoints 
   TABLE DATA           W   COPY public.userstories_rolepoints (id, points_id, role_id, user_story_id) FROM stdin;
    public          taiga    false    230   =�      �          0    3594964    userstories_userstory 
   TABLE DATA           �  COPY public.userstories_userstory (id, tags, version, is_blocked, blocked_note, ref, is_closed, backlog_order, created_date, modified_date, finish_date, subject, description, client_requirement, team_requirement, assigned_to_id, generated_from_issue_id, milestone_id, owner_id, project_id, status_id, sprint_order, kanban_order, external_reference, tribe_gig, due_date, due_date_reason, generated_from_task_id, from_task_ref, swimlane_id) FROM stdin;
    public          taiga    false    231   Z�      4          0    3599272 $   userstories_userstory_assigned_users 
   TABLE DATA           Y   COPY public.userstories_userstory_assigned_users (id, userstory_id, user_id) FROM stdin;
    public          taiga    false    334   w�      7          0    3599420 
   votes_vote 
   TABLE DATA           [   COPY public.votes_vote (id, object_id, content_type_id, user_id, created_date) FROM stdin;
    public          taiga    false    337   ��      8          0    3599429    votes_votes 
   TABLE DATA           L   COPY public.votes_votes (id, object_id, count, content_type_id) FROM stdin;
    public          taiga    false    338   ��      ;          0    3599487    webhooks_webhook 
   TABLE DATA           J   COPY public.webhooks_webhook (id, url, key, project_id, name) FROM stdin;
    public          taiga    false    341   ��      <          0    3599498    webhooks_webhooklog 
   TABLE DATA           �   COPY public.webhooks_webhooklog (id, url, status, request_data, response_data, webhook_id, created, duration, request_headers, response_headers) FROM stdin;
    public          taiga    false    342   ��      �          0    3595665    wiki_wikilink 
   TABLE DATA           M   COPY public.wiki_wikilink (id, title, href, "order", project_id) FROM stdin;
    public          taiga    false    247   �      �          0    3595677    wiki_wikipage 
   TABLE DATA           �   COPY public.wiki_wikipage (id, version, slug, content, created_date, modified_date, last_modifier_id, owner_id, project_id) FROM stdin;
    public          taiga    false    248   %�                0    3596691    workspaces_workspace 
   TABLE DATA           x   COPY public.workspaces_workspace (id, name, slug, color, created_date, modified_date, owner_id, is_premium) FROM stdin;
    public          taiga    false    290   B�      A          0    3599623    workspaces_workspacemembership 
   TABLE DATA           f   COPY public.workspaces_workspacemembership (id, user_id, workspace_id, workspace_role_id) FROM stdin;
    public          taiga    false    347   �      �           0    0    attachments_attachment_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.attachments_attachment_id_seq', 1, false);
          public          taiga    false    221            �           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    224            �           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    226            �           0    0    auth_permission_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.auth_permission_id_seq', 284, true);
          public          taiga    false    222            �           0    0    contact_contactentry_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.contact_contactentry_id_seq', 1, false);
          public          taiga    false    246            �           0    0 ,   custom_attributes_epiccustomattribute_id_seq    SEQUENCE SET     [   SELECT pg_catalog.setval('public.custom_attributes_epiccustomattribute_id_seq', 1, false);
          public          taiga    false    260            �           0    0 3   custom_attributes_epiccustomattributesvalues_id_seq    SEQUENCE SET     b   SELECT pg_catalog.setval('public.custom_attributes_epiccustomattributesvalues_id_seq', 1, false);
          public          taiga    false    261            �           0    0 -   custom_attributes_issuecustomattribute_id_seq    SEQUENCE SET     \   SELECT pg_catalog.setval('public.custom_attributes_issuecustomattribute_id_seq', 1, false);
          public          taiga    false    262            �           0    0 4   custom_attributes_issuecustomattributesvalues_id_seq    SEQUENCE SET     c   SELECT pg_catalog.setval('public.custom_attributes_issuecustomattributesvalues_id_seq', 1, false);
          public          taiga    false    263            �           0    0 ,   custom_attributes_taskcustomattribute_id_seq    SEQUENCE SET     [   SELECT pg_catalog.setval('public.custom_attributes_taskcustomattribute_id_seq', 1, false);
          public          taiga    false    264            �           0    0 3   custom_attributes_taskcustomattributesvalues_id_seq    SEQUENCE SET     b   SELECT pg_catalog.setval('public.custom_attributes_taskcustomattributesvalues_id_seq', 1, false);
          public          taiga    false    265            �           0    0 1   custom_attributes_userstorycustomattribute_id_seq    SEQUENCE SET     `   SELECT pg_catalog.setval('public.custom_attributes_userstorycustomattribute_id_seq', 1, false);
          public          taiga    false    266            �           0    0 8   custom_attributes_userstorycustomattributesvalues_id_seq    SEQUENCE SET     g   SELECT pg_catalog.setval('public.custom_attributes_userstorycustomattributesvalues_id_seq', 1, false);
          public          taiga    false    267            �           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    207            �           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 71, true);
          public          taiga    false    204            �           0    0    django_migrations_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.django_migrations_id_seq', 307, true);
          public          taiga    false    202            �           0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          taiga    false    269            �           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          taiga    false    271            �           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    273            �           0    0    epics_epic_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.epics_epic_id_seq', 1, false);
          public          taiga    false    275            �           0    0    epics_relateduserstory_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.epics_relateduserstory_id_seq', 1, false);
          public          taiga    false    276            �           0    0 %   external_apps_applicationtoken_id_seq    SEQUENCE SET     T   SELECT pg_catalog.setval('public.external_apps_applicationtoken_id_seq', 1, false);
          public          taiga    false    279            �           0    0    feedback_feedbackentry_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.feedback_feedbackentry_id_seq', 1, false);
          public          taiga    false    281            �           0    0    issues_issue_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.issues_issue_id_seq', 1, false);
          public          taiga    false    282            �           0    0    likes_like_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.likes_like_id_seq', 1, false);
          public          taiga    false    283            �           0    0    milestones_milestone_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.milestones_milestone_id_seq', 1, false);
          public          taiga    false    284            �           0    0 >   notifications_historychangenotification_history_entries_id_seq    SEQUENCE SET     m   SELECT pg_catalog.setval('public.notifications_historychangenotification_history_entries_id_seq', 1, false);
          public          taiga    false    234            �           0    0 .   notifications_historychangenotification_id_seq    SEQUENCE SET     ]   SELECT pg_catalog.setval('public.notifications_historychangenotification_id_seq', 1, false);
          public          taiga    false    286            �           0    0 ;   notifications_historychangenotification_notify_users_id_seq    SEQUENCE SET     j   SELECT pg_catalog.setval('public.notifications_historychangenotification_notify_users_id_seq', 1, false);
          public          taiga    false    236            �           0    0 !   notifications_notifypolicy_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.notifications_notifypolicy_id_seq', 161, true);
          public          taiga    false    287            �           0    0    notifications_watched_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.notifications_watched_id_seq', 1, false);
          public          taiga    false    288            �           0    0 $   notifications_webnotification_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.notifications_webnotification_id_seq', 1, false);
          public          taiga    false    289            �           0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 1, false);
          public          taiga    false    354            �           0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 1, false);
          public          taiga    false    350            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    352            �           0    0    projects_epicstatus_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.projects_epicstatus_id_seq', 225, true);
          public          taiga    false    296            �           0    0    projects_issueduedate_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.projects_issueduedate_id_seq', 135, true);
          public          taiga    false    297            �           0    0    projects_issuestatus_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.projects_issuestatus_id_seq', 315, true);
          public          taiga    false    298            �           0    0    projects_issuetype_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.projects_issuetype_id_seq', 135, true);
          public          taiga    false    299            �           0    0    projects_membership_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.projects_membership_id_seq', 161, true);
          public          taiga    false    300            �           0    0    projects_points_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.projects_points_id_seq', 540, true);
          public          taiga    false    301            �           0    0    projects_priority_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.projects_priority_id_seq', 135, true);
          public          taiga    false    302            �           0    0    projects_project_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.projects_project_id_seq', 45, true);
          public          taiga    false    303            �           0    0 $   projects_projectmodulesconfig_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.projects_projectmodulesconfig_id_seq', 1, false);
          public          taiga    false    304            �           0    0    projects_projecttemplate_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.projects_projecttemplate_id_seq', 2, true);
          public          taiga    false    305            �           0    0    projects_severity_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.projects_severity_id_seq', 225, true);
          public          taiga    false    306            �           0    0    projects_swimlane_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.projects_swimlane_id_seq', 1, false);
          public          taiga    false    307            �           0    0 '   projects_swimlaneuserstorystatus_id_seq    SEQUENCE SET     V   SELECT pg_catalog.setval('public.projects_swimlaneuserstorystatus_id_seq', 1, false);
          public          taiga    false    308            �           0    0    projects_taskduedate_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.projects_taskduedate_id_seq', 135, true);
          public          taiga    false    309            �           0    0    projects_taskstatus_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.projects_taskstatus_id_seq', 225, true);
          public          taiga    false    310            �           0    0     projects_userstoryduedate_id_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('public.projects_userstoryduedate_id_seq', 135, true);
          public          taiga    false    311            �           0    0    projects_userstorystatus_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.projects_userstorystatus_id_seq', 270, true);
          public          taiga    false    312            �           0    0    references_project1    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project1', 1, false);
          public          taiga    false    356            �           0    0    references_project10    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project10', 1, false);
          public          taiga    false    365            �           0    0    references_project11    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project11', 1, false);
          public          taiga    false    366            �           0    0    references_project12    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project12', 1, false);
          public          taiga    false    367                        0    0    references_project13    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project13', 1, false);
          public          taiga    false    368                       0    0    references_project14    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project14', 1, false);
          public          taiga    false    369                       0    0    references_project15    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project15', 1, false);
          public          taiga    false    370                       0    0    references_project16    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project16', 1, false);
          public          taiga    false    371                       0    0    references_project17    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project17', 1, false);
          public          taiga    false    372                       0    0    references_project18    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project18', 1, false);
          public          taiga    false    373                       0    0    references_project19    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project19', 1, false);
          public          taiga    false    374                       0    0    references_project2    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project2', 1, false);
          public          taiga    false    357                       0    0    references_project20    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project20', 1, false);
          public          taiga    false    375            	           0    0    references_project21    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project21', 1, false);
          public          taiga    false    376            
           0    0    references_project22    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project22', 1, false);
          public          taiga    false    377                       0    0    references_project23    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project23', 1, false);
          public          taiga    false    378                       0    0    references_project24    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project24', 1, false);
          public          taiga    false    379                       0    0    references_project25    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project25', 1, false);
          public          taiga    false    380                       0    0    references_project26    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project26', 1, false);
          public          taiga    false    381                       0    0    references_project27    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project27', 1, false);
          public          taiga    false    382                       0    0    references_project28    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project28', 1, false);
          public          taiga    false    383                       0    0    references_project29    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project29', 1, false);
          public          taiga    false    384                       0    0    references_project3    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project3', 1, false);
          public          taiga    false    358                       0    0    references_project30    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project30', 1, false);
          public          taiga    false    385                       0    0    references_project31    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project31', 1, false);
          public          taiga    false    386                       0    0    references_project32    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project32', 1, false);
          public          taiga    false    387                       0    0    references_project33    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project33', 1, false);
          public          taiga    false    388                       0    0    references_project34    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project34', 1, false);
          public          taiga    false    389                       0    0    references_project35    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project35', 1, false);
          public          taiga    false    390                       0    0    references_project36    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project36', 1, false);
          public          taiga    false    391                       0    0    references_project37    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project37', 1, false);
          public          taiga    false    392                       0    0    references_project38    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project38', 1, false);
          public          taiga    false    393                       0    0    references_project39    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project39', 1, false);
          public          taiga    false    394                       0    0    references_project4    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project4', 1, false);
          public          taiga    false    359                       0    0    references_project40    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project40', 1, false);
          public          taiga    false    395                       0    0    references_project41    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project41', 1, false);
          public          taiga    false    396                        0    0    references_project42    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project42', 1, false);
          public          taiga    false    397            !           0    0    references_project43    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project43', 1, false);
          public          taiga    false    398            "           0    0    references_project44    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project44', 1, false);
          public          taiga    false    399            #           0    0    references_project45    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project45', 1, false);
          public          taiga    false    400            $           0    0    references_project5    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project5', 1, false);
          public          taiga    false    360            %           0    0    references_project6    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project6', 1, false);
          public          taiga    false    361            &           0    0    references_project7    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project7', 1, false);
          public          taiga    false    362            '           0    0    references_project8    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project8', 1, false);
          public          taiga    false    363            (           0    0    references_project9    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project9', 1, false);
          public          taiga    false    364            )           0    0    references_reference_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.references_reference_id_seq', 1, false);
          public          taiga    false    314            *           0    0 #   settings_userprojectsettings_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.settings_userprojectsettings_id_seq', 1, false);
          public          taiga    false    317            +           0    0    tasks_task_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.tasks_task_id_seq', 1, false);
          public          taiga    false    318            ,           0    0 "   telemetry_instancetelemetry_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.telemetry_instancetelemetry_id_seq', 1, false);
          public          taiga    false    320            -           0    0    timeline_timeline_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.timeline_timeline_id_seq', 247, true);
          public          taiga    false    321            .           0    0 %   token_denylist_denylistedtoken_id_seq    SEQUENCE SET     T   SELECT pg_catalog.setval('public.token_denylist_denylistedtoken_id_seq', 1, false);
          public          taiga    false    324            /           0    0 &   token_denylist_outstandingtoken_id_seq    SEQUENCE SET     U   SELECT pg_catalog.setval('public.token_denylist_outstandingtoken_id_seq', 1, false);
          public          taiga    false    322            0           0    0    users_authdata_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.users_authdata_id_seq', 1, false);
          public          taiga    false    327            1           0    0    users_role_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.users_role_id_seq', 93, true);
          public          taiga    false    328            2           0    0    users_user_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.users_user_id_seq', 19, true);
          public          taiga    false    329            3           0    0    users_workspacerole_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.users_workspacerole_id_seq', 44, true);
          public          taiga    false    330            4           0    0    userstorage_storageentry_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.userstorage_storageentry_id_seq', 1, false);
          public          taiga    false    332            5           0    0    userstories_rolepoints_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.userstories_rolepoints_id_seq', 1, false);
          public          taiga    false    335            6           0    0 +   userstories_userstory_assigned_users_id_seq    SEQUENCE SET     Z   SELECT pg_catalog.setval('public.userstories_userstory_assigned_users_id_seq', 1, false);
          public          taiga    false    333            7           0    0    userstories_userstory_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.userstories_userstory_id_seq', 1, false);
          public          taiga    false    336            8           0    0    votes_vote_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.votes_vote_id_seq', 1, false);
          public          taiga    false    339            9           0    0    votes_votes_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.votes_votes_id_seq', 1, false);
          public          taiga    false    340            :           0    0    webhooks_webhook_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.webhooks_webhook_id_seq', 1, false);
          public          taiga    false    343            ;           0    0    webhooks_webhooklog_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.webhooks_webhooklog_id_seq', 1, false);
          public          taiga    false    344            <           0    0    wiki_wikilink_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.wiki_wikilink_id_seq', 1, false);
          public          taiga    false    345            =           0    0    wiki_wikipage_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.wiki_wikipage_id_seq', 1, false);
          public          taiga    false    346            >           0    0    workspaces_workspace_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.workspaces_workspace_id_seq', 28, true);
          public          taiga    false    348            ?           0    0 %   workspaces_workspacemembership_id_seq    SEQUENCE SET     U   SELECT pg_catalog.setval('public.workspaces_workspacemembership_id_seq', 102, true);
          public          taiga    false    349            8           2606    3594738 2   attachments_attachment attachments_attachment_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.attachments_attachment
    ADD CONSTRAINT attachments_attachment_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.attachments_attachment DROP CONSTRAINT attachments_attachment_pkey;
       public            taiga    false    220            A           2606    3594803    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    225            F           2606    3594789 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    227    227            I           2606    3594778 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    227            C           2606    3594768    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    225            <           2606    3594780 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    223    223            >           2606    3594760 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    223            �           2606    3595650 .   contact_contactentry contact_contactentry_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.contact_contactentry
    ADD CONSTRAINT contact_contactentry_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.contact_contactentry DROP CONSTRAINT contact_contactentry_pkey;
       public            taiga    false    245                       2606    3597646 \   custom_attributes_epiccustomattribute custom_attributes_epiccu_project_id_name_3850c31d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute
    ADD CONSTRAINT custom_attributes_epiccu_project_id_name_3850c31d_uniq UNIQUE (project_id, name);
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute DROP CONSTRAINT custom_attributes_epiccu_project_id_name_3850c31d_uniq;
       public            taiga    false    258    258            
           2606    3596090 P   custom_attributes_epiccustomattribute custom_attributes_epiccustomattribute_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute
    ADD CONSTRAINT custom_attributes_epiccustomattribute_pkey PRIMARY KEY (id);
 z   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute DROP CONSTRAINT custom_attributes_epiccustomattribute_pkey;
       public            taiga    false    258                       2606    3596318 e   custom_attributes_epiccustomattributesvalues custom_attributes_epiccustomattributesvalues_epic_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues
    ADD CONSTRAINT custom_attributes_epiccustomattributesvalues_epic_id_key UNIQUE (epic_id);
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues DROP CONSTRAINT custom_attributes_epiccustomattributesvalues_epic_id_key;
       public            taiga    false    259                       2606    3596105 ^   custom_attributes_epiccustomattributesvalues custom_attributes_epiccustomattributesvalues_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues
    ADD CONSTRAINT custom_attributes_epiccustomattributesvalues_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues DROP CONSTRAINT custom_attributes_epiccustomattributesvalues_pkey;
       public            taiga    false    259            �           2606    3597670 ]   custom_attributes_issuecustomattribute custom_attributes_issuec_project_id_name_6f71f010_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute
    ADD CONSTRAINT custom_attributes_issuec_project_id_name_6f71f010_uniq UNIQUE (project_id, name);
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute DROP CONSTRAINT custom_attributes_issuec_project_id_name_6f71f010_uniq;
       public            taiga    false    252    252            �           2606    3596120 R   custom_attributes_issuecustomattribute custom_attributes_issuecustomattribute_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute
    ADD CONSTRAINT custom_attributes_issuecustomattribute_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute DROP CONSTRAINT custom_attributes_issuecustomattribute_pkey;
       public            taiga    false    252            �           2606    3596478 h   custom_attributes_issuecustomattributesvalues custom_attributes_issuecustomattributesvalues_issue_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues
    ADD CONSTRAINT custom_attributes_issuecustomattributesvalues_issue_id_key UNIQUE (issue_id);
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues DROP CONSTRAINT custom_attributes_issuecustomattributesvalues_issue_id_key;
       public            taiga    false    255            �           2606    3596135 `   custom_attributes_issuecustomattributesvalues custom_attributes_issuecustomattributesvalues_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues
    ADD CONSTRAINT custom_attributes_issuecustomattributesvalues_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues DROP CONSTRAINT custom_attributes_issuecustomattributesvalues_pkey;
       public            taiga    false    255            �           2606    3597658 \   custom_attributes_taskcustomattribute custom_attributes_taskcu_project_id_name_c1c55ac2_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute
    ADD CONSTRAINT custom_attributes_taskcu_project_id_name_c1c55ac2_uniq UNIQUE (project_id, name);
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute DROP CONSTRAINT custom_attributes_taskcu_project_id_name_c1c55ac2_uniq;
       public            taiga    false    253    253            �           2606    3596150 P   custom_attributes_taskcustomattribute custom_attributes_taskcustomattribute_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute
    ADD CONSTRAINT custom_attributes_taskcustomattribute_pkey PRIMARY KEY (id);
 z   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute DROP CONSTRAINT custom_attributes_taskcustomattribute_pkey;
       public            taiga    false    253            �           2606    3596165 ^   custom_attributes_taskcustomattributesvalues custom_attributes_taskcustomattributesvalues_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues
    ADD CONSTRAINT custom_attributes_taskcustomattributesvalues_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues DROP CONSTRAINT custom_attributes_taskcustomattributesvalues_pkey;
       public            taiga    false    256                       2606    3598419 e   custom_attributes_taskcustomattributesvalues custom_attributes_taskcustomattributesvalues_task_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues
    ADD CONSTRAINT custom_attributes_taskcustomattributesvalues_task_id_key UNIQUE (task_id);
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues DROP CONSTRAINT custom_attributes_taskcustomattributesvalues_task_id_key;
       public            taiga    false    256            �           2606    3597682 a   custom_attributes_userstorycustomattribute custom_attributes_userst_project_id_name_86c6b502_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute
    ADD CONSTRAINT custom_attributes_userst_project_id_name_86c6b502_uniq UNIQUE (project_id, name);
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute DROP CONSTRAINT custom_attributes_userst_project_id_name_86c6b502_uniq;
       public            taiga    false    254    254            �           2606    3596180 Z   custom_attributes_userstorycustomattribute custom_attributes_userstorycustomattribute_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute
    ADD CONSTRAINT custom_attributes_userstorycustomattribute_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute DROP CONSTRAINT custom_attributes_userstorycustomattribute_pkey;
       public            taiga    false    254                       2606    3599387 q   custom_attributes_userstorycustomattributesvalues custom_attributes_userstorycustomattributesva_user_story_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues
    ADD CONSTRAINT custom_attributes_userstorycustomattributesva_user_story_id_key UNIQUE (user_story_id);
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues DROP CONSTRAINT custom_attributes_userstorycustomattributesva_user_story_id_key;
       public            taiga    false    257                       2606    3596195 h   custom_attributes_userstorycustomattributesvalues custom_attributes_userstorycustomattributesvalues_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues
    ADD CONSTRAINT custom_attributes_userstorycustomattributesvalues_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues DROP CONSTRAINT custom_attributes_userstorycustomattributesvalues_pkey;
       public            taiga    false    257            �           2606    3594442 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    208            �           2606    3594416 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    205    205            �           2606    3594414 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    205            �           2606    3594406 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    203            b           2606    3598331 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    315                       2606    3596215 "   djmail_message djmail_message_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.djmail_message
    ADD CONSTRAINT djmail_message_pkey PRIMARY KEY (uuid);
 L   ALTER TABLE ONLY public.djmail_message DROP CONSTRAINT djmail_message_pkey;
       public            taiga    false    268                       2606    3596224 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    270                       2606    3596236 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    270    270                       2606    3596234 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    272    272    272            !           2606    3596232 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    272            &           2606    3596260 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    274            (           2606    3596262 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    274            �           2606    3596291    epics_epic epics_epic_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_pkey;
       public            taiga    false    250            �           2606    3596341 2   epics_relateduserstory epics_relateduserstory_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.epics_relateduserstory
    ADD CONSTRAINT epics_relateduserstory_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.epics_relateduserstory DROP CONSTRAINT epics_relateduserstory_pkey;
       public            taiga    false    251            �           2606    3599377 Q   epics_relateduserstory epics_relateduserstory_user_story_id_epic_id_ad704d40_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.epics_relateduserstory
    ADD CONSTRAINT epics_relateduserstory_user_story_id_epic_id_ad704d40_uniq UNIQUE (user_story_id, epic_id);
 {   ALTER TABLE ONLY public.epics_relateduserstory DROP CONSTRAINT epics_relateduserstory_user_story_id_epic_id_ad704d40_uniq;
       public            taiga    false    251    251            -           2606    3598999 \   external_apps_applicationtoken external_apps_applicatio_application_id_user_id_b6a9e9a8_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.external_apps_applicationtoken
    ADD CONSTRAINT external_apps_applicatio_application_id_user_id_b6a9e9a8_uniq UNIQUE (application_id, user_id);
 �   ALTER TABLE ONLY public.external_apps_applicationtoken DROP CONSTRAINT external_apps_applicatio_application_id_user_id_b6a9e9a8_uniq;
       public            taiga    false    278    278            +           2606    3596359 8   external_apps_application external_apps_application_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.external_apps_application
    ADD CONSTRAINT external_apps_application_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.external_apps_application DROP CONSTRAINT external_apps_application_pkey;
       public            taiga    false    277            1           2606    3596389 B   external_apps_applicationtoken external_apps_applicationtoken_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.external_apps_applicationtoken
    ADD CONSTRAINT external_apps_applicationtoken_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.external_apps_applicationtoken DROP CONSTRAINT external_apps_applicationtoken_pkey;
       public            taiga    false    278            4           2606    3596417 2   feedback_feedbackentry feedback_feedbackentry_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.feedback_feedbackentry
    ADD CONSTRAINT feedback_feedbackentry_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.feedback_feedbackentry DROP CONSTRAINT feedback_feedbackentry_pkey;
       public            taiga    false    280            �           2606    3595763 .   history_historyentry history_historyentry_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.history_historyentry
    ADD CONSTRAINT history_historyentry_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.history_historyentry DROP CONSTRAINT history_historyentry_pkey;
       public            taiga    false    249            Z           2606    3596442    issues_issue issues_issue_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_pkey;
       public            taiga    false    229            �           2606    3598925 E   likes_like likes_like_content_type_id_object_id_user_id_e20903f0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.likes_like
    ADD CONSTRAINT likes_like_content_type_id_object_id_user_id_e20903f0_uniq UNIQUE (content_type_id, object_id, user_id);
 o   ALTER TABLE ONLY public.likes_like DROP CONSTRAINT likes_like_content_type_id_object_id_user_id_e20903f0_uniq;
       public            taiga    false    243    243    243            �           2606    3596501    likes_like likes_like_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.likes_like
    ADD CONSTRAINT likes_like_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.likes_like DROP CONSTRAINT likes_like_pkey;
       public            taiga    false    243            M           2606    3597470 G   milestones_milestone milestones_milestone_name_project_id_fe19fd36_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_name_project_id_fe19fd36_uniq UNIQUE (name, project_id);
 q   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_name_project_id_fe19fd36_uniq;
       public            taiga    false    228    228            P           2606    3596514 .   milestones_milestone milestones_milestone_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_pkey;
       public            taiga    false    228            U           2606    3597472 G   milestones_milestone milestones_milestone_slug_project_id_e59bac6a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_slug_project_id_e59bac6a_uniq UNIQUE (slug, project_id);
 q   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_slug_project_id_e59bac6a_uniq;
       public            taiga    false    228    228            �           2606    3598844 t   notifications_historychangenotification_notify_users notifications_historycha_historychangenotificatio_3b0f323b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users
    ADD CONSTRAINT notifications_historycha_historychangenotificatio_3b0f323b_uniq UNIQUE (historychangenotification_id, user_id);
 �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users DROP CONSTRAINT notifications_historycha_historychangenotificatio_3b0f323b_uniq;
       public            taiga    false    237    237            �           2606    3596627 w   notifications_historychangenotification_history_entries notifications_historycha_historychangenotificatio_8fb55cdd_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries
    ADD CONSTRAINT notifications_historycha_historychangenotificatio_8fb55cdd_uniq UNIQUE (historychangenotification_id, historyentry_id);
 �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries DROP CONSTRAINT notifications_historycha_historychangenotificatio_8fb55cdd_uniq;
       public            taiga    false    235    235            z           2606    3598854 g   notifications_historychangenotification notifications_historycha_key_owner_id_project_id__869f948f_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification
    ADD CONSTRAINT notifications_historycha_key_owner_id_project_id__869f948f_uniq UNIQUE (key, owner_id, project_id, history_type);
 �   ALTER TABLE ONLY public.notifications_historychangenotification DROP CONSTRAINT notifications_historycha_key_owner_id_project_id__869f948f_uniq;
       public            taiga    false    233    233    233    233            �           2606    3595776 t   notifications_historychangenotification_history_entries notifications_historychangenotification_history_entries_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries
    ADD CONSTRAINT notifications_historychangenotification_history_entries_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries DROP CONSTRAINT notifications_historychangenotification_history_entries_pkey;
       public            taiga    false    235            �           2606    3595150 n   notifications_historychangenotification_notify_users notifications_historychangenotification_notify_users_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users
    ADD CONSTRAINT notifications_historychangenotification_notify_users_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users DROP CONSTRAINT notifications_historychangenotification_notify_users_pkey;
       public            taiga    false    237            }           2606    3596615 T   notifications_historychangenotification notifications_historychangenotification_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification
    ADD CONSTRAINT notifications_historychangenotification_pkey PRIMARY KEY (id);
 ~   ALTER TABLE ONLY public.notifications_historychangenotification DROP CONSTRAINT notifications_historychangenotification_pkey;
       public            taiga    false    233            t           2606    3596649 :   notifications_notifypolicy notifications_notifypolicy_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.notifications_notifypolicy
    ADD CONSTRAINT notifications_notifypolicy_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.notifications_notifypolicy DROP CONSTRAINT notifications_notifypolicy_pkey;
       public            taiga    false    232            w           2606    3598885 V   notifications_notifypolicy notifications_notifypolicy_project_id_user_id_e7aa5cf2_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_notifypolicy
    ADD CONSTRAINT notifications_notifypolicy_project_id_user_id_e7aa5cf2_uniq UNIQUE (project_id, user_id);
 �   ALTER TABLE ONLY public.notifications_notifypolicy DROP CONSTRAINT notifications_notifypolicy_project_id_user_id_e7aa5cf2_uniq;
       public            taiga    false    232    232            �           2606    3598874 R   notifications_watched notifications_watched_content_type_id_object_i_e7c27769_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watched_content_type_id_object_i_e7c27769_uniq UNIQUE (content_type_id, object_id, user_id, project_id);
 |   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watched_content_type_id_object_i_e7c27769_uniq;
       public            taiga    false    238    238    238    238            �           2606    3596662 0   notifications_watched notifications_watched_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watched_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watched_pkey;
       public            taiga    false    238            7           2606    3596676 @   notifications_webnotification notifications_webnotification_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.notifications_webnotification
    ADD CONSTRAINT notifications_webnotification_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.notifications_webnotification DROP CONSTRAINT notifications_webnotification_pkey;
       public            taiga    false    285            �           2606    3599823 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    355            �           2606    3599798 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    351            �           2606    3599807 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    353            �           2606    3599809 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    353    353    353            �           2606    3596820 ,   projects_epicstatus projects_epicstatus_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.projects_epicstatus
    ADD CONSTRAINT projects_epicstatus_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.projects_epicstatus DROP CONSTRAINT projects_epicstatus_pkey;
       public            taiga    false    244            �           2606    3597370 E   projects_epicstatus projects_epicstatus_project_id_name_b71c417e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_epicstatus
    ADD CONSTRAINT projects_epicstatus_project_id_name_b71c417e_uniq UNIQUE (project_id, name);
 o   ALTER TABLE ONLY public.projects_epicstatus DROP CONSTRAINT projects_epicstatus_project_id_name_b71c417e_uniq;
       public            taiga    false    244    244            �           2606    3597372 E   projects_epicstatus projects_epicstatus_project_id_slug_f67857e5_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_epicstatus
    ADD CONSTRAINT projects_epicstatus_project_id_slug_f67857e5_uniq UNIQUE (project_id, slug);
 o   ALTER TABLE ONLY public.projects_epicstatus DROP CONSTRAINT projects_epicstatus_project_id_slug_f67857e5_uniq;
       public            taiga    false    244    244            A           2606    3596898 0   projects_issueduedate projects_issueduedate_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.projects_issueduedate
    ADD CONSTRAINT projects_issueduedate_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.projects_issueduedate DROP CONSTRAINT projects_issueduedate_pkey;
       public            taiga    false    291            D           2606    3597449 I   projects_issueduedate projects_issueduedate_project_id_name_cba303bc_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_issueduedate
    ADD CONSTRAINT projects_issueduedate_project_id_name_cba303bc_uniq UNIQUE (project_id, name);
 s   ALTER TABLE ONLY public.projects_issueduedate DROP CONSTRAINT projects_issueduedate_project_id_name_cba303bc_uniq;
       public            taiga    false    291    291                       2606    3596910 .   projects_issuestatus projects_issuestatus_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.projects_issuestatus
    ADD CONSTRAINT projects_issuestatus_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.projects_issuestatus DROP CONSTRAINT projects_issuestatus_pkey;
       public            taiga    false    212                       2606    3597432 G   projects_issuestatus projects_issuestatus_project_id_name_a88dd6c0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuestatus
    ADD CONSTRAINT projects_issuestatus_project_id_name_a88dd6c0_uniq UNIQUE (project_id, name);
 q   ALTER TABLE ONLY public.projects_issuestatus DROP CONSTRAINT projects_issuestatus_project_id_name_a88dd6c0_uniq;
       public            taiga    false    212    212                       2606    3597434 G   projects_issuestatus projects_issuestatus_project_id_slug_ca3e758d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuestatus
    ADD CONSTRAINT projects_issuestatus_project_id_slug_ca3e758d_uniq UNIQUE (project_id, slug);
 q   ALTER TABLE ONLY public.projects_issuestatus DROP CONSTRAINT projects_issuestatus_project_id_slug_ca3e758d_uniq;
       public            taiga    false    212    212            
           2606    3596992 *   projects_issuetype projects_issuetype_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.projects_issuetype
    ADD CONSTRAINT projects_issuetype_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.projects_issuetype DROP CONSTRAINT projects_issuetype_pkey;
       public            taiga    false    213                       2606    3597361 C   projects_issuetype projects_issuetype_project_id_name_41b47d87_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuetype
    ADD CONSTRAINT projects_issuetype_project_id_name_41b47d87_uniq UNIQUE (project_id, name);
 m   ALTER TABLE ONLY public.projects_issuetype DROP CONSTRAINT projects_issuetype_project_id_name_41b47d87_uniq;
       public            taiga    false    213    213            �           2606    3597068 ,   projects_membership projects_membership_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_pkey;
       public            taiga    false    210            �           2606    3598686 H   projects_membership projects_membership_user_id_project_id_a2829f61_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_user_id_project_id_a2829f61_uniq UNIQUE (user_id, project_id);
 r   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_user_id_project_id_a2829f61_uniq;
       public            taiga    false    210    210                       2606    3597086 $   projects_points projects_points_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.projects_points
    ADD CONSTRAINT projects_points_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.projects_points DROP CONSTRAINT projects_points_pkey;
       public            taiga    false    214                       2606    3597326 =   projects_points projects_points_project_id_name_900c69f4_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_points
    ADD CONSTRAINT projects_points_project_id_name_900c69f4_uniq UNIQUE (project_id, name);
 g   ALTER TABLE ONLY public.projects_points DROP CONSTRAINT projects_points_project_id_name_900c69f4_uniq;
       public            taiga    false    214    214                       2606    3597154 (   projects_priority projects_priority_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.projects_priority
    ADD CONSTRAINT projects_priority_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.projects_priority DROP CONSTRAINT projects_priority_pkey;
       public            taiga    false    215                       2606    3597290 A   projects_priority projects_priority_project_id_name_ca316bb1_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_priority
    ADD CONSTRAINT projects_priority_project_id_name_ca316bb1_uniq UNIQUE (project_id, name);
 k   ALTER TABLE ONLY public.projects_priority DROP CONSTRAINT projects_priority_project_id_name_ca316bb1_uniq;
       public            taiga    false    215    215            �           2606    3596837 <   projects_project projects_project_default_epic_status_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_epic_status_id_key UNIQUE (default_epic_status_id);
 f   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_epic_status_id_key;
       public            taiga    false    211            �           2606    3596927 =   projects_project projects_project_default_issue_status_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_issue_status_id_key UNIQUE (default_issue_status_id);
 g   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_issue_status_id_key;
       public            taiga    false    211            �           2606    3597003 ;   projects_project projects_project_default_issue_type_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_issue_type_id_key UNIQUE (default_issue_type_id);
 e   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_issue_type_id_key;
       public            taiga    false    211            �           2606    3597097 7   projects_project projects_project_default_points_id_key 
   CONSTRAINT        ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_points_id_key UNIQUE (default_points_id);
 a   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_points_id_key;
       public            taiga    false    211            �           2606    3597165 9   projects_project projects_project_default_priority_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_priority_id_key UNIQUE (default_priority_id);
 c   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_priority_id_key;
       public            taiga    false    211            �           2606    3597941 9   projects_project projects_project_default_severity_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_severity_id_key UNIQUE (default_severity_id);
 c   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_severity_id_key;
       public            taiga    false    211            �           2606    3598030 9   projects_project projects_project_default_swimlane_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_swimlane_id_key UNIQUE (default_swimlane_id);
 c   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_swimlane_id_key;
       public            taiga    false    211            �           2606    3598120 <   projects_project projects_project_default_task_status_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_task_status_id_key UNIQUE (default_task_status_id);
 f   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_task_status_id_key;
       public            taiga    false    211            �           2606    3598222 :   projects_project projects_project_default_us_status_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_us_status_id_key UNIQUE (default_us_status_id);
 d   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_us_status_id_key;
       public            taiga    false    211            �           2606    3597230 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    211            �           2606    3594490 *   projects_project projects_project_slug_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_slug_key UNIQUE (slug);
 T   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_slug_key;
       public            taiga    false    211            �           2606    3597855 @   projects_projectmodulesconfig projects_projectmodulesconfig_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.projects_projectmodulesconfig
    ADD CONSTRAINT projects_projectmodulesconfig_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.projects_projectmodulesconfig DROP CONSTRAINT projects_projectmodulesconfig_pkey;
       public            taiga    false    241            �           2606    3597422 J   projects_projectmodulesconfig projects_projectmodulesconfig_project_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmodulesconfig
    ADD CONSTRAINT projects_projectmodulesconfig_project_id_key UNIQUE (project_id);
 t   ALTER TABLE ONLY public.projects_projectmodulesconfig DROP CONSTRAINT projects_projectmodulesconfig_project_id_key;
       public            taiga    false    241                       2606    3597869 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    216                       2606    3594565 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    216                       2606    3597930 (   projects_severity projects_severity_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.projects_severity
    ADD CONSTRAINT projects_severity_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.projects_severity DROP CONSTRAINT projects_severity_pkey;
       public            taiga    false    217            !           2606    3597387 A   projects_severity projects_severity_project_id_name_6187c456_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_severity
    ADD CONSTRAINT projects_severity_project_id_name_6187c456_uniq UNIQUE (project_id, name);
 k   ALTER TABLE ONLY public.projects_severity DROP CONSTRAINT projects_severity_project_id_name_6187c456_uniq;
       public            taiga    false    217    217            P           2606    3598006 (   projects_swimlane projects_swimlane_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.projects_swimlane
    ADD CONSTRAINT projects_swimlane_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.projects_swimlane DROP CONSTRAINT projects_swimlane_pkey;
       public            taiga    false    294            S           2606    3597314 A   projects_swimlane projects_swimlane_project_id_name_a949892d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlane
    ADD CONSTRAINT projects_swimlane_project_id_name_a949892d_uniq UNIQUE (project_id, name);
 k   ALTER TABLE ONLY public.projects_swimlane DROP CONSTRAINT projects_swimlane_project_id_name_a949892d_uniq;
       public            taiga    false    294    294            U           2606    3598212 ]   projects_swimlaneuserstorystatus projects_swimlaneusersto_swimlane_id_status_id_d6ff394d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus
    ADD CONSTRAINT projects_swimlaneusersto_swimlane_id_status_id_d6ff394d_uniq UNIQUE (swimlane_id, status_id);
 �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus DROP CONSTRAINT projects_swimlaneusersto_swimlane_id_status_id_d6ff394d_uniq;
       public            taiga    false    295    295            W           2606    3598078 F   projects_swimlaneuserstorystatus projects_swimlaneuserstorystatus_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus
    ADD CONSTRAINT projects_swimlaneuserstorystatus_pkey PRIMARY KEY (id);
 p   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus DROP CONSTRAINT projects_swimlaneuserstorystatus_pkey;
       public            taiga    false    295            F           2606    3598091 .   projects_taskduedate projects_taskduedate_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.projects_taskduedate
    ADD CONSTRAINT projects_taskduedate_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.projects_taskduedate DROP CONSTRAINT projects_taskduedate_pkey;
       public            taiga    false    292            I           2606    3597396 G   projects_taskduedate projects_taskduedate_project_id_name_6270950e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskduedate
    ADD CONSTRAINT projects_taskduedate_project_id_name_6270950e_uniq UNIQUE (project_id, name);
 q   ALTER TABLE ONLY public.projects_taskduedate DROP CONSTRAINT projects_taskduedate_project_id_name_6270950e_uniq;
       public            taiga    false    292    292            #           2606    3598103 ,   projects_taskstatus projects_taskstatus_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.projects_taskstatus
    ADD CONSTRAINT projects_taskstatus_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.projects_taskstatus DROP CONSTRAINT projects_taskstatus_pkey;
       public            taiga    false    218            &           2606    3597405 E   projects_taskstatus projects_taskstatus_project_id_name_4b65b78f_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskstatus
    ADD CONSTRAINT projects_taskstatus_project_id_name_4b65b78f_uniq UNIQUE (project_id, name);
 o   ALTER TABLE ONLY public.projects_taskstatus DROP CONSTRAINT projects_taskstatus_project_id_name_4b65b78f_uniq;
       public            taiga    false    218    218            (           2606    3597407 E   projects_taskstatus projects_taskstatus_project_id_slug_30401ba3_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskstatus
    ADD CONSTRAINT projects_taskstatus_project_id_slug_30401ba3_uniq UNIQUE (project_id, slug);
 o   ALTER TABLE ONLY public.projects_taskstatus DROP CONSTRAINT projects_taskstatus_project_id_slug_30401ba3_uniq;
       public            taiga    false    218    218            K           2606    3598183 8   projects_userstoryduedate projects_userstoryduedate_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.projects_userstoryduedate
    ADD CONSTRAINT projects_userstoryduedate_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.projects_userstoryduedate DROP CONSTRAINT projects_userstoryduedate_pkey;
       public            taiga    false    293            N           2606    3597352 Q   projects_userstoryduedate projects_userstoryduedate_project_id_name_177c510a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstoryduedate
    ADD CONSTRAINT projects_userstoryduedate_project_id_name_177c510a_uniq UNIQUE (project_id, name);
 {   ALTER TABLE ONLY public.projects_userstoryduedate DROP CONSTRAINT projects_userstoryduedate_project_id_name_177c510a_uniq;
       public            taiga    false    293    293            ,           2606    3598195 6   projects_userstorystatus projects_userstorystatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_userstorystatus
    ADD CONSTRAINT projects_userstorystatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_userstorystatus DROP CONSTRAINT projects_userstorystatus_pkey;
       public            taiga    false    219            /           2606    3597335 O   projects_userstorystatus projects_userstorystatus_project_id_name_7c0a1351_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstorystatus
    ADD CONSTRAINT projects_userstorystatus_project_id_name_7c0a1351_uniq UNIQUE (project_id, name);
 y   ALTER TABLE ONLY public.projects_userstorystatus DROP CONSTRAINT projects_userstorystatus_project_id_name_7c0a1351_uniq;
       public            taiga    false    219    219            1           2606    3597337 O   projects_userstorystatus projects_userstorystatus_project_id_slug_97a888b5_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstorystatus
    ADD CONSTRAINT projects_userstorystatus_project_id_slug_97a888b5_uniq UNIQUE (project_id, slug);
 y   ALTER TABLE ONLY public.projects_userstorystatus DROP CONSTRAINT projects_userstorystatus_project_id_slug_97a888b5_uniq;
       public            taiga    false    219    219            \           2606    3598313 .   references_reference references_reference_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.references_reference
    ADD CONSTRAINT references_reference_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.references_reference DROP CONSTRAINT references_reference_pkey;
       public            taiga    false    313            _           2606    3598298 F   references_reference references_reference_project_id_ref_82d64d63_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.references_reference
    ADD CONSTRAINT references_reference_project_id_ref_82d64d63_uniq UNIQUE (project_id, ref);
 p   ALTER TABLE ONLY public.references_reference DROP CONSTRAINT references_reference_project_id_ref_82d64d63_uniq;
       public            taiga    false    313    313            e           2606    3598358 >   settings_userprojectsettings settings_userprojectsettings_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.settings_userprojectsettings
    ADD CONSTRAINT settings_userprojectsettings_pkey PRIMARY KEY (id);
 h   ALTER TABLE ONLY public.settings_userprojectsettings DROP CONSTRAINT settings_userprojectsettings_pkey;
       public            taiga    false    316            h           2606    3599022 Z   settings_userprojectsettings settings_userprojectsettings_project_id_user_id_330ddee9_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.settings_userprojectsettings
    ADD CONSTRAINT settings_userprojectsettings_project_id_user_id_330ddee9_uniq UNIQUE (project_id, user_id);
 �   ALTER TABLE ONLY public.settings_userprojectsettings DROP CONSTRAINT settings_userprojectsettings_project_id_user_id_330ddee9_uniq;
       public            taiga    false    316    316            �           2606    3598400    tasks_task tasks_task_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_pkey;
       public            taiga    false    239            k           2606    3598445 <   telemetry_instancetelemetry telemetry_instancetelemetry_pkey 
   CONSTRAINT     z   ALTER TABLE ONLY public.telemetry_instancetelemetry
    ADD CONSTRAINT telemetry_instancetelemetry_pkey PRIMARY KEY (id);
 f   ALTER TABLE ONLY public.telemetry_instancetelemetry DROP CONSTRAINT telemetry_instancetelemetry_pkey;
       public            taiga    false    319            �           2606    3598475 (   timeline_timeline timeline_timeline_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.timeline_timeline
    ADD CONSTRAINT timeline_timeline_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.timeline_timeline DROP CONSTRAINT timeline_timeline_pkey;
       public            taiga    false    242            s           2606    3598516 B   token_denylist_denylistedtoken token_denylist_denylistedtoken_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_denylistedtoken
    ADD CONSTRAINT token_denylist_denylistedtoken_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.token_denylist_denylistedtoken DROP CONSTRAINT token_denylist_denylistedtoken_pkey;
       public            taiga    false    325            u           2606    3598518 J   token_denylist_denylistedtoken token_denylist_denylistedtoken_token_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_denylistedtoken
    ADD CONSTRAINT token_denylist_denylistedtoken_token_id_key UNIQUE (token_id);
 t   ALTER TABLE ONLY public.token_denylist_denylistedtoken DROP CONSTRAINT token_denylist_denylistedtoken_token_id_key;
       public            taiga    false    325            n           2606    3598508 G   token_denylist_outstandingtoken token_denylist_outstandingtoken_jti_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_outstandingtoken
    ADD CONSTRAINT token_denylist_outstandingtoken_jti_key UNIQUE (jti);
 q   ALTER TABLE ONLY public.token_denylist_outstandingtoken DROP CONSTRAINT token_denylist_outstandingtoken_jti_key;
       public            taiga    false    323            p           2606    3598506 D   token_denylist_outstandingtoken token_denylist_outstandingtoken_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_outstandingtoken
    ADD CONSTRAINT token_denylist_outstandingtoken_pkey PRIMARY KEY (id);
 n   ALTER TABLE ONLY public.token_denylist_outstandingtoken DROP CONSTRAINT token_denylist_outstandingtoken_pkey;
       public            taiga    false    323            �           2606    3595312 5   users_authdata users_authdata_key_value_7ee3acc9_uniq 
   CONSTRAINT     v   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_key_value_7ee3acc9_uniq UNIQUE (key, value);
 _   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_key_value_7ee3acc9_uniq;
       public            taiga    false    240    240            �           2606    3598576 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    240            �           2606    3598593    users_role users_role_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_role
    ADD CONSTRAINT users_role_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_role DROP CONSTRAINT users_role_pkey;
       public            taiga    false    209            �           2606    3597276 3   users_role users_role_slug_project_id_db8c270c_uniq 
   CONSTRAINT     z   ALTER TABLE ONLY public.users_role
    ADD CONSTRAINT users_role_slug_project_id_db8c270c_uniq UNIQUE (slug, project_id);
 ]   ALTER TABLE ONLY public.users_role DROP CONSTRAINT users_role_slug_project_id_db8c270c_uniq;
       public            taiga    false    209    209            �           2606    3594814 )   users_user users_user_email_243f6e77_uniq 
   CONSTRAINT     e   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_243f6e77_uniq UNIQUE (email);
 S   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_243f6e77_uniq;
       public            taiga    false    206            �           2606    3598644    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    206            �           2606    3594817 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    206            �           2606    3598546 (   users_user users_user_uuid_6fe513d7_uniq 
   CONSTRAINT     c   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_uuid_6fe513d7_uniq UNIQUE (uuid);
 R   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_uuid_6fe513d7_uniq;
       public            taiga    false    206            w           2606    3599169 ,   users_workspacerole users_workspacerole_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.users_workspacerole
    ADD CONSTRAINT users_workspacerole_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.users_workspacerole DROP CONSTRAINT users_workspacerole_pkey;
       public            taiga    false    326            {           2606    3599666 G   users_workspacerole users_workspacerole_slug_workspace_id_1c9aef12_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.users_workspacerole
    ADD CONSTRAINT users_workspacerole_slug_workspace_id_1c9aef12_uniq UNIQUE (slug, workspace_id);
 q   ALTER TABLE ONLY public.users_workspacerole DROP CONSTRAINT users_workspacerole_slug_workspace_id_1c9aef12_uniq;
       public            taiga    false    326    326                       2606    3599196 L   userstorage_storageentry userstorage_storageentry_owner_id_key_746399cb_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.userstorage_storageentry
    ADD CONSTRAINT userstorage_storageentry_owner_id_key_746399cb_uniq UNIQUE (owner_id, key);
 v   ALTER TABLE ONLY public.userstorage_storageentry DROP CONSTRAINT userstorage_storageentry_owner_id_key_746399cb_uniq;
       public            taiga    false    331    331            �           2606    3599214 6   userstorage_storageentry userstorage_storageentry_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.userstorage_storageentry
    ADD CONSTRAINT userstorage_storageentry_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.userstorage_storageentry DROP CONSTRAINT userstorage_storageentry_pkey;
       public            taiga    false    331            b           2606    3599306 2   userstories_rolepoints userstories_rolepoints_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_pkey;
       public            taiga    false    230            g           2606    3599341 Q   userstories_rolepoints userstories_rolepoints_user_story_id_role_id_dc0ba15e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_user_story_id_role_id_dc0ba15e_uniq UNIQUE (user_story_id, role_id);
 {   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_user_story_id_role_id_dc0ba15e_uniq;
       public            taiga    false    230    230            �           2606    3599352 `   userstories_userstory_assigned_users userstories_userstory_as_userstory_id_user_id_beae1231_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory_assigned_users
    ADD CONSTRAINT userstories_userstory_as_userstory_id_user_id_beae1231_uniq UNIQUE (userstory_id, user_id);
 �   ALTER TABLE ONLY public.userstories_userstory_assigned_users DROP CONSTRAINT userstories_userstory_as_userstory_id_user_id_beae1231_uniq;
       public            taiga    false    334    334            �           2606    3599277 N   userstories_userstory_assigned_users userstories_userstory_assigned_users_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory_assigned_users
    ADD CONSTRAINT userstories_userstory_assigned_users_pkey PRIMARY KEY (id);
 x   ALTER TABLE ONLY public.userstories_userstory_assigned_users DROP CONSTRAINT userstories_userstory_assigned_users_pkey;
       public            taiga    false    334            n           2606    3599320 0   userstories_userstory userstories_userstory_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_pkey;
       public            taiga    false    231            �           2606    3599440 E   votes_vote votes_vote_content_type_id_object_id_user_id_97d16fa0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.votes_vote
    ADD CONSTRAINT votes_vote_content_type_id_object_id_user_id_97d16fa0_uniq UNIQUE (content_type_id, object_id, user_id);
 o   ALTER TABLE ONLY public.votes_vote DROP CONSTRAINT votes_vote_content_type_id_object_id_user_id_97d16fa0_uniq;
       public            taiga    false    337    337    337            �           2606    3599462    votes_vote votes_vote_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.votes_vote
    ADD CONSTRAINT votes_vote_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.votes_vote DROP CONSTRAINT votes_vote_pkey;
       public            taiga    false    337            �           2606    3599438 ?   votes_votes votes_votes_content_type_id_object_id_5abfc91b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.votes_votes
    ADD CONSTRAINT votes_votes_content_type_id_object_id_5abfc91b_uniq UNIQUE (content_type_id, object_id);
 i   ALTER TABLE ONLY public.votes_votes DROP CONSTRAINT votes_votes_content_type_id_object_id_5abfc91b_uniq;
       public            taiga    false    338    338            �           2606    3599475    votes_votes votes_votes_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.votes_votes
    ADD CONSTRAINT votes_votes_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.votes_votes DROP CONSTRAINT votes_votes_pkey;
       public            taiga    false    338            �           2606    3599534 &   webhooks_webhook webhooks_webhook_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.webhooks_webhook
    ADD CONSTRAINT webhooks_webhook_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.webhooks_webhook DROP CONSTRAINT webhooks_webhook_pkey;
       public            taiga    false    341            �           2606    3599562 ,   webhooks_webhooklog webhooks_webhooklog_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.webhooks_webhooklog
    ADD CONSTRAINT webhooks_webhooklog_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.webhooks_webhooklog DROP CONSTRAINT webhooks_webhooklog_pkey;
       public            taiga    false    342            �           2606    3599587     wiki_wikilink wiki_wikilink_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.wiki_wikilink
    ADD CONSTRAINT wiki_wikilink_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.wiki_wikilink DROP CONSTRAINT wiki_wikilink_pkey;
       public            taiga    false    247            �           2606    3597603 9   wiki_wikilink wiki_wikilink_project_id_href_a39ae7e7_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikilink
    ADD CONSTRAINT wiki_wikilink_project_id_href_a39ae7e7_uniq UNIQUE (project_id, href);
 c   ALTER TABLE ONLY public.wiki_wikilink DROP CONSTRAINT wiki_wikilink_project_id_href_a39ae7e7_uniq;
       public            taiga    false    247    247            �           2606    3599604     wiki_wikipage wiki_wikipage_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_pkey;
       public            taiga    false    248            �           2606    3597617 9   wiki_wikipage wiki_wikipage_project_id_slug_cb5b63e2_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_project_id_slug_cb5b63e2_uniq UNIQUE (project_id, slug);
 c   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_project_id_slug_cb5b63e2_uniq;
       public            taiga    false    248    248            <           2606    3599652 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    290            ?           2606    3596698 2   workspaces_workspace workspaces_workspace_slug_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_slug_key UNIQUE (slug);
 \   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_slug_key;
       public            taiga    false    290            �           2606    3599721 Z   workspaces_workspacemembership workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq UNIQUE (user_id, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq;
       public            taiga    false    347    347            �           2606    3599748 B   workspaces_workspacemembership workspaces_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacemembership_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacemembership_pkey;
       public            taiga    false    347            4           1259    3594729 /   attachments_attachment_content_type_id_35dd9d5d    INDEX     }   CREATE INDEX attachments_attachment_content_type_id_35dd9d5d ON public.attachments_attachment USING btree (content_type_id);
 C   DROP INDEX public.attachments_attachment_content_type_id_35dd9d5d;
       public            taiga    false    220            5           1259    3594734 =   attachments_attachment_content_type_id_object_id_3f2e447c_idx    INDEX     �   CREATE INDEX attachments_attachment_content_type_id_object_id_3f2e447c_idx ON public.attachments_attachment USING btree (content_type_id, object_id);
 Q   DROP INDEX public.attachments_attachment_content_type_id_object_id_3f2e447c_idx;
       public            taiga    false    220    220            6           1259    3598754 (   attachments_attachment_owner_id_720defb8    INDEX     o   CREATE INDEX attachments_attachment_owner_id_720defb8 ON public.attachments_attachment USING btree (owner_id);
 <   DROP INDEX public.attachments_attachment_owner_id_720defb8;
       public            taiga    false    220            9           1259    3597457 *   attachments_attachment_project_id_50714f52    INDEX     s   CREATE INDEX attachments_attachment_project_id_50714f52 ON public.attachments_attachment USING btree (project_id);
 >   DROP INDEX public.attachments_attachment_project_id_50714f52;
       public            taiga    false    220            ?           1259    3594804    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    225            D           1259    3594800 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    227            G           1259    3594801 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    227            :           1259    3594786 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    223            �           1259    3597592 (   contact_contactentry_project_id_27bfec4e    INDEX     o   CREATE INDEX contact_contactentry_project_id_27bfec4e ON public.contact_contactentry USING btree (project_id);
 <   DROP INDEX public.contact_contactentry_project_id_27bfec4e;
       public            taiga    false    245            �           1259    3598934 %   contact_contactentry_user_id_f1f19c5f    INDEX     i   CREATE INDEX contact_contactentry_user_id_f1f19c5f ON public.contact_contactentry USING btree (user_id);
 9   DROP INDEX public.contact_contactentry_user_id_f1f19c5f;
       public            taiga    false    245                       1259    3596319 -   custom_attributes_epiccu_epic_id_d413e57a_idx    INDEX     �   CREATE INDEX custom_attributes_epiccu_epic_id_d413e57a_idx ON public.custom_attributes_epiccustomattributesvalues USING btree (epic_id);
 A   DROP INDEX public.custom_attributes_epiccu_epic_id_d413e57a_idx;
       public            taiga    false    259                       1259    3597647 9   custom_attributes_epiccustomattribute_project_id_ad2cfaa8    INDEX     �   CREATE INDEX custom_attributes_epiccustomattribute_project_id_ad2cfaa8 ON public.custom_attributes_epiccustomattribute USING btree (project_id);
 M   DROP INDEX public.custom_attributes_epiccustomattribute_project_id_ad2cfaa8;
       public            taiga    false    258            �           1259    3596479 .   custom_attributes_issuec_issue_id_868161f8_idx    INDEX     �   CREATE INDEX custom_attributes_issuec_issue_id_868161f8_idx ON public.custom_attributes_issuecustomattributesvalues USING btree (issue_id);
 B   DROP INDEX public.custom_attributes_issuec_issue_id_868161f8_idx;
       public            taiga    false    255            �           1259    3597671 :   custom_attributes_issuecustomattribute_project_id_3b4acff5    INDEX     �   CREATE INDEX custom_attributes_issuecustomattribute_project_id_3b4acff5 ON public.custom_attributes_issuecustomattribute USING btree (project_id);
 N   DROP INDEX public.custom_attributes_issuecustomattribute_project_id_3b4acff5;
       public            taiga    false    252            �           1259    3598420 -   custom_attributes_taskcu_task_id_3d1ccf5e_idx    INDEX     �   CREATE INDEX custom_attributes_taskcu_task_id_3d1ccf5e_idx ON public.custom_attributes_taskcustomattributesvalues USING btree (task_id);
 A   DROP INDEX public.custom_attributes_taskcu_task_id_3d1ccf5e_idx;
       public            taiga    false    256            �           1259    3597659 9   custom_attributes_taskcustomattribute_project_id_f0f622a8    INDEX     �   CREATE INDEX custom_attributes_taskcustomattribute_project_id_f0f622a8 ON public.custom_attributes_taskcustomattribute USING btree (project_id);
 M   DROP INDEX public.custom_attributes_taskcustomattribute_project_id_f0f622a8;
       public            taiga    false    253                       1259    3599388 3   custom_attributes_userst_user_story_id_99b10c43_idx    INDEX     �   CREATE INDEX custom_attributes_userst_user_story_id_99b10c43_idx ON public.custom_attributes_userstorycustomattributesvalues USING btree (user_story_id);
 G   DROP INDEX public.custom_attributes_userst_user_story_id_99b10c43_idx;
       public            taiga    false    257            �           1259    3597683 >   custom_attributes_userstorycustomattribute_project_id_2619cf6c    INDEX     �   CREATE INDEX custom_attributes_userstorycustomattribute_project_id_2619cf6c ON public.custom_attributes_userstorycustomattribute USING btree (project_id);
 R   DROP INDEX public.custom_attributes_userstorycustomattribute_project_id_2619cf6c;
       public            taiga    false    254            �           1259    3594453 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    208            �           1259    3598675 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    208            `           1259    3598333 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    315            c           1259    3598332 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    315                       1259    3596216 !   djmail_message_uuid_8dad4f24_like    INDEX     p   CREATE INDEX djmail_message_uuid_8dad4f24_like ON public.djmail_message USING btree (uuid varchar_pattern_ops);
 5   DROP INDEX public.djmail_message_uuid_8dad4f24_like;
       public            taiga    false    268                       1259    3596239 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    270                       1259    3596240 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    270                       1259    3596237 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    270                       1259    3596238 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    270                       1259    3596248 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    272                       1259    3596249 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    272            "           1259    3596250 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    272            #           1259    3596246 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    272            $           1259    3596247 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    272            �           1259    3598972 "   epics_epic_assigned_to_id_13e08004    INDEX     c   CREATE INDEX epics_epic_assigned_to_id_13e08004 ON public.epics_epic USING btree (assigned_to_id);
 6   DROP INDEX public.epics_epic_assigned_to_id_13e08004;
       public            taiga    false    250            �           1259    3598985    epics_epic_owner_id_b09888c4    INDEX     W   CREATE INDEX epics_epic_owner_id_b09888c4 ON public.epics_epic USING btree (owner_id);
 0   DROP INDEX public.epics_epic_owner_id_b09888c4;
       public            taiga    false    250            �           1259    3597632    epics_epic_project_id_d98aaef7    INDEX     [   CREATE INDEX epics_epic_project_id_d98aaef7 ON public.epics_epic USING btree (project_id);
 2   DROP INDEX public.epics_epic_project_id_d98aaef7;
       public            taiga    false    250            �           1259    3595833    epics_epic_ref_aa52eb4a    INDEX     M   CREATE INDEX epics_epic_ref_aa52eb4a ON public.epics_epic USING btree (ref);
 +   DROP INDEX public.epics_epic_ref_aa52eb4a;
       public            taiga    false    250            �           1259    3596878    epics_epic_status_id_4cf3af1a    INDEX     Y   CREATE INDEX epics_epic_status_id_4cf3af1a ON public.epics_epic USING btree (status_id);
 1   DROP INDEX public.epics_epic_status_id_4cf3af1a;
       public            taiga    false    250            �           1259    3596309 '   epics_relateduserstory_epic_id_57605230    INDEX     m   CREATE INDEX epics_relateduserstory_epic_id_57605230 ON public.epics_relateduserstory USING btree (epic_id);
 ;   DROP INDEX public.epics_relateduserstory_epic_id_57605230;
       public            taiga    false    251            �           1259    3599378 -   epics_relateduserstory_user_story_id_329a951c    INDEX     y   CREATE INDEX epics_relateduserstory_user_story_id_329a951c ON public.epics_relateduserstory USING btree (user_story_id);
 A   DROP INDEX public.epics_relateduserstory_user_story_id_329a951c;
       public            taiga    false    251            )           1259    3596373 *   external_apps_application_id_e9988cf8_like    INDEX     �   CREATE INDEX external_apps_application_id_e9988cf8_like ON public.external_apps_application USING btree (id varchar_pattern_ops);
 >   DROP INDEX public.external_apps_application_id_e9988cf8_like;
       public            taiga    false    277            .           1259    3596384 6   external_apps_applicationtoken_application_id_0e934655    INDEX     �   CREATE INDEX external_apps_applicationtoken_application_id_0e934655 ON public.external_apps_applicationtoken USING btree (application_id);
 J   DROP INDEX public.external_apps_applicationtoken_application_id_0e934655;
       public            taiga    false    278            /           1259    3596385 ;   external_apps_applicationtoken_application_id_0e934655_like    INDEX     �   CREATE INDEX external_apps_applicationtoken_application_id_0e934655_like ON public.external_apps_applicationtoken USING btree (application_id varchar_pattern_ops);
 O   DROP INDEX public.external_apps_applicationtoken_application_id_0e934655_like;
       public            taiga    false    278            2           1259    3599000 /   external_apps_applicationtoken_user_id_6e2f1e8a    INDEX     }   CREATE INDEX external_apps_applicationtoken_user_id_6e2f1e8a ON public.external_apps_applicationtoken USING btree (user_id);
 C   DROP INDEX public.external_apps_applicationtoken_user_id_6e2f1e8a;
       public            taiga    false    278            �           1259    3595769 %   history_historyentry_id_ff18cc9f_like    INDEX     x   CREATE INDEX history_historyentry_id_ff18cc9f_like ON public.history_historyentry USING btree (id varchar_pattern_ops);
 9   DROP INDEX public.history_historyentry_id_ff18cc9f_like;
       public            taiga    false    249            �           1259    3595770 !   history_historyentry_key_c088c4ae    INDEX     a   CREATE INDEX history_historyentry_key_c088c4ae ON public.history_historyentry USING btree (key);
 5   DROP INDEX public.history_historyentry_key_c088c4ae;
       public            taiga    false    249            �           1259    3595771 &   history_historyentry_key_c088c4ae_like    INDEX     z   CREATE INDEX history_historyentry_key_c088c4ae_like ON public.history_historyentry USING btree (key varchar_pattern_ops);
 :   DROP INDEX public.history_historyentry_key_c088c4ae_like;
       public            taiga    false    249            �           1259    3597549 (   history_historyentry_project_id_9b008f70    INDEX     o   CREATE INDEX history_historyentry_project_id_9b008f70 ON public.history_historyentry USING btree (project_id);
 <   DROP INDEX public.history_historyentry_project_id_9b008f70;
       public            taiga    false    249            V           1259    3598779 $   issues_issue_assigned_to_id_c6054289    INDEX     g   CREATE INDEX issues_issue_assigned_to_id_c6054289 ON public.issues_issue USING btree (assigned_to_id);
 8   DROP INDEX public.issues_issue_assigned_to_id_c6054289;
       public            taiga    false    229            W           1259    3596530 "   issues_issue_milestone_id_3c2695ee    INDEX     c   CREATE INDEX issues_issue_milestone_id_3c2695ee ON public.issues_issue USING btree (milestone_id);
 6   DROP INDEX public.issues_issue_milestone_id_3c2695ee;
       public            taiga    false    229            X           1259    3598796    issues_issue_owner_id_5c361b47    INDEX     [   CREATE INDEX issues_issue_owner_id_5c361b47 ON public.issues_issue USING btree (owner_id);
 2   DROP INDEX public.issues_issue_owner_id_5c361b47;
       public            taiga    false    229            [           1259    3597206 !   issues_issue_priority_id_93842a93    INDEX     a   CREATE INDEX issues_issue_priority_id_93842a93 ON public.issues_issue USING btree (priority_id);
 5   DROP INDEX public.issues_issue_priority_id_93842a93;
       public            taiga    false    229            \           1259    3597486     issues_issue_project_id_4b0f3e2f    INDEX     _   CREATE INDEX issues_issue_project_id_4b0f3e2f ON public.issues_issue USING btree (project_id);
 4   DROP INDEX public.issues_issue_project_id_4b0f3e2f;
       public            taiga    false    229            ]           1259    3594931    issues_issue_ref_4c1e7f8f    INDEX     Q   CREATE INDEX issues_issue_ref_4c1e7f8f ON public.issues_issue USING btree (ref);
 -   DROP INDEX public.issues_issue_ref_4c1e7f8f;
       public            taiga    false    229            ^           1259    3597982 !   issues_issue_severity_id_695dade0    INDEX     a   CREATE INDEX issues_issue_severity_id_695dade0 ON public.issues_issue USING btree (severity_id);
 5   DROP INDEX public.issues_issue_severity_id_695dade0;
       public            taiga    false    229            _           1259    3596968    issues_issue_status_id_64473cf1    INDEX     ]   CREATE INDEX issues_issue_status_id_64473cf1 ON public.issues_issue USING btree (status_id);
 3   DROP INDEX public.issues_issue_status_id_64473cf1;
       public            taiga    false    229            `           1259    3597044    issues_issue_type_id_c1063362    INDEX     Y   CREATE INDEX issues_issue_type_id_c1063362 ON public.issues_issue USING btree (type_id);
 1   DROP INDEX public.issues_issue_type_id_c1063362;
       public            taiga    false    229            �           1259    3595476 #   likes_like_content_type_id_8ffc2116    INDEX     e   CREATE INDEX likes_like_content_type_id_8ffc2116 ON public.likes_like USING btree (content_type_id);
 7   DROP INDEX public.likes_like_content_type_id_8ffc2116;
       public            taiga    false    243            �           1259    3598926    likes_like_user_id_aae4c421    INDEX     U   CREATE INDEX likes_like_user_id_aae4c421 ON public.likes_like USING btree (user_id);
 /   DROP INDEX public.likes_like_user_id_aae4c421;
       public            taiga    false    243            J           1259    3594852 "   milestones_milestone_name_23fb0698    INDEX     c   CREATE INDEX milestones_milestone_name_23fb0698 ON public.milestones_milestone USING btree (name);
 6   DROP INDEX public.milestones_milestone_name_23fb0698;
       public            taiga    false    228            K           1259    3594853 '   milestones_milestone_name_23fb0698_like    INDEX     |   CREATE INDEX milestones_milestone_name_23fb0698_like ON public.milestones_milestone USING btree (name varchar_pattern_ops);
 ;   DROP INDEX public.milestones_milestone_name_23fb0698_like;
       public            taiga    false    228            N           1259    3598766 &   milestones_milestone_owner_id_216ba23b    INDEX     k   CREATE INDEX milestones_milestone_owner_id_216ba23b ON public.milestones_milestone USING btree (owner_id);
 :   DROP INDEX public.milestones_milestone_owner_id_216ba23b;
       public            taiga    false    228            Q           1259    3597473 (   milestones_milestone_project_id_6151cb75    INDEX     o   CREATE INDEX milestones_milestone_project_id_6151cb75 ON public.milestones_milestone USING btree (project_id);
 <   DROP INDEX public.milestones_milestone_project_id_6151cb75;
       public            taiga    false    228            R           1259    3594854 "   milestones_milestone_slug_08e5995e    INDEX     c   CREATE INDEX milestones_milestone_slug_08e5995e ON public.milestones_milestone USING btree (slug);
 6   DROP INDEX public.milestones_milestone_slug_08e5995e;
       public            taiga    false    228            S           1259    3594855 '   milestones_milestone_slug_08e5995e_like    INDEX     |   CREATE INDEX milestones_milestone_slug_08e5995e_like ON public.milestones_milestone USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.milestones_milestone_slug_08e5995e_like;
       public            taiga    false    228            �           1259    3595177 6   notifications_historycha_historyentry_id_ad550852_like    INDEX     �   CREATE INDEX notifications_historycha_historyentry_id_ad550852_like ON public.notifications_historychangenotification_history_entries USING btree (historyentry_id varchar_pattern_ops);
 J   DROP INDEX public.notifications_historycha_historyentry_id_ad550852_like;
       public            taiga    false    235            �           1259    3596628 >   notifications_historychang_historychangenotification__65e52ffd    INDEX     �   CREATE INDEX notifications_historychang_historychangenotification__65e52ffd ON public.notifications_historychangenotification_history_entries USING btree (historychangenotification_id);
 R   DROP INDEX public.notifications_historychang_historychangenotification__65e52ffd;
       public            taiga    false    235            �           1259    3596639 >   notifications_historychang_historychangenotification__d8e98e97    INDEX     �   CREATE INDEX notifications_historychang_historychangenotification__d8e98e97 ON public.notifications_historychangenotification_notify_users USING btree (historychangenotification_id);
 R   DROP INDEX public.notifications_historychang_historychangenotification__d8e98e97;
       public            taiga    false    237            �           1259    3595176 3   notifications_historychang_historyentry_id_ad550852    INDEX     �   CREATE INDEX notifications_historychang_historyentry_id_ad550852 ON public.notifications_historychangenotification_history_entries USING btree (historyentry_id);
 G   DROP INDEX public.notifications_historychang_historyentry_id_ad550852;
       public            taiga    false    235            �           1259    3598845 +   notifications_historychang_user_id_f7bd2448    INDEX     �   CREATE INDEX notifications_historychang_user_id_f7bd2448 ON public.notifications_historychangenotification_notify_users USING btree (user_id);
 ?   DROP INDEX public.notifications_historychang_user_id_f7bd2448;
       public            taiga    false    237            {           1259    3598855 9   notifications_historychangenotification_owner_id_6f63be8a    INDEX     �   CREATE INDEX notifications_historychangenotification_owner_id_6f63be8a ON public.notifications_historychangenotification USING btree (owner_id);
 M   DROP INDEX public.notifications_historychangenotification_owner_id_6f63be8a;
       public            taiga    false    233            ~           1259    3597520 ;   notifications_historychangenotification_project_id_52cf5e2b    INDEX     �   CREATE INDEX notifications_historychangenotification_project_id_52cf5e2b ON public.notifications_historychangenotification USING btree (project_id);
 O   DROP INDEX public.notifications_historychangenotification_project_id_52cf5e2b;
       public            taiga    false    233            u           1259    3597541 .   notifications_notifypolicy_project_id_aa5da43f    INDEX     {   CREATE INDEX notifications_notifypolicy_project_id_aa5da43f ON public.notifications_notifypolicy USING btree (project_id);
 B   DROP INDEX public.notifications_notifypolicy_project_id_aa5da43f;
       public            taiga    false    232            x           1259    3598886 +   notifications_notifypolicy_user_id_2902cbeb    INDEX     u   CREATE INDEX notifications_notifypolicy_user_id_2902cbeb ON public.notifications_notifypolicy USING btree (user_id);
 ?   DROP INDEX public.notifications_notifypolicy_user_id_2902cbeb;
       public            taiga    false    232            �           1259    3595220 .   notifications_watched_content_type_id_7b3ab729    INDEX     {   CREATE INDEX notifications_watched_content_type_id_7b3ab729 ON public.notifications_watched USING btree (content_type_id);
 B   DROP INDEX public.notifications_watched_content_type_id_7b3ab729;
       public            taiga    false    238            �           1259    3597530 )   notifications_watched_project_id_c88baa46    INDEX     q   CREATE INDEX notifications_watched_project_id_c88baa46 ON public.notifications_watched USING btree (project_id);
 =   DROP INDEX public.notifications_watched_project_id_c88baa46;
       public            taiga    false    238            �           1259    3598875 &   notifications_watched_user_id_1bce1955    INDEX     k   CREATE INDEX notifications_watched_user_id_1bce1955 ON public.notifications_watched USING btree (user_id);
 :   DROP INDEX public.notifications_watched_user_id_1bce1955;
       public            taiga    false    238            5           1259    3596611 .   notifications_webnotification_created_b17f50f8    INDEX     {   CREATE INDEX notifications_webnotification_created_b17f50f8 ON public.notifications_webnotification USING btree (created);
 B   DROP INDEX public.notifications_webnotification_created_b17f50f8;
       public            taiga    false    285            8           1259    3598863 .   notifications_webnotification_user_id_f32287d5    INDEX     {   CREATE INDEX notifications_webnotification_user_id_f32287d5 ON public.notifications_webnotification USING btree (user_id);
 B   DROP INDEX public.notifications_webnotification_user_id_f32287d5;
       public            taiga    false    285            �           1259    3599833     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    355            �           1259    3599832    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    1182    351    351    351            �           1259    3599830    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    351    1182    351            �           1259    3599831 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    351            �           1259    3599829 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    351    1182    351            �           1259    3599834 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    353            �           1259    3597373 '   projects_epicstatus_project_id_d2c43c29    INDEX     m   CREATE INDEX projects_epicstatus_project_id_d2c43c29 ON public.projects_epicstatus USING btree (project_id);
 ;   DROP INDEX public.projects_epicstatus_project_id_d2c43c29;
       public            taiga    false    244            �           1259    3595580 !   projects_epicstatus_slug_63c476c8    INDEX     a   CREATE INDEX projects_epicstatus_slug_63c476c8 ON public.projects_epicstatus USING btree (slug);
 5   DROP INDEX public.projects_epicstatus_slug_63c476c8;
       public            taiga    false    244            �           1259    3595581 &   projects_epicstatus_slug_63c476c8_like    INDEX     z   CREATE INDEX projects_epicstatus_slug_63c476c8_like ON public.projects_epicstatus USING btree (slug varchar_pattern_ops);
 :   DROP INDEX public.projects_epicstatus_slug_63c476c8_like;
       public            taiga    false    244            B           1259    3597450 )   projects_issueduedate_project_id_ec077eb7    INDEX     q   CREATE INDEX projects_issueduedate_project_id_ec077eb7 ON public.projects_issueduedate USING btree (project_id);
 =   DROP INDEX public.projects_issueduedate_project_id_ec077eb7;
       public            taiga    false    291                       1259    3597435 (   projects_issuestatus_project_id_1988ebf4    INDEX     o   CREATE INDEX projects_issuestatus_project_id_1988ebf4 ON public.projects_issuestatus USING btree (project_id);
 <   DROP INDEX public.projects_issuestatus_project_id_1988ebf4;
       public            taiga    false    212                       1259    3595353 "   projects_issuestatus_slug_2c528947    INDEX     c   CREATE INDEX projects_issuestatus_slug_2c528947 ON public.projects_issuestatus USING btree (slug);
 6   DROP INDEX public.projects_issuestatus_slug_2c528947;
       public            taiga    false    212                       1259    3595354 '   projects_issuestatus_slug_2c528947_like    INDEX     |   CREATE INDEX projects_issuestatus_slug_2c528947_like ON public.projects_issuestatus USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.projects_issuestatus_slug_2c528947_like;
       public            taiga    false    212                       1259    3597362 &   projects_issuetype_project_id_e831e4ae    INDEX     k   CREATE INDEX projects_issuetype_project_id_e831e4ae ON public.projects_issuetype USING btree (project_id);
 :   DROP INDEX public.projects_issuetype_project_id_e831e4ae;
       public            taiga    false    213            �           1259    3598700 *   projects_membership_invited_by_id_a2c6c913    INDEX     s   CREATE INDEX projects_membership_invited_by_id_a2c6c913 ON public.projects_membership USING btree (invited_by_id);
 >   DROP INDEX public.projects_membership_invited_by_id_a2c6c913;
       public            taiga    false    210            �           1259    3597300 '   projects_membership_project_id_5f65bf3f    INDEX     m   CREATE INDEX projects_membership_project_id_5f65bf3f ON public.projects_membership USING btree (project_id);
 ;   DROP INDEX public.projects_membership_project_id_5f65bf3f;
       public            taiga    false    210            �           1259    3598608 $   projects_membership_role_id_c4bd36ef    INDEX     g   CREATE INDEX projects_membership_role_id_c4bd36ef ON public.projects_membership USING btree (role_id);
 8   DROP INDEX public.projects_membership_role_id_c4bd36ef;
       public            taiga    false    210            �           1259    3598687 $   projects_membership_user_id_13374535    INDEX     g   CREATE INDEX projects_membership_user_id_13374535 ON public.projects_membership USING btree (user_id);
 8   DROP INDEX public.projects_membership_user_id_13374535;
       public            taiga    false    210                       1259    3597327 #   projects_points_project_id_3b8f7b42    INDEX     e   CREATE INDEX projects_points_project_id_3b8f7b42 ON public.projects_points USING btree (project_id);
 7   DROP INDEX public.projects_points_project_id_3b8f7b42;
       public            taiga    false    214                       1259    3597291 %   projects_priority_project_id_936c75b2    INDEX     i   CREATE INDEX projects_priority_project_id_936c75b2 ON public.projects_priority USING btree (project_id);
 9   DROP INDEX public.projects_priority_project_id_936c75b2;
       public            taiga    false    215            �           1259    3597882 .   projects_project_creation_template_id_b5a97819    INDEX     {   CREATE INDEX projects_project_creation_template_id_b5a97819 ON public.projects_project USING btree (creation_template_id);
 B   DROP INDEX public.projects_project_creation_template_id_b5a97819;
       public            taiga    false    211            �           1259    3595583 (   projects_project_epics_csv_uuid_cb50f2ee    INDEX     o   CREATE INDEX projects_project_epics_csv_uuid_cb50f2ee ON public.projects_project USING btree (epics_csv_uuid);
 <   DROP INDEX public.projects_project_epics_csv_uuid_cb50f2ee;
       public            taiga    false    211            �           1259    3595584 -   projects_project_epics_csv_uuid_cb50f2ee_like    INDEX     �   CREATE INDEX projects_project_epics_csv_uuid_cb50f2ee_like ON public.projects_project USING btree (epics_csv_uuid varchar_pattern_ops);
 A   DROP INDEX public.projects_project_epics_csv_uuid_cb50f2ee_like;
       public            taiga    false    211            �           1259    3595387 )   projects_project_issues_csv_uuid_e6a84723    INDEX     q   CREATE INDEX projects_project_issues_csv_uuid_e6a84723 ON public.projects_project USING btree (issues_csv_uuid);
 =   DROP INDEX public.projects_project_issues_csv_uuid_e6a84723;
       public            taiga    false    211            �           1259    3595388 .   projects_project_issues_csv_uuid_e6a84723_like    INDEX     �   CREATE INDEX projects_project_issues_csv_uuid_e6a84723_like ON public.projects_project USING btree (issues_csv_uuid varchar_pattern_ops);
 B   DROP INDEX public.projects_project_issues_csv_uuid_e6a84723_like;
       public            taiga    false    211            �           1259    3597231 %   projects_project_name_id_44f44a5f_idx    INDEX     f   CREATE INDEX projects_project_name_id_44f44a5f_idx ON public.projects_project USING btree (name, id);
 9   DROP INDEX public.projects_project_name_id_44f44a5f_idx;
       public            taiga    false    211    211            �           1259    3598713 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    211            �           1259    3594516 #   projects_project_slug_2d50067a_like    INDEX     t   CREATE INDEX projects_project_slug_2d50067a_like ON public.projects_project USING btree (slug varchar_pattern_ops);
 7   DROP INDEX public.projects_project_slug_2d50067a_like;
       public            taiga    false    211            �           1259    3595389 (   projects_project_tasks_csv_uuid_ecd0b1b5    INDEX     o   CREATE INDEX projects_project_tasks_csv_uuid_ecd0b1b5 ON public.projects_project USING btree (tasks_csv_uuid);
 <   DROP INDEX public.projects_project_tasks_csv_uuid_ecd0b1b5;
       public            taiga    false    211            �           1259    3595390 -   projects_project_tasks_csv_uuid_ecd0b1b5_like    INDEX     �   CREATE INDEX projects_project_tasks_csv_uuid_ecd0b1b5_like ON public.projects_project USING btree (tasks_csv_uuid varchar_pattern_ops);
 A   DROP INDEX public.projects_project_tasks_csv_uuid_ecd0b1b5_like;
       public            taiga    false    211            �           1259    3596707    projects_project_textquery_idx    INDEX     �  CREATE INDEX projects_project_textquery_idx ON public.projects_project USING gin ((((setweight(to_tsvector('simple'::regconfig, (COALESCE(name, ''::character varying))::text), 'A'::"char") || setweight(to_tsvector('simple'::regconfig, COALESCE(public.inmutable_array_to_string(tags), ''::text)), 'B'::"char")) || setweight(to_tsvector('simple'::regconfig, COALESCE(description, ''::text)), 'C'::"char"))));
 2   DROP INDEX public.projects_project_textquery_idx;
       public            taiga    false    211    211    211    211    401            �           1259    3595501 (   projects_project_total_activity_edf1a486    INDEX     o   CREATE INDEX projects_project_total_activity_edf1a486 ON public.projects_project USING btree (total_activity);
 <   DROP INDEX public.projects_project_total_activity_edf1a486;
       public            taiga    false    211            �           1259    3595502 3   projects_project_total_activity_last_month_669bff3e    INDEX     �   CREATE INDEX projects_project_total_activity_last_month_669bff3e ON public.projects_project USING btree (total_activity_last_month);
 G   DROP INDEX public.projects_project_total_activity_last_month_669bff3e;
       public            taiga    false    211            �           1259    3595503 2   projects_project_total_activity_last_week_961ca1b0    INDEX     �   CREATE INDEX projects_project_total_activity_last_week_961ca1b0 ON public.projects_project USING btree (total_activity_last_week);
 F   DROP INDEX public.projects_project_total_activity_last_week_961ca1b0;
       public            taiga    false    211            �           1259    3595504 2   projects_project_total_activity_last_year_12ea6dbe    INDEX     �   CREATE INDEX projects_project_total_activity_last_year_12ea6dbe ON public.projects_project USING btree (total_activity_last_year);
 F   DROP INDEX public.projects_project_total_activity_last_year_12ea6dbe;
       public            taiga    false    211            �           1259    3595505 $   projects_project_total_fans_436fe323    INDEX     g   CREATE INDEX projects_project_total_fans_436fe323 ON public.projects_project USING btree (total_fans);
 8   DROP INDEX public.projects_project_total_fans_436fe323;
       public            taiga    false    211            �           1259    3595506 /   projects_project_total_fans_last_month_455afdbb    INDEX     }   CREATE INDEX projects_project_total_fans_last_month_455afdbb ON public.projects_project USING btree (total_fans_last_month);
 C   DROP INDEX public.projects_project_total_fans_last_month_455afdbb;
       public            taiga    false    211            �           1259    3595507 .   projects_project_total_fans_last_week_c65146b1    INDEX     {   CREATE INDEX projects_project_total_fans_last_week_c65146b1 ON public.projects_project USING btree (total_fans_last_week);
 B   DROP INDEX public.projects_project_total_fans_last_week_c65146b1;
       public            taiga    false    211            �           1259    3595508 .   projects_project_total_fans_last_year_167b29c2    INDEX     {   CREATE INDEX projects_project_total_fans_last_year_167b29c2 ON public.projects_project USING btree (total_fans_last_year);
 B   DROP INDEX public.projects_project_total_fans_last_year_167b29c2;
       public            taiga    false    211            �           1259    3595509 1   projects_project_totals_updated_datetime_1bcc5bfa    INDEX     �   CREATE INDEX projects_project_totals_updated_datetime_1bcc5bfa ON public.projects_project USING btree (totals_updated_datetime);
 E   DROP INDEX public.projects_project_totals_updated_datetime_1bcc5bfa;
       public            taiga    false    211            �           1259    3595391 .   projects_project_userstories_csv_uuid_6e83c6c1    INDEX     {   CREATE INDEX projects_project_userstories_csv_uuid_6e83c6c1 ON public.projects_project USING btree (userstories_csv_uuid);
 B   DROP INDEX public.projects_project_userstories_csv_uuid_6e83c6c1;
       public            taiga    false    211            �           1259    3595392 3   projects_project_userstories_csv_uuid_6e83c6c1_like    INDEX     �   CREATE INDEX projects_project_userstories_csv_uuid_6e83c6c1_like ON public.projects_project USING btree (userstories_csv_uuid varchar_pattern_ops);
 G   DROP INDEX public.projects_project_userstories_csv_uuid_6e83c6c1_like;
       public            taiga    false    211            �           1259    3599679 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    211                       1259    3594682 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    216                       1259    3597388 %   projects_severity_project_id_9ab920cd    INDEX     i   CREATE INDEX projects_severity_project_id_9ab920cd ON public.projects_severity USING btree (project_id);
 9   DROP INDEX public.projects_severity_project_id_9ab920cd;
       public            taiga    false    217            Q           1259    3597315 %   projects_swimlane_project_id_06871cf8    INDEX     i   CREATE INDEX projects_swimlane_project_id_06871cf8 ON public.projects_swimlane USING btree (project_id);
 9   DROP INDEX public.projects_swimlane_project_id_06871cf8;
       public            taiga    false    294            X           1259    3598213 3   projects_swimlaneuserstorystatus_status_id_2f3fda91    INDEX     �   CREATE INDEX projects_swimlaneuserstorystatus_status_id_2f3fda91 ON public.projects_swimlaneuserstorystatus USING btree (status_id);
 G   DROP INDEX public.projects_swimlaneuserstorystatus_status_id_2f3fda91;
       public            taiga    false    295            Y           1259    3598021 5   projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21    INDEX     �   CREATE INDEX projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21 ON public.projects_swimlaneuserstorystatus USING btree (swimlane_id);
 I   DROP INDEX public.projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21;
       public            taiga    false    295            G           1259    3597397 (   projects_taskduedate_project_id_775d850d    INDEX     o   CREATE INDEX projects_taskduedate_project_id_775d850d ON public.projects_taskduedate USING btree (project_id);
 <   DROP INDEX public.projects_taskduedate_project_id_775d850d;
       public            taiga    false    292            $           1259    3597408 '   projects_taskstatus_project_id_8b32b2bb    INDEX     m   CREATE INDEX projects_taskstatus_project_id_8b32b2bb ON public.projects_taskstatus USING btree (project_id);
 ;   DROP INDEX public.projects_taskstatus_project_id_8b32b2bb;
       public            taiga    false    218            )           1259    3595355 !   projects_taskstatus_slug_cf358ffa    INDEX     a   CREATE INDEX projects_taskstatus_slug_cf358ffa ON public.projects_taskstatus USING btree (slug);
 5   DROP INDEX public.projects_taskstatus_slug_cf358ffa;
       public            taiga    false    218            *           1259    3595356 &   projects_taskstatus_slug_cf358ffa_like    INDEX     z   CREATE INDEX projects_taskstatus_slug_cf358ffa_like ON public.projects_taskstatus USING btree (slug varchar_pattern_ops);
 :   DROP INDEX public.projects_taskstatus_slug_cf358ffa_like;
       public            taiga    false    218            L           1259    3597353 -   projects_userstoryduedate_project_id_ab7b1680    INDEX     y   CREATE INDEX projects_userstoryduedate_project_id_ab7b1680 ON public.projects_userstoryduedate USING btree (project_id);
 A   DROP INDEX public.projects_userstoryduedate_project_id_ab7b1680;
       public            taiga    false    293            -           1259    3597338 ,   projects_userstorystatus_project_id_cdf95c9c    INDEX     w   CREATE INDEX projects_userstorystatus_project_id_cdf95c9c ON public.projects_userstorystatus USING btree (project_id);
 @   DROP INDEX public.projects_userstorystatus_project_id_cdf95c9c;
       public            taiga    false    219            2           1259    3595357 &   projects_userstorystatus_slug_d574ed51    INDEX     k   CREATE INDEX projects_userstorystatus_slug_d574ed51 ON public.projects_userstorystatus USING btree (slug);
 :   DROP INDEX public.projects_userstorystatus_slug_d574ed51;
       public            taiga    false    219            3           1259    3595358 +   projects_userstorystatus_slug_d574ed51_like    INDEX     �   CREATE INDEX projects_userstorystatus_slug_d574ed51_like ON public.projects_userstorystatus USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_userstorystatus_slug_d574ed51_like;
       public            taiga    false    219            Z           1259    3598309 -   references_reference_content_type_id_c134e05e    INDEX     y   CREATE INDEX references_reference_content_type_id_c134e05e ON public.references_reference USING btree (content_type_id);
 A   DROP INDEX public.references_reference_content_type_id_c134e05e;
       public            taiga    false    313            ]           1259    3598310 (   references_reference_project_id_00275368    INDEX     o   CREATE INDEX references_reference_project_id_00275368 ON public.references_reference USING btree (project_id);
 <   DROP INDEX public.references_reference_project_id_00275368;
       public            taiga    false    313            f           1259    3598354 0   settings_userprojectsettings_project_id_0bc686ce    INDEX        CREATE INDEX settings_userprojectsettings_project_id_0bc686ce ON public.settings_userprojectsettings USING btree (project_id);
 D   DROP INDEX public.settings_userprojectsettings_project_id_0bc686ce;
       public            taiga    false    316            i           1259    3599023 -   settings_userprojectsettings_user_id_0e7fdc25    INDEX     y   CREATE INDEX settings_userprojectsettings_user_id_0e7fdc25 ON public.settings_userprojectsettings USING btree (user_id);
 A   DROP INDEX public.settings_userprojectsettings_user_id_0e7fdc25;
       public            taiga    false    316            �           1259    3598894 "   tasks_task_assigned_to_id_e8821f61    INDEX     c   CREATE INDEX tasks_task_assigned_to_id_e8821f61 ON public.tasks_task USING btree (assigned_to_id);
 6   DROP INDEX public.tasks_task_assigned_to_id_e8821f61;
       public            taiga    false    239            �           1259    3596562     tasks_task_milestone_id_64cc568f    INDEX     _   CREATE INDEX tasks_task_milestone_id_64cc568f ON public.tasks_task USING btree (milestone_id);
 4   DROP INDEX public.tasks_task_milestone_id_64cc568f;
       public            taiga    false    239            �           1259    3598909    tasks_task_owner_id_db3dcc3e    INDEX     W   CREATE INDEX tasks_task_owner_id_db3dcc3e ON public.tasks_task USING btree (owner_id);
 0   DROP INDEX public.tasks_task_owner_id_db3dcc3e;
       public            taiga    false    239            �           1259    3597561    tasks_task_project_id_a2815f0c    INDEX     [   CREATE INDEX tasks_task_project_id_a2815f0c ON public.tasks_task USING btree (project_id);
 2   DROP INDEX public.tasks_task_project_id_a2815f0c;
       public            taiga    false    239            �           1259    3595272    tasks_task_ref_9f55bd37    INDEX     M   CREATE INDEX tasks_task_ref_9f55bd37 ON public.tasks_task USING btree (ref);
 +   DROP INDEX public.tasks_task_ref_9f55bd37;
       public            taiga    false    239            �           1259    3598161    tasks_task_status_id_899d2b90    INDEX     Y   CREATE INDEX tasks_task_status_id_899d2b90 ON public.tasks_task USING btree (status_id);
 1   DROP INDEX public.tasks_task_status_id_899d2b90;
       public            taiga    false    239            �           1259    3599361 !   tasks_task_user_story_id_47ceaf1d    INDEX     a   CREATE INDEX tasks_task_user_story_id_47ceaf1d ON public.tasks_task USING btree (user_story_id);
 5   DROP INDEX public.tasks_task_user_story_id_47ceaf1d;
       public            taiga    false    239            �           1259    3598472    timeline_ti_content_1af26f_idx    INDEX     �   CREATE INDEX timeline_ti_content_1af26f_idx ON public.timeline_timeline USING btree (content_type_id, object_id, created DESC);
 2   DROP INDEX public.timeline_ti_content_1af26f_idx;
       public            taiga    false    242    242    242            �           1259    3598471    timeline_ti_namespa_89bca1_idx    INDEX     o   CREATE INDEX timeline_ti_namespa_89bca1_idx ON public.timeline_timeline USING btree (namespace, created DESC);
 2   DROP INDEX public.timeline_ti_namespa_89bca1_idx;
       public            taiga    false    242    242            �           1259    3595427 *   timeline_timeline_content_type_id_5731a0c6    INDEX     s   CREATE INDEX timeline_timeline_content_type_id_5731a0c6 ON public.timeline_timeline USING btree (content_type_id);
 >   DROP INDEX public.timeline_timeline_content_type_id_5731a0c6;
       public            taiga    false    242            �           1259    3598453 "   timeline_timeline_created_4e9e3a68    INDEX     c   CREATE INDEX timeline_timeline_created_4e9e3a68 ON public.timeline_timeline USING btree (created);
 6   DROP INDEX public.timeline_timeline_created_4e9e3a68;
       public            taiga    false    242            �           1259    3595426 /   timeline_timeline_data_content_type_id_0689742e    INDEX     }   CREATE INDEX timeline_timeline_data_content_type_id_0689742e ON public.timeline_timeline USING btree (data_content_type_id);
 C   DROP INDEX public.timeline_timeline_data_content_type_id_0689742e;
       public            taiga    false    242            �           1259    3595428 %   timeline_timeline_event_type_cb2fcdb2    INDEX     i   CREATE INDEX timeline_timeline_event_type_cb2fcdb2 ON public.timeline_timeline USING btree (event_type);
 9   DROP INDEX public.timeline_timeline_event_type_cb2fcdb2;
       public            taiga    false    242            �           1259    3595429 *   timeline_timeline_event_type_cb2fcdb2_like    INDEX     �   CREATE INDEX timeline_timeline_event_type_cb2fcdb2_like ON public.timeline_timeline USING btree (event_type varchar_pattern_ops);
 >   DROP INDEX public.timeline_timeline_event_type_cb2fcdb2_like;
       public            taiga    false    242            �           1259    3595431 $   timeline_timeline_namespace_26f217ed    INDEX     g   CREATE INDEX timeline_timeline_namespace_26f217ed ON public.timeline_timeline USING btree (namespace);
 8   DROP INDEX public.timeline_timeline_namespace_26f217ed;
       public            taiga    false    242            �           1259    3595432 )   timeline_timeline_namespace_26f217ed_like    INDEX     �   CREATE INDEX timeline_timeline_namespace_26f217ed_like ON public.timeline_timeline USING btree (namespace varchar_pattern_ops);
 =   DROP INDEX public.timeline_timeline_namespace_26f217ed_like;
       public            taiga    false    242            �           1259    3597576 %   timeline_timeline_project_id_58d5eadd    INDEX     i   CREATE INDEX timeline_timeline_project_id_58d5eadd ON public.timeline_timeline USING btree (project_id);
 9   DROP INDEX public.timeline_timeline_project_id_58d5eadd;
       public            taiga    false    242            l           1259    3598524 1   token_denylist_outstandingtoken_jti_70fa66b5_like    INDEX     �   CREATE INDEX token_denylist_outstandingtoken_jti_70fa66b5_like ON public.token_denylist_outstandingtoken USING btree (jti varchar_pattern_ops);
 E   DROP INDEX public.token_denylist_outstandingtoken_jti_70fa66b5_like;
       public            taiga    false    323            q           1259    3599031 0   token_denylist_outstandingtoken_user_id_c6f48986    INDEX        CREATE INDEX token_denylist_outstandingtoken_user_id_c6f48986 ON public.token_denylist_outstandingtoken USING btree (user_id);
 D   DROP INDEX public.token_denylist_outstandingtoken_user_id_c6f48986;
       public            taiga    false    323            �           1259    3595318    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    240            �           1259    3595319     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    240            �           1259    3598663    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    240            �           1259    3597277    users_role_project_id_2837f877    INDEX     [   CREATE INDEX users_role_project_id_2837f877 ON public.users_role USING btree (project_id);
 2   DROP INDEX public.users_role_project_id_2837f877;
       public            taiga    false    209            �           1259    3594466    users_role_slug_ce33b471    INDEX     O   CREATE INDEX users_role_slug_ce33b471 ON public.users_role USING btree (slug);
 ,   DROP INDEX public.users_role_slug_ce33b471;
       public            taiga    false    209            �           1259    3594467    users_role_slug_ce33b471_like    INDEX     h   CREATE INDEX users_role_slug_ce33b471_like ON public.users_role USING btree (slug varchar_pattern_ops);
 1   DROP INDEX public.users_role_slug_ce33b471_like;
       public            taiga    false    209            �           1259    3594815    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    206            �           1259    3598542    users_user_upper_idx    INDEX     ^   CREATE INDEX users_user_upper_idx ON public.users_user USING btree (upper('username'::text));
 (   DROP INDEX public.users_user_upper_idx;
       public            taiga    false    206            �           1259    3598543    users_user_upper_idx1    INDEX     \   CREATE INDEX users_user_upper_idx1 ON public.users_user USING btree (upper('email'::text));
 )   DROP INDEX public.users_user_upper_idx1;
       public            taiga    false    206            �           1259    3594818 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    206            �           1259    3598547    users_user_uuid_6fe513d7_like    INDEX     h   CREATE INDEX users_user_uuid_6fe513d7_like ON public.users_user USING btree (uuid varchar_pattern_ops);
 1   DROP INDEX public.users_user_uuid_6fe513d7_like;
       public            taiga    false    206            x           1259    3598571 !   users_workspacerole_slug_2db99758    INDEX     a   CREATE INDEX users_workspacerole_slug_2db99758 ON public.users_workspacerole USING btree (slug);
 5   DROP INDEX public.users_workspacerole_slug_2db99758;
       public            taiga    false    326            y           1259    3598572 &   users_workspacerole_slug_2db99758_like    INDEX     z   CREATE INDEX users_workspacerole_slug_2db99758_like ON public.users_workspacerole USING btree (slug varchar_pattern_ops);
 :   DROP INDEX public.users_workspacerole_slug_2db99758_like;
       public            taiga    false    326            |           1259    3599667 )   users_workspacerole_workspace_id_30155f00    INDEX     q   CREATE INDEX users_workspacerole_workspace_id_30155f00 ON public.users_workspacerole USING btree (workspace_id);
 =   DROP INDEX public.users_workspacerole_workspace_id_30155f00;
       public            taiga    false    326            }           1259    3599202 *   userstorage_storageentry_owner_id_c4c1ffc0    INDEX     s   CREATE INDEX userstorage_storageentry_owner_id_c4c1ffc0 ON public.userstorage_storageentry USING btree (owner_id);
 >   DROP INDEX public.userstorage_storageentry_owner_id_c4c1ffc0;
       public            taiga    false    331            c           1259    3597138 )   userstories_rolepoints_points_id_cfcc5a79    INDEX     q   CREATE INDEX userstories_rolepoints_points_id_cfcc5a79 ON public.userstories_rolepoints USING btree (points_id);
 =   DROP INDEX public.userstories_rolepoints_points_id_cfcc5a79;
       public            taiga    false    230            d           1259    3598623 '   userstories_rolepoints_role_id_94ac7663    INDEX     m   CREATE INDEX userstories_rolepoints_role_id_94ac7663 ON public.userstories_rolepoints USING btree (role_id);
 ;   DROP INDEX public.userstories_rolepoints_role_id_94ac7663;
       public            taiga    false    230            e           1259    3599342 -   userstories_rolepoints_user_story_id_ddb4c558    INDEX     y   CREATE INDEX userstories_rolepoints_user_story_id_ddb4c558 ON public.userstories_rolepoints USING btree (user_story_id);
 A   DROP INDEX public.userstories_rolepoints_user_story_id_ddb4c558;
       public            taiga    false    230            h           1259    3598813 -   userstories_userstory_assigned_to_id_5ba80653    INDEX     y   CREATE INDEX userstories_userstory_assigned_to_id_5ba80653 ON public.userstories_userstory USING btree (assigned_to_id);
 A   DROP INDEX public.userstories_userstory_assigned_to_id_5ba80653;
       public            taiga    false    231            �           1259    3599291 5   userstories_userstory_assigned_users_user_id_6de6e8a7    INDEX     �   CREATE INDEX userstories_userstory_assigned_users_user_id_6de6e8a7 ON public.userstories_userstory_assigned_users USING btree (user_id);
 I   DROP INDEX public.userstories_userstory_assigned_users_user_id_6de6e8a7;
       public            taiga    false    334            �           1259    3599353 :   userstories_userstory_assigned_users_userstory_id_fcb98e26    INDEX     �   CREATE INDEX userstories_userstory_assigned_users_userstory_id_fcb98e26 ON public.userstories_userstory_assigned_users USING btree (userstory_id);
 N   DROP INDEX public.userstories_userstory_assigned_users_userstory_id_fcb98e26;
       public            taiga    false    334            i           1259    3596462 6   userstories_userstory_generated_from_issue_id_afe43198    INDEX     �   CREATE INDEX userstories_userstory_generated_from_issue_id_afe43198 ON public.userstories_userstory USING btree (generated_from_issue_id);
 J   DROP INDEX public.userstories_userstory_generated_from_issue_id_afe43198;
       public            taiga    false    231            j           1259    3599297 5   userstories_userstory_generated_from_task_id_8e958d43    INDEX     �   CREATE INDEX userstories_userstory_generated_from_task_id_8e958d43 ON public.userstories_userstory USING btree (generated_from_task_id);
 I   DROP INDEX public.userstories_userstory_generated_from_task_id_8e958d43;
       public            taiga    false    231            k           1259    3596547 +   userstories_userstory_milestone_id_37f31d22    INDEX     u   CREATE INDEX userstories_userstory_milestone_id_37f31d22 ON public.userstories_userstory USING btree (milestone_id);
 ?   DROP INDEX public.userstories_userstory_milestone_id_37f31d22;
       public            taiga    false    231            l           1259    3598828 '   userstories_userstory_owner_id_df53c64e    INDEX     m   CREATE INDEX userstories_userstory_owner_id_df53c64e ON public.userstories_userstory USING btree (owner_id);
 ;   DROP INDEX public.userstories_userstory_owner_id_df53c64e;
       public            taiga    false    231            o           1259    3597503 )   userstories_userstory_project_id_03e85e9c    INDEX     q   CREATE INDEX userstories_userstory_project_id_03e85e9c ON public.userstories_userstory USING btree (project_id);
 =   DROP INDEX public.userstories_userstory_project_id_03e85e9c;
       public            taiga    false    231            p           1259    3595031 "   userstories_userstory_ref_824701c0    INDEX     c   CREATE INDEX userstories_userstory_ref_824701c0 ON public.userstories_userstory USING btree (ref);
 6   DROP INDEX public.userstories_userstory_ref_824701c0;
       public            taiga    false    231            q           1259    3598263 (   userstories_userstory_status_id_858671dd    INDEX     o   CREATE INDEX userstories_userstory_status_id_858671dd ON public.userstories_userstory USING btree (status_id);
 <   DROP INDEX public.userstories_userstory_status_id_858671dd;
       public            taiga    false    231            r           1259    3599303 *   userstories_userstory_swimlane_id_8ecab79d    INDEX     s   CREATE INDEX userstories_userstory_swimlane_id_8ecab79d ON public.userstories_userstory USING btree (swimlane_id);
 >   DROP INDEX public.userstories_userstory_swimlane_id_8ecab79d;
       public            taiga    false    231            �           1259    3599451 #   votes_vote_content_type_id_c8375fe1    INDEX     e   CREATE INDEX votes_vote_content_type_id_c8375fe1 ON public.votes_vote USING btree (content_type_id);
 7   DROP INDEX public.votes_vote_content_type_id_c8375fe1;
       public            taiga    false    337            �           1259    3599452    votes_vote_user_id_24a74629    INDEX     U   CREATE INDEX votes_vote_user_id_24a74629 ON public.votes_vote USING btree (user_id);
 /   DROP INDEX public.votes_vote_user_id_24a74629;
       public            taiga    false    337            �           1259    3599458 $   votes_votes_content_type_id_29583576    INDEX     g   CREATE INDEX votes_votes_content_type_id_29583576 ON public.votes_votes USING btree (content_type_id);
 8   DROP INDEX public.votes_votes_content_type_id_29583576;
       public            taiga    false    338            �           1259    3599512 $   webhooks_webhook_project_id_76846b5e    INDEX     g   CREATE INDEX webhooks_webhook_project_id_76846b5e ON public.webhooks_webhook USING btree (project_id);
 8   DROP INDEX public.webhooks_webhook_project_id_76846b5e;
       public            taiga    false    341            �           1259    3599546 '   webhooks_webhooklog_webhook_id_646c2008    INDEX     m   CREATE INDEX webhooks_webhooklog_webhook_id_646c2008 ON public.webhooks_webhooklog USING btree (webhook_id);
 ;   DROP INDEX public.webhooks_webhooklog_webhook_id_646c2008;
       public            taiga    false    342            �           1259    3595703    wiki_wikilink_href_46ee8855    INDEX     U   CREATE INDEX wiki_wikilink_href_46ee8855 ON public.wiki_wikilink USING btree (href);
 /   DROP INDEX public.wiki_wikilink_href_46ee8855;
       public            taiga    false    247            �           1259    3595704     wiki_wikilink_href_46ee8855_like    INDEX     n   CREATE INDEX wiki_wikilink_href_46ee8855_like ON public.wiki_wikilink USING btree (href varchar_pattern_ops);
 4   DROP INDEX public.wiki_wikilink_href_46ee8855_like;
       public            taiga    false    247            �           1259    3597604 !   wiki_wikilink_project_id_7dc700d7    INDEX     a   CREATE INDEX wiki_wikilink_project_id_7dc700d7 ON public.wiki_wikilink USING btree (project_id);
 5   DROP INDEX public.wiki_wikilink_project_id_7dc700d7;
       public            taiga    false    247            �           1259    3598944 '   wiki_wikipage_last_modifier_id_38be071c    INDEX     m   CREATE INDEX wiki_wikipage_last_modifier_id_38be071c ON public.wiki_wikipage USING btree (last_modifier_id);
 ;   DROP INDEX public.wiki_wikipage_last_modifier_id_38be071c;
       public            taiga    false    248            �           1259    3598958    wiki_wikipage_owner_id_f1f6c5fd    INDEX     ]   CREATE INDEX wiki_wikipage_owner_id_f1f6c5fd ON public.wiki_wikipage USING btree (owner_id);
 3   DROP INDEX public.wiki_wikipage_owner_id_f1f6c5fd;
       public            taiga    false    248            �           1259    3597618 !   wiki_wikipage_project_id_03a1e2ca    INDEX     a   CREATE INDEX wiki_wikipage_project_id_03a1e2ca ON public.wiki_wikipage USING btree (project_id);
 5   DROP INDEX public.wiki_wikipage_project_id_03a1e2ca;
       public            taiga    false    248            �           1259    3595721    wiki_wikipage_slug_10d80dc1    INDEX     U   CREATE INDEX wiki_wikipage_slug_10d80dc1 ON public.wiki_wikipage USING btree (slug);
 /   DROP INDEX public.wiki_wikipage_slug_10d80dc1;
       public            taiga    false    248            �           1259    3595722     wiki_wikipage_slug_10d80dc1_like    INDEX     n   CREATE INDEX wiki_wikipage_slug_10d80dc1_like ON public.wiki_wikipage USING btree (slug varchar_pattern_ops);
 4   DROP INDEX public.wiki_wikipage_slug_10d80dc1_like;
       public            taiga    false    248            9           1259    3599653 )   workspaces_workspace_name_id_69b27cd8_idx    INDEX     n   CREATE INDEX workspaces_workspace_name_id_69b27cd8_idx ON public.workspaces_workspace USING btree (name, id);
 =   DROP INDEX public.workspaces_workspace_name_id_69b27cd8_idx;
       public            taiga    false    290    290            :           1259    3599012 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    290            =           1259    3596704 '   workspaces_workspace_slug_c37054a2_like    INDEX     |   CREATE INDEX workspaces_workspace_slug_c37054a2_like ON public.workspaces_workspace USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.workspaces_workspace_slug_c37054a2_like;
       public            taiga    false    290            �           1259    3599646 /   workspaces_workspacemembership_user_id_091e94f3    INDEX     }   CREATE INDEX workspaces_workspacemembership_user_id_091e94f3 ON public.workspaces_workspacemembership USING btree (user_id);
 C   DROP INDEX public.workspaces_workspacemembership_user_id_091e94f3;
       public            taiga    false    347            �           1259    3599722 4   workspaces_workspacemembership_workspace_id_d634b215    INDEX     �   CREATE INDEX workspaces_workspacemembership_workspace_id_d634b215 ON public.workspaces_workspacemembership USING btree (workspace_id);
 H   DROP INDEX public.workspaces_workspacemembership_workspace_id_d634b215;
       public            taiga    false    347            �           1259    3599648 9   workspaces_workspacemembership_workspace_role_id_39c459bf    INDEX     �   CREATE INDEX workspaces_workspacemembership_workspace_role_id_39c459bf ON public.workspaces_workspacemembership USING btree (workspace_role_id);
 M   DROP INDEX public.workspaces_workspacemembership_workspace_role_id_39c459bf;
       public            taiga    false    347            -           2620    3599845 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    351    1182    351    426            1           2620    3599849 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    351    429            0           2620    3599848 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    351    351    428    1182    351            /           2620    3599847 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    402    351    351    1182            .           2620    3599846 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    351    427    351            ,           2620    3596003 ^   custom_attributes_epiccustomattribute update_epiccustomvalues_after_remove_epiccustomattribute    TRIGGER       CREATE TRIGGER update_epiccustomvalues_after_remove_epiccustomattribute AFTER DELETE ON public.custom_attributes_epiccustomattribute FOR EACH ROW EXECUTE FUNCTION public.clean_key_in_custom_attributes_values('epic_id', 'epics_epic', 'custom_attributes_epiccustomattributesvalues');
 w   DROP TRIGGER update_epiccustomvalues_after_remove_epiccustomattribute ON public.custom_attributes_epiccustomattribute;
       public          taiga    false    420    258            )           2620    3595972 a   custom_attributes_issuecustomattribute update_issuecustomvalues_after_remove_issuecustomattribute    TRIGGER     !  CREATE TRIGGER update_issuecustomvalues_after_remove_issuecustomattribute AFTER DELETE ON public.custom_attributes_issuecustomattribute FOR EACH ROW EXECUTE FUNCTION public.clean_key_in_custom_attributes_values('issue_id', 'issues_issue', 'custom_attributes_issuecustomattributesvalues');
 z   DROP TRIGGER update_issuecustomvalues_after_remove_issuecustomattribute ON public.custom_attributes_issuecustomattribute;
       public          taiga    false    252    420            (           2620    3595812 4   epics_epic update_project_tags_colors_on_epic_insert    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_epic_insert AFTER INSERT ON public.epics_epic FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 M   DROP TRIGGER update_project_tags_colors_on_epic_insert ON public.epics_epic;
       public          taiga    false    406    250            '           2620    3595811 4   epics_epic update_project_tags_colors_on_epic_update    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_epic_update AFTER UPDATE ON public.epics_epic FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 M   DROP TRIGGER update_project_tags_colors_on_epic_update ON public.epics_epic;
       public          taiga    false    250    406            "           2620    3595548 7   issues_issue update_project_tags_colors_on_issue_insert    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_issue_insert AFTER INSERT ON public.issues_issue FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 P   DROP TRIGGER update_project_tags_colors_on_issue_insert ON public.issues_issue;
       public          taiga    false    406    229            !           2620    3595547 7   issues_issue update_project_tags_colors_on_issue_update    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_issue_update AFTER UPDATE ON public.issues_issue FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 P   DROP TRIGGER update_project_tags_colors_on_issue_update ON public.issues_issue;
       public          taiga    false    406    229            &           2620    3595546 4   tasks_task update_project_tags_colors_on_task_insert    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_task_insert AFTER INSERT ON public.tasks_task FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 M   DROP TRIGGER update_project_tags_colors_on_task_insert ON public.tasks_task;
       public          taiga    false    239    406            %           2620    3595545 4   tasks_task update_project_tags_colors_on_task_update    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_task_update AFTER UPDATE ON public.tasks_task FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 M   DROP TRIGGER update_project_tags_colors_on_task_update ON public.tasks_task;
       public          taiga    false    406    239            $           2620    3595544 D   userstories_userstory update_project_tags_colors_on_userstory_insert    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_userstory_insert AFTER INSERT ON public.userstories_userstory FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 ]   DROP TRIGGER update_project_tags_colors_on_userstory_insert ON public.userstories_userstory;
       public          taiga    false    406    231            #           2620    3595543 D   userstories_userstory update_project_tags_colors_on_userstory_update    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_userstory_update AFTER UPDATE ON public.userstories_userstory FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 ]   DROP TRIGGER update_project_tags_colors_on_userstory_update ON public.userstories_userstory;
       public          taiga    false    231    406            *           2620    3595971 ^   custom_attributes_taskcustomattribute update_taskcustomvalues_after_remove_taskcustomattribute    TRIGGER       CREATE TRIGGER update_taskcustomvalues_after_remove_taskcustomattribute AFTER DELETE ON public.custom_attributes_taskcustomattribute FOR EACH ROW EXECUTE FUNCTION public.clean_key_in_custom_attributes_values('task_id', 'tasks_task', 'custom_attributes_taskcustomattributesvalues');
 w   DROP TRIGGER update_taskcustomvalues_after_remove_taskcustomattribute ON public.custom_attributes_taskcustomattribute;
       public          taiga    false    253    420            +           2620    3595970 j   custom_attributes_userstorycustomattribute update_userstorycustomvalues_after_remove_userstorycustomattrib    TRIGGER     <  CREATE TRIGGER update_userstorycustomvalues_after_remove_userstorycustomattrib AFTER DELETE ON public.custom_attributes_userstorycustomattribute FOR EACH ROW EXECUTE FUNCTION public.clean_key_in_custom_attributes_values('user_story_id', 'userstories_userstory', 'custom_attributes_userstorycustomattributesvalues');
 �   DROP TRIGGER update_userstorycustomvalues_after_remove_userstorycustomattrib ON public.custom_attributes_userstorycustomattribute;
       public          taiga    false    254    420            �           2606    3594714 Q   attachments_attachment attachments_attachme_content_type_id_35dd9d5d_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.attachments_attachment
    ADD CONSTRAINT attachments_attachme_content_type_id_35dd9d5d_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.attachments_attachment DROP CONSTRAINT attachments_attachme_content_type_id_35dd9d5d_fk_django_co;
       public          taiga    false    205    220    3506            �           2606    3599062 B   attachments_attachment attachments_attachment_owner_id_720defb8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.attachments_attachment
    ADD CONSTRAINT attachments_attachment_owner_id_720defb8_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.attachments_attachment DROP CONSTRAINT attachments_attachment_owner_id_720defb8_fk;
       public          taiga    false    206    220    3511            �           2606    3597768 D   attachments_attachment attachments_attachment_project_id_50714f52_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.attachments_attachment
    ADD CONSTRAINT attachments_attachment_project_id_50714f52_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.attachments_attachment DROP CONSTRAINT attachments_attachment_project_id_50714f52_fk;
       public          taiga    false    220    211    3565            �           2606    3594795 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    223    3646    227            �           2606    3594790 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    3651    227    225            �           2606    3594781 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    223    3506    205            �           2606    3597813 @   contact_contactentry contact_contactentry_project_id_27bfec4e_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.contact_contactentry
    ADD CONSTRAINT contact_contactentry_project_id_27bfec4e_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.contact_contactentry DROP CONSTRAINT contact_contactentry_project_id_27bfec4e_fk;
       public          taiga    false    245    211    3565            �           2606    3599122 =   contact_contactentry contact_contactentry_user_id_f1f19c5f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.contact_contactentry
    ADD CONSTRAINT contact_contactentry_user_id_f1f19c5f_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 g   ALTER TABLE ONLY public.contact_contactentry DROP CONSTRAINT contact_contactentry_user_id_f1f19c5f_fk;
       public          taiga    false    206    245    3511                       2606    3596334 Z   custom_attributes_epiccustomattributesvalues custom_attributes_epiccus_epic_id_d413e57a_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues
    ADD CONSTRAINT custom_attributes_epiccus_epic_id_d413e57a_fk FOREIGN KEY (epic_id) REFERENCES public.epics_epic(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues DROP CONSTRAINT custom_attributes_epiccus_epic_id_d413e57a_fk;
       public          taiga    false    250    259    3807                        2606    3597833 b   custom_attributes_epiccustomattribute custom_attributes_epiccustomattribute_project_id_ad2cfaa8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute
    ADD CONSTRAINT custom_attributes_epiccustomattribute_project_id_ad2cfaa8_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute DROP CONSTRAINT custom_attributes_epiccustomattribute_project_id_ad2cfaa8_fk;
       public          taiga    false    3565    258    211            �           2606    3596494 \   custom_attributes_issuecustomattributesvalues custom_attributes_issuecu_issue_id_868161f8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues
    ADD CONSTRAINT custom_attributes_issuecu_issue_id_868161f8_fk FOREIGN KEY (issue_id) REFERENCES public.issues_issue(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues DROP CONSTRAINT custom_attributes_issuecu_issue_id_868161f8_fk;
       public          taiga    false    229    255    3674            �           2606    3597843 d   custom_attributes_issuecustomattribute custom_attributes_issuecustomattribute_project_id_3b4acff5_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute
    ADD CONSTRAINT custom_attributes_issuecustomattribute_project_id_3b4acff5_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute DROP CONSTRAINT custom_attributes_issuecustomattribute_project_id_3b4acff5_fk;
       public          taiga    false    211    252    3565            �           2606    3598430 Z   custom_attributes_taskcustomattributesvalues custom_attributes_taskcus_task_id_3d1ccf5e_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues
    ADD CONSTRAINT custom_attributes_taskcus_task_id_3d1ccf5e_fk FOREIGN KEY (task_id) REFERENCES public.tasks_task(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues DROP CONSTRAINT custom_attributes_taskcus_task_id_3d1ccf5e_fk;
       public          taiga    false    256    3735    239            �           2606    3597838 b   custom_attributes_taskcustomattribute custom_attributes_taskcustomattribute_project_id_f0f622a8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute
    ADD CONSTRAINT custom_attributes_taskcustomattribute_project_id_f0f622a8_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute DROP CONSTRAINT custom_attributes_taskcustomattribute_project_id_f0f622a8_fk;
       public          taiga    false    3565    253    211            �           2606    3597848 [   custom_attributes_userstorycustomattribute custom_attributes_usersto_project_id_2619cf6c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute
    ADD CONSTRAINT custom_attributes_usersto_project_id_2619cf6c_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute DROP CONSTRAINT custom_attributes_usersto_project_id_2619cf6c_fk;
       public          taiga    false    254    211    3565            �           2606    3599413 e   custom_attributes_userstorycustomattributesvalues custom_attributes_usersto_user_story_id_99b10c43_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues
    ADD CONSTRAINT custom_attributes_usersto_user_story_id_99b10c43_fk FOREIGN KEY (user_story_id) REFERENCES public.userstories_userstory(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues DROP CONSTRAINT custom_attributes_usersto_user_story_id_99b10c43_fk;
       public          taiga    false    257    3694    231            �           2606    3594443 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    3506    205    208            �           2606    3599047 5   django_admin_log django_admin_log_user_id_c564eba6_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 _   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk;
       public          taiga    false    208    206    3511                       2606    3596241 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    3863    272    270                       2606    3596263 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    274    3873    272            �           2606    3599137 0   epics_epic epics_epic_assigned_to_id_13e08004_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_assigned_to_id_13e08004_fk FOREIGN KEY (assigned_to_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 Z   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_assigned_to_id_13e08004_fk;
       public          taiga    false    206    250    3511            �           2606    3599142 *   epics_epic epics_epic_owner_id_b09888c4_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_owner_id_b09888c4_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 T   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_owner_id_b09888c4_fk;
       public          taiga    false    206    250    3511            �           2606    3597828 ,   epics_epic epics_epic_project_id_d98aaef7_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_project_id_d98aaef7_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 V   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_project_id_d98aaef7_fk;
       public          taiga    false    211    3565    250            �           2606    3596891 +   epics_epic epics_epic_status_id_4cf3af1a_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_status_id_4cf3af1a_fk FOREIGN KEY (status_id) REFERENCES public.projects_epicstatus(id) DEFERRABLE INITIALLY DEFERRED;
 U   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_status_id_4cf3af1a_fk;
       public          taiga    false    250    244    3770            �           2606    3596329 A   epics_relateduserstory epics_relateduserstory_epic_id_57605230_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_relateduserstory
    ADD CONSTRAINT epics_relateduserstory_epic_id_57605230_fk FOREIGN KEY (epic_id) REFERENCES public.epics_epic(id) DEFERRABLE INITIALLY DEFERRED;
 k   ALTER TABLE ONLY public.epics_relateduserstory DROP CONSTRAINT epics_relateduserstory_epic_id_57605230_fk;
       public          taiga    false    251    3807    250            �           2606    3599408 G   epics_relateduserstory epics_relateduserstory_user_story_id_329a951c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_relateduserstory
    ADD CONSTRAINT epics_relateduserstory_user_story_id_329a951c_fk FOREIGN KEY (user_story_id) REFERENCES public.userstories_userstory(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.epics_relateduserstory DROP CONSTRAINT epics_relateduserstory_user_story_id_329a951c_fk;
       public          taiga    false    3694    251    231                       2606    3596374 X   external_apps_applicationtoken external_apps_applic_application_id_0e934655_fk_external_    FK CONSTRAINT     �   ALTER TABLE ONLY public.external_apps_applicationtoken
    ADD CONSTRAINT external_apps_applic_application_id_0e934655_fk_external_ FOREIGN KEY (application_id) REFERENCES public.external_apps_application(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.external_apps_applicationtoken DROP CONSTRAINT external_apps_applic_application_id_0e934655_fk_external_;
       public          taiga    false    277    3883    278                       2606    3599147 Q   external_apps_applicationtoken external_apps_applicationtoken_user_id_6e2f1e8a_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.external_apps_applicationtoken
    ADD CONSTRAINT external_apps_applicationtoken_user_id_6e2f1e8a_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.external_apps_applicationtoken DROP CONSTRAINT external_apps_applicationtoken_user_id_6e2f1e8a_fk;
       public          taiga    false    206    278    3511            �           2606    3597798 @   history_historyentry history_historyentry_project_id_9b008f70_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.history_historyentry
    ADD CONSTRAINT history_historyentry_project_id_9b008f70_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.history_historyentry DROP CONSTRAINT history_historyentry_project_id_9b008f70_fk;
       public          taiga    false    3565    211    249            �           2606    3599072 4   issues_issue issues_issue_assigned_to_id_c6054289_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_assigned_to_id_c6054289_fk FOREIGN KEY (assigned_to_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 ^   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_assigned_to_id_c6054289_fk;
       public          taiga    false    206    229    3511            �           2606    3596577 2   issues_issue issues_issue_milestone_id_3c2695ee_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_milestone_id_3c2695ee_fk FOREIGN KEY (milestone_id) REFERENCES public.milestones_milestone(id) DEFERRABLE INITIALLY DEFERRED;
 \   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_milestone_id_3c2695ee_fk;
       public          taiga    false    228    3664    229            �           2606    3599077 .   issues_issue issues_issue_owner_id_5c361b47_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_owner_id_5c361b47_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 X   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_owner_id_5c361b47_fk;
       public          taiga    false    206    229    3511            �           2606    3597223 1   issues_issue issues_issue_priority_id_93842a93_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_priority_id_93842a93_fk FOREIGN KEY (priority_id) REFERENCES public.projects_priority(id) DEFERRABLE INITIALLY DEFERRED;
 [   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_priority_id_93842a93_fk;
       public          taiga    false    3604    215    229            �           2606    3597778 0   issues_issue issues_issue_project_id_4b0f3e2f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_project_id_4b0f3e2f_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 Z   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_project_id_4b0f3e2f_fk;
       public          taiga    false    211    229    3565            �           2606    3597999 1   issues_issue issues_issue_severity_id_695dade0_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_severity_id_695dade0_fk FOREIGN KEY (severity_id) REFERENCES public.projects_severity(id) DEFERRABLE INITIALLY DEFERRED;
 [   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_severity_id_695dade0_fk;
       public          taiga    false    3614    217    229            �           2606    3596985 /   issues_issue issues_issue_status_id_64473cf1_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_status_id_64473cf1_fk FOREIGN KEY (status_id) REFERENCES public.projects_issuestatus(id) DEFERRABLE INITIALLY DEFERRED;
 Y   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_status_id_64473cf1_fk;
       public          taiga    false    3585    229    212            �           2606    3597061 -   issues_issue issues_issue_type_id_c1063362_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_type_id_c1063362_fk FOREIGN KEY (type_id) REFERENCES public.projects_issuetype(id) DEFERRABLE INITIALLY DEFERRED;
 W   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_type_id_c1063362_fk;
       public          taiga    false    229    3594    213            �           2606    3595466 H   likes_like likes_like_content_type_id_8ffc2116_fk_django_content_type_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.likes_like
    ADD CONSTRAINT likes_like_content_type_id_8ffc2116_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 r   ALTER TABLE ONLY public.likes_like DROP CONSTRAINT likes_like_content_type_id_8ffc2116_fk_django_content_type_id;
       public          taiga    false    205    243    3506            �           2606    3599117 )   likes_like likes_like_user_id_aae4c421_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.likes_like
    ADD CONSTRAINT likes_like_user_id_aae4c421_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 S   ALTER TABLE ONLY public.likes_like DROP CONSTRAINT likes_like_user_id_aae4c421_fk;
       public          taiga    false    206    243    3511            �           2606    3599067 >   milestones_milestone milestones_milestone_owner_id_216ba23b_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_owner_id_216ba23b_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_owner_id_216ba23b_fk;
       public          taiga    false    206    228    3511            �           2606    3597773 @   milestones_milestone milestones_milestone_project_id_6151cb75_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_project_id_6151cb75_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_project_id_6151cb75_fk;
       public          taiga    false    3565    228    211            �           2606    3595777 r   notifications_historychangenotification_history_entries notifications_histor_historyentry_id_ad550852_fk_history_h    FK CONSTRAINT       ALTER TABLE ONLY public.notifications_historychangenotification_history_entries
    ADD CONSTRAINT notifications_histor_historyentry_id_ad550852_fk_history_h FOREIGN KEY (historyentry_id) REFERENCES public.history_historyentry(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries DROP CONSTRAINT notifications_histor_historyentry_id_ad550852_fk_history_h;
       public          taiga    false    235    249    3802            �           2606    3597793 L   notifications_notifypolicy notifications_notifypolicy_project_id_aa5da43f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_notifypolicy
    ADD CONSTRAINT notifications_notifypolicy_project_id_aa5da43f_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.notifications_notifypolicy DROP CONSTRAINT notifications_notifypolicy_project_id_aa5da43f_fk;
       public          taiga    false    3565    211    232            �           2606    3599102 I   notifications_notifypolicy notifications_notifypolicy_user_id_2902cbeb_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_notifypolicy
    ADD CONSTRAINT notifications_notifypolicy_user_id_2902cbeb_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.notifications_notifypolicy DROP CONSTRAINT notifications_notifypolicy_user_id_2902cbeb_fk;
       public          taiga    false    232    3511    206            �           2606    3595205 P   notifications_watched notifications_watche_content_type_id_7b3ab729_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watche_content_type_id_7b3ab729_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watche_content_type_id_7b3ab729_fk_django_co;
       public          taiga    false    3506    238    205            �           2606    3597788 B   notifications_watched notifications_watched_project_id_c88baa46_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watched_project_id_c88baa46_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watched_project_id_c88baa46_fk;
       public          taiga    false    238    211    3565            �           2606    3599097 ?   notifications_watched notifications_watched_user_id_1bce1955_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watched_user_id_1bce1955_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watched_user_id_1bce1955_fk;
       public          taiga    false    3511    206    238                       2606    3599092 O   notifications_webnotification notifications_webnotification_user_id_f32287d5_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_webnotification
    ADD CONSTRAINT notifications_webnotification_user_id_f32287d5_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.notifications_webnotification DROP CONSTRAINT notifications_webnotification_user_id_f32287d5_fk;
       public          taiga    false    206    285    3511                        2606    3599824 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    355    4003    351                       2606    3599810 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    351    4003    353            �           2606    3597733 >   projects_epicstatus projects_epicstatus_project_id_d2c43c29_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_epicstatus
    ADD CONSTRAINT projects_epicstatus_project_id_d2c43c29_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.projects_epicstatus DROP CONSTRAINT projects_epicstatus_project_id_d2c43c29_fk;
       public          taiga    false    244    211    3565                       2606    3597763 B   projects_issueduedate projects_issueduedate_project_id_ec077eb7_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_issueduedate
    ADD CONSTRAINT projects_issueduedate_project_id_ec077eb7_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.projects_issueduedate DROP CONSTRAINT projects_issueduedate_project_id_ec077eb7_fk;
       public          taiga    false    291    3565    211            �           2606    3597758 @   projects_issuestatus projects_issuestatus_project_id_1988ebf4_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuestatus
    ADD CONSTRAINT projects_issuestatus_project_id_1988ebf4_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.projects_issuestatus DROP CONSTRAINT projects_issuestatus_project_id_1988ebf4_fk;
       public          taiga    false    3565    211    212            �           2606    3597728 <   projects_issuetype projects_issuetype_project_id_e831e4ae_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuetype
    ADD CONSTRAINT projects_issuetype_project_id_e831e4ae_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 f   ALTER TABLE ONLY public.projects_issuetype DROP CONSTRAINT projects_issuetype_project_id_e831e4ae_fk;
       public          taiga    false    213    211    3565            �           2606    3597703 >   projects_membership projects_membership_project_id_5f65bf3f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_project_id_5f65bf3f_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_project_id_5f65bf3f_fk;
       public          taiga    false    210    211    3565            �           2606    3598632 ;   projects_membership projects_membership_role_id_c4bd36ef_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_role_id_c4bd36ef_fk FOREIGN KEY (role_id) REFERENCES public.users_role(id) DEFERRABLE INITIALLY DEFERRED;
 e   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_role_id_c4bd36ef_fk;
       public          taiga    false    3525    209    210            �           2606    3599052 ;   projects_membership projects_membership_user_id_13374535_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_user_id_13374535_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 e   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_user_id_13374535_fk;
       public          taiga    false    3511    210    206            �           2606    3597713 6   projects_points projects_points_project_id_3b8f7b42_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_points
    ADD CONSTRAINT projects_points_project_id_3b8f7b42_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 `   ALTER TABLE ONLY public.projects_points DROP CONSTRAINT projects_points_project_id_3b8f7b42_fk;
       public          taiga    false    214    211    3565            �           2606    3597698 :   projects_priority projects_priority_project_id_936c75b2_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_priority
    ADD CONSTRAINT projects_priority_project_id_936c75b2_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.projects_priority DROP CONSTRAINT projects_priority_project_id_936c75b2_fk;
       public          taiga    false    215    211    3565            �           2606    3597923 B   projects_project projects_project_creation_template_id_b5a97819_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_creation_template_id_b5a97819_fk FOREIGN KEY (creation_template_id) REFERENCES public.projects_projecttemplate(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_creation_template_id_b5a97819_fk;
       public          taiga    false    216    211    3609            �           2606    3599057 6   projects_project projects_project_owner_id_b940de39_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 `   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk;
       public          taiga    false    206    211    3511            �           2606    3599736 :   projects_project projects_project_workspace_id_7ea54f67_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk;
       public          taiga    false    3900    211    290            �           2606    3597753 R   projects_projectmodulesconfig projects_projectmodulesconfig_project_id_eff1c253_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmodulesconfig
    ADD CONSTRAINT projects_projectmodulesconfig_project_id_eff1c253_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.projects_projectmodulesconfig DROP CONSTRAINT projects_projectmodulesconfig_project_id_eff1c253_fk;
       public          taiga    false    3565    241    211            �           2606    3597738 :   projects_severity projects_severity_project_id_9ab920cd_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_severity
    ADD CONSTRAINT projects_severity_project_id_9ab920cd_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.projects_severity DROP CONSTRAINT projects_severity_project_id_9ab920cd_fk;
       public          taiga    false    217    211    3565                       2606    3597708 :   projects_swimlane projects_swimlane_project_id_06871cf8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlane
    ADD CONSTRAINT projects_swimlane_project_id_06871cf8_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.projects_swimlane DROP CONSTRAINT projects_swimlane_project_id_06871cf8_fk;
       public          taiga    false    294    211    3565                       2606    3598278 W   projects_swimlaneuserstorystatus projects_swimlaneuserstorystatus_status_id_2f3fda91_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus
    ADD CONSTRAINT projects_swimlaneuserstorystatus_status_id_2f3fda91_fk FOREIGN KEY (status_id) REFERENCES public.projects_userstorystatus(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus DROP CONSTRAINT projects_swimlaneuserstorystatus_status_id_2f3fda91_fk;
       public          taiga    false    3628    295    219                       2606    3598071 Y   projects_swimlaneuserstorystatus projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus
    ADD CONSTRAINT projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21_fk FOREIGN KEY (swimlane_id) REFERENCES public.projects_swimlane(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus DROP CONSTRAINT projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21_fk;
       public          taiga    false    294    3920    295            	           2606    3597743 @   projects_taskduedate projects_taskduedate_project_id_775d850d_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskduedate
    ADD CONSTRAINT projects_taskduedate_project_id_775d850d_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.projects_taskduedate DROP CONSTRAINT projects_taskduedate_project_id_775d850d_fk;
       public          taiga    false    292    211    3565            �           2606    3597748 >   projects_taskstatus projects_taskstatus_project_id_8b32b2bb_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskstatus
    ADD CONSTRAINT projects_taskstatus_project_id_8b32b2bb_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.projects_taskstatus DROP CONSTRAINT projects_taskstatus_project_id_8b32b2bb_fk;
       public          taiga    false    211    3565    218            
           2606    3597723 J   projects_userstoryduedate projects_userstoryduedate_project_id_ab7b1680_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstoryduedate
    ADD CONSTRAINT projects_userstoryduedate_project_id_ab7b1680_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.projects_userstoryduedate DROP CONSTRAINT projects_userstoryduedate_project_id_ab7b1680_fk;
       public          taiga    false    293    211    3565            �           2606    3597718 H   projects_userstorystatus projects_userstorystatus_project_id_cdf95c9c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstorystatus
    ADD CONSTRAINT projects_userstorystatus_project_id_cdf95c9c_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 r   ALTER TABLE ONLY public.projects_userstorystatus DROP CONSTRAINT projects_userstorystatus_project_id_cdf95c9c_fk;
       public          taiga    false    219    211    3565                       2606    3598299 O   references_reference references_reference_content_type_id_c134e05e_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.references_reference
    ADD CONSTRAINT references_reference_content_type_id_c134e05e_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.references_reference DROP CONSTRAINT references_reference_content_type_id_c134e05e_fk_django_co;
       public          taiga    false    3506    313    205                       2606    3598304 T   references_reference references_reference_project_id_00275368_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.references_reference
    ADD CONSTRAINT references_reference_project_id_00275368_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 ~   ALTER TABLE ONLY public.references_reference DROP CONSTRAINT references_reference_project_id_00275368_fk_projects_project_id;
       public          taiga    false    211    3565    313                       2606    3598344 R   settings_userprojectsettings settings_userproject_project_id_0bc686ce_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.settings_userprojectsettings
    ADD CONSTRAINT settings_userproject_project_id_0bc686ce_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.settings_userprojectsettings DROP CONSTRAINT settings_userproject_project_id_0bc686ce_fk_projects_;
       public          taiga    false    211    316    3565                       2606    3599157 M   settings_userprojectsettings settings_userprojectsettings_user_id_0e7fdc25_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.settings_userprojectsettings
    ADD CONSTRAINT settings_userprojectsettings_user_id_0e7fdc25_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.settings_userprojectsettings DROP CONSTRAINT settings_userprojectsettings_user_id_0e7fdc25_fk;
       public          taiga    false    3511    316    206            �           2606    3599107 0   tasks_task tasks_task_assigned_to_id_e8821f61_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_assigned_to_id_e8821f61_fk FOREIGN KEY (assigned_to_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 Z   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_assigned_to_id_e8821f61_fk;
       public          taiga    false    239    206    3511            �           2606    3596587 .   tasks_task tasks_task_milestone_id_64cc568f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_milestone_id_64cc568f_fk FOREIGN KEY (milestone_id) REFERENCES public.milestones_milestone(id) DEFERRABLE INITIALLY DEFERRED;
 X   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_milestone_id_64cc568f_fk;
       public          taiga    false    228    239    3664            �           2606    3599112 *   tasks_task tasks_task_owner_id_db3dcc3e_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_owner_id_db3dcc3e_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 T   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_owner_id_db3dcc3e_fk;
       public          taiga    false    3511    239    206            �           2606    3597803 ,   tasks_task tasks_task_project_id_a2815f0c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_project_id_a2815f0c_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 V   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_project_id_a2815f0c_fk;
       public          taiga    false    211    239    3565            �           2606    3598176 +   tasks_task tasks_task_status_id_899d2b90_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_status_id_899d2b90_fk FOREIGN KEY (status_id) REFERENCES public.projects_taskstatus(id) DEFERRABLE INITIALLY DEFERRED;
 U   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_status_id_899d2b90_fk;
       public          taiga    false    3619    218    239            �           2606    3599403 /   tasks_task tasks_task_user_story_id_47ceaf1d_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_user_story_id_47ceaf1d_fk FOREIGN KEY (user_story_id) REFERENCES public.userstories_userstory(id) DEFERRABLE INITIALLY DEFERRED;
 Y   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_user_story_id_47ceaf1d_fk;
       public          taiga    false    231    239    3694            �           2606    3595416 I   timeline_timeline timeline_timeline_content_type_id_5731a0c6_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.timeline_timeline
    ADD CONSTRAINT timeline_timeline_content_type_id_5731a0c6_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.timeline_timeline DROP CONSTRAINT timeline_timeline_content_type_id_5731a0c6_fk_django_co;
       public          taiga    false    3506    242    205            �           2606    3595411 N   timeline_timeline timeline_timeline_data_content_type_id_0689742e_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.timeline_timeline
    ADD CONSTRAINT timeline_timeline_data_content_type_id_0689742e_fk_django_co FOREIGN KEY (data_content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.timeline_timeline DROP CONSTRAINT timeline_timeline_data_content_type_id_0689742e_fk_django_co;
       public          taiga    false    3506    205    242            �           2606    3597808 :   timeline_timeline timeline_timeline_project_id_58d5eadd_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.timeline_timeline
    ADD CONSTRAINT timeline_timeline_project_id_58d5eadd_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.timeline_timeline DROP CONSTRAINT timeline_timeline_project_id_58d5eadd_fk;
       public          taiga    false    3565    211    242                       2606    3598526 R   token_denylist_denylistedtoken token_denylist_denyl_token_id_dca79910_fk_token_den    FK CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_denylistedtoken
    ADD CONSTRAINT token_denylist_denyl_token_id_dca79910_fk_token_den FOREIGN KEY (token_id) REFERENCES public.token_denylist_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.token_denylist_denylistedtoken DROP CONSTRAINT token_denylist_denyl_token_id_dca79910_fk_token_den;
       public          taiga    false    3952    325    323                       2606    3599162 S   token_denylist_outstandingtoken token_denylist_outstandingtoken_user_id_c6f48986_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_outstandingtoken
    ADD CONSTRAINT token_denylist_outstandingtoken_user_id_c6f48986_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 }   ALTER TABLE ONLY public.token_denylist_outstandingtoken DROP CONSTRAINT token_denylist_outstandingtoken_user_id_c6f48986_fk;
       public          taiga    false    206    323    3511            �           2606    3599042 1   users_authdata users_authdata_user_id_9625853a_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 [   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk;
       public          taiga    false    206    3511    240            �           2606    3597693 ,   users_role users_role_project_id_2837f877_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_role
    ADD CONSTRAINT users_role_project_id_2837f877_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 V   ALTER TABLE ONLY public.users_role DROP CONSTRAINT users_role_project_id_2837f877_fk;
       public          taiga    false    209    211    3565                       2606    3599731 @   users_workspacerole users_workspacerole_workspace_id_30155f00_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_workspacerole
    ADD CONSTRAINT users_workspacerole_workspace_id_30155f00_fk FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.users_workspacerole DROP CONSTRAINT users_workspacerole_workspace_id_30155f00_fk;
       public          taiga    false    290    3900    326                       2606    3599197 T   userstorage_storageentry userstorage_storageentry_owner_id_c4c1ffc0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstorage_storageentry
    ADD CONSTRAINT userstorage_storageentry_owner_id_c4c1ffc0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 ~   ALTER TABLE ONLY public.userstorage_storageentry DROP CONSTRAINT userstorage_storageentry_owner_id_c4c1ffc0_fk_users_user_id;
       public          taiga    false    206    331    3511            �           2606    3597147 C   userstories_rolepoints userstories_rolepoints_points_id_cfcc5a79_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_points_id_cfcc5a79_fk FOREIGN KEY (points_id) REFERENCES public.projects_points(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_points_id_cfcc5a79_fk;
       public          taiga    false    3599    214    230            �           2606    3598637 A   userstories_rolepoints userstories_rolepoints_role_id_94ac7663_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_role_id_94ac7663_fk FOREIGN KEY (role_id) REFERENCES public.users_role(id) DEFERRABLE INITIALLY DEFERRED;
 k   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_role_id_94ac7663_fk;
       public          taiga    false    230    3525    209            �           2606    3599398 G   userstories_rolepoints userstories_rolepoints_user_story_id_ddb4c558_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_user_story_id_ddb4c558_fk FOREIGN KEY (user_story_id) REFERENCES public.userstories_userstory(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_user_story_id_ddb4c558_fk;
       public          taiga    false    3694    230    231            �           2606    3599292 U   userstories_userstory userstories_userstor_generated_from_task__8e958d43_fk_tasks_tas    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstor_generated_from_task__8e958d43_fk_tasks_tas FOREIGN KEY (generated_from_task_id) REFERENCES public.tasks_task(id) DEFERRABLE INITIALLY DEFERRED;
    ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstor_generated_from_task__8e958d43_fk_tasks_tas;
       public          taiga    false    239    231    3735            �           2606    3599298 L   userstories_userstory userstories_userstor_swimlane_id_8ecab79d_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstor_swimlane_id_8ecab79d_fk_projects_ FOREIGN KEY (swimlane_id) REFERENCES public.projects_swimlane(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstor_swimlane_id_8ecab79d_fk_projects_;
       public          taiga    false    294    3920    231                       2606    3599285 W   userstories_userstory_assigned_users userstories_userstor_user_id_6de6e8a7_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory_assigned_users
    ADD CONSTRAINT userstories_userstor_user_id_6de6e8a7_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.userstories_userstory_assigned_users DROP CONSTRAINT userstories_userstor_user_id_6de6e8a7_fk_users_use;
       public          taiga    false    206    3511    334            �           2606    3599082 F   userstories_userstory userstories_userstory_assigned_to_id_5ba80653_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_assigned_to_id_5ba80653_fk FOREIGN KEY (assigned_to_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 p   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_assigned_to_id_5ba80653_fk;
       public          taiga    false    206    231    3511            �           2606    3596489 O   userstories_userstory userstories_userstory_generated_from_issue_id_afe43198_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_generated_from_issue_id_afe43198_fk FOREIGN KEY (generated_from_issue_id) REFERENCES public.issues_issue(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_generated_from_issue_id_afe43198_fk;
       public          taiga    false    231    3674    229            �           2606    3596582 D   userstories_userstory userstories_userstory_milestone_id_37f31d22_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_milestone_id_37f31d22_fk FOREIGN KEY (milestone_id) REFERENCES public.milestones_milestone(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_milestone_id_37f31d22_fk;
       public          taiga    false    228    3664    231            �           2606    3599087 @   userstories_userstory userstories_userstory_owner_id_df53c64e_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_owner_id_df53c64e_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_owner_id_df53c64e_fk;
       public          taiga    false    206    231    3511            �           2606    3597783 B   userstories_userstory userstories_userstory_project_id_03e85e9c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_project_id_03e85e9c_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_project_id_03e85e9c_fk;
       public          taiga    false    3565    231    211            �           2606    3598283 A   userstories_userstory userstories_userstory_status_id_858671dd_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_status_id_858671dd_fk FOREIGN KEY (status_id) REFERENCES public.projects_userstorystatus(id) DEFERRABLE INITIALLY DEFERRED;
 k   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_status_id_858671dd_fk;
       public          taiga    false    231    219    3628                       2606    3599441 H   votes_vote votes_vote_content_type_id_c8375fe1_fk_django_content_type_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.votes_vote
    ADD CONSTRAINT votes_vote_content_type_id_c8375fe1_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 r   ALTER TABLE ONLY public.votes_vote DROP CONSTRAINT votes_vote_content_type_id_c8375fe1_fk_django_content_type_id;
       public          taiga    false    205    337    3506                       2606    3599446 7   votes_vote votes_vote_user_id_24a74629_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.votes_vote
    ADD CONSTRAINT votes_vote_user_id_24a74629_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 a   ALTER TABLE ONLY public.votes_vote DROP CONSTRAINT votes_vote_user_id_24a74629_fk_users_user_id;
       public          taiga    false    206    337    3511                       2606    3599453 J   votes_votes votes_votes_content_type_id_29583576_fk_django_content_type_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.votes_votes
    ADD CONSTRAINT votes_votes_content_type_id_29583576_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.votes_votes DROP CONSTRAINT votes_votes_content_type_id_29583576_fk_django_content_type_id;
       public          taiga    false    205    338    3506                       2606    3599507 L   webhooks_webhook webhooks_webhook_project_id_76846b5e_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.webhooks_webhook
    ADD CONSTRAINT webhooks_webhook_project_id_76846b5e_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.webhooks_webhook DROP CONSTRAINT webhooks_webhook_project_id_76846b5e_fk_projects_project_id;
       public          taiga    false    211    341    3565                       2606    3599555 >   webhooks_webhooklog webhooks_webhooklog_webhook_id_646c2008_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.webhooks_webhooklog
    ADD CONSTRAINT webhooks_webhooklog_webhook_id_646c2008_fk FOREIGN KEY (webhook_id) REFERENCES public.webhooks_webhook(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.webhooks_webhooklog DROP CONSTRAINT webhooks_webhooklog_webhook_id_646c2008_fk;
       public          taiga    false    342    3988    341            �           2606    3597818 2   wiki_wikilink wiki_wikilink_project_id_7dc700d7_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikilink
    ADD CONSTRAINT wiki_wikilink_project_id_7dc700d7_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 \   ALTER TABLE ONLY public.wiki_wikilink DROP CONSTRAINT wiki_wikilink_project_id_7dc700d7_fk;
       public          taiga    false    211    3565    247            �           2606    3599127 8   wiki_wikipage wiki_wikipage_last_modifier_id_38be071c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_last_modifier_id_38be071c_fk FOREIGN KEY (last_modifier_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 b   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_last_modifier_id_38be071c_fk;
       public          taiga    false    206    248    3511            �           2606    3599132 0   wiki_wikipage wiki_wikipage_owner_id_f1f6c5fd_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_owner_id_f1f6c5fd_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 Z   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_owner_id_f1f6c5fd_fk;
       public          taiga    false    206    248    3511            �           2606    3597823 2   wiki_wikipage wiki_wikipage_project_id_03a1e2ca_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_project_id_03a1e2ca_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 \   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_project_id_03a1e2ca_fk;
       public          taiga    false    211    248    3565                       2606    3599152 >   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk;
       public          taiga    false    206    290    3511                       2606    3599631 Q   workspaces_workspacemembership workspaces_workspace_user_id_091e94f3_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_user_id_091e94f3_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_user_id_091e94f3_fk_users_use;
       public          taiga    false    3511    206    347                       2606    3599641 [   workspaces_workspacemembership workspaces_workspace_workspace_role_id_39c459bf_fk_users_wor    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_workspace_role_id_39c459bf_fk_users_wor FOREIGN KEY (workspace_role_id) REFERENCES public.users_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_workspace_role_id_39c459bf_fk_users_wor;
       public          taiga    false    3959    326    347                       2606    3599741 V   workspaces_workspacemembership workspaces_workspacemembership_workspace_id_d634b215_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacemembership_workspace_id_d634b215_fk FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacemembership_workspace_id_d634b215_fk;
       public          taiga    false    347    3900    290            �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   �
  xڍ��r�:���S�	nY��z�3ۙͭ�Rlu��m�l�Sy��H�8 ����E~e$!�"��p����6�/��1�׬�L��!/-u���]��eO�y\"ֵ![[��4~IrmA�	^����-+����y��Q�w�zD�w��������8_����ۘU�	ߴ���}�`���,⽃�/�ψ��
�
^?F�^k�ʋ�e���}d̻��]c�z�.xt��w���w�X�̳}̋:��w���B�{�rϮ!g�c��=�=k�c�?�RL���q����n8 &���u����1��_^���br�^�� ��_v Lm�m����=<���iX���~}^�J�iļL�ٌ�w�I���YϘ��5�?���x�.�F;�JLg%��F1��ƻi`�+�@��,�}0ι	h��G��&a%���)4�Dā�P�����P��Ș��c�����[����j�V@�m�k3I����hJJ����,)���2���x�>O�e<�ȭ5��%"2S*?<%���)!DrJf��D��y:�]a��My#�\����h�<<��va�l��ZǾ��6�� X�����XX�G�mrX,��e�.��m�?>�[V�Ր[�F$��� -r��� �n!H���$g��}��x\�­��1o��!�'w���ސ8�2����pԚm�sM~��|d�sͶ������G!Q��B ���k���vWv���u{�5�賃�1�诃��[B�Wr$��麘�e�=�:F�g���/��G��3�'�D�p���򝕵���9�r&2�"����L�����g#s~:��d����yX���p����
�����T	�(��2�05p��=��7�4��C+�����<Q0�D�P��?V�Ѵ��xn�^�|��"�"�{������"1��_D+qְ��o�>�<l;i���dp$�&>�(%�U��������T\���<>�C��=+:�������
	m@Fd�OE��!cD�(�{)��Kd g�?��1�=~6�>���6�[u���ɿ�b/�D�� x�"ޏY�"��+�x�=���ɣ<��e�6�'^T�2Ƣ��"\�X�`��Ƃ(m0^���B��!y�D��@aI�BP���4B&�m���Ʉ�[��qBau:��V&V�A�k�����]��g�4p�
1*΀�2P� !��!�
�a"mV{�s�=Ym��P4(m�J�1m+��U뗐�$^�����x�G��p�uh0�,}!I0�ea*��%1D]a�x�~|��\vòܧ��a����}yQ%��)���Ķ>es�6���)�#��J�J-oB���Z�Δr�6Ѩ\�29U�h�ܚ2r��w�\�m�2�j;��ܛ2�`m����)kqNVְ.����R�"r���ٜ��z�A�k��@B�?۬^���!��f�*���f�����֪~+��V�2��v0���eL����d��!���B����l��c���N���_2/�0�����f���7��1��p%O2:aT�L�R�,�n�ᘣM4꼓2'm���@)�0����o��i��&�m^�4��b�b�������,b��������x���ܤt��jw�����,5+��Fd{��#�4�͕)�9[_�e�������hp��u����"+�E�Wi�("�T�����^��#}��+�e�@^���[�GK�+R���9�{&͕���0�?u�g����c<e��~�G��}���d ҧ� B��}g���-�۰��h4"��d�R�,�R� b%��S:7*��aR�p���@�jw"���!Y�"�������C�����(g���/�(���O�^"������fժ������R��M��OxD�!�OxB� ;T�]	�V�\0�^��N�P{a!pc�Z�E�#+ �X��h�:f�;o���O�H�V��V��k�K� �}_P�����ө��k?,�Q��u� Q�w��l��(�~��Ms�Pu������EE��2Tk�8*ڤġz�Ģ����j���}il�p��l,e�7��V���.�p'+𥼚t���T�7k�j��6J�+B�Q�]��Ta�d�ve�1���8�fW�L�!>���p�4H-WN�y�%Y�tG���J�������t�`��`��̿"|�7 G���9����8�o�����P"�H�-�"nK+,�&�tk*s���6���t���9/eES��g�%��g��K"�����M���e�>��5��B��;*��M�����V���p/���H�L��G��CX�>�2b]?L�!ֵ	]4L���L�Ja�@�
Z�ѹL��L�1kݚG�1��
FE�"J9�Q�W]�`����8�ކ��M[�R��MeyMK�˱JD�Vy�cĴ�؁Ċ�������Ǽ�e-�x���"��Ȼ{�bWOm�=TŞ�W���F�L�!넃K'�$�$^���V�K4���N�L��V�J6�!y%y%����w�W8����X���l�"q�.���t.���в%�G",T����B<<a�Nݶ�z9f��(���x��J��+��� "p�
�+	�
`�XI �'`�N%A���y_<�%pOy)�'��_�D42Fs	�Xd�}�%>�}</o�a:g���@�󐤴��l�0%f���.5�iOw'�����f�Ⱥ�t�����t?��#��"����;��r�B;��z����b��e\�έ��:�Nny�R��&�r/�T��8��MrR�v�J��_y���$�u      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   �  xڕUђ� }&sGT��˝�PM+���]��FE�jwf�����D8���Y��S�)�!^��5C	+����{t����l�V�U�4k̓Xv����W����������e�3z	�A%�-�7V>��}q�9�A}�P��r���;/u��c� ���U�*0�_���U�=}��[UJ?��ӟ��\�ޚ,�cv7
�V=��x~�:S-:��]=�/���T���_^�Z�1��h��(�	�o�ՀTN�8~)�t��&�o�t�2V��]�?qw	�=p��������>���=U�J��Dg�X��������i3�w��K�	]tW�U���R��@H�7�-�[�aOU=�7Ĺ'f��Hݧl�����ft�]�+?�~�f�Y���}��4f�xu����j5�&m�-k�i��T���S���
RqT���e�(\Y���v2�9kUC�M+��4S��
�ew�NQ;{�	�D|i�y����vV�o�l�H�2&CO���fg"�6�WY�e���jԼ�46A/�U�,.�H��_�0�#jm�i�._[{+`���U���bvG�n�l6!�K����4n KO=��ד�{v�5��2 �Y��I�� vnJ7+J7^}=t7M�f��r�l"���ʊ���9� [��2dJOO�� �?����      �      xڕ\�r�8�}V�}����[nC�h�]Z|�������B�R%N?Tے�K.'�	���t������WY	!d7��ٯH�[�K�?��m��Ư��9�/!����ҟ��h�e�P���0H8-��"z�n��@Ͽ�s8}���v=u�ݎ���lz��0Ԅ�n���c���|t��Ӱ�
�X!HM�N���|R� d�e�y�l���|���^��v�k�|#��X,@ �MtXm�����/xr����b.Ii�.����]w���}��;n��ZXl~HPr��1BJ��̓8�uZ?Is]��; I˔C�9������<=��AXa��$)�c�q��1\=�����mO��D�ڠ��#��h��?����*�����n����zPÎG���P��/��T�]�&i�t��K����󕲆5�4i0�Q�����a�\��'M=l~u�����b�4,�&,y�R+�}�6��%��� ��k��O���zy����aj���r��l��n�'K㜥�3��(;���|ߒ�W]\4����;�+C�����z:_�[���ӹ;����23oC��d�p�]�W��L�B��h	��d���(P���k�Vg��+����+�wp�~W
�/�Q�S�fu�fI��އ��i�.uR"%���Ç�ŝ�v��@�ki�:���J�z���.ި����z�h�nJO��R(W�x��&���Y�׷��G}�J��f9�:��r=_s��v������D�;�D^`�'	;^H��B���"��sv ��<��N��j1Q�����t�%��B|�Ʃ�fZ΁t�e1yD$�Ӕ4�AL:i�eA�n�Z�A�ِ�4b�ʮW�9��֥�u�~jw�ޟ����-����Wc"Z�cak9�j;	c���6�����w���(|^�����u;)x��J�W���p�`�����}�Rh���S��`��u�8:������g��݈��tއm\`O��N����q��F|�RTK5(-���5�sx?� �] ���0 �څl4 ����/9с:|�]�A��l4�<.�P����S�=��oL�������B$늅!Oȹ�{�����u��j��R�!��*l��X2���b)��{<��1��A����>�EK�ʴ�V���ˏ�:)�˴YFN2ԥ_9e	�O�V��U_満AN�լ�0�2�q�U�_���͂�/�{�L~���m%n)��5����NҮ���6�@Z[�������=i��8)Q>%�~��l:2ɋ<>?L�>�@(9q�cP"�QNL�O�]<��Y�"����"�$W��2�{R]71�ȧ��:m<�!R�$��~8�����H&1�;w:BA��rq�Ap�M<Ywc ��`��@,���f�umhl`����u�x�&4c�o�ᴻ����uY@qJ��]����qx�`�qx���qx� �܁`r<�&=�APOv�,}>B�AO��~q���L�`&�e����R�J��Z�Z���7

��>����ă���;<6��0��BH�� 
��:�1�|G.~�
�;g-��V�:��g��Xb��h�l|tDG�����%�1vj����X�!ͳ�j��c,����h�E�r�'[���!4�J�&�)�M������QV�����E!�W"����(Ջ	�s~��]�d0��Q��aD1���(s�Ш'Ջ�ђv<A������:��LZ!xXj���h%��!@+a��@=\>@�%� ؘ]�ᑌ�#���Ox���R�{��3�q �}�x�#�����p���ޟ��=��і�@Ğ�~����A�ay㡹htR���`R�"��#S �T�>���������>�J�%$���d!܏-�oR��Lv�>�},î��_�`x��N4*�t5��6D7��x��
\���������~��{���R�htT�;�����~�ٟ��)+�(�rUM�ba�=YaS������5%��!���*Q�@U� ��q�y=C&�����{�7�b$P��v��g��"'.�m�����k�7Ϊ2�F���hTb3��a,��F��n d��`!9�U�htY�"Fl�ܗ�0F˲L�*k�!�k���!���~7�������� �a��}uFJ]�yYN
��G7&C��Rn�ظ�HT zY^
 c�. �0�2S����* ;�i^�?��fM�[*��>�x���)����#����	��)[Voju�5�MpbsF�6�D�V7}/`�lt�ƭiu��)oך_�hc�-��4S��[��廻�.�Z�(���jj;s��l��s~�K�W�t9�`e�%C>| �hdkgg��˦������K<a�!t��m��ɮI{��8Tcr����7^���8�(��j�p�"2I�B(kK*,�N�������ص�hY��bc�|T�Fy��o����]�2��k�/�~͟Ï���Vf��]�^F�|m>��x�ryp����!F"ϋ{�������xv���гr�X���$5�?�pM��B"��FW'Gj�<��,-S�QV�]F?�p�<i,W6<=���b2"��^yC>�c�'��5��G7��"�Jh�S��\���0������ǖ� �9�\�������t>~xmmi	�~��x��%vU�RO'�$f��_Z�YZ�̤�$��"�ek̤�D��-8n��i�=��OR��K8�{�r�s��b]}ԑ���ɤ�!�1�H�YH�T;~9n�.��+�5���$SC�y�H����y���Z5�@��tP%��F'ĉ��U
���[������o�`O�]̕K�2��e ~#P>��_��x��c�#��U��I�����X9�ը�V��{�m[���v�<�L�<X� ���羚�7��Kb}��W�cV�{v<^;S6�j~<jb�0�]���G��`=����غ۞�Ț����w�db1��A7�cwz{�����~6	k��ƺ��i2X��_Y�c�:�Eh�a��Bnu���X�N�Ekm��7��)�̈́N�.K'x�0Ò�����㿌%Y,)��� �D�B���+Z� VƔ!�V;��7-�lT˩�Y����8yc���V��
��j%6���V$��� ���d����P��'"�a!$�2.^�'rO*S�om���A��9���9_�FH�I9fs���&��*�4;ȱ��#l.���o��#p.��e|,;'N��������7�P4��&�L��\R�xo���哐W�<VVBO�&��%�?���
��@�2����ʉ�v�wK��~ȝBһ�}Л�����~� �({O����t�t?��<�He���KU�p�)�7%㊁�c��)�S^ڕl#�Gٱճ�N:�fSnI�Y�*�h�������ǫU��BS�ؘ=O�#��TxAЫ�V���ْ�*�)�(��,��,���VRm�N�3Lb9�)+�V���뇒	��аb�2�Bov�{<!�~�<Zc���_A#�չ��Z�.;k ��-�ߢ>���	}w�x�Ɋ[n���J2,s ���� �	��-��n�(���[���T��kYR��H	V>ؠ|Y83ɏ�����z�����6�=���?�.���jn���-$@��E�����%��<��ćܸ/�c��Yt������qlӶ���"�:�x´p\�>�K�G������'ݾ���<�s��o���k^�B�csN��G��tۼ�J�q��ħ�H�>^��Rf��t�q��l_f����ˮH6U�jN���Do}1ⶂe|M�c���uz��MQ�%�P�^[,W�!�\�#ٔ씕����,��� �nPS)�����~-<�q�T
��b��e�&���R�;5������5�2��Z`uw�9��c�
ze
��pe�]p���� �*U��^٩����7���O����ڲ�vډc��'�5� "^�3eN�vکw�n0<�պܱj�Wv�sd�qJ��n�Wn*�=9��������
��� $�t�rGh��:W��_9�< �  Lj�\5 &�A֩�~�T!���!L��4�t������~���*�FA�y��Ga�����n�e�/ś���j�ҵ�O�\�rR�D�)�M5Z���p�	�Wa�Z��W>�b3�*'_��Lr���OY�Ab	#oR�K_n�|��t�ņ�K�ǏrN;S؞�F���7�d�����젞���甙R?���ԍ�������]̏,QY��_��I캶Erjŗ�b�u����O��r䈩�]4�}0�b9گ���?�חW{�`��Q�Z�q�#�	�����A��s������+"O��X�BX�����¾J��t��/�C-�*��� XG�Mi�#�����$@co�g!��{�\C�wv�����)�t�^AI�Y®?��#�|��*�F[���:*����Ă(���R���"[�[�:Ń�P�:��J��^n�Jבrg+�������ȱ��|��*��r���d���y٪vj+�i���'l1���SY�ꥍ,W�$/o�/
l��>�e�O�;Ȋc��>�4��������,�7�4͑���Sly*~+~ � Tħ����9(���~�P���٩��(?�w�[yym�7��I�J ]���^���zUNͩ�����@#+�Fy׫KH�,"��/�(�^�BRv���`oT�0i�r��_���O�I�_F�LJ�s��I��������e 	Ã��&�����"��&�F1��)�q���rn�ܽj���B�&� J���\��7=D(�K��h��q��r+����T�|���@R��MN~~�]��0I�gAT�E��mw���B);)/h ����W�y�WN��Mwi�˭���q�f��Ah.3�_s������؟1�]~�Mdo, �N�6�8\��SC�(I�ws�P�>��F�PΕ����bdo���� ���:�/O�L)!$L�K*���`���D�<�[#j�\p��[�ް�I�C&	�T�qB�P��z�=����W����ղAC> ��,������tzy�r��w��F����V�$l�iH���l��d�\�4"O��5���7]i�����e$���@��#|<���ꤰ���[�{� �-�[Iƾԅ�ro]��fQ��h��/i�.��%u�*��3�+R�N�wa  �F��{7�(ND���Ret.�*1Oe�D��U��0�<�ӥ$�x4�qKW��E��������>逢      !      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   �  x�u�M��
E�Y������Zzo��� y�;�I]�I�/I��濇�M��?��H����o�N�*�����?�8s;䤪VH h���j�Q; '[k"N�N����1ęb� g�����Ù��S!g�^��!{@��4�/�ե��_ ����;�VWg�� I&s0mU�x�g=����JŠT�8�" �!Cg��Tߌq�0�-:��f$ d̄#ڪj�*פ��s�ï���l=�6��>��d���J�4�2�&�O�֥F��=9��$��U|AP��b��"-�cBR��1u $$��Q��m�ݘH�AP�"*s3#�
SQ�sv��e� ������gfV��D�`D[�~5O��T� '�E�i#1��\���Tg�������nD�j5�$i����j%`�R�V�����6�RCE�V�u��D����jG��B�X�A��7�z�0 Q6IsD����J"d!
���iR6�H1���m5�媕�P��`���!��d"�)�BR��IU�� �8� �k����8�h����j:VB��m���lS�jPd�9�	`�������܋)Gڪ���d����� AٔΫU�(�vN����:�H��Y;��0��T�;�*Eގ��v�ղ�x[��c�r��R�q�I����ܒ�<Z�J{�Z�Ws�ɽ˂��A��\�L����R��8�@(]�Q���Q�I"D�y��R�C*sR�3|���=����M�n'J��F��) E��ȕ��
�N_�o�k��ӣ�X�:��H9a��4�S�`����*�lT����`LJU��u�Y T���!�/�Z� �Fl�P[���Q�L��G@T���	e�ɀ�c(ܣ<j��Ew�=����W�~@U1Shq�/|��N>�N����LX�<�׉B>ϙ��^��'����|���dX2[��n�^��DF�]���"����msˊ2@L���z}04*7�>!j�h}U���^�UՙU�b@�E�^�UNtOu� T0��G%���S�2����Z��F��T�$�P[�*�sڴ&"��
[m+���� i��PDڪ��W�-���;���j��-��X����T��>�;}�G;�R�FU��	����;B�juF����$r�Q�v���"�*j�����<�
H�K7ZeuU�s8�HN�ֆR��D�z��T:/z�ٜ�/�IkN��Ty܈�PP�~���E����T0O9���s��b�<ב���m���y���=�8�[��D������w�Mli�0�s��ah�Yj��Fu��r�,"��^��9]B�,�M{�>ţs���m�MC�U�t�ib��z0U[���n��*�N��*�=u�� �#�i������,HaT[���+�A�ܓ%Rk��s�B9=7:���7�Y�챖*����Y�#�\�?Q�E�c�^U*Թo3��\���8���kL���K�=|�놅X+G�	Y�v7��,(���Ə���wXڬ@,�0��U_LR��s���oѱk�}Zr�\uz�MNh�\��oxnM�&9��(��+v��|ز�ð�z��M�/Agm�x应��}�J�nU�MJ��ْ"���8��M�{��%臭���+��g��k}���3���B�
���R��нG �#+Z�K�?sM�~Ư��rDJ��*|QPN�R�L��j�g��O���\�6�;S��ҋR�Z9IcT��;Wz��}�O�\���P��홌���Lk��a�=�����Q�p)~�J�t�7.G��`�V����|�
���3!�V{�[7��;Q���j଩�J��((gePҭ�߉���עƿC-��jmQe�a	be�3[�U�2޸�2��k����â7.C�����U;�����g`��Z?$��>a-�ʥ8 ʜ�"6�� S&� [�ʼ�ab-p��j�VJn\�W�&�Ls�Z|T�M̶A��}[��v��V�e�����\��Z�a����;�|:���Vk�-o���6�O�p0�ZG7����S�\De����>葷w}_��#[p@Vn���x�k�`l.�*�������Tk\���~_��ӱ��k��Ӈ]8���G5�eWqP���U��v���|Z��h����M��*5��EF�k�U`�6���|zf�	#�V�e�\�}��O�V�ѴTj����U��S��`A?�)UkS�Y'�o���}�~|Rj���V��T�Ӳ�aw�5�l։�K�N����u��m��Vu?�x�+�v@��q}_�����f¸�Z��ӷ�~߫���a\�R-�Uq����ϟ� �}      �      xڋ���� � �            xڋ���� � �      I      xڋ���� � �      E      xڋ���� � �      G      xڋ���� � �      �   �  xڕ�=�Q���W,l��}�;�ucag�dFf��95`ԧ�
����<ɥ�����OwƟ�{��~m��n��};�x��]����2M����ݗ�������t�u��O��=������t�o������~�eO�������/>=w�.�S�ʿ��{���DY���*��ٖz�f{���xH���)G4%b��L�+M�c��퉘�`Et��D��EgkZ1'���(ƕ(ұ�bM�"�D1X]lT�HǢ��Z1'���(ƕ(ұ�f�Ẻb�"�٤D��Ew��(bN�Q�+Q�cѡ�I���L9YA���TَY��ń���0Y��0/�'4a�llQ���,�6[�-��m	lQ���,�b^ڢ	�ɖ�5i�ɒ�d��E����-j��%[�K[4a��آ&m1Y�]l��h�v�-�EM�b�d�yi�&l7�[Ԥ-&K����M����I[L�l1/m��B����ɥ �����^ �c�6 i^�9_� �%�Qs
����-)sŒʌBO��yN*s���R�Q(c�
�1�Ie���q@�d��(3'�9ZR���(��@�9��ђ2�5ͣP^�e�2GK�< ���(3'�9ZR���y�;R�̜T�hI��2��[&��<�}���r��(^��	�9�ɗc-�����Q(�	6:�Ie���q@.u�2����Ie���y@*3
e�2�n�9��ђ2_�JeF��[&X�<'�9ZR���(�q�[��2GK�8 =�B�L��yN*s���R�Q(�	�=�Ie���q@�|�2n�`��T�hI��2��t�[&��<'?_p����&w?���Ӏ��=�}�����G�ܐe�2GK�8 w?�ByD
����-)�Tf���(3'�9ZR��9�Q(�\�̜T�hI���l�?��?�*�X      	   ,  x�}ױn1Eњ���wI�N���Tqa��3��U}��ڃ�m��z�<��K+��>��R>~�f^�ח����˭��nk�ZZ����������P��{=F�j��\t;i�m�b��ŰE�a��d��p3��h�����a�x�h��FOkG3NͶht�W��h4���4��i4�A����ь�F�M|���׾ZT|�36�M1O8eeP�TsF���V����2v�պu楊�X;��0U$����i����2Edֆ�L�)��6�`j�hM��ekSEn��ͫ�-��ћ7;ٛ*zS�OX~��|Ĳ�g,#z󰓽�����y���Tћ"z��{SEo���O�M�)�76ٛ*zSDo>m�7U����|�do��M�E��޲.���ޢ�bo��M���bo��M�Ǽ���Y�x����"����vFr����c�2��Qݮ�.�$��ng��+ʋ�5�����bfe};#�]�_��pg�+�5+TvD�+*�-+3���ge�;#�]�bOP�wF���?s�){�;��?t���'�`�;�Ƭof�●�      �   {  x�}�MkG���������oG�q��r�%�rp��&�>��ٙ��~�&4�J�B�~�j:����D���w5Un�^>~|�q�ӧǻ��O??����������^�{��=9�鏇���w���������$o/������K���_޿=<��ÿO/_Nzz=�{{��>_?yΗ�����ݧǯO�����\�������˃s�|�>�^ޥ\ߥ�����Z>}��ߟ^^�?=^^R��&Sm���%�o�?�������uS���1�hTηrb��6�d��{;)�gO9�˵�
��_g���(_������s�˞����3�|]~���g���1��(_o�\P���:�W��@�����5_���=���1_x��o�"(?�|�q~��%��l����W�_|~�嗐�G������4�/{�2�/&_%��k�*̯._�,�����(�n��W������w�_M~N!�]�3����3���1?�(�m���7���8������f�k��K~�����Y~?�4���B(����<��{~��M~�ȝt�/�'��2%O
�C��m�'�t �d�}��B�8�E}u�>�:�_�_�o�_��s�����V�5�V�@�
lSR``2�66�@rl �d$ؐ�R�E
�b��-H�m�A
lC���9H΃x�;!Y�(BZH�1	ɛ�OMH�}�B�Tء
ɱ��qaG.$�aH�)aR>�a4�!R�6R�@$'DJ��d�H	!��)E&RY���H�0�)��a�H�� �y�����ɚ�(��5a6�w#��T��C:R݇�H��$YAGB�bHb�H�$�2��#������!@J��$1�$M#NRsÈ������aSTRP%ɐ�����?R�$cK�K��$��䅗$ؗ�}I2&�8��09�À�����ɞ0!d�E&iT&/�$��d�Lҩ398�tMޠI
��N����LvȚLn��F^�19r<�9���c<u��c���1�G��ѣ={���џ>Fs�z��1:�p����x�����2Cw�s' O6���V�T"=Y��XlO���2�'|R�7}R��d�� �d��@ euÈ�U���S�rh
�w�V(P��@�lZ�@�	�F��*Њ��֩@9
�ʻ@({�6 P�mH��ڢ@yh��@�T�چ�]�
��@([�6$Pv�Q��
�c��A�}*P��C��.��^���@;(;��(P^ڱ@� �>(�r
�7�r���Z@�l�		��@9E��"PNX���i*PIqC�Jڇ*�T�]�!��(S���m�/P��@%�i(P��*N�L@�BvH�BnQ���0�@��y*P	e
T6�2C��(3��2#�
��`��y���0�Kp����e^��M��U�݅\��m�D��m�*���L*q'.C�ʾ(P�{q�$Pq�q��E��X����� P֡@e(+�8����(+�X��F�JY��*�0��@��a*�@9C��(g P1�*V���@e(g,P��<��xud(P��0�@��a �J��@+P.Q����x�r�
T�@�*m�I*N�\�@���47�(P��0�@��1�D�֡@eh�/�
*V�	T�@k���X�zh�
T�@�P���B��hU+І�N�-
TW�6,P=�M�Q�m(P�ڠ@����hCU'���@�ڧ�(�>���P��ځ@�
�#��h��U�T�S�jh
Tw�v(Pu��F���@�
T��B��W'W2�@%�/e�J_��*	_�T?t5S�0��LuÈ��~&a����T��h�P����$(P��4	T�MMBU+�?:����|      �   6  x�uֱ�T1����5�G�����< =B#�`(�}��Sz�i�K��Y���=n��ۘ��������{v܆����ُ��������������۽�G�e�d�	��L��2�Є�E&\���.�h$ލ�D�2D;Z��AV"�e��h%�Y�t��)��J�+Y�dee�9Z��NV"��r��h%�'Y����&vAoM�1qѴP7���U�|30��*auq�8c�W�ڥC���l����r�9[լ�t�9󜭂�)���Hg��uɀ�30��*k�d@��lU�5Pv����Ve��	eg`���|���9���U��rB���h�ʶ.���dg��mȄ�30�٪l;eB���lU�MYPv&;[�mK�����Ve�%���dg���ɂ�#\Lv�*�U.(;����v����dg{9;����Gzz��Qi{��ޅ�ޱ��8(��c�qV4(|F|�j�g\X�.L�����x��wa�w����GH}f}Ǌ��x�ڳ�c��5!�]��+�n������X�� l��.�}F9���gwzxg��{ v�~�>��O"����m      �   �  xڍZK�-�W�"���Oy�d��d`������%���m��A�(~��~�������������������o6�� ��d���I��������@ǯ�o9�Y\�$no9���[J?�-D>
�~���-$@��_��b��?�N�j�u�`�z����F��:;�-�}��ތ�����֓��̵#�cx�}LN�����p���t:���@Sf].L9�59x��q_r<�p�i'���f�X��{�B�&���̦���r2��зF�݉�٦~����j�?_�EGrHU�;�8����t���T�L�E^��jńW�h�I��S�n�~u�b�f�F	�*�.uQNe������4pis�I�ð[���/��+�(J�}9��kF��&�y�ːO)�.G���=�-ƿ�Q�Y͔c'`-��!�ߕ��czQL�s��S�$P���,�[�e����%�)-9Ǉ���ċ�DnM�:O����C.�K�>8����wV	��)�V��%Č�	��1So����N�Bp鋜���N.����~K����{�Iq�IpB�(Jt�>�<z �\�������
��#�欶��-��!d��6Aʾ���Z[�f�	��b|}���	���������u��<HT�8}f�H{�%��JkAN�W�-p)ܪLI���ծ-[��Q��Vn;��Ze��������暐�`� �	&NU(M
1�rS�%J�(S�up��b�*97���y&�x�����f�)Ml-XT�P�Ƌ[�>3(�U�dX1Eg5���Z��4%YR�\[���.����U��x?5v�nI�qf�U�j``m�=�C�X�����=A��6�/X[�$����Yh5���Ny��M�j�1{�,U�ꈅ@Kʳ�K�b��i��>��>�S�=�f�3	�7����C��o(����7���<[d���b�\��g���2�{m�Р��f���oK�4�k�E��I7B�6��T���-���4+�]���l��n����J�/���G���tlWte<|I�z":�O�����KM�]L֖���P�:�I�c��ƺ���:Y�I�����������f����Ĭ6��p�XbR�8���fJ�j�&��WʶV�أa�$<�����^B�yr83�`�n[mX��jJSS���^:4��X�����QUvKc2?pMϾ�'q�s�A;��C��B_�-~�%�֫�w���$' �W���DR4���׬К����o� UAn*��9��ٱ桀z�b9I��k�²�i2C��U��c'B�5�>�͊b�� �LKL�&`+����4�>YEo���1�%��p,,H��I����`�YO�V\�z��<1�95T\���l��# zz�]!�J�T�'����]ݐh�q��hR5J
��RN	uz��L�2Ϥ�*{���׼ܾ8Z�5)܃�+yڗ�����%�vC΃7Y�UJBN�d}��Vէ�:d}��� �y�r�EK*ET�zN�T�]jk�H�n���xq���j�BSm�ܡ�-E��KJ}��"��Lt5I+�/-���_��s�ұ��V�Ylh������f51,��Y��)��o�}�2&��؟���`���^�	@�.��%�w���[que���>�$�i��}3j���0m(��d�;n/�@hkX�RP�㨷����*��`���Q���HZ��n�!�ӽ�{��C��փ�Z�6jY�7�[k�BW]m���ak���1���쏣|��!���D~
�PJu"��c[tX_ᙋ�al�ە�D�����R�>D6z����ٹ�*������v����D>�G==��+>	Q����8�Ƹ����p�ېL��mz�ٞ����\�xz#%��� �����d{Gi\�s6�a��lw�2^er�G{W[i!���n�^��e+-�"�P�D���p}T��f`�l��ק������Z���-�,�~p�����(]��@����?������eQ�:Gl��#}h�┎F#X�1 ����4N^,�5W���"�F�tO��l}�W`���p� Y|4�Gì0��ж?j�4�{@RǕ�B{[5ƴ�3�$�I�Gc`�շ��&Kn���1���v�_nJӡ�nrxKG�M��� ��h�i��O�y�����.      �   �  x�U�M��4��q{1��O��+`��@ҍd��s�c���{q��?���߿�e���?��>���g�|�:��q��g'�*�qa�?˸?�X��|?����>��,��?�ǲ~v����9�:��9�G�<��`y=���~���9�:�/�s$,��	X癠m�	�癠�g��z>g��3��s&,ϙ��}�3a�<g�r}΄�3�<t�3A�<t�L����LX��L��?�3a�<g�r}΄���	��9�G���L�5���L��g:��}΄�Rg��LXnϙ�ܟ3ay<g��|΄�3�<��g:���g�����˞n�㍥�K8��p,=�X�?�U3ՌC5�Pf��g˞q�3��gK�8���kܞq,�5�P�8T3e��q{Ʊ�=�Xz����c���3��q�f��jơ��o�<�X����l�s�)��cε�k:�sҩu�f��a'3���4ϻ��ϼ�<��'_��s�Ś�
��j@N�y���<7�'�'��'��'��'���z?��~�����Sǂ���>�.DnDp%�;\
��a�"V/r#W3r�Y6��]�6܎�z���.HpC¬H���*I���Դ�{�(n�NJpS��\�଄ٕXa�U�\iɳ���O[ī-n�-"mi�H[D�"�-�ۢ�-�����	�-��7�����E�-"m����n������-��7�����E�������j���n������-��7����%mi�H[D�Ev[t�Ew[�l��-��6ִE�-"mi�H[D�Ev[t�Ew[t�Z���^�%t[�p[��ܖ��%̶�jK���ڒ�֊W��m	ݖ6ܖ��%�-�m	�-��jK������W�����n�����w"o1�����d�~���m���:m�|�q[B���%�-�r[��ܖ0��-�ڒ�-9m�;䶄n���ܖ��%�-a�%V[r�%W[�l��[`�"^mq#mi�H[D�"�Qm���mx�����	�-��7�����E�-"m���r�Ew[�l���j�i�H[D�"�0��j���n������-��7�����i�H[D�Ev[t�Ew[�l��-��6r� �-"mi�H[D�Ev[t�Ew[t�ھc����mi�m	nKp[��ܖ0��-�ڢ��AN[��-��҆�ܖ��%�-a�E�=�\m�Ֆ���r[B���%�-�m	n��݄0��-�ڒ�-y��mP���m7rG�F�}��[9"�rD�̑}7G����st��x/綄nk�5��ܖ��%�-a�%V[r�%W[�l�{�2�W[�H[D�"�����ET[d�Ew[p�eȳ�J[ī-n�-"mi�H[D�"�-��2�n������-��7�����E�- wB�Ev[t�Ew[�l���j�i�H[@�2��E�-��"�-�ۢ�-z�����j�������E�-��"�-�ۢ�-:m�߱�.C趴��%�-�m	nK�m�Ֆ\m�}�!��}�ܖ�mi�m	nKp[��ܖ0�"�.C���jKN[�
�-��҆�ܖ����f[b�%W[r�%��}�ܖ�mi�m	n��]���%̶�jK���jK�_�v(ߖ���%l�.C�&"ߘ�|e"򝉨/Mdk��k�ߛ���&�-��7�����E�-"m��m��?hu[���1��q�2�      �     x�m�1�P1����ۣ�N^��!Q N@CH��h��zRθ���>���׷�W�^^��׏��n~}{���ǟ+2��c��q}����5���2Z�M]�ݼt[�ۺ{x�M���۬��lA�i}�8��q��Ʒ��㬛��/�㬝�ٜ��<t�u�8ۤ�c~�8��q��8��S�hM�d�OH��
,#�nQ Cf���EAY�e��7d�����Q�Cr�l��6
tȢ���e�p�,�Y^�6z�b����f�Y�!�?o6�o�����]�C����sV=r������<�.�!�������U�C��ϧ����Cd~�*�!�?D���v�Y�!�?߶�����c���,��_4ۅ�̏�Cd��)�!�?D�nO�Y�!ʡͣZ���zlqm`�m��Ӆ�l0����TfyQ[��t�x*K������b�T�;c��t�x*{�'c�ty*�-ca�婬r�����sx�B��B�T�9қ8O��!�A��� �~QY�HoQ�<]tf�������R�      �      x��\kwG��L~E�i��c�9�=qb;Nl�=Y��]���Z�A�<k����4Ȁq��FМR�}v�s�>U
��?�'��v�ΚPś�+�.��eZ���R�z��SvC>�ѯiꖩ:O.V�������<w˦���x�c5�5����o܎�T��!䐕�b����o9�x.�#\-�-�5|t�_ƃ2<�}�4JS��r�~Ha9�7	:�Fx)<͒)*i��<����L�N���Q��5�p�1,�ɴ=kG�����(����|��m|�h����s��UӢ���4-�<�*4��j���3�.���Q�0���v�4�^/�Y�0x����t�E���
�jc9<� ȘH���;�DL���WD:�8N9��s"0�rHVR�<��%��RBE�>���aب �/w��YS�r�|�\��z����EWa�\5˛��To�������E�����)��n�HiY�ErեC�4�*�t��4��m��{q*VC9%\�i8��q')�dl����L�zb$��D�b�$��Z���I�J�4F9��*ʔ��@�r�ک[4SL37�u\4Wi^u�˴����j�F��a�ΰzwX����2z�f�:-�[�~(����CP�J��!��ą��yk'd�$N8��)R�RP|���l�!��@�M.$�Hp��V+�Yև�k$d����u�:�r��<�/P,V]5\�(o���G�ÈZ�>��c����-�M��j��Ҵj����Z��.bu�v��ro9)N`ʚC�X���'�bNCE�è�1�B���("&�Dj��$��&gI�g�Q���.E�ȱ�[��?JI� E��x��.�:���<M$��k��52�<�lS��@u�v��֛���y���@�i���T�-]՝�+$�n��q�zc��v�S H�� �x���l]�X9����k��.la�'��@,#Qx���E>z��C8j��y�,M����*.,��*bæp�M��x=�F���e�cYwi�5�*��R׍��Q�'������?�ի��Ɲ�/+`0���*u��\{�Dwޖ��hBW/�qyh�T](�*/��~�LDV�Oɂ�4���8�#�����i�@��RTY�j�{�2F�d� YS�;k�$�昕��X�@5P�D"�0rzM�
|�_�R�sV�K��\�>�]�i�#�~�Uo��oGՏ�g�Wf����y� k��٢�����C���"u�j�V*�Ġ��� �V������ �1!o��A2�v��,���I�Q� �M ߣ9gl�b
H)���*����0HfT"�[n�mŒr&8����5~�6�
Ze��Sߍ�����w��y����!{�ӗ�����W�����\(Q��$0(y(��������G�$0����PY*C=/d.i�B���(�G97�9�qV��2���|�F�Qao��J�;wW�?m��V��r�f�.�CG�`�{k�k�|s���G��Ӓ٪9jL�k]sV����G��i�!�=�v�%��W3���jVh7��a�2��+R������Z)��x6���P�����r�
ɉ�̛3�4�	�9I���H��0uD��ur���E+��^� q@���/��y�gE�b7r�1�0�>[���͘z���7�G�v^��Z��#b<5VsWHwu}��%��r?D� y�C�j�I�DO�H���1�ҝXr��lb'<���(�Ҳ���"��`8؄�-T��"�	�"єmbGb	��{�����xUz ��jx^M+d�+TvH��b�{}k���5�o��=�py�"H]�7������^����b\}��g�kQx�]��b){����O�4���竑SI�n5R z	�\�T���(��Zf���a���0��:f!䞶:j����fC���݆W�p���h��0��?�ןn�
��?~�4����WS�:;��64iy3�c�C��=�V�r��#�Zjn���-Tj��ȓ(E4�	� ���!�e�@�e�Ne�=�Iq&C�B�p��|��h�/x��Z�_L�v��+H[j����t��'�~@)_�;z�jS4�ͺผq+գY�vs�h��]��.�mW��C�9ۏ�6���`�Ҕ���Rc$ B�6X���1��{r�:ʌKJ{CW��qm�A����N�x8�X� ڷ�Ρc�+)�&��Mu1o�A�ϒGt�V���zgD�L�N�O{�ʀ�'i�	9�B)ZV�-�yO�!\gX��e���+d�i�����N�Fܥ�B����(1�ƘRT�H@��D%�����@@�L21��6*4�mi
eE�]��i+<���C��n�J�t��6O+����}��������|;����m;����57�Y�t��@A���*OZN8�ϧ<=f(w������ �p�T���=��(eL*9	B����mHw&4` 	Vcj�.}3��|�^��qp�	�#�O5��-Jpk������n��� �tWP�];K�L)���߿Ԕ�_�Y[O�A�4@Ƚ�ޯD�ѻ� =�X��<�L��;A��&��]��@is��CŘ���k��1�<�n��7������%{�AFn5����տ����w�jӮ��R��!���-Z�-�v�<W��n5K��N�b�_�f��n\oE�}@�>ϪM���}�f��09h���*���IBY)>D�Zw���V*�X�F[��h��h���ݳ*7d��B�-B�)�u�{�rCF+���q�*\�n?����Y�� ������	}O�[6˞���	uZݴ�E���*�im�G�ʷ{�|��⨷�<��|�rd��h�[�0@�Lht$Q��K�i� GzT4����{�KÎh.}�	�^�#]��^Z����{WR����tˢ[�g�<�k�؇n��^�����~�-�G/���'5����Д��������e���|M�c�)��=R����Vr�k�8��ڤ��P��
�XZ2��:�3���B�p)I �������dv	f�YJ��v�׋�>�2z�5��Vs���7���x��X�P���5{���ϗ�򝚬;���A�D����ya��}�X���e[�V�"���Y�ڻ�Ecw(	�R�Mq��?ѭ?����<��y�r�z8O�9O�>O-_�ZN��7}�Yue�a��2��Nw�\B�NN�KM�ܴ����&�!0�揪[�������=Ǵ�@1�o�_�X�3W9hzD�C͊��c9�yU2j��s�l��q�����%וvѲm�KoP�ڜ���.��ջE����1�z^ń���W}C�*������>�-�A��˾�Q�j� l:z�b�)�ꖕ[��e)�~�^k��M.�pY�7��ޯ������?�!����jX�:��ެF�fG���W� N�&8XQRΊēL�����$}LBJ��}� �#�ӑ*�0Y��f��3�d��UZ�I\&8읡��3�?�_�=-�h��u��U�a$�A��(H����P0�q�UEs�C�B����������,+oc��e*�fml�MyW6��2z麋��������w���o�w�-�eB�(��X����9�R��eT�zC�N&kC���������	��d2�E����8yf��Û�;y��f&�5��U�i�k;Mݨ[ՋrT��~��'�m���,�9틆o�@ߔY�>�+��e���O]��u���.7�ؕedwq`)�'��_q��$cJ�;���
����� �F2�l��)ʘ�E ���].���^�5��[3�*�v��T�����W�(!�§.Κ����-��b��
f������O�s��O���[�`Hq��əD�R�CY�O��M�������@�&R�z48D�8�]6$:��.����^����Ӽ��W[9p��	+�9�qX��_��tL���|v(.|b98h�B����,�8��3��d���\�"�i6�{I�E&1�_�g��8�=��7�7�黣���;�[]w�ۮ����)��r��k+59�?���/�옺۠�1��D���A��U� y  HaM�N�"�K-�4B�'LCT˔3� �g-�Q��k��l</zϋ�����%���?�uΡ�9]!z���9�ƒ�a#�<hPY9*,W0�/w<ǌ�;��}m����4D�Y�f��H��R�$�H@!K0k�b <�U���ىx��r��y�|� �n �= ���]�`�n;{;��|��WT	K����O�F臛��QNԧ;��<%1n�c)'��M#	�%���9z-�b1弶�h&��MFk����cܷ#fecU]����. ��k��������Br�Ӱ*��jvgc�&�n���vn�Rv���$��4�D��3Ƹ�c^0�"1��_(�0(������{��w����滛>�iO�����;D�VM�W�4�Hvz�Ӵ_��4Bː��͕T:�M�TT""G
�R����|���z�,��z��dpv����Ӧ�O�����/x�k�?�iX5�_��}S�^����IR����BiYY�6A�����8�9,�F���H�Ѥ�QN]�'d~����Ӷv��0}�<�)J�9��b]����i�G$�]O�M5b�|��gX��`�����o�a���ZBAZ�-)�l2Lu����^�-���4#��f�^<}/�?�Ӟ.{ �������u���ЊL��E���0��#̄@U�4E2#1�s@r�;S�o�XJYs�'���sp�є�ה����5O��W88��d���:m�؃qp|)e�ߛ�T0M�P�'����
�!}�A[ByJ6F�����(�4Gv�3>d��d��ąŗg�g^o����X�?#�`)� <��3
N�H�.� �����Mb�b�ˢV�69mѡ�q�[�ʰ䀅:0H�����@ׁ$���ƣ�j���,W��ܢ�|�HE���y����Lc� B���}_5׈��XQ��o�;�D;��X�� !���3���GO�����G�eu*���L�^[3����~������hǻ��[���no�-����J�{�"�M*�C���\�I�JM��ɥ,	�IFE=�K`0""�3R�zw]17�R�����摾��L~8o��.+���mQ�d-�Rį��)�B�[��d�4m�(Rﺜ��J0��SL��3�B1ύO���J#7�~���X4���1&���i��m�뭴!���};E������������u+��U" �7�ɘh,�H(�W<-R����/������eU�'Ҋ�`��s$�V��2ɑS�)����yFdc�',A[}����d;��^~^
�;��/�.��˕�6��X��sW����Ë������M��������k�܁:\F	�#!�f��>�*{�O�� w�u��Ǆ㉘_\�qae���'�����p�0�+.#�2e$�%�p&���P`�i)h
�Fr���-Ww��Z�O	�V���AW�;#�C�����oF�����z�Nx��O૬$���*���O|_�+#Qri)��	��_���`�z_�/�ϒR`
Dr�퐴��,�He�W�0�|�f2+���y���|�6�}oZ�5�z�%���o�2p�ୁ��9���{6��(;\@?�^u���Q�-�9�WԘ)�u�Mz�F�J��G�&x���I��[M���΢��"Vf �p���QT!}b����K�^�䅖���b�Q�)�b�����طs����.طs��������_Q��e�.���!�@�s2����mZ��E~1*�ǩ�����7z��)�
2*��	Jr�Riԁc�0,s�5��s���uF}V����ö\��>{*��4��//�>}�����v���ZAY�/F���I$+�l���^6�|1�:N��������gф�RH(�&�R,��K�%i�I`��hb
��//��nQ7k��5��o��B�      �      xڋ���� � �      �   �  x��X�o�6~v�
�{��lO����K�&�Vl�@��`���F"5�����Ǔ%��S;풢�I�x��x<R�����2��� t�2 �IkrC��L�	�2$LjF��L��!!)P]JP$cJH,���3>'j!�&	߬�LpEDJh����1*h��
-�4�L�؄����E�BoU�a�[E�ЄCJQ�"Z��	���{0��L/�����j@�"��4ELfF"�2�B<�*�Ո`֋�ɂB�爥Al�̥X�/(���)�	h���X�Qj{i�=ӊĥ�"�z��C/���pz�G���w��C�Co:B��ǧ�7���$g��{���{�.{��B0���)��H�ު*.��i�Zw��-��$R���KX��)U�L�
@��r�J(X�k�����W}߻���4�NeƷ�Z�E&$��L�I0�uB&�:�r;�3� 1rJ3F�d�,c9�F��,[�Q/����~@������Ql�
C/�� ���cU��R6Ƈ��39=����A�!��I�Ќ���+R�t�.HR���gS� ;|�
�e���ϚA�t������6���D�v���	y�.�;��P�w�z�*m,������ښF�i{gC��3h�Ac���45��adN,èe8���ᴽn'C'�jvR���=۶4p���m�n���.�h{���_9��Ou��F:_Y�f�%>p<Ǘ �"�y*�0�!��� �?�^���Bk�_����ݽ���D�H��.xi�>���8#�.̧��^�������ʬ�}�@��f�MK(v��z�M�W�w�*�Z�Zq�"��j��ms�V�3�'6_�#�[��:x��@�2n,�˃���M�?���ya�?��̳�u|�C�o���b�ѾT���ĤBR�^ܦ�n��~�)�"/JMo2��
��yQ�c�(���dV�7Z�eTK	d��r��tUw���8-��F�4b��+'(���������X�j�[U�m�۴���_�����=��K<���+�YGfG�B��_�G��=�3]9�RZf-�'Im���j��֛RN�Jʹ�%�].J J�� izr��4�������}�{C�&8r��Ə��jӻ�t�yLf���ϔ�P޻]�ZKkV5�Iuq��9���\,3H�@�B�ּ&'���,���RiӲ5ˁ�[�݁\��i\$J��3At�$���X�H52�Qb��\�4^���I�ȍ��|ȱ��\���>���42�l(��)a���
֋*�4m+L��*��bBm@�0[�^k���J(a�"H#��?M�Ӈ	�h4>�Ҵ�Hӎ �Ҏ �Ҏ �Ҏ �ү� ���fG�v�#	ҝ$&Hw��0A�S�F�����_���N��� W���[�4�Ҏ �h�.3]f>� }7:::��B�f      �     x�uػ�QEѸ�7���۷_�28�S'N'��h����J{W��@��R�4���}�>�i�l���o�m�q�xm���ַ��<��x����p���z�����������p���-�2\����>�8o��+}]���u-��׵8��ZL#}��D_8�t*�P��Ш���Y�LUv�h�TG���T�*;5�S�k��S���\cF�::���NEp��S:�ѹ�|v*�S��{tt���~v*�S��Щ��i�~���ԙ�Z�z@�G�!Uz����H?FX�b�*��q���X<�
bU+b-,���+�UI�\�{l,���%6��X�ka����X��ʅx���X��bU+b-,���=v��X��q�X��8@�Jb�B�������B�N��u]�y��m�rFguvf��\�{��Dw/쾠�������Lv����^خ�	��dw/���ʅ��;�ݽ�{b���Z��Lv�®�O�\ؾi�3���'�{a����dw/��,˅��;�ݽ�{b���z��F���l��gZ.�cJ�j���{������v�Cp�e&�{a��[.l��=�;�ݽ�{b�����-3�������������۽�]�\p���^�5����������۽�]��r���^�5�9����A�����۽��(z���L���������}�r�g{v���\�޴�ݙ��]�u��}�vg��vOl��v��vg��vM��h^�����Lv����K����{�|            xڋ���� � �            xڋ���� � �      
   ,  x�}ױn1Eњ���wI�N���Tqa��3��U}��ڃ�m��z�<��K+��>��R>~�f^�ח����˭��nk�ZZ����������P��{=F�j��\t;i�m�b��ŰE�a��d��p3��h�����a�x�h��FOkG3NͶht�W��h4���4��i4�A����ь�F�M|���׾ZT|�36�M1O8eeP�TsF���V����2v�պu楊�X;��0U$����i����2Edֆ�L�)��6�`j�hM��ekSEn��ͫ�-��ћ7;ٛ*zS�OX~��|Ĳ�g,#z󰓽�����y���Tћ"z��{SEo���O�M�)�76ٛ*zSDo>m�7U����|�do��M�E��޲.���ޢ�bo��M���bo��M�Ǽ���Y�x����"����vFr����c�2��Qݮ�.�$��ng��+ʋ�5�����bfe};#�]�_��pg�+�5+TvD�+*�-+3���ge�;#�]�bOP�wF���?s�){�;��?t���'�`�;�Ƭof�●�      �   �  x�}�AkGFϳ�B��tU�t�1(
��Cι�hA
Z���h�wZ�U�݌g1U��>�NX�8_��|�k�������-__��{���|�,���1懸�Ͽ��ߞ�x����ӏ��׷����}��ч��G�>���?�����������}��ky��O�s��S�g9?]<�.���I!���:������ഩ��:qv'&1qA�<q�&���a�F��#��f������b� 9�<u0A�1�K���ulc���jl�v��M.��ylҴS�?��Nbl���<6���1�K;��5�������ؐ���6io��٥�}�5�|�}�Y~�@�y�M��ۥ��ؚvic����.jl�v��]����QӮױ�O���#�]�7�I�c���[�޿:�s���O��!�����&��s7۸į��'�<4G& IiɄ5�<�lQS���L�f��K_&�]3��gn>w!���ެ��R�殼���qn>wa����Թ�ҝ����{f���g6�7f�]
4c�ʠ��~(4�܅C���I4�ҢsW�6�ã��.DZ�ͤp�*-��ri��2->wa�bpo:-���i�ܕP���0j���V�{sjܥT+殬Zm�V��]x�1ԼZAI�VDʫ�N�u4�EB�a�䩙5�>z�j+dOʭa5�S��)��� �iZ ���F��,��Ը@/S��4�)�S�uj�)�>��d��J�QA��T�8SIw��t�6��JB���UJ��p�ۀ���o�������\���� ئ�6��}�ú��W�F�R�n 	Ky�}_@�7�Ky,�_ ���� �@��(z�����$���f� ����[��72�u,�_���x���uZ ^�W��y&�������nb�<�W.kۙ���~�4���MJ�'��emb�uy�؏]�&6j���A��dbܻ�Ml/����o����A��db��MlW/�����F�r71_�L�˗�����ab�}Y�؈_�&�˓�q��6�ݿ<L�0K��� �y21n`�&�#����
fib#���t0O&�!���v	�0���,Ml�0w���ĸ�Y���a&�{���� ��Ġ��db��Q��n⸎7W��+ab2�8�7����41�&���d7qc�1��P_ \���H/`_�01�MI�=4.�LL���41�&���d7q䱀��}p�8-�/����[��V��5�8����L�pqG��n�8���M�����t:���ֻ         ,  x�}ױn1Eњ���wI�N���Tqa��3��U}��ڃ�m��z�<��K+��>��R>~�f^�ח����˭��nk�ZZ����������P��{=F�j��\t;i�m�b��ŰE�a��d��p3��h�����a�x�h��FOkG3NͶht�W��h4���4��i4�A����ь�F�M|���׾ZT|�36�M1O8eeP�TsF���V����2v�պu楊�X;��0U$����i����2Edֆ�L�)��6�`j�hM��ekSEn��ͫ�-��ћ7;ٛ*zS�OX~��|Ĳ�g,#z󰓽�����y���Tћ"z��{SEo���O�M�)�76ٛ*zSDo>m�7U����|�do��M�E��޲.���ޢ�bo��M���bo��M�Ǽ���Y�x����"����vFr����c�2��Qݮ�.�$��ng��+ʋ�5�����bfe};#�]�_��pg�+�5+TvD�+*�-+3���ge�;#�]�bOP�wF���?s�){�;��?t���'�`�;�Ƭof�●�      �   9  xڅڻn7��z�Sp���[�8��Ej7F,%n�@��s�#�Ù�7K�/@���>��������!s�u�������.��~�������j�����˗.������o>�������^���������}�7ߞ�<���������o�������.q���������]��?�=���W.i�{�㯯�����#������G>�O�/m�׍o侱z����b$�G���V�3y?��ם�x�����r\�K,�p����\*�Ҋ�j��x���L�R=,e^,��R�T�RVs��rDKc[���8�foi<.-��,�pilK%�K�~�Z�^��AQ���RYa��Kk��R��4-��� )���H���J�|^�X�ܖ�-R�/U(Ry]��H�/UW�r\����X�җ�"�i)��.��H�/��H��4�D��W)������F(�����T���}�k�����J�[Ok�J�G[:�,]��M�%j���F���J:fRZv�d��H%���XJP'j���hSr}�c2�P�)c��GS�����24�Z6e)ݔ]��Ny��r��)��m�hj���OŠ�F=�*:�SYaE��
֊z@�+�
�`�ZB˫�P���Qe���bx�3�:^MU�W-����(��{uL���
�T5��1U����ث�S��j�T��ʧ?�`���`�գ��C֔U�Y-�(Xh����UN��l��p���\e^��j�Ed�52�ȷ�ZDK�*���Ы���ה[D�/}���jW0��+�8���0� �F���"��q�.b�1�E�:���"^A� ���dLc�MӼ�Tq_mV�n�^u:���:���jZ�sju8���q?�C3�]����d���+���8�[3���j�ڏ��x���K�t��#Śqo1R[3�b�k�jK��[�kO���E��ЬEG�)�(b�Z�Q�4K��Y_�c�Q\j����Y��Ҽk��jK��[�kvj����Y24m���6KX��f��l�f����fi�j�dh6�,9��m��f�Ͳ�ٮͲ�٩��R3�f��l�Yv4��,Cͤ�Y64�]�eW39�Y^i&��2�LF�[3�۬@ͤ�Y14�]�W39�YYi&��
�LF�[3�۬@ͤ�Y14�]�W39�Y]i&��*�LF�U[3�۬�;��fպUܵY��OmV�7��ͪq�8ڬ:����E���FC3�]1W39]2��f���L�Ec�5���1`��ec�4�]7_�ӅcXj����Yo3&G��͘�f�͘,���:����fLK�@�1�����,ͫ�f���4˻վf�t������Yo3fG��͘�f�͘-�F�1�����f�64+c��Y�Wc�Z��X��6c�5;��R��^�04�m��h6��LC_mh�a���L�i�J3h5�L�xY��L�6c��i�K�t����یu���6cŚ)�նfJ�j��r_mh��[�j��6��LA�qĚio3��f��AP3mm���LG�qt5S9�^i��Vc�T�j[3�y5~���Y���ڵY���:�YZ���,6K�[`s�%��x��l�f����fi�j�dh6�,;�Mm�����?0��O            xڋ���� � �      "      xڋ���� � �      �      xڋ���� � �      %      xڋ���� � �      �      x���[s�6� �g�S`�zJ-�I�m��i�49�Μ�%�bL�
I�Qv���ċ,��̈'�;�e�~��ą Ѐ�Y�>]�Ȇ���(�<�}>�����?O±����g�"�A�AyJ�S�����p�ϰN�̒�e��Yb�A�!�%{��S"L�T�U�d V�
�\��\%D�s���U��*��e��re��U����*�b�Δ\��yo���WIUȊB댑e�ho�H2EןX^g�-3�{3օ&�\e���3&�������2ֲ��s��9ӽ9S�D�5-Z�i��TCloΌpT��E�Y�|F����e�i0���2	g�{ �i���<���y�ɳ�4��,O�<I�����M��u����!�J�d��x�_�?��?�u.:QͯL��H�y�D^��oҎ�l���<Lbs��A�??����(IA�b�$���U��Ԑq"�0RHS��9��Hi(:�eL�&)�%E��;�p-��i�e�L��$��/A��\�_�ǣ ��t4�:�h� ���x�<6Q������ }x���0�m�P)���bխ�y�㥹x7���
�"�DU�p^�xi.������c���γG����������K7p��#�<n,A�T��¨^[wX���>zd�ǋE�"�	-"��[�k?������{�x�-,n��wbmT>�,����2I�'S/
c�u�d<��M�/�V~�ޫ����|��&/vR%i .�a��-�4��zO��B�k0�u�(���ꋃ��2h�$�?�=V��p�-45&?vl�S�T���[�f����RKʣ_3ىkR�.�H�m�q����<zt��d���� �ڤ㼗Sk�-��6q�-NqH_��zR�~�&��4��I��ԏ��8o�d��$y���iPg�GxGx�Gx�L�|�m�~g���2m���}|�X�+�Z���蠼�<m���-5u����ղx��F\�x��'�E<��I��3PV��%�ꉽub�}�����9� ~���( QpD �'���4%�L�l�>����,�~�p'��E!9)BL$�e
˾BG��PʇG!�V�~Zx�U�(U=�������G�;qRx*��aGQ�p�����p��Q�Nˎ&�ǡ(��)ttw�=z��y����	N�V.e���9��z���Is5�o����z/��y���h��qc0������� �#�ES�j�`�y�w��8ƛɷ���O7��8�`��>�&�<�l�G�����A��v�3b�q�d�Xc7�r(9+z���;�i��<z���]8Y]�D�t�ʲ�����<~��~�
�0[�.C���{����Ǐ]�+]%�E#����!��u5.�հ�
���m�\r}4�������#>�^�Y��7��0YV��jx[x��/�;�y3����>�j�M5͂�&�@��0Kn�T��0Y��!8_��G�\�/@62c��i2���*����|&�? X���G0�0'��aY�u� ־���{��DŨS�}8� �3���o�3���+n7~�t�ո���_�;`�)-&sp�e�����[q�w�RV0�zl����q;h�Ѿc�NP�²���y��~���e�bȘ+��_����L�A���+�}Y�'�e-����0j.��>v3��:X���&��f�����^y��l2M���?&�~�ϳ�cp�&��V�t=�{��)�i�%�t4�2JEY��������]�(9aQ��E�@ˉ N�FT��1�[�Ҝ%SH7|����d#�v�G�I~qXva�� !��<zL��9KA׋+����r�͖�L£ǥ<aJ���\��DVv�����-�h�H�A(g�l�)����ӣ|�
a]I/�Y��;�fKMy��Ξ�-O�R@R.++�僫β�RS�A9�y*�ڶ�-�D�5;����e�8Z�]��*���b6��A��ɽ*�W%���o���;M��8���a9�ʌ��Qx6L�$C,+{��ݰ�#cE����js�p�M��)ac��ۉ���+JF~��,
��f���z˄�fB��?�z���Y�2'��L���+C���`%Y0?D�Q�5f�I�O��,������)F�xZٵg�%�ŭ"�Y�t@%�U���I�y/���]D瞮��Hb^�̕�z���~O�ɻ�Pq�T�re2e�.�üS[��m�׼g��Vp��Jhc#�y�L���N��<�S�c��&��dvm3��l��[$��ɽ�Ur/,�{�sI��p�E�~W+��c�`��c�,�
n'���$���%�"(D1�Y)��t�{ͮ����ܷ-��d\���A۵$�~H㈻�Iy����V�e�]�1�e4����$;UKF!�B�v�'� i y'QIO�R
J����T '� i ;i��yz��[b�!�eT*ˇѝd���D��s��R� -�R�Xu�;ƽ�F�����~��ŭ�_�X������ :6�j�(��G@�qj-q��N�I�zR�w/ίw^h���:�8LRp��#3���Os������*��S��?܄���fj����^.���nF��Z#K;�[�\�,'H"����h�5����影�U������ 9�\��"fE_l%!XT1k9��\�]5+���`op���N�[�19�h�l'�1�[E��e�[C9W{W��M[���!dU�Z�*G{ ����-�o��q9&�9������F����ꋭn+\]n�՞��� W�J��I��S�l���՞����f�����E��|��|s���2��J�x|�E���n4Q�ϯ& KFa�/�h��GQ��R�Ƹ�v1�jU�o�Q��rL�خ��#B�����p�Y��,"��>������͛p�))c�rNM<��"F��n�+m
V�e7���Aᠪ��W]��&�Uö��x�$эfɒh��W����#Q�g�N�m���i�1"��w�V��fQ�t����_^�O�M�4������7�nu ]�4[|��$�jRU\Q^>�E������Ԑ�N"��*B�e�K������Ԑ�Aճ}_'7�V=d�=5�z+�]ꯜ���e��c?]��8����Up�o4k���2������B��=��p���$��\��w���r)�!x;��,h4K�,���I�rEf���3E��h��	��a��u;j#ͻ�l�Sn.�k��k�:�6�Z��kی���3A���bm�ʚS~��Ff��x޳��S�I��v��ph㌻�i�OiJ�UH[����l�i'�h�SjE(��v�k�ph��;�i�OjFk{V!&l;�􃡍s'm�}�^O��C.q9��l�r�����pW1�\���Ԩ}�R}0��<�C/2���|=,s��#��z�b��J�%߰]]��'�&����< �a4����LqY=]_��2X�]|�[���C�+��D��VO�me�h'������Z��[/��o+C�;�,�h�!��W�����2T��Ȓ�K*X�-Ǉ�줙�֪�C�V�;f���Y�NY��M�i�%���r�����e�o�C��6CO8�*�w'���������e	X�|�[F�n+�&Ib֑O�/q��!x�e�i .݌��n]����$,(aU(
d;S�l|q���NWBB��AAl�%��F�v��7��	\�i!���߹ڻV�E����JEH���9W{W�*;����*�q5�V(���=�V�J�Eܪ��
LH����q��������臭B,�,���MPq����U�ê}�Q��`{�n"[5r�3,��I�y��ϗ���{�Y�/52ُ̚�u���!Eϡ9ī��G7o�/;�_��U ���$�Y���<]/���0_N��A�X$�4�K`��_��H����d��M���2Hfۥ��il�Et�>ss�xu���l�[Qi��u���[)«붲}��i����
vݢ�ܔ`$ʥ6��\;�V�Fwr݆}�V��WF�������-�{��e�DY?��[a�NZ������.je9�[Q�NZ����T��#[Y>��[Q�3���e��)n���nq��Ϟ>W\�P� `  &M�� � D��L�[d�YA=�
��Y��[&�VI�UR��_�N����~z� �I��Y�yh�I�6��&�Rp�� ��vA�V�6�]��G�b�U��ph�1�����6��>"3AWe��nc���Qƻ�2����b�D�e�	�:��ZE��"��c'c�Ҫ�f�%��ZF�-�j�k�8~���h���D����ޚ����]�MVw�V���g�����<dV���ܬ�l֭��Ex�Ղ̹٧鍿 �p�&�?��N��M�p�l[e�t��_S�z��B��
��1�����:���+���lh�-��>�zw@�Λ��H!-�&��[��?k�7k�8�E�-g�����Y˽Y�*A���Xe�,�V{��U� W����^��Z��1΍͸fu�w��Ql﯋�/^g;�Ӽ���7��w`�2/�>~C�I},/�X:j��Cc���<r���ܞ�X+~��e���^����C�=�̺F�P�o�8�K����j�TW�l�G0�EW�HU?%��S�]��N��%����y����u�0q/KB����*^��ۻU���x�AU�4���n��:}6VǪ���$�{~����#������m�� �x����%�C�d{/Y.Z���$r'���?����H8#�������b� ƃH��i�$���qՊ��&Q;I�����;elK���� �����x��z3Hco�n�Ԋ��$�p	�^����⫓��f����Ƕu�>�h]�"U;�4�s�vu^���ީ���y����W��O_�:����΀E�m0n����r�L��=�2V��+��j��\�n�b����J���x9����b�9�e�X�oO��:m5�4w��������{�~�(�p�ԡ����_�|v��n:,i8e�v�`���">�U?	m�'����U��ư�a�w����x�����(b%x�E&��ھc+9�U�
m�_���	���{\��+�3ʖ_��;��B���/�p��P��[��}o�n�L�z�����ξ̻��w|��I��e�% N�r�����w?=��3Vũ���8�Nൻ>�i�_D���v�����=_�߄���ͳf�m$�[��g?�]�(�⫂�Jc����\
).�ۺك�.�����7�x@��0��F�;�jUd�Į0��5�y�]�YbWA�"��_�~'�z�U��r�n��)���-ئ@��ńӲ��lunwB��8rq�ҠZ��ƞ@���P��"��F9�ųY �N�l�CY</�>O>}�B%ƨ쫦���p�q��0��[�Փ?�����Ћ"�
d��P ʮ@�o��^�����B�����+�#?�{xvv�_��4      +      xڋ���� � �      )      xڋ���� � �      �      xڋ���� � �      �   �  x�͚Kk�@Fף�R������PYt��(��Ư`�iJ��|�n��.�]�@2�c�pdͬ߮v��p���t83����r:����n�n��/�2���~����Ӫ��W�q�����|Ǹ>�3�ǻ�:�6��4�ܕ]9t�p>��na��D��\��|RID.	�$���$2���$Z>�PI�)E�(�峈`A�f�L`A�f��`Ag�l����,��z�FY�u�e��ӎ��nND�S�O��td�Z��S`P��td�ZħS�P��td�Z��`Q$��-�E�
ۢ�P�`Qd��-�E�
ۢ(Q�`Q���-�uhQO��C�zuhQO��C�z;��({-�XԡE�,z������9t�'ϡ}k�w�{sz>�&��?���"��e�05��S�������dv�*�2�5�n]��7}��o=�f��e(���E�!?�����@���yN�w�
�D�D����!+���-��;N�@GK����
�&��H������	�;2�wT`QAG�E�XT�����E4}"[TP�I�EQ��mQTb�`QTb�Z��JL��JLl������o�Ĭ�o����*1+�G%f��<*1+�G%�~�跬�o��������@@���[㢀Z��(���w|_R�_��ʭq���6M�� '      �   	  xڕ��n"���駰d�6�/-�4���0`�t�+`�b)6?�	�=��csN��ʕ_,D�L� B�"��̿q���k!� �
�L��Qj�nү�EJ��\ �0�VG4#�h������?S3��Q(����]�� �@!�Y��2�r8r,ǂ1iK$�|dq&H\����:�u."$�BQ�d�V8��$��z>��T�3�����f~��M���[�bp��CD+��DQ������_���13�õ�<Ř�S0Ba���D1cJE�o�;4Wy�ޮm���M�a+
��9�3��e�{�)�&D�0�@ ��H{o6
ie���g
#z�V�&�p(��9[afE��H�E��R`�9���C[�_���USC����q�ZM���0�o���Vu��>����Al�@���#L�H�@�,(x��h�L���q��e&*�[	�+~�V|+=�^��#!Fc�l��rh+������+ ��cL��x�h/0��1տ���NpC����a%��9Qe�R�9��B4�Z�.�1I�`���`�5�z�����(�o+N9W笤P������Z9�	E�)�G��3s;���g54��,dB��bojwuܡ�ln`������ʳ&��h�����cr�C��0��p̈́�+��1���/��F�7�����ӌ����c��}�v�>Ͽ�G�ti�d	d��	��oL}#�Zb�7��xL-#�XQ�u�R���*h��;�7P�ߨ�x���ui�vR�������5_,d;�ri��ݰu{�Yn��/���>��Ϲ��a�&�ho���������?bƇi�n&˩�(�Vð�\:N����?}M�0S�T�ߨ�� '!!93F[O��G.<����~����Z'�b��֗��%�:��I#���[�\N����{�o�z~+U+��fd��x�X�]�z��耚|����d9��d2ژY�҃�u�[I�Yn������8��A6�3V�����ܫy�T'�t|��_��u�,g9����j�5T�)�7��+�^��V��j=�?Uv��7�X����ѫ�!^t�ă\��N�kHV�ρ��E�c�9qтj����Cp�9�m}�l��^'���G��v(�k[��=F��'��r�Z7W��uڗ�L��6^���c=o�Wfv�5��[�+�A|>�V�u�8��@A����i�(��yO5��=���s���ݴJ���뫖��}��<���/5>}�]�z����Ӽ��ɺ���6���[�%��5�X���C��d��iX�3�Q9��)r��'�!�j6��J)�~��a"v��?G6�˷J��g��	E��5���tƦ�鴉j��Bn�W���v᫢��Pj�*���ͬ;�<��X���Ð�d.n 2>m��*q+��Y�[+��**�#��J�A�D��1:����i2?���lнOZ������A�OÚ��S����0�N^Aj�+]l?�j����b�?@��o������F��&��A�kˬ'�A�S�أ2�pm� �`Ma�y�vr�N?g�r�%��d���v��/z��m6���t~Kr%����Q�C�~I�(�[��|w{^���c=��Z�i�bPk?G�		av{�)��1�0�ƞR��t����}�^��{6����W�Ҿ:�2�)��w��VR�i���e��o�����ߐ0�>M��t����#��[3M�������O��>��-��Es��尷`
��q�����\��{��ܖCK�������Ͱ>@�eux��6�/�p_�6�cc?x����V���ws�8j;H�ǯ�Խ6�p0�H�O`s���+\��z4��d�x:�<L)ob�9*��D�c���R�a�6z�GYssO���)����\������EqKh�z���Tͫ�ת�Oz��6B?7�u2��[�xzM�?E��S�Jφ:�	P7(�$l`���hB��P��O�o�Ў��q�d_V3ӞW�k�d�F�E���V�E���3�|�֬�To��	z'��ϳ��ct�ss�~c&�^�&��A�Rr�y<AO ��Y�c=�F3}�����S�;���O4qr�^��F�}�H7��ln��fǌǹ�t@��k��0<�������#��7;�g�Zӓ��c�G�ar�0�t4��K=��	~�`.=[�"�Lc��7�	f��NJ��	�J�c����}����~�v߷f�Ńk=1�./���qەUI�y������Hn�W�%[h�����o���(��Vj��+w��A��Ϊ���@kh3�[��t�+p>q!��u��˗�|B�      ,   �  xڕ�[O�@��{���3��=�D��XE01&�$ z�"����M��M�93_rzy��b�]�M5kv�7;y_�U޾�������G��xL3����<�j��}/��;��,�@�+�i�Ђ9�����ш�Ă���n�ۓ&�y��?�`<��3�O{�[�Q(��$q�|P`��a2�@gI(9A ��Ġ�B��*o�#��$�
,1�4�,�M6����d$�S ��L!X[H��Qg+��HrLXdt�,����-��H�L	Xb4�P��{q���H$�f�U��j���l�Y]HF"	5+(;�}����F"�5��u]��+g��k���NF���]'hI�9�yA��=�?�E�B2I�9��s�k����u"��%����      1      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      4      xڋ���� � �      7      xڋ���� � �      8      xڋ���� � �      ;      xڋ���� � �      <      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �         4  xڅW˒�8<�_�юu�����q����^O�u�ܼ���~K@�E�e&B�A�R�*5q�c��$n�{��*��~tS��;Y��L� #�8;�{צw�G)xq	��+�����yV���͊:��e�g�@7q�J��T��*6u�X�4����3�h0�Upy����Xf���jQ����s�"��޹I�����H!/�&�]	�V�}���80r����i�ˢ~�j	QT`R���q�U��ᖕ,@�m�H7N��F��$5�`F�9��/��>Ž.
s����墷լ���*��.n�H\]f�Q�"�@A���w���2AHB�#b��	U$����'��S�ղ���k�
�)�����<n�_D�B	q�wef���7r��Δ@� F  n�M������2���w�D��?�MY�6�Cj��d'�x������3�/~Xn� �i5A��-4�h<~���ة/������~ZJN0J�oUD�w���fwa-u�ֵľ�˦Vɯ���+�~�������ڗ�q�"��������I�>5}P�����ө�Y����X�}��A�]\w��r�0M:u��2+�Jvy�q`Ω��{��)�-�
N�M��!a̉��Zn�!SǙ[�u��m�':Fn�����<"ά��QwX&�φܬ1��E-��2��Y�:�Up~I��ҒK� ������Ý<���6�f�I��-*��AU�����aJ���(�,3yNU�)��tH�W86mv4�M	F���`�����Y�(�!X�֠C�2��pr��c^��Xeأ;�TG6����+��	}{.���Ks	��,�]�{Wn6*Q8.\���t�a�a�+�ފF�[:yȹ��DG#�E�`��uUj�%����J78M�Jq���s\�j������0��g7�(�o7�3�덬s�*s�J|5%�?7/�0��~!�D��T��g��͔�B��A(��`�YQ�iuS��}Y�5�t�n�x�]��҅������z4 d|�R�%�G\�����|-k��nvS���jՕ��F,�W�p����Ш����Iق�w닺�)�F�����S���^_��� �N��=�z�'G�����MlS����f�dPr�Ghg�‟�Q�[����]q���4����P�����N����?��*��p�=�5֭u�ha�$8p H-A��}ʚ�"�',��\�%=�鐮6jB��F�.�Fޯ�*x
��ot�Y��@�p��h4+�pRT���rOG{k]V���co�{}y�.�|T�$
"����6��=Y�V��{!      A   �  x�-�ّ� D���lYq�2�Ǳ�U3��Ζ�27Gp�6lbr��H;�����m�_��!s�����߄�h�<|n��y�S<->xj3-���6w�3~�ǂ6o�3�����"�QeԦ�STRa1+QV�����n�N�ݺP��Q��1ma�:&�,� Y.��0Dr :�]��U����-F��S4�fY%�,f'���'Q5F�eS�K9�#Hyh�"5M��.�>6.�ʀ�4���k��|}�_˗����RS��{��ȎU�=\�֬褏%x,9J*[�'��d�[~͕e)hcWf�'^
����P�x��U�����-u��I�:O��88?)-6Ws�
�k�(��8W�Q���)���N������g�X�=?䍛�Ow�)�w�L��>��}�O�X~�>P�5�]R�pؿ��^~ ����k     