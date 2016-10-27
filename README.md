# 使用介绍

文件：

1、check-dev.sh ====>监控脚本                 

2、zabbix_agentd.conf ====>自定义key

3、zabbix_OMSA.xml ====>zabbix监控模板

4、说明文件



> 注意：以上文件配置和放置位置根据使用者自己情况更改，使用该套监控需要安装OMSA套件，具体方法见我博客：[http://yigemeng.blog.51cto.com/8638584/1731828](http://yigemeng.blog.51cto.com/8638584/1731828)

 

使用方法：

1、将监控脚本（check-dev.sh）放到需要加监控得服务器（agent端）上

2、将自定义key写入到zabbix_agentd.conf配置文件中，重启zabbix_agentd服务；

3、将OMSA 监控模板在zabibx web界面中选中模板

4、脚本中有使用MegaCli来获取硬盘、BBU信息，所以需要授权sudo权限



```
[root@localhost ~]#visudo （vim /etc/sudoers）

zabbix ALL=(ALL)       NOPASSWD:/usr/sbin/MegaCli  （根据实际情况写上MegaCli路径）

```





### 执行脚本

脚本格式

```
check-dev.sh $1 $2 $3
```



发现设备(**CPU**）

```
check-dev.sh discovery cpu
```



获取数据(**CPU状态**）

```
check-dev.sh get-data cpu_status
```



item都在脚本中有，具体看脚本。脚本low，轻喷，只是为了分享个方法。





