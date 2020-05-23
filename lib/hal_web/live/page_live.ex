defmodule HalWeb.PageLive do
  use HalWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def render(assigns) do
    ~L"""
    <div>
    <p>Battery: <%= @state.power.battery.charge %>%</p>
    <p>Power: <%= @state.power.load %> kW</p>
    <p>Header: <%= @state.tank.header.percent %>%</p>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: PubSub.subscribe(Hal.PubSub, "state")
    {:ok, assign(socket, state: Hal.State.get_state())}
  end

  @impl true
  def handle_info(state, socket), do: {:noreply, assign(socket, state: state)}
end
