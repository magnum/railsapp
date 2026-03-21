# railsapp 
This template is intended for use as a starting point for new Rails applications.

## Assumptions and Notes
- changes to `.kamal/secrets` and `config/deploy.yml` do no require to be committed
- PostgreSQL accessory is initialized ONLY if its directory is empty; 5432 port is reachable from web container, but it's to be exposed on different ports on the host eg. 5433 etc.
- we use different dbs for solid cache, cable and queue
- a default worker is run on the same machine, jobs are not run via web process, `SOLID_QUEUE_IN_PUMA` is set to `false`
- a `data` directoy will be use to persist postgres data and attachments
- some secrets are stored on 1password


## Env variables
The default name is `railsapp`, find/replace it with the current one; pay attention to do i manually in `config/application.rb` and `config/settings.yml`.

Set `POSTGRES_PASSWORD` in `.kamal/secrets` and eventually add any other secret you want to use during deploy.

In `deploy.yml` set the `ip address` and  `proxy.host`  accorgingly to yours; 



## Setup
Create a "data" directory on remote server, login via ssh and execute something like
```
dir=/data/railsapp/postgresql/data/ ; rm -fr $dir ; mkdir -p $dir
```

In `deploy.yml` verify **accessory** parameters: Supposedly, you shouldn't change anything except for the app name prefix in `POSTGRES_DB`, the `ip address` and the `port`
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


## Api 

### generate api key for a user in rails console
```
User.last.api_key!
```