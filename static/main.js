var can_load_next = true;

function load(v) {
    var filter = v ? v : 'timeline';
    $.ajax({
        url: "/api/tweet/show/" + filter,
        data: {},
        type: 'get',
        dataType: 'json',
        success: function (r) {
            $('div#timeline').append(
                $('<div>').append(filter).addClass('fn'));

            var twbase = 'http://twitter.com/';
            //console.log(r);
            for (var i in r) {
                var id = r[i].id;

                $("div#timeline").append( $('<div>').attr({id:id}) );

                if (r[i].retweeted_status != undefined) $("div#" + id).css("background-color", "#ffc");
                if (/pun[y|i]tan/.test(r[i]["processed"])) $("div#" + id).css("background-color", "pink");

                $("div#" + id).append(
                    $('<div>').append(
                        $('<img>').attr({src: r[i].user.profile_image_url}).addClass('icon'),
                        $('<div>').append("(", r[i].user.friends_count, "/", r[i].user.followers_count, ")")
                    ).addClass('iconarea')
                );

                $("div#" + id).append(
                    $('<div>').append(
                        $('<span>').append(
                            $('<a>').append(r[i].user.screen_name).attr(
                                {href: twbase + r[i].user.screen_name, 'target': '_blank'})),
                        $('<span>').append(r[i].processed)
                    ).addClass('tweetholder')
                );

                $("div#" + id).append( $('<div>').addClass('via') );

                $("div#" + id + " > div.via").append(
                    $('<span>').append('RT').addClass('rt'),                      $('<span>').append(' / '),
                    $('<span>').append('Unofficial RT').addClass('unofficialrt'), $('<span>').append(' / '),
                    $('<span>').append('Reply').addClass('reply'),                $('<span>').append(' / '),
                    $('<span>').append('Fav').addClass('fav'),                    $('<span>').append(' / '),

                    $('<a>').append(r[i].created_at).attr(
                        {href: twbase + r[i].user.screen_name + "/status/" + r[i].id, 'target': '_blank'}),
                    $('<span>').append(' / '),

                    $('<span>').append(r[i].source)
                );

                $("div#" + id).append( $('<div>').addClass('clear') );

                if (r[i].in_reply_to_status_id) {
                    var target = r[i].in_reply_to_status_id + Math.floor(Math.random() * 10000);
                    $("div#timeline").append(
                        $('<div>').addClass('in_reply_to_status_id').attr(
                            {id:target}).addClass(target));
                    load_reply(r[i].in_reply_to_status_id, target);
                }
            }

            if (r.length == 0) $("div#timeline").append($('<div>').append("no item"));
        }
    });
    load_unread();
}

function load_unread() {
    $.ajax({
        url: '/api/filter/unread',
        data : {},
        type: 'get',
        dataType: 'json',
        success: function (r) {
            $('div#tabs > div').remove();
            for (var i in r) {
                if (r[i] > 0) {
                    $('div#tabs').append(
                        $('<div>').append(i, " (", r[i], ") ").attr({id: "_" + i}));
                }
            }
        }
    });
}

function statuses_update(status) {
    $.ajax({
        url: '/twitter/statuses/update',
        data : { status : status },
        type: 'post',
        dataType: 'json',
        success: function (r) {
            //console.log(r);
        }
    });
}

function load_reply(id, target) {
    $('div#' + target).append(function () {
        $.ajax({
            url: "/twitter/statuses/show/" + id,
            data: { },
            type: 'get',
            dataType: 'json',
            success: function(r) {
                //console.log($('div#' + id).val() );
                if ($('div#' + target).val() != '') return;
                $('div#' + target).append(
                    $('<div>').append(
                        $('<img>').attr({src: r[1].user.profile_image_url}).addClass('icon')).addClass('iconarea'),
                    $('<div>').append(
                        $('<span>').append(r[1].text)).addClass('tweetholder'),
                    $('<div>').addClass('clear')
                );
            }
        });
    });
}

$(window).scroll(function () {
    var d = $("div#timeline > div:last").offset().top
            - $(window).scrollTop()
            - $(window).height();

    if (d < 5 && can_load_next == true) {
        load_unread();
        var v = $('div#tabs div:first-child').attr('id');
        if (v != undefined) load(v.substr(1));
    }
});

$(function () {
    load();

    $("textarea").charCount();

    $('#can_load_next').iphoneSwitch("on",
        function() { can_load_next = true;  },
        function() { can_load_next = false; },
        {
            switch_path:               '/static/iphone_switch.png',
            switch_on_container_path:  '/static/iphone_switch_container_on.png',
            switch_off_container_path: '/static/iphone_switch_container_off.png'
        }
    );

    $('div#next').click(function () {
        var v = $('div#tabs div:first-child').attr('id');
        if (v != undefined) load(v.substr(1));
        load_unread();
    });

    $('span.fav').live('click', function () {
        var id = this.parentNode.parentNode.id;
        lbdialog({
            content: 'Fav it?',
            cancelButton: {
                text: 'No'
            },
            OKButton: {
                text: 'Yes',
                callback: function () {
                    lbdialog({content: 'done', autoDisappear: 3});
                    $.ajax({
                        url: "/twitter/favorites/create/" + id,
                        data: { },
                        type: 'post',
                        dataType: 'json',
                        success: function(r) {
                            //console.log(r);
                        }
                    });
                }
            }
        });
    });

    $('span.rt').live('click', function () {
        var id = this.parentNode.parentNode.id;
        lbdialog({
            content: 'Retweet it?',
            cancelButton: {
                text: 'No'
            },
            OKButton: {
                text: 'Yes',
                callback: function () {
                    $.ajax({
                        url: "/twitter/statuses/retweet/" + id,
                        data: { },
                        type: 'post',
                        dataType: 'json',
                        success: function(r) {
                            //console.log(r);
                        }
                    });
                }
            }
        });
    });

    $('span.reply').live('click', function () {
        var id = this.parentNode.parentNode.id;
        var screen_name = $('div#' + id + ' > .tweetholder > span:first').text();
        var text        = $('div#' + id + ' > .tweetholder > span:last').text();
        var new_text    = '@' + screen_name + ' ';

        $('textarea').val(new_text); $('textarea').focus();
    });

    $('span.unofficialrt').live('click', function () {
        var id = this.parentNode.parentNode.id;
        var screen_name = $('div#' + id + ' > .tweetholder > span:first').text();
        var text        = $('div#' + id + ' > .tweetholder > span:last').text();
        var new_text    = ' RT @' + screen_name + ': ' + text;

        $('textarea').val(new_text); $('textarea').focus();
    });

    $('#statuses_update').submit(function () {
        lbdialog({
            content: 'Do you want to update status?',
            cancelButton: {
                text: 'No'
            },
            OKButton: {
                text: 'Yes',
                callback: function () {
                    statuses_update( $('#statuses_update textarea[name="status"]').val() );
                    $('#statuses_update textarea[name="status"]').val('')
                }
            }
        });
    });

    $("#new_filter").submit(function () {
        var screen_name = $('#new_filter_box input[name="screen_name"]');
        var filter      = $('#new_filter_box input[name="filter"]');

        $.ajax({
            url: "/api/filter",
            data: {
                screen_name : screen_name.val(),
                filter : filter.val()
            },
            type: 'post',
            dataType: 'json',
            success: function(r) {
                if (r.success == 1) {
                    screen_name.val('');
                    filter.val('');
                    $('div#new_filter_box').append(
                        $('<div>').append('OK').fadeIn('slow').fadeOut('slow') );
                } else {
                    $('div#new_filter_box').append(
                        $('<div>').append('ERROR').fadeIn('slow').fadeOut('slow') );
                }
            }
        });
    });

    $(document).keydown(function (event) {
        if (event.which == 65) {        /* a */
            $('#can_load_next').click();
        } else if (event.which == 78) {  /* n */
            $('#next').click();
        } else if (event.which == 84) { /* t */
            $('textarea').focus();
        } else {
        }
    });

    $('textarea').bind('keydown', function(e) { e.stopPropagation(); });
    $('input').bind('keydown',    function(e) { e.stopPropagation(); });

});

