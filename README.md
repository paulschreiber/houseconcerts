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

Admins can also sign in with a passkey instead of a password. Password login stays enabled because it's required to register the first passkey: sign in with your password, then go to `/backstage/passkeys/new` and follow your browser/OS prompt to create one.

## Deployment notes

- Production runs on Apache + Phusion Passenger. If a fresh server is ever provisioned, check `systemctl show apache2 | grep -i memorydeny` before deploying. If `MemoryDenyWriteExecute=yes` is set (a systemd hardening default on some distros), any gem that relies on libffi's runtime JIT trampolines (e.g. `ruby-vips`, used for ActiveStorage image variants) will fail to boot with a cryptic/garbled `RuntimeError` from `ffi/function.rb`, because that setting blocks the mmap(RW)->mprotect(RX) pattern libffi uses to generate trampolines. Fix: `sudo systemctl edit apache2`, add:
  ```ini
  [Service]
  MemoryDenyWriteExecute=no
  ```
  then `sudo systemctl daemon-reload && sudo systemctl restart apache2`.

## TODO

- [ ] Mail merge invites
- [ ] Navigation on mobile
- [ ] Gmail mail actions (https://developers.google.com/gmail/markup/)
- [ ] Calendar event in confirmation email
- [ ] Calendar feed for upcoming shows
