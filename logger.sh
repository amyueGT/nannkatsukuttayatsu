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


function is_str(){
	#local arg=$1
	local result="false";
	expr $1 + 1 &>/dev/null
	if (( $? == 2 ));then result="true";fi
	echo $result
}



log_sep='=========='
format_text='[${mode_letter}]%s${additional_format}'
format_text_append='%s${additional_format}'
invoke_stat="\${BASH_SOURCE[1]##*/}@line:\${BASH_LINENO[0]}\(\#\${FUNCNAME[1]}\)"
format_command_start="[\${mode_letter}]${log_sep} ${invoke_stat}::varName:%s\${additional_format}:: command log start ${log_sep}\\\n\\\n%s\\\n\\\n"
format_command_end="[\${mode_letter}]${log_sep} ${invoke_stat}::varName:%s\${additional_format}:: command log end ${log_sep}\\\n\\\n"
format_result_start="[\${mode_letter}]${log_sep} ${invoke_stat}::varName:%s\(size:%s\)\${additional_format}:: result log start ${log_sep}\\\n\\\n"
format_result_end="\\\n[\${mode_letter}]${log_sep} ${invoke_stat}::varName:%s\(size:%s\):: result log end ${log_sep}\\\n\\\n"

mode_letter_info="INFO"
mode_letter_debug="DEBUG"
mode_letter_trace="TRACE"
mode_letter_warn="WARN"
mode_letter_error="ERROR"
mode_letter_logger_warn="LOGGER-WARN"
mode_letter_logger_error="LOGGER-ERROR"


logm_info=0
logm_info_dnl=1
logm_info_append=2
logm_info_append_dnl=3
logm_exec_result=4
logm_exec_command=5

log_mode_debug=50
log_mode_trace=60
log_mode_warn=80
log_mode_error=90

log_mode_info=0 #<100
log_mode_debug=100
log_mode_trace=200


target_log_mode=$shell_log_mode

function logger(){
	# $1=$log_mode 出力するフォーマットの切り替え用
	local log_mode=$1
	log_mode=${log_mode:="info"}
	local is_str_log_mode=$(is_str ${log_mode}) 
	local text="$2"

	local additional_format=

	local mode_letter=$mode_letter_info
	flag=false
	if ${is_str_log_mode} && [[ ${log_mode} =~ (deb|debug) ]];then flag=true;fi
	if ! $flag && ! ${is_str_log_mode} && (( ${log_mode} >= $log_mode_debug && ${log_mode} < $log_mode_trace ));then flag=true;fi
	if $flag;then
		if (( $target_log_mode < $log_mode_debug ));then return 0;fi
		mode_letter=$mode_letter_debug
	fi
	flag=false
	if ${is_str_log_mode} && [[ ${log_mode} =~ (trc|trace) ]];then flag=true;fi
	if ! $flag && ! ${is_str_log_mode} && (( ${log_mode} >= $log_mode_trace && ${log_mode} < $log_mode_warn ));then flag=true;fi
	if $flag;then
		if (( $target_log_mode < $log_mode_trace ));then return 0;fi
		mode_letter=$mode_letter_trace
	fi
	local flag=false;
	if ! ${is_str_log_mode}&&$(3ex $( (( $log_mode%100 >= $log_mode_warn ));echo $?)$qq"true"$qor"false");then flag=true;fi
	if $flag || [[ ${log_mode} =~ (warn|wrn|wan) ]];then
		mode_letter=$mode_letter_warn
	fi
	flag=false
	if ! $is_str_log_mode&&$(3ex $( (( $log_mode%100 >= $log_mode_error ));echo $?)$qq"true"$qor"false");then flag=true;fi
	if $flag || [[ ${log_mode} =~ (error|err|errr) ]];then
		mode_letter=$mode_letter_error
	fi

	local flag=false;
	#if $(3ex $(is_str ${log_mode};echo $?)$qq"true"$qor"false") && [[ ${log_mode} =~ (text|txt) ]];then flag=true;fi
	if ${is_str_log_mode} && [[ ${log_mode} =~ (text|txt|info|inf) ]];then flag=true;fi
	if ! $flag && ! ${is_str_log_mode} && (( ${log_mode}%10 <= $logm_info_dnl ));then flag=true;fi
	if $flag;then
		#echo =====info log 
		# 通常のログ 件数とかフリーなテキスト ダブルクォートで囲って一行で
		# $1=text
		# fromat $text
		flag=false;
		if ${is_str_log_mode} && [[ ${log_mode} =~ (result|res|r) ]];then flag=true;fi
		if ! $flag  &&  ! ${is_str_log_mode} && (( ${log_mode} == $logm_exec_result ));then flag=true;fi
		if $flag;then
			print_result "$@" #$1=$log_mode $2=$text $3=var_name $4=value $5=size
			return
		fi 


		local format=$format_text
		flag=false
		if ${is_str_log_mode} && [[ ${log_mode} =~ (appe|apen|apnd|appnd|apd|appen|append) ]];then flag=true; fi
		if ! $flag &&  ! ${is_str_log_mode} && (( ${log_mode} != ${logm_info_append} ));then flag=true;fi
		if $flag;then
			format=$format_text_append
		fi
		flag=false
		if ${is_str_log_mode} && [[ ! ${log_mode} =~ (dnl|disable_new_line|_disablenewline|disable) ]];then flag=true;fi
		if ! $flag &&  ! ${is_str_log_mode} && (( ${log_mode} != ${logm_info_dnl} ));then flag=true;fi
		if $flag;then
			additional_format='\n'
		fi
		printf "$(eval echo "${format}")" "${text}"
		return
	fi
	if(( $target_log_mode < $log_mode_debug ));then
		return; 
	else
		#print result
		mode_letter=$mode_letter_debug
		flag=false;
		if ${is_str_log_mode} && [[ ${log_mode} =~ (result|res|r) ]];then flag=true;fi
		if ! $flag  &&  ! ${is_str_log_mode} && (( ${log_mode} == $logm_exec_result ));then flag=true;fi
		if $flag;then
			local inv=$(echo $(eval echo $invoke_stat))
			if [[ -z $3 ]];then printf "[${mode_letter_logger_error}]%s\n" "${inv} result-log \$3=var_name is blank. logger canceled"; return 1; fi
			if [[ -z $4 ]];then printf "[${mode_letter_logger_error}]%s\n" "${inv} result-log \$4=value is blank. logger canceled"; return 1; fi

			#echo ====result log
			# $1=$log_mode $2=$text $3=var_name $4=value $5=size
			# $4 value は配列ならクォーテーションありで${arr[*]}アットでなくアスタ、テキストならクォーテーションをつけないで引数を渡す事でレコードまたは配列の要素が正常に区切られる
			# $5 size は表示したい件数。マイナス指定で後ろから 
			# 行数が大きくなるコマンド実行結果の変数の値
			# フォーマットは format_result_start/format_result_end

			local var_name="$3"
			local size=$5
			size=${size:=0}

			eval local ${var_name}=\"$4\"
			eval ${var_name}=\(\"${!var_name// /\" \"}\"\)
			local list_size=$(eval "echo \"\${#$var_name[@]}\"")
			if (( size == 0 ));then size=$list_size; fi

			if [[ ! -z $text ]];then
				additional_format="::${text}"
			fi
			local max=${size}
			local key=0
			if(( $size < 0 ));then max=${list_size}; key=$((list_size+size)); fi

			printf "$(eval echo "${format_result_start}")"  "${var_name}" "${list_size}"
			for (( ;key<$max;key++ ));do
				printf "${var_name}[%s]:%s\n" $key "$(eval echo "\${$var_name[$key]}")"
			done
			printf "$(eval echo "${format_result_end}")" "${var_name}" "${list_size}"
		fi
	fi

	if(( $target_log_mode < $log_mode_trace ));then
		return; 
	else
		#print command
		mode_letter=$mode_letter_trace
		flag=false;
		if ${is_str_log_mode} && [[ ${log_mode} =~ (command|com|c) ]];then flag=true;fi
		if ! $flag &&  ! ${is_str_log_mode} && (( ${log_mode} == $logm_exec_command ));then flag=true;fi
		if $flag;then
			#echo ====command log
			# $1=$log_mode $2=$text $3=var_name $4=exec_com
			# シェル上で作ったコマンド
			local var_name="$3"
			var_name="${var_name:= #blank# }"
			local exec_com="$4"
			if [[ ! -z $text ]];then
				additional_format="::${text}"
			fi

			printf "$(eval echo "${format_command_start}")" "${var_name}" "${exec_com}"
			printf "$(eval echo "${format_command_end}")" "${var_name}" 

		fi
	fi

	# 設定してない項目とか

	return 0;	
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
