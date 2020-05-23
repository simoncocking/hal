defmodule Hal.Rs485 do
  use Task, restart: :permanent
  require Logger
  alias Circuits.UART
  alias Hal.State

  @spec start_link(String.t()) :: {:ok, pid}
  def start_link(port) do
    {:ok, pid} = UART.start_link()
    Task.start_link(__MODULE__, :init, [pid, port])
  end

  @spec init(atom | pid | {atom, any} | {:via, atom, any}, binary) :: no_return
  def init(pid, port) do
    Logger.info("Reading from #{port}")
    :ok = UART.open(pid, port, speed: 115_200, active: true)
    :ok = UART.configure(pid, id: :pid, framing: {UART.Framing.Line, separator: <<0x7E, 0xFF>>})
    recv_packet()
  end

  @spec recv_packet :: no_return
  def recv_packet do
    receive do
      {:circuits_uart, _pid, packet} -> packet |> parse_packet() |> put_state()
    end

    recv_packet()
  end

  @spec parse_packet(binary) :: list(tuple)
  defp parse_packet(<<0x03, 0x42, 0x43, 0x01, 0x0B, _col, row, _pad::size(32), payload::binary>>) do
    payload
    |> :binary.split(<<0x00>>)
    |> List.first()
    |> parse_payload(row)
  end

  defp parse_packet(packet) do
    Logger.info("Unrecognised packet: #{inspect(packet)}")
    []
  end

  @spec parse_payload(binary, byte) :: list(tuple())
  defp parse_payload(<<0x03, "---", 0xA4, _::binary>>, 1), do: [{"genset/engaged", false}]
  defp parse_payload(<<0x03, "----", _::binary>>, 1), do: [{"genset/engaged", true}]

  defp parse_payload(
         <<gen_kw::3-binary, "kW  ", flow, " ", charge::4-binary, "kW   ", fan::1-binary,
           gen_requested::1-binary>>,
         2
       ) do
    {charge, _} =
      charge
      |> String.trim()
      |> Float.parse()

    {gen_kw, _} = Float.parse(gen_kw)

    [
      {"genset/output", gen_kw},
      {"genset/request", gen_requested != "o"},
      {"flow/power", if(flow == 0x01, do: -charge, else: charge)},
      {"load", charge},
      {"battery/fan", fan != "o"}
    ]
  end

  defp parse_payload(
         <<charge::12-binary, h::2-binary, ":", m::2-binary, ":", s::2-binary>>,
         4
       ) do
    {charge, _} =
      charge
      |> String.trim()
      |> Integer.parse()

    [
      {"battery/charge", charge},
      {"time", "#{h}:#{m}:#{s}"}
    ]
  end

  defp parse_payload(_payload, _row), do: []

  @spec put_state(list({String.t(), any})) :: :ok
  defp put_state([]), do: :ok

  defp put_state(tuples) do
    tuples
    |> Enum.map(fn {topic, val} -> {"power/#{topic}", val} end)
    |> State.put_values()
  end
end
