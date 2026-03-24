# railsapp 
This template is intended for use as a starting point for new Rails applications.

## Assumptions and Notes
- changes to `.kamal/secrets` and `config/deploy.yml` do no require to be committed
- PostgreSQL accessory is initialized ONLY if its directory is empty; 5432 port is reachable from web container, but it's to be exposed on different ports on the host eg. 5433 etc.
- we use different dbs for solid cache, cable and queue
- a default worker is run on the same machine, jobs are not run via web process, `SOLID_QUEUE_IN_PUMA` is set to `false`
- a `data` directoy will be use to persist postgres data and attachments
- some secrets are stored on 1password, **remember** that secrets has to be set in `.kamal/secrets` and named in `env.secret` in `config/deploy.yml` too.


## Env variables
The default name is `railsapp`, find/replace it with the current one; pay attention to do it manually in `config/application.rb` and `config/settings.yml`.

Set `POSTGRES_PASSWORD` in `.kamal/secrets` and eventually add any other secret you want to use during deploy.


In `config/deploy.yml` set the `ip address` and  `proxy.host` accorgingly to yours; 



## Setup
Create a "data" directory on remote server, login via ssh and execute something like
```
dir=/data/railsapp/postgresql/data/ ; rm -fr $dir ; mkdir -p $dir
```

In `config/deploy.yml` verify **accessory** parameters: Supposedly, you shouldn't change anything except for the app name prefix in `POSTGRES_DB`, the `ip address` and the `port`
```
accessories:
  db:
    image: postgres:17
    host: 159.69.196.166
    port: "127.0.0.1:5435:5432"
    env:
      clear:
        POSTGRES_DB: railsapp_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - /data/railsapp/postgresql/data:/var/lib/postgresql/data
      - /data/railsapp:/data
```

Boot PostgreSQL accessory
```
kamal accessory boot db
```
Eventually, check db is ok with a command like this
```
ssh root@159.69.196.166 "psql -h 127.0.0.1 -p 5435 -U postgres -c 'SELECT datname FROM pg_database;'"
```
Setup Kamal
```
kamal setup
```


## Deploy
```
kamal deploy
```


## Commands

### db:remote_pull

Copies the production PostgreSQL databases from the Kamal server into your local environment (development only). By default it syncs **primary, cache, queue, and cable**. It runs `pg_dump` inside the Postgres container over SSH, saves dumps under `tmp/db_remote_sync/`, then drops and recreates the matching local databases and runs `pg_restore`.

**Prerequisites:** `ssh` to the server (key-based auth), and local `psql` / `pg_restore` on your PATH.

**Defaults from `config/deploy.yml`:** if you omit env overrides, the task reads `accessories.db.host` for SSH (`root@<host>`) and `env.clear.POSTGRES_HOST` for the Docker container name (else `<service>-db`, else `railsapp-db`).

**Optional environment variables:**

| Variable | Purpose |
|----------|---------|
| `DB_SYNC_PRIMARY_ONLY=1` | Sync only the primary database (skip cache, queue, cable) |
| `REMOTE_DB_SSH` | Full SSH target (e.g. `deploy@example.com`) instead of `root@<accessories.db.host>` |
| `REMOTE_PG_CONTAINER` | Docker container name for `docker exec` instead of the value derived from deploy |
| `REMOTE_PG_USER` | Postgres user for `pg_dump` (default `postgres`) |
| `REMOTE_POSTGRES_PASSWORD` | Only if `pg_hba` inside the container requires a password for local connections |

**Safety:** you must type `yes` (any case) after a summary that lists SSH target, container, user, and local DB names to be overwritten. There is no non-interactive bypass.

**Examples:**

```sh
bin/rails db:remote_pull
```

With explicit overrides (only when you need them):

```sh
DB_SYNC_PRIMARY_ONLY=1 bin/rails db:remote_pull
REMOTE_DB_SSH=ubuntu@203.0.113.10 bin/rails db:remote_pull
REMOTE_PG_USER=railsapp REMOTE_PG_CONTAINER=railsapp-db REMOTE_DB_SSH=root@203.0.113.10 bin/rails db:remote_pull
```

After a pull, run `bin/rails db:migrate` if your local schema should differ from production.


## Api 

### generate api key for a user in rails console
```
User.last.api_key!
```