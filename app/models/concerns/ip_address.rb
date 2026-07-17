module IPAddress
  extend ActiveSupport::Concern

  def set_ip_address
    self.ip_address = Current.ip_address if ip_address.nil?
  end
end
