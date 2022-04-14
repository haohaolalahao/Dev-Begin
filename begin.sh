#! /usr/bin/bash

# Reset
RESET="\033[0m"

# Format
BOLD="\033[1m"
UNDERLINE="\033[4m"
UNDERLINEOFF="\033[24m"

# Regular Colors foreground
BLACK="\033[0;30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

echo -e "${BOLD}${UNDERLINE}${BLUE}Dev-Begin${RESET}" >&2

# NOTE: 1. Start logging
LOG_FILE="${PWD}/dev-begin.log"
# 条件判断，-f：文件存在
if [[ -f "${LOG_FILE}" ]]; then
	# mv -f 若文件或目录存在，覆盖旧文件
	mv -f "${LOG_FILE}" "${LOG_FILE}.old"
fi
# tee 从标准输入读取数据并重定向到标准输出和文件
# tee -a 追加文件而不是覆盖
# >() process substitution 进程替换写入，<() 写出，目的是为了解决无法使用管道的情况
# >&2 将标准输出重定向到标准错误
# exec 执行命令
# 将标准错误stderr追加进LOG_FILE的同时写入到标准错误stderr，主要是为了记录错误信息
exec 2> >(tee -a "${LOG_FILE}" >&2)
# echo -e 激活转义字符串
echo -e "${BOLD}${WHITE}The script output will be logged to file: ${GREEN}\"${LOG_FILE}\"${WHITE}.${RESET}" >&2

# NOTE: 2. Get system information
OS_NAME=""
# uname, 打印系统信息
if [[ "$(uname -s)" == "Darwin" ]]; then
	# OS_NAME="macOS"
	# PACKAGE_MANAGER="Homebrew"
	OS_NAME=""
	PACKAGE_MANAGER=""
elif [[ "$(uname -s)" == "Linux" ]]; then
	# grep <match_pattern> <file>
	# grep -q quiet 不显示信息 -i ignore 忽略大小写 -E 扩展正则表达式
	# for ubuntu /etc/os-release/ and /etc/lsb-release/
	if grep -qiE 'ID.*ubuntu' /etc/*-release; then
		OS_NAME="ubuntu"
		PACKAGE_MANAGER="APT"
		# PACKAGE_MANAGER="APT, Homebrew"
	elif grep -qiE 'ID.*manjaro' /etc/*-release; then
		# OS_NAME="Manjaro"
		# PACKAGE_MANAGER="Pacman, Homebrew"
		OS_NAME=""
		PACKAGE_MANAGER=""
	fi
fi

# -z 判断string非空
if [[ -z "${OS_NAME}" ]]; then
	# echo -e "${BOLD}${RED}The operating system is not supported yet. ${YELLOW}Only macOS, Ubuntu Linux, and Manjaro Linux are supported.${RESET}" >&2
	echo -e "${BOLD}${RED}The operating system is not supported yet. ${YELLOW}Only Ubuntu is suppored.${RESET}" >&2
	exit 1
fi

echo -e "${BOLD}${WHITE}Operating System: ${BLUE}${OS_NAME}${RESET}"

# Options
# NOTE 3. SET_MIRRORS 是否使用镜像
# =~ 等价于 == 表达式为正则表达式
if [[ "${SET_MIRRORS}" =~ (yes|Yes|YES|true|True|TRUE) ]]; then
	SET_MIRRORS=true
elif [[ "${SET_MIRRORS}" =~ (no|No|NO|false|False|FALSE) ]]; then
	SET_MIRRORS=false
else
	# unset 删除变量
	unset SET_MIRRORS
	# -t fildescriptor, True, if file descriptor number fildes is open and associated with a terminal device.
	# [ -t 0 ] 0 stdin
	# [ -t 1 ] 1 stdout
	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			# read == input, -p prompt -n 1 + answer 读取一个字符并赋值给变量answer
			read -n 1 -p "$(echo -e "${BOLD}${CYAN}Do you wish to set the source of package managers ${BLUE}(${PACKAGE_MANAGER})${CYAN} to the open source mirrors ? ${WHITE}[y/N]: ${RESET}")" answer
			# -n sting 不为空 返回 true
			if [[ -n "${answer}" ]]; then
				echo
			else
				answer="n"
			fi
			if [[ "${answer}" == [Yy] ]]; then
				SET_MIRRORS=true
				break
			elif [[ "${answer}" == [Nn] ]]; then
				SET_MIRRORS=false
				break
			fi
		done
	fi
fi
export SET_MIRRORS

# Run script if it exists
# $0 expands to the name of the shell or shell script，表示当前脚本的名字
# dirname 返回路径中的目录部分
# basename 返回路径中的文件部分
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# -x 可执行
if [[ -x "${SCRIPT_DIR}/begin_${OS_NAME}.sh" && "$(basename "$0")" == "begin.sh" ]]; then
	echo -e "${BOLD}${UNDERLINE}${CYAN}Run existing script ${GREEN}\"${SCRIPT_DIR}/begin_${OS_NAME}.sh\"${UNDERLINEOFF}${RESET}" >&2
	echo " " >&2
	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to configure ${OS_NAME}? ${RED}[y/N]: ${RESET}")" answer
			if [[ -n "${answer}" ]]; then
				echo
			else
				echo
			fi
			if [[ "${answer}" == [Yy] ]]; then
				echo -e "${BOLD}${YELLOW}Begin configure ${OS_NAME}${RESET}" >&2
				/usr/bin/bash "${SCRIPT_DIR}/begin_${OS_NAME}.sh"
				break
			elif [[ "${answer}" == [Nn] ]]; then
				echo -e "${BOLD}${RED}will not configure ${OS_NAME}${RESET}" >&2
				break
			fi
		done
	fi

	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to configure dotfiles? ${RED}[y/N]: ${RESET}")" answer
			if [[ -n "${answer}" ]]; then
				echo
			else
				echo
			fi
			if [[ "${answer}" == [Yy] ]]; then
				echo -e "${BOLD}${YELLOW}Begin configure dotfiles${RESET}" >&2
				/usr/bin/bash "${SCRIPT_DIR}/begin_${OS_NAME}_dotfiles.sh"
				break
			elif [[ "${answer}" == [Nn] ]]; then
				echo -e "${BOLD}${RED}will not configure dotfiles${RESET}" >&2
				break
			fi
		done
	fi

	# 退出脚本
	exit $?
fi

# Download and run
# if [[ -x "$(command -v wget)" ]]; then
# 	echo -e "${BOLD}${WHITE}Download and run script via ${GREEN}wget${WHITE}.${RESET}" >&2
# 	echo
# 	/bin/bash -c "$(wget --progress=bar:force:noscroll -O - "https://github.com/XuehaiPan/Dev-Setup/raw/HEAD/setup_${OS_NAME}.sh")"
# elif [[ -x "$(command -v curl)" ]]; then
# 	echo -e "${BOLD}${WHITE}Download and run script via ${GREEN}curl${WHITE}.${RESET}" >&2
# 	echo
# 	/bin/bash -c "$(curl -fL# "https://github.com/XuehaiPan/Dev-Setup/raw/HEAD/setup_${OS_NAME}.sh")"
# elif [[ -x "$(command -v git)" ]]; then
# 	echo -e "${BOLD}${WHITE}Download and run script via ${GREEN}git${WHITE}.${RESET}" >&2
# 	echo
# 	git clone --depth=1 https://github.com/XuehaiPan/Dev-Setup.git 2>&1
# 	/bin/bash "Dev-Setup/setup_${OS_NAME}.sh"
# else
# 	echo -e "${BOLD}${WHITE}Please download the script from ${YELLOW}https://github.com/XuehaiPan/Dev-Setup${WHITE} manually.${RESET}" >&2
# fi
