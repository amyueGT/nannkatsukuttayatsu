#!/usr/bin/bash
echo -n run $0


mode_nothing=0
mode_tar=1
mode_cp=2
mode_compress=3
is_make_tar_mode=$mode_tar
if [[ $@ =~ --copy ]];then
	is_make_tar_mode=$mode_cp
fi

exclude_word_reg_array=(".*mozilla.*cache2.*" ".*vivaldi.*Cache_Data.*")


source_home_dir=/home/dir
diff_home_name=/home/backup
archive_home_dir=/home/data/backup
user=user


list_home_dir=/home/dir
prefix_list=.backup_home_dir_
login_list=$prefix_list"login.txt"
logout_list=$prefix_list"logout.txt"
target_list=$prefix_list"target.txt"



diff_prefix=home_dir_diff_
standard_prefix=home_dir_

extention_tar=.tar
extention_compress=.xz

tar_option_update=-uf
tar_option_create=-cf
tar_option_create_compresss=-cJf

today=`date +%Y%m%d`
diff_dir_name=$diff_prefix$today


diff_dir_path=$diff_home_name/$diff_dir_name
archive_tar_path=$archive_home_dir/$standard_prefix$today$extention_tar$extention_compress
archive_diff_file_path=$archive_home_dir/$diff_dir_name$extention_tar$extention_compress



function print_storage_remaining(){
	echo ============ storage remainig is 
	echo -en "$source_home_dir\t:\t"
	df -h $source_home_dir|tail -n1|awk '{print $4,$5,$6,$1}'|while read byte per mounted fs;do echo "$byte($per) at $mounted (${fs})"; done
	echo -en "$diff_home_name\t:\t"
	df -h $diff_home_name|tail -n1|awk '{print $4,$5,$6,$1}'|while read byte per mounted fs;do echo "$byte($per) at $mounted (${fs})"; done
	echo -en "$archive_home_dir\t:\t"
	df -h $archive_home_dir|tail -n1|awk '{print $4,$5,$6,$1}'|while read byte per mounted fs;do echo "$byte($per) at $mounted (${fs})"; done
	echo
	echo
}

function make_backup_add(){
	local tar_mode=$1
	local tar_option=$2
	local dest_dir=$3
	local source_dir=$4
	local file=$5

	if [[ -f $source_dir ]];then
		file=$source_dir
		source_dir=""
	fi
	
	if [[ $tar_mode = $mode_tar || "$tar_option" =~ [jJzZI] ]];then
		dest_dir+=$extention_tar
		if [[ "$tar_option" =~ [jJzZI] ]] ;then
			dest_dir+=$extention_compress
			file+=$extention_tar
		fi
		echo "tar $tar_option $dest_dir \"$source_dir$file\""
		tar $tar_option $dest_dir "$source_dir$file"
	elif [[ $tar_mode = $mode_cp ]];then
		dest_dir=$dest_dir/$source_dir
		echo copy file is "$source_dir$file"
		echo dest_dir "$dest_dir"
		
		if [[ -d "$source_dir$file" ]];then
			if [[ ! -d "$dest_dir$file" ]];then
				echo "mkdir --parents \"$dest_dir$file\""
				mkdir --parents "$dest_dir$file"
			fi
		elif [[ -d "$source_dir" && ! -d "$dest_dir" ]];then
			echo "mkdir --parents \"$dest_dir\""
			mkdir --parents "$dest_dir"	
		else
			#echo :copy mode
			echo "cp -aH --preserve=all -t\"$dest_dir\" \"$source_dir$file\""
			cp -aH --preserve=all -t"$dest_dir" "$source_dir$file"
		fi
	elif [[ $tar_mode = $mode_nothing ]];then
		echo nothing for backup/archive file
	fi

}

function make_backup_add_from_list(){

	while IFS=$'\t' read source_dir file
	do 
		if [[ -z $source_dir && -z $file ]]; then
			echo nothing for backup file.
			is_make_tar_mode=$mode_nothing
			break
		fi
		echo ============ work for source_dir="$source_dir" file=$file 
		source_dir="${source_dir//\'/}"
		if [[ -n `echo "$source_dir"|grep cache2|grep mozilla` || -n `echo "$source_dir"|grep Cache_Data|grep vivaldi` || "$source_dir"/$file == $source_home_dir ]];then
			echo :pass
			continue
		fi

		source_dir="${source_dir#$source_home_dir}"
		if [[ $source_dir != $source_home_dir && -n $source_dir ]];then
			source_dir="${source_dir#/}"
			source_dir=$source_dir/
		fi

		make_backup_add $is_make_tar_mode "$tar_option_update" "$diff_dir_path" "$source_dir" "$file" 

	done << EOS
		`cat $target_list|awk -v FS=$'\t' -v OFS=$'\t' '{print $2,$3}'`
EOS

}

function make_backup_login(){
	echo " make_backup_login()"
	print_storage_remaining
	#=ログイン時動作
	echo ============ make list 
	#ログイン時の$source_home_dirの内容を記録
	find $source_home_dir -printf "%A+\t'%h'\t%f\n" > $source_home_dir/$login_list

	#ディレクトリがなければ作る
	if [ -z "`readlink -f $diff_home_name`"  ];then
		echo "sudo mkdir $diff_home_name"
		sudo mkdir --parents $diff_home_name
		sudo chown $user:$user $diff_home_name
	fi
	if [ -z "`readlink -f $archive_home_dir`"  ];then
		echo "sudo mkdir $archive_home_dir"
		sudo mkdir --parents $archive_home_dir
		sudo chown $user:$user $archive_home_dir
	fi

	cd $source_home_dir
	if [[ ! -f $archive_tar_path && `date +%d`%5 -eq 0 ]];then
		echo  ============ full_archive
		make_backup_add $is_make_tar_mode $tar_option_create_compresss $archive_tar_path $source_home_dir 
	fi
	if [[ ! -f $diff_dir_path$extention_tar && $is_make_tar_mode = $mode_tar ]];then
		echo :tar mode
		login_list="${login_list#$source_home_dir/}"
	elif [ ! -d $diff_dir_path ];then
		echo :copy mode
		mkdir $diff_dir_path;
	fi
	make_backup_add $is_make_tar_mode $tar_option_create $diff_dir_path $login_list 
}


function make_backup_logout(){
	echo " make_backup_logout()"
	print_storage_remaining
	#=ログアウト時動作
	#更新のあったファイルを取得
	echo ============ make list 
	find $source_home_dir -printf "%A+\t'%h'\t%f\n" > $source_home_dir/$logout_list

	excludes=""
	for reg in ${exclude_word_reg_array[@]}; do
  		excludes="$excludes-e$reg "
	done
	diff -u $login_list $logout_list | grep -v ${excludes} \
		| grep -v -e^+++ -e^--- -e^@@ -e"\s\/\s" | grep ^+ > $source_home_dir/$target_list
	logout_list="${logout_list#$source_home_dir/}"
	target_list="${target_list#$source_home_dir/}"

	local dest_dir=$diff_dir_path
	if [[ $is_make_tar_mode = $mode_tar ]] ;then
		dest_dir=$dest_dir$extention_tar
	fi
	cd $source_home_dir
	make_backup_add $is_make_tar_mode $tar_option_update $dest_dir $logout_list
	make_backup_add $is_make_tar_mode $tar_option_update $dest_dir $target_list

	echo ============ make archive from list
	make_backup_add_from_list

	#=アーカイブファイル作成
	echo ============ make $archive_diff_file_path

	cd $diff_home_name
	tar_mode=$mode_compress
	make_backup_add $is_make_tar_mode "$tar_option_create_compresss" "$archive_home_dir/$diff_dir_name" "$diff_dir_name"

}


if [[ "$@" =~ "--login" ]];then
	echo -n " login"
	make_backup_login
fi
if [[ "$@" =~ "--logout" ]];then
	echo -n " logout"
	make_backup_logout
fi


