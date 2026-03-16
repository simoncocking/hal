defmodule Hal.Rs485 do
  @moduledoc """
  Reads raw data from the SMA Sunny Remote Control RS485 bus and publishes
  parsed values to MQTT under the `power/` topic prefix.

  The Sunny Remote Control connects to a Sunny Island 6.0H via RS485.
  This module taps the bus mid-stream, parsing the display update packets
  sent from the Sunny Island to the remote control.

  Packet framing: 0x7E 0xFF delimiter, 115200 baud.
  """

  use Task, restart: :permanent
  require Logger
  alias Circuits.UART

  @spec start_link(String.t()) :: {:ok, pid}
  def start_link(port) do
    {:ok, pid} = UART.start_link()
    Task.start_link(__MODULE__, :init, [pid, port])
  end

  @spec init(pid, String.t()) :: no_return
  def init(pid, port) do
    Logger.info("Hal.Rs485: reading from #{port}")

    :ok =
      UART.open(pid, port,
        speed: 115_200,
        active: true,
        id: :pid,
        framing: {UART.Framing.Line, separator: <<0x7E, 0xFF>>}
      )

    recv_loop()
  end

  defp recv_loop do
    receive do
      {:circuits_uart, _pid, packet} -> packet |> parse_packet() |> Enum.each(&publish/1)
    end

    recv_loop()
  end

  # Publish parsed values to MQTT under the power/ pref
  defp publish({topic, value}),
    do: Tortoise311.publish(Hal.MQTT, "power/#{topic}", "#{value}", qos: 0)

  # Parse a display update packet from the Sunny Island.
  # Header: 0x03 0x42 0x43 0x01 0x0B <col> <row> <4 bytes padding> <payload>
  @spec parse_packet(binary) :: [{String.t(), any}]
  defp parse_packet(<<0x03, 0x42, 0x43, 0x01, 0x0B, _col, row, _pad::size(32), payload::binary>>),
    do: payload |> :binary.split(<<0x00>>) |> List.first() |> parse_payload(row)

  defp parse_packet(_packet), do: []

  # Row 1: Generator engaged status
  defp parse_payload(<<0x03, "---", 0xA4, _::binary>>, 1), do: [{"genset/engaged", false}]
  defp parse_payload(<<0x03, "----", _::binary>>, 1), do: [{"genset/engaged", true}]

  # Row 2: Generator output, charge/discharge flow, fan and genset request
  defp parse_payload(
         <<gen_kw::3-binary, "kW  ", flow, " ", charge::4-binary, "kW   ", fan::1-binary,
           gen_requested::1-binary>>,
         2
       ) do
    {charge_kw, _} = charge |> String.trim() |> Float.parse()
    {gen_kw, _} = Float.parse(gen_kw)

    [
      {"genset/output", gen_kw},
      {"genset/request", gen_requested != "o"},
      {"flow/power", if(flow == 0x01, do: -1, else: 1) * abs(charge_kw)},
      {"flow/status", if(flow == 0x01, do: "charge", else: "discharge")},
      {"load", charge_kw},
      {"battery/fan", fan != "o"}
    ]
  end

  # Row 4: Battery charge (SOC%) and time
  defp parse_payload(
         <<charge::12-binary, h::2-binary, ":", m::2-binary, ":", s::2-binary>>,
         4
       ) do
    {charge, _} = charge |> String.trim() |> Integer.parse()
    [{"battery/charge", charge}, {"time", "#{h}:#{m}:#{s}"}]
  end

  defp parse_payload(_payload, _row), do: []
end
