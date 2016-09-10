a=$(ps -ef | grep -v grep | grep NPMCollector | awk '{print $2}')
kill -15 $a
