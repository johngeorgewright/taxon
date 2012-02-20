if [[ $# -lt 3 ]]
then
  echo "USAGE: $0 $1 [project_name] [release_number]"
  exit 1
fi

#################################################################
# CONFIGURATION #################################################
#################################################################
project_name=$2
release_number=$3
tmp_dir="/tmp/taxon/$project_name/$RANDOM"
source $root_dir/lib/config.sh
load_config_for_project $project_name

#################################################################
# MAKE TMP DIRECTORY ############################################
#################################################################
mkdir -p $tmp_dir

#################################################################
# CREATE BRANCH #################################################
#################################################################
i=0
for project in ${projects[@]}
do
  # CHECK OUT PROJECT
  checkout_dir=$tmp_dir/$i/co
  checkout=`svn co -N --force $project/trunk $checkout_dir`
  if [ ! -d $checkout_dir ]
  then
    continue
  fi

  # CREATE EXTERNALS FILE
  externals_file=$tmp_dir/$i/externals.txt
  old_ifs=$IFS
  IFS='
'
  svn_externals=`svn pg svn:externals $checkout_dir/.`
  for svn_external in ${svn_externals[@]}
  do
    for p in ${projects[@]}
    do
      if [ `echo $svn_external | grep $p` ]
      then
        svn_external=${svn_external/$p\/trunk/$p\/branches\/$release_number}
        break
      fi
    done
    echo $svn_external >> $externals_file
  done
  IFS=$old_ifs

  # CREATE BRANCH
  svn_branch_path=$project/branches/$release_number
  echo "Creating new branch \"$svn_branch_path\""
  new_branch=`svn cp $project/trunk $svn_branch_path -m "Creating release branch $release_number."`
  if [ -f $externals_file ]
  then
    checkout=`svn switch $svn_branch_path $checkout_dir`
    new_branch=`svn pd svn:externals $checkout_dir/.`
    new_branch=`svn ps -F $externals_file svn:externals $checkout_dir/.`
    new_branch=`svn ci $checkout_dir -m "Updated svn:externals"`
  fi

  let "i += 1"
done

unset checkout
unset old_ifs
unset externals_file
unset new_branch

echo "Cleaning tmp files"
rm -rf $tmp_dir

