$(document).ready(function() {

	function updateStripePrice() {
		var pricePerSeat = parseInt($('#rsvp_show_price').val(), 10);
		var seats = parseInt($('[type="radio"][name="rsvp[seats]"]:checked').val(), 10) || 0;
		var tag = document.getElementById('stripe-js');
		if (tag) {
			tag.setAttribute('data-amount', pricePerSeat * seats);
		}
	}

	if ( $('[type="radio"][name="rsvp[seats]"]').length > 0 ) {
		$('[type="radio"][name="rsvp[seats]"]').on( 'click', function(event) {
			updateStripePrice();
		});
	}

	if ( $('[name="rsvp[response]"]').length > 0 ) {
		$('[name="rsvp[response]"]').on( 'click', function(event) {
			if ( 'no' === this.value ) {
				$('.stripe-button-el').hide();
				$('[type="radio"][name="rsvp[seats]"]').prop('checked', false).attr('disabled', 'disabled');
			} else if ( 'yes' === this.value ) {
				$('.stripe-button-el').show();
				$('[type="radio"][name="rsvp[seats]"]').removeAttr('disabled');
				$('[type="radio"][name="rsvp[seats]"][value="1"]').prop('checked', true);
			}
			updateStripePrice();
		})
	}

});

