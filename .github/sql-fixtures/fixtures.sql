PGDMP  	             	            z           taiga    12.3 (Debian 12.3-1.pgdg100+1)    13.6               0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false                       0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false                       0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false                       1262    6780561    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false                        3079    6780685    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            	           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2            
           1247    6781036    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false                       1247    6781026    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            �            1255    6781101 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
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
       public          taiga    false                       1255    6781118 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
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
       public          taiga    false            �            1255    6781102 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
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
       public          taiga    false            �            1259    6781053    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
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
       public         heap    taiga    false    775    775            �            1255    6781103 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
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
       public          taiga    false    238                       1255    6781117 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
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
       public          taiga    false    775                       1255    6781116 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
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
       public          taiga    false    775            �            1255    6781104 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
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
       public          taiga    false    775            �            1255    6781106    procrastinate_notify_queue()    FUNCTION     
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
       public          taiga    false            �            1255    6781105 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
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
       public          taiga    false                       1255    6781109 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false            	           1255    6781107 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            
           1255    6781108 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
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
       public          taiga    false                       1255    6781110 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
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
       public          taiga    false            C           3602    6780692    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR word WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_part WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR uint WITH simple;
 7   DROP TEXT SEARCH CONFIGURATION public.simple_unaccent;
       public          taiga    false    2    2    2    2            �            1259    6780645 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    6780643    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    214            �            1259    6780654    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    6780652    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    216            �            1259    6780638    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    6780636    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    212            �            1259    6780615    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id uuid NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap    taiga    false            �            1259    6780613    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    210            �            1259    6780606    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    6780604    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    208            �            1259    6780564    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    6780562    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    204            �            1259    6780920    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false            �            1259    6780695    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false            �            1259    6780693    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    218            �            1259    6780702    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false            �            1259    6780700     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    220            �            1259    6780727 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false            �            1259    6780725 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    222            �            1259    6780839    invitations_projectinvitation    TABLE     �  CREATE TABLE public.invitations_projectinvitation (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    num_emails_sent integer NOT NULL,
    resent_at timestamp with time zone,
    revoked_at timestamp with time zone,
    invited_by_id uuid,
    project_id uuid NOT NULL,
    resent_by_id uuid,
    revoked_by_id uuid,
    role_id uuid NOT NULL,
    user_id uuid
);
 1   DROP TABLE public.invitations_projectinvitation;
       public         heap    taiga    false            �            1259    6780741    memberships_workspacemembership    TABLE     �   CREATE TABLE public.memberships_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 3   DROP TABLE public.memberships_workspacemembership;
       public         heap    taiga    false            �            1259    6781083    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    778            �            1259    6781081    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    242            
           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    241            �            1259    6781051    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    238                       0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    237            �            1259    6781067    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            �            1259    6781065 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    240                       0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    239            �            1259    6780761    projects_project    TABLE     �  CREATE TABLE public.projects_project (
    id uuid NOT NULL,
    name character varying(80) NOT NULL,
    slug character varying(250) NOT NULL,
    description character varying(220),
    color integer NOT NULL,
    logo character varying(500),
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    public_permissions text[],
    workspace_member_permissions text[],
    owner_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            �            1259    6780789    projects_projectmembership    TABLE     �   CREATE TABLE public.projects_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 .   DROP TABLE public.projects_projectmembership;
       public         heap    taiga    false            �            1259    6780781    projects_projectrole    TABLE     	  CREATE TABLE public.projects_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 (   DROP TABLE public.projects_projectrole;
       public         heap    taiga    false            �            1259    6780771    projects_projecttemplate    TABLE     ]  CREATE TABLE public.projects_projecttemplate (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    roles jsonb,
    workflows jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    taiga    false            �            1259    6780882    roles_workspacerole    TABLE     
  CREATE TABLE public.roles_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 '   DROP TABLE public.roles_workspacerole;
       public         heap    taiga    false            �            1259    6780962 
   tasks_task    TABLE     C  CREATE TABLE public.tasks_task (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    name character varying(500) NOT NULL,
    "order" bigint NOT NULL,
    reference bigint,
    created_by_id uuid NOT NULL,
    project_id uuid NOT NULL,
    status_id uuid NOT NULL,
    workflow_id uuid NOT NULL
);
    DROP TABLE public.tasks_task;
       public         heap    taiga    false            �            1259    6781006    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    taiga    false            �            1259    6780996    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
    id uuid NOT NULL,
    object_id uuid,
    jti character varying(255) NOT NULL,
    token_type text NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    content_type_id integer
);
 +   DROP TABLE public.tokens_outstandingtoken;
       public         heap    taiga    false            �            1259    6780584    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            �            1259    6780572 
   users_user    TABLE     �  CREATE TABLE public.users_user (
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    full_name character varying(256),
    accepted_terms boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    date_verification timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            �            1259    6780930    workflows_workflow    TABLE     �   CREATE TABLE public.workflows_workflow (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    "order" bigint NOT NULL,
    project_id uuid NOT NULL
);
 &   DROP TABLE public.workflows_workflow;
       public         heap    taiga    false            �            1259    6780938    workflows_workflowstatus    TABLE     �   CREATE TABLE public.workflows_workflowstatus (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    "order" bigint NOT NULL,
    workflow_id uuid NOT NULL
);
 ,   DROP TABLE public.workflows_workflowstatus;
       public         heap    taiga    false            �            1259    6780746    workspaces_workspace    TABLE     T  CREATE TABLE public.workspaces_workspace (
    id uuid NOT NULL,
    name character varying(40) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    is_premium boolean NOT NULL,
    owner_id uuid NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false            �           2604    6781086    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    241    242    242            �           2604    6781056    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    238    237    238            �           2604    6781070     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    240    239    240            �          0    6780645 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    214   ҵ      �          0    6780654    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    216   �      �          0    6780638    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    212   �      �          0    6780615    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    210   ��      �          0    6780606    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    208   ʹ      �          0    6780564    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    204   ٺ      �          0    6780920    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    231   P�      �          0    6780695    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    218   m�      �          0    6780702    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    220   ��      �          0    6780727 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    222   ��      �          0    6780839    invitations_projectinvitation 
   TABLE DATA           �   COPY public.invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          taiga    false    229   Ľ      �          0    6780741    memberships_workspacemembership 
   TABLE DATA           i   COPY public.memberships_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          taiga    false    223   ��                0    6781083    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    242   ��      �          0    6781053    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    238   ��                 0    6781067    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    240   ��      �          0    6780761    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, slug, description, color, logo, created_at, modified_at, public_permissions, workspace_member_permissions, owner_id, workspace_id) FROM stdin;
    public          taiga    false    225   ��      �          0    6780789    projects_projectmembership 
   TABLE DATA           b   COPY public.projects_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          taiga    false    228   :�      �          0    6780781    projects_projectrole 
   TABLE DATA           j   COPY public.projects_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          taiga    false    227   p�      �          0    6780771    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, created_at, modified_at, default_owner_role, roles, workflows) FROM stdin;
    public          taiga    false    226   ��      �          0    6780882    roles_workspacerole 
   TABLE DATA           k   COPY public.roles_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    230   ��      �          0    6780962 
   tasks_task 
   TABLE DATA           �   COPY public.tasks_task (id, created_at, name, "order", reference, created_by_id, project_id, status_id, workflow_id) FROM stdin;
    public          taiga    false    234   �      �          0    6781006    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    236   %�      �          0    6780996    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          taiga    false    235   B�      �          0    6780584    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    206   _�      �          0    6780572 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, is_active, is_superuser, full_name, accepted_terms, date_joined, date_verification) FROM stdin;
    public          taiga    false    205   |�      �          0    6780930    workflows_workflow 
   TABLE DATA           Q   COPY public.workflows_workflow (id, name, slug, "order", project_id) FROM stdin;
    public          taiga    false    232   
      �          0    6780938    workflows_workflowstatus 
   TABLE DATA           _   COPY public.workflows_workflowstatus (id, name, slug, color, "order", workflow_id) FROM stdin;
    public          taiga    false    233   �      �          0    6780746    workspaces_workspace 
   TABLE DATA           t   COPY public.workspaces_workspace (id, name, slug, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          taiga    false    224   �                 0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    213                       0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    215                       0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 92, true);
          public          taiga    false    211                       0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    209                       0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 23, true);
          public          taiga    false    207                       0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 32, true);
          public          taiga    false    203                       0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          taiga    false    217                       0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          taiga    false    219                       0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    221                       0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 1, false);
          public          taiga    false    241                       0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 1, false);
          public          taiga    false    237                       0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    239            �           2606    6780683    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    214            �           2606    6780669 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    216    216            �           2606    6780658 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    216            �           2606    6780649    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    214            �           2606    6780660 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    212    212            �           2606    6780642 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    212            �           2606    6780623 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    210            �           2606    6780612 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    208    208            �           2606    6780610 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    208            �           2606    6780571 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    204            	           2606    6780927 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    231            �           2606    6780699 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    218            �           2606    6780710 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    218    218            �           2606    6780708 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    220    220    220            �           2606    6780706 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    220            �           2606    6780733 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    222            �           2606    6780735 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    222            �           2606    6780876 Z   invitations_projectinvitation invitations_projectinvitation_email_project_id_b248b6c9_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_email_project_id_b248b6c9_uniq UNIQUE (email, project_id);
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_email_project_id_b248b6c9_uniq;
       public            taiga    false    229    229            �           2606    6780843 @   invitations_projectinvitation invitations_projectinvitation_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_pkey;
       public            taiga    false    229            �           2606    6780916 [   memberships_workspacemembership memberships_workspacemem_user_id_workspace_id_7c8ad949_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.memberships_workspacemembership
    ADD CONSTRAINT memberships_workspacemem_user_id_workspace_id_7c8ad949_uniq UNIQUE (user_id, workspace_id);
 �   ALTER TABLE ONLY public.memberships_workspacemembership DROP CONSTRAINT memberships_workspacemem_user_id_workspace_id_7c8ad949_uniq;
       public            taiga    false    223    223            �           2606    6780745 D   memberships_workspacemembership memberships_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.memberships_workspacemembership
    ADD CONSTRAINT memberships_workspacemembership_pkey PRIMARY KEY (id);
 n   ALTER TABLE ONLY public.memberships_workspacemembership DROP CONSTRAINT memberships_workspacemembership_pkey;
       public            taiga    false    223            4           2606    6781089 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    242            *           2606    6781064 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    238            /           2606    6781073 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    240            1           2606    6781075 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    240    240    240            �           2606    6780768 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    225            �           2606    6780770 *   projects_project projects_project_slug_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_slug_key UNIQUE (slug);
 T   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_slug_key;
       public            taiga    false    225            �           2606    6780793 :   projects_projectmembership projects_projectmembership_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_pkey;
       public            taiga    false    228            �           2606    6780818 V   projects_projectmembership projects_projectmembership_user_id_project_id_95c79910_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_user_id_project_id_95c79910_uniq UNIQUE (user_id, project_id);
 �   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_user_id_project_id_95c79910_uniq;
       public            taiga    false    228    228            �           2606    6780788 .   projects_projectrole projects_projectrole_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_pkey;
       public            taiga    false    227            �           2606    6780808 G   projects_projectrole projects_projectrole_slug_project_id_4d3edd11_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_slug_project_id_4d3edd11_uniq UNIQUE (slug, project_id);
 q   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_slug_project_id_4d3edd11_uniq;
       public            taiga    false    227    227            �           2606    6780778 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    226            �           2606    6780780 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    226                       2606    6780889 ,   roles_workspacerole roles_workspacerole_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.roles_workspacerole
    ADD CONSTRAINT roles_workspacerole_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.roles_workspacerole DROP CONSTRAINT roles_workspacerole_pkey;
       public            taiga    false    230                       2606    6780891 G   roles_workspacerole roles_workspacerole_slug_workspace_id_2a6db2b2_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.roles_workspacerole
    ADD CONSTRAINT roles_workspacerole_slug_workspace_id_2a6db2b2_uniq UNIQUE (slug, workspace_id);
 q   ALTER TABLE ONLY public.roles_workspacerole DROP CONSTRAINT roles_workspacerole_slug_workspace_id_2a6db2b2_uniq;
       public            taiga    false    230    230                       2606    6780969    tasks_task tasks_task_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_pkey;
       public            taiga    false    234                       2606    6780971 8   tasks_task tasks_task_reference_project_id_1aa51c14_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_reference_project_id_1aa51c14_uniq UNIQUE (reference, project_id);
 b   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_reference_project_id_1aa51c14_uniq;
       public            taiga    false    234    234            $           2606    6781010 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            taiga    false    236            &           2606    6781012 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            taiga    false    236                        2606    6781005 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            taiga    false    235            "           2606    6781003 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            taiga    false    235            �           2606    6780595 5   users_authdata users_authdata_key_value_7ee3acc9_uniq 
   CONSTRAINT     v   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_key_value_7ee3acc9_uniq UNIQUE (key, value);
 _   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_key_value_7ee3acc9_uniq;
       public            taiga    false    206    206            �           2606    6780591 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    206            �           2606    6780583    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            taiga    false    205            �           2606    6780579    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    205            �           2606    6780581 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    205                       2606    6780937 *   workflows_workflow workflows_workflow_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_pkey;
       public            taiga    false    232                       2606    6780947 C   workflows_workflow workflows_workflow_slug_project_id_80394f0d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq UNIQUE (slug, project_id);
 m   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq;
       public            taiga    false    232    232                       2606    6780945 6   workflows_workflowstatus workflows_workflowstatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_pkey;
       public            taiga    false    233                       2606    6780955 P   workflows_workflowstatus workflows_workflowstatus_slug_workflow_id_06486b8e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq UNIQUE (slug, workflow_id);
 z   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq;
       public            taiga    false    233    233            �           2606    6780750 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    224            �           2606    6780752 2   workspaces_workspace workspaces_workspace_slug_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_slug_key UNIQUE (slug);
 \   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_slug_key;
       public            taiga    false    224            �           1259    6780684    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    214            �           1259    6780680 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    216            �           1259    6780681 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    216            �           1259    6780666 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    212            �           1259    6780634 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    210            �           1259    6780635 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    210                       1259    6780929 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    231            
           1259    6780928 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    231            �           1259    6780713 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    218            �           1259    6780714 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    218            �           1259    6780711 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    218            �           1259    6780712 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    218            �           1259    6780722 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    220            �           1259    6780723 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    220            �           1259    6780724 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    220            �           1259    6780720 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    220            �           1259    6780721 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    220            �           1259    6780849 4   invitations_projectinvitation_invited_by_id_016c910f    INDEX     �   CREATE INDEX invitations_projectinvitation_invited_by_id_016c910f ON public.invitations_projectinvitation USING btree (invited_by_id);
 H   DROP INDEX public.invitations_projectinvitation_invited_by_id_016c910f;
       public            taiga    false    229            �           1259    6780877 1   invitations_projectinvitation_project_id_a48f4dcf    INDEX     �   CREATE INDEX invitations_projectinvitation_project_id_a48f4dcf ON public.invitations_projectinvitation USING btree (project_id);
 E   DROP INDEX public.invitations_projectinvitation_project_id_a48f4dcf;
       public            taiga    false    229            �           1259    6780878 3   invitations_projectinvitation_resent_by_id_b715caff    INDEX     �   CREATE INDEX invitations_projectinvitation_resent_by_id_b715caff ON public.invitations_projectinvitation USING btree (resent_by_id);
 G   DROP INDEX public.invitations_projectinvitation_resent_by_id_b715caff;
       public            taiga    false    229            �           1259    6780879 4   invitations_projectinvitation_revoked_by_id_e180a546    INDEX     �   CREATE INDEX invitations_projectinvitation_revoked_by_id_e180a546 ON public.invitations_projectinvitation USING btree (revoked_by_id);
 H   DROP INDEX public.invitations_projectinvitation_revoked_by_id_e180a546;
       public            taiga    false    229            �           1259    6780880 .   invitations_projectinvitation_role_id_d4a584ff    INDEX     {   CREATE INDEX invitations_projectinvitation_role_id_d4a584ff ON public.invitations_projectinvitation USING btree (role_id);
 B   DROP INDEX public.invitations_projectinvitation_role_id_d4a584ff;
       public            taiga    false    229            �           1259    6780881 .   invitations_projectinvitation_user_id_3fc27ac1    INDEX     {   CREATE INDEX invitations_projectinvitation_user_id_3fc27ac1 ON public.invitations_projectinvitation USING btree (user_id);
 B   DROP INDEX public.invitations_projectinvitation_user_id_3fc27ac1;
       public            taiga    false    229            �           1259    6780917 0   memberships_workspacemembership_role_id_27888d1d    INDEX        CREATE INDEX memberships_workspacemembership_role_id_27888d1d ON public.memberships_workspacemembership USING btree (role_id);
 D   DROP INDEX public.memberships_workspacemembership_role_id_27888d1d;
       public            taiga    false    223            �           1259    6780918 0   memberships_workspacemembership_user_id_b8343167    INDEX        CREATE INDEX memberships_workspacemembership_user_id_b8343167 ON public.memberships_workspacemembership USING btree (user_id);
 D   DROP INDEX public.memberships_workspacemembership_user_id_b8343167;
       public            taiga    false    223            �           1259    6780919 5   memberships_workspacemembership_workspace_id_2e5659c7    INDEX     �   CREATE INDEX memberships_workspacemembership_workspace_id_2e5659c7 ON public.memberships_workspacemembership USING btree (workspace_id);
 I   DROP INDEX public.memberships_workspacemembership_workspace_id_2e5659c7;
       public            taiga    false    223            2           1259    6781099     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    242            '           1259    6781098    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    238    775    238    238            (           1259    6781096    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    775    238    238            +           1259    6781097 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    238            ,           1259    6781095 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    238    238    775            -           1259    6781100 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    240            �           1259    6780804 %   projects_project_name_id_44f44a5f_idx    INDEX     f   CREATE INDEX projects_project_name_id_44f44a5f_idx ON public.projects_project USING btree (name, id);
 9   DROP INDEX public.projects_project_name_id_44f44a5f_idx;
       public            taiga    false    225    225            �           1259    6780837 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    225            �           1259    6780805 #   projects_project_slug_2d50067a_like    INDEX     t   CREATE INDEX projects_project_slug_2d50067a_like ON public.projects_project USING btree (slug varchar_pattern_ops);
 7   DROP INDEX public.projects_project_slug_2d50067a_like;
       public            taiga    false    225            �           1259    6780838 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    225            �           1259    6780834 .   projects_projectmembership_project_id_ec39ff46    INDEX     {   CREATE INDEX projects_projectmembership_project_id_ec39ff46 ON public.projects_projectmembership USING btree (project_id);
 B   DROP INDEX public.projects_projectmembership_project_id_ec39ff46;
       public            taiga    false    228            �           1259    6780835 +   projects_projectmembership_role_id_af989934    INDEX     u   CREATE INDEX projects_projectmembership_role_id_af989934 ON public.projects_projectmembership USING btree (role_id);
 ?   DROP INDEX public.projects_projectmembership_role_id_af989934;
       public            taiga    false    228            �           1259    6780836 +   projects_projectmembership_user_id_aed8d123    INDEX     u   CREATE INDEX projects_projectmembership_user_id_aed8d123 ON public.projects_projectmembership USING btree (user_id);
 ?   DROP INDEX public.projects_projectmembership_user_id_aed8d123;
       public            taiga    false    228            �           1259    6780816 (   projects_projectrole_project_id_0ec3c923    INDEX     o   CREATE INDEX projects_projectrole_project_id_0ec3c923 ON public.projects_projectrole USING btree (project_id);
 <   DROP INDEX public.projects_projectrole_project_id_0ec3c923;
       public            taiga    false    227            �           1259    6780814 "   projects_projectrole_slug_c6fb5583    INDEX     c   CREATE INDEX projects_projectrole_slug_c6fb5583 ON public.projects_projectrole USING btree (slug);
 6   DROP INDEX public.projects_projectrole_slug_c6fb5583;
       public            taiga    false    227            �           1259    6780815 '   projects_projectrole_slug_c6fb5583_like    INDEX     |   CREATE INDEX projects_projectrole_slug_c6fb5583_like ON public.projects_projectrole USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.projects_projectrole_slug_c6fb5583_like;
       public            taiga    false    227            �           1259    6780806 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    226                       1259    6780897 !   roles_workspacerole_slug_8cc7c5e8    INDEX     a   CREATE INDEX roles_workspacerole_slug_8cc7c5e8 ON public.roles_workspacerole USING btree (slug);
 5   DROP INDEX public.roles_workspacerole_slug_8cc7c5e8;
       public            taiga    false    230                       1259    6780898 &   roles_workspacerole_slug_8cc7c5e8_like    INDEX     z   CREATE INDEX roles_workspacerole_slug_8cc7c5e8_like ON public.roles_workspacerole USING btree (slug varchar_pattern_ops);
 :   DROP INDEX public.roles_workspacerole_slug_8cc7c5e8_like;
       public            taiga    false    230                       1259    6780899 )   roles_workspacerole_workspace_id_40fde8cc    INDEX     q   CREATE INDEX roles_workspacerole_workspace_id_40fde8cc ON public.roles_workspacerole USING btree (workspace_id);
 =   DROP INDEX public.roles_workspacerole_workspace_id_40fde8cc;
       public            taiga    false    230                       1259    6780992 !   tasks_task_created_by_id_1345568a    INDEX     a   CREATE INDEX tasks_task_created_by_id_1345568a ON public.tasks_task USING btree (created_by_id);
 5   DROP INDEX public.tasks_task_created_by_id_1345568a;
       public            taiga    false    234                       1259    6780993    tasks_task_project_id_a2815f0c    INDEX     [   CREATE INDEX tasks_task_project_id_a2815f0c ON public.tasks_task USING btree (project_id);
 2   DROP INDEX public.tasks_task_project_id_a2815f0c;
       public            taiga    false    234                       1259    6780994    tasks_task_status_id_899d2b90    INDEX     Y   CREATE INDEX tasks_task_status_id_899d2b90 ON public.tasks_task USING btree (status_id);
 1   DROP INDEX public.tasks_task_status_id_899d2b90;
       public            taiga    false    234                       1259    6780995    tasks_task_workflow_id_4462b211    INDEX     ]   CREATE INDEX tasks_task_workflow_id_4462b211 ON public.tasks_task USING btree (workflow_id);
 3   DROP INDEX public.tasks_task_workflow_id_4462b211;
       public            taiga    false    234                       1259    6781019 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            taiga    false    235                       1259    6781018 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            taiga    false    235            �           1259    6780601    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    206            �           1259    6780602     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    206            �           1259    6780603    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    206            �           1259    6780593    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    205            �           1259    6780592 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    205                       1259    6780953 &   workflows_workflow_project_id_59dd45ec    INDEX     k   CREATE INDEX workflows_workflow_project_id_59dd45ec ON public.workflows_workflow USING btree (project_id);
 :   DROP INDEX public.workflows_workflow_project_id_59dd45ec;
       public            taiga    false    232                       1259    6780961 -   workflows_workflowstatus_workflow_id_8efaaa04    INDEX     y   CREATE INDEX workflows_workflowstatus_workflow_id_8efaaa04 ON public.workflows_workflowstatus USING btree (workflow_id);
 A   DROP INDEX public.workflows_workflowstatus_workflow_id_8efaaa04;
       public            taiga    false    233            �           1259    6780760 )   workspaces_workspace_name_id_69b27cd8_idx    INDEX     n   CREATE INDEX workspaces_workspace_name_id_69b27cd8_idx ON public.workspaces_workspace USING btree (name, id);
 =   DROP INDEX public.workspaces_workspace_name_id_69b27cd8_idx;
       public            taiga    false    224    224            �           1259    6780759 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    224            �           1259    6780758 '   workspaces_workspace_slug_c37054a2_like    INDEX     |   CREATE INDEX workspaces_workspace_slug_c37054a2_like ON public.workspaces_workspace USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.workspaces_workspace_slug_c37054a2_like;
       public            taiga    false    224            X           2620    6781111 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    775    252    238    238            \           2620    6781115 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    238    268            [           2620    6781114 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    267    238    775    238    238            Z           2620    6781113 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    238    238    265    775            Y           2620    6781112 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    266    238    238            :           2606    6780675 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    2988    212    216            9           2606    6780670 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    214    2993    216            8           2606    6780661 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    2979    212    208            6           2606    6780624 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    210    2979    208            7           2606    6780629 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          taiga    false    205    210    2965            ;           2606    6780715 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    218    3003    220            <           2606    6780736 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    222    220    3013            G           2606    6780844 V   invitations_projectinvitation invitations_projecti_invited_by_id_016c910f_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_invited_by_id_016c910f_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_invited_by_id_016c910f_fk_users_use;
       public          taiga    false    205    229    2965            H           2606    6780850 S   invitations_projectinvitation invitations_projecti_project_id_a48f4dcf_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_project_id_a48f4dcf_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 }   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_project_id_a48f4dcf_fk_projects_;
       public          taiga    false    229    3038    225            I           2606    6780855 U   invitations_projectinvitation invitations_projecti_resent_by_id_b715caff_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_resent_by_id_b715caff_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
    ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_resent_by_id_b715caff_fk_users_use;
       public          taiga    false    2965    229    205            J           2606    6780860 V   invitations_projectinvitation invitations_projecti_revoked_by_id_e180a546_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_revoked_by_id_e180a546_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_revoked_by_id_e180a546_fk_users_use;
       public          taiga    false    205    229    2965            K           2606    6780865 P   invitations_projectinvitation invitations_projecti_role_id_d4a584ff_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_role_id_d4a584ff_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_role_id_d4a584ff_fk_projects_;
       public          taiga    false    227    229    3049            L           2606    6780870 ]   invitations_projectinvitation invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id;
       public          taiga    false    205    2965    229            =           2606    6780900 R   memberships_workspacemembership memberships_workspac_role_id_27888d1d_fk_roles_wor    FK CONSTRAINT     �   ALTER TABLE ONLY public.memberships_workspacemembership
    ADD CONSTRAINT memberships_workspac_role_id_27888d1d_fk_roles_wor FOREIGN KEY (role_id) REFERENCES public.roles_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.memberships_workspacemembership DROP CONSTRAINT memberships_workspac_role_id_27888d1d_fk_roles_wor;
       public          taiga    false    3073    230    223            >           2606    6780905 R   memberships_workspacemembership memberships_workspac_user_id_b8343167_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.memberships_workspacemembership
    ADD CONSTRAINT memberships_workspac_user_id_b8343167_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.memberships_workspacemembership DROP CONSTRAINT memberships_workspac_user_id_b8343167_fk_users_use;
       public          taiga    false    205    2965    223            ?           2606    6780910 W   memberships_workspacemembership memberships_workspac_workspace_id_2e5659c7_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.memberships_workspacemembership
    ADD CONSTRAINT memberships_workspac_workspace_id_2e5659c7_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.memberships_workspacemembership DROP CONSTRAINT memberships_workspac_workspace_id_2e5659c7_fk_workspace;
       public          taiga    false    3031    224    223            W           2606    6781090 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    3114    238    242            V           2606    6781076 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    3114    240    238            A           2606    6780794 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          taiga    false    2965    205    225            B           2606    6780799 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          taiga    false    224    3031    225            D           2606    6780819 P   projects_projectmembership projects_projectmemb_project_id_ec39ff46_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmemb_project_id_ec39ff46_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmemb_project_id_ec39ff46_fk_projects_;
       public          taiga    false    228    225    3038            E           2606    6780824 M   projects_projectmembership projects_projectmemb_role_id_af989934_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmemb_role_id_af989934_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmemb_role_id_af989934_fk_projects_;
       public          taiga    false    228    227    3049            F           2606    6780829 W   projects_projectmembership projects_projectmembership_user_id_aed8d123_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_user_id_aed8d123_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_user_id_aed8d123_fk_users_user_id;
       public          taiga    false    205    2965    228            C           2606    6780809 T   projects_projectrole projects_projectrole_project_id_0ec3c923_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_project_id_0ec3c923_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 ~   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_project_id_0ec3c923_fk_projects_project_id;
       public          taiga    false    225    227    3038            M           2606    6780892 J   roles_workspacerole roles_workspacerole_workspace_id_40fde8cc_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.roles_workspacerole
    ADD CONSTRAINT roles_workspacerole_workspace_id_40fde8cc_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.roles_workspacerole DROP CONSTRAINT roles_workspacerole_workspace_id_40fde8cc_fk_workspace;
       public          taiga    false    230    3031    224            P           2606    6780972 =   tasks_task tasks_task_created_by_id_1345568a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_created_by_id_1345568a_fk_users_user_id FOREIGN KEY (created_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 g   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_created_by_id_1345568a_fk_users_user_id;
       public          taiga    false    205    2965    234            Q           2606    6780977 @   tasks_task tasks_task_project_id_a2815f0c_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_project_id_a2815f0c_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_project_id_a2815f0c_fk_projects_project_id;
       public          taiga    false    234    225    3038            R           2606    6780982 G   tasks_task tasks_task_status_id_899d2b90_fk_workflows_workflowstatus_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_status_id_899d2b90_fk_workflows_workflowstatus_id FOREIGN KEY (status_id) REFERENCES public.workflows_workflowstatus(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_status_id_899d2b90_fk_workflows_workflowstatus_id;
       public          taiga    false    3089    234    233            S           2606    6780987 C   tasks_task tasks_task_workflow_id_4462b211_fk_workflows_workflow_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_workflow_id_4462b211_fk_workflows_workflow_id FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_workflow_id_4462b211_fk_workflows_workflow_id;
       public          taiga    false    232    3084    234            U           2606    6781020 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          taiga    false    235    236    3106            T           2606    6781013 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          taiga    false    208    2979    235            5           2606    6780596 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          taiga    false    2965    205    206            N           2606    6780948 P   workflows_workflow workflows_workflow_project_id_59dd45ec_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id;
       public          taiga    false    3038    232    225            O           2606    6780956 O   workflows_workflowstatus workflows_workflowst_workflow_id_8efaaa04_fk_workflows    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows;
       public          taiga    false    232    3084    233            @           2606    6780753 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          taiga    false    2965    224    205            �      xڋ���� � �      �      xڋ���� � �      �   �  x�u�]��0���Sp�U���#���M�I gFs�w��ƞ7��*�B&F��Ƭ���2�Ύ.s�O��Z���ֶ�s^n�x�Gv^x��w�"v^z�s�_Gx�h�;~��1,�0�*�~iC�ܮ �,c�U�蔱-��ɸ���:O��*�A�͉�s���v��J ����t�ֻ7�һX�~�Mɍp�Yq?�DOD�d�s�Q��n�p+�Wڴ�1hl���a�*`��L�-��}M����.6{�ǻ����T����h�sQ���;�]�A���zV��>iR[%R��ݪF���t^�����4M:j��@Ӧ�Bf��P���S���}��$=��Ѯ.���.uAm|��?{q��,X�BT���
��!a�E0VB�����(s��wn}랸����6�Q��[���P�߅�)�!d<�L��?:��T��)�T�@�4 (RI�@� A'8wp9g569��J\֩R)�pq�J$�2�q:)��P6��}�R����u6`��@F}$�+���n�+PE�.[\�^�2�0	��*SV���8Ȫ�o&;��:�D"K��m��anG����E]%/�����d�X>YL\'�/����Bj�k��2ppo׺uc ��w �%��a���ܽ�-�;�)g鶱�u-�*8�B�h�@��������M/�>c?���Mv��ph���׍�bR��c��fR�Ib)+kR��2joo����8������ߔ
�EB����EB���G�D�b�-*�sz�֍�j�m D��<Ѳ҅�7Sj�2���3'�V��"$|�#%FT�bG����`G���n����w���o�VTM���+�&�p��ee$�.�αˬv��t,*/�a��)i��>��?`�y?p�� O�<�e^&~����/���      �      xڋ���� � �      �   �   x�uQYn!��S�d�K��̸	Ͱ�Ds���4�������A9���eJЀ-z���;.��1ǒp��.���#���vN� 7��8��%�k�gI�㷈[�q��w��{�{H9�p��H�����`��h�t23}r#Z���C��!��PE�AZ�WI[����6P�Ʒ��}��c�V-�4���Ƣ54�.���Z=�qp���� �r�V����KO��uC��Xr}4cf��Y�o��׹����x�ǈ      �   g  xڍ��n� ���S���3`~�,+!�Є�m����/Ʃ�n�K�s>f��@��ŞPJ���'ok����_T>�z��^j���t����ڔ.�۠T@Q�QɈ=6�� �r��MN��x1�5��;�`��̨�`�Ȩnvcd����Ck�k{2�s����"K���_�Ǐj�/��ƴ�q�(%9�%I���nFn��⟚hl�\4��������D��wS���������H�3�]Ic�k��W!��
G
���1㣔��l���
03�{Fm�4��Άz���-'
����o�qH��M��/� �!�Zʫ��Ѧ��c��q}oO�Q�8�J���qjѝ}�$�y!U3I�hJi,��
�u�a�6a�
Eu���0C�-r����r��e �TSz�8�w���ƶ 5�4:M�OkW)8�)vH���Ť��<�9����iV������o\��	��r�I㚧��Ͼ�R�HK���[�/}gn�0�Q|GN���C� �r������O6��֕���,�Y�?
E�%-%���ҝ̗XL��φ�|�T��P��]��z�&t�
��9<��m�N���d��-�q�9C�[/P�i%�/��n���^"`      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   �  x�͝�n$7�Ϟ��{��>(��)O�'��>�v� �}�H�{�� ��B	00��ݮ�)�R��L�!���nm��1�����������?����������o���R�����s�&�;�/C?:���gG�0�;}�y~�-� ��SR��O��z�����~cs�,��v�>��On��ڒߝt1~
�-ޯ!6�e��".��	|6~zʎ{[�o�-��=n@��`vK���>����'_��=F����3����t|B�e�O��/��Rl�f���<�O���� �5~��,��|w��$��}������8�o����O�?�߾���~�_���7X�_~�p���)����+�%�\e���&�靂eEϞ��n�/��n������z��ȳ�������{�����=%�P�\�g�����~|Y-�a�Ȣ�'~������*��u
���^e�c��dp�G�a��'�u<���j�K|�\�c�'�(�'��Mq��Er�Sw4��	n|YR��3M�:�C���Je�=Ƌ^�����aϮȄ��=���e����6��=�i�K<�?]{����l8*�u��L!�.��\���I Q��}����djl
�՚� ������n`~I�b�"H��~��[_Ԃ��WMM;�-�/�|֤�g{���IwX��ȟ�Ϛ�n��]m��鬩P�S�k����+p2;\+���V������u�D�ٹ��5{���%=Hkm�̊�=�_�lU��g[?b��b	4��!g����G�2��V���a��A�Z�ax�_[�-�Zm�{��fF��m�`�G�^��_ո�������n����<��͘N���ӳ�m#�_�ő_�KPH�^��|6M�g�Gqge�� _������E�ď���FnK�&)f�i{g7��tg#
��':p��ݦ��*�!-��?9(it����̊zv�{w?�L�:�-��7菻����B�����;���c�z�����y���^���X&jR�ܝF�w1����0����/}��Ȋ�O����2�O��Q����az��uzm�[���b���46�~�YS�|kh���d�b#g������sFs�}��q_�����z3�����/��C��E�{��3����o�gI�ʞ��p�m�p~�wR,Ո�U��c>q�)�ವT�%<����j|jM�\�H/>Y�k��b��R��6�fz����:v$�P3j�7�n7�.ېT�Lv�}�.��YY�1s�\4�L�+	�v8��j|,E���{0Es�g��������X2c��ۮ��|�Rʺg�.��D�,��,�}<܂/*� S<k6��r�d��T��fX�6�K�/ޓpߨ�R��L.����'���U�8DcQsry�wu�-���qvPlN���-���!��XY��4�yzQ���_ћ��xo��OV�BA0g�7���m�`�BS�-l�<C�M����P1�Td�Ipd[�����jn�|����~����)�G����Ũl��ff���~���b.���ɔ��l������Y�VMsU%���,8_/��C��CR[g��0M[Ɇ���9�z��>m�/�k�F�$����q�[�eY���z-�'�q��|Q1zO�wZ��7�e54��^k��;������;�b�#�n�zQ�À��Y�'=�@/��`��%5A��w�6��A���]��7W�5L��1�\� �k��+l-�oe|�5C���X�U�ڌ'>ƫ�-��VV�I�^���>���ea�X��p
6��U,���=��׾L�b����������2�Ҳ�(�'�qt�|�X�1xT��v��H�ԄMk��Al���6�`]S�������Bɽ)��	�x�m�p�bN�r�����|�٘��L۸��A3�^	�eP�kaz�\�Q�w6�)z��ˢ��&VT�����UJl+�Չ��g��Z+�Ʀ�V'�!��c|�Z��Q�<��p��=�2�V ��E`O�@��e�$cO�2�H�L����ЋJ�ye�l������!��[h��Go����Z'dw�u� ���c_���@��}����r:���?n@/s�`�ྤx��xa������Y�Z��n�Gam�{�_$�8��bT��o7�3�GN���s=��~�p_>���/��      �   �  xڭ�Ir%���]���!bb����?��~��CY�*��>���P0�F�+f�/�޾�r����F�1���+�/���o�o�̪��/P2���
��s`�����~{��|�sQ�'�dQn�V��W�� �1B���Ģ��C�!Ŷ��"]Z]��-����l��­
�I� FZ3E�ĉC䛘����Z�F_XY��C�m�X ��b�b��Ɋ8I^x�?�T/��SiEl#��_�L��7]Ĺw�WE��QEV��
qj<ꊸ������Rx���"αE�qe���{�e?VD�(O���s~��u�U<� %x��1�j�U)�+��[��Jq�P���H�g���
1(�U<�xb�ddtS^��BYx��&Ⱥ�nS���G������ '|���R�	g��O��yl<c[]�D�� ��s�q@��c�L��q'K���VT�o�F3=,�G��VY:֒t��{��<2}T��J�w4\٘@T�I��-a�ʔ��!
�p�y4�F�>��,�nbF|��:��r��}Up�Y�ntM.�suM�]"��]m�ꍜ�#�X�����}�pgA; �"�acW�#V�qB,��A�nNb�v�
��6�]=���&��A8n�*!��6��ȝ��=',��y?�p�&o����&�	ˬ�d�h��>g��P���S�r��q�'�hO��"veiq����n̤�X>{N��Qэ�ݔg���٦�8�8�n�(��<�G<J�?wcyNX\ľ��"���A<��qڱ���|�e���e��bW}�#�rP�������Nb)v�
��(o��Um��g����U��4�sF�S�猞C�&��՝����\ĳ��3?u�g��� ��c��8͞�&.��^ѱ�8��U$� �9�3Vx� ����<si��Ɨ�]ĔI�U!��	�#b��n�F98�0c�n�F�>bf�8͢x���|Ĺ,+\���/���4��� �:�&:h�r<_4��@'&N3������E���~�&�´ac�v��8;P����/�������D���g�k��i���"�?�w��}:v��9k�~@b�_�5�ă�62��b��E\����I��<���pע��t�b��E\G��x<��'���A\Yڵ���
QL����<�>�vt,���b_<��r0�{�yq����]�"�tr�1n�N6��)ŃX�:�y��+<Ăvn$Q��k�����=;7�N�%i�bg]�"�0l�|E�p��-!��=[BB�	q
����+|�-T�
 ��x����
1���~r��ؗ�|Ĺ��4l�ؗ�\���'�`_!��1.*hDP�/���]�nbb��F�x�3���x.�aI�n����gn�e<L_iA�J^���V����z�Xe��g�X}�܊�.�I,!�x@|��r�0ʺ®��7����vY��S����й�a�9�~G�&�ڷ�5y���WL�#-�'�k�~�^�q-�q���/
���C<��8Ҽ��.∋⟉�} 4�s^���|��p��K��H4{��!.)�"�b=�>	�q)��'1c�b�(\��ZT��=C���?�:�7l\g%�W�h���mbF����ݱ�찱�x���:��E���Ҭ}_�fV�*�2���*`՟��E<��Wl�$�t@l��A�*�ac(1�텛�����1��U�<���e���1͎'������,�B�ZK�����-���M<˸�S9�y(.��}�G���oϛ��Iޱ�f��"�nc6�n��M�,�dc���"�".��}K���y��͢,�����W�`Л�H#z���xM�7!�ظ&\��'���P
��)cW=�s���<bZ�x@,�;��M��
^�m��a�8٣c��J�c��|�E\)�ص1\7�g��!�DQV0�3�����Ɋ����q���p��+�b}w��"6�VE�cBDS��C��|����"�y*            xڋ���� � �      �      xڋ���� � �             xڋ���� � �      �      x��\ks��r�����iޏ����{kS��u��T�R��'		h $E��O�i���IɖIv�&NOw�3�IR�8b�kDHHs�ǊGL���?u��iW�/þ��_�z�]Ot����0�tY�k;�rm(}[�]Y5`n�P����
RS��A��X�@�D�)f����Ud�?�;�!�G��� �X�,���I�F��w���{��Km�*?Ʈ-����m|,}��M5��e/t�BG/����o�]�����VqwW�bݵ���^ܓ{uO<WQ�蓷^F�w��hU�!1�T �2ʂ�2zM-�:Ii���u�h_�Rca���(� h��s@�L��N���ZUy�ҵ�ЮP]5�S׆��m5���.�Х������.�nS���1�'���8�����\[X�U�(=<�e��R̡x��4r`��9)�~��h�s�%���ok�U�W�	(t�66e�Y�.��t�X��Е�vCb�wݪ�Ů �ؕg�46�p%&��1o��$�G�mp�l!�%��������ئ/�)W�t過h�J��i]i���u,븍u�K���o�P.�~]�Ή��2TS!���V�.�Rr:�ŉvs�N�4��N��C���6M�a-m�;�ӄ�%��;(\���}�N����>��+����v�e�l7������]��&�؀moK���?{W�sa���½�>)��K�b��"��!�"ƐU�{�dIZ�#�	��ta4�`<ف����GF��Ld���^¿��� ���Ǧ������>�}�_x�ϼ����߲��w�[,�`^���ƾ�4��ow���6�~W�xW�2�Y� �}��\GS׮&����ĨZSV�.��	KG��J�n K�aM�|����="�~��1W��8�xX�uX���Ѕ:{��+����-����)]�+w�N�c��:�.���D5�d��I��*� 6D�3�Y�%�ه�?z`y�� �a@ߴ͢ru<Q�w���=��g��q��naa���p����l�Mm+�������������	������,}�2F,�Ǝ��:��k��JzyG�PXO!���
q��rq/�[�Vy�g�~i;��[o�Z�븂::bV�G+��ڊg��xW�9���i��}��h������u�C~�T���o���e�����?E�B���N�tDFAp�"�5�Ш�#�p�=S���p\�BR�B�c|#�[MF���u���9bj,�ۑx��9���L�P�_:�^�0�9��L
{�AG�8������z�*�5���T��9� �"�;�$`Y�nY���pW�s�q@�C�Xń��E1�T:-a�X�p I:Cm�Nr
�Y?�%�X)�!p*z2G�f�̕�Ȍ6�,�BNhEiS�Pl�Р�����=��َ.�����^�@
r�Gl*��;ZS���5�&vw叛� �ph��=B�������З+8�+6	�`��CH@���`�C��+�����n�w]N��X���ë'������	x\Y��bY���Ⱏ`�pq���U_^���<w�X5Ǟ<cj���)n[ 8�ތ��=�ϱ.��}�F�6.l�;��Lm��jjS��,߭"%� S�ul���0*�E�����T�El#�O�]�J�v�&n��y����������6�P�`�}�ش;�A��`���:{�+Իݮ>�����/#�[	eq(��r�a @��L��-�VWeVB6ף���?[�K�T��ߵSFk�S,ˍ����@"X��*��(��	�׎�Z���L1��d���j��������d9B)8�_���HQ:fw7�5q8�������v��;�j��}ٵ����d@��U9ا�)�{����rBh���S�:�(�Å�D%�0��i#0�����|
�lU�� C��\�	B��4��iڭ��s�?*�XTg�E�9���6�g?� q˃���g���u�g��r���j�|Rd��*��Š�$*�Ψ9�����[P�J sF�'�p$�P�N�'�?��w��� &�X�~ٶ����I�v��|�����T���͙Ie*�z:a�*�v#�tn�E�)}�F�1��5�r��L
�x�l5S:��K?�>�z���n��? �i3������(���ƆwW�)��=H�>֩�������ҵ�K5`��ܧ{�#��t���	Ujj4P8�,�5Z�nn��Q�
��k�2r#L`��%K�<�3Q�X:�c:}[R�����>ׂ�2����Y"��&f�N��6;�����'�m��o�{����d]����³�I�kht�{T�h�5Q�>p�$i�A�Fc�p�B��/��pE���d���V�P�0Oܒ��&n߈Z����vic~vޑ}j�j�P��@S.6Ԛ
X������$ݒ�i=�9V�ɛo�$%�,GO��p��3>�X/���nU�B�W��<��ـ�]L]*~^�;J�٠���o��-���u������=U_T�sJ�'�0ix�VW��T�NnD�^bA�sa��� :��I*�$�U\0<���m��}��[�!��8��x���Q�S���ރ�����O���?3>*?���3(���o�Nx]��ֱ/��3��g��}�ZW�{ָ� Ju��6�} ��Cjt9ކ�>Y�z���ŭf2��*��F��������~(	t�����w��cH0�%�jêj�/�/���a���((�����I�J5%�Q�wIY<WP�zj����DE"�$��vj��;&� �`e@�Qަ�`�wi3z�bgѣ#z==����u�6-ʋ�qU4��q18鼕A%���%�$Ȧ�������T���
֧�e���B4[��F�:hVtQ6"���c����6������?>�G��56�B/_*#��I �*ԷB�8e�K��@p�k��6_�	��-�0��<9����O�'�p�S"V���ĳJw6�d]��PϘ����B�iT���L���+�ˍ�!1\1�+P���~�i/����#���__�X!�┄֠�1.��0��q�	�Q�hI�Yg|6�n|P7�5���5����H���`u"3�WW�>$*3�r|�2���a��+[�~9]eDө��^�W]Q!FK_{����r����W^�D�@���p�j�m.\SXl����/\���No_y�j�µ >1y�`�V�_+���^�y�p��_6��,
�7U�=Ē�`%�;�u� ��O��O��>PP$��^0Cp��ZG˧��$RL��l���A��WI�H
�{���J �wDٸ���qĜ��=�t����	��t,
t>��!
���"Ϭ� O���-��U�o��ជY2OG2O��۵��W O��� �L��_���Xl�':K�����y5<,7_��_$S|F��O�bE�/�>���rCf�6|\$���M�~�ߵe�5�|ꚳ���-[�s~�bM�r6#��8E۶��k=��V��LLf6��s��]+A�g�u�N��&l�{c�?/��}NO໲�Ѐ���I�#G���E�L��%���SQ��"�{r1�4]K��7����p����*PS^�YPG�9z�|g�W�$�lʟ�h!�H�����k��ѠyPw����"Hb��X�����b0P�I�l��$ɷ۱���Ś�A�~y7b���WW�g#:�F#:�y҇!�O���\P�����'��9\�ϑ�}.��x;��'�	�
d4�)��
XG�a�`(��*H	RZG�vc��u�oDN(C���p�͛,hMl�L�<	�tZ.�!;.��&ѳ���o�yOh�P�E��<�~&r/���;�_��P�`e�8G���Nƙ���K@�L9"�_��ώ/�@_8�˶_�j>gf��������)�����0�,M�"@W��Qk����Hłd� 5�λ�������*����S	��
����f�8�s�s_9��a�f�5ן��*���f�O�y�spW<�7���pҗ��*�����/F��R: C  �h�χ/f�7�E߼}���m�_�)B�1�9�=P0ɝ�I�2J!lJ\���JL�#�q�������N&�fJ��;�%��I��Z{?�{��093Lx���|ܪ����UU���g̼�"\��O���m�[��ſ���0��8���xW�z����n=N��o��w���9M���
Tts���|wǍsq�F;͹�P����4�7�q*ZQ@��3ܱ�%��x�;)��4��zyO�h����?!��+f��L��8�[�_Mz�6�o��Y���:9����U�q[���r]�5���,�h�2�/��8+����}����rF&Om$ �ā��FiNR�̨�q���IRX�A��I&��N+�wXb������/�����w��I�+� �&>���3�������ϧE�:N̼�-�î������Ec3��bvB;�(��q8q����C����$H�|�q�vC�[Ʀ\�u�+�3�UWv�`�������:�>]�6������C,2f0s� )gRx/(�ʱWD8�:&�l>��I�i:b��E���o���Ti�_y���U�:�|�����'G���У���`@~�eIԏ��v� ��vU���ʟR���B�b��t�`�����)��N=��"��i��AT�P�j�B���c��	�X��� fa�P.��7bř���?X{�t���*f��wm���	�d7�p��P���B�^��.�SA��A�?��?����\����|  O�c�y�{�������4
���6�%Jcþ�2�����z�A��5��E�&z8����4��9;�+'t��ڙ���ՎS:�� ��w���Pj��\IU��h���c���σ��X�^�J���r���
J��������	�������֣��I��x<������یPm>|����'&��n4	X��'����ُ��8����P	�0�a�:c4z�+/t�B JW���=D�#|m�Gs��q1չ�u��-�B�4.0�O�԰,����J9١�U+����m�_c��[h������^w�A'�N���(�#�8�gF���h���N��<��n��nuI,(��IBpk�(%���7O����ā�`#��(+,�T�0�y�a��@o�Ӥ.[��Fp
��%������Wr�}�>�G��H�tvA.��}�n��-~n�����٦Z������q�fۭ��^v�|�:�S�8EF|\a@�0�p�pÁ�Y��$� �Z�4$8G!�WJ���C&��?[��~=���������笮�縨�Y�kGB�}�.��=nw�]���z��oe�)~W�<�b����Va��ZI�����Å��31Oc
��R�w2�b�[e��ρuAb(^�B���"�,M����M���Jk��uj�n�V1�'@=p	����y��ogWr��KF�]��W�Bu>|�?�]s�j����t1����f}y<�CYʧ"��m1�j#	�@�A�k�@��d@�s:��IJ�z��TTΔz����/���U_�������ꙧ��I���������#�      �   &  xڭ�I�9���S���HQ�,��x�#���W�54QWf �=&����[j�����'@o?�r�IA���c���`?��oԿ!}	�C�k�B|�|�:���:����c���4.�'1�3��#�� 7Ħ"�6�7�K⒥�+j��:.�̝[]K�"��8%o�XrXgC� 6L�ĵB�%1�B��P���u.�$�b~l)Ew?αE�1���0��n�"��2�P��1��`$��RP�*�	7��
EKL�Ă�.�%��٣�����G�F�%䄘�\�m��1��+���j�LS�/���E���*H��^!�?�6d_�L�J�[�;i�b�H��{٭�\�A��%�^���4^����ћxϏG�	/��/%�G���4^(!� ���QzX�<ń="OI�k2�@� �K�)��#�"�7�V�i��o�)�7�Vੵ΋��8��XS�cI̥��tӒ�^s������T�H��,���[bS+�������{��2eo��h�Q/�N���7s[m�B��DI�M�՗�TOݘ�B� �S�*����r�ц�ω!��؃G�0�E�0�%o⭂g1f�ĉ�����<��Cω��]����H)���Y�vA�bzű�w�H�Q�m������r�Cl��Gĭ({(7k��"�i�W[�*��k3V?�e�\x���6~�{^1"�A���{Ez�U��{b�t,���h��9�����q���ʍ� ��r>��ϼ �P�8�L}��+X{Ĉi��x��|ue��%:�u ���|AL�J7?�E��.�������*ry"�X�^,5�D�Y̲��]-��<(�7�VW�[(톘�بt	��/��tKg����Z�r�Y�����]���Wh0�)zo	��M.V*`����#�jJ�X/R�I���k?�`�sc�?t��zW(;�1��˷~��W+�� $r��(�*\ؘ��~�[��0Ů�)�zoi��M��)�¯T�G,���U�<�"���׋�|V�R�f��ŋk��D����6?�-�V*�r�ƚ�p�I\�TT� ��x�}���y%�ˬ겴R��UEĩ4�X�\fm*V�HnP����[�{�ޔm>ʭ�(˵�:N�.^!��'K�f��|��ƌ�v�6��ե�UզxAL&ћxK�g��Xb4o�
R-6���l�M�U�k�N�"��;�T�,��Yͫ�s;w�A՛x3W��.�a�!�����f�]^�bӷ��$5�,��8���1E�w뱎VV"g*ڎ�ŏ�5��z$QH�6�%NK7�\\��[n��/a�����X`v�+B��i�b�w�яxϏ��zcc3t'�����
B��f����"��T/�)�sn~�[k��U,��)D{������P�^ӹ���}�w[�= /���[�H�<W$�wE�x�Ĕo�M��&�B=A�sY�NG�>sn=	�|ALH�M����Ԗ�1'w��3Z��j�D��V������xKu	��x����[�
��)��x�f�ՙ��u�i�A�^�^s��؍x�~�V�^����3�[��M�R�#�KMo&W8H|�������T�r��F��[�G�^`1��m��^6�� &q7�^2�^Th�����D��t�%N`�M�CbZ�*��P�e�i��G@�!���ně6�Xn
S�tD��_�Ï[��Y~E��V��\no����[�mԚ�y��Y���R\I�a�yd7���Ή��+��T&}�"g��ՇX@/�DH�g	�9�7������|S!���Ҁ����I����2.��h��4{oD�|S���H��C[.��K���,R����Xtu{K��7�"_�gUӓx��<��>������Wl�y�h���=��C珁i�~��m��*f7Rt��і��O���S��	�����XD�ʚ��)�rKX��	!|���`j�����,;�=��y�T#rD�h�b�az|��$N&�#+�̘YE� ��-K,������X��+���`y���J���K02~���׊H��1��Rk?>�+϶X4��X�Olv*�b�6�'1��s�d��
��yvK"�^�h��Շ�ޢ�D��l�#/)p��Y~���*�g7������e>��m/�4۳1�X�sŬ��z�&q�ݥ�h	]�s����xzU[E���%W����Ē�X�����=޴�ĳD�OϤ�jZ�h� .�� �v.��i�O�;�FF�1�Z��т����F����
��y�m�y���D�ll���fM�K������X�M{�9��Wd���M#� ��@V.���R?�A�|A�
鈸�\i�c���E������!��K��y��.U�u�,��'�%%��`�5Z�>ט<����3=&�.�t�~��mj���(uy�v!�|�G��
b1ʻ��I�bu������#ov�>����]�R��Kͫ�V� 60�#�Z�G,�e�$f�|ځ�W@��!��ly���yU��D�o��,zBgӂ.6n���m&���ڭj�J�5϶����b�pk�#bN�u�-7V;��/����y-+���gE�����񿇫儘0�@ω���6����a.%���|���~�#b]'���Lz|*�f'���6`	Pz���f�,�Ҋ����"�g��+��j��@��C\��I�?E�H�%�JX��o��pA<{��Sԩq4��kK�a�M�����;BpB�PVC�`}��,x����h�w[
R[���P�jAh���U�3����m����Mg�����[��#���ewMJY��mڸ��ܦĿr������ƣ�ra�)5?ۥ�j�q�-��b�2f� V�#`Ϋ�{&�$����f-��w ]m6χzY]öi�5����{�G���5���f��j���WMt.�\DE�3�K������K��%�1B;�x&�>cc���V�g$�����/d�)}.�%��"{�e*�ә&_3����D�d����XYf[��V�!��T��#��c����R����b`k|����E@�/���4�W`�@��j��ъ�T���೮�K�cՀ��?�?���׏?���B      �     x�͜�j$7���ϒIT:�.��밐�@(�Jk�>��؛lȻ���؀����``�Ѝ��W����U����2�d�1���в��P���g�g��:\���x�������������ñ9�\rl]\ͳ��u&��ǻt�����O<��yh?<ul����a��L-?7ȓ�&*��i��\����?~-��[V��Qu�G�'j$�F�z�(�rD�ztj]T���7��B�a���>֐�Y:t�����ٳs=��,����=�+��*���<0�$�$x��B�3���_�D#g�d����Q�H���A���$-��a� � ����5�Fci�X�@��5&�,�z+z��B1 J��_њ�u�&�9��Q`e���6���`�z�($Tt�O������0Qp�0Ź�RS3έ���DQ(���މU���s<7Q� q��cm��J������R��?f�E_Y
{�O4QH����)]9jz i�z��F����!cD������D�B��Z*Q%��=�6�γy���CI��/��<�s������	�T�^�������;wz�1��y���6ˌ*I'ǹ���!>��w�~���O��?�wg�ӛ|����5a��kk� ��Q��~�{9��]nv󩵿�t��o��R_/a<�~>�9�:������'~��M;�bg�1v��}EϿb�@��c_a�h)e��G�H%��_X�~�*S��f�T#d,��ҵP4���q�G[�I*I�s�a�(�둻�Ijɞ�0Q�����7\�I�4v���BfB��MR=�JT]�a��Tb�����	&bA�z�(0
��h��X%����F1���B�\�H�+�g=,���t���Vt��}<�6�>qzϯz+j��S��+�MP�S��Z���$�58^�6
Z�W�zt��!�R�g�n����p$s-i���ٵ�(r��=�q*�L�a������g�U�^jMp\����ك�4p� �U�O3f뇶����"*I-/=�r�,��4����L!.���S�3f�gF���U���n_Θ�"�8_c0�T5����D6
N؆w=8ִt��q�`��R��Gk��$�2z��D��8�p�Hc�Hflյ}X(f����	ej�g����#E#D�zT��O�|�`��a�zpJI]Y�Ra�zX(d8���q��E%�i%�z�(��{�+�"D��
�㇍�Y��W2Z���-�"�z(b�����6�-栒�B��6
Ɛ��#���\3�$u%�o�X(~�����_�K      �   )  x�͑QK�0���_��&i���	��胯s��rWd䦎!��mbS�wChsN�87��k��#�2{�:;���WՒ�~��׼�7��e�PRg��B�¢f�]oHr��ł�vM�a��7�h�S���������sB�$�4�����u�s{�j������K������Q��(CD�C� ����=�FmZ���X��W;@K���6��go(6S���ȁ�����ԣܛ�D�;c6�WqII��V�Xg�f'k�Di���Ԏ9�$g5˹7� t$�	�����o�y��I�      �   .  xڭ��N;7ůûPy�c{���J�?!�$�(T}�:���ޕ,."$��8g>�,P xc�Q{�G���|x$�(+Ԝ�������r=�����v�|��ן_��_�7�;�V�+5�v��Q{�{�C��ǩd���#���.��|�|����7\%u!��]Y�Jt��2X-�M�R0�Mv*�Cvv!@��҈ cj��v�9�!�h������F0�&C-�0��l �$�
�Z)��)��3����>��>C�ǲB���2���M�Z������S	��E�$�G�ϛ�x��|@B�vm4��H y�d�P�!C#���O%0d]��r�#��1o눷����}qJ5#�@hM]����Z+M2*]7��[
���F u�Ƴ�R'�&#�=�҅`"�ňu䭙��t�l�	�Gm��T#H�C��6�MF�����҅ b�� �|�S�5!jw�Gax�~��L���a1ÞT�d�k<���>���"QQS�#�V��A�hG���J`�b�:#�P�"�n[���O�!�G���A�SS���m4�b�QOZ�sG�ZO��p���6#��s�B��{jZQj֛(��ǋ�ߵ�Y?�R�L6Tf�W��z�W���8�����]�ϧ���w!���VBB63;����)\d�L�T�6�B�~~w!DYr�� ��8sQ9�4�4rI>���n�����|�!ꖾ˰
��v�B`y���R!��؍	��zM�++��� ���)f� DN�"C଄��"�DVR;��c��2�4H����>��g�zьX!���zd05D�E��#	��[����2����,2�����q;��õ#n1�>]0<" �s	D-/`o^��F����I�
��>��C��i��4��A��� t��s��A��hS;��q�؅�G�^���R��lx����u!�6�Ċj@���7��j--����v��F�l�����ޞ�����?VBD"mi��o�a��uD�#
�%�gsyɱQg�m2���㷇��� ;\�      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   ~	  xڍ�ko����k
_�άvfn+��T�+�����p�7��j�9���m� %��uf��@nE���S�&��>�W?SeK��pG]�Ϟi,�ul?K�
')���C�i�گ���?c�"��o@�;��O�?(���8n �7h�<ñ�;eb�;���n��%,& Q��o���K��W}���[�~^eU�UV�׿?� �s?|b!��I�o������_���@߶�5+ڂ��4Bҟ��XR�-7ZUΫ#�N���e 9�l��>c6�w�LL@�?�æ�'�\���*3��'�$Y�q���"1{�����������$�~@��1O�$����R��1^�n5� �5YD��3c�;�'+Q7́^g��:�J��ӓ�G�qu��+~x�0a�S
z�o)���HO;�qP���h�ԥ!�aV 9R��VewV]�Z�3e� =2��N|a��<�v����y�u8v7Mr�]�Z�sɧ꥾Ռ��fZ��{z�9�� `�.κ��^�rF��4��nc3)/�x���vZ�2b�)�7И�ܗ�߆"]�7fw��B�r�K}��Υ��t�K�3�DA��ΡQ¦q���W�s��J�}�h#i����u=�_���:5��9�Ʃ6)��W�I9b>��/��E!)z�,��,!���c��;��Y��X��<�!?S�$ti���jChW��f��d�|@㳴����\����O~�S���Xb���R�z�>ɜ� ����I�?��,9��3<Z�����d��)|���]�9-��*���)��4����ن:��je����c�Ђ�S�R�͵�侙�'fm���N��,0����#]�*����:��iHP�%zN�:ޝ��p�'=�[��ص7��U��0��9�{��Aڹ��G��a���8VF�^�YrJ�Hl��N�}~���F,ohX������D\���� eͦϑ����R��>�6����E�f��L��1�g!fq���gc>�<�f���26!Η}i>��3@roq���tF�p��'�0���U��k$W�m�,�R��;(�>ζ�?N�	�<��.ˬ�n|�&Ko�
/��(J��Ӟ#*����̨�:��g�铩��܌f���'M�~Y ��C�, �>y�Y�S�k�pm(|Hb�8��Ψ+7|<��i�NO���Y��`pb�2ʷ7�:�rXpff����n�3��'ʲ���B�6m�+ ����^�\��i��6�ʿ> �4À�'�������g.���H#����A�/f�q<���Ԡ&�*��g�sYY�q�sc�p���Xl�/��}��f)���v���m�`A�0]�����[���PS���&��7�A��V�fiDQ��b��&�������\7w69�����a���R���}B���Θ;O�}j���ޕ���SF�ֿMk�l����>��"�p:�ݘ�Hˋd˙!��%��Lֱ?o���Z��/��uq�,I���އjS�Pn9��;%���`�
�dw�ľp�j|�e-YJI����S[{�/���|XXw>������x�|=�����u�<$��}Xv�>��<�B Ke	��xe�)L�ƃ0��.[�gq��u������p��T�n���q���< �� q�if���4ko?��ۮ�.��"W�Bk�^���.�����'*>O$/�v����j!˥��D"�����l��90��s�Ĥ�Hن����E-ۨR�76�<A�1�d�x�47E:^!\E=K'VЗV.myB���h�>.)Mq�y�,Θ=�*��n�~>^�,Ȼ��Xv���z|��fi`�{RA����6���Q9s��$�JM�	.7�@���|����.w�4�����ˊ}I�qi�u�H�%�р�ÓO:�L�6�^��ã�{ġ8Ģ���[Y/��	+�o��/��|�8J|\l�p:T|ݐ`YzbO�����k�b���y@�9e��K}8��n;��R��?m4���m�D�l���C���^�1��^qcW!��Fn��mq�s
�,D�=��?	�O2�ĉY����W	f�zZW�*� ���ٖ���n�*m�ecs��iRǕV=�ƫ̐��Z��� ��Jg�ɐ���������L�C!/��2�_��� ��%f��j�ϯ/7{۟w{����(
w�6�**G��M4]1����b��\)�r�Vn��7 >�G��s�\��<׬�=7�5�8��}����Nz��Y�����Ƌ���=c2�By����+}C=�ڮia��L�o�z�-��w�v�i�'�HRk*Z����-�u�/�?yT'����`�;�󭝱>
ۉ��F����/i������㼰�}���j�ߥ�����i� �%'�gz�dޝg��A��y�O���<�6L�뻈�������ne      �   x  xڕ�=�A�㧻�50� ���?S����y�Q$J��
5���Y���{n�7@�[hۛS��s�ܿ�~����/8Kb2}z���rw���!�E���5� ���X�J�E�jP��yJ�G�C2����\�e���sU���Q�[�ɹ��F��������^���T
\�t<�Ol-���Ҡ��*]-sr'摫���;~�9��et�媺���̎~¤���ѡƳ���~Z�Fjb�T\���,��Ծ#[����f�w[�Ϭ81:�=1!?� Ǡ��{�W,�}96��D**{u�w'C����A�V�3*�0T�U���*��Au;cG�{�\TԻ�cu���+]��_�S��>�D<������WԼ���U\������:�*9E�-�'C�Y��`��^�lR��Y�6>ޡjʪ�����ugب<`tj�{�𨨁�n��;`�O��Q�!tT���b++�5��Su+"�����P�
�}k6�>[�R��9
�$�yJ�N١2O-�!|�C5_R� bRD�[�D5� d)`���J"��U�}ݨ�HT��-H��2_Q���_��XQC�tH�{�}��:h��붋
g���j�z��4�<~�x�^� s�̽      �     xڥ���$7��٧����/G�g�C&����aez{��8c�Ќ��� ���
f&��/ޚ{�=�w�m����{r%��Z�o��?޾��y-�hu����Q������������ϰ_0y�^_�����������o�~���q�P��K��~�no�������풆�3Uҁ��m�<Rrnc*�drnc�16�q{H�G���i�1r�,7nc*=�qn#��
�v��.=Q�뵒n���^���Z�6�-�]e�.�^/��Z}Ǻ����M��*:k���wI
��^>�t��i���9o�&I@��_��W�!nnk1k��(�NTqΔt$K�7I���.��m�;�e�c��n�4���6Hn1ٍۘ�E���`;�v����R�m��k��mL%���
�v��۽���Gj���nc�&�n��T�j�/n#��2��ٽ�Kr��.l/	�-���Tb��������v�ꑪ{�`݆���n��TR��wE�̜d�ŢGj�J����»� !u��Kb��V7�mM�!�iu6�Aro�&I@�m�Rnc��}d�DG��ԥ������5u�Y۠JϑK�;w�SoO�j<�13D�ةH��&�pT�d\�q��I�Y�sGjMٵ��O7 ��\�\q�_�]Ҝ�x���$���1��	�6�m%z�޶�85�6&]b����T
TI�u�����%���ء�\`�6HncݬmLe77��Ja�>��W/z̧�����6H+_���ώ�m��bN�.�lN'GjK��I@��f*��\�B�qwRp��i��l��j(��F�����g�JN��m�+1��%���P[q�t$�yQ��*)����m�[�$Ǹ]t�>���J''�0y4�7nc*kR�m�;�.��g���T�l�`d}�$	�R�#�F�%x���.^��a�U�0�m�<R��A����g�1��Ӕ�ے������8e݆�%��V)��s��Jg��Z��"��%Ar7	7nc*k���q��)1n��穮�.��� ��E��hp�چ�IrV��}��G��!��9�%r�6�����Ƹ��۵�Uw���*�6F���$	�҃7��Ƹ�2��sAs�TW���m���ƛ�T�d\nC���a�nR�8}���<ؚ$��o�mP�g2I0n��2I�zM�J����m�\Mn*@P���m�ۥ��t�]���.ϩ5�6F.�/�U��Kbܱ
U���+=TM5��$Hn#��6���0�m�;ܲ�$�p}�S]9|���%ArS��J�*����1n.!3���!��g�G+�u"����U�\�`�)�05ɘ�Ow��I�6F6��f���"��F���V&�5�;Y��2;�� yVS�`*9�N�>��qG����h����ڭ��$FV7��.	�d[�چ�3�W&If*��;[�K�d�� A�Q������3n��c=R%�I�{��%A���׫�I����;R�#�� ��}�ﻍ��թ$�i�Ĺ� G�O�죐5	J��/rU�u�m��j3e�n�;;R-�߼F�=I�Y۠J5�{�(wu
�/�e�ՒK�u#���[Nnc*+qS)�;c�
<�9O��L�4;��6H.}]���*����/nc�:b��U�6��3w�,���DU����A��b�dNMv��e�$�ps.	�,_s��F��x���4:��c�LCɥ��T
U�Z�z���1n�<�u��]Ƴ���6s�$���K�;-O����x�X�� ArUw�$�����$7�*J<-�\��ly�Ig${I��̝��DUd�m���7��|�*�Ha�%k�9U�/�J���~���/s���      �     xڥ�˒�8�׮�`Y����R��Y�b��Bؤ�8�'�����- �+"����?~�&9��Y����3��MǊ{L�����G��v>y/B�Զ�H2_ﾵi��-�	�>я3�n'vS��A�&X���'/�j��0�E	1C4�Ͻł/��Fr�r�E����*��l�{d��gIQ筅X���_�ݥ��4t��N����O�S��s�1��	����f�<��]�����pH\Y�c@��Pմ�m��> N�r��rМ�J!�}��ϥK�l�$M�I�e�V�(�J.���֡���%���(4}�|b�p���Wa�햆���}��������V8N��2f�m':śl+�y��O��D����D���~�#b�"�b譾TJu��P��2��R��� �����������h�����5r��TEk�*.|�f��YL��������}���:�p�9��$k��]�(�dA!'t�eJ�L&r�^-y�VI��!	��+{+�!��(�F�vxˠ�=o،J��,Ci�Ɏm,N(�7��?�D1��H��?;���Dʚq�H�&A����2 ]��y��֦��С&Gi�a�T�k�k�z�A����9f�1K�E���,���0�f�z���|(a��oC$��<6��ȘdRiF� J>�*��Z����~y�l;
?��z�T����P7e�/�h�5���0Ƽ~.߱�ʕ��D�4�S�1۸8�j�������˾��29��fž
�#h��}��C�vF��B@T��8GR�� �&�޸tލ��ū��6��w��1,z}Ǫ�#q���VI�&���ib�b��Uj�0��s�rc�������ш8c؂tc�l��R�U�F�\���������N�S�}��90�rKBs��'�	O��p��qjd�phvb^����Ԩ�Sy0�����%,(c��!���\�H[��h!�����gzmsa�j�lP�kw�l{L|���}+	aZ��0���*E9���Å�Q����)�h8��s���Է�&�*�Q�v_����
�堻��.�Hwh�m�+.���q��9�J�̮��l�K�C��|[���\�]�࿤j�TF�~IB�$tI�N�m#ӌ����3��,WҮ��?��5Urn�c���;7�� ՙ�a�<k��E*Yd.�/�@��R����z�1I
X�%�J};���0��f8����i�R�>r�#��BpL./�b���h7�bk�����`�_m�"]���
䜮9����|��1�^$|�������׸|�Y������+����;GS�PS�B{�����m *�`ݍ���7��O'
�2D2Ӭ1SJ|Is�=6�=�?��$�mV�o�'����F��qD���$x���ndYofG�*7�ĭ��!�R�� �b��*6��҉k=4�9��p'���M�|���<�������m����m|E=� �dpt��)�W�"�[�t9 ��QBa�HHR�R�|1ρ$y�&��0<"x��@Wx;v��iO3/B)�oc�O׍h�2��Ĳ\�|E,�^:UHlY6g�}?�6�F�����%����5Ơe�,���A䊮1����9���X�i�di��#h�Fb�������>Ҍ�{�>|TyD'g}�ȕUA������xE�HʦI�'ӌ�p8�b4�����Un�E\,j�$�J+����{޶� _��U��t�Cq��O˕�a���Fj=]���T�Վ9��խo�E��S=���\��j2�n���Aũ�W�TQ�����˷o����a(     