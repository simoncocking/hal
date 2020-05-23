defmodule Hal.State do
  use GenServer, restart: :permanent
  alias MQTT.Client
  alias Phoenix.PubSub

  @type t :: map()

  @spec start_link(map()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  @spec init(%{broker: String.t(), publish_interval: non_neg_integer}) :: {:ok, t()}
  def init(%{broker: broker, publish_interval: interval}) do
    {:ok, mqtt, false} = Client.connect(%{transport: {:tcp, %{host: broker}}})
    {:ok, [{"tank/#", 0}]} = Client.subscribe(mqtt, ["tank/#"])
    {:ok, [{"power/pv/#", 0}]} = Client.subscribe(mqtt, ["power/pv/#"])
    :timer.send_interval(interval, :publish)
    {:ok, %{private: %{mqtt: mqtt}}}
  end

  @spec get_state :: t()
  def get_state(), do: GenServer.call(__MODULE__, :get_state)

  @spec get_value(String.t()) :: any
  def get_value(key), do: GenServer.call(__MODULE__, key)

  @spec put_value(String.t(), any) :: :ok
  def put_value(key, value), do: GenServer.cast(__MODULE__, {key, value})

  @spec put_value(t(), String.t(), any) :: t()
  def put_value(state, key, value) do
    key
    |> String.split("/")
    |> Enum.map(&String.to_atom/1)
    |> Enum.reverse()
    |> Enum.reduce(value, &%{&1 => &2})
    |> (&merge(state, &1)).()
  end

  @spec put_values(list({String.t(), any})) :: list(:ok)
  def put_values(values) do
    for {key, value} <- values, do: put_value(key, value)
  end

  @impl true
  def handle_info({:mqtt_client, _pid, {:publish, topic, message, _}}, state) do
    {:noreply, put_value(state, topic, message), :hibernate}
  end

  def handle_info(:publish, state) do
    public = public_state(state)
    :ok = PubSub.broadcast(Hal.PubSub, "state", public)

    for {topic, value} <- flatten_map(public),
        do: Client.publish(state.private.mqtt, topic, "#{value}")

    {:noreply, state, :hibernate}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, public_state(state), state, :hibernate}

  def handle_call(key, _from, state) do
    key
    |> String.split("/")
    |> Enum.map(&String.to_atom/1)
    |> Enum.reduce(public_state(state), &Map.get(&2, &1))
    |> (&{:reply, &1, state, :hibernate}).()
  rescue
    _ -> {:reply, nil, state}
  end

  @impl true
  def handle_cast({key, value}, state), do: {:noreply, put_value(state, key, value), :hibernate}

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

  @spec flatten_map(map, String.t()) :: list(tuple)
  defp flatten_map(map, prefix \\ "") do
    Enum.reduce(map, [], fn
      {k, v}, acc when is_map(v) -> [flatten_map(v, form_key(prefix, k)) | acc]
      {k, v}, acc -> [{form_key(prefix, k), v} | acc]
    end)
    |> Enum.reverse()
    |> List.flatten()
  end

  defp form_key(prefix, key), do: String.replace_leading("#{prefix}/#{key}", "/", "")

  defp public_state(state), do: Map.delete(state, :private)
end
