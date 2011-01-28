#!/bin/sh

plackup -s Twiggy -p 2222 bin/app.psgi -E deployment --access-log log/server.log 2> log/server.err &

