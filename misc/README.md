# LoRaWan Letterbox Sensor HTTP integration and Web UI
`ttn-letterbox.cgi` is a Perl-based CGI script which serves
- HTTP integration triggered from TTN
- Web UI

## Prerequisites

Following Perl modules are required:

- perl-Data-UUID
- perl-URI-Encode
- perl-Apache-Htpasswd (for user authentication)
- perl-Authen-Passphrase or perl-Crypt-SaltedHash (for user authentication)
- perl-LWP-Protocol-https (for CAPTCHA verification)


## Installation

- enable your favorite web server (e.g. Apache) to be able to support CGI
- create directories

```
# base directory, can var
BASEDIR="/path/to/my.iot.domain.example"

# create CGI directory (this needs to be enabled then in web server's config for supporting CGI
mkdir $BASEDIR/cgi-bin

# config directory outside public content
mkdir $BASEDIR/conf

# data directory outside public content (this directory must be writable by web server)
mkdir -p $BASEDIR/data/ttn
```

- copy files

```
# configuration file (template)
cp ttn-letterbox.conf $BASEDIR/conf/

# base CGI
cp ttn-letterbox.cgi $BASEDIR/cgi-bin/

# RRD graph module (optional)
cp ttn-letterbox-rrd.pm $BASEDIR/cgi-bin/

# statistics module (optional)
cp ttn-letterbox-statistics.p $BASEDIR/cgi-bin/

# user authentication module (optional)
cp ttn-letterbox-userauth.pm $BASEDIR/cgi-bin/

# notification/Email module (optional)
cp ttn-letterbox-notifyEmail.pm $BASEDIR/cgi-bin/

# notification/Signal module (optional)
cp ttn-letterbox-notifyDbusSignal.pm $BASEDIR/cgi-bin/
```

## Base Configuration

adjust configuration template

```
$BASEDIR/conf/ttn-letterbox.conf
```

- for initial configuration, enable device auto-register

`autoregister=1`

(don't forget to disable it afterwards)

- device file: `$BASEDIR/data/ttn/ttn.devices.list`


## Test TTN receiver support

- use provided test script, see online help

```
ttn-letterbox-simulator.sh -U <url> -H <auth-header> -D <device-id> -B <box-status> [...]

 Mandatory
  -U <url>             URL to post simulation data, e.g. https://my.iot.domain.example/cgi-bin/ttn-letterbox-test.cgi
  -H <auth-header>     authentication header, e.g. "X-TTN-AUTH: MySeCrEt"
  -D <device-id>       device ID
  -B <box-status>      box status to submit (full|empty|filled|emptied)

 Optional:
  -C <counter-file>    fetch/store counter value of sensors (default: ./ttn-letterbox-simulator.counter.<device-id>)
  -S <serial>          hardware serial (default: 0000000000000000)
  -F <sensor-full>     overwrite sensor value for 'full'  (default: 500)
  -E <sensor-empty>    overwrite sensor value for 'empty' (default: 25)
  -d                   debug
  -r                   real-run (otherwise only print what will be done)
  -2                   switch to v2 API (legacy)
```

- Log file with raw contents: `$BASEDIR/data/ttn/ttn.my-sensor-name.%Y%m%d.raw.log`
- Last status change files:
  - `$BASEDIR/data/ttn/ttn.my-sensor-name.filled.time.status`
  - `$BASEDIR/data/ttn/ttn.my-sensor-name.emptied.time.status`
- Last received raw content:
  - '$BASEDIR/data/ttn/ttn.my-sensor-name.last.raw.status`

## Configure TTN HTTP integration

### Application

(work-in-progress)

Applications → Add application 

Payload Formaters → Uplink
- Formatter Type: Javascript
- Payload Format: Custom
- Decoder: -> take from `payload.formatter.uplink-v3.txt`

### Integration

(work-in-progress)

Integration → Webhooks → Custom webhook 
- Webhook Format: JSON
- Base URL: `https://my.iot.domain.example/cgi-bin/ttn-letterbox.cgi` (example)
- Additional Headers: `X-TTN-AUTH: MySeCrEt` (example)


## Module Configuration

### ttn-letterbox-userauth.pm

- supports
  - username/password authentication
  - optional protection by CAPTCHA (reCAPTCHA, hCaptcha, FriendlyCaptcha)
- user file: `$BASEDIR/data/ttn/ttn.users.list`

-> see more for now description inside module

### ttn-letterbox-rrd.pm

- support displaying timeline of various values
- RRD file (per sensor): `$BASEDIR/data/ttn/ttn.my-sensor-name.rrd`

-> see more for now description inside module

### ttn-letterbox-statistics.pm

- support displaying 'boxstatus' and 'receivedstatus' in a matrix picture
- statistics file 'boxstatus' (per sensor): `$BASEDIR/data/ttn/ttn.my-sensor-name.boxstatus.xpm`
- statistics file 'receivedstatus' (per sensor): `$BASEDIR/data/ttn/ttn.my-sensor-name.receivedstatus.xpm`

-> see more for now description inside module

### ttn-letterbox-notifyEmail.pm

- support sending e-mail on status change
- notification per user/sensor: `$BASEDIR/data/ttn/ttn.notify.list`

-> see more for now description inside module

### ttn-letterbox-notifyDbusSignal.pm

- support sending a "Signal" message on status change
- notification per user/sensor: `$BASEDIR/data/ttn/ttn.notify.list`

-> see more for now description inside module
