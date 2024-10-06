apt install ntp ntpdate -y
service ntp stop
ntpdate -bs ru.pool.ntp.org
service ntp start
