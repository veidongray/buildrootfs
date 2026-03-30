#!/bin/bash
#
# This script can build U-Boot, the Kernle, the RootFS, or all of above on arm64.
# 

# 支持的参数列表
args_list="hHrRcCd:D:"
# 主机需要安装的依赖和软件包
host_pack_list="debootstrap qemu-user qemu-user-static qemu-system"
# 获取主机名称，如：Ubuntu
host_dist_name=$(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
# 获取主机发行版版本号，如：24.04
host_dist_id=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
# 输出目录
output_dir="output"
# 用于下载软件包的mirror
debootstrap_mirror="https://mirrors.aliyun.com/ubuntu-ports/"
# 根文件系统构建目录
rootfs="$output_dir/rootfs"
# 在chroot里面运行的脚本路径
script_in_rootfs="build_in_rootfs.sh"
# 对应版本apt mirror文件
mirror_ubuntu_2004_file="mirror_ubuntu_2004.txt"
mirror_ubuntu_2204_file="mirror_ubuntu_2204.txt"
mirror_ubuntu_2404_file="mirror_ubuntu_2404.txt"

function rootfs () {
    log_info "Create output directory"
    mkdir -pv $output_dir

    log_info "Install host depends"
    sudo apt install -y $host_pack_list

    log_info "Run debootstrap --arch=arm64 $target $rootfs $debootstrap_mirror"
    #if ! sudo debootstrap --arch=arm64 \
    #    --components=main,universe,restricted,multiverse \
    #    --include=ubuntu-standard \
    #    $target $rootfs $debootstrap_mirror; then
    #        exit 1
    #fi

    log_info "Copy script to rootfs"
    sudo cp -v $script_in_rootfs $rootfs
    sudo chmod -v a+x $rootfs/$script_in_rootfs

    if [ "$target" == "focal" ]; then
        log_info "Configure apt mirror"
        sudo cp -v $mirror_ubuntu_2004_file $rootfs/etc/apt/sources.list
    elif [ "$target" == "jammy" ]; then
        log_info "Configure apt mirror"
        sudo cp -v $mirror_ubuntu_2204_file $rootfs/etc/apt/sources.list
    elif [ "$target" == "noble" ]; then
        log_info "Configure apt mirror"
        sudo cp -v $mirror_ubuntu_2404_file $rootfs/etc/apt/sources.list.d/ubuntu.sources
    fi

    log_info "chroot to rootfs"
    sudo chroot $output_dir/rootfs /bin/bash $script_in_rootfs

    log_info "Logout from chroot"

    log_info "Create rootfs image to $output_dir/disk.img"
    sudo dd if=/dev/zero of=$output_dir/disk.img bs=1G count=10 conv=sync
    sudo mkfs.ext4 -v $output_dir/disk.img
    mkdir -pv $output_dir/mnt
    sudo mount -v -t ext4 $output_dir/disk.img $output_dir/mnt

    log_info "Package rootfs to $output_dir/disk.tar"
    if ! sudo tar \
        --numeric-owner \
        --preserve-permissions \
        --exclude="dev/*" \
        --exclude="proc/*" \
        --exclude="sys/*" \
        --exclude="tmp/*" \
        -cf $output_dir/disk.tar -C $rootfs/ .; then
            exit 1
    fi
    log_info "Extract rootfs to $output_dir/mnt"
    sudo tar -xf $output_dir/disk.tar -C $output_dir/mnt
    sudo umount -v -t ext4 $output_dir/mnt

    log_info "Resize rootfs image"
    sudo e2fsck -f $output_dir/disk.img
    sudo resize2fs -M $output_dir/disk.img

    log_info "Done!"
}


function help () {
    echo "usage: $0 -$args_list"
    echo -e "\t-h|-H Show help infomations"
    echo -e "\t-d|-D [arguments...] target [focal|jammy|noble]"
    echo -e "\t-r|-R Build RootFS"
    echo -e "\t-c|-C Clean"
}

function log_info () {
    echo -e "[\033[32m$0\033[0m] $(date): $1"
}

function log_err () {
    echo -e "[\033[31m$0\033[0m] $(date): $1"
}

function clean() {
    log_info "Clean $output_dir"
    sudo rm -rvf $output_dir
}

function check_host() {
    if [ "$host_dist_id" != "20.04" ] \
        && [ "$host_dist_id" != "22.04" ] \
        && [ "$host_dist_id" != "24.04" ] \
        && [ "$host_dist_name" != "Ubuntu" ]; then
            log_err "Only supports building on Ubuntu 20.04/22.04/24.04!"
            exit 1
    fi
}

function main()
{
    local rootfs_flag=false
    local target_flag=false

    check_host
    if (( $# > 0 )); then
        while getopts "$args_list" opt; do
            case "$opt" in
                h|H)
                    help
                    exit 0
                    ;;
                r|R)
                    rootfs_flag=true
                    ;;
                d|D)
                    target="$OPTARG"
                    target_flag=true
                    ;;
                c|C)
                    clean
                    exit 0
                    ;;
                *)
                    help
                    exit 1
                    ;;
            esac
        done
    else
        help
        exit 1
    fi

    if [ $rootfs_flag == true ] && [ $target_flag == true ]; then
        rootfs
    else
        help
        exit 1
    fi
    exit 0
}

main "$@"
