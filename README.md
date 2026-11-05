# houseconcerts

A web app for managing house concerts.

## Features

- Support for multiple artists per show
- Support for multiple venues
- Support for grouping venues together
- Mobile/responsive
- Admin UI for managing shows, artists and reservations

## Admin access

The admin UI lives at `/backstage/`. To access it, create an admin user with `bin/rails console`:

```ruby
Admin.create!(email: "you@example.com", password: "changeme", password_confirmation: "changeme")
```

Admins can also sign in with a passkey instead of a password. Password login stays enabled because it’s required to register the first passkey: sign in with your password, then go to `/backstage/passkeys` and follow your browser/OS prompt to create one.

## Deployment

Production runs on Apache and Phusion Passenger. See `INFRASTRUCTURE.md` for hosting, email (Amazon SES) and Cloudflare, and `SETUP.md` for the server’s deploy user and deploys from GitHub Actions.
