#!/bin/bash
infocmp xterm-kitty > /tmp/xterm-kitty-terminfo
tic -x -o ~/.terminfo /tmp/xterm-kitty-terminfo
