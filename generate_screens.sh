#!/bin/bash

# List of graphs to use for screen creation
GRAPHS=( 'Free space' 'Cpu' 'Memory' 'Network' 'I/O sda', 'Running VMs')

# Parameters to pass to mysql, can be use to configure authentication
MYSQL_PARAMS=--defaults-file=/etc/mysql/debian.cnf 

# Mysql database to use
MYSQL_DB="zabbix"

IFS=
for graph in ${GRAPHS[*]};do
	FINAL_NAME=$(echo $graph|tr ' /' '_')
	TMP=/tmp/templates.$FINAL_NAME
	COLS=2
	CURRENT_COL=0 
	CURRENT_ROW=0 
	rm -f $TMP
	echo """<zabbix_export version=\"1.0\" date=\"20.02.12\" time=\"14.45\">
	  <screens>
	    <screen>
	      <screenitems>""" > $TMP
	while read host;do
		echo """	<screenitem>
		  <resourcetype>0</resourcetype>
		  <resourceid>
		    <host>$host</host>
		    <name>$graph</name>
		  </resourceid>
		  <width>500</width>
		  <height>100</height>
		  <x>$CURRENT_COL</x>
		  <y>$CURRENT_ROW</y>
		  <colspan>0</colspan>
		  <rowspan>0</rowspan>
		  <elements>0</elements>
		  <valign>0</valign>
		  <halign>0</halign>
		  <style>0</style>
		  <dynamic>0</dynamic>
		</screenitem>""" >> $TMP
		CURRENT_COL=$(( CURRENT_COL + 1 ))
		if [ $CURRENT_COL -eq $COLS ];then
		  CURRENT_ROW=$(( CURRENT_ROW + 1 ))
		  CURRENT_COL=0
		fi
	done < <( echo "select distinct h.host from hosts as h INNER JOIN items as i using(hostid) INNER JOIN graphs_items as gi using(itemid) INNER JOIN graphs as g using(graphid) where h.host not like '%Template%' and g.name='${graph}';"|mysql $MYSQL_PARAMS --skip-column-names $MYSQL_DB )
	echo $MYSQL_PARAMS
	echo """	</screenitems>
      <name>System overview : $graph</name>
      <hsize>$COLS</hsize>
      <vsize>$CURRENT_ROW</vsize>
    </screen>
  </screens>
</zabbix_export>""" >> $TMP
mv $TMP $FINAL_NAME.xml
echo "[*] Created $FINAL_NAME.xml"

done
