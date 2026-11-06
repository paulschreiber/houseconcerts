require "application_system_test_case"

# Uploads a photo through the artist edit form in a real browser, so the form
# has to send the file.
class ArtistPhotoUploadTest < ApplicationSystemTestCase
  setup do
    sign_in_as_admin
  end

  test "a photo that's too small is refused, with a message for each side" do
    artist = artists(:one)
    visit edit_madmin_artist_path(artist)

    attach_file "Photo", file_fixture("tiny.jpg")
    click_button "Update Artist"

    assert_selector ".alert", text: "Please correct the following errors:"
    assert_selector ".alert li", text: "the photo must be at least 400 pixels wide"
    assert_selector ".alert li", text: "the photo must be at least 440 pixels tall"
    assert_no_selector "p.error"
    assert_not artist.reload.photo.attached?
  end
end
