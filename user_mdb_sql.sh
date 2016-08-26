#/bin/sh

if [ "$1" == "-h" -o "$1" == "" ]
then
  echo "======================================================="
  echo "        This tool must input number!"
  echo "        Usage: sh $0 number"
  echo "======================================================="
  exit 0
fi

localhost_ip=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1 | grep -v 192.168 |grep -v inet6|awk '{print $2}'|tr -d "addr:"`
user_port=33455;
route_port=36000;
user_sql_file=./_bat_user_mdb.sql
route_sql_file=./_bat_route_mdb.sql

#号码头
NUMBER_HEAD=20000001
#号码尾部的处理，如NUMBER_STEP=1（默认），尾号1，2，3；如NUMBER_STEP=100，尾号100，200，300的递增处理
NUMBER_STEP=1

#shell脚本不支持2为数组，只能分开这么定义了：
#以下约束命名一定要PRICE_PLAN_ARRAY*,如PRICE_PLAN_ARRAY1，PRICE_PLAN_ARRAY2！！！
PRICE_PLAN_ARRAY1=(99900101)
PRICE_PKG_ARRAY1=(7001388)

# PRICE_PLAN_ARRAY2=(99900102,2)
# PRICE_PKG_ARRAY2=(7001389,9)

#这个参数个数需要和定义的一致！！！
# PRICE_ARRAY_COUNT=2
PRICE_ARRAY_COUNT=1

#用户订购数据数组，循环订购比如生成5个用户，且PRICE_PLAN_ARRAY1=((99900101 1 11),PRICE_PLAN_ARRAY1=(2 3))，则
#第1、3、5个用户都会订购3个产品，定价分别是99900101,1,11，（其中99900101是主产品）
#第2，4个用户订购2个产品，定价是2,3，（其中2是主产品）

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
delete from CSysRtCustomer;
exit;
EOF

check_mdb $user_port;
mdb_client $localhost_ip $user_port << EOF
delete from CCustomer;
delete from CIdentity;
delete from CUser;
delete from CUserAcctRel;
delete from CAccount;
delete from CUserProm;
delete from CAcctProm;
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
        identity_base=$1
        i_SQL_COUNT=1
        #处理尾号位数问题，如10个用户尾号0-9，100个用户尾号00-99
        while [ $identity_base -gt 10 ]; do
                i_SQL_COUNT=$[i_SQL_COUNT+1]
                identity_base=$[identity_base/10]
        done

        #NUMBER_HEAD*10的i_SQL_COUNT次方
        identity_base=$[NUMBER_HEAD*10**i_SQL_COUNT]

        i_SQL_COUNT=0           #第几个用户
        i_PRICE_ARRAY=0         #第几个定价数组
        PRICE_COUNT=0           #第几个定价数组个数
        #Identity IDENTITY_ID, servId 10000, acctId 20000, custId 30000, groupId 50000, promNo 90000(+n*100000) 
        while [ $i_SQL_COUNT -lt $SQL_COUNT ]; do
                echo "run $i_SQL_COUNT" 
                IDENTITY_ID=$[identity_base+i_SQL_COUNT]
                IDENTITY_ID=$[IDENTITY_ID*NUMBER_STEP]  #尾号多了0的情况
                #route_mdb
                echo_route_sql "insert into CSysRtIdentity(identity_id,id_type,resource_id,valid_date,expire_date) values('$IDENTITY_ID',1,$[i_SQL_COUNT+10000],1,2000000000);"
                echo_route_sql "insert into CSysRtResource(acct_id,resource_id,update_version,valid_date,expire_date) values($[i_SQL_COUNT+20000],$[i_SQL_COUNT+10000],0,1,2000000000);"
                echo_route_sql "insert into CSysRtAccount(cust_id,acct_id,region_code,valid_date,expire_date) values($[i_SQL_COUNT+30000],$[i_SQL_COUNT+20000],1001,1,2000000000);"
                echo_route_sql "insert into CSysRtCustomer(cust_id,acct_id,valid_date,expire_date) values($[i_SQL_COUNT+30000],$[i_SQL_COUNT+20000],1,2000000000);"

                #user_mdb
                echo_user_sql "insert into CCustomer (m_llCustId,m_nCustType,m_nRegionCode,m_nGender,m_nOccupation,m_nCustClass,m_nCustSegment,m_nCustStatus,m_nTaxFlag,m_llTenantId,m_nRealNameFlag,m_nCustPhyFlag,m_nCreditLevel,m_nLangReading,m_dBirthday,m_dCreateDate,m_dValidDate,m_dExpireDate)                                      values($[i_SQL_COUNT+30000],1,1,1,1,1,1,1,1,10,1,1,1,1,'20160101000000','20160101000000',1,2000000000);"                               
                echo_user_sql "insert into CIdentity (m_szIdentity,m_szImsi,m_llServId,m_nIdentityType,m_nIdentityAttr,m_llTenantId,m_dValidDate,m_dExpireDate)                                                                                                                                                                                                       values('$IDENTITY_ID','$IDENTITY_ID',$[i_SQL_COUNT+10000],999,999,10,1,2000000000);"                                                                
                echo_user_sql "insert into CUser (m_llServId,m_nBrand,m_nRegionCode,m_nCountyCode,m_nLangReading,m_nLangListening,m_nLangWriting,m_nBillType,m_nUserSegment,m_nFlhFlag,m_nContinueFlag,m_nEmailLanguage,m_nResourceSpecId,m_nIsVirtual,m_llTenantId,m_dCreateDate,m_dFirstUseTime,m_dValidDate,m_dExpireDate)                                             values($[i_SQL_COUNT+10000],1,1,1,1,1,1,1,1,1,1,1,1,1,10,'20160101000000',1,1,2000000000);"                           
                echo_user_sql "insert into CUserAcctRel (m_llServId,m_llAcctId,m_llPayAcctId,m_nChangeFlag,m_nTitleRoleId,m_nUserValidFlag,m_dValidDate,m_dExpireDate)                                                                                                                                                                                                values($[i_SQL_COUNT+10000],$[i_SQL_COUNT+20000],$[i_SQL_COUNT+20000],999,999,999,1,2000000000);"                                                                                  
                echo_user_sql "insert into CAccount (m_llAcctId,m_llCustId,m_nCreditCtrl,m_nCountyCode,m_nRegionCode,m_nOperatorId,m_nAccountType,m_nAccountClass,m_nAccountSegment,m_nBillSts,m_nTaxFlag,m_nTaxRef,m_nAcctFlag,m_nSpecAcctType,m_nBalanceType,m_nDueDay,m_nBillType,m_nMeasureId,m_llTenantId,m_dBillStsDate,m_dCreateDate,m_dValidDate,m_dExpireDate)       values($[i_SQL_COUNT+20000],$[i_SQL_COUNT+30000],999,99,999,281,999,999,999,999,999,999,999,999,999,999,999,10201,10,'20160101000000','20160101000000',1,2000000000);"

                i_PRICE_ARRAY=$[i_SQL_COUNT%PRICE_ARRAY_COUNT+1]
                eval PLAN_ARRAY=\${PRICE_PLAN_ARRAY${i_PRICE_ARRAY}[@]} #得到第几个数组
                eval PKG_ARRAY=\${PRICE_PKG_ARRAY${i_PRICE_ARRAY}[@]} #得到第几个数组

                #切换成数组
                OLD_IFS="$IFS" 
                IFS="," 
                PLAN_ARRAY=($PLAN_ARRAY) 
                PKG_ARRAY=($PKG_ARRAY) 
                IFS="$OLD_IFS" 

                PRICE_COUNT=${#PLAN_ARRAY[@]}
                i_PRICE_COUNT=0
                isMain=1
                #用户可以订购多个产品（更具PRICE_PLAN_ARRAY定义数组决定）
                while [ $i_PRICE_COUNT -lt $PRICE_COUNT ]; do
                        if [ $i_PRICE_COUNT -gt 0 ]; then
                                #只有第一个是主产品
                                isMain=0
                        fi
                        i_PROD_NUMBER=$[90000+i_PRICE_COUNT*100000]
                        echo_user_sql "insert into CUserProm (m_llServId,m_llPromNo,m_llOfferInstId,m_llPayAcctId,m_nPromCycle,m_nPromType,m_nIsMain,m_nPromClass,m_llPricePlanId,m_nBillMode,m_nTaxFlag,m_nRegionCode,m_nCountryId,m_llPricePkgId,m_dValidDate,m_dExpireDate,m_dPromValidDate,m_dPromExpireDate)                                                                     values($[i_SQL_COUNT+10000],$[i_SQL_COUNT+i_PROD_NUMBER],999,999,1,101,$isMain,999,${PLAN_ARRAY[i_PRICE_COUNT]},1,999,999,999,${PKG_ARRAY[i_PRICE_COUNT]},1,2000000000,1,2000000000);"                

                        echo_user_sql "insert into CAcctProm (m_llAcctId,m_llPromNo,m_llOfferInstId,m_llPayAcctId,m_nPromCycle,m_nPromType,m_nIsMain,m_nPromClass,m_llPricePlanId,m_nBillMode,m_nTaxFlag,m_nRegionCode,m_nCountryId,m_llPricePkgId,m_dValidDate,m_dExpireDate,m_dPromValidDate,m_dPromExpireDate)                                                                     values($[i_SQL_COUNT+20000],$[i_SQL_COUNT+i_PROD_NUMBER],999,999,1,101,$isMain,999,${PLAN_ARRAY[i_PRICE_COUNT]},1,999,999,999,${PKG_ARRAY[i_PRICE_COUNT]},1,2000000000,1,2000000000);"                

                        i_PRICE_COUNT=$[i_PRICE_COUNT+1];
                done


                i_SQL_COUNT=$[i_SQL_COUNT+1];
        done
        echo_user_sql "exit;"
        echo_user_sql "EOF"

        echo_route_sql "exit;"
        echo_route_sql "EOF"

        #′|àíê￡óàsqlêy?Y
        sh $route_sql_file;
        sh $user_sql_file;
}

function exec_sql_loop(){
        #run empty data
        clean_db_data;
        for sql_count in ${SQL_COUNT_ARRY[@]}
        do
                exec_sql $sql_count;
        done
}
#--------------??DD??±?main
exec_sql_loop;

echo "--------ending"



