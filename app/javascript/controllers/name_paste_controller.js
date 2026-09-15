import { Controller } from "@hotwired/stimulus";

// Parses a pasted "Firstname Lastname <email@example.com>" string into
// separate first name / last name / email fields.
//
// Same regex (and the same tradeoff) is duplicated in
// lib/tasks/people.rake's import_subscribers task -- keep both in sync.
// The greedy first group always treats everything before the last space
// as the first name: correct for multi-word first names ("Mary Jane
// Watson" -> first="Mary Jane", last="Watson"), but a middle initial
// lands in the first name too ("John Q Public" -> first="John Q",
// last="Public", not first="John", last="Q Public").
export default class extends Controller {
  static targets = ["firstName", "lastName", "email"];

  parse(event) {
    const text = event.clipboardData.getData("text");
    const matches = text.match(/(.*) (.*) <([^>]+)>/);

    if (matches !== null) {
      event.preventDefault();
      this.firstNameTarget.value = matches[1];
      this.lastNameTarget.value = matches[2];
      this.emailTarget.value = matches[3];
    }
  }
}
