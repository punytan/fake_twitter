/* ===============================
| JQUERY.LIGHTBOXLIB.JS
| Copyright, Andy Croxall (mitya@mitya.co.uk)
| For documentation and demo see http://www.mitya.co.uk/scripts/Lightbox-and-lightbox-dialog-99
|
| USAGE
| This script may be used, distributed and modified freely but this header must remain in tact.
| For usage info and demo, including info on args and params, see www.mitya.co.uk/scripts
=============================== */


/* -------------------
 | CONFIG
 ------------------- */

lightboxConfig = {
	lbOpacity:	.6,
	lbBackground: '444',
	lbdialog_defaultHeight: 105, //default height of lightbox replcement dialog box (i.e. alert/confirm)
	lbdialog_allowCloseByClickingLightbox: false, //see notes at top
	lbdialog_css: {
		borderRadius: 10,
		width: 400,
		boxShadow: '0 0 32px #26a1ce'
	}
};


/* -------------------
 | PREP. Log whether IE6 and declare func used by lbdialog to allow closure via escsape key (need to declare as non-anonymouse
 | func so it can be unbound when lbdialog closes
 ------------------- */

var ie6 = navigator.appVersion.match(/MSIE 6\.0/);
var closeLBDialogOnEscapePress = function(e) { if (e.keyCode == 27) hidelightbox(); };


$(function() {
	
	/* -------------------
	| MAIN LIGHTBOX FUNC
	------------------- */
	
	jQuery.fn.lightbox = function(noFade, autoDisappear, noLightbox, noClose) {
	
		
	    //prep
		
	    var ac = arguments.callee;
	    $(this).addClass('lightbox_centralElement');
	    var centralElement = this.get(0);
	    $(centralElement).children().hide();
	    if (noLightbox) $('#lightbox').css({opacity: 0, filter: 'alpha(opacity=0)'})
		if (noClose) $('#lightbox').addClass('noClose');
	
	
	    //utility functions
	    
	    ac.doHide = function(noFade, callback) { //called on hide request
	        if (!noFade) {
	            var numChildren;
		        if ((numChildren = $(ac.centralElement).children().length) > 0) {
	                var childrenFaded = 0;
		    	    $(ac.centralElement).children().fadeOut('', function() {
	                    childrenFaded++;
	                    if (childrenFaded == numChildren) $(ac.centralElement).slideUp('fast', function() {
	                    	reinsertCentralElement();
	                    	$('#lightbox').fadeOut('fast', callback ? callback() : null);
                    	});
	                });
	            } else
		    	$(ac.centralElement).slideUp('fast', function() { $('#lightbox').fadeOut('fast', callback ? callback() : null); reinsertCentralElement(); });
	        } else {
	            $(ac.centralElement).hide();
	            $('#lightbox').hide();
	            if (callback) callback();
	            reinsertCentralElement();
	        }
	
		};
	
	    
	    //request to show
	    
	    if (centralElement.id != 'lightbox') {
	
	    	
	        //force central element to be child of body (lift it out of the DOM and re-insert). This ensures centering relative to body. After, put back where it was.	    	
	        
			var node_holder = $(centralElement).clone(true);
			var markerNodeForReinsertion = document.createElement('em');
			$(centralElement).before($(markerNodeForReinsertion));
			markerNodeForReinsertion.id = 'markerNodeForReinsertion';
			$(centralElement).remove();
			centralElement = document.body.insertBefore(node_holder.get(0), document.body.childNodes[0]);
			
			
			//assuming noClose not passed, close lighbox if any <button> or element with .close inside central element is clicked
			if (!noClose) $(centralElement).find('button, .close').not('.noLBClose, [rel=noLBClose]').click(function(e) { $('#lightbox').lightbox(); });
	
	        
	        //force position absolute and z-index 10001 if not set
	        
	        if ($(centralElement).css('position') != 'absolute') $(centralElement).css('position', 'absolute');
	        if ($(centralElement).css('zIndex') != 10001) $(centralElement).css('zIndex', 10001);
	
	        
	        //remember the central element so we can kill it on hide request
	        ac.centralElement = centralElement
	
	        
	        //centre it and ensure that, if user scrolls while LB open, central element moves with it
	        $(centralElement).centreElement();
			$(window).scroll(function() { $(centralElement).centreElement(); });
	
	    }
	
	
		//toggle show/hide lightbox
	    
	    if ($('#lightbox').is(":hidden")) { //hidden - so show pos as necessary)
	
			var callback = function() { $(centralElement).slideDown('fast', function() { $(centralElement).children(':not(:visible)').fadeIn(); }); };
			if (!noFade) $('#lightbox').fadeIn('fast', callback); else { $('#lightbox').show(); callback(); }
			if (autoDisappear) setTimeout(hidelightbox, autoDisappear * 1000)
	
	    } else //showing - so hide
	        ac.doHide();
	
	}



	/* -------------------
	| UTILITY: centre central element
	------------------- */
	
	jQuery.fn.centreElement = function(horiz, vert, justReturnValues) {
	
	    //prep
	    if (horiz == undefined) horiz = true;
	    if (vert == undefined) vert = true;
	    var scrollX = (document.documentElement.scrollLeft || document.body.scrollLeft || 0) || window.pageXOffset;
	    var scrollY = (document.documentElement.scrollTop || document.body.scrollTop || 0) || window.pageYOffset;
	    if (scrollX == undefined) scrollX = 0;
	    if (scrollY == undefined) scrollY = 0;
	    var el = this.get(0);
	
	    //calculate
	    var temp_elWidth = parseInt(el.currentStyle ? el.currentStyle.width : getComputedStyle(el, null).width);
	    if (isNaN(temp_elWidth)) { $(el).css('width', '300px'); temp_elWidth = 300; } //force default width if none set
	    var left = (self.innerWidth || (document.documentElement.clientWidth || document.body.clientWidth)) / 2 - (temp_elWidth / 2) + scrollX;
	
	    var temp_elHeight = parseInt(el.currentStyle ? el.currentStyle.height : getComputedStyle(el, null).height);
	    if (isNaN(temp_elHeight)) { $(el).css('height', '300px'); temp_elHeight = 300; } // " " "
	    var top = (self.innerHeight || (document.documentElement.clientHeight || document.body.clientHeight)) / 2 - (temp_elHeight / 2) + scrollY;
	
	    //account for padding
	    top -= parseInt(el.currentStyle ? el.currentStyle.paddingTop : getComputedStyle(el, null).paddingTop);
	    left -= parseInt(el.currentStyle ? el.currentStyle.paddingLeft : getComputedStyle(el, null).paddingLeft);
	
	    //return/effect
	    if (!justReturnValues) {
	        if (horiz) el.style.left = left+"px";
	        if (vert) el.style.top = top+"px";
	    } else {
	        if ((!horiz || horiz) && (!vert || vert))
	            return [left, top];
	        else if (!horiz || horiz)
	            return left;
	        else if (!vert || vert)
	            return vert;
	    }
	
	}


	/* -------------------
	| BUILD LIGHTBOX ONLOAD
	------------------- */

    //build
    var lightboxDiv = document.createElement('div');
    lightboxDiv.id = 'lightbox';
    $(lightboxDiv).click(function() {
    	if (
			!$(this).hasClass('noClose')
			&&
			(
				jQuery.fn.lightbox.centralElement.id != 'lightboxdialog'
				||
				lightboxConfig.lbdialog_allowCloseByClickingLightbox
			)
    	)
    		$(this).lightbox();
    });
    $(document.body).prepend(lightboxDiv);

    //style it (doing it here means the script is portable, don't need to tell users to add rules to their CSS sheets)
    $('#lightbox').css({
    	opacity: lightboxConfig.lbOpacity,
    	filter: 'alpha(opacity='+(lightboxConfig.lbOpacity * 100)+')',
    	width: $(document).width(),
    	height: $(document).height(),
    	background: '#'+lightboxConfig.lbBackground,
    	position: 'fixed',
    	left: 0,
    	top: 0,
    	zIndex: 10000,
    	display: 'none'
    });

});



/* -------------------
| UTILITY FUNC: supporting func - on lightbox close, reinsert central element into DOM at its original position
------------------- */

reinsertCentralElement = function() {
    var ce = jQuery.fn.lightbox.centralElement;
    try {
        markerNodeForReinsertion = $('#markerNodeForReinsertion').get(0);
        if (markerNodeForReinsertion.parentNode.tagName.toLowerCase() != "body") {
            var ceHolder = ce;
            ce.parentNode.removeChild(ce);
            markerNodeForReinsertion.parentNode.insertBefore(ceHolder, markerNodeForReinsertion);
            markerNodeForReinsertion.parentNode.removeChild(markerNodeForReinsertion);
        }
    } catch(e) {}
}



/* -------------------
| UTILITY FUNC: lightbox-utilising replacement for in-built alert/confirm methods. See usage notes at top of page.
------------------- */

lbdialog = function(params) {

	
    //checktype passed args before continuing
	
    if (
        typeof params.content != 'string'
        ||
            (params.okButton &&
                (typeof params.okButton.callback != 'function' && params.okButton.callback)
            )
        ||
            (params.cancelButton &&
                (typeof params.cancelButton.callback != 'function' && params.cancelButton.callback)
            )
        )
        return false;

    
    //clean up from any previous alert
    
    if ($('#lightboxdialog').length != 0) $('#lightboxdialog').remove();

    
    //create, style (with necessary CSS, params-passed CSS and config CSS at top of file) and append dialog box
    
    var box = document.createElement('div');
    with ($(box)) {
    	attr('id', 'lightboxdialog');
    	css({background: '#fff', position: 'absolute', padding: 15, width: 320, height: lightboxConfig.lbdialog_defaultHeight, display: 'none', textAlign: 'left'});
    	if (typeof params.css == 'object') $(box).css(params.css);
    	if (lightboxConfig.lbdialog_css) css(lightboxConfig.lbdialog_css);
    }
    $('body').prepend(box);

    
    //add content
    
    var fs = lightboxConfig.lbdialog_css.fontSize+'';
    if (!fs.match(/^\d$/)) fs += 'px'; 
    var header;
    if (params.error) header = ['ERROR', 'b00'];
	else if (params.success) header = ['SUCCESS', '0b0'];
	var header = header == undefined ? '' : "<h4 style='margin: 0 0 10px 0; color: #"+header[1]+"'>"+header[0]+"</h4>";
    $(box).html(header+'<p'+(fs ? " style='margin-bottom: 10px; font-size: "+fs+"'" : '')+'>'+params.content+"</p<div style='clear: both'></div>");

    
    //add buttons, unless params stipulate the dialog should close itself after X seconds. right button will always be put out,
    //whereas left button is only put out if params.cancelButton object is passed, i.e. is confirm, not alert. onclick, along
    //with effecting any callbacks passed, they will also close the lightbox unless  you pass 'noLBClose' in their object
    
    if (!params.autoDisappear) {
	    var buttons = ['OK', 'cancel'];
	    for(var e in buttons) {
	        if (buttons[e] == 'OK' || params.cancelButton) {
	            var but = document.createElement('button');
	            $(but).css({'float': buttons[e] == 'OK' ? 'right' : 'left'});
	            if (params[buttons[e]+'Button']) {
	                if (params[buttons[e]+'Button'].noLBClose) $(but).addClass('noLBClose');
	                var butText = params[buttons[e]+'Button'].text ? params[buttons[e]+'Button'].text : buttons[e];
	                if (params[buttons[e]+'Button'].callback) $(but).click(params[buttons[e]+'Button'].callback);
	            } else
	                var butText = buttons[e];
	            $(but).text(butText);
	            box.appendChild(but);
	        }
	    }
    }

    
    //centre and show
    $(box).lightbox(true, params.autoDisappear ? params.autoDisappear : null, params.noLightbox ? true : null);
    
    //lastly, close on keypress to <escape>
    $(document).bind('keypress', closeLBDialogOnEscapePress);

};


/* -------------------
| UTILITY FUNC: close lightbox and remove keypress bind to escape key
------------------- */

hidelightbox = function(noFade, callback) {
	jQuery.fn.lightbox.doHide(noFade, callback);
	$(document).unbind('keypress', closeLBDialogOnEscapePress);
};