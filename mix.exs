defmodule Hal.MixProject do
  use Mix.Project

  def project do
    [
      app: :hal,
      version: "0.2.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Hal.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:circuits_uart, "~> 1.4"},
      {:jason, "~> 1.2"},
      {:tortoise311, "~> 0.12"}
    ]
  end
end
