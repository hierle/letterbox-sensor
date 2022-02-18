#!/bin/perl -w -T
#
# TheThingsNetwork HTTP letter box sensor RRD extension
#
# (P) & (C) 2019-2022 Dr. Peter Bieringer <pb@bieringer.de>
#
# License: GPLv3
#
# Authors:  Dr. Peter Bieringer (bie)
#
# Supported Query String parameters
#   - rrd=[on|off]
#   - rrdRange=[day|week|month|year]
#
# Required configuration:
#   datadir=<path>
#
# Optional configuration:
#   rrd.debug=1
#
# Changelog:
# 20191110/bie: initial version
# 20191111/bie: add support for snr/rssi, change RRD font render mode
# 20191112/bie: rework button implementation
# 20191113/bie: implement rrdRange support, adjust rrd database
# 20191114/bie: change colors of rrdRange buttons, use different xgrid for mobile devices
# 20191115/bie: remove border of RRD to get it smaller
# 20191120/bie: insert dev_id into title
# 20191214/bie: add "de" translation
# 20200213/bie: improve layout for Mobile browers, fix RRD database definition to cover 1y instead of 12d
# 20211030/bie: add support for v3 API
# 20220218/bie: align config options, do not die in case of RRD updates happen too often

use strict;
use warnings;
use RRDs;
use GD;
use JSON;
use Date::Parse;
use MIME::Base64;
use utf8;

## globals
our %hooks;
our %config;
our %translations;
our $mobile;

## prototyping
sub rrd_init();
sub rrd_init_device($);
sub rrd_get_graphics($$);
sub rrd_store_data($$$);
sub rrd_html_actions($);


## hooks
$hooks{'rrd'}->{'init'} = \&rrd_init;
$hooks{'rrd'}->{'init_device'} = \&rrd_init_device;
$hooks{'rrd'}->{'get_graphics'} = \&rrd_get_graphics;
$hooks{'rrd'}->{'store_data'} = \&rrd_store_data;
$hooks{'rrd'}->{'store_data'} = \&rrd_store_data;
$hooks{'rrd'}->{'html_actions'} = \&rrd_html_actions;

## translations
$translations{'day'}->{'de'} = "Tag";
$translations{'week'}->{'de'} = "Woche";
$translations{'month'}->{'de'} = "Monat";
$translations{'year'}->{'de'} = "Jahr";
$translations{'month-of-year'}->{'de'} = "Monat-vom-Jahr";
$translations{'week-of-year'}->{'de'} = "Woche-vom-Jahr";
$translations{'day-of-month'}->{'de'} = "Tag-vom-Monat";
$translations{'hour-of-day'}->{'de'} = "Stunde-vom-Tag";


## statistics
my @rrd = ("sensor", "voltage", "tempC", "rssi", "snr"); # order must match RRD create definition


## sizes
my %rrd_config = (
  'sensor' => {
      'format' => '%d',
      'color' => '#6FEF00'
  },
  'tempC' => {
      'format' => '%d',
      'color' => '#0000F0'
  },
  'voltage' => {
      'format' => '%5.3f',
      'color' => '#F000F0'
  },
  'rssi' => {
      'format' => '%5.3f',
      'color' => '#00F0F0'
  },
  'snr' => {
      'format' => '%5.3f',
      'color' => '#0080F0'
  }
);


## ranges
my %rrd_range = (
  'day' => {
      'label' => 'hour-of-day',
      'start' => 'end-24h',
      'xgrid' => "HOUR:1:HOUR:6:HOUR:2:0:%H",
      'xgrid_mobile' => "HOUR:1:HOUR:6:HOUR:4:0:%H"
  },
  'week' => {
      'label' => 'day-of-month',
      'start' => 'end-7d',
      'xgrid' => "HOUR:6:DAY:1:DAY:1:86400:%d",
      'xgrid_mobile' => "HOUR:6:DAY:1:DAY:1:86400:%d"
  },
  'month' => {
      'label' => 'week-of-year',
      'start' => 'end-1M',
      'xgrid' => "DAY:1:WEEK:1:DAY:7:0:CW %V",
      'xgrid_mobile' => "DAY:1:WEEK:1:DAY:7:0:CW %V"
  },
  'year' => {
      'label' => 'month-of-year',
      'start' => 'end-1y',
      'xgrid' => "MONTH:1:MONTH:1:MONTH:1:0:%m",
      'xgrid_mobile' => "MONTH:1:MONTH:1:MONTH:2:0:%m"
  }
);


### create new RRD
sub rrd_create($) {
  my $file = $_[0];

	logging("Create  new RRD: " . $file) if defined $config{'rrd.debug'};

  # 86400 s * 365 d / 300 s = 105120 measurements
  RRDs::create($file,
    "--step=300",
    "--start=1571200000",
    "DS:sensor:GAUGE:3600:0:U",
    "DS:voltage:GAUGE:3600:0:4",
    "DS:tempC:GAUGE:3600:-50:150",
    "DS:rssi:GAUGE:3600:-300:0",
    "DS:snr:GAUGE:3600:-99:99",
    "RRA:AVERAGE:0.5:1:4800",
    "RRA:MIN:0.5:1:4800",
    "RRA:MAX:0.5:1:4800",
    "RRA:AVERAGE:0.5:10:24000",
    "RRA:MIN:0.5:5:24000",
    "RRA:MAX:0.5:5:24000",
    "RRA:AVERAGE:0.5:10:48000",
    "RRA:MIN:0.5:10:48000",
    "RRA:MAX:0.5:10:48000",
    "RRA:AVERAGE:0.5:1000:480000",
    "RRA:MIN:0.5:1000:480000",
    "RRA:MAX:0.5:1000:480000"
  );

  my $ERR=RRDs::error;
  die "ERROR : RRD::create problem " . $file .": $ERR\n" if $ERR;

	logging("Created new RRD: " . $file) if defined $config{'rrd.debug'};
};


## update RRD
sub rrd_update($$$) {
  my $file = $_[0];
  my $timestamp = $_[1];
  my $values_hp = $_[2];

  my @data;

  push @data, $timestamp;

  for my $rrd_entry (@rrd) {
    push @data, $$values_hp{$rrd_entry};
  };

  my $rrd = join(":", @data);

	logging("Update  RRD: " . $file . " with: " . $rrd) if defined $config{'rrd.debug'};

  RRDs::update($file, $rrd);
  my $ERR=RRDs::error;
  if ($ERR) {
    if ($ERR =~ /minimum one second step/o) {
      # only a transient issue
      logging("Updated RRD: not possible: $ERR:" . $file) if defined $config{'rrd.debug'};
    } else {
      die "ERROR : RRD::update problem " . $file .": $ERR\n" if $ERR;
    };
  } else {
	  logging("Updated RRD: " . $file) if defined $config{'rrd.debug'};
  };
};


############
## init module
############
sub rrd_init() {
  if (defined $config{'rrd.debug'} && $config{'rrd.debug'} eq "0") {
    undef $config{'rrd.debug'};
  };

  logging("rrd/init: called") if defined $config{'rrd.debug'};
};

## fill historical data of device
sub rrd_fill_device($$) {
  my $dev_id = $_[0];
  my $file = $_[1];

  my @logfiles;
  my %values;

  # read directory
  my $dir = $config{'datadir'};
  opendir (DIR, $dir) or die $!;
  while (my $entry = readdir(DIR)) {
    next unless (-f "$dir/$entry");
    next unless ($entry =~ /^ttn\.$dev_id\.[0-9]+\.raw.log$/);
    logging("DEBUG : logfile found: " . $entry) if defined $config{'rrd.debug'};
    push @logfiles, $entry;
  };

  # get data from logfiles
  foreach my $logfile (sort @logfiles) {
    open LOGF, '<', $dir . "/" . $logfile or die $!;
		while (<LOGF>) {
			my $line = $_;
			chomp($line);
			$line =~ s/^([^{]+) //g;
			my $timeReceived = $1;

      my $timeReceived_ut = str2time($timeReceived);
      if (! defined $timeReceived_ut) {
        die("cannot parse time: " . $timeReceived);
      };

			my $content = eval{ decode_json($line)};
			if ($@) {
				die("major problem found", "", "line not in JSON format");
			};

      my $payload;
      $payload = $content->{'uplink_message'}->{'decoded_payload'}; # v3 (default)
      $payload = $content->{'payload_fields'} if (! defined $payload); # v2 (fallback)

      $values{$timeReceived_ut}->{'voltage'} = $payload->{'voltage'};
      $values{$timeReceived_ut}->{'sensor'} = $payload->{'sensor'};
      $values{$timeReceived_ut}->{'tempC'} = $payload->{'tempC'};

      my $metadata;
      $metadata = $content->{'uplink_message'}->{'rx_metadata'}[0]; # v3 (default)
      $metadata = $content->{'metadata'}->{'gateways'}[0] if (! defined $metadata); # v2 (fallback)

      $values{$timeReceived_ut}->{'rssi'} = $metadata->{'rssi'};
      $values{$timeReceived_ut}->{'snr'} = $metadata->{'snr'};
    };
  };

  # loop
  for my $time_ut (sort { $a <=> $b } keys %values) {
    rrd_update($file, $time_ut, $values{$time_ut});
  };
};


## init device
sub rrd_init_device($) {
  my $dev_id = $_[0];

  logging("Called: init_device with dev_id=" . $dev_id) if defined $config{'rrd.debug'};

  my $file = $config{'datadir'} . "/ttn." . $dev_id . ".rrd";

  logging("DEBUG : check for file: " . $file) if defined $config{'rrd.debug'};
  if (! -e $file) {
    logging("DEBUG : file missing, create now: " . $file) if defined $config{'rrd.debug'};
    rrd_create($file);
    rrd_fill_device($dev_id, $file);
  } else {
    logging("DEBUG : file already existing: " . $file) if defined $config{'rrd.debug'};
  };
};


## store data
sub rrd_store_data($$$) {
  my $dev_id = $_[0];
  my $timeReceived = $_[1];
  my $content = $_[2];

  my %values;

  logging("rrd/store_data: called") if defined $config{'rrd.debug'};

  my $file = $config{'datadir'} . "/ttn." . $dev_id . ".rrd";

  my $timeReceived_ut = str2time($timeReceived);

  my $payload;
  $payload = $content->{'uplink_message'}->{'decoded_payload'}; # v3 (default)
  $payload = $content->{'payload_fields'} if (! defined $payload); # v2 (fallback)

  $values{'voltage'} = $payload->{'voltage'};
  $values{'sensor'} = $payload->{'sensor'};
  $values{'tempC'} = $payload->{'tempC'};

  my $metadata;
  $metadata = $content->{'uplink_message'}->{'rx_metadata'}[0]; # v3 (default)
  $metadata = $content->{'metadata'}->{'gateways'}[0] if (! defined $metadata); # v2 (fallback)

  $values{'rssi'} = $metadata->{'rssi'};
  $values{'snr'} = $metadata->{'snr'};

  rrd_update($file, $timeReceived_ut, \%values);
};


## get graphics
sub rrd_get_graphics($$) {
  my $dev_id = $_[0];
  my $querystring_hp = $_[1];

  my %html;

  logging("Called: get_graphics with dev_id=" . $dev_id) if defined $config{'rrd.debug'};

  my $file = $config{'datadir'} . "/ttn." . $dev_id . ".rrd";

  my $rrdRange = $querystring_hp->{'rrdRange'} || "day";

  logging("DEBUG : check for file: " . $file) if defined $config{'rrd.debug'};
  if (! -e $file) {
    logging("DEBUG : file missing, skip: " . $file) if defined $config{'rrd.debug'};
  } else {
    for my $type (@rrd) {
      logging("DEBUG : file existing, export graphics: " . $file . " type:" . $type) if defined $config{'rrd.debug'};

      my $output = $config{'datadir'} . "/ttn." . $dev_id . "." . $type . ".png";

      my $color = $rrd_config{$type}->{'color'};

      my $width = 260;
      my $height = 80;
      my $start = $rrd_range{$rrdRange}->{'start'};
      my $xgrid = $rrd_range{$rrdRange}->{'xgrid'};
      my $title = $rrd_range{$rrdRange}->{'label'};
      my $label = $type;

      if ($mobile == 1) {
        $width = 140;
        $height = 50;
        $xgrid = $rrd_range{$rrdRange}->{'xgrid_mobile'};
      };

      my $font_title = "10:Courier";
      $font_title = "8:Helvetica" if ($mobile == 1);

      if ($type eq "sensor") {
        RRDs::graph($output,
          "--title=" . $dev_id . ": " . translate($title),
          "--vertical-label=" . $label,
          "--watermark=" . strftime("%Y-%m-%d %H:%M:%S UTC", gmtime(time)),
          "--no-legend",
          "--end=now",
          "--start=" . $start,
          "--width=" . $width,
          "--height=" . $height,
          "--x-grid=" . $xgrid,
          "--border=0",
          "--font-render-mode=mono",
          "--font=TITLE:" . $font_title,
          "--logarithmic",
          "--units=si",
          "DEF:" . $type . "=" . $file . ":" . $type . ":AVERAGE",
          "LINE1:" . $type . $color . ":" . $type,
        );
      } else {
        RRDs::graph($output,
          "--title=" . $dev_id . ": " . translate($title),
          "--vertical-label=" . $label,
          "--watermark=" . strftime("%Y-%m-%d %H:%M:%S UTC", gmtime(time)),
          "--no-legend",
          "--end=now",
          "--start=" . $start,
          "--width=" . $width,
          "--height=" . $height,
          "--x-grid=" . $xgrid,
          "--border=0",
          "--font-render-mode=mono",
          "--font=TITLE:" . $font_title,
          "DEF:" . $type . "=" . $file . ":" . $type . ":AVERAGE",
          "LINE1:" . $type . $color . ":" . $type
        );

# not supported on EL7
#          "--left-axis-format=\"" . $rrd_config{$type}->{'format'} . "\"",
#          "--left-axis-format=\"" . $rrd_config{$type}->{'format'} . "\"",
#          "--left-axis-formatter=numeric",
#          "--left-axis-formatter=numeric",
      };

      my $ERR=RRDs::error;
      die "ERROR : RRD::graph problem " . $file . ": $ERR\n" if $ERR;

      my $image = GD::Image->new($output);
      die "ERROR : GD::Image->new problem " . $output . "\n" if (! defined $image);

      my $png_base64 = encode_base64($image->png(9), "");
      $html{"RRD:" . $type} = '<img alt="' . $type . '" src="data:image/png;base64,' . $png_base64 . '">';

      logging("DEBUG : exported graphics: " . $file . " type:" . $type . " size=" . length($png_base64)) if defined $config{'rrd.debug'};
    };
  };
  return %html;
};


## HTML actions
sub rrd_html_actions($) {
  my $querystring_hp = $_[0];
  my $button_size;

  # default
  if (! defined $querystring_hp->{'rrdRange'} || $querystring_hp->{'rrdRange'} !~ /^(day|week|month|year)$/o) {
    $querystring_hp->{'rrdRange'} = "day";
  };

  if (! defined $querystring_hp->{'rrd'} || $querystring_hp->{'rrd'} !~ /^(on|off)$/o) {
    $querystring_hp->{'rrd'} = "off";
  };

  my $querystring = { %$querystring_hp }; # copy for form

  my $toggle_color;

  my $response = "";

  $response .= "  <td>\n";

  if ($querystring_hp->{'rrd'} eq "off") {
    $querystring->{'rrd'} = "on";
    $toggle_color = "#E0E0E0";
  } else {
    $querystring->{'rrd'} = "off";
    $toggle_color = "#00E000";
  };

  $response .= "   <form method=\"get\">\n";
  $button_size = "width:100px;height:40px;";
  $button_size = "width:50px;height:40px;" if ($mobile == 1);
  $response .= "    <input type=\"submit\" value=\"RRD\" style=\"background-color:" . $toggle_color . ";" . $button_size . "\">\n";
  for my $key (sort keys %$querystring) {
    $response .= "    <input type=\"text\" name=\"" . $key . "\" value=\"" . $querystring->{$key} . "\" hidden>\n";
  };
  $response .= "   </form>\n";
  $response .= "  </td>\n";

  # timerange buttons
  if ($querystring_hp->{'rrd'} eq "on") {
    $querystring = { %$querystring_hp }; # copy for form

    for my $rrdRange ("day", "week", "month", "year") {
      if ($querystring_hp->{'rrdRange'} eq $rrdRange) {
        $toggle_color = "#00BFFF";
      } else {
        $toggle_color = "#E0E0E0";
      };

      $querystring->{'rrdRange'} = $rrdRange;

      $response .= "  <td>\n";
      $response .= "   <form method=\"get\">\n";
      $response .= "    <input type=\"submit\" value=\"" . translate($rrdRange) . "\" style=\"background-color:" . $toggle_color . ";width:60px;height:40px;\">\n";
      for my $key (sort keys %$querystring) {
        $response .= " <input type=\"text\" name=\"" . $key . "\" value=\"" . $querystring->{$key} . "\" hidden>\n";
      };
      $response .= "   </form>\n";

      $response .= "  </td>\n";
    };
  };

  return $response;
};

# vim: set noai ts=2 sw=2 et:
