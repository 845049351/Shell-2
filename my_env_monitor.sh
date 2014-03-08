#!/bin/sh
echo "############################################"
echo "      this is a monitor shell script!"
echo "############################################"
echo "start runing my_env_monitor..."
echo

is_file()
{
    file=$1
    if test -f $file; then
        echo "$file exists and is a regular file!"
        return 1
    else
        echo "$file not exists or is't a regular file!"
        return 0
    fi
    
}

#function : delete the files of "find" found;
#param { $1: file_path , $2£ºfile }
del_found_file()
{
    file_path=$1
    file=$2
    if [ $# -eq 2 ]; then
        echo "***** delete $file from $file_path *****" 
    else
        echo "Your del_file param must be 2!, pls check your scirpt!"
        echo "Unnormal exit!"
        echo "==============================================" 
        exit;    
    fi
    if [ ! -e $file_path ]; then
        echo "The path [$file_path] is not exist!"
        echo "==============================================" 
        return 1
    fi
    
    cd $file_path;pwd;
    ret=`find . -name $file | grep -v boost | wc -l`;
    if [ $ret -gt 0 ]; then
        find . -name $file | grep -v boost
        find . -name $file | grep -v boost | xargs rm 
        echo "Delete $ret $file successfully!"  
    else
        echo "No $file in [$file_path]!"
    fi

    echo
}
#mdb file
del_mdb_file()
{
    echo "************  del_mdb_file ******************" 
    file_path=$1
    file_param=$2
    i=0
    cd $file_path
    pwd
    #for f in `find . -name \"$file_param\"`
    for f in `ls $file_param`
    do
        echo "del [$f] ok!"
        rm $f
        i=$[i+1]
    done
    if [ $i -gt 0 ]; then
        echo "Total del $i mdb files!"
    else
        echo "No mdb file need clear!"
    fi

    echo
    
}

#main()
del_found_file $HOME commlog.log 
del_found_file $HOME core

del_mdb_file $HOME/mdb/user_mdb "*.mdb.*"
#del_mdb_file $HOME/mdb/user_mdb "*.mdb"


echo "############################################"
echo "exit my_env_monitor!"
exit
