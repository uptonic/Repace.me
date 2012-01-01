/*#########################################################

TODO: 1) Investigate using Webkit transitions instead of JS
      for animations. Should be more fluid.
      
      2) Reset error text on upload screen, animation
      margins for download screen.
      
      3) Hook up reset link to run another file. Could be
      as simple as reloading the page.
      
      4) Move errors & notifications into an array.

#########################################################*/

$(function(){
  
  /* NOTIFICATIONS
  ------------------------------*/

  var errors = [];
  
  
  /* INITIALIZE
  ------------------------------*/
  
  $("input:file").uniform();
  
  var loading = $('#view_loading').hide();
  var views = $('section').hide();
  
  var view_intro = $('#view_intro').show();
  var view_upload = $('#view_upload');
  var view_convert = $('#view_convert');
  var view_download = $('#view_download');
  
  var upload_notice = $('#upload_notice')
  
  var download_notice = $('#download_notice').css('opacity',0);
  var download_arrow = $('#download_arrow').css('opacity',0);
  var download_link = $('#download_link').css('opacity',0);
  
  var start_over_link = $('#start_over_link').hide();
  
  /* HIDE INTRO
  ------------------------------*/
  
  $('#view_intro a.button').click(function(){
    view_intro.hide();
    view_upload.fadeIn();
  });
  
  
  /* FANCIFY SUBMIT BUTTONS
  ------------------------------*/
  
  // set active class on mousedown
  $('input[type=submit]').mousedown(function(){
    $(this).addClass('active')
  }).mouseup(function(){
    $(this).removeClass('active')
  });
  
  
  /* HANDLE FILE UPLOAD
  ------------------------------*/
  
  // sends uploaded file to Sinatra and handles response
  $('#upload_form').ajaxForm({ 
    dataType: 'json',
    clearForm: 'true',
    resetForm: 'true',
    beforeSerialize: function(){
      // check to see if there is a file to upload
      if($('#file').fieldValue() == ''){
        alert("Please select a file first!");
        return false;
      }
    },
    beforeSend: function(){
      view_upload.hide();
      loading.find('p').text("Uploading file...");
      loading.show();
    },
    success: function(response){
      loading.fadeOut(function(){
        
        $('#name').html(response.name);
        $('#duration').html(response.duration);

        var d = response.duration.split(":");

        $('#convert_hours').val(d[0]);
        $('#convert_minutes').val(d[1]);
        $('#convert_seconds').val(d[2]);
                
        views.hide();
        view_convert.fadeIn(function(){
          $('.autofocus:first').focus().select();
        });
        
      });
    },
    error: function(response){      
      loading.fadeOut(function(){
        upload_notice.html(response.responseText).addClass('error');
        view_upload.fadeIn();
      });
    }
  });
  
  
  /* RESPOND TO CONVERSION
  ------------------------------*/
  
  // sends conversion values to Sinatra and handles response
  $('#convert_form').ajaxForm({ 
    dataType: 'json',
    resetForm: 'true',
    beforeSend: function(){
      
      var h = $('#convert_hours').fieldValue();
      var m = $('#convert_minutes').fieldValue();
      var s = $('#convert_seconds').fieldValue();
      
      if(validate_range(h, [0,48]) && validate_range(m, [0,59]) && validate_range(s, [0,59])) {
        view_convert.hide();
        loading.find('p').text("Converting. This may take awhile...");
        loading.show();
      } else {
        alert("Please enter a valid time (HH:MM:SS).\rTotal time must be under 48 hours.");
        return false;
      }
    },
    success: function(response){
      loading.fadeOut(function(){
        views.hide();
        view_download.fadeIn(function(){
          download_link.animate({
            opacity: 1.0,
            marginTop: ['+=70', 'easeOutElastic']
          }, 1000, function(){
            start_over_link.delay(1200).fadeIn();
            download_notice.animate({opacity:1.0}, 300);
            download_arrow.animate({
              opacity: 1.0,
              right: '-=40'
            }, 300, 'easeOutQuad');
          });
        });
        
        download_link.attr('href',response.download);
      });
    },
    error: function(){
      loading.fadeOut(function(){
        alert(response.responseText);
      });
    }
  });
  
  $('#start_over_link').click(function(){    
    // take me back to the upload view
    views.hide();
    view_upload.fadeIn();
    
    // reset file field to default value
    $('span.filename').text($.uniform.options.fileDefaultText);
  
    var download_notice = $('#download_notice').css({'opacity':0});
    var download_arrow = $('#download_arrow').css({'opacity':0,'right':'-40px'});
    var download_link = $('#download_link').css({'opacity':0,'marginTop':'-70px'});
    var start_over_link = $('#start_over_link').hide();
  });
  
  $(":text").click(function(){
    // select the entire block of text
    this.select();
  });
});


/* HELPER FUNCTIONS
------------------------------*/

// Is the value in the range?
function validate_range(value, param) {
  return ( value != '' && value >= param[0] && value <= param[1] );
}