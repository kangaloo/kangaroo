#/usr/bin/expect
set timout 10
set password [lindex $argv 0]
set targetIp [lindex $argv 1]
spawn scp -o StrictHostKeyChecking=no -r /root/.ssh  $targetIp:/root/
expect "*password*"
send "$password\r"
interact
