#
# Start mount emmc....
#

case "$1" in
  start)
	echo "开始挂载EMMC，创建路径/mnt/emmc"
	mkdir -p /mnt/emmc
	mount -t ext2 /dev/mmcblk0p1 /mnt/emmc
	ret=$?
	if [ $ret -ne 0 ]; then
	echo "EMMC正在格式化..."
	echo -e "n \n p \n 1 \n \n \n w \n" | fdisk /dev/mmcblk1
	mkfs.ext2 /dev/mmcblk1p1
	mount -t ext2 /dev/mmcblk1p1 /mnt/emmc
	fi
	echo "EMMC挂载成功!"  
        if [ -f "/mnt/emmc/a.out" ]; then
		cd /mnt/emmc
		./a.out
	else
           echo "开始挂载TF，创建路径tmp"
	   mkdir -p /tmp
	   mount /dev/mmcblk0p1 /tmp
	   if [ -f "/tmp/a.out" ]; then
	       cp /tmp/a.out /mnt/emmc/a.out		
               echo "程序从TF卡复制到EMMC成功" 
	       cd /mnt/emmc
	       ./a.out
	   fi 
	fi 
	;;
  	stop)
	;;
  *)
	echo "Usage: $0 {start|stop}"
	exit 1
esac

exit $?
