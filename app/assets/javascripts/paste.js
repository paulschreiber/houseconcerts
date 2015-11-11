$(document).ready(function() {

	if ( $('#rsvp_first_name').length > 0 ) {
		$('#rsvp_first_name').on( 'paste', function(event) {
			var text = event.originalEvent.clipboardData.getData('text') ;
			var matches = text.match( /(.*) (.*) <([^>]+)>/ );
			if ( null !== matches ) {
				event.preventDefault();
				$('#rsvp_first_name').val( matches[1] );
				$('#rsvp_last_name').val( matches[2] );
				$('#rsvp_email').val( matches[3] );
			}
		});
	}

	if ( $('#person_first_name').length > 0 ) {
		$('#person_first_name').on( 'paste', function(event) {
			var text = event.originalEvent.clipboardData.getData('text') ;
			var matches = text.match( /(.*) (.*) <([^>]+)>/ );
			if ( null !== matches ) {
				event.preventDefault();
				$('#person_first_name').val( matches[1] );
				$('#person_last_name').val( matches[2] );
				$('#person_email').val( matches[3] );
			}
		});
	}
});

