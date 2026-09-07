import { Controller } from "@hotwired/stimulus";

// Disables the form's submit button immediately on submit, so a rapid
// double-click can't fire the same action (e.g. "Send Invites", "Retry")
// twice before the first request's response -- always a full page
// redirect here -- replaces the page. The button never needs
// re-enabling here: that response always reloads the page with a
// fresh, enabled one.
export default class extends Controller {
  disable(event) {
    const button = event.target.querySelector("button, input[type=submit]");
    if (button) {
      button.disabled = true;
    }
  }
}
