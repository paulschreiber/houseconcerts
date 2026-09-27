import { Controller } from "@hotwired/stimulus";

// Disables submit buttons once a form is submitted, so a second click (e.g.
// while the request or a passkey prompt is still in flight) can't re-submit
// and trigger an error. Re-enabled if a passkey ceremony fails, since the
// page doesn't reload in that case and the user needs to be able to retry.
export default class extends Controller {
  static targets = ["submit"];

  disable() {
    this.submitTargets.forEach((button) => (button.disabled = true));
  }

  enable() {
    this.submitTargets.forEach((button) => (button.disabled = false));
  }
}
