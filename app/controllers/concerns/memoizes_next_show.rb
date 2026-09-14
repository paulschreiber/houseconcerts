# Shared by Madmin controllers that need the next upcoming show more than
# once per request (e.g. once to render a button, again to check whether an
# action on that button is allowed) without querying for it every time.
module MemoizesNextShow
  extend ActiveSupport::Concern

  private

    def next_show
      @next_show ||= Show.next
    end
end
