#!/bin/bash

NC='\033[0m'      # Normal Color
RED='\033[0;31m'  # Error Color
CYAN='\033[0;36m' # Info Color

#--------------------------------------------
# 执行命令
#
# demo： run_cmd "mkdir -p $1"
#--------------------------------------------
function run_cmd()
{
    local t=`date`
    echo "$t: $1"
    eval $1
}

#--------------------------------------------
# 递归创建目录
#
# demo： recursive_mkdir "/opt/data/hosea"
#--------------------------------------------
function recursive_mkdir()
{
    if [ ! -d $1 ]; then
        run_cmd "mkdir -p $1"
    fi
}

#--------------------------------------------
# 递归创建目录 通过传入的文件地址
#
# demo： recursive_mkdir_with_file "/opt/data/hosea/a.txt"
#--------------------------------------------

function recursive_mkdir_with_file()
{
    recursive_mkdir $(dirname $1)
}


#--------------------------------------------
# 列出包含的命令
#
#--------------------------------------------
function list_contains()
{
    local var="$1"
    local str="$2"
    local val

    eval "val=\" \${$var} \""
    [ "${val%% $str *}" != "$val" ]
}

#--------------------------------------------
# 修改host
# sh docker.sh updateHost www.baidu.com 127.0.0.1
#--------------------------------------------
function updateHost()
{
    local in_url="$2"
    local in_ip="$3"

    # 域名下的IP
    inner_host=`cat /etc/hosts | grep ${in_url} | awk '{print $1}'`
    if [[ ${inner_host} = ${in_ip} ]];
    then
        echo "${inner_host}  ${in_url} ok, do nothing."
    else
        # 替换 http://man.linuxde.net/sed
        # sudo sed -i "" "s/${inner_host:='updateHost'}/${in_ip}/g" /etc/hosts

        inner_ip_map="${in_ip} ${in_url}"
        # sudo 只能作用于echo 操作符仍然 >> 需要权限 sh -c 可以让sudu 命令作用于整个语句
        sudo sh -c "echo ${inner_ip_map} >> /etc/hosts"
        # tee -a 追加 等同于 >>
        # echo ${inner_ip_map}|sudo tee -a /etc/hosts

        if [ $? = 0 ]; then
           echo "${inner_ip_map} to hosts success host is `cat /etc/hosts`"
        fi
    fi
}

#--------------------------------------------
# 读取 文件中 key=value 的value
#
# demo: read_kv_config .env APP_NAME
function read_kv_config()
{
    local file=$1
    local key=$2
    cat $file | grep "$key=" | awk -F '=' '{print $2}'
}

#--------------------------------------------
# 模板变量替换 生成新文件 适用于配置中心
#
# demo: render_local_config $config_key $prj_dir/9douyu-core/.env.example $config_file $prj_dir/9douyu-core/.env
#--------------------------------------------
function render_local_config()
{
    local config_key=$1
    local template_file=$2
    local config_file=$3
    local out=$4

    shift
    shift
    shift
    shift

    local config_type=yaml
    cmd="curl -s -F 'template_file=@$template_file' -F 'config_file=@$config_file' -F 'config_key=$config_key' -F 'config_type=$config_type'"
    for kv in $*
    do
        cmd="$cmd -F 'kv_list[]=$kv'"
    done
    cmd="$cmd $CONFIG_SERVER/render-config > $out"
    run_cmd "$cmd"
    head $out && echo
}



#--------------------------------------------
# 删除容器
#
# demo: rm_container "container_name"
#--------------------------------------------
function rm_container()
{
    local container_name=$1
    local cmd="docker ps -a -f name='^/$container_name$' | grep '$container_name' | awk '{print \$1}' | xargs -I {} docker rm -f --volumes {}"
    run_cmd "$cmd"
}

#--------------------------------------------
# 构建容器
#
#--------------------------------------------
function build_image()
{
    local docker_image=$1
    local docker_file_dir=$2
    docker build -t $docker_image $docker_file_dir
}

#--------------------------------------------
# 容器是否在运行
#
# demo: container_is_running "container_name"
#--------------------------------------------
function container_is_running()
{
    local container_name=$1
    local num=$(docker ps -a -f name="^/$container_name$" -q | wc -l)
    if [ "$num" == "1" ]; then
        local ret=$(docker inspect -f {{.State.Running}} $1)
        echo $ret
    else
        echo 'false'
    fi
}

#--------------------------------------------
# 推送sunfund镜像到自己的仓库
#
# demo: sh docker.sh push_sunfund_image 9dy-php:5.6.8-fpm
#--------------------------------------------
function push_sunfund_image()
{
    local image_name=$2
    local user_image="hoseadevops/sunfund-$image_name"
    run_cmd "docker tag docker.sunfund.com/$image_name $user_image"
    run_cmd "docker push $user_image"
}

#--------------------------------------------
# 下载sunfund 镜像
#
# demo: sh docker.sh pull_sunfund_image 9dy-php:5.6.8-fpm
#--------------------------------------------
function pull_sunfund_image()
{
    local image_name=$2
    local url=docker.sunfund.com/$image_name
    run_cmd "docker pull $url"
}

#--------------------------------------------
# 推送本地镜像到自己的仓库
#
# demo: sh docker.sh push_image
#--------------------------------------------
function push_image()
{
    local image_name=$2
    local user_image="hoseadevops/own-$image_name"
    run_cmd "docker tag $image_name $user_image"
    run_cmd "docker push $user_image"
}

#--------------------------------------------
# docker0 ip
#--------------------------------------------
function docker0_ip()
{
    local host_ip=$(ip addr show docker0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | awk '{print $1}' | head  -1)
    echo $host_ip
}

#--------------------------------------------
# 通过key=value的配置文件 替换 模板中的 $val 变量; 不适合模板中有$符号的 非替换字符串
# replace_template config.file template.file out.file
#--------------------------------------------
function replace_template()
{
    local config=`cat $1`
    local template=`cat $2`
    local out=$3

    printf "$config\ncat << EOF\n$template\nEOF" | bash > $out
}
#--------------------------------------------
# 批量替换配置 sed 多个变量替换
# replace_template_key_value config.file template.file out.file
#--------------------------------------------
function replace_template_key_value()
{
    local config=$1
    local template=$2
    local out=$3

    cmd="sed '"
    sub_cmd=""
    for kv in `cat $config`
    do
        key=$(echo $kv| awk -F '=' '{print $1}')
        val=$(echo $kv| awk -F '=' '{print $2}')

        sub_cmd=$sub_cmd"s|{{ $key }}|$val|g;";
    done
    sub_cmd="${sub_cmd%?}'"

    run_cmd "$cmd$sub_cmd $template > $out";
}


#--------------------------------------------
# 变量扩展 默认值类用法
#
# ${parameter-word} 若parameter变量未定义，则扩展为word。
# ${parameter:-word} 若parameter变量未定义或为空，则扩展为word。
#--------------------------------------------
#if [ "$action" = 'init' ]; then
#    if [ $# -lt 1 ]; then
#        echo "Usage sh $0 init";
#        exit 1
#    fi
#    init
#    exit 0
#fi


#busybox_image=busy
#syslogng_image=balabit/syslog-ng
#redis_image=redis:3.0.1
#mysql_image=mysql:5.7
#php_image=hoseadevops/own-php:7.1.7-fpm
#nginx_image=nginx:1.11