import { Controller } from "@hotwired/stimulus";

// Parses a pasted "Firstname Lastname <email@example.com>" string into
// separate first name / last name / email fields.
export default class extends Controller {
  static targets = ["firstName", "lastName", "email"];

  parse(event) {
    const text = event.clipboardData.getData("text");
    const matches = text.match(/(\S+) (.*) <([^>]+)>/);

    if (matches !== null) {
      event.preventDefault();
      this.firstNameTarget.value = matches[1];
      this.lastNameTarget.value = matches[2];
      this.emailTarget.value = matches[3];
    }
  }
}
