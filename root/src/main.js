<script type="text/javascript"> 
  jQuery(function() {
    jQuery('#dob').datepicker({
     dateFormat: "yy-mm",
     changeMonth: true,
     changeYear: true,
     yearRange: "-99:-17"
    });

    jQuery('#payment_button').click(function() {
      jQuery('.payment_hide').toggle();
    });

    jQuery('.payment').change(function() {
      jQuery.get({
        url: "[% c.uri_for('get_dues') %]",
        data:jQuery('#register-form').serialize(),
        success: function(data,status) {
          jQuery('#payment_override').val(data);
        }
      });
    });

    jQuery('#associated_button').click(function() {
      jQuery('.associated_hide').toggle();
    });

    // Caution: magic number(s) based on ordering
    jQuery('.door_colour').prop('disabled', true);
    if (jQuery('#tier\\.3').is(':checked')) {
      jQuery('.door_colour').prop('disabled', false);
    }
    jQuery('[name=tier]').change(function() {
      if (jQuery('#tier\\.3').is(':checked')) {
        jQuery('.door_colour').prop('disabled', false);
      } else {
        if (jQuery('#tier\\.6').is(':checked')) {
          jQuery('.donor_hide').hide();
        } else {
          jQuery('.donor_hide').show();
        }
        jQuery('.door_colour').prop('checked', false);
        jQuery('#door_colour\\.0').prop('checked', true);
        jQuery('.door_colour').prop('disabled', true);
      }
    });
  });
</script>
    
