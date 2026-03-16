#!/usr/bin/env perl
use JSON;
use LWP::UserAgent;

# Home Assistant API configuration
my $ha_url = "http://atlas.local:8123";
my $ha_token = $ENV{HA_TOKEN} // die "Set HA_TOKEN environment variable\n";

my $ua = LWP::UserAgent->new(timeout => 5);
my $res = $ua->post(
    "$ha_url/api/template",
    'Authorization' => "Bearer $ha_token",
    'Content-Type'  => 'application/json',
    Content => encode_json({
        template => join("\n",
            '{% set soc = states("sensor.battery_soc") | float(0) %}',
            '{% set flow = states("sensor.charge_discharge_power") | float(0) %}',
            '{% set pv = states("sensor.solar_pv_power") | float(0) %}',
            '{% set load = states("sensor.true_house_load") | float(0) %}',
            '{% set genset = states("sensor.generator_output") | float(0) %}',
            '{% set today = states("sensor.pv_energy_today") | float(0) %}',
            '{% set volts = states("sensor.grid_voltage") | float(0) %}',
            '{% set freq = states("sensor.grid_frequency") | float(0) %}',
            '{{ {"soc": soc, "flow": flow, "pv": pv, "load": load, "genset": genset, "today": today, "volts": volts, "freq": freq} | to_json }}',
        )
    })
);

unless ($res->is_success) {
    print("⚡ err | size=10 color=red\n");
    exit;
}

my $d = decode_json($res->content);

printf("%d%% %+0.1fkW | size=10\n",
    $d->{soc},
    - $d->{flow}
);
print("---\n");
printf("PV: %0.1fkW | size=14 href=http://atlas.local:3000/d/hal-power-system\n", $d->{pv} / 1000);
printf("Load: %0.1fkW | size=14 href=http://atlas.local:3000/d/hal-power-system\n", $d->{load});
printf("Grid: %0.1fV @ %0.1fHz | size=14 href=http://atlas.local:3000/d/hal-power-system\n", $d->{volts}, $d->{freq});
printf("Genset: %0.1fkW | size=14 href=http://atlas.local:3000/d/hal-power-system\n", $d->{genset});
printf("Today: %0.1fkWh | size=14 href=http://atlas.local:3000/d/hal-power-system\n", $d->{today});
