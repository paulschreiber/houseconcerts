import { Controller } from "@hotwired/stimulus";

// A Markdown editor's live preview. When typing pauses, the form is
// submitted with its hidden Preview button, which posts to the preview
// action and targets the preview iframe, so the preview shows the unsaved
// text. Buttons that act on the saved text (the invite's Send Test) are
// disabled until the changes are saved, with testNotice as their tooltip.
export default class extends Controller {
  static targets = ["form", "previewButton", "testButton"];
  static values = { testNotice: String };

  connect() {
    this.refresh();
  }

  disconnect() {
    clearTimeout(this.timeout);
  }

  changed() {
    this.testButtonTargets.forEach((button) => {
      button.disabled = true;
      button.title = this.testNoticeValue;
    });
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => this.refresh(), 400);
  }

  refresh() {
    this.formTarget.requestSubmit(this.previewButtonTarget);
  }
}
