# houseconcerts

A web app for managing house concerts.

## Features

### Public site

- Upcoming and past shows, and a calendar feed
- Mailing-list signup and one-click unsubscribe
- RSVPs that guests can change or cancel from their email, with a waitlist for full shows

### Shows and invites

- Shows with multiple artists, at multiple venues, which can be grouped
- Invites sent in batches with live progress, and resent to people who didn’t open them
- Automatic reminders by email and text message
- Email open tracking, and SES bounces and complaints handled automatically

### Admin (`/backstage/`)

- Dashboard with the next show’s invites, seats and RSVPs
- Confirming and waitlisting RSVPs
- Attendance tracking and printable attendance lists
- Bulk import of people to the mailing list
- Artist photos, uploaded as JPEG, HEIC, AVIF or WebP and cropped to fit
- Passkey sign-in

Mobile/responsive throughout.

## Admin access

The admin UI lives at `/backstage/`. To access it, create an admin user with `bin/rails console`:

```ruby
Admin.create!(email: "you@example.com", password: "changeme", password_confirmation: "changeme")
```

Admins can also sign in with a passkey instead of a password. Password login stays enabled because it’s required to register the first passkey: sign in with your password, then go to `/backstage/passkeys` and follow your browser/OS prompt to create one.

## Deployment

Production runs on Apache and Phusion Passenger. See [`INFRASTRUCTURE.md`](INFRASTRUCTURE.md) for hosting, email (Amazon SES) and Cloudflare, and [`SETUP.md`](SETUP.md) for the server’s deploy user and deploys from GitHub Actions.
