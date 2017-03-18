#第一步,找出所有导入的包
#下面两个正则分别对应块导入和单行导入
find .  -name "*.go" -print0|xargs -0 sed -rn -e "/^import\s+\(/,/\)/p" -e "/^import\s+[^(]+/p" > allImports

#第二步,过滤掉自带的包(依据是有无反斜杠)和注释语句
#通过观察发现github.com和golang.org上面在包的路径至少有两个反斜杠
#所以抽取形如 "xxxx/xxx/xxx"的import路径即可 另外第一部分要有点号
# grep -Po '(?<=")[^/]+/[^/]+/[^/]+[^"]+(?=")' allImports | sort |uniq >result
grep -Po '(?<=")[^.]+\.[^.]+/[^/]+/[^/]+[^"]+(?=")' allImports | sort |uniq >result

totalLines=$(wc -l result | grep -Po '\d+')
index=1
RED=$(tput setaf 1)
RESET=$(tput sgr0)
#注意点,go get使用的是版本管理工具下载的,如果有需要的话,先设置git的proxy
while read import;do
    echo -e "${RED}[${index}/${totalLines}]${RESET} go get ${RED}$import${RESET} ..."
    go get $import
    ((index++))
done<result
