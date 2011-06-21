FT = {};

(function () {

FT.status = {
    isLoading   : false,
    canLoadNext : true
};

FT.expandURL = function (id) {
    $('div#' + id + ' > div.tweetholder > span:nth-child(2) > a').append(function () {
        if ( /twitter\.com\/|buzztter.com\/|nico\.ms\/lv|s\.nikkei\.com\/|tcrn.ch\/|nhk\.jp\/|tvtwi\.com\/|metacpan\.org\//.test(this) )
            return;

        $.get('http://api.linknode.net/urlresolver?url=' + encodeURIComponent(this), function (data) {
            var info;
            switch (data.status) {
                case 'not_html' :
                    info = data.content_type;
                    break;
                case 'ok' :
                    info = data.title;
                    break;
                default :
                    info = 'Error';
                    break;
            }

            $('div#' + id + ' > div.tweetholder').append(
                $('<div>').append(
                    info,
                    $('<br>'),
                    $('<a>').attr({
                        href : data.url,
                        target : '_blank'
                    }).append(data.url)
                ).addClass('expanded_url')
            );
        });
    });
};

FT.loadUnread = function (res) {
    $.getJSON('/api/filter/unread').success(function (res) {
        $('div#tabs > div').remove();
        for (var i in res) {
            if (res[i] > 0) {
                $('div#tabs').append(
                    $('<div>').append(
                        i, " (", res[i], ") "
                    ).attr({
                        id : "_" + i
                    })
                );
            }
        }
    });
};

FT.load = function (f) {
    var filter = f ? encodeURIComponent(f) : 'timeline',
        url    = "/api/tweet/show/" + filter;

    if (FT.status.isLoading) {
        FT.loadUnread();
        return;
    }

    FT.status.isLoading = true;
    $.getJSON(url).success(function (res) {
        FT.status.isLoading = false;

        if (res.length == 0)
            return;

        $('div#timeline').append(
            $('<div>').append(filter).addClass('fn'));

        var twbase = 'http://twitter.com/';
        for (var i = 0; i < res.length; i++) {
            var item   = res[i],
                id     = 'div#' + item.id;

            $("div#timeline").append(
                $('<div>').attr({
                    id : item.id
                }));

            if (item.retweeted_status !== undefined)
                $(id).css("background-color", "#ffc");

            if (/pun[y|i]tan/.test(item.processed))
                $(id).css("background-color", "pink");

            $(id).append(
                $('<div>').append(
                    $('<img>').attr({ src : item.user.profile_image_url }).addClass('icon'),
                    $('<div>').append( "(", item.user.friends_count, "/", item.user.followers_count, ")")
                ).addClass('iconarea'),

                $('<div>').append(
                    $('<span>').append(
                        $('<a>').append(item.user.screen_name).attr({
                            href   : twbase + item.user.screen_name,
                            target : '_blank'
                        })),
                    $('<span>').append(item.processed)
                ).addClass('tweetholder'),

                $('<div>').append(
                    $('<span>').append('RT').addClass('rt'),
                    $('<span>').append(' / '), $('<span>').append('Unofficial RT').addClass('unofficialrt'),
                    $('<span>').append(' / '), $('<span>').append('Reply')        .addClass('reply'),
                    $('<span>').append(' / '), $('<span>').append('Fav')          .addClass('fav'),
                    $('<span>').append(' / '), $('<a>').append(item.created_at).attr({
                        href   : twbase + item.user.screen_name + "/status/" + item.id,
                        target : '_blank'
                    }),
                    $('<span>').append(' / '), $('<span>').append(item.source)
                ).addClass('via'),

                $('<div>').addClass('clear')
            );

            if (item.in_reply_to_status_id) {
                var id = item.in_reply_to_status_id;
                var target = id + Math.floor(Math.random() * 10000);

                $("div#timeline").append(
                    $('<div>').addClass('in_reply_to_status_id').attr({
                        id : target
                    }).addClass(target));

                $('div#' + target).append(function () {
                    $.getJSON("/twitter/statuses/show/" + id).success(function(res) {
                        if ($('div#' + target).val() != '')
                            return;

                        $('div#' + target).append(
                            $('<div>').append(
                                $('<img>').attr({
                                    src : res[1].user.profile_image_url
                                }).addClass('icon')
                            ).addClass('iconarea'),

                            $('<div>').append(
                                $('<span>').append(res[1].text)
                            ).addClass('tweetholder'),

                            $('<div>').addClass('clear')
                        );
                    });
                });
            }

            FT.expandURL(item.id);
        }

    }).error(function () {
        FT.status.isLoading = false;
        return;
    });
};

FT.statusesUpdate = function (status, in_reply_to_status_id) {
    var parameters = {
        status : status
    };

    if (in_reply_to_status_id)
        parameters["in_reply_to_status_id"] = in_reply_to_status_id;

    $.post('/twitter/statuses/update', parameters, function (res) {
        // noop
    }, 'json');
};

})();

