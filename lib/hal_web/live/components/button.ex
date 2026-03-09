defmodule HalWeb.Components.Button do
  use HalWeb, :component

  def toggle(assigns) do
    ~H"""
    <div
      class={"flex rounded-md bg-zinc-900 border border-zinc-800 p-4 items-center justify-center"}
      phx-click="click"
      phx-value-id={@id}
    >
      <div class="flex flex-col items-center justify-around w-full h-full">
        <p class="text-sm"><%= @label %></p>
        <div class={"w-1/2 h-2 border rounded-full bg-gradient-to-b #{color(@state)} transition duration-200 ease-in-out"}></div>
      </div>
    </div>
    """
  end

  defp color(true), do: "from-lime-800 via-lime-900 to-lime-700 border-lime-800"

  defp color(_),
    do:
      "from-zinc-800 via-zinc-900 to-zinc-700 border-t-zinc-800 border-l-zinc-800 border-b-zinc-700 border-r-zinc-700"
end
