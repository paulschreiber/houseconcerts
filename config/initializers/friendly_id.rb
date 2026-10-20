FriendlyId.defaults do |config|
  # Words that can't be used as slugs, since they'd conflict with routes or
  # read oddly in a URL.
  config.use :reserved

  config.reserved_words = %w[new edit index session login logout users admin
                             stylesheets assets javascripts images]
end
