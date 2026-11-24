# One tab of the backstage settings page (Madmin::SettingsController): the
# settings it edits, with their validations. A subclass lists its settings with
# `setting`, naming the form's attribute and the setting's dotted key. A new
# form starts from the current settings. Saving stores only the values that
# differ from the defaults (SettingValue), so a setting an admin sets back to
# its default follows the YAML again.
class SettingsForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Attributes::Normalization

  class_attribute :settings, instance_writer: false, default: {}

  class << self
    # type: :string (one line: line breaks and tabs become spaces), :text
    # (several lines), :integer or :boolean. Text is cleaned like a record's
    # (TextCleaner). from: reads the setting's value into the form's attribute;
    # to: turns the attribute into the value stored for the setting.
    def setting(name, key, type = :string, from: nil, to: nil)
      attribute name, { integer: WholeNumber.new, text: :string }.fetch(type, type)
      normalizes name, with: ->(value) { TextCleaner.clean(value, one_line: type == :string) } if %i[string text].include?(type)
      self.settings = settings.merge(name => { key:, from:, to: })
    end
  end

  def initialize(values = {})
    super()
    settings.each do |name, setting|
      value = setting[:key].split(".").inject(Settings) { |node, part| node.public_send(part) }
      public_send("#{name}=", setting[:from] ? setting[:from].call(value) : value)
    end
    assign_attributes(values)
  end

  # Like Active Record's save: true if it stored the settings, false if invalid.
  def save # rubocop:disable Naming/PredicateMethod
    return false unless valid?

    SettingValue.transaction do
      records = SettingValue.where(key: settings.values.pluck(:key)).index_by(&:key)
      settings.each { |name, setting| store(records[setting[:key]], setting[:key], stored_value(name, setting)) }
    end
    true
  end

  def persisted?
    true
  end

  private

    def stored_value(name, setting)
      value = public_send(name)
      (setting[:to] ? setting[:to].call(value) : value).to_s
    end

    def store(record, key, value)
      if value == Defaults.dig(*key.split(".").map(&:to_sym)).to_s
        record&.destroy!
      else
        (record || SettingValue.new(key:)).update!(value:)
      end
    end
end
