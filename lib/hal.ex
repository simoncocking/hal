defmodule Hal do
  @moduledoc """
  Hal - RS485 data acquisition for SMA Sunny Island power system.

  Taps the RS485 bus between a Sunny Island 6.0H and its Sunny Remote Control,
  parses display update packets, and publishes real-time power system data to MQTT.

  Published MQTT topics (under `power/` prefix):
    - power/genset/engaged    (boolean)
    - power/genset/output     (kW)
    - power/genset/request    (boolean)
    - power/flow/power        (kW, negative = charging)
    - power/flow/status       ("charge" | "discharge")
    - power/load              (kW)
    - power/battery/fan       (boolean)
    - power/battery/charge    (integer, SOC%)
    - power/time              (HH:MM:SS)
  """
end
