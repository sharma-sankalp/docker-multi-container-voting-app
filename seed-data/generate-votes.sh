#!/bin/sh

# create 3000 votes (2000 for option a, 1000 for option b)
vote_url="${VOTE_URL:-http://vote:8080}"
ab -n 1000 -c 50 -p posta -T "application/x-www-form-urlencoded" "${vote_url}/"
ab -n 1000 -c 50 -p postb -T "application/x-www-form-urlencoded" "${vote_url}/"
ab -n 1000 -c 50 -p posta -T "application/x-www-form-urlencoded" "${vote_url}/"
