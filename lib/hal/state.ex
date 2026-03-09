defmodule Hal.State do
  use GenServer, restart: :permanent
  alias __MODULE__
  alias MQTT.Client
  alias Phoenix.PubSub

  @buttons Application.compile_env!(:hal, :buttons)
  defp buttons, do: @buttons

  @type t :: map()
  @type value :: {binary(), any()}

  @spec start_link(map()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(args) do
    GenServer.start_link(State, args, name: State)
  end

  @impl true
  @spec init(%{broker: String.t()}) :: {:ok, t()}
  def init(%{broker: broker}) do
    {:ok, mqtt, false} = Client.connect(%{transport: {:tcp, %{host: broker}}})
    {:ok, _topics} = Client.subscribe(mqtt, ["tank/#", "power/pv/#"])
    {:ok, %{buttons: buttons(), private: %{mqtt: mqtt}}}
  end

  @spec get_state :: t()
  def get_state(), do: GenServer.call(State, :get_state)

  @spec get_value(String.t()) :: any
  def get_value(key), do: GenServer.call(State, key)

  @spec put_value(
          value :: value() | list(value()),
          opts :: keyword()
        ) :: :ok
  def put_value(value, opts \\ []), do: GenServer.cast(State, {:put, List.wrap(value), opts})

  @spec put_value(
          state :: t(),
          value :: value(),
          opts :: keyword()
        ) :: t()
  defp put_value(state, {key, value}, opts) do
    key
    |> String.split("/")
    |> Enum.map(&String.to_atom/1)
    |> Enum.reverse()
    |> Enum.reduce(value, &%{&1 => &2})
    |> then(&merge(state, &1))
    |> tap(&publish(&1, {key, value}, opts[:publish]))
    |> tap(&PubSub.broadcast(Hal.PubSub, "state", public_state(&1)))
  end

  defp publish(state, {key, value}, true) do
    Client.publish(state.private.mqtt, key, "#{value}")
  end

  defp publish(_state, _value, _publish), do: :ok

  @impl true
  def handle_info({:mqtt_client, _pid, {:publish, topic, message, _}}, state) do
    {:noreply, put_value(state, {topic, message}, publish: false), :hibernate}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, public_state(state), state, :hibernate}

  def handle_call(key, _from, state) do
    key
    |> String.split("/")
    |> Enum.map(&String.to_atom/1)
    |> Enum.reduce(public_state(state), &Map.get(&2, &1))
    |> then(&{:reply, &1, state, :hibernate})
  rescue
    _ -> {:reply, nil, state}
  end

  @impl true
  def handle_cast({:put, values, opts}, state),
    do: {:noreply, Enum.reduce(values, state, &put_value(&2, &1, opts)), :hibernate}

  @spec merge(map, map) :: map
  defp merge(map1, map2) do
    Map.merge(map1, map2, fn
      _k, v1, v2 when is_map(v1) and is_map(v2) ->
        merge(v1, v2)

      k, v1, v2 when is_map(v1) ->
        Map.put(v1, k, v2)

      k, v1, v2 when is_map(v2) ->
        Map.put(v2, k, v1)

      _k, _v1, v2 ->
        v2
    end)
  end

  defp public_state(state), do: Map.delete(state, :private)
end
