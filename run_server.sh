#!/bin/sh

plackup -s Twiggy -p 2222 bin/app.psgi -r > log/server 2>&1 &

