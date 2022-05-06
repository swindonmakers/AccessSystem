<script type="text/javascript"> 
  jQuery(function() {
    jQuery('#dob').datepicker({
     dateFormat: "yy-mm",
     changeMonth: true,
     changeYear: true,
     yearRange: "-17:-120"
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
  });
</script>
    
