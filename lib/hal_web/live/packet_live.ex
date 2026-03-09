defmodule HalWeb.PacketLive do
  use HalWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <pre>
      <%= for packet <- @packets, do: "#{inspect(packet)}\n" %>
      </pre>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: PubSub.subscribe(Hal.PubSub, "rs485_unkn")
    {:ok, assign(socket, packets: [])}
  end

  @impl true
  def handle_info(packet, socket),
    do: {:noreply, assign(socket, packet: Enum.reverse([packet | socket.assigns.packets]))}
end
