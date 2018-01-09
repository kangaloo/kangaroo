#!/bin/bash
#定义sftp的数据存放目录
sftprootdir="/data/sftp"
#新用户密码位数
passwd_num=8
#产生的密码文件路径与文件名
passwdfile=$(cd `dirname $0`; pwd)"/bocsftp.passwd"
#产生的sshd配置文件路径与文件名
includefile=$(cd `dirname $0`; pwd)"/includefile"
#需要关闭掉selinux
/usr/sbin/setenforce 0

err(){
    echo -e "`date +%Y-%m-%d\ %H:%M:%S `\033[31m $@ \033[0m"
    sleep 2
    return 1
}

log(){
    echo -e "`date +%Y-%m-%d\ %H:%M:%S `\033[32m $@ \033[0m"
    sleep 2
    return 0
}

randompasswd() {
	a=(a b c d e A B C D E F 0 1 2 3 4 5 6 7 8 9);
	for((i=1;i<=($passwd_num);i++)); do
        echo -n ${a[$RANDOM % ${#a[@]}]}
    done
}

create_admin(){
	log "创建总行管理员账户";
	#创建总行管理员用户
    /bin/mkdir -p ${sftprootdir}"/admin"
    /usr/sbin/useradd -d ${sftprootdir}"/admin" -s /bin/false bocadmin
    /bin/chmod 700 ${sftprootdir}"/admin"
    echo "bocadmin:$(randompasswd)" >> $passwdfile
}


mkalldir(){
	log "开始创建各分行及对应物管公司sftp数据存放目录,并创建相应用户";
	#创建需要往sshd_config增加的配置文件
	[ -f $includefile ] && cp $includefile $includefile"_bak"
	>$includefile

	for line in $allsubbranch; do
	    fh_id=`echo $line | awk -F',' '{print $1}'`
	    fh_name=`echo $line | awk -F',' '{print $2}'`
	    fh_wg=`echo $line | awk -F',' '{print $3}'`

        fh_dir="${sftprootdir}/${fh_id}"
        fh_admin_dir="${fh_dir}/0"
        fh_admin_user="boc${fh_id}"

        if [ -d "$fh_admin_dir" ]; then
            # 向已有分行添加物管公司
            old_wg_sum=
            old_wg_sum_1=`/usr/bin/find $fh_dir -maxdepth 1 -type d -group $fh_admin_user | wc -l`
            old_wg_sum_2=`/usr/bin/find $fh_dir -maxdepth 1 -type d -group $fh_admin_user -user $fh_admin_user | wc -l`
            old_wg_sum=$(($old_wg_sum_1 - $old_wg_sum_2))

            if [ $fh_wg -gt $old_wg_sum ]; then
                fh_wg=$(($fh_wg - $old_wg_sum))

                log "向已存在的分行: ${fh_name}分行 添加新的物管公司"
                for((num=0; num<=($fh_wg - 1); num++)); do 
                    home_dir="${fh_dir}/00${num}"
                    # echo "判断${home_dir}是否存在"
                    if [ -d "$home_dir" ]; then
                        fh_wg=$(($fh_wg + 1))
                    else
                        /bin/mkdir -p $home_dir
                        new_user="cst${fh_id}00${num}"
                        echo "创建新用户: $new_user"
                        /usr/sbin/useradd -d $home_dir -g ${fh_admin_user} -s /bin/false $new_user
                        /bin/chmod 750 $home_dir
                        /bin/chown "$new_user":"$fh_admin_user" $home_dir
                        echo "${new_user}:$(randompasswd)" >> $passwdfile
                    fi
                done
            else
                log "分行 ${fh_name}分行 未增加物管公司"

            fi

        else
            log "创建新的分行: ${fh_name}分行，并添加物管公司"
    	    echo "Match group ${fh_admin_user}" >> $includefile
    	    echo "ForceCommand internal-sftp -u 007" >> $includefile
    	    echo "ChrootDirectory ${fh_dir}" >> $includefile
    	    echo "X11Forwarding no" >> $includefile
    
            echo "创建分行用户组${fh_admin_user}"
            /usr/sbin/groupadd $fh_admin_user
            /bin/mkdir -p ${fh_admin_dir}
            /usr/sbin/useradd -d ${fh_admin_dir} -g ${fh_admin_user} -s /bin/false $fh_admin_user
            /bin/chmod 700 ${fh_admin_dir}
            /bin/chown "${fh_admin_user}":"$fh_admin_user" ${fh_admin_dir}
            echo "${fh_admin_user}:$(randompasswd)" >> $passwdfile
            
            echo "开始创建${fh_name}分行数据目录"
            
            for((num=0; num<=($fh_wg - 1); num++)); do 
                home_dir="${fh_dir}/00${num}"
                /bin/mkdir -p $home_dir
                new_user="cst${fh_id}00${num}"
                echo "创建新用户: $new_user"
                /usr/sbin/useradd -d $home_dir -g ${fh_admin_user} -s /bin/false $new_user
                /bin/chmod 750 $home_dir
                /bin/chown "$new_user":"$fh_admin_user" $home_dir
                echo "${new_user}:$(randompasswd)" >> $passwdfile
            done
        fi
        set_facl ${fh_admin_dir} ${fh_dir} ${fh_wg} ${fh_id}
	done
    change_pass
}

set_facl(){
    local fh_admin_dir=$1
    local fh_dir=$2
    local fh_wg=$3
    local fh_id=$4
    /usr/bin/setfacl -m u:bocadmin:rwx $fh_admin_dir
    for((num=0; num<=($fh_wg - 1); num++)); do
        /usr/bin/setfacl -m u:bocadmin:rwx "$fh_dir/00${num}"
        for((nums=0; nums<=($fh_wg - 1); nums++)); do
            if [ $num -ne $nums ]; then
                /usr/bin/setfacl -m u:"cst${fh_id}00${num}":- "${fh_dir}/00${nums}"
            fi
        done
    done
}

change_pass(){
    /usr/sbin/chpasswd < $passwdfile
}

clean_passwdfile(){

    if [ -f $passwdfile ]; then
        mv $passwdfile "${passwdfile}.bak"
        if [ $? -eq 0 ]; then 
            log "move $passwdfile to ${passwdfile}.bak"
        else
            err "备份密码文件失败，请手动备份 $passwdfile 后删除该文件"
        fi
    fi
}

clean_date_dir(){
    if [ -d "$sftprootdir" ]; then
        err "目录 $sftprootdir 已存在，请手动删除或更改要存储目录后重新执行该脚本"
        exit 0
    fi
}

# configauth() {
# 	for i in $allsubbranch; do
# 	    j=`echo $i|awk -F',' '{print $1}'`;
# 	    k=`echo $i|awk -F',' '{print $2}'`;
# 	    /usr/bin/setfacl -m u:bocadmin:rwx ${sftprootdir}"/"$j"/0"
# 	    for((h=0;h<=($wuguan_count - 1);h++)); do 
# 	        /usr/bin/setfacl -m u:bocadmin:rwx ${sftprootdir}"/"$j"/00"$h
# 	        for((hh=0;hh<=($wuguan_count - 1);hh++)); do
# 	            if [ $h -ne $hh ]; then
# 	                /usr/bin/setfacl -m u:"cst"$j"00"$h:- ${sftprootdir}"/"$j"/00"$hh
# 	            fi
# 	        done
# 	    done
# 	
# 	done
# }

usage(){
    echo "
        -h help
        -a action: init/add 初始化 和 后期增加用户
        -f file:   指定建立分行和物管公司的文件
            
            e.g:
                ./add_user.sh -a init -f conf 
                ./add_user.sh -a add -f conf 

            conf 文件格式：
                11,北京市,5
                12,天津市,6
                ......

                用英文逗号分隔的三列，分别为分行id，分行名称，分行下的物管公司数

            使用实例: 

                1、第一次使用该脚本时选择 init 模式：

                    # vim conf 
                        11,北京市,5
                        12,天津市,6

                    # ./add_user.sh -a init -f conf 

                    此时会初始化存储目录，并创建分行管理员账户、分行下的物管公司账户
                    密码文件为 bocsftp.passwd 妥善保存
                    
                2、以后每次使用该脚本增加分行、增加分行下物管公司的情况
                    !!!基于上次使用过的conf文件进行修改!!! 
                    以免对已有用户造成影响

                    # vim conf 
                        11,北京市,10   # 物管公司数改为10，会在该分行增加5个物管公司，编号会根据已有物管公司延续
                        12,天津市,6    # 未改变
                        13,广东省,5    # 新增了分行，并在分行下建立5个物管公司

                    # ./add_user.sh -a add -f conf 

                    新用户的密码会追加到 bocsftp.passwd 文件里，
                    如果用户已删除了 bocsftp.passwd 则会生成新的 bocsftp.passwd
                    且文件里只有新增用户的用户名、密码信息
    "
    exit 0
}


while [ $# -gt 0 ]; do

    case $1 in
        "-a")
            shift
            action=$1
            ;;
        "-f")
            shift
            file=$1
            ;;
        "-h")
            usage
            ;;
    esac
    shift
done

echo $action" " $file

if [ -f $file ]; then
    allsubbranch=`cat $file | tr ['\n'] [' ']`
else
    err "未找到配置文件: $file"
fi

echo "$allsubbranch"

if [ "$action" == "init" ] || [ "$action" == "add" ]; then
    echo "running the $action command"

    if [ "$action" == "init" ]; then
        # # 以初始化的方式添加用户，限第一次创建用户时使用
        clean_date_dir
        clean_passwdfile
        create_admin
        mkalldir
        # configauth
        # 
        #修改sshd_config文件并重启sshd服务
        if grep -q "#already modify" /etc/ssh/sshd_config ; then
        	/bin/cp /etc/ssh/sshd_config_bak  /etc/ssh/sshd_config  
        else
        	/bin/cp /etc/ssh/sshd_config /etc/ssh/sshd_config_bak
        fi
        echo "#already modify" >>/etc/ssh/sshd_config
        sed -i '/Subsystem/s/^/#/g' /etc/ssh/sshd_config
        echo "Subsystem sftp internal-sftp" >>/etc/ssh/sshd_config
        cat $includefile >>/etc/ssh/sshd_config
        /sbin/service sshd restart
    else
        mkalldir
        cat $includefile >>/etc/ssh/sshd_config
        /sbin/service sshd restart
    fi
else
    echo "no such command"
    exit 0
fi

