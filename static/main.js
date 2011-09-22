/*
 * initializer goes here
 *
 */

// initial loading
$(function () {
    FT.load();
});

// key bindings
$(function () {
    $(document).keydown(function (event) {
        if (event.which == 65) {        /* a */
            $('#can_load_next').click();
        } else if (event.which == 78) {  /* n */
            $('#next').click();
        } else if (event.which == 84) { /* t */
            $('textarea').focus();
        }
    });

    $('textarea, input').bind('keydown', function(event) {
        event.stopPropagation();
    });
});

// init plugins
$(function () {
    $("textarea").charCount();

    $('#can_load_next').iphoneSwitch("on",
        function() {
            FT.status.canLoadNext = true;
        }, function() {
            FT.status.canLoadNext = false;
        }, {
            switch_path :
                '/static/iphone_switch.png',
            switch_on_container_path :
                '/static/iphone_switch_container_on.png',
            switch_off_container_path :
                '/static/iphone_switch_container_off.png'
        }
    );
});

/*
 * specific event binding goes here
 *
 */

// bind mouse event
$(window).scroll(function () {
    var d = $("div#next").offset().top
        - $(window).scrollTop()
        - $(window).height();

    FT.loadUnread();
    if (d < 5 && FT.status.canLoadNext === true) {
        var v = $('div#tabs div:first-child').attr('id');
        if (v !== undefined)
            FT.load(v.substr(1));
    }
});

// bind click event - retweet
$(function () {
    $('span.rt').live('click', function () {
        var id = this.parentNode.parentNode.id;
        lbdialog({
            content      : 'Retweet it?',
            cancelButton : {
                text : 'No'
            },
            OKButton     : {
                text     : 'Yes',
                callback : function () {
                    $.post("/twitter/statuses/retweet/" + id, function(res) {
                        // TODO : check the result value
                    }, 'json');
                }
            }
        });
    });
});

// bind click event - unofficial retweet
$(function () {
    $('span.unofficialrt').live('click', function () {
        var id = this.parentNode.parentNode.id;
        var screen_name = $('div#' + id + ' > .tweetholder > span:first').text();
        var text        = $('div#' + id + ' > .tweetholder > span:last').text();
        var new_text    = ' RT @' + screen_name + ': ' + text;

        $('textarea').val(new_text);
        $('textarea').focus();
    });
});

// bind click event - reply
$(function () {
    $('span.reply').live('click', function () {
        var id = this.parentNode.parentNode.id;
        var screen_name = $('div#' + id + ' > .tweetholder > span:first').text();
        var text        = $('div#' + id + ' > .tweetholder > span:last').text();
        var new_text    = '@' + screen_name + ' ';

        $('form#statuses_update').removeClass().addClass(id);
        $('textarea').val(new_text);
        $('textarea').focus();
    });
});

// bind click event - fav
$(function () {
    $('span.fav').live('click', function () {
        var id = this.parentNode.parentNode.id;
        lbdialog({
            content      : 'Fav it?',
            cancelButton : {
                text : 'No'
            },
            OKButton     : {
                text     : 'Yes',
                callback : function () {
                    lbdialog({
                        content : 'Done',
                        autoDisappear : 3
                    });
                    $.post("/twitter/favorites/create/" + id, function(res) {
                        // TODO : check the result value
                    }, 'json');
                }
            }
        });
    });
})

// bind submit event - statuses update
$(function () {
    var execute_statuses_update = function () {
        var status = $('#statuses_update textarea[name="status"]').val();
        var in_reply_to_status_id = $('form#statuses_update').attr('class') || undefined;

        FT.statusesUpdate(status, in_reply_to_status_id);;

        $('#statuses_update textarea[name="status"]').val('');
        $('form#statuses_update').removeClass();
    };

    $('#statuses_update').submit(function () {
        lbdialog({
            content      : 'Do you want to update status?',
            cancelButton : {
                text : 'No'
            },
            OKButton     : {
                text     : 'Yes',
                callback : execute_statuses_update
            }
        });
    });
});

// bind submit event - create new filter
$(function () {
    $("#new_filter").submit(function () {
        var screen_name = $('#new_filter_box input[name="screen_name"]');
        var filter      = $('#new_filter_box input[name="filter"]');

        $.post("/api/filter", {
            screen_name : screen_name.val(),
            filter : filter.val()
        }).success(function(res) {
            if (res.success == 1) {
                screen_name.val('');
                filter.val('');
                $('div#new_filter_box').append(
                    $('<div>').append('OK').fadeIn('slow').fadeOut('slow') );
            } else {
                $('div#new_filter_box').append(
                    $('<div>').append('ERROR').fadeIn('slow').fadeOut('slow') );
            }
        });
    });
});

$(function () {
    $("#add_ignore_word").submit(function () {
        var word = $('#ignore_word_box input[name="word"]');
        FT.ignoreWords.push(word.val());
        word.val('');
        $('div#ignore_word_box').append(
            $('<div>').append('OK').fadeIn('slow').fadeOut('slow') );
    });
});
