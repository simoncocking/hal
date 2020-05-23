SHELL := bash

release:
	SECRET_KEY_BASE=$$(mix phx.gen.secret)
	mix deps.get --only prod
	mix local.rebar --force
	MIX_ENV=prod SECRET_KEY_BASE=$${SECRET_KEY_BASE} mix compile
	npm install --prefix ./assets
	npm run deploy --prefix ./assets
	mix phx.digest
	MIX_ENV=prod SECRET_KEY_BASE=$${SECRET_KEY_BASE} mix release

install:
	cp -r _build/prod/rel/hal /opt
