require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "every enum validates its value" do
    Rails.application.eager_load!

    ApplicationRecord.descendants.each do |model|
      model.defined_enums.each_key do |name|
        assert model.validators_on(name).any?(ActiveModel::Validations::InclusionValidator), "#{model}##{name} isn’t validated"
      end
    end
  end

  test "an enum with its values as keywords validates its value" do
    model = Class.new(ApplicationRecord) do
      self.table_name = "people"
      enum :status, active: 0, removed: 3
    end

    assert_equal({ "active" => 0, "removed" => 3 }, model.statuses)
    assert model.validators_on(:status).any?(ActiveModel::Validations::InclusionValidator)
  end

  test "an enum without its own validate: option rejects an unknown value" do
    batch_run = BatchRun.new(show: shows(:upcoming), kind: "bogus")

    assert_not batch_run.valid?
    assert_includes batch_run.errors.attribute_names, :kind
  end
end
