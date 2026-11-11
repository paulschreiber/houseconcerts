# In production, files and directories the app creates (uploaded photos and
# their sizes, logs) are group-writable and closed to everyone else, so the
# Solid Queue worker, which is in the same group but a different user, can
# write alongside them. This matches the worker unit's UMask=0007, which the
# worker would otherwise lose when the app boots. See
# config/deploy/setup_solidqueue_user.sh.
File.umask(0o007) if Rails.env.production?
