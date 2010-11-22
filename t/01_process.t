use common::sense;
use Test::More;
use Text::Twitter;

my $tweet = { text => 'foo' };
ok Text::Twitter::process($tweet) eq 'foo', 'basic tweet';

my $rt = {
    retweeted_status => {
        text => 'foo',
        user => { screen_name => 'bar' },
    },
};
ok Text::Twitter::process($rt)
    eq 'RT @<a href="http://twitter.com/bar" target="_blank">bar</a>: foo', 'basic RT';

my $basic_url = { text => 'http://google.com' };
ok Text::Twitter::process($basic_url)
    eq q{<a href="http://google.com" target="_blank">http://google.com</a>}, 'basic URL';

my $basic_reply = { text => '@foo bar' };
ok Text::Twitter::process($basic_reply)
    eq q{@<a href="http://twitter.com/foo" target="_blank">foo</a> bar}, 'basic reply';

my $basic_hash = { text => '#foo bar' };
ok Text::Twitter::process($basic_hash)
    eq q{<a href="http://search.twitter.com/search?q=%23foo" target="_blank">#foo</a> bar}, 'basic hash';

my $basic_com = { text => 'foo [co77] bar'};
ok Text::Twitter::process($basic_com)
    eq q{foo <img src="http://icon.nimg.jp/community/s/co77.jpg" class="thumb_mini" /> bar}, 'basic com';

my $web_yfrog = { text => 'prepared: http://yfrog.com/2s9i0xj' };
ok Text::Twitter::process($web_yfrog)
    eq q{prepared: <img src="http://yfrog.com/2s9i0xj.th.jpg" class="thumb" /><a href="http://yfrog.com/2s9i0xj" target="_blank">http://yfrog.com/2s9i0xj</a>}, 'web yfrog';

my $web_twitpic = { text => 'PLAYERZ!! http://twitpic.com/37mbup' };
ok Text::Twitter::process($web_twitpic)
    eq q{PLAYERZ!! <img src="http://twitpic.com/show/thumb/37mbup" class="thumb" /><a href="http://twitpic.com/37mbup" target="_blank">http://twitpic.com/37mbup</a>}, 'web twitpic';

my $web_movapic = { text => 'v http://movapic.com/pic/201011172244194ce3dc3311c79' };
ok Text::Twitter::process($web_movapic)
    eq q{v <img src="http://image.movapic.com/pic/m_201011172244194ce3dc3311c79.jpeg" class="thumb" /><a href="http://movapic.com/pic/201011172244194ce3dc3311c79" target="_blank">http://movapic.com/pic/201011172244194ce3dc3311c79</a>}, 'web movapic';

my $web_gyazo = { text => '!http://gyazo.com/e872e7277689674cbc7744052e46acf0.png' };
ok Text::Twitter::process($web_gyazo)
    eq q{!<img src="http://gyazo.com/e872e7277689674cbc7744052e46acf0.png" class="thumb" /><a href="http://gyazo.com/e872e7277689674cbc7744052e46acf0.png" target="_blank">http://gyazo.com/e872e7277689674cbc7744052e46acf0.png</a>}, 'web gyazo';

my $web_nico = { text => 'http://nico.ms/sm9 http://www.nicovideo.jp/watch/sm9' };
ok Text::Twitter::process($web_nico)
    eq q{<img src="http://tn-skr2.smilevideo.jp/smile?i=9" class="thumb" /><a href="http://www.nicovideo.jp/watch/sm9" target="_blank">http://nico.ms/sm9</a> <img src="http://tn-skr2.smilevideo.jp/smile?i=9" class="thumb" /><a href="http://www.nicovideo.jp/watch/sm9" target="_blank">http://www.nicovideo.jp/watch/sm9</a>}, 'web nico';

my $web_instagram = { text => 'AirBnB http://instagr.am/p/O4mh/' };
ok Text::Twitter::process($web_instagram)
    eq q{AirBnB <img src="http://api.linknode.net/instagram/O4mh" class="thumb" /><a href="http://instagr.am/p/O4mh" target="_blank">http://instagr.am/p/O4mh/</a>}, 'web instagram';

my $web_plixi = { text => 'language! http://plixi.com/p/57448825' };
ok Text::Twitter::process($web_plixi)
    eq q{language! <img src="http://api.plixi.com/api/TPAPI.svc/imagefromurl?size=medium&url=http://plixi.com/p/57448825" class="thumb" /><a href="http://plixi.com/p/57448825" target="_blank">http://plixi.com/p/57448825</a>}, 'web plixi';

my $web_twipple = { text => 'language! http://p.twipple.jp/myhP4' };
ok Text::Twitter::process($web_twipple)
    eq q{language! <img src="http://p.twipple.jp/data/m/y/h/P/4_m.jpg" class="thumb" /><a href="http://p.twipple.jp/myhP4" target="_blank">http://p.twipple.jp/myhP4</a>}, 'web twipple';

done_testing;

