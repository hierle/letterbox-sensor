#!/bin/perl -w -T
#
# TheThingsNetwork HTTP letter box sensor RRD extension
#
# (P) & (C) 2019-2019 Dr. Peter Bieringer <pb@bieringer.de>
#
# License: GPLv3
#
# Authors:  Dr. Peter Bieringer (bie)
#
# 20191110/bie: initial version
# 20191111/bie: add support for snr/rssi, change RRD font render mode

use strict;
use warnings;
use RRDs;
use GD;
use JSON;
use Date::Parse;
use MIME::Base64;

## globals
our %hooks;
our %config;


## prototyping
sub rrd_init();
sub rrd_init_device($);
sub rrd_get_graphics($);
sub rrd_store_data($$$);


## hooks
$hooks{'rrd'}->{'init'} = \&rrd_init;
$hooks{'rrd'}->{'init_device'} = \&rrd_init_device;
$hooks{'rrd'}->{'get_graphics'} = \&rrd_get_graphics;
$hooks{'rrd'}->{'store_data'} = \&rrd_store_data;


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


### create new RRD
sub rrd_create($) {
  my $file = $_[0];

	logging("Create  new RRD: " . $file) if defined $config{'rrd'}->{'debug'};

  RRDs::create($file,
    "--step=300",
    "--start=1571200000",
    "DS:sensor:GAUGE:3600:0:U",
    "DS:voltage:GAUGE:3600:0:4",
    "DS:tempC:GAUGE:3600:-50:150",
    "DS:rssi:GAUGE:3600:-300:0",
    "DS:snr:GAUGE:3600:-99:99",
    "RRA:AVERAGE:0.5:1:4800",
    "RRA:MIN:0.5:12:4800",
    "RRA:MAX:0.5:12:4800"
  );

  my $ERR=RRDs::error;
  die "ERROR : RRD::create problem " . $file .": $ERR\n" if $ERR;

	logging("Created new RRD: " . $file) if defined $config{'rrd'}->{'debug'};
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

	logging("Update  RRD: " . $file . " with: " . $rrd) if defined $config{'rrd'}->{'debug'};

  RRDs::update($file, $rrd);
  my $ERR=RRDs::error;
  die "ERROR : RRD::update problem " . $file .": $ERR\n" if $ERR;

	logging("Updated RRD: " . $file) if defined $config{'rrd'}->{'debug'};
};


############
## init module
############
sub rrd_init() {
  if (defined $ENV{'TTN_LETTERBOX_DEBUG_RRD'}) {
    $config{'rrd'}->{'debug'} = 1;
  };

  logging("rrd/init: called") if defined $config{'rrd'}->{'debug'};
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
    logging("DEBUG : logfile found: " . $entry) if defined $config{'rrd'}->{'debug'};
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

      $values{$timeReceived_ut}->{'voltage'} = $content->{'payload_fields'}->{'voltage'};
      $values{$timeReceived_ut}->{'sensor'} = $content->{'payload_fields'}->{'sensor'};
      $values{$timeReceived_ut}->{'tempC'} = $content->{'payload_fields'}->{'tempC'};
      $values{$timeReceived_ut}->{'rssi'} = $content->{'metadata'}->{'gateways'}[0]->{'rssi'};
      $values{$timeReceived_ut}->{'snr'} = $content->{'metadata'}->{'gateways'}[0]->{'snr'};
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

  logging("Called: init_device with dev_id=" . $dev_id) if defined $config{'rrd'}->{'debug'};

  my $file = $config{'datadir'} . "/ttn." . $dev_id . ".rrd";

  logging("DEBUG : check for file: " . $file) if defined $config{'rrd'}->{'debug'};
  if (! -e $file) {
    logging("DEBUG : file missing, create now: " . $file) if defined $config{'rrd'}->{'debug'};
    rrd_create($file);
    rrd_fill_device($dev_id, $file);
  } else {
    logging("DEBUG : file already existing: " . $file) if defined $config{'rrd'}->{'debug'};
  };
};


## store data
sub rrd_store_data($$$) {
  my $dev_id = $_[0];
  my $timeReceived = $_[1];
  my $content = $_[2];

  my %values;

  logging("rrd/store_data: called") if defined $config{'rrd'}->{'debug'};

  my $file = $config{'datadir'} . "/ttn." . $dev_id . ".rrd";

  my $timeReceived_ut = str2time($timeReceived);

  $values{'voltage'} = $content->{'payload_fields'}->{'voltage'};
  $values{'sensor'} = $content->{'payload_fields'}->{'sensor'};
  $values{'tempC'} = $content->{'payload_fields'}->{'tempC'};
  $values{$timeReceived_ut}->{'rssi'} = $content->{'metadata'}->{'gateways'}[0]->{'rssi'};
  $values{$timeReceived_ut}->{'snr'} = $content->{'metadata'}->{'gateways'}[0]->{'snr'};

  rrd_update($file, $timeReceived_ut, \%values);
};

## get graphics
sub rrd_get_graphics($) {
  my $dev_id = $_[0];

  my %html;

  logging("Called: get_graphics with dev_id=" . $dev_id) if defined $config{'rrd'}->{'debug'};

  my $file = $config{'datadir'} . "/ttn." . $dev_id . ".rrd";

  logging("DEBUG : check for file: " . $file) if defined $config{'rrd'}->{'debug'};
  if (! -e $file) {
    logging("DEBUG : file missing, skip: " . $file) if defined $config{'rrd'}->{'debug'};
  } else {
    for my $type (@rrd) {
      logging("DEBUG : file existing, export graphics: " . $file . " type:" . $type) if defined $config{'rrd'}->{'debug'};

      my $output = $config{'datadir'} . "/ttn." . $dev_id . "." . $type . ".png";

      my $color = $rrd_config{$type}->{'color'};

      my $width = 260;
      my $height = 80;
      my $start = "end-14d";

      if (defined $ENV{'HTTP_USER_AGENT'} && $ENV{'HTTP_USER_AGENT'} =~ /Mobile/) {
        $width = 140;
        $height = 50;
        $start = "end-7d";
      };

      if ($type eq "sensor") {
        RRDs::graph($output,
          "--end=now",
          "--start=" . $start,
          "--width=" . $width,
          "--height=" . $height,
          "--x-grid=HOUR:12:DAY:1:DAY:1:86400:%d",
          "--font-render-mode=mono",
          "--logarithmic",
          "--units=si",
          "DEF:" . $type . "=" . $file . ":" . $type . ":AVERAGE",
          "LINE1:" . $type . $color . ":" . $type
        );
      } else {
        RRDs::graph($output,
          "--end=now",
          "--start=" . $start,
          "--width=" . $width,
          "--height=" . $height,
          "--x-grid=HOUR:12:DAY:1:DAY:1:86400:%d",
          "--font-render-mode=mono",
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

      logging("DEBUG : exported graphics: " . $file . " type:" . $type . " size=" . length($png_base64)) if defined $config{'rrd'}->{'debug'};
    };
  };
  return %html;
};
