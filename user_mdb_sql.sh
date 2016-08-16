#/bin/sh

localhost_ip=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1 | grep -v 192.168 |grep -v inet6|awk '{print $2}'|tr -d "addr:"`
user_port=33455;
route_port=36000;
user_sql_file=./_bat_user_mdb.sql
route_sql_file=./_bat_route_mdb.sql

PRICE_PLAN_ARRAY=(99900101 99900105)
PRICE_PKG_ARRAY=(7001388 7001390)

PRICE_COUNT=${#PRICE_PLAN_ARRAY[@]}

SQL_COUNT_ARRY=($1)

check_serv()
{
	port=$1;
	i=0;
	while [ $i -lt $2 ]
	do
		if [ `netstat -an | grep $port | grep LISTEN | wc -l` -lt 1 ];then
			sleep 1;
		fi
		i=$[i+1];
	done
	
	if [ `netstat -an | grep $port | grep LISTEN | wc -l` -lt 1 ];then
		echo "[error] serv[$port]  not startup !";
		exit 0 ;
	fi
}

check_mdb()
{
	check_serv $1 3;
	echo "mdb serv start ok";
	
#mdb_change_role
mdb_change_role $localhost_ip $1 << EOF
	2
	3
	exit;
EOF

	echo "mdb_change_role $1 ok";
}

function clean_db_data(){
check_mdb $route_port;
mdb_client $localhost_ip $route_port << EOF
delete from CSysRtIdentity;
delete from CSysRtResource;
delete from CSysRtAccount;
exit;
EOF

check_mdb $user_port;
mdb_client $localhost_ip $user_port << EOF
delete from CIdentity;
delete from CUser;
delete from CUserAcctRel;
delete from CAccount;
delete from CUserProm;
exit;
EOF
}

function echo_user_sql(){
	echo $1 >> $user_sql_file;
}

function echo_route_sql(){
	echo $1 >> $route_sql_file;
}

function exec_sql(){
	SQL_COUNT=$1
	echo "mdb_client $localhost_ip $user_port << EOF" > $user_sql_file;
	echo "mdb_client $localhost_ip $route_port << EOF" > $route_sql_file;
	IDENTITY_ID=$1
	i_SQL_COUNT=1
	while [ $IDENTITY_ID -gt 10 ]; do
		i_SQL_COUNT=$[i_SQL_COUNT+1]
		IDENTITY_ID=$[IDENTITY_ID/10]
	done
	IDENTITY_ID=$[20000001*10**i_SQL_COUNT]
	i_SQL_COUNT=0
	#Identity IDENTITY_ID, servId 10000, acctId 20000, custId 30000, groupId 50000, promNo 90000 
	while [ $i_SQL_COUNT -lt $SQL_COUNT ]; do
		echo "run $i_SQL_COUNT" 
		#route_mdb
		echo_route_sql "insert into CSysRtIdentity(identity_id,id_type,resource_id,valid_date,expire_date) values('$[i_SQL_COUNT+IDENTITY_ID]',1,$[i_SQL_COUNT+10000],1,2000000000);"
		echo_route_sql "insert into CSysRtResource(acct_id,resource_id,update_version,valid_date,expire_date) values($[i_SQL_COUNT+20000],$[i_SQL_COUNT+10000],0,1,2000000000);"
		echo_route_sql "insert into CSysRtAccount(cust_id,acct_id,region_code,valid_date,expire_date) values($[i_SQL_COUNT+30000],$[i_SQL_COUNT+20000],1001,1,2000000000);"

		#user_mdb
		echo_user_sql "insert into CIdentity (m_szIdentity,m_szImsi,m_llServId,m_nIdentityType,m_nIdentityAttr,m_llTenantId,m_dValidDate,m_dExpireDate)                                                                                                                                                                                                       values('$[i_SQL_COUNT+IDENTITY_ID]','$[i_SQL_COUNT+IDENTITY_ID]',$[i_SQL_COUNT+10000],999,999,10,1,2000000000);"                                                                
		echo_user_sql "insert into CUser (m_llServId,m_nBrand,m_nRegionCode,m_nCountyCode,m_nLangReading,m_nLangListening,m_nLangWriting,m_nBillType,m_nUserSegment,m_nFlhFlag,m_nContinueFlag,m_nEmailLanguage,m_nResourceSpecId,m_nIsVirtual,m_llTenantId,m_dCreateDate,m_dFirstUseTime,m_dValidDate,m_dExpireDate)                                             values($[i_SQL_COUNT+10000],1,1,1,1,1,1,1,1,1,1,1,1,1,10,'20160101000000',1,1,2000000000);"                           
		echo_user_sql "insert into CUserAcctRel (m_llServId,m_llAcctId,m_llPayAcctId,m_nChangeFlag,m_nTitleRoleId,m_nUserValidFlag,m_dValidDate,m_dExpireDate)                                                                                                                                                                                                values($[i_SQL_COUNT+10000],$[i_SQL_COUNT+20000],999,999,999,999,1,2000000000);"                                                                                  
		echo_user_sql "insert into CAccount (m_llAcctId,m_llCustId,m_nCreditCtrl,m_nCountyCode,m_nRegionCode,m_nOperatorId,m_nAccountType,m_nAccountClass,m_nAccountSegment,m_nBillSts,m_nTaxFlag,m_nTaxRef,m_nAcctFlag,m_nSpecAcctType,m_nBalanceType,m_nDueDay,m_nBillType,m_nMeasureId,m_llTenantId,m_dBillStsDate,m_dCreateDate,m_dValidDate,m_dExpireDate)       values($[i_SQL_COUNT+20000],$[i_SQL_COUNT+30000],999,99,999,999,999,999,999,999,999,999,999,999,999,999,999,999,999,'20160101000000','20160101000000',1,2000000000);"
		echo_user_sql "insert into CUserProm (m_llServId,m_llPromNo,m_llOfferInstId,m_llPayAcctId,m_nPromCycle,m_nPromType,m_nIsMain,m_nPromClass,m_llPricePlanId,m_nBillMode,m_nTaxFlag,m_nRegionCode,m_nCountryId,m_llPricePkgId,m_dValidDate,m_dExpireDate,m_dPromValidDate,m_dPromExpireDate)                                                                     values($[i_SQL_COUNT+10000],$[i_SQL_COUNT+90000],999,999,1,101,1,999,${PRICE_PLAN_ARRAY[i_SQL_COUNT%PRICE_COUNT]},1,999,999,999,${PRICE_PKG_ARRAY[i_SQL_COUNT%PRICE_COUNT]},1,2000000000,1,2000000000);"                
		
		i_SQL_COUNT=$[i_SQL_COUNT+1];
	done
	echo_user_sql "exit;"
	echo_user_sql "EOF"
	
	echo_route_sql "exit;"
	echo_route_sql "EOF"
	
	sh $route_sql_file;
	sh $user_sql_file;
}

function exec_sql_loop(){
	clean_db_data;
	for sql_count in ${SQL_COUNT_ARRY[@]}
	do
		exec_sql $sql_count;
	done
}

exec_sql_loop;

