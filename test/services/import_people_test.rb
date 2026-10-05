require "test_helper"

class ImportPeopleTest < ActiveSupport::TestCase
  test "imports all three formats, mixed in one file" do
    data = <<~TEXT
      Jane Smith <jane.smith@example.com>
      John,Doe,john.doe@example.com
      Mary Jane\tWatson\tMJ@Example.com
    TEXT

    result = nil
    assert_difference("Person.count", 3) { result = ImportPeople.call(data) }

    assert_equal([ %w[Jane Smith jane.smith@example.com], %w[John Doe john.doe@example.com], [ "Mary Jane", "Watson", "mj@example.com" ] ],
                 result.added.map { |person| [ person.first_name, person.last_name, person.email ] })
    assert_empty result.skipped
    assert_empty result.invalid
  end

  test "handles quoted CSV fields, Windows line breaks, a byte order mark and blank lines" do
    data = "﻿\"Jane\",\"Smith\",\"jane.smith@example.com\"\r\n\r\nJohn,Doe,john.doe@example.com\r\n"

    assert_equal %w[jane.smith@example.com john.doe@example.com], ImportPeople.call(data).added.map(&:email)
  end

  test "skips anyone already on file, including someone who unsubscribed" do
    Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com", status: "removed")

    result = nil
    assert_no_difference("Person.count") { result = ImportPeople.call("Jane Smith <Jane.Smith@example.com>") }

    assert_equal([ [ 1, "Jane Smith <Jane.Smith@example.com>" ] ], result.skipped.map { |line| [ line.number, line.text ] })
    assert_predicate Person.find_by(email: "jane.smith@example.com"), :removed?
  end

  test "reports lines it can't parse, and people who fail validation, with line numbers" do
    result = ImportPeople.call("Jane Smith <jane.smith@example.com>\nnot a person\nJ,Doe,john.doe@example.com\n")

    assert_equal [ "jane.smith@example.com" ], result.added.map(&:email)
    assert_equal [ 2, 3 ], result.invalid.map(&:number)
    assert_equal "not in a recognized format", result.invalid.first.reason
    assert_predicate result.invalid.second.reason, :present?
  end

  test "rejects more than max_lines lines before importing anything" do
    data = "Jane Smith <jane.smith@example.com>\nJohn Doe <john.doe@example.com>\n"

    error = assert_raises(ImportPeople::Error) { ImportPeople.call(data, max_lines: 1) }
    assert_equal "2 lines is too many; the most is 1.", error.message
    assert_not Person.exists?(email: "jane.smith@example.com")
  end

  test "max_lines defaults to the import.max_lines setting" do
    assert_equal 1000, Settings.import.max_lines
  end

  test "rejects data that isn't text before importing anything" do
    assert_raises(ImportPeople::Error) { ImportPeople.call("Jane Smith <jane.smith@example.com>\n\x00\x01\x02") }
    assert_raises(ImportPeople::Error) { ImportPeople.call("\xFF\xFEnot utf-8".b) }
    assert_raises(ImportPeople::Error) { ImportPeople.call("\x89PNG\r\n\x1A\n".b, filename: "people.txt") }
    assert_not Person.exists?(email: "jane.smith@example.com")
  end

  test "accepts a .csv, .tsv or .txt file, in any case" do
    %w[people.csv people.tsv people.txt PEOPLE.TXT].each_with_index do |filename, i|
      assert_equal 1, ImportPeople.call("Jane Smith <jane#{i}@example.com>", filename:).added.size, filename
    end
  end

  test "rejects a file without a .csv, .tsv or .txt extension, even if it's text" do
    %w[people.xlsx people.md people].each do |filename|
      error = assert_raises(ImportPeople::Error) { ImportPeople.call("Jane Smith <jane.smith@example.com>", filename:) }
      assert_equal "#{filename} isn’t a .csv, .tsv or .txt file.", error.message
    end
    assert_not Person.exists?(email: "jane.smith@example.com")
  end

  test "handles display names in quotes, Last, First order, and a separator after the address" do
    data = <<~TEXT
      "Jane Smith" <jane.smith@example.com>
      Doe, John <john.doe@example.com>;
      Mary Jane Watson <mj@example.com>,
    TEXT

    assert_equal([ %w[Jane Smith], %w[John Doe], [ "Mary Jane", "Watson" ] ],
                 ImportPeople.call(data).added.map { |person| [ person.first_name, person.last_name ] })
  end

  test "reports an email listed twice in the file, not as already on file" do
    result = ImportPeople.call("Jane Smith <jane.smith@example.com>\nJane Smith <JANE.SMITH@example.com>\n")

    assert_equal 1, result.added.size
    assert_equal([ [ 2, "listed twice in this file" ] ], result.skipped.map { |line| [ line.number, line.reason ] })
  end

  test "treats old Mac line breaks as line breaks, for the line limit too" do
    data = "Jane Smith <jane.smith@example.com>\rJohn Doe <john.doe@example.com>\r"

    assert_equal 2, ImportPeople.call(data).added.size
    assert_raises(ImportPeople::Error) { ImportPeople.call("a\rb\rc", max_lines: 2) }
  end

  test "rejects more than max_bytes before importing anything" do
    error = assert_raises(ImportPeople::Error) { ImportPeople.call("Jane Smith <jane.smith@example.com>", filename: "people.txt", max_bytes: 10) }
    assert_equal "people.txt is too big; the most is 10 Bytes.", error.message
    assert_equal 1_048_576, Settings.import.max_bytes
  end
end
