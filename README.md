<img width="330" height="339" alt="11324af3ae5c6233dd66be42030c9d25" src="https://github.com/user-attachments/assets/ae8df542-8793-43c8-ab79-28abd9571c2c" />
deepseek写的，用nftables管理对外端口，bug未知，测试了开关tcp端口正常，udp没测试，第一次运行请初始化，会只保留22端口防止失联，同时还会阻止ping，选择完全禁用防火墙可开放ping及所有端口，只选只开所有端口不会开放ping，可能还有选项是无用的，会自己设nftables开机自启动，好像是成功的
本想把一键开关ping搞进去，奈何ai写的总是不能用，有大佬路过可以帮忙看看嘛！
