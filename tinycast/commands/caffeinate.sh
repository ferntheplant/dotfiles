#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Caffeinate
# @raycast.mode inline

# Optional parameters:
# @raycast.icon ☕️

# Documentation:
# @raycast.description Toggle keep-awake: stop display and idle sleep until you run it again
# @raycast.author fjorn
# @raycast.authorURL https://github.com/ferntheplant

# The pid file marks the caffeinate process that this command started, so the
# toggle never stops a caffeinate process that another app started.
pid_file="${TMPDIR:-/tmp}/tinycast-caffeinate.pid"

if [ -f "$pid_file" ]; then
	pid=$(cat "$pid_file")
	if [ "$(ps -p "$pid" -o comm= 2>/dev/null)" = "/usr/bin/caffeinate" ]; then
		kill "$pid"
		rm -f "$pid_file"
		echo "😴 Decaffeinated"
		exit 0
	fi
	rm -f "$pid_file"
fi

# Start caffeinate in its own session, so it keeps running after Tinycast ends
# this script and its process group. The child calls setsid and then execs
# caffeinate. The exec closes the pipe, so the parent waits for the setsid to
# finish before it writes the pid file and exits.
perl -MPOSIX -e '
	my $pid_file = shift @ARGV;
	pipe(my $r, my $w) or die "pipe: $!";
	my $pid = fork() // die "fork: $!";
	if ($pid == 0) {
		close $r;
		POSIX::setsid();
		exec @ARGV or POSIX::_exit(1);
	}
	close $w;
	1 while sysread($r, my $buf, 1);
	open(my $f, ">", $pid_file) or die "pid file: $!";
	print $f "$pid\n";
' "$pid_file" /usr/bin/caffeinate -di </dev/null >/dev/null 2>&1
echo "☕️ Caffeinated"
