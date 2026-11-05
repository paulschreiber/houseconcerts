namespace :artists do
  desc "Attach each artist's photo from public/photos/headshots, once (DRY_RUN=1 lists what would be attached)"
  task import_photos: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil)) || false
    result = ImportArtistPhotos.call(dry_run:)

    puts "#{dry_run ? 'Would attach' : 'Attached'} #{result.attached.size} photos"
    puts "Skipped #{result.skipped.size} artists who already have a photo" if result.skipped.any?
    puts "No photo file for: #{result.missing.map(&:name).to_sentence}" if result.missing.any?
    puts "No artist for: #{result.unmatched.map { |path| path.basename.to_s }.to_sentence}" if result.unmatched.any?
    result.failed.each { |artist, errors| puts "Couldn’t attach #{artist.name}’s photo: #{errors}" }
  end
end
