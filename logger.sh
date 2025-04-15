#!/usr/bin/bash
echo include logger.sh

qq=':?:'
qor=':or:'
function 3ex(){
	#echo "abcd$(3ex "0"$qq"AAA"$qor"BBB")efg"
	#echo "abcd$(3ex "1"$qq"AAA"$qor"BBB")efg"
	expr=${1%$qq*}
	res="${1:4}"

	test $expr -eq 0 &>/dev/null
	if [[ $? -eq 0 ]];then
		echo -n "${res%\:or\:*}"
	else
		echo -n "${res#*\:or\:}"
	fi
}

function AAAis_str(){
	#local arg=$1
	local result=1;
	expr $1 + 1 2>>/dev/null
	if (( $? == 2 ));then result=0;fi
	return $result
}

function is_str(){
	#local arg=$1
	local result="false";
	expr $1 + 1 &>/dev/null
	if (( $? == 2 ));then result="true";fi
	echo $result
}



log_sep='=========='
log_format_text='%s${additional_format}'
log_format_exec="%sfuncName::line:%s:%s\n%s"
#log_format_command="%s::line:%s::%s\=%s\${additional_format}\\n%s"
log_format_command_start="${log_sep} command log::%s@%s\(line@%s\)::varName:%s\${additional_format}::start ${log_sep}\\\n\\\n%s"
log_format_command_end="${log_sep} command log::%s@%s\(line@%s\)::varName:%s\${additional_format}::end ${log_sep}\\\n\\\n"
log_format_result_start="${log_sep} list log::%s@%s\(line@%s\)::varName:%s\(size:%s\)\${additional_format}::start ${log_sep}\\\n\\\n"
log_format_result_end="${log_sep} list log::%s@%s\(line@%s\):%s::varName:%s\(size:%s\)::end ${log_sep}\\\n\\\n"

logm_info=0
logm_info_dnl=1
logm_exec_command=11
logm_exec_result=12

function logger(){
	# $1=$log_mode 出力するフォーマットの切り替え用 

	local log_mode=$1
	local text="$2"

	local additional_format=

	local flag=false;
	if $(is_str ${log_mode}) && [[ ${log_mode} =~ (text|txt|t|info|inf|i) ]];then flag=true;fi
	if ! $flag && (( ${log_mode} < $logm_exec_command ));then flag=true;fi
	if $flag;then
	#if (( $mode < $mode_debug ));then
		# $log_mode print_text 
		# 通常のログ 件数とかフリーなテキスト ダブルクォートで囲って一行で
		# $1=text
		# fromat $text
		if $(is_str ${log_mode}) && [[ ! ${log_mode} =~ (disable_new_line|_disablenewline|disable|_dnl|d) ]];then flag=true;fi
		if ! $flag && (( ${log_mode} != ${logm_info_dnl} ));then flag=true;fi
		if $flag;then
			additional_format='\n'
		fi
		printf "$(eval echo "${log_format_text}")" "${text}"
	fi

	flag=false;
	if $(is_str ${log_mode}) && [[ ${log_mode} =~ (command|com|c) ]];then flag=true;fi
	if ! $flag && (( ${log_mode} == $logm_exec_command ));then flag=true;fi
	if $flag;then
		# $1=$log_mode $2=$text $3=file_name $3=func_name $4=line $5=var_name $6=exec_com
		# シェル上で作ったコマンド
		# format:funcName::line:行数::変数名=value::必要ならメッセージ\nコマンド
		local file_name="$3"
		local func_name="$4"
		local line=$5
		local var_name="$6"
		local exec_com="$7"
		if [[ ! -z $text ]];then
			#additional_format='::%s'
			additional_format="::${text}"
		fi

		printf "$(eval echo "${log_format_command_start}")" "${file_name}" "${func_name}" "${line}" "${var_name}" "${exec_com}"
		printf "$(eval echo "${log_format_command_end}")" "${file_name}"  "${func_name}" "${line}" "${var_name}" 
	fi


	flag=false;
	if $(is_str ${log_mode}) && [[ ${log_mode} =~ (result|res|r) ]];then flag=true;fi
	if ! $flag && (( ${log_mode} == $logm_exec_result ));then flag=true;fi
	if (( $log_mode == $logm_exec_result ));then
			# $1=$log_mode $2=$text $3=file_name $4=func_name $5=line $6=var_name $7=size $8=value
			# 行数が大きくなるコマンド実行結果の変数の値
			# format:
			# ========= funcName::line:行数::varName:変数名(size:件数)::必要ならメッセージ::start =========\n
			# 変数内容\n
			# ========= funcName::line:行数::varName:変数名(size:件数)::end =========\n
			local file_name="$3"
			local func_name="$4"
			local line=$5
			local var_name="$6"
			local size=$7
			eval "local $var_name=\"$8\""
			if [[ $(declare -p $var_name) =~ -a ]];then
				var_name+="[@]"
			fi
			if [[ ! -z $text ]];then
				#additional_format='::%s'
				additional_format="::${text}"
			fi

			printf "$(eval echo "${log_format_result_start}")" "${file_name}" "${func_name}" "${line}" "${var_name}" "${size}"
			echo -e "${!var_name}"
			printf "${log_format_result_end}" "${file_name}" "${func_name}" "${line}" "${var_name}" "${size}"
		fi
		
		# $log_mode warn_mes
		# 設定してない項目とか

		# $log_mode 
		# format WARNING $
		return 0;
	fi

	# funcName line:No.
	
}


logger-test(){
	echo
	echo run logger help
	echo called by ${BASH_SOURCE[0]##*/}@${FUNCNAME[1]}@lineNo:"${LINENO}"
	for lineNo in ${BASH_LINENO[@]};do
		echo $lineNo
	done


	echo
	for (( n=0;n<${#BASH_LINENO[@]};n++));do
		echo "\${BASH_SOURCE[$(( $n + 1))]}="${BASH_SOURCE[$(( $n + 1))]}
		echo "\${FUNCNAME[$n]}="${FUNCNAME[$n]}
		echo "\${BASH_LINENO[$n]}="${BASH_LINENO[$n]}
	done
	echo
	echo
	logger ${logm_info} "\${BASH_SOURCE[@]}=${BASH_SOURCE[@]}"
	this_file="${BASH_SOURCE[0]}"
	this_file_name=${BASH_SOURCE[0]##*/}
	logger ${logm_info}  this_file_name=$this_file_name
	echo "echo FUNCNAME[@]="${FUNCNAME[@]}
	logger ${logm_info} \${FUNCNAME[@]}="${FUNCNAME[@]}"
	logger ${logm_info} "\${FUNCNAME[0]}=${FUNCNAME[0]}"
	logger ${logm_info} "\${BASH_LINENO}=${BASH_LINENO}"
	echo
	echo
	echo run logger help end


	funcname-test
}