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
            '{% set manifold = states("sensor.shw_manifold_average") | float(0) %}',
            '{% set tank_upper = states("sensor.shw_tank_upper_average") | float(0) %}',
            '{% set tank_lower = states("sensor.shw_tank_lower_average") | float(0) %}',
            '{% set pump = states("switch.tasmota_4") %}',
            '{{ {"manifold": manifold, "tank_upper": tank_upper, "tank_lower": tank_lower, "pump": pump} | to_json }}',
        )
    })
);

unless ($res->is_success) {
    print("☀ err | size=10 color=red\n");
    exit;
}

my $d = decode_json($res->content);

printf("M%.1fº T%.1fº | size=10 color=%s\n",
    $d->{manifold},
    $d->{tank_upper},
    $d->{pump} eq "on" ? "white" : "#aaaaaa"
);
print("---\n");
printf("Manifold: %0.1fºC | size=14 href=http://atlas.local:3000/d/hal-power-system\n", $d->{manifold});
printf("Upper: %0.1fºC | size=14 href=http://atlas.local:3000/d/hal-power-system\n", $d->{tank_upper});
printf("Lower: %0.1fºC | size=14 href=http://atlas.local:3000/d/hal-power-system\n", $d->{tank_lower});
