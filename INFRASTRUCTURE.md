# Infrastructure

Examples use the placeholder domain `houseconcerts.example`.

```
visitor ──▶ Cloudflare (proxy, DNS, WAF) ──▶ Apache + Passenger ──▶ Rails
                                                                    │
Rails ──SMTP──▶ Amazon SES ──▶ recipients                           │
                   │                                                │
                   └─ events ─▶ EventBridge ─┬─▶ CloudWatch Logs    │
                                             │   (/aws/events/ses)  │
                                             └─▶ API destination ───┘
                                                 POST /ses (bounces, complaints)
```

## Amazon Web Services

All the AWS resources below must be in the same region; the scripts read it from `R`.

### Credentials

The app reads these from Rails credentials (`bin/rails credentials:edit`):

```yaml
amazon:
  username: …
  password: …
  server: …
  ses_events_token: …
```

| Key                | What it is                    | Where                                                                     |
| ------------------ | ----------------------------- | ------------------------------------------------------------------------- |
| `username`         | SES SMTP user name            | SES → SMTP settings → Create SMTP credentials                             |
| `password`         | SES SMTP user’s password      | SES → SMTP settings → Create SMTP credentials (shown once)                |
| `server`           | SES SMTP endpoint             | SES → SMTP settings → SMTP endpoint                                       |
| `ses_events_token` | Shared secret for `POST /ses` | EventBridge → Integration → Connections → `houseconcerts` → API key value |

#### Notes

- Password is not the IAM user’s secret access key.
- Server is of the form `email-smtp.<region>.amazonaws.com`.
- Generate `ses_events_token` with `openssl rand -hex 32`.

The app won’t boot in production without `username`, `password` and `server`.
Without `ses_events_token` it boots, but refuses every `POST /ses`.

To rotate `ses_events_token`, set the new value in the credentials, deploy, then
set it on the EventBridge connection (Edit → API key value). In between, events
fail with 401 and EventBridge retries them for up to 24 hours, so none are lost.

### SES: sending

The app sends all email through SES’s SMTP interface
(`config/environments/production.rb`).

| Setting                   | Value                                                                                                |
| ------------------------- | ---------------------------------------------------------------------------------------------------- |
| Verified identity         | the domain `houseconcerts.example`                                                                   |
| DKIM                      | Easy DKIM for the domain: three CNAME records in Cloudflare DNS                                      |
| Custom MAIL FROM domain   | `mail.houseconcerts.example` (an MX record and an SPF TXT record in Cloudflare DNS)                  |
| DMARC                     | `p=reject` on `houseconcerts.example`                                                                |
| SMTP credentials          | `credentials.amazon.username`, `.password` and `.server`, port 587 (see [Credentials](#credentials)) |
| Default configuration set | `houseconcerts` (see below)                                                                          |

Invite emails carry `List-Unsubscribe` and `List-Unsubscribe-Post` headers
(one-click unsubscribe, RFC 8058). SES’s Easy DKIM signature covers both, which
Gmail and Yahoo require before showing their own Unsubscribe button. To check,
send yourself an invite, choose **Show original** in Gmail, and look for
`List-Unsubscribe` and `List-Unsubscribe-Post` in the `h=` list of the
`DKIM-Signature` for `houseconcerts.example`.

### SES: events, bounces and complaints

SES publishes an event for every message (sent, delivered, bounced, complained,
rejected). They’re logged, and permanent bounces and complaints update the
mailing list automatically (`SesEventsController`, `SesEvent`):

- a **permanent bounce** marks the person `bouncing`, so they’re no longer invited
- a **complaint** (marked as spam) marks them `removed`, like an unsubscribe

| Resource                    | Name                                   | Settings                                                                                                         |
| --------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| SES configuration set       | `houseconcerts`                        | default for the `houseconcerts.example` identity                                                                 |
| SES event destination       | `eventbridge`                          | in `houseconcerts`; Amazon EventBridge, default bus; sends, deliveries, hard bounces, complaints, rejects        |
| EventBridge rule            | `ses-all-events`                       | default bus; pattern `{"source": ["aws.ses"]}`; target the log group below                                       |
| CloudWatch log group        | `/aws/events/ses`                      | 90-day retention (it contains recipients’ addresses)                                                             |
| EventBridge connection      | `houseconcerts`                        | public API, custom configuration, API key `X-SES-Events-Token` = the app’s `credentials.amazon.ses_events_token` |
| EventBridge API destination | `houseconcerts-ses-events`             | `POST https://houseconcerts.example/ses`, 5 invocations/second, connection `houseconcerts`                       |
| EventBridge rule            | `ses-bounces-complaints-to-app`        | default bus; pattern below; target the API destination, role below, default retries, dead-letter queue below     |
| IAM role                    | `eventbridge-houseconcerts-ses-events` | trusted by `events.amazonaws.com`; allows `events:InvokeApiDestination` on the API destination                   |
| SQS queue                   | `ses-events-dlq`                       | standard queue; events the app still refuses after retries end up here                                           |

Pattern for `ses-bounces-complaints-to-app` (the app ignores transient bounces
itself):

```json
{ "source": ["aws.ses"], "detail": { "eventType": ["Bounce", "Complaint"] } }
```

In the EventBridge console, rules are under **Event buses → `default` →
Rules**, and connections and API destinations under **Integration**. Log groups
are under **CloudWatch → Logs → Log Management**.

Don’t also turn on SES’s per-identity SNS notifications for bounces and
complaints: the app would get each event twice.

Keep SES’s email feedback forwarding on (Identities → your domain →
Notifications). Besides bounces and complaints, it’s how auto-replies, such as
out-of-office messages, reach the sender: they go to the return address SES
owns, and SES counts them as transient bounces.

#### Testing bounce and complaint handling

With SES’s mailbox simulator:

1. In Madmin, create people with the emails `bounce@simulator.amazonses.com`
   and `complaint@simulator.amazonses.com`.
2. **SES → Identities → `houseconcerts.example` → Send test email**, with the
   **Bounce** scenario, then the **Complaint** scenario.
3. Within a minute or two, the first person should be **bouncing** and the
   second **removed**, and `production.log` should show `POST "/ses"` …
   `Completed 204` for each.
4. Delete the test people, and check `ses-events-dlq` is empty.

#### Tracing a message

Every message SES sends is in `/aws/events/ses`, keyed by its SES message ID.
For example, an auto-reply or bounce forwarded by `MAILER-DAEMON@amazonses.com`
has the original message’s ID in its `In-Reply-To` header
(`<010001a1…-000000@email.amazonses.com>`). To find who it was sent to, run this
in AWS CloudShell with the part before the `@`:

```bash
R=us-east-1                         # Replace with your AWS region
ID=010001a10382efb8-18c49095-5b62-4e7d-b58a-95324e4f081e-000000
aws logs filter-log-events --region $R --log-group-name /aws/events/ses \
  --start-time $(( ($(date +%s) - 30*86400) * 1000 )) --filter-pattern "\"$ID\"" \
  --query 'events[].message' --output text \
  | jq -r '[.time, ."detail-type", (.detail.mail.destination | join(","))] | @tsv'
```

In the console’s **Search log group**, put the ID in double quotes.

### CloudShell setup

The whole AWS setup, from AWS CloudShell (the `>_` icon in the console). Set
the variables, then run each part in order.

```bash
R=us-east-1                         # Replace with your AWS region
DOMAIN=houseconcerts.example.com
SECRET=3f9c2a7e5b81d046        # Replace with the output of `openssl rand -hex 32`
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
```

**1. SES domain identity.** This prints the DNS records to add in Cloudflare.
Add them as **DNS only** (grey cloud); proxied DKIM records don’t work.

```bash
aws sesv2 create-email-identity --region $R --email-identity $DOMAIN \
  --query 'DkimAttributes.Tokens' --output text | tr '\t' '\n' \
  | while read -r T; do echo "CNAME  ${T}._domainkey.$DOMAIN  ${T}.dkim.amazonses.com"; done
aws sesv2 put-email-identity-mail-from-attributes --region $R --email-identity $DOMAIN \
  --mail-from-domain mail.$DOMAIN --behavior-on-mx-failure USE_DEFAULT_VALUE
echo "MX     mail.$DOMAIN    10 feedback-smtp.$R.amazonses.com"
echo "TXT    mail.$DOMAIN    \"v=spf1 include:amazonses.com ~all\""
echo "TXT    _dmarc.$DOMAIN  \"v=DMARC1; p=reject\""
```

Once the records have propagated, this should print `True SUCCESS SUCCESS`:

```bash
aws sesv2 get-email-identity --region $R --email-identity $DOMAIN \
  --query '[VerifiedForSendingStatus, DkimAttributes.Status, MailFromAttributes.MailFromDomainStatus]' --output text
```

New SES accounts start in the sandbox, which only sends to verified addresses.
Request production access in **SES → Account dashboard**.

**2. SMTP credentials.** In the console: **SES → SMTP settings → Create SMTP
credentials**. The CLI can’t produce the SMTP password, so this step has no
command. Put the results in the app’s credentials (see [Credentials](#credentials)).

**3–5. Configuration set, event log, and bounces and complaints to the app.**

```bash
# 3. Configuration set and its EventBridge destination, as the identity’s default
aws sesv2 create-configuration-set --region $R --configuration-set-name houseconcerts
aws sesv2 create-configuration-set-event-destination --region $R --configuration-set-name houseconcerts \
  --event-destination-name eventbridge --event-destination "{
    \"Enabled\": true,
    \"MatchingEventTypes\": [\"SEND\", \"DELIVERY\", \"BOUNCE\", \"COMPLAINT\", \"REJECT\"],
    \"EventBridgeDestination\": { \"EventBusArn\": \"arn:aws:events:$R:$ACCOUNT:event-bus/default\" }
  }"
aws sesv2 put-email-identity-configuration-set-attributes --region $R \
  --email-identity $DOMAIN --configuration-set-name houseconcerts

# 4. Log every SES event
aws logs create-log-group --region $R --log-group-name /aws/events/ses
aws logs put-retention-policy --region $R --log-group-name /aws/events/ses --retention-in-days 90
aws logs put-resource-policy --region $R --policy-name EventBridgeToEventsLogs --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{ \"Effect\": \"Allow\",
    \"Principal\": { \"Service\": [\"events.amazonaws.com\", \"delivery.logs.amazonaws.com\"] },
    \"Action\": [\"logs:CreateLogStream\", \"logs:PutLogEvents\"],
    \"Resource\": \"arn:aws:logs:$R:$ACCOUNT:log-group:/aws/events/*:*\" }]
}"
aws events put-rule --region $R --name ses-all-events --event-pattern '{"source":["aws.ses"]}' --state ENABLED
aws events put-targets --region $R --rule ses-all-events \
  --targets "Id=cloudwatch-logs,Arn=arn:aws:logs:$R:$ACCOUNT:log-group:/aws/events/ses"

# 5. Send bounces and complaints to the app
CONN_ARN=$(aws events create-connection --region $R --name houseconcerts --authorization-type API_KEY \
  --auth-parameters "{\"ApiKeyAuthParameters\":{\"ApiKeyName\":\"X-SES-Events-Token\",\"ApiKeyValue\":\"$SECRET\"}}" \
  --query ConnectionArn --output text)
DEST_ARN=$(aws events create-api-destination --region $R --name houseconcerts-ses-events \
  --connection-arn "$CONN_ARN" --invocation-endpoint https://$DOMAIN/ses \
  --http-method POST --invocation-rate-limit-per-second 5 --query ApiDestinationArn --output text)
Q=$(aws sqs create-queue --region $R --queue-name ses-events-dlq \
  --attributes MessageRetentionPeriod=1209600 --query QueueUrl --output text)
DLQ_ARN=$(aws sqs get-queue-attributes --region $R --queue-url $Q --attribute-names QueueArn \
  --query Attributes.QueueArn --output text)
RULE=ses-bounces-complaints-to-app
RULE_ARN=arn:aws:events:$R:$ACCOUNT:rule/$RULE
aws events put-rule --region $R --name $RULE --state ENABLED \
  --event-pattern '{"source":["aws.ses"],"detail":{"eventType":["Bounce","Complaint"]}}'
aws iam create-role --role-name eventbridge-houseconcerts-ses-events --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"events.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam put-role-policy --role-name eventbridge-houseconcerts-ses-events --policy-name invoke-api-destination \
  --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"events:InvokeApiDestination\",\"Resource\":\"$DEST_ARN\"}]}"
ROLE_ARN=$(aws iam get-role --role-name eventbridge-houseconcerts-ses-events --query Role.Arn --output text)
aws sqs set-queue-attributes --region $R --queue-url $Q --attributes "{\"Policy\":\"{\\\"Version\\\":\\\"2012-10-17\\\",\\\"Statement\\\":[{\\\"Effect\\\":\\\"Allow\\\",\\\"Principal\\\":{\\\"Service\\\":\\\"events.amazonaws.com\\\"},\\\"Action\\\":\\\"sqs:SendMessage\\\",\\\"Resource\\\":\\\"$DLQ_ARN\\\",\\\"Condition\\\":{\\\"ArnEquals\\\":{\\\"aws:SourceArn\\\":\\\"$RULE_ARN\\\"}}}]}\"}"
sleep 10 # let the new role propagate
aws events put-targets --region $R --rule $RULE \
  --targets "Id=houseconcerts,Arn=$DEST_ARN,RoleArn=$ROLE_ARN,DeadLetterConfig={Arn=$DLQ_ARN}"
```

## Cloudflare

`houseconcerts.example` is proxied through Cloudflare, which also hosts its DNS,
including the SES records above.

### Security rules

**Security → WAF → Custom rules.**

#### 1. Unsubscribe or RSVP no

The one-click links in invite and reminder emails (`/unsubscribe/<token>` and
`/rsvps/show/<show>/<token>/no`) act as soon as they’re opened. Email security
scanners (Microsoft Defender/Safe Links, Mimecast, Proofpoint, …) open links in
incoming mail to check them, which would unsubscribe the recipient or cancel
their RSVP without them clicking anything. A Managed Challenge stops those
automated visits; people opening the links in a browser almost always pass it
invisibly.

| Field      | Value                                   |
| ---------- | --------------------------------------- |
| Rule name  | Unsubscribe or RSVP no                  |
| Expression | below                                   |
| Action     | **Managed Challenge**                   |
| Order      | first (it stops evaluating later rules) |

```
(http.request.method eq "GET" and (starts_with(http.request.uri.path, "/unsubscribe/") or http.request.uri.path wildcard r"/rsvps/show/*/no"))
```

Keep the `GET` condition. One-click unsubscribe from Gmail’s or Yahoo’s own
Unsubscribe button is a `POST` to the same `/unsubscribe/<token>` URL, sent by
their servers, which can’t solve a challenge.

#### 2. Don’t challenge AWS

`POST /ses` comes from EventBridge, so it must not be challenged or blocked
(the app checks its secret header). If the `ses-bounces-complaints-to-app`
rule shows failed invocations, or `ses-events-dlq` fills up with 403s, add a
custom rule that matches `http.request.uri.path eq "/ses"` with the action
**Skip**, skipping the remaining custom rules and, where the plan allows, Bot
Fight Mode, and put it above any rule that could match.

## Server

The app lives in `/data/sites/houseconcerts`, deployed there by Capistrano
(`config/deploy.rb`, `config/deploy/production.rb`).

To set up a new server, or add a deploy key, follow [`SETUP.md`](SETUP.md).

| User                   | What it does                                                                                                 | Set up by                  |
| ---------------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------- |
| `houseconcerts-deploy` | Capistrano logs in as it; owns the app directory; Passenger runs the web app as it                           | `setup_deploy_user.sh`     |
| `houseconcerts-jobs`   | runs the Solid Queue worker (`houseconcerts-solidqueue` systemd service); can only write to logs and storage | `setup_solidqueue_user.sh` |

Both are in the `houseconcerts` group, which can read the app’s secrets in
`shared/config` and write to `shared/log` and `shared/storage`.

`houseconcerts-deploy` has no password and logs in only with the SSH keys in its
`~/.ssh/authorized_keys`, each limited with `restrict`. Its only sudo right is
`systemctl restart houseconcerts-solidqueue` (see [sudo](#sudo)). To work on
the server as it, log in as yourself and run `sudo -iu houseconcerts-deploy`.

### sudo

The deploy user’s one sudo rule, for the `solid_queue:restart` Capistrano task,
is in its own file, `/etc/sudoers.d/houseconcerts-deploy`, not in
`/etc/sudoers` itself. `setup_deploy_user.sh` writes it, with the path from
`command -v systemctl`:

```
houseconcerts-deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart houseconcerts-solidqueue
```

sudo ignores the file, without an error, unless `/etc/sudoers` has its usual
last line, which reads the files in `/etc/sudoers.d` (Ubuntu’s and Debian’s
default):

```
@includedir /etc/sudoers.d
```

Older versions of sudo write this as `#includedir /etc/sudoers.d`; despite the
`#`, it isn’t a comment. To check the rule: `sudo -l -U houseconcerts-deploy`.

### Deploying

From a checkout, with your key in `houseconcerts-deploy`’s `authorized_keys`:

```bash
bundle exec cap production deploy
```

Or from GitHub: **Actions → Deploy → Run workflow** (`.github/workflows/deploy.yml`).
It deploys `main`, and only runs for the repository’s owner. It needs:

| GitHub setting                                           | Value                                                                                   |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Environment `production` → Deployment branches           | `main` only                                                                             |
| Environment `production` → Required reviewers            | optional; if set, approve each run                                                      |
| Environment `production` → secret `DEPLOY_SSH_KEY`       | private half of a key used only for this, in `houseconcerts-deploy`’s keys              |
| Environment `production` → variable `DEPLOY_KNOWN_HOSTS` | every line for the server in your `~/.ssh/known_hosts`, including its `ssh-ed25519` key |

`SETUP.md` sets these up. Deploys refuse to connect if the server’s host key
isn’t in `DEPLOY_KNOWN_HOSTS` (`verify_host_key: :always`). With the `ed25519`
gem, net-ssh asks for the server’s ED25519 host key first, so `known_hosts`
(yours too, for deploys from your development machine) needs that key, not
only ECDSA.

## File storage

Uploaded files (artist photos) are stored with Active Storage.
`storage_service` in `config/settings.yml` picks the service in
`config/storage.yml`:

- **`local` (the default):** files go in `storage/`, which Capistrano links to
  `shared/storage` so they outlive each release. Back up `shared/storage` with
  the database: the database only records which files exist.
- **`amazon`:** an S3 bucket. Add `gem "aws-sdk-s3", require: false` to the
  `Gemfile`, add this service to `config/storage.yml` with the bucket’s name and
  region, add the `aws` keys to the credentials, then set
  `storage_service: "amazon"`. The bucket stays private: the keys need
  `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` and `s3:ListBucket` on it.

  ```yaml
  amazon:
    service: S3
    access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
    secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
    region: …
    bucket: …
  ```

An uploaded photo is stored as a JPEG, rotated upright and without metadata
(such as where it was taken), whatever format was uploaded. Each photo size is
a JPEG made from it by libvips the first time it’s requested, then stored (see
[Image libraries](#image-libraries)).

Only the photo sizes are served, through Rails (URLs under
`/rails/active_storage/representations/proxy/`), never straight from the disk
or the bucket. Images stay on the site’s own domain, so the content security
policy’s `img-src 'self'` allows them and Cloudflare caches them. Active
Storage’s other routes are turned off (`draw_routes` in
`config/application.rb`): they would serve the stored photo itself to anyone
with a photo size’s URL, and accept uploads from anyone.

## Apache

### Virtual hosts

```apache
<VirtualHost *:80>
    ServerName   houseconcerts.example
    ServerAlias  www.houseconcerts.example
    DocumentRoot /data/sites/houseconcerts/current/public
    CustomLog    /data/logs/houseconcerts.example/access vhost_combined
    ErrorLog     /data/logs/houseconcerts.example/error

    RewriteEngine on
    RewriteCond %{HTTP_HOST} !^houseconcerts\.example$ [NC]
    RewriteCond %{HTTP_HOST} !^$
    RewriteRule ^/(.*)       https://houseconcerts.example/$1 [L,R=301]

    RewriteCond %{HTTPS} off
    RewriteRule (.*)         https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName   houseconcerts.example
    ServerAlias  www.houseconcerts.example
    DocumentRoot /data/sites/houseconcerts/current/public
    CustomLog    /data/logs/houseconcerts.example/access vhost_combined
    ErrorLog     /data/logs/houseconcerts.example/error

    PassengerFriendlyErrorPages off

    <Directory /data/sites/houseconcerts/current/public>
        Require all granted
        Options -MultiViews +FollowSymLinks
        AllowOverride all
    </Directory>

    SSLCertificateFile    /etc/letsencrypt/live/houseconcerts.example/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/houseconcerts.example/privkey.pem

    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"

    # How long browsers keep files from public/ (see Cache lifetimes).
    <LocationMatch "^/assets/">
        Header set Cache-Control "public, max-age=31536000, immutable"
    </LocationMatch>

    # Redirect other host names (e.g. www.) to the canonical one.
    RewriteEngine on
    RewriteCond %{HTTP_HOST} !^houseconcerts\.example$ [NC]
    RewriteCond %{HTTP_HOST} !^$
    RewriteRule ^/(.*)       https://houseconcerts.example/$1 [L,R=301]

    RewriteCond %{HTTPS} off
    RewriteRule (.*)         https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>
</IfModule>
```

### Cache lifetimes

Apache serves the files in `public/` itself, so Rails’
`config.public_file_server.headers` never reaches them. The vhost sets their
`Cache-Control` instead:

- **`/assets/`, 1 year:** each file has a fingerprint in its name
  (`application-9346c3cd.css`) that changes whenever its content does, so
  browsers can keep it, without rechecking (`immutable`), until the name
  changes.

Uploaded photos (`/rails/active_storage/`) don’t come from `public/`, so Rails
sets their `Cache-Control` itself: public and cached indefinitely, since a
replaced photo gets a new URL.

To check, `curl -sI` a stylesheet. Its `cache-control` should show
`max-age=31536000, immutable`.

### Real visitor IPs

Behind Cloudflare, requests reach Apache from Cloudflare’s addresses.
`mod_remoteip` takes the visitor’s address from the `CF-Connecting-IP` header
instead, trusting it only from Cloudflare’s ranges. Two files, on Debian/Ubuntu:

`/etc/apache2/mods-available/remoteip.conf` (`sudo a2enmod remoteip`):

```apache
<IfModule remoteip_module>
    RemoteIPHeader CF-Connecting-IP
    RemoteIPTrustedProxy 127.0.0.1 ::1
</IfModule>
```

`/etc/apache2/conf-available/cloudflare-remoteip.conf` (`sudo a2enconf cloudflare-remoteip`):

```apache
<IfModule remoteip_module>
    # Cloudflare’s IP ranges (https://www.cloudflare.com/ips/), checked 2026-10-02
    RemoteIPHeader CF-Connecting-IP
    RemoteIPTrustedProxy 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22
    RemoteIPTrustedProxy 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20
    RemoteIPTrustedProxy 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13
    RemoteIPTrustedProxy 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    RemoteIPTrustedProxy 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32
    RemoteIPTrustedProxy 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
</IfModule>
```

Cloudflare changes its ranges occasionally; compare them with
[cloudflare.com/ips](https://www.cloudflare.com/ips/) now and then.

### Access log

In `/etc/apache2/apache2.conf`:

```apache
LogFormat "%v:%p %a %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
```

`%a` is the visitor’s address as worked out by `mod_remoteip`.

### Boot errors

Errors raised while Passenger starts the app, before a worker exists, go to
Apache’s global error log (`/var/log/apache2/error.log`), not the vhost’s
`ErrorLog`. Check both when the app won’t start.

### Image libraries

libvips resizes artist photos. Reading HEIC and AVIF uploads also needs
libheif’s decoder plugins, which `SETUP.md` installs:

- `libheif-plugin-libde265` decodes HEIC. libvips doesn’t install it, and
  without it HEIC uploads are refused as unreadable.
- `libheif-plugin-dav1d` decodes AVIF. On Ubuntu 26.04, libvips already brings
  `libheif-plugin-aomdec`, which also does, but dav1d is faster.

libvips lists `.heic` and `.avif` among the formats it reads even when no
plugin can decode them, so check by decoding the sample photos, from the
deployed app:

```bash
cd /data/sites/houseconcerts/current
bundle exec ruby -e 'require "vips"; %w[heic avif].each { |f| Vips::Image.new_from_file("test/fixtures/files/photo.#{f}").avg; puts "#{f}: ok" }'
```

It should print `heic: ok` and `avif: ok`. A missing plugin raises a
`Vips::Error` instead.

### Native gems and systemd hardening

Gems that use `ffi` (such as `ruby-vips`, for Active Storage image variants)
generate code at runtime, which systemd’s `MemoryDenyWriteExecute=yes` blocks.
If `apache2.service` sets it, Passenger can’t start the app, and the global
error log shows a garbled `RuntimeError` from `ffi/function.rb` in `attach`.
`SETUP.md` checks for it on a new server. If
`systemctl show apache2 -p MemoryDenyWriteExecute` says `yes`, turn it off with
`sudo systemctl edit apache2`:

```ini
[Service]
MemoryDenyWriteExecute=no
```

Then `sudo systemctl daemon-reload && sudo systemctl restart apache2`.
