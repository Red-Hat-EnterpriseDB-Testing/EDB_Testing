-- Run on the EDB Postgres for Kubernetes primary for namespace edb-pg-demo (e.g. pod demo-pg-1) as superuser.
-- Replace REPLACE_WITH_STRONG_PASSWORD before execution (avoid characters that break shell/YAML: use a long random string).
--
-- Example:
--   oc exec -n edb-pg-demo -it demo-pg-1 -- psql -U postgres -v ON_ERROR_STOP=1 -c "$(cat create-aap-databases.sql)"
-- Or paste into psql after substituting the password line.

CREATE ROLE aap LOGIN PASSWORD 'REPLACE_WITH_STRONG_PASSWORD';

CREATE DATABASE platform_gateway OWNER aap;
CREATE DATABASE automation_controller OWNER aap;
CREATE DATABASE automation_hub OWNER aap;
CREATE DATABASE automation_eda OWNER aap;

\c automation_hub
CREATE EXTENSION IF NOT EXISTS hstore;
