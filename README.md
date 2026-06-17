# reinstall_after

reinstall 脚本重装之后 安全相关的脚本





reinstall 重装系统

```
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O ${_##*/} $_
bash reinstall.sh ubuntu --minimal

(设置账号密码 后面登录要用这个)

root
```

再次连接ssh  查看dd log

          tail -fn+1 /reinstall.log

重装结束之后 执行脚本

```
curl -sSO https://raw.githubusercontent.com/return2002o/reinstall_after/main/nopassword.sh && bash nopassword.sh && rm -f nopassword.sh
```

