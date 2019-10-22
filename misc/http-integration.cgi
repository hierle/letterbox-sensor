#!/usr/bin/perl -w

# simple ttn http integration
use English;
use strict;
use Socket;

my $nowint = time;
my $nowstr = int2time($nowint);
my $today = `date +%Y%m%d`;
my $reqm = $ENV{'REQUEST_METHOD'};
#if ((!defined $reqm)||($reqm ne "GET")) { response(400,"illegal request method"); exit; }
my $logfile = "/home/ttn/public_html/letterbox-sensor.$today";
my $statusfile = "/home/ttn/public_html/letterbox-sensor.status";
my $threshold=30;

if ($reqm eq "POST") {
 # write log file
 open LOGF, ">> $logfile";
 print LOGF $nowstr . " ";
 while (<STDIN>) {
   print LOGF $_ . "\n";
 }
 close LOGF;
 response(200,"OK");
 #my $status = &getstatus();
 #my $change = &getchange();

}
else {
 my $last = `tail -1 $logfile`;
 my $sensor=0;
 if($last =~ /"sensor":(.*?),.*/) { $sensor=$1; }
 if($sensor > $threshold) { &letter("green",":) $sensor (:"); }
 else { &letter("grey",":( $sensor ):"); }
}

exit;


##############
sub response {
  my $status = shift;
  my $message = shift;

  my $html = "Status: $status
Date: $nowstr
Last-modified: $nowstr
Pragma: no-cache
Cache-control: no-cache
Content-Type: text/html; charset=utf-8

<html><head></head><body>$message</body></html>
\n";
  print $html;
}

############
sub letter {
  my $bg = shift;
  my $message = shift;

  my $html = "Status: 200 OK
Date: $nowstr
Last-modified: $nowstr
Pragma: no-cache
Cache-control: no-cache
Content-Type: text/html; charset=utf-8

<html><head></head><body bgcolor=$bg><font size=+3 face=verdana><b>$message</b></font></body></html>
\n";
  print $html;
}

##############
sub int2time {
    my $nowint=$ARG[0];
    if (!defined $nowint) { $nowint = time; }
    my $nowstr;
    $nowstr = gmtime($nowint);
    if ( $nowstr =~ /^(...)\ (...)\ (..)\ (..:..:..)\ (....)$/ ) {
         $nowstr = "$1\, $3 $2 $5 $4 GMT";
    }
    return $nowstr;
}
