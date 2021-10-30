#!/bin/perl -w -T
#
# TheThingsNetwork HTTP letter box sensor notification to Signal (via D-Bus)
#
# (P) & (C) 2021-2021 Dr. Peter Bieringer <pb@bieringer.de>
#
# License: GPLv3
#
# Authors:  Dr. Peter Bieringer (bie)
#
# Supported environment:
#   - TTN_LETTERBOX_DEBUG_NOTIFYDBUSSIGNAL
#
# Required system features
#   - "signal-cli" accessable via D-Bus interface, see https://ct.de/ywjz
#     successfully tested with: https://github.com/AsamK/signal-cli/releases/tag/v0.7.4 on EL8
#
# Required configuration:
#   - enable sending messages (otherwise dry-run)
#       notifyDbusSignal.enable=1
#
#   - sender phone number (required to be registered at Signal before)
#       EXAMPLE:
#       notifyDbusSignal.sender=+000example000
#
#   - D-Bus destination (currently only supported: "org.asamk.Signal")
#       notifyDbusSignal.dest=org.asamk.Signal
#
# Honors entries starting with "signal=" from "@notify_list" provided by main CGI
#
# 20210626/bie: initial version
# 20210627/bie: major update
# 20211001/bie: adjust German translation
# 20211030/bie: add support for v3 API

use strict;
use warnings;
use utf8;

## globals
our %hooks;
our %config;
our %features;
our %translations;
our $language;
our @notify_list;


## prototyping
sub notifyDbusSignal_init();
sub notifyDbusSignal_store_data($$$);


## hooks
$hooks{'notifyDbusSignal'}->{'init'} = \&notifyDbusSignal_init;
$hooks{'notifyDbusSignal'}->{'store_data'} = \&notifyDbusSignal_store_data;

## translations
$translations{'boxstatus'}->{'de'} = "Briefkasten-Status";
$translations{'emptied'}->{'de'} = "GELEERT";
$translations{'filled'}->{'de'} = "GEFÜLLT";
$translations{'at'}->{'de'} = "am";

## active status (= passed all validity checks)
my $notifyDbusSignal_active = 0;
my $notifyDbusSignal_enable = 0;


############
## init module
############
sub notifyDbusSignal_init() {
  # set feature
  $features{'notify'} = 1;

  if (defined $ENV{'TTN_LETTERBOX_DEBUG_NOTIFYDBUSSIGNAL'}) {
    $config{'notifyDbusSignal.debug'} = 1;
  };

  if (defined $config{'notifyDbusSignal.debug'} && $config{'notifyDbusSignal.debug'} eq "0") {
    undef $config{'notifyDbusSignal.debug'};
  };

  logging("notifyDbusSignal/init: called") if defined $config{'notifyDbusSignal.debug'};

  if (! defined $config{'notifyDbusSignal.enable'}) {
    logging("notifyDbusSignal/init/NOTICE: missing entry in config file: notifyDbusSignal.enable -> notifications not enabled") if defined $config{'notifyDbusSignal.debug'};
    $config{'notifyDbusSignal.enable'} = "0";
  };

  if ($config{'notifyDbusSignal.enable'} ne "1") {
    logging("notifyDbusSignal/init/NOTICE: notifyDbusSignal.enable is not '1' -> notifications not enabled") if defined $config{'notifyDbusSignal.debug'};
  } else {
    $notifyDbusSignal_enable = 1;
  };

  if (! defined $config{'notifyDbusSignal.dest'}) {
    logging("notifyDbusSignal/init/ERROR: missing entry in config file: notifyDbusSignal.dest");
    return 0;
  };

  if ($config{'notifyDbusSignal.dest'} ne "org.asamk.Signal") {
    logging("notifyDbusSignal/init/ERROR: notifyDbusSignal.dest is not a supported one: " . $config{'notifyDbusSignal.dest'});
    return 0;
  };

  if (! defined $config{'notifyDbusSignal.sender'}) {
    logging("notifyDbusSignal/init/ERROR: missing entry in config file: notifyDbusSignal.sender");
    return 0;
  };

  if ($config{'notifyDbusSignal.sender'} !~ /^(\+|_)[0-9]+$/o) {
    logging("notifyDbusSignal/init/ERROR: notifyDbusSignal.sender is not a valid phone number: " . $config{'notifyDbusSignal.sender'});
    return 0;
  };

  $config{'notifyDbusSignal.sender'} =~ s/^\+/_/o; # convert trailing + with _

  # TODO: further D-Bus validation checks for
  # - reachability at all
  # - sender is available

  $notifyDbusSignal_active = 1;
};


## store data
sub notifyDbusSignal_store_data($$$) {
  my $dev_id = $_[0];
  my $timeReceived = $_[1];
  my $content = $_[2];

  return if ($notifyDbusSignal_active != 1); # nothing to do

  my $payload;
  $payload = $content->{'uplink_message'}->{'decoded_payload'}; # v3 (default)
  $payload = $content->{'payload_fields'} if (! defined $payload); # v2 (fallback)
  my $status = $payload->{'box'};

  logging("notifyDbusSignal/store_data: called with sensor=$dev_id boxstatus=$status") if defined $config{'notifyDbusSignal.debug'};

  if ($status =~ /^(filled|emptied)$/o) {
    # filter list
    logging("notifyDbusSignal/store_data: notification list: " . join(' ', @notify_list)) if defined $config{'notifyDbusSignal.debug'};
    my @notify_list_filtered = grep /^signal=/, @notify_list;

    logging("notifyDbusSignal/store_data: notification list filtered: " . join(' ', @notify_list_filtered)) if defined $config{'notifyDbusSignal.debug'};

    if (scalar(@notify_list_filtered) == 0) {
      logging("notifyDbusSignal/store_data: no related entry found in notification list");
      return 0;
    };

    logging("notifyDbusSignal/store_data: notification list: " . join(' ', @notify_list_filtered)) if defined $config{'notifyDbusSignal.debug'};

    foreach my $receiver (@notify_list_filtered) {
      $receiver =~ s/^signal=//o; # remove prefix
      if ($receiver !~ /^(\+[0-9]+)(;[a-z]{2})?$/o) {
        logging("notifyDbusSignal/store_data: notification receiver not a valid phone number + optional language token (SKIP): " . $receiver);
        next;
      };

      my $phonenumber = $1;

      if (defined $2) {
        $language = $2;
        $language =~ s/^;//o; # remove separator
      };

      my $icon = "";
      if ($status =~ /^(filled)$/o) {
        $icon = "📬 ";
      } elsif ($status =~ /^(emptied)$/o) {
        $icon = "📫 ";
      };

      my $message = translate("boxstatus") . ": " . $icon . $dev_id . " " . translate($status) . " " . translate("at") . " " . strftime("%Y-%m-%d %H:%M:%S %Z", localtime(str2time($timeReceived)));

      logging("notifyDbusSignal/store_data: send notification: $dev_id/$status/$receiver") if defined $config{'notifyDbusSignal.debug'};

      # action
      my $command = 'dbus-send --system --type=method_call --print-reply --dest=' . $config{'notifyDbusSignal.dest'} . ' /org/asamk/Signal/' . $config{'notifyDbusSignal.sender'} . ' org.asamk.Signal.sendMessage string:"' . $message . '" array:string: string:' . $phonenumber;

      if ($notifyDbusSignal_enable != 1) {
        logging("notifyDbusSignal/store_data/NOTICE: would call system command (if enabled): $command");
         # skip
      } else {
        logging("notifyDbusSignal/store_data: call system command: $command") if defined $config{'notifyDbusSignal.debug'};
        my $result = `$command 2>&1`;
        my $rc = $?;
        logging("notifyDbusSignal/store_data: result of called system command: $rc") if defined $config{'notifyDbusSignal.debug'};

        if ($rc == 0) {
          logging("notifyDbusSignal: notification SUCCESS: $dev_id/$status/$receiver");
        } else {
          chomp($result);
          $result =~ s/\n/ /og;
          $result =~ s/\r/ /og;
          logging("notifyDbusSignal: notification PROBLEM: $dev_id/$status/$receiver (" . $result . ")");
        };
      };
    };
  };
};

return 1;

# vim: set noai ts=2 sw=2 et:
