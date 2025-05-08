document.addEventListener("DOMContentLoaded", function () {
  if (document.getElementById("rsvp_first_name")) {
    document.getElementById("rsvp_first_name").addEventListener("paste", function (event) {
      const text = event.clipboardData.getData("text");
      const matches = text.match(/(.*) (.*) <([^>]+)>/);
      if (null !== matches) {
        event.preventDefault();
        document.getElementById("rsvp_first_name").value = matches[1];
        document.getElementById("rsvp_last_name").value = matches[2];
        document.getElementById("rsvp_email").value = matches[3];
      }
    });
  }

  if (document.getElementById("person_first_name")) {
    document.getElementById("person_first_name").addEventListener("paste", function (event) {
      const text = event.clipboardData.getData("text");
      const matches = text.match(/(.*) (.*) <([^>]+)>/);
      if (null !== matches) {
        event.preventDefault();
        document.getElementById("person_first_name").value = matches[1];
        document.getElementById("person_last_name").value = matches[2];
        document.getElementById("person_email").value = matches[3];
      }
    });
  }

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
