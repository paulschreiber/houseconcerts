document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll('input[name="rsvp[seats_reserved]"]').forEach((item) =>
    item.addEventListener("click", function () {
      document.getElementById("rsvp_response_yes").checked = true;
    })
  );

  if (document.getElementById("rsvp_response_no")) {
    document.getElementById("rsvp_response_no").addEventListener("click", function () {
      document
        .querySelectorAll('input[name="rsvp[seats_reserved]"]')
        .forEach((item) => (item.checked = false));
    });
  }
});
