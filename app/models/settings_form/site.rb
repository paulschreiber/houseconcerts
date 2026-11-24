class SettingsForm
  class Site < SettingsForm
    setting :site_name, "site_name"
    setting :meta_description, "meta_description", :one_line
    setting :meta_keywords, "meta_keywords", :one_line
    setting :google_analytics_id, "google_analytics_id"

    validates :site_name, :meta_description, presence: true, length: { maximum: 255 }
    # The site name goes into email subjects, so it can't have a line break.
    validates :site_name, format: { with: /\A[^\p{Cntrl}]+\z/, message: :not_a_single_line }, allow_blank: true
    validates :meta_keywords, length: { maximum: 255 }
    validates :google_analytics_id, format: { with: /\AG-[A-Z0-9]+\z/, message: :not_an_analytics_id }, allow_blank: true
  end
end
