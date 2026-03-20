# README

this is meant to be a rails app scaffold

## setup

```
bin/rails db:create
bin/rails db:prepare
```


## Api 

### generate api key for a user in rails console
```
User.last.api_key!
```