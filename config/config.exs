# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :hal,
  buttons: %{
    lizzie: %{
      label: "Lizzie",
      order: 0,
      rf: %{on: "111000011000010100001100", off: "111000011000010100000100"}
    },
    compressor: %{
      label: "Compressor",
      order: 1,
      rf: %{on: "111000011000010100001010", off: "111000011000010100000010"}
    },
    squirt_light: %{
      label: "Squirt",
      order: 2,
      rf: %{on: "111000011000010100001110", off: "111000011000010100000110"}
    },
    garage_door: %{
      label: "Garage",
      order: 3,
      rf: %{on: "000000000000000000001111", off: "000000000000000000001110"}
    },
    tasmota_CB1E76: %{
      label: "Beer chiller",
      order: 4
    },
    bedroom: %{
      label: "Bedroom",
      order: 5,
      rf: %{on: "000000000000000000000111", off: "000000000000000000000110"}
    },
    squirt_pump: %{
      label: "Squirt pump",
      order: 6,
      rf: %{on: "111000011000010100001101", off: "111000011000010100000101"}
    },
    desk: %{
      label: "Desk lamp",
      order: 7,
      rf: %{on: "010101000101011110001110", off: "010101000101011110000110"}
    },
    internet: %{
      label: "Starlink",
      order: 8
    },
    water_pump: %{
      label: "Water pump",
      order: 9,
      rf: %{on: "111000011000010100001011", off: "111000011000010100000011"}
    },
    tasmota_E8D958_2: %{
      label: "Stair lights",
      order: 10
    },
    upstairs_lights: %{
      label: "Upstairs lights",
      order: 11
    }
  },
  generators: [context_app: :hal]

config :hal, Hal.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configures the endpoint
config :hal, HalWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: HalWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Hal.PubSub,
  live_view: [signing_salt: "tb+l0QDg"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/hal_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :tailwind,
  version: "3.0.13",
  default: [
    args: ~w[
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ],
    cd: Path.expand("../apps/hal_web/assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
