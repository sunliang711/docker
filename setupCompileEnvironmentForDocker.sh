#!/bin/bash

##建立编译docker的环境
##在debian:jessie系统中运行
forcecheck(){
    if (($?!=0));then
        echo "somethind failed!"
        exit 1
    fi
    echo
}
shopt -s expand_aliases
RED=$(tput setaf 1)
RESET=$(tput sgr0)
WRONG="${RED}\u2717${RESET}"

if (($EUID!=0));then
    echo -e "Need run as ${RED}Root${RESET}  ${WRONG}"
    exit 1
fi
#1 linux
if [[ "$(uname)" != "Linux" ]];then
    echo -e "Not linux OS. ${WRONG}"
    exit 1
fi

#2 exists apt-get command
if ! command -v apt-get >/dev/null 2>&1;then
    echo -e "Can not find ${RED}apt-get${RESET} command. ${WRONG}"
    exit 1
fi

#3 debian version must jessie
if [[ ! -e /etc/os-release ]];then
    echo -e "Can not find /etc/os-release file.(Not debian? ) ${WRONG}"
    exit 1
fi

if ! grep '^VERSION=' /etc/os-release | grep -q jessie;then
# /etc/debian_version also contains version info
    echo -e "The current OS is not debian jessie ${WRONG}"
    exit 1
fi

# proxy="http://192.168.1.103:8118"
proxy="http://10.0.0.38:8118"
socksproxy="socks5://10.0.0.38:1080"
# allow replacing httpredir or deb mirror
export APT_MIRROR="deb.debian.org"
sed -ri "s/(httpredir|deb).debian.org/${APT_MIRROR}/g" /etc/apt/sources.list

mkdir -pv /go/src/github.com/docker/docker/keys/
#set apt-get proxy
echo 'Acquire::http::Proxy "$proxy";' >>/etc/apt/apt.conf
#install git
apt-get update && apt-get install -y git
git config --global http.proxy "$socksproxy"
git config --global https.proxy "$socksproxy"
git config --global http.postBuffer 524288000
git config --global http.postBuffer
# export GIT_TRACE_PACKET=1
# export GIT_TRACE=1
# export GIT_CURL_VERBOSE=1
alias curl="curl --proxy $proxy"
alias pipinstallfromproxy="pip install --proxy $proxy"
export https_proxy=$proxy
#download docker source
export TMPDOCKER=/tmp/docker
downloadDockerFrom(){
    source=$1
    case $source in
        nas)
            wget -O docker.tar.bz2 http://eaagle.iask.in:5000/fbsharing/Kd1Wo5wg
            tar -C /tmp -xjvf docker.tar.bz2
            ;;
        github)
            git clone https://github.com/moby/moby.git $TMPDOCKER
            ;;
    esac
}
dockerDirItems='api cli client cmd container contrib daemon Dockerfile Makefile keys'
dockerfull=1
for i in $dockerDirItems;do
    if [ ! -e "/tmp/docker/$i" ];then
        dockerfull=0
    fi
done
if (($dockerfull==0));then
    rm -rf /tmp/docker
    downloadDockerFrom github
    if (($?!=0));then
        downloadDockerFrom nas
    fi
    forcecheck
fi
# git clone https://github.com/docker/docker.git $TMPDOCKER
# git clone https://github.com/moby/moby.git $TMPDOCKER
# Add zfs ppa
cp $TMPDOCKER/keys/launchpad-ppa-zfs.asc /go/src/github.com/docker/docker/keys/
apt-key add /go/src/github.com/docker/docker/keys/launchpad-ppa-zfs.asc
echo deb http://ppa.launchpad.net/zfs-native/stable/ubuntu trusty main > /etc/apt/sources.list.d/zfs.list

# Packaged dependencies
apt-get update && apt-get install -y \
	apparmor \
	apt-utils \
	aufs-tools \
	automake \
	bash-completion \
	binutils-mingw-w64 \
	bsdmainutils \
	btrfs-tools \
	build-essential \
	clang \
	cmake \
	createrepo \
	curl \
	dpkg-sig \
	gcc-mingw-w64 \
	git \
	iptables \
	jq \
	less \
	libapparmor-dev \
	libcap-dev \
	libltdl-dev \
	libnl-3-dev \
	libprotobuf-c0-dev \
	libprotobuf-dev \
	libsystemd-journal-dev \
	libtool \
	libzfs-dev \
	mercurial \
	net-tools \
	pkg-config \
	protobuf-compiler \
	protobuf-c-compiler \
	python-dev \
	python-mock \
	python-pip \
	python-websocket \
	tar \
	ubuntu-zfs \
	vim \
	vim-common \
	xfsprogs \
	zip \
	--no-install-recommends \
	&& pipinstallfromproxy awscli==1.10.15
forcecheck
# Get lvm2 source for compiling statically
export LVM2_VERSION=2.02.103
mkdir -p /usr/local/lvm2 \
	&& curl  -fsSL "https://mirrors.kernel.org/sourceware/lvm2/LVM2.${LVM2_VERSION}.tgz" \
		| tar -xzC /usr/local/lvm2 --strip-components=1
# See https://git.fedorahosted.org/cgit/lvm2.git/refs/tags for release tags

# Compile and install lvm2
cd /usr/local/lvm2 \
	&& ./configure \
		--build="$(gcc -print-multiarch)" \
		--enable-static_link \
	&& make device-mapper \
	&& make install_device-mapper
# See https://git.fedorahosted.org/cgit/lvm2.git/tree/INSTALL

# Configure the container for OSX cross compilation
export OSX_SDK=MacOSX10.11.sdk
export OSX_CROSS_COMMIT=a9317c18a3a457ca0a657f08cc4d0d43c6cf8953
set -x \
	&& export OSXCROSS_PATH="/osxcross" \
	&& git clone https://github.com/tpoechtrager/osxcross.git $OSXCROSS_PATH \
	&& ( cd $OSXCROSS_PATH && git checkout -q $OSX_CROSS_COMMIT) \
	&& curl  -sSL https://s3.dockerproject.org/darwin/v2/${OSX_SDK}.tar.xz -o "${OSXCROSS_PATH}/tarballs/${OSX_SDK}.tar.xz" \
	&& UNATTENDED=yes OSX_VERSION_MIN=10.6 ${OSXCROSS_PATH}/build.sh
export PATH=/osxcross/target/bin:$PATH

# Install seccomp: the version shipped upstream is too old
export SECCOMP_VERSION=2.3.2
set -x \
	&& export SECCOMP_PATH="$(mktemp -d)" \
	&& curl  -fsSL "https://github.com/seccomp/libseccomp/releases/download/v${SECCOMP_VERSION}/libseccomp-${SECCOMP_VERSION}.tar.gz" \
		| tar -xzC "$SECCOMP_PATH" --strip-components=1 \
	&& ( \
		cd "$SECCOMP_PATH" \
		&& ./configure --prefix=/usr/local \
		&& make \
		&& make install \
		&& ldconfig \
	) \
	&& rm -rf "$SECCOMP_PATH"

# Install Go
# IMPORTANT: If the version of Go is updated, the Windows to Linux CI machines
#            will need updating, to avoid errors. Ping #docker-maintainers on IRC
#            with a heads-up.
export GO_VERSION=1.7.5
downloadGoSourceFrom(){
    case "$1" in
        github)
            curl  -fsSL "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
                | tar -xzC /usr/local
            ;;
        nas)
            gosource=/tmp/$(date +%Y%m%d%H%M)-go
            wget -O $gosource http://eaagle.iask.in:5000/fbsharing/bgvRvzlf
            tar -xzC /usr/local -f $gosource
            ;;
        *)
            exit 1
            ;;
    esac
}
# curl  -fsSL "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
# 	| tar -xzC /usr/local
downloadGoSourceFrom github
if (($?!=0));then
    downloadGoSourceFrom nas
    forcecheck
fi

export PATH=/go/bin:/usr/local/go/bin:$PATH
export GOPATH=/go

# Compile Go for cross compilation
export DOCKER_CROSSPLATFORMS='linux/386 linux/arm  darwin/amd64  freebsd/amd64 freebsd/386 freebsd/arm  windows/amd64 windows/386  solaris/amd64'

# Dependency for golint
export GO_TOOLS_COMMIT=823804e1ae08dbb14eb807afc7db9993bc9e3cc3
git clone https://github.com/golang/tools.git /go/src/golang.org/x/tools \
	&& (cd /go/src/golang.org/x/tools && git checkout -q $GO_TOOLS_COMMIT)

# Grab Go's lint tool
export GO_LINT_COMMIT=32a87160691b3c96046c0c678fe57c5bef761456
git clone https://github.com/golang/lint.git /go/src/github.com/golang/lint \
	&& (cd /go/src/github.com/golang/lint && git checkout -q $GO_LINT_COMMIT) \
	&& go install -v github.com/golang/lint/golint

# Install CRIU for checkpoint/restore support
export CRIU_VERSION=2.9
mkdir -p /usr/src/criu \
	&& curl  -sSL https://github.com/xemul/criu/archive/v${CRIU_VERSION}.tar.gz | tar -v -C /usr/src/criu/ -xz --strip-components=1 \
	&& cd /usr/src/criu \
	&& make \
	&& make install-criu

# Install two versions of the registry. The first is an older version that
# only supports schema1 manifests. The second is a newer version that supports
# both. This allows integration-cli tests to cover push/pull with both schema1
# and schema2 manifests.
export REGISTRY_COMMIT_SCHEMA1=ec87e9b6971d831f0eff752ddb54fb64693e51cd
export REGISTRY_COMMIT=47a064d4195a9b56133891bbb13620c3ac83a827
set -x \
	&& export GOPATH="$(mktemp -d)" \
	&& git clone https://github.com/docker/distribution.git "$GOPATH/src/github.com/docker/distribution" \
	&& (cd "$GOPATH/src/github.com/docker/distribution" && git checkout -q "$REGISTRY_COMMIT") \
	&& GOPATH="$GOPATH/src/github.com/docker/distribution/Godeps/_workspace:$GOPATH" \
		go build -o /usr/local/bin/registry-v2 github.com/docker/distribution/cmd/registry \
	&& (cd "$GOPATH/src/github.com/docker/distribution" && git checkout -q "$REGISTRY_COMMIT_SCHEMA1") \
	&& GOPATH="$GOPATH/src/github.com/docker/distribution/Godeps/_workspace:$GOPATH" \
		go build -o /usr/local/bin/registry-v2-schema1 github.com/docker/distribution/cmd/registry \
	&& rm -rf "$GOPATH"

# Install notary and notary-server
export NOTARY_VERSION=v0.5.0
set -x \
	&& export GOPATH="$(mktemp -d)" \
	&& git clone https://github.com/docker/notary.git "$GOPATH/src/github.com/docker/notary" \
	&& (cd "$GOPATH/src/github.com/docker/notary" && git checkout -q "$NOTARY_VERSION") \
	&& GOPATH="$GOPATH/src/github.com/docker/notary/vendor:$GOPATH" \
		go build -o /usr/local/bin/notary-server github.com/docker/notary/cmd/notary-server \
	&& GOPATH="$GOPATH/src/github.com/docker/notary/vendor:$GOPATH" \
		go build -o /usr/local/bin/notary github.com/docker/notary/cmd/notary \
	&& rm -rf "$GOPATH"

# Get the "docker-py" source so we can run their integration tests
export DOCKER_PY_COMMIT=4a08d04aef0595322e1b5ac7c52f28a931da85a5
git clone https://github.com/docker/docker-py.git /docker-py \
	&& cd /docker-py \
	&& git checkout -q $DOCKER_PY_COMMIT \
	&& pipinstallfromproxy docker-pycreds==0.2.1 \
	&& pipinstallfromproxy -r test-requirements.txt

# Install yamllint for validating swagger.yaml
pipinstallfromproxy yamllint==1.5.0

# Install go-swagger for validating swagger.yaml
export GO_SWAGGER_COMMIT=c28258affb0b6251755d92489ef685af8d4ff3eb
git clone https://github.com/go-swagger/go-swagger.git /go/src/github.com/go-swagger/go-swagger \
	&& (cd /go/src/github.com/go-swagger/go-swagger && git checkout -q $GO_SWAGGER_COMMIT) \
	&& go install -v github.com/go-swagger/go-swagger/cmd/swagger

# Set user.email so crosbymichael's in-container merge commits go smoothly
git config --global user.email 'docker-dummy@example.com'

# Add an unprivileged user to be used for tests which need it
groupadd -r docker
useradd --create-home --gid docker unprivilegeduser

# VOLUME /var/lib/docker
# WORKDIR /go/src/github.com/docker/docker
export DOCKER_BUILDTAGS='apparmor pkcs11 seccomp selinux'

# Let us use a .bashrc file
ln -sfv $PWD/.bashrc ~/.bashrc
# Add integration helps to bashrc
echo "source $PWD/hack/make/.integration-test-helpers" >> /etc/bash.bashrc

# Register Docker's bash completion.
ln -sv $PWD/contrib/completion/bash/docker /etc/bash_completion.d/docker

# Get useful and necessary Hub images so we can "docker load" locally instead of pulling
cp $TMPDOCKER/contrib/download-frozen-image-v2.sh /go/src/github.com/docker/docker/contrib/
./contrib/download-frozen-image-v2.sh /docker-frozen-images \
	buildpack-deps:jessie@sha256:25785f89240fbcdd8a74bdaf30dd5599a9523882c6dfc567f2e9ef7cf6f79db6 \
	busybox:latest@sha256:e4f93f6ed15a0cdd342f5aae387886fba0ab98af0a102da6276eaf24d6e6ade0 \
	debian:jessie@sha256:f968f10b4b523737e253a97eac59b0d1420b5c19b69928d35801a6373ffe330e \
	hello-world:latest@sha256:8be990ef2aeb16dbcb9271ddfe2610fa6658d13f6dfb8bc72074cc1ca36966a7
# See also "hack/make/.ensure-frozen-images" (which needs to be updated any time this list is)

# Install tomlv, vndr, runc, containerd, tini, docker-proxy
# Please edit hack/dockerfile/install-binaries.sh to update them.
cp $TMPDOCKER/hack/dockerfile/binaries-commits /tmp/binaries-commits
cp $TMPDOCKER/hack/dockerfile/install-binaries.sh /tmp/install-binaries.sh
/tmp/install-binaries.sh tomlv vndr runc containerd tini proxy bindata

# Wrap all commands in the "docker-in-docker" script to allow nested containers
# ENTRYPOINT ["hack/dind"]

# for i in $(ls -A $TMPDOCKER);do
#     cp -r "$TMPDOCKER/$i" /go/src/github.com/docker/docker
# done
cp -nr $TMPDOCKER/* /go/src/github.com/docker/docker
cp -nr $TMPDOCKER/.git /go/src/github.com/docker/docker
cp -nr $TMPDOCKER/.gitignore /go/src/github.com/docker/docker
cp -nr $TMPDOCKER/.mailmap /go/src/github.com/docker/docker
cp -nr $TMPDOCKER/.dockerignore /go/src/github.com/docker/docker
cp -nr $TMPDOCKER/.idea /go/src/github.com/docker/docker

cat>/go/src/github.com/docker/docker/compileDocker.sh<<'EOF'
#compile docker using the following cmds
if (($EUID!=0));then
    echo "Need ROOT privilege!"
    exit 1
fi
export PATH=/osxcross/target/bin:$PATH
export PATH=/go/bin:/usr/local/go/bin:$PATH
export GOPATH=/go

cd /go/src/github.com/docker/docker
hack/make.sh binary
EOF
chmod +x /go/src/github.com/docker/docker/compileDocker.sh
echo "Now,you can 'cd' to /go/src/github.com/docker/docker to compile docker."
