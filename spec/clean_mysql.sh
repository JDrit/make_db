mysql -uroot --password='RRewj#rds$gsFASD'  -e "show databases" | grep -v Database | grep -v mysql| grep -v information_schema| grep -v test | grep -v OLD |gawk '{print "drop database " $1 ";select sleep(0.1);"}' | mysql -uroot --password='RRewj#rds$gsFASD'
mysql -uroot --password='RRewj#rds$gsFASD' -e "delete from mysql.user where user != 'root';"
