#!/bin/sh
# $Id: #
if [ "$1" == "-h" -o "$1" == "" ]
then
  echo "This tool add /* $Id:$ */ to the first line of files"
  echo "Usage: add_svn_id.sh file(s)"
  exit 0
fi

while [ $# -ge 1 ]
do
  if [ -f $1 ]
  then
    echo "Adding to $1 ..."
    tmp=`head -n1 $1 | grep '/* \$Id' | wc -l`
    if [ $tmp -eq 0 ]
    then
      svn propset svn:keywords "Id" $1
      cp $1 $1.bak
      echo "/* \$Id:$  */" > $1
      cat $1.bak >> $1
    fi
  else
    echo "Ignoring $1 ..."
  fi
  shift
done

