$(document).ready(function () {
  $('input[name="rsvp[seats]"]').on("click", function (event) {
    $("#rsvp_response_yes").click();
  });

  $("#rsvp_response_no").on("click", function (event) {
    $('input[name="rsvp[seats]"]').prop("checked", false);
  });
});
