# houseconcerts

A web app for managing house concerts.

Originally built with Rails 2.2.2. Now with Rails 7.

## Features

- Support for multiple artists per show
- Support for multiple venues
- Support for grouping venues together
- Mobile/responsive

## Deployment notes

- Production runs on Apache + Phusion Passenger. If a fresh server is ever provisioned, check `systemctl show apache2 | grep -i memorydeny` before deploying. If `MemoryDenyWriteExecute=yes` is set (a systemd hardening default on some distros), any gem that relies on libffi's runtime JIT trampolines (e.g. `ruby-vips`, used for ActiveStorage image variants) will fail to boot with a cryptic/garbled `RuntimeError` from `ffi/function.rb`, because that setting blocks the mmap(RW)->mprotect(RX) pattern libffi uses to generate trampolines. Fix: `sudo systemctl edit apache2`, add:
  ```ini
  [Service]
  MemoryDenyWriteExecute=no
  ```
  then `sudo systemctl daemon-reload && sudo systemctl restart apache2`.

## TODO

- [ ] Admin dashboard
- [ ] Admin UI
- [ ] Mail merge invites
- [ ] Navigation on mobile
- [ ] Gmail mail actions (https://developers.google.com/gmail/markup/)
- [ ] Calendar event in confirmation email
- [ ] Calendar feed for upcoming shows
