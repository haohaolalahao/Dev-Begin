#! /usr/bin/bash
# NOTE add visudo
eval "sudo -A -v"

if (sudo grep -qiF ${USER} /etc/sudoers); then
	echo "User ${USER} is already in sudoers."
else
	echo "User ${USER} is not in sudoers."
	echo "Adding user ${USER} to sudoers..."
	sudo bash -c "echo '${USER} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
fi

# NOTE change apt source
APT_SOURCE_LIST="/etc/apt/sources.list"

echo "Choose APT source from Aliyun, Huawei or Tuna. Recommend Huawei"
PS3="Select apt source:) "
select apt in aliyun huawei tuna; do
	case $apt in
	aliyun)
		eval "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
		echo "Choose apt sources: aliyun"
		echo "Change apt sources to aliyun:"
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
		echo "Change apt sources success"
		break
		;;
	huawei)
		eval "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
		echo "Choose apt sources: huawei"
		echo "Change apt sources to huawei:"
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
		echo "Change apt sources success"
		break
		;;
	tuna)
		eval "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
		echo "choose apt sources: tuna"
		echo "change apt sources to tuna:"
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
		echo "Change apt sources success"
		break
		;;
	*)
		echo "invalid option $REPLY"
		echo "Please choose again"
		;;
	esac
done
