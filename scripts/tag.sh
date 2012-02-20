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
patch_numbers=()
svn_tag_paths=()
source $root_dir/lib/config.sh
load_config_for_project $project_name

#################################################################
# MAKE TMP DIRECTORY ############################################
#################################################################
mkdir -p $tmp_dir

#################################################################
# LOOP THROUGH PROJECTS##########################################
#################################################################
i=0
for project in ${projects[@]}
do

  #################################################################
  # CHECK OUT BRANCH ##############################################
  #################################################################
  svn_branch_path=$project/branches/$release_number
  checkout_dir=$tmp_dir/$i/co
  checkout=`svn co -N --force $svn_branch_path $checkout_dir`
  if [ ! -d $tmp_dir/$i/co ]
  then
    continue
  fi

  #################################################################
  # DECIPHER A TAG FROM THE BRANCH ($svn_tag_path $patch_number) ##
  #################################################################
  confirmation=false
  svn_tag_list=(`svn ls $project/tags | grep $release_number-`)
  list_key=${#svn_tag_list[@]}
  let "list_key -= 1"
  if [ $list_key -ge 0 ]
  then
    svn_current_tag="${svn_tag_list[$list_key]}"
  else
    svn_current_tag=""
  fi
  if [[ $svn_current_tag =~ "[^/]+" ]]
  then
    svn_current_tag="${BASH_REMATCH[0]}"
  else
    echo "There aren't any tags created for $svn_branch_path. Should I use $release_number-01?"
    while [ $confirmation != "y" ] && [ $confirmation != "n" ]
    do
      echo -n "[y/n] > "
      read confirmation
      if [ $confirmation = "y" ]
      then
        svn_current_tag="$svn_branch-00"
      elif [ $confirmation = "n" ]
      then
        echo "Fine then! go do it yourself you stupid mung."
        continue 2
      fi
    done
  fi
  if [[ $svn_current_tag =~ "\-([[:digit:]]+)$" ]]
  then
    patch_number="${BASH_REMATCH[1]}"
    let "patch_number += 1"
    patch_number=`printf %02d $patch_number`
    svn_tag_path="$svn_path/tags/$release_number}-$patch_number"
  else
    echo
    echo "I can't decipher the current tag patch. You better deal with this yourself."
    continue
  fi
  patch_numbers[$i]=$patch_number
  svn_tag_path=$project/tags/$release_number-$patch_number
  svn_tag_paths[$i]=$svn_tag_path
  unset confirmation
  unset svn_tag_list
  unset list_key
  unset svn_current_tag
  
  #################################################################
  # CREATE TAG ####################################################
  #################################################################
  echo "Creating new tag \"$svn_tag_path\""
  new_branch=`svn cp $svn_branch_path $svn_tag_path -m "Creating release tag $release_number-$patch_number."`
 
  let "i += 1"
done

unset checkout
unset old_ifs
unset externals_file
unset new_branch

i=0
for project in ${projects[@]}
do
  checkout_dir=$tmp_dir/$i/co
  svn_tag_path=${svn_tag_paths[$i]}

  #################################################################
  # CREATE EXTERNALS FILE #########################################
  #################################################################
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
        svn_external=${svn_external/$p\/branches\/$release_number/$p\/tags\/$release_number-${patch_numbers[$i]}}
        break
      fi
    done
    echo $svn_external >> $externals_file
  done
  IFS=$old_ifs
  if [ -f $externals_file ]
  then
    echo "Updating svn:externals $checkout_dir/."
    checkout=`svn switch $svn_tag_path $checkout_dir`
    new_tag=`svn pd svn:externals $checkout_dir/.`
    new_tag=`svn ps -F $externals_file svn:externals $checkout_dir/.`
    new_tag=`svn ci $checkout_dir -m "Updated svn:externals"`
  fi

  #################################################################
  # BUMP THE SPEC FILE ############################################
  #################################################################
  spec_files=(`find $checkout_dir -type f -name \*.spec`)
  if [ ${#spec_files[@]} -lt 1 ]
  then
    echo "I can't find a spec file for $svn_tag_path"
    continue
  fi
  for spec_file in ${spec_files[@]}
  do
    echo "Updating the $spec_file"
    sed -e "s/%define IPC_VERSION .*/%define IPC_VERSION $release_number/g" $spec_file > $spec_file.new
    sed -e "s/%define IPC_RELEASE .*/%define IPC_RELEASE $patch_number/" $spec_file.new > $spec_file
    rm $spec_file.new
    updated_spec=`svn ci $checkout_dir -m "Bumped spec."`
  done
  unset updated_spec
  unset spec_files
  unset spec_file

  let "i += 1"
done

echo "Cleaning tmp files"
rm -rf $tmp_dir

