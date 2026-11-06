require "application_system_test_case"

# Removing a photo from the artist edit form goes through Turbo, so it runs in a
# real browser to check the form isn't reloaded.
class ArtistPhotoRemovalTest < ApplicationSystemTestCase
  setup do
    sign_in_as_admin
  end

  test "Remove takes the photo off the edit form and keeps unsaved changes" do
    artist = attach_photo(artists(:one))
    visit edit_madmin_artist_path(artist)
    fill_in "URL", with: "https://example.com/unsaved"

    accept_confirm("Are you sure you want to delete the photo for #{artist.name}?") { click_link "Remove" }

    assert_no_selector ".photo-field-current"
    assert_field "URL", with: "https://example.com/unsaved"
    assert_current_path edit_madmin_artist_path(artist)
    assert_not artist.reload.photo.attached?
  end
end
