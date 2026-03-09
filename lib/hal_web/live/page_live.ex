defmodule HalWeb.PageLive do
  use HalWeb, :live_view

  alias Hal.State
  alias HalWeb.Components.Button
  alias Phoenix.PubSub

  @impl true
  def render(assigns) do
    ~H"""
    <main class="w-screen h-screen text-white bg-black">
      <div class="flex flex-row space-x-2">
        <p>Power: <%= String.to_float(@state.power.pv.ac_watts) / 1000 %> kW</p>
        <p>Header: <%= @state.tank.header.percent %>%</p>
      </div>
      <div class="flex flex-col grow">
        <div class="grid h-full grid-cols-3 gap-1">
          <%= for button <- @buttons do %>
            <Button.toggle id={button.id} state={button[:state]} label={button.label} />
          <% end %>
        </div>
      </div>
    </main>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: PubSub.subscribe(Hal.PubSub, "state")
    {:ok, socket |> assign(state: State.get_state()) |> assign_buttons()}
  end

  defp assign_buttons(%{assigns: %{state: %{buttons: buttons}}} = socket) do
    assign(socket,
      buttons:
        buttons
        |> Enum.map(fn {id, button} -> Map.put(button, :id, id) end)
        |> Enum.sort_by(& &1.order)
    )
  end

  @impl true
  def handle_event("click", %{"id" => id}, %{assigns: %{state: %{buttons: buttons}}} = socket) do
    id = String.to_existing_atom(id)
    State.put_value({"buttons/#{id}/state", !buttons[id][:state]}, publish: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info(state, socket),
    do: {:noreply, socket |> assign(state: state) |> assign_buttons()}
end
