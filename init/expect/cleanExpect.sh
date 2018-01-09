#/usr/bin/expect
set timout 10
set password [lindex $argv 0]
set targetIp [lindex $argv 1]
set targetHome [lindex $argv 2]
spawn ssh -o StrictHostKeyChecking=no $targetIp "rm -fr $targetHome/.ssh"
expect "*password*"
send "$password\r"
interact
