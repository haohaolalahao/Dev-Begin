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

# * Options
export SET_MIRRORS="${SET_MIRRORS:-false}"

# * Set USER
export USER="${USER:-"$(whoami)"}"

# * Set configuration backup directory

# * dotfile directory
DATETIME="$(date +"%Y-%m-%d-%T")"
BACKUP_DIR="${HOME}/.dotfiles/backups/${DATETIME}"
mkdir -p "${BACKUP_DIR}/.dotfiles"
ln -sfn "${DATETIME}" "${HOME}/.dotfiles/backups/latest"
chmod 755 "${HOME}/.dotfiles"

# * Set temporary directory
# TMP_DIR="$(mktemp -d -t dev-begin.XXXXXX)"
TMP_DIR="/tmp/dev-begin.UiZbKf"

if [[ ! -d "${TMP_DIR}" ]]; then
	mkdir "${TMP_DIR}"
fi

# NOTE Common Functions
function exec_cmd() {
	printf "%s" "$@" | awk \
		'BEGIN {
			RESET = "\033[0m";
			BOLD = "\033[1m";
			UNDERLINE = "\033[4m";
			UNDERLINEOFF = "\033[24m";
			RED = "\033[31m";
			GREEN = "\033[32m";
			YELLOW = "\033[33m";
			WHITE = "\033[37m";
			GRAY = "\033[90m";
			IDENTIFIER = "[_a-zA-Z][_a-zA-Z0-9]*";
			idx = 0;
			in_string = 0;
			double_quoted = 1;
			printf("%s$", BOLD WHITE);
		}
		{
			for (i = 1; i <= NF; ++i) {
				style = WHITE;
				post_style = WHITE;
				if (!in_string) {
					if ($i ~ /^-/)
						style = YELLOW;
					else if ($i == "sudo" && idx == 0) {
						style = UNDERLINE GREEN;
						post_style = UNDERLINEOFF WHITE;
					}
					else if ($i ~ "^" IDENTIFIER "=" && idx == 0) {
						style = GRAY;
						'"if (\$i ~ \"^\" IDENTIFIER \"=[\\\"']\") {"'
							in_string = 1;
							double_quoted = ($i ~ "^" IDENTIFIER "=\"");
						}
					}
					else if ($i ~ /^[12&]?>>?/ || $i == "\\")
						style = RED;
					else {
						++idx;
						'"if (\$i ~ /^[\"']/) {"'
							in_string = 1;
							double_quoted = ($i ~ /^"/);
						}
						if (idx == 1)
							style = GREEN;
					}
				}
				if (in_string) {
					if (style == WHITE)
						style = "";
					post_style = "";
					'"if ((double_quoted && \$i ~ /\";?\$/ && \$i !~ /\\\\\";?\$/) || (!double_quoted && \$i ~ /';?\$/))"'
						in_string = 0;
				}
				if (($i ~ /;$/ && $i !~ /\\;$/) || $i == "|" || $i == "||" || $i == "&&") {
					if (!in_string) {
						idx = 0;
						if ($i !~ /;$/)
							style = RED;
					}
				}
				if ($i ~ /;$/ && $i !~ /\\;$/)
					printf(" %s%s%s;%s", style, substr($i, 1, length($i) - 1), (in_string ? WHITE : RED), post_style);
				else
					printf(" %s%s%s", style, $i, post_style);
				if ($i == "\\")
					printf("\n\t");
			}
		}
		END {
			printf("%s\n", RESET);
		}' >&2
	eval "$@"
}

unset HAVE_SUDO_ACCESS

function have_sudo_access() {
	# UID: user ID, 0 is root
	if [[ "${EUID:-"${UID}"}" == "0" ]]; then
		return 0
	fi

	if [[ ! -x "/usr/bin/sudo" ]]; then
		return 1
	fi

	local -a SUDO=("/usr/bin/sudo")
	if [[ -n "${SUDO_ASKPASS-}" ]]; then
		SUDO+=("-A")
	fi

	if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
		echo -e "${BOLD}${UNDERLINE}${CYAN}Checking sudo access (press ${YELLOW}Ctrl+C${CYAN} to run as normal user).${UNDERLINEOFF}${RESET}" >&2
		# [*] 取全部字段
		exec_cmd "${SUDO[*]} -v && ${SUDO[*]} -l mkdir &>/dev/null"
		HAVE_SUDO_ACCESS="$?"
	fi

	if [[ "${HAVE_SUDO_ACCESS}" == "0" ]]; then
		echo -e "${BOLD}${YELLOW}sudo access available.${RESET}" >&2
	else
		echo -e "${BOLD}${MAGENTA}sudo access unavailable.${RESET}" >&2
	fi

	return "${HAVE_SUDO_ACCESS}"
}

# cp -rf 强行递归复制
function backup_dotfiles() {
	local file original_file
	for file in "$@"; do
		if [[ -f "${file}" || -d "${file}" ]]; then
			# -L 符号链接
			# realpath 将符号链接转换为绝对路径
			if [[ -L "${file}" ]]; then
				original_file="$(realpath "${file}")"
				rm -f "${file}"
				cp -rf "${original_file}" "${file}"
			fi
			cp -rf "${file}" "${BACKUP_DIR}/${file}"
		fi
	done
}

# --no-verbose 关闭长信息，静默执行； --timeout=10 可以设置超时时间; --show-progress 显示进度条, --progress 进度条格式
# command, 调用并执行命令
function new_wget() {
	command wget --no-verbose --timeout=10 -t=10 --no-check-certificate --show-progress --progress=bar:force:noscroll "$@"
}

# github releases info api
function get_latest_version() {
	local REPO="$1" VERSION="" i
	for ((i = 0; i < 5; ++i)); do
		VERSION="$(
			curl --silent --connect-timeout 10 "https://api.github.com/repos/${REPO}/releases/latest" |
				grep '"tag_name":' |
				sed -E 's/^.*:\s*"([^"]+)",?$/\1/'
		)"
		if [[ -n "${VERSION}" ]]; then
			break
		fi
	done
	echo "${VERSION}"
}

function check_binary() {
	local CMD="$1" OPT REQUIRED="${2#v}" VERSION
	for OPT in "--version" "-v" "-V"; do
		VERSION="$("${CMD}" "${OPT}" 2>&1)"
		if [[ $? -eq 0 && "${VERSION}" == *"${REQUIRED}"* ]]; then
			return 0
		fi
	done
	return 1
}

# NOTE Begin of the script
if have_sudo_access; then
	# NOTE add User to visudo
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}NOPASSWD for ${RED}${USER}${CYAN}...${RESET}" >&2
	if (sudo grep -qiF ${USER} /etc/sudoers); then
		echo -e "${BOLD}${YELLOW}User ${RED}${USER}${YELLOW} is already in sudoers.${RESET}" >&2
	else
		echo -e "${BOLD}${YELLOW}User ${RED}${USER}${YELLOW} is not in sudoers." >&2
		echo -e "${BOLD}${CYAN}Adding user ${RED}${USER}${CYAN} to sudoers..." >&2
		sudo bash -c "echo '${USER} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
	fi

	# NOTE change apt sources
	if ${SET_MIRRORS}; then

		APT_SOURCE_LIST="/etc/apt/sources.list"

		echo " " >&2
		echo -e "${BLOD}${UNDERLINE}${CYAN}Setting APT Sources...${RESET}" >&2
		echo -e "${BLOD}${RED}Choose APT source from Aliyun, Huawei or Tuna.(Recommend Huawei)${RESET}" >&2
		PS3="Select apt source:) "

		select apt in Aliyun Huawei Tuna; do
			case $apt in
			Aliyun)
				exec_cmd "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
				echo -e "${BOLD}${BLUE}Change apt sources to Aliyun:${RESET}" >&2
				cat <<-'EOF' | sudo tee ${APT_SOURCE_LIST}
					deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
					deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
					deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
					deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
					deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
				EOF
				echo -e "${BOLD}${YELLOW}Change apt sources success${RESET}" >&2
				break
				;;
			Huawei)
				exec_cmd "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
				echo -e "${BOLD}${BLUE}Change apt sources to Huawei:${RESET}" >&2
				cat <<-'EOF' | sudo tee ${APT_SOURCE_LIST}
					deb http://repo.huaweicloud.com/ubuntu/ focal main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal main restricted universe multiverse
					deb http://repo.huaweicloud.com/ubuntu/ focal-security main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal-security main restricted universe multiverse
					deb http://repo.huaweicloud.com/ubuntu/ focal-updates main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal-updates main restricted universe multiverse
					deb http://repo.huaweicloud.com/ubuntu/ focal-proposed main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal-proposed main restricted universe multiverse
					deb http://repo.huaweicloud.com/ubuntu/ focal-backports main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal-backports main restricted universe multiverse
				EOF
				echo -e "${BOLD}${YELLOW}Change apt sources success${RESET}" >&2
				break
				;;
			Tuna)
				exec_cmd "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
				echo -e "${BOLD}${BLUE}Change apt sources to Tuna:${RESET}" >&2
				cat <<-'EOF' | sudo tee ${APT_SOURCE_LIST}
					# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
					deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal main restricted universe multiverse
					deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-updates main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-updates main restricted universe multiverse
					deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-backports main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-backports main restricted universe multiverse
					deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-security main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-security main restricted universe multiverse

					# 预发布软件源，不建议启用
					# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-proposed main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-proposed main restricted universe multiverse
				EOF
				echo -e "${BOLD}${YELLOW}Change apt sources success${RESET}" >&2
				break
				;;
			*)
				echo -e "${BOLD}${RED}invalid option $REPLY${RESET}" >&2
				echo -e "${BOLD}${RED}Please choose again ${RESET}" >&2
				;;
			esac
		done
	fi

	# NOTE install packages

	# * Add PPA
	echo " " >&2
	echo -e "${BOLD}${BLUE}Add PPA:${RESET}" >&2
	# gdu
	exec_cmd 'sudo add-apt-repository ppa:daniel-milde/gdu --yes'
	echo -e "${BOLD}${YELLOW}Add gdu PPA success${RESET}" >&2
	# neovim
	exec_cmd 'sudo add-apt-repository ppa:neovim-ppa/unstable --yes'
	echo -e "${BOLD}${YELLOW}Add neovim PPA success${RESET}" >&2
	# vscode

	# * Update && Upgrade
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Update && Upgrade Packages${RESET}" >&2
	exec_cmd 'sudo apt-get update --yes'
	exec_cmd 'sudo apt-get upgrade --yes'
	echo -e "${BOLD}${YELLOW}Update && Upgrade Packages success${RESET}" >&2

	# * APT tools
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install APT tools${RESET}" >&2
	exec_cmd 'sudo apt-get install software-properties-common, apt-transport-https --yes'
	echo -e "${BOLD}${YELLOW}Install APT tools success${RESET}" >&2

	# * shell
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Shell Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install zsh --yes'
	echo -e "${BOLD}${YELLOW}Install Shell Packages success${RESET}" >&2

	# * zsh
	if ! grep -qF '/usr/bin/zsh' /etc/shells; then
		exec_cmd "echo '/usr/bin/zsh' | sudo tee -a /etc/shells"
		echo -e "${BOLD}${UNDERLINE}${BLUE}Add zsh to /etc/shells success${RESET}" >&2
	else
		echo -e "${BOLD}${UNDERLINE}${BLUE}zsh already in /etc/shells${RESET}" >&2
	fi

	# * Git
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Git Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install git git-lfs git-extras --yes'
	echo -e "${BOLD}${YELLOW}Install Git Packages success${RESET}" >&2

	# * Compress
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Compress Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install tar gzip unzip atools --yes'
	echo -e "${BOLD}${YELLOW}Install Compress Packages success${RESET}" >&2

	# * File && Net
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install File and Net Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install curl wget httpie rsync tree colordiff xclip xsel net-tools --yes'
	echo -e "${BOLD}${YELLOW}Install File and Net Packages success${RESET}" >&2

	# * Searching
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Searching Tools${RESET}" >&2
	exec_cmd 'sudo apt-get install fzf gawk ripgrep autojump --yes'
	echo -e "${BOLD}${YELLOW}Searching Tools install success${RESET}" >&2

	# * tmux
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install tmux${RESET}" >&2
	exec_cmd 'sudo apt-get install tmux --yes'
	echo -e "${BOLD}${YELLOW}Tmux install success${RESET}" >&2

	# * Query
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install query Tools${RESET}" >&2
	exec_cmd 'sudo apt-get install tldr thefuck --yes'
	echo -e "${BOLD}${YELLOW}Query Tools install success${RESET}" >&2

	# * Top
	# * DevTools
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install DevTools Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install build-essential libboost-all-dev make camke automake autoconf gcc g++ gdb --yes'
	echo -e "${BOLD}${YELLOW}DevTools Packages install success${RESET}" >&2

	# * Top
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Top Tools${RESET}" >&2
	exec_cmd 'sudo apt-get install htop gpustat --yes'
	echo -e "${BOLD}${YELLOW}Top Tools install success${RESET}" >&2

	# * SSH && fail2ban
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install SSH Tools${RESET}" >&2
	exec_cmd 'sudo apt-get install ssh openssh-server fail2ban --yes'
	echo -e "${BOLD}${YELLOW}SSH Tools install success${RESET}" >&2

	# * NVME
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install NVME Tools${RESET}" >&2
	exec_cmd 'sudo apt-get install smartmontools --yes'
	echo -e "${BOLD}${YELLOW}NVME Tools install succes${RESET}" >&2

	# * du
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install gdu & ncdu ${RESET}" >&2
	exec_cmd 'sudo apt-get install gdu ncdu --yes'
	echo -e "${BOLD}${YELLOW}gdu & ncdu install success${RESET}" >&2

	# * neovim
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install neovim${RESET}" >&2
	exec_cmd 'sudo apt-get install neovim --yes'
	echo -e "${BOLD}${YELLOW}neovim install success${RESET}" >&2

	# * fd
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install fd${RESET}" >&2
	LATEST_FD_VERSION="$(get_latest_version "sharkdp/fd")"
	if [[ -n "${LATEST_FD_VERSION}" ]] && ! check_binary fd "${LATEST_FD_VERSION}" && ! check_binary fdfind "${LATEST_FD_VERSION}"; then
		exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://github.com/sharkdp/fd/releases/download/${LATEST_FD_VERSION}/fd_${LATEST_FD_VERSION#v}_amd64.deb"
		exec_cmd "sudo dpkg -i \"${TMP_DIR}/fd_${LATEST_FD_VERSION#v}_amd64.deb\""
		exec_cmd "sudo rm -rf \"${TMP_DIR}/fd_${LATEST_FD_VERSION#v}_amd64.deb\""
		echo -e "${BOLD}${YELLOW}fd installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}fd is already installed${RESET}" >&2
	fi

	# * bat
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install bat${RESET}" >&2
	LATEST_BAT_VERSION="$(get_latest_version "sharkdp/bat")"
	if [[ -n "${LATEST_BAT_VERSION}" ]] && ! check_binary bat "${LATEST_BAT_VERSION}" && ! check_binary batcat "${LATEST_BAT_VERSION}"; then
		exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://github.com/sharkdp/bat/releases/download/${LATEST_BAT_VERSION}/bat_${LATEST_BAT_VERSION#v}_amd64.deb"
		exec_cmd "sudo dpkg -i \"${TMP_DIR}/bat_${LATEST_BAT_VERSION#v}_amd64.deb\""
		exec_cmd "sudo rm -rf \"${TMP_DIR}/bat_${LATEST_BAT_VERSION#v}_amd64.deb\""
		echo -e "${BOLD}${YELLOW}bat installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}bat is already installed${RESET}" >&2
	fi

	# * exa
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install exa${RESET}" >&2
	LATEST_EXA_VERSION="$(get_latest_version "ogham/exa")"
	if [[ -n "${LATEST_EXA_VERSION}" ]] && ! check_binary exa "${LATEST_EXA_VERSION}"; then
		exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://github.com/ogham/exa/releases/download/${LATEST_EXA_VERSION}/exa-linux-x86_64-${LATEST_EXA_VERSION}.zip"
		exec_cmd "sudo unzip -q \"${TMP_DIR}/exa-linux-x86_64-${LATEST_EXA_VERSION}.zip\" bin/exa -d /usr/lcoal"
		exec_cmd "sudo rm -rf \"${TMP_DIR}/exa-linux-x86_64-${LATEST_EXA_VERSION}.zip\""
		echo -e "${BOLD}${YELLOW}exa installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}exa is already installed${RESET}" >&2
	fi

	# * duf
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install duf${RESET}" >&2
	LATEST_DUF_VERSION="$(get_latest_version "muesli/duf")"
	if [[ -n "${LATEST_DUF_VERSION}" ]] && ! check_binary duf "${LATEST_DUF_VERSION}"; then
		exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://github.com/muesli/duf/releases/download/${LATEST_DUF_VERSION}/duf_${LATEST_DUF_VERSION#v}_linux_amd64.deb"
		exec_cmd "sudo dpkg -i \"${TMP_DIR}/duf_${LATEST_DUF_VERSION#v}_linux_amd64.deb\""
		exec_cmd "sudo rm -rf \"${TMP_DIR}/duf_${LATEST_DUF_VERSION#v}_linux_amd64.deb\""
		echo -e "${BOLD}${YELLOW}duf installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}duf is already installed${RESET}" >&2
	fi

	# * btop
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install btop${RESET}" >&2
	if (snap list | grep -qiF btop); then
		exec_cmd 'sudo snap refresh btop'
		echo -e "${BOLD}${RED}btop is already installed${RESET}" >&2
	else
		exec_cmd 'sudo snap install btop --edge'
		echo -e "${BOLD}${YELLOW}btop installed${RESET}" >&2
	fi

	# NOTE Install Nvidia Driver
	echo " " >&2
	echo -e "${BLOD}${UNDERLINE}${CYAN}Install Nvidia Driver${RESET}" >&2
	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to install Nvidia Driver? ${RED}[y/N]: ${RESET}")" answer
			if [[ -n "${answer}" ]]; then
				echo
			else
				answer="n"
			fi
			if [[ "${answer}" == [Yy] ]]; then
				echo -e "${BOLD}${YELLOW}Installing Nvidia Driver${RESET}" >&2
				if (ubuntu-drivers devices | grep -q nvidia); then
					VERSIONS=$(ubuntu-drivers devices | grep -Eo 'nvidia-driver-[0-9]*(-server)?' | sort -r)
					OLD_IFS="$IFS"
					IFS='\n'
					array=("$VERSIONS")
					IFS="$OLD_IFS"
					echo -e "${BOLD}${BLUE}Select the Nvidia Driver version you wish to install:${RESET}" >&2
					PS3="Select Driver :) "
					select var in ${array[@]}; do
						if [[ "${array[@]/${var}/}" != "${array[@]}" ]]; then
							echo -e "${BLOD}${YELLOW}Your choose driver is: $var${RESET}" >&2
							echo -e "${BOLD}${BLUE}Begin install${RESET}" >&2
							exec_cmd "sudo apt install ${var}"
							break
						else
							echo -e "${BLOD}${RED}Your choose is not exist!${RESET}" >&2
						fi
					done
				fi
				break
			elif [[ "${answer}" == [Nn] ]]; then
				echo -e "${BOLD}${RED}Nvidia Driver will not be installed${RESET}" >&2
				break
			fi
		done
	fi

	# NOTE Install CUDA
	echo " " >&2
	echo -e "${BLOD}${UNDERLINE}${CYAN}Install CUDA & CUDNN${RESET}" >&2
	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to install Nvidia CUDA Toolkit 11+ and CUDNN 8.4+ ? ${RED}[y/N]: ${RESET}")" answer
			if [[ -n "${answer}" ]]; then
				echo
			else
				answer="n"
			fi
			if [[ "${answer}" == [Yy] ]]; then
				echo -e "${BOLD}${YELLOW}Installing Nvidia CUDA Toolkit 11+ and CUDNN 8.4+${RESET}" >&2
				echo -e "${BOLD}${BLUE}Begin install${RESET}" >&2
				exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin"
				exec_cmd "sudo mv \"${TMP_DIR}/cuda-ubuntu2004.pin\" /etc/apt/preferences.d/cuda-repository-pin-600"
				exec_cmd 'sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/7fa2af80.pub'
				exec_cmd 'sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /" --yes'
				exec_cmd 'sudo apt-get install cuda --yes'
				exec_cmd 'sudo apt-get install libcudnn8 libcudnn8-dev --yes'
				echo -e "${BOLD}${YELLOW}CUDA & CUDNN installed${RESET}" >&2
				break
			elif [[ "${answer}" == [Nn] ]]; then
				echo -e "${BOLD}${RED}Nvidia CUDA Toolkit and CUDNN will not be installed${RESET}" >&2
				break
			fi
		done
	fi

	# NOTE python
	echo " " >&2
	echo -e "${BLOD}${UNDERLINE}${CYAN}Install nodejs & npm${RESET}" >&2
	exec_cmd 'sudo apt-get install python3 python3-pip --yes'
	echo -e "${BOLD}${YELLOW}gdu & ncdu install success${RESET}" >&2

	# NOTE Install Anaconda3
	echo " " >&2
	echo -e "${BLOD}${UNDERLINE}${CYAN}Install Anaconda3${RESET}" >&2
	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to install Anaconda3 ? ${RED}[y/N]: ${RESET}")" answer
			if [[ -n "${answer}" ]]; then
				echo
			else
				answer="n"
			fi
			if [[ "${answer}" == [Yy] ]]; then
				echo -e "${BOLD}${YELLOW}Installing Anaconda3 ${RESET}" >&2
				echo -e "${BOLD}${BLUE}Begin install${RESET}" >&2
				exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://mirrors.tuna.tsinghua.edu.cn/anaconda/archive/Anaconda3-2021.11-Linux-x86_64.sh"
				echo -e "${BOLD}${BLUE}For root: recommend ${RED}/usr/local/anaconda3${BLUE} For personal: recommend ${RED}${HOME}/anaconda3${RESET}"
				read -p "$(echo -e ${BOLD}${YELLOW}Please input anaconda path: ${RESET})" ANACONDA_PATH
				echo -e "${BOLD}${BLUE}For root: recommend ${RED}anaconda3${BLUE} For personal: recommend ${RED}${USER}${RESET}"
				read -p "$(echo -e ${BOLD}${YELLOW}Pleae input group name: ${RESET})" GROUP_NAME
				exec_cmd "sudo sh ${TMP_DIR}/Anaconda3-2021.11-Linux-x86_64.sh -b -p ${ANACONDA_PATH}"
				if ${SET_MIRRORS}; then
					cat <<-EOF | sudo tee ${ANACONDA_PATH}/.condarc
						default_channels:
						  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main
						  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r
						  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2
						custom_channels:
						  conda-forge: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
						  pytorch: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
						  msys2: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
						  bioconda: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
						  menpo: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
						  simpleitk: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
						channel_priority: flexible

						ssl_verify: true
						show_channel_urls: false
						report_errors: false

						force_reinstall: true
						create_default_packages:
						  - pip
						  - ipython
						  - numpy
						  - numba
						  - matplotlib-base
						  - pandas
						  - seaborn
						  - cython
						  - rich
						  - tqdm
						  - autopep8
						  - pylint
						  - black
						  - flake8
					EOF
				else
					cat <<-EOF | sudo tee ${ANACONDA_PATH}/.condarc
						channel_priority: flexible

						ssl_verify: true
						show_channel_urls: false
						report_errors: false

						force_reinstall: true
						create_default_packages:
						  - pip
						  - ipython
						  - numpy
						  - numba
						  - matplotlib-base
						  - pandas
						  - seaborn
						  - cython
						  - rich
						  - tqdm
						  - autopep8
						  - pylint
						  - black
						  - flake8
					EOF
				fi
				exec_cmd "sudo su -c \"source ${ANACONDA_PATH}/bin/activate && conda update conda --yes && conda install pip ipython numpy numba matplotlib-base pandas seaborn cython rich tqdm autopep8 pylint black flake8 --yes && conda clean --all --yes\""
				exec_cmd "sudo newgrp ${GROUP_NAME}"
				exec_cmd "sudo chgrp ${GROUP_NAME} -R ${ANACONDA_PATH}"
				exec_cmd "sudo chmod 2770 -R ${ANACONDA_PATH}"
				exec_cmd "sudo chmod g-w ${ANACONDA_PATH}/envs"
				exec_cmd "sudo su -c \"source ${ANACONDA_PATH}/bin/activate && conda create -n share python=3.9 --yes && conda activate share && conda install rich --yes\""
				exec_cmd "sudo chmod 554 -R ${ANACONDA_PATH}/pkgs/"
				echo -e "${BOLD}${YELLOW}Anaconda3 install success${RESET}" >&2
				break
			elif [[ "${answer}" == [Nn] ]]; then
				echo -e "${BOLD}${RED}Anaconda3 will not be installed${RESET}" >&2
				break
			fi
		done
	fi
	# * nodejs & npm
	echo " " >&2
	echo -e "${BLOD}${UNDERLINE}${CYAN}Install nodejs & npm${RESET}" >&2
	if ! check_binary npm; then
		exec_cmd 'curl -sL https://deb.nodesource.com/setup_17.x | sudo -E bash -'
		exec_cmd "sudo apt-get install nodejs --yes"
		echo -e "${BOLD}${YELLOW}npm installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}nodejs & npm is already installed${RESET}" >&2
	fi

	# NOTE install frpc
	echo " " >&2
	echo -e "${BLOD}${UNDERLINE}${CYAN}Install frpc${RESET}" >&2
	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to install frpc ? ${RED}[y/N]: ${RESET}")" answer
			if [[ -n "${answer}" ]]; then
				echo
			else
				answer="n"
			fi
			if [[ "${answer}" == [Yy] ]]; then
				echo -e "${BOLD}${YELLOW}Installing frpc${RESET}" >&2
				echo -e "${BOLD}${BLUE}Begin install${RESET}" >&2
				exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://raw.githubusercontent.com/stilleshan/frpc/master/frpc_linux_install.sh"
				exec_cmd "chmod +x \"${TMP_DIR}/frpc_linux_install.sh\""
				exec_cmd "sudo /usr/bin/bash \"${TMP_DIR}/frpc_linux_install.sh\""
				echo -e "${BOLD}${YELLOW}frpc installed${RESET}" >&2
				break
			elif [[ "${answer}" == [Nn] ]]; then
				echo -e "${BOLD}${RED}frpc will not be installed${RESET}" >&2
				break
			fi
		done
	fi

	# NOTE install BIT-LOGIN
	echo " " >&2
	echo -e "${BLOD}${UNDERLINE}${CYAN}Install BIT-LOGIN${RESET}" >&2
	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to install BIT-Login? ${RED}[y/N]: ${RESET}")" answer
			if [[ -n "${answer}" ]]; then
				echo
			else
				answer="n"
			fi
			if [[ "${answer}" == [Yy] ]]; then
				echo -e "${BOLD}${YELLOW}Installing BIT-login ${RESET}" >&2
				echo -e "${BOLD}${BLUE}Begin install${RESET}" >&2
				LATEST_LOGIN_VERSION=$(get_latest_version Mmx233/BitSrunLoginGo)
				exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://github.com/Mmx233/BitSrunLoginGo/releases/download/${LATEST_LOGIN_VERSION}/autoLogin_linux_amd64.zip"
				exec_cmd "sudo unzip -o \"${TMP_DIR}/autoLogin_linux_amd64.zip\" -d /usr/local/autologin"
				exec_cmd "sudo chmod +x /usr/local/autologin/autoLogin"
				read -p "$(${BLOD}${RED}Please input your BIT username: ${RESET})" USERNAME
				read -p "$(${BLOD}${RED}Please input your BIT password: ${RESEST})" PASSWORD
				cat <<-EOF | sudo tee /usr/local/autologin/Config.yaml
				form:
				  domain: "10.0.0.55"
				  username: "${USERNAME}"
				  usertype: ""
				  password: "${PASSWORD}"
				meta:
				  "n": "200"
				  type: "1"
				  acid: "5"
				  enc: srun_bx1
				settings:
				  basic:
				    https: false
				    skip_cert_verify: false
				    timeout: 5
				    interfaces: ""
				  guardian:
				    enable: true
				    duration: 300
				  daemon:
				    enable: true
				    path: /usr/local/autologin/autoLogin
				  debug:
				    enable: false
				    write_log: false
				    log_path: ./
				EOF
				cat <<-EOF | sudo tee /etc/systemd/system/autoLogin.service
				[Unit]
				Description=login service
				After=network.target

				[Service]
				Type=simple
				User=root
				ExecStart=/usr/local/autologin/autoLogin
				Restart=always # or always, on-abort, etc

				[Install]
				WantedBy=multi-user.target
				EOF
				exec_cmd "sudo systemctl enable --now autoLogin.service"
				echo -e "${BOLD}${YELLOW}BIT-Login install success${RESET}" >&2
				break
			elif [[ "${answer}" == [Nn] ]]; then
				echo -e "${BOLD}${RED}BIT-Login will not be installed${RESET}" >&2
				break
			fi
		done
	fi

	# NOTE install xrdp
	echo " " >&2
	echo -e "${BLOD}${UNDERLINE}${CYAN}Install xrdp${RESET}" >&2
	if [ -t 0 ] && [ -t 1 ]; then
		while true; do
			read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to install xrdp? ${RED}[y/N]: ${RESET}")" answer
			if [[ -n "${answer}" ]]; then
				echo
			else
				answer="n"
			fi
			if [[ "${answer}" == [Yy] ]]; then
				echo -e "${BOLD}${YELLOW}Installing xrdp ${RESET}" >&2
				echo -e "${BOLD}${BLUE}Begin install${RESET}" >&2
				exec_cmd "wget -t 10 -T 15 -N -P \"${TMP_DIR}\" https://www.c-nergy.be/downloads/xRDP/xrdp-installer-1.3.zip"
				exec_cmd "unzip -o \"${TMP_DIR}/xrdp-installer-1.3.zip\" -d \"${TMP_DIR}\""
				exec_cmd "chmod +x \"${TMP_DIR}/xrdp-installer-1.3.sh\""
				exec_cmd "/usr/bin/bash \"${TMP_DIR}/xrdp-installer-1.3.sh\" -l"
				echo -e "${BOLD}${YELLOW}xrdp installed${RESET}" >&2
				break
			elif [[ "${answer}" == [Nn] ]]; then
				echo -e "${BOLD}${RED}xrdp will not be installed${RESET}" >&2
				break
			fi
		done
	fi

	# NOTE Enabel Service
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Enabel Service${RESET}" >&2
	exec_cmd 'sudo systemctl daemon-reload'
	# * 1. ssh
	echo -e "${BOLD}${BLUE}Enabel ssh service${RESET}" >&2
	exec_cmd 'sudo systemctl enable --now ssh'

	# * 2. fail2ban
	echo -e "${BOLD}${BLUE}Enabel fail2ban service${RESET}" >&2
	exec_cmd 'sudo systemctl enable --now fail2ban'

	# NOTE autoremove && autoclean
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Autoremove & Autoclean${RESET}" >&2
	exec_cmd 'sudo apt-get autoremove --purge --yes && sudo apt-get autoclean --yes'
	echo -e "${BOLD}${YELLOW}Autoremove & Autoclean success${RESET}" >&2
fi

# NOTE Change the login shell to zsh
if [[ "$(basename "${SHELL}")" != "zsh" ]]; then
	CHSH="chsh"
	if have_sudo_access; then
		CHSH="sudo chsh"
	fi
	if grep -qF '/usr/bin/zsh' /etc/shells; then
		exec_cmd "${CHSH} --shell /usr/bin/zsh ${USER}"
	elif grep -qF '/bin/zsh' /etc/shells; then
		exec_cmd "${CHSH} --shell /bin/zsh ${USER}"
	fi
fi

