SHELL := bash

.EXPORT_ALL_VARIABLES:
	MIX_ENV = prod
	NODE_ENV = production
	SECRET_KEY_BASE = $$(mix phx.gen.secret)

release:
	mix deps.get --only prod
	mix local.rebar --force
	mix compile
	npm install --prefix ./assets
	npm run deploy --prefix ./assets
	mix phx.digest
	mix release

install:
	cp -r _build/prod/rel/hal /opt
