var can_load_next = true;
var is_loading = false;

function load(v) {
    var filter = v ? v : 'timeline';

    if (is_loading) {
        load_unread();
        return;
    }

    var onsuccess = function (res) {
        if (res.length == 0)
            return;

        $('div#timeline').append(
            $('<div>').append(filter).addClass('fn'));

        for (var i in res) {
            var item = res[i];
            var id = 'div#' + item.id;
            var twbase = 'http://twitter.com/';

            $("div#timeline").append(
                $('<div>').attr({ id : item.id }));

            if (item.retweeted_status != undefined)
                $(id).css("background-color", "#ffc");

            if (/pun[y|i]tan/.test(item.processed))
                $(id).css("background-color", "pink");

            $(id).append(
                $('<div>').append(
                    $('<img>').attr({ src : item.user.profile_image_url }).addClass('icon'),
                    $('<div>').append( "(", item.user.friends_count, "/", item.user.followers_count, ")")
                ).addClass('iconarea')
            );

            $(id).append(
                $('<div>').append(
                    $('<span>').append(
                        $('<a>').append(item.user.screen_name).attr({
                            href   : twbase + item.user.screen_name,
                            target : '_blank'
                        })
                    ),
                    $('<span>').append(item.processed)
                ).addClass('tweetholder')
            );

            $(id).append(
                $('<div>').addClass('via'));

            $(id + " > div.via").append(
                $('<span>').append('RT').addClass('rt'),
                $('<span>').append(' / '), $('<span>').append('Unofficial RT').addClass('unofficialrt'),
                $('<span>').append(' / '), $('<span>').append('Reply')        .addClass('reply'),
                $('<span>').append(' / '), $('<span>').append('Fav')          .addClass('fav'),
                $('<span>').append(' / '), $('<a>').append(item.created_at).attr({
                    href   : twbase + item.user.screen_name + "/status/" + item.id,
                    target : '_blank'
                }),
                $('<span>').append(' / '), $('<span>').append(item.source)
            );

            $(id).append(
                $('<div>').addClass('clear'));

            if (item.in_reply_to_status_id) {
                var target = item.in_reply_to_status_id + Math.floor(Math.random() * 10000);
                $("div#timeline").append(
                    $('<div>').addClass('in_reply_to_status_id').attr({
                        id : target
                    }).addClass(target));

                load_reply(item.in_reply_to_status_id, target);
            }

            expand_url(item.id);
        }
    };

    is_loading = true;
    $.get("/api/tweet/show/" + filter, function (res) {
        is_loading = false;
        onsuccess(res)
    }, 'json').error(function () {
        is_loading = false;
    });

    load_unread();
}

function load_unread() {
    $.get('/api/filter/unread', function (res) {
        $('div#tabs > div').remove();
        for (var i in res) {
            if (res[i] > 0)
                $('div#tabs').append($('<div>').append(i, " (", res[i], ") ").attr({id: "_" + i}));
        }
    }, 'json');
}

function statuses_update(status, in_reply_to_status_id) {
    var parameters = {
        status : status
    };

    if (in_reply_to_status_id)
        parameters["in_reply_to_status_id"] = in_reply_to_status_id;

    $.post('/twitter/statuses/update', parameters, function (res) {
        // noop
    }, 'json');
}

function load_reply(id, target) {
    $('div#' + target).append(function () {
        $.get("/twitter/statuses/show/" + id, function(res) {
            if ($('div#' + target).val() != '')
                return;

            $('div#' + target).append(
                $('<div>').append(
                    $('<img>').attr({
                        src : res[1].user.profile_image_url
                    }).addClass('icon')
                ).addClass('iconarea'),

                $('<div>').append(
                    $('<span>').append(res[1].text)).addClass('tweetholder'),

                $('<div>').addClass('clear')
            );
        }, 'json');
    });
}

function expand_url(id) {
    $('div#' + id + ' > div.tweetholder > span:nth-child(2) > a').append(function () {
        if ( /twitter\.com\/|buzztter.com\/|frepan\.org|nico\.ms\/lv|s\.nikkei\.com\/|tcrn.ch\/|nhk\.jp\//.test(this) )
            return;

        $.get('http://api.linknode.net/urlresolver?url=' + this, function (data) {
            var info;
            switch (data.status) {
                case 'not_html' :
                    info = data.content_type; break;
                case 'ok' :
                    info = data.title; break;
                default :
                    info = 'Error'; break;
            }

            $('div#' + id + ' > div.tweetholder').append(
                $('<div>').append( info, $('<br>'),
                    $('<a>').attr({ href : data.url, target : '_blank' }).append(data.url)
                ).addClass('expanded_url')
            );
        });
    });
}

/*
 * initializer goes here
 *
 */

// initial loading
$(function () {
    load();
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
            can_load_next = true;
        }, function() {
            can_load_next = false;
        }, {
            switch_path :
                '/static/iphone_switch.png',
            switch_on_container_path :
                '/static/iphone_switch_container_on.png',
            switch_off_container_path :
                '/static/iphone_switch_container_off.png'
        }
    );
})

/*
 * specific event binding goes here
 *
 */

// bind mouse event
$(window).scroll(function () {
    var d = $("div#next").offset().top
            - $(window).scrollTop()
            - $(window).height();

    if (d < 5 && can_load_next == true) {
        load_unread();
        var v = $('div#tabs div:first-child').attr('id');
        if (v != undefined)
            load(v.substr(1));
    }
});

// bind click event - retweet
$(function () {
    $('span.rt').live('click', function () {
        var id = this.parentNode.parentNode.id;
        lbdialog({
            content      : 'Retweet it?',
            cancelButton : { text : 'No' },
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
        $('textarea').val(new_text); $('textarea').focus();
    });
});

// bind click event - fav
$(function () {
    $('span.fav').live('click', function () {
        var id = this.parentNode.parentNode.id;
        lbdialog({
            content      : 'Fav it?',
            cancelButton : { text : 'No' },
            OKButton     : {
                text     : 'Yes',
                callback : function () {
                    lbdialog({ content : 'Done', autoDisappear : 3 });
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

        statuses_update(status, in_reply_to_status_id);

        $('#statuses_update textarea[name="status"]').val('');
        $('form#statuses_update').removeClass();
    };

    $('#statuses_update').submit(function () {
        lbdialog({
            content      : 'Do you want to update status?',
            cancelButton : { text : 'No' },
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
        }, function(res) {
            if (res.success == 1) {
                screen_name.val('');
                filter.val('');
                $('div#new_filter_box').append(
                    $('<div>').append('OK').fadeIn('slow').fadeOut('slow') );
            } else {
                $('div#new_filter_box').append(
                    $('<div>').append('ERROR').fadeIn('slow').fadeOut('slow') );
            }
        }, 'json');
    });
});

