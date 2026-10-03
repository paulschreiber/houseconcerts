# Infrastructure

What houseconcerts relies on outside this repo, and how it's configured. All
AWS resources are in **us-east-1 (N. Virginia)**.

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

## Amazon SES: sending

The app sends all email through SES's SMTP interface
(`config/environments/production.rb`).

| Setting                  | Value                                                                                                     |
| ------------------------ | --------------------------------------------------------------------------------------------------------- |
| Verified identity        | the domain `houseconcerts.nyc`                                                                            |
| DKIM                     | Easy DKIM for the domain: three CNAME records in Cloudflare DNS                                           |
| Custom MAIL FROM domain  | `mail.houseconcerts.nyc` (an MX record and an SPF TXT record in Cloudflare DNS)                          |
| DMARC                    | `p=reject` on `houseconcerts.nyc`                                                                         |
| SMTP credentials         | `credentials.amazon.username`, `.password` and `.server` (the SMTP endpoint), port 587                    |
| Default configuration set | `houseconcerts` (see below)                                                                              |

Invite emails carry `List-Unsubscribe` and `List-Unsubscribe-Post` headers
(one-click unsubscribe, RFC 8058). SES's Easy DKIM signature covers both, which
Gmail and Yahoo require before showing their own Unsubscribe button. To check,
send yourself an invite, choose **Show original** in Gmail, and look for
`List-Unsubscribe` and `List-Unsubscribe-Post` in the `h=` list of the
`DKIM-Signature` for `houseconcerts.nyc`.

## Amazon SES: events, bounces and complaints

SES publishes an event for every message (sent, delivered, bounced, complained,
rejected). They're logged, and permanent bounces and complaints update the
mailing list automatically (`SesEventsController`, `SesEvent`):

- a **permanent bounce** marks the person `bouncing`, so they're no longer invited
- a **complaint** (marked as spam) marks them `removed`, like an unsubscribe

| Resource                    | Name                               | Settings                                                                                                                     |
| --------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| SES configuration set       | `houseconcerts`                    | default for the `houseconcerts.nyc` identity                                                                                 |
| SES event destination       | `eventbridge`                      | in `houseconcerts`; Amazon EventBridge, default bus; sends, deliveries, hard bounces, complaints, rejects                     |
| EventBridge rule            | `ses-all-events`                   | default bus; pattern `{"source": ["aws.ses"]}`; target the log group below                                                   |
| CloudWatch log group        | `/aws/events/ses`                  | 90-day retention (it contains recipients' addresses)                                                                         |
| EventBridge connection      | `houseconcerts`                    | public API, custom configuration, API key `X-SES-Events-Token` = the app's `credentials.amazon.ses_events_token`             |
| EventBridge API destination | `houseconcerts-ses-events`         | `POST https://houseconcerts.nyc/ses`, 5 invocations/second, connection `houseconcerts`                                       |
| EventBridge rule            | `ses-bounces-complaints-to-app`    | default bus; pattern below; target the API destination, role below, default retries, dead-letter queue below                 |
| IAM role                    | `eventbridge-houseconcerts-ses-events` | trusted by `events.amazonaws.com`; allows `events:InvokeApiDestination` on the API destination                           |
| SQS queue                   | `ses-events-dlq`                   | standard queue; events the app still refuses after retries end up here                                                      |

Pattern for `ses-bounces-complaints-to-app` (the app ignores transient bounces
itself):

```json
{ "source": ["aws.ses"], "detail": { "eventType": ["Bounce", "Complaint"] } }
```

In the EventBridge console, rules are under **Event buses → `default` →
Rules**, and connections and API destinations under **Integration**. Log groups
are under **CloudWatch → Logs → Log Management**.

### The shared secret

`POST /ses` refuses every request unless its `X-SES-Events-Token` header matches
`credentials.amazon.ses_events_token`. To rotate it:

1. Generate a new one: `openssl rand -hex 32`.
2. Set it in `bin/rails credentials:edit` and deploy.
3. Set the same value on the EventBridge connection `houseconcerts` (Edit →
   API key value).

Between steps 2 and 3, requests fail with 403 and EventBridge retries them for up
to 24 hours, so no events are lost if both changes happen within a few hours.

### Testing

With SES's mailbox simulator:

1. In Madmin, create people with the emails `bounce@simulator.amazonses.com`
   and `complaint@simulator.amazonses.com`.
2. **SES → Identities → `houseconcerts.nyc` → Send test email**, with the
   **Bounce** scenario, then the **Complaint** scenario.
3. Within a minute or two, the first person should be **bouncing** and the
   second **removed**, and `production.log` should show `POST "/ses"` …
   `Completed 204` for each.
4. Delete the test people, and check `ses-events-dlq` is empty.

### Tracing a message

Every message SES sends is in `/aws/events/ses`, keyed by its SES message ID.
For example, an auto-reply or bounce forwarded by `MAILER-DAEMON@amazonses.com`
has the original message's ID in its `In-Reply-To` header
(`<010001a1…-000000@email.amazonses.com>`). To find who it was sent to, run this
in AWS CloudShell with the part before the `@`:

```bash
ID=010001a10382efb8-18c49095-5b62-4e7d-b58a-95324e4f081e-000000
aws logs filter-log-events --region us-east-1 --log-group-name /aws/events/ses \
  --start-time $(( ($(date +%s) - 30*86400) * 1000 )) --filter-pattern "\"$ID\"" \
  --query 'events[].message' --output text \
  | jq -r '[.time, ."detail-type", (.detail.mail.destination | join(","))] | @tsv'
```

In the console's **Search log group**, put the ID in double quotes.

### Recreating it from scratch

The console steps above work, but the CLI is quicker and less error-prone. From
AWS CloudShell (assumes the `houseconcerts.nyc` identity already exists, and
`SECRET` is the app's `ses_events_token`):

```bash
R=us-east-1
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
SECRET=…

# Configuration set and its EventBridge destination, as the identity's default
aws sesv2 create-configuration-set --region $R --configuration-set-name houseconcerts
aws sesv2 create-configuration-set-event-destination --region $R --configuration-set-name houseconcerts \
  --event-destination-name eventbridge --event-destination "{
    \"Enabled\": true,
    \"MatchingEventTypes\": [\"SEND\", \"DELIVERY\", \"BOUNCE\", \"COMPLAINT\", \"REJECT\"],
    \"EventBridgeDestination\": { \"EventBusArn\": \"arn:aws:events:$R:$ACCOUNT:event-bus/default\" }
  }"
aws sesv2 put-email-identity-configuration-set-attributes --region $R \
  --email-identity houseconcerts.nyc --configuration-set-name houseconcerts

# Log every SES event
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

# Send bounces and complaints to the app
CONN_ARN=$(aws events create-connection --region $R --name houseconcerts --authorization-type API_KEY \
  --auth-parameters "{\"ApiKeyAuthParameters\":{\"ApiKeyName\":\"X-SES-Events-Token\",\"ApiKeyValue\":\"$SECRET\"}}" \
  --query ConnectionArn --output text)
DEST_ARN=$(aws events create-api-destination --region $R --name houseconcerts-ses-events \
  --connection-arn "$CONN_ARN" --invocation-endpoint https://houseconcerts.nyc/ses \
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

Don't also turn on SES's per-identity SNS notifications for bounces and
complaints: the app would get each event twice. SES's email feedback forwarding
(bounces and complaints emailed to the sender) is optional now that the app
handles them.

## Cloudflare

`houseconcerts.nyc` is proxied through Cloudflare, which also hosts its DNS,
including the SES records above.

### Real visitor IPs

Apache only sees Cloudflare's addresses unless it trusts Cloudflare's
`CF-Connecting-IP` header. The server has `mod_remoteip` enabled with
`RemoteIPHeader CF-Connecting-IP` and a `RemoteIPTrustedProxy` line for each of
[Cloudflare's IP ranges](https://www.cloudflare.com/ips/), so Rails, Rack::Attack's
per-IP throttles and the access log (`%a` in its `LogFormat`) see the visitor's
address. Re-check the ranges against Cloudflare's list now and then.

### Security rules

**Security → WAF → Custom rules.**

#### 1. Unsubscribe or RSVP no

The one-click links in invite and reminder emails (`/unsubscribe/<token>` and
`/rsvps/show/<show>/<token>/no`) act as soon as they're opened. Email security
scanners (Microsoft Defender/Safe Links, Mimecast, Proofpoint, …) open links in
incoming mail to check them, which would unsubscribe the recipient or cancel
their RSVP without them clicking anything. A Managed Challenge stops those
automated visits; people opening the links in a browser almost always pass it
invisibly.

| Field      | Value                                       |
| ---------- | ------------------------------------------- |
| Rule name  | Unsubscribe or RSVP no                      |
| Expression | below                                       |
| Action     | **Managed Challenge**                       |
| Order      | first (it stops evaluating later rules)     |

```
(http.request.method eq "GET" and (starts_with(http.request.uri.path, "/unsubscribe/") or http.request.uri.path wildcard r"/rsvps/show/*/no"))
```

Keep the `GET` condition. One-click unsubscribe from Gmail's or Yahoo's own
Unsubscribe button is a `POST` to the same `/unsubscribe/<token>` URL, sent by
their servers, which can't solve a challenge.

#### 2. Don't challenge AWS

`POST /ses` comes from EventBridge, so it must not be challenged or blocked
(the app checks its secret header). If the `ses-bounces-complaints-to-app`
rule shows failed invocations, or `ses-events-dlq` fills up with 403s, add a
custom rule that matches `http.request.uri.path eq "/ses"` with the action
**Skip**, skipping the remaining custom rules and, where the plan allows, Bot
Fight Mode, and put it above any rule that could match.
