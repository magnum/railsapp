# README

this is meant to be a rails app scaffold

assumptions:
- dbms is PostgreSQL
- in development we use different db for solid cache, cable and queue
- a default worker for jobs is run on the same machine, and jobs are not run via web process so `SOLID_QUEUE_IN_PUMA` is set to `false`
- on the same machine we can host multiple rails app using kamal
- some secrets are stored on 1password

## setup

```
bin/rails db:create
bin/rails db:prepare
```

## deploy
in `deploy.yml`  
set the `ip address` accorgingly to your server's one  
set `POSTGRES_HOST`  
set `proxy.host` 
pay ATTENTION to user a not occupied port to expose it from, ie `5435` and set db accessory like this
```
accessories:
  db:
    image: postgres:17
    host: 159.69.196.166
    port: "127.0.0.1:5435:5432"
    env:
      secret:
        - POSTGRES_PASSWORD
    directories:
      - /data/railsapp/postgresql/data:/var/lib/postgresql/data
```

setup the db accessory
```
kamal accessory boot db
kamal accessory exec db --interactive bash #test if it's up, optionally
````

setup the app for the first time
```
kamal setup
```


## Api 

### generate api key for a user in rails console
```
User.last.api_key!
```