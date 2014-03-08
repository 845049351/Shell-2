#!/bin/sh
##################################################
#           ./a.sh localhost 33400 10086 20140101120000 0
##################################################

tenant_id=-1;
if [ "$#" -eq 5 ]
then
	tenant_id=$5;
elif [ "$#" -eq 4 ]
then
	echo ;
else
	echo "*********************** mdb_client.sh ***************************"
	echo "功能说明:"
	echo "	1、支持通过计费号码进行资料查询并校验，仅校验必须存在且正确的必要数据"
	echo "	2、支持user_mdb或route_mdb，脚本内部登录后区分"
	echo "	3、查询结果分类：[OK]资料正确；[WARN]存在资料不全；[ERROR]资料不全，查询会失败；"
	echo "使用方法:"
	echo "	$0 mdb_ip mdb_port identity date_time [tenant_id]"
	echo "查询参数，user_mdb5个参数，route_mdb4个参数："
	echo "	mdb_ip : 	mdb IP地址[公用]"
	echo "	mdb_port :	mdb端口[公用]"
	echo "	identity :	查询号码[公用]"
	echo "	date_time :	查询时间点[公用]"
	echo "	tenant_id :	归属运营商[user_mdb用]"
	echo "举例："
	echo "	1、user_mdb :	sh $0 localhost 33400 10086 20140101120000 0"
	echo "	2、route_mdb :	sh $0 localhost 35800 10086 20140101120000"
	echo "*******************************************************************"
	exit 0 ;
fi

ip=$1;
port=$2;
identity=$3;
date_time=$4;
records_line=-1;
start_line=-1;
user_mdb=0;

#打印输出并增量添加到文件
multi_echo()
{
	echo "$1" | tee -a mdb_client_exec.sql;	
}

#首次打印信息
print_input()
{
	multi_echo "-----------------begin----------------------------------";
	multi_echo "ip = $ip" ;
	multi_echo "port = $port" ;
	multi_echo "identity = $identity" ;
	multi_echo "date_time = $date_time" ;
	multi_echo "tenant_id = $tenant_id" ;
}
#退出并清理
do_exit()
{	
	if test -f 'mdb_client_date.tmp'
	then
		rm mdb_client_date.tmp;
	fi
	
	echo;
	multi_echo "-----------------end----------------------------------";
	exit 0 ;
}
# 检查服务函数
check_serv()
{
	if [ $ip == "localhost" ];then
		if [ `netstat -an | grep $port | grep LISTEN | wc -l` -lt 1 ];then
			echo "[ERROR] MDB没有启动并监听端口：$port";
			do_exit;
		fi
	else
		servStatus=0;
mdb_client $ip $port > mdb_client_date.tmp << EOF
	exit;
EOF
		eval $(awk '/failed/{printf("servStatus=%d",1);}' mdb_client_date.tmp);
		if [ $servStatus -eq 1 ];then
			do_exit;
		fi
	fi
}
#区分user_mdb还是route_mdb
check_mdb()
{
mdb_client $ip $port > mdb_client_date.tmp << EOF
    showtables;
    exit;
EOF
	eval $(awk '/CUserMdbParam/{if(NF == 1){printf("user_mdb=%d",1);}}' mdb_client_date.tmp);
}
# mdb查询函数
mdb_select()
{
	echo;
	echo "--------------------------mdb_select()-----------------------------------";
    table=$1;
    field=$2;
    condition=$3;
    sql="";
    
	if [ $user_mdb -eq 1 ]
	then
	    if [ "$table" == "CIdentity" ];then
	    	sql="select * from $table where $field = '$condition' and m_dValidDate < '$date_time' and m_dExpireDate > '$date_time';";
	    else
	    	sql="select * from $table where $field = $condition and m_dValidDate < '$date_time' and m_dExpireDate > '$date_time';";
		fi
	else
	    if [ "$table" == "CSysRtIdentity" ];then
	    	sql="select * from $table where $field = '$condition' and valid_date < '$date_time' and expire_date > '$date_time';";
	    else
	    	sql="select * from $table where $field = $condition and valid_date < '$date_time' and expire_date > '$date_time';";
		fi
	fi
#mdb_client工具数据查询
mdb_client $ip $port > mdb_client_date.tmp << EOF
    $sql
    exit;
EOF
	echo '\n' >> mdb_client_date.tmp;
	multi_echo "$sql";

	awk -v _table=$table '/records selected/{if(NF == 4){print "[OK] " _table "查找到 " $2 " 条数据!";} else{print "[WARN] " _table "查找到 0 条数据!";}}' mdb_client_date.tmp
	#awk到shell的取值
	eval $(awk '/records selected/{if(NF == 4){printf("records_line=%d",$2);} else{printf("records_line=%d",0);}}' mdb_client_date.tmp);
	eval $(awk '/_oid/{printf("start_line=%d",NR);}' mdb_client_date.tmp);
}
#校验CIdentity表数据是否存在
check_identity_data()
{
	if [ "$records_line" -lt 1 ]
	then
	    echo "[ERROR] 没查询到数据：请检查CIdentity 表号码,生失效时间!";
	    do_exit;
	else
	    #cat mdb_client_date.tmp
	    #tenant_id与records_line：shell到awk的2中实现方式
	    awk -F, -v _tenant_id=$tenant_id 'BEGIN{bFound=0;}
		 {
		     if(NR > '$start_line' && NR <= ('$records_line'+'$start_line') && bFound == 0){
		         if($7 != _tenant_id){
		             print "[ERROR] tenant_id 不一致! 业务分析传入:" _tenant_id ";CIdentity中:" $7 ";本条记录数据:" $0;
		         }
		         else if($5 != 0){
		             print "[ERROR] 查询参数号码类型不对!m_nIdentityType=0才是计费号码类型";
		         }
		         else{
		         	printf("[OK] CIdentity找到符合条件的serv_id:%s",$2);
		         	bFound=1;
		         }
		     }
		 }
		 END{}' mdb_client_date.tmp
		 
		 eval $(cat mdb_client_date.tmp | awk 'BEGIN{bFound=0;} {if(NR> '$start_line' && NR <= ('$records_line'+'$start_line') && bFound== 0){printf("serv_id=%d",$2);bFound=1;} }' );
	fi
}
#校验CUserAcctRel表数据是否存在
check_userAcctRel_data()
{
	if [ "$records_line" -lt 1 ]
	then
	    echo "[ERROR] 没查询到数据：请检查CUserAcctRel 表数据,生失效时间!";
	    do_exit;
	else
	    awk -F, 'BEGIN{bFound=0;}
		 {
		     if(NR > '$start_line' && NR <= ('$records_line'+'$start_line') && bFound== 0){
		         printf("[OK] CUserAcctRel找到符合条件的acct_id:%s",$3);
		         bFound=1;
		     }
		 }
		 END{}' mdb_client_date.tmp
		 
		 eval $(cat mdb_client_date.tmp | awk 'BEGIN{bFound=0;} {if(NR> '$start_line' && NR <= ('$records_line'+'$start_line') && bFound== 0){printf("acct_id=%d",$3);bFound=1;} }' );
	fi
}	
#校验单表数据是否存在
check_table_data()
{
	_table=$1;
	if [ "$records_line" -lt 1 ]
	then
	    echo "[ERROR] 没查询到数据：请检查$_table 表数据,生失效时间!";
	    do_exit;
	else
	    awk -F, 'BEGIN{bFound=0;}
		 {
		     if(NR > '$start_line' && NR <= ('$records_line'+'$start_line') && bFound== 0){
		         printf("[OK] '$_table'找到符合条件资料信息!");
		         bFound=1;
		     }
		 }
		 END{}' mdb_client_date.tmp
	fi
}

#校验CSysRtIdentity表数据是否存在
check_sys_identity_data()
{
	if [ "$records_line" -lt 1 ]
	then
	    echo "[ERROR] 没查询到数据：请检查CSysRtIdentity 表号码,生失效时间!";
	    do_exit;
	else
	    awk -F, 'BEGIN{bFound=0;}
		 {
		     if(NR > '$start_line' && NR <= ('$records_line'+'$start_line') && bFound == 0){
		         if($3 == 1){
		         	printf("[OK] CSysRtIdentity找到符合条件的resource_id:%s",$4);
		         	bFound=1;
		         }
		         else{
		             print "[ERROR] 查询参数号码类型不对! id_type=1才是计费号码类型";
		         }
		     }
		 }
		 END{}' mdb_client_date.tmp
		 
		 eval $(cat mdb_client_date.tmp | awk 'BEGIN{bFound=0;} {if(NR> '$start_line' && NR <= ('$records_line'+'$start_line') && bFound== 0){printf("serv_id=%d",$4);bFound=1;} }' );
	fi
}
#校验CSysRtResource表数据是否存在
check_sysResource_data()
{
	if [ "$records_line" -lt 1 ]
	then
	    echo "[ERROR] 没查询到数据：请检查CSysRtResource 表数据,生失效时间!";
	    do_exit;
	else
	    awk -F, 'BEGIN{bFound=0;}
		 {
		     if(NR > '$start_line' && NR <= ('$records_line'+'$start_line') && bFound== 0){
		         printf("[OK] CSysRtResource找到符合条件的acct_id:%s;用户版本号:%s",$2,$4);
		         bFound=1;
		     }
		 }
		 END{}' mdb_client_date.tmp
		 
		 eval $(cat mdb_client_date.tmp | awk 'BEGIN{bFound=0;} {if(NR> '$start_line' && NR <= ('$records_line'+'$start_line') && bFound== 0){printf("acct_id=%d",$2);bFound=1;} }' );
	fi
}
##################################################
print_input;
check_serv;
check_mdb;
##################################################
serv_id=-1;
acct_id=-1;

if [ $user_mdb -eq 1 ]
then
	multi_echo "This is user_mdb!" ;
	#################  CIdentity
	mdb_select CIdentity m_szIdentity $identity;
	check_identity_data;
	#################  CUser
	mdb_select CUser m_llServId $serv_id;
	check_table_data CUser;
	#################  CUserAcctRel
	mdb_select CUserAcctRel m_llServId $serv_id;
	check_userAcctRel_data;
	#################  CAccount
	mdb_select CAccount m_llAcctId $acct_id;
	check_table_data CAccount;
	#################  CAcctBillCycle
	mdb_select CAcctBillCycle m_llAcctId $acct_id;
	check_table_data CAcctBillCycle;
else
	multi_echo "This is route_mdb!" ;
	#################  CSysRtIdentity
	mdb_select CSysRtIdentity identity_id $identity;
	check_sys_identity_data;
	#################  CSysRtResource
	mdb_select CSysRtResource resource_id $serv_id;
	check_sysResource_data;
fi

##################################################
do_exit;
