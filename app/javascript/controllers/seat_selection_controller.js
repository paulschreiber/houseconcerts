import { Controller } from "@hotwired/stimulus";

// Choosing a seat count implies "yes"; choosing "no" clears any selected seat count.
export default class extends Controller {
  static targets = ["seat", "yes"];

  selectYes() {
    this.yesTarget.checked = true;
  }

  clearSeats() {
    this.seatTargets.forEach((seat) => {
      seat.checked = false;
    });
  }
}
