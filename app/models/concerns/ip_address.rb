module IPAddress
  extend ActiveSupport::Concern

  def set_ip_address
    self.ip_address = current_ip if ip_address.nil?
  end
end
