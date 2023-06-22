# 1. 许可
```
遵循 MIT 许可
```

# 2. 服务端和客户端
```
https://github.com/hwdsl2/setup-ipsec-vpn/
```

# 3. 配置环境
```
sudo cp ./vpn-client.service /lib/systemd/system
sudo ln -s /lib/systemd/system/vpn-client.service /etc/systemd/system/multi-user.target.wants/vpn-client.service

sudo systemctl start vpn-client   #链接VPN
sudo systemctl stop vpn-client    #断开链接VPN
sudo systemctl status vpn-client  #查看状态
```




