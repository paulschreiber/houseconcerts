import { Controller } from "@hotwired/stimulus";

// The invite editor's live preview. When typing pauses, the form is
// submitted with its hidden Preview button, which posts to the preview
// action and targets the preview iframe, so the preview shows the unsaved
// text. Send Test sends the saved revision, so it's disabled until the
// changes are saved.
export default class extends Controller {
  static targets = ["form", "previewButton", "testButton"];

  connect() {
    this.refresh();
  }

  disconnect() {
    clearTimeout(this.timeout);
  }

  changed() {
    this.testButtonTargets.forEach((button) => {
      button.disabled = true;
      button.title = "Save the invite first";
    });
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => this.refresh(), 400);
  }

  refresh() {
    this.formTarget.requestSubmit(this.previewButtonTarget);
  }
}
