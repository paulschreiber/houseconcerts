import { Controller } from "@hotwired/stimulus";

// A file drop area. The file input covers the whole area (invisibly), so
// dropping a file on it, or clicking it, goes to the input natively (either
// way the input fires "change"); this highlights the area while a file is
// dragged over it, and shows when a file has been chosen, with its name.
export default class extends Controller {
  static targets = ["input", "label"];

  connect() {
    this.prompt = this.labelTarget.textContent;
  }

  highlight() {
    this.element.classList.add("drop-zone--active");
  }

  unhighlight() {
    this.element.classList.remove("drop-zone--active");
  }

  showFilename() {
    const file = this.inputTarget.files[0];
    this.element.classList.toggle("drop-zone--has-file", Boolean(file));
    this.labelTarget.textContent = file ? `✓ ${file.name}, ready to import` : this.prompt;
  }
}
