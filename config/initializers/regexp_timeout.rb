# Cap how long any single regex match can run, so a pathological pattern
# fed crafted input (catastrophic backtracking) raises Regexp::TimeoutError
# instead of tying up a worker indefinitely.
Regexp.timeout = 1.0
