# DOMjudge installer

original repository: https://github.com/melongist/CSL

## Support version

* Ubuntu 24.04 x86_64
* DOMjudge 9.0.0

## Guide

DOMjudge 9.0.0 채점 환경을 구축하는 전체 과정입니다. 모든 스크립트는 **Ubuntu 24.04 LTS x86_64** 에서만 동작하며, PC / AWS(EC2) / GCE 환경을 지원합니다.

### 구성 개요

DOMjudge 는 크게 세 가지 역할로 나뉩니다.

* **domserver** : 웹 인터페이스 + REST API (참가자/심사위원이 접속하는 서버)
* **db** : MariaDB 데이터베이스
* **judgehost** : 제출된 코드를 실제로 채점하는 전용 머신

judgehost 는 채점 일관성을 위해 항상 **별도의 전용 머신**에 설치하는 것을 권장합니다. domserver 와 db 는 다음 두 가지 방식 중 하나로 설치할 수 있습니다.

| 방식 | 설명 | 사용하는 스크립트 |
| --- | --- | --- |
| **단일 호스트** | domserver 와 db 를 같은 머신에 설치 (소규모/테스트) | `dj900server.sh` (DB 위치 = `local`) |
| **분리 호스트** | domserver 와 db 를 서로 다른 머신에 설치 (대규모) | `dj900db.sh` + `dj900server.sh` (DB 위치 = `external`) |

준비물 예시:

* 4코어 8GB 이상 머신 2개 이상
  * domserver(+db) 1대, judgehost 1대 이상
  * db 를 분리한다면 db 전용 머신 1대 추가
* 도메인(예: `test.icpc.kr`)을 domserver 의 public IP 에 DNS A 레코드로 연결

> 이 가이드의 예시는 도메인 `test.icpc.kr`, 리눅스 유저 `jhnah917` 을 기준으로 합니다. 본인 환경에 맞게 바꿔 사용하세요.

---

### 0. 공통 사전 준비 (모든 머신)

각 머신에서 root 로 접속해 작업용 non-root 유저를 만들고 방화벽 포트를 엽니다.

```bash
ssh root@<머신 주소>

adduser jhnah917
usermod -aG sudo jhnah917
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
exit
```

이후 모든 설치 작업은 생성한 non-root 유저로 진행합니다. (스크립트는 `sudo` 로 실행하면 안 되고, `bash <스크립트>` 형태로 실행해야 합니다.)

---

## A. domserver + db (단일 호스트)

domserver 와 db 를 한 머신에 설치하는 가장 단순한 방식입니다. db 를 분리하려면 이 섹션을 건너뛰고 **섹션 B** 로 진행하세요.

### A-1. domserver 설치

```bash
ssh jhnah917@test.icpc.kr

wget https://raw.githubusercontent.com/justiceHui/domjudge-installer/main/dj900server.sh
bash dj900server.sh
```

설치 중 입력 항목:

* `apache2 or nginx? [apache2/nginx]:` → 대규모 대회는 **nginx** 권장
* (nginx 선택 시) `Server's public IP address associated with the domain name? [y/n]:` → `y`
* 이후 도메인 입력 (확인 위해 2번 입력): `test.icpc.kr`
* `Database location? [local/external]:` → **`local`** (단일 호스트이므로)
* timezone 선택: `4`(Asia) → `28`(South Korea) → `1`(Yes)
* 이후 충분히 기다림
* (선택) ssh 설정 관련 보라색 창이 뜨면 그냥 엔터 (keep the local version currently installed)
* MariaDB 보안 설정(`mysql_secure_installation`):
  * `Enter current password for root (enter for none):` → 그냥 엔터
  * `Switch to unix_socket authentication [Y/n]:` → `N`
  * `Change the root password? [Y/n]:` → `Y` → MariaDB root 비밀번호 입력 (예: `asdf`)
  * `Remove anonymous user? [Y/n]:` → `Y`
  * `Disallow root login remotely? [Y/n]:` → `Y`
  * `Remove test database and access to it? [Y/n]:` → `Y`
  * `Reload privilege tables now? [Y/n]:` → `Y`
* `[sudo] password for jhnah917:` → 리눅스 유저 비밀번호 입력
* `Enter password:` → 위에서 정한 MariaDB root 비밀번호(`asdf`) 입력 (DB 생성 시 2번 입력)
* 이후 충분히 기다림 → 서버 자동 재부팅

### A-2. 설치 확인

```bash
ssh jhnah917@test.icpc.kr

cat readme.txt
# ID : admin
# PW : (initial_admin_password.secret 값)
# Domain name URL : http://test.icpc.kr
# judgehost PW : (judgehost 설치 시 사용할 비밀번호)
```

* 브라우저에서 `http://test.icpc.kr` 접속이 되는지 확인합니다.
* `readme.txt` 에 적힌 **admin 비밀번호**와 **judgehost PW** 는 이후 단계에서 사용하므로 잘 보관하세요.

### A-3. HTTPS 적용 (선택)

`dj900server.sh` 가 `dj900https.sh` 를 자동으로 내려받아 두므로 바로 실행할 수 있습니다.

```bash
bash dj900https.sh
```

* `Did you associate ... A record? [y/n]:` → `y`
* 도메인 입력 (2번): `test.icpc.kr`
* 이후 certbot 안내에 따라 진행
* `https://test.icpc.kr` 접속이 되는지 확인합니다.

> HTTPS 를 적용하면 judgehost 에 입력할 서버 URL 은 `https://test.icpc.kr` 가 됩니다.

---

## B. domserver / db 분리 호스트

db 를 별도 머신에 설치하는 방식입니다. **반드시 db 머신을 먼저 설정한 뒤 domserver 를 설치**합니다.

### B-1. db 머신 설치 (`dj900db.sh`)

db 전용 머신에서 실행합니다. 이 스크립트는 MariaDB 를 설치하고, 지정한 domserver IP 에서만 접속을 허용하도록 설정합니다.

```bash
ssh jhnah917@<db 머신 주소>

wget https://raw.githubusercontent.com/justiceHui/domjudge-installer/main/dj900db.sh
bash dj900db.sh
```

설치 중 입력 항목:

* `Input domserver IP :` → **domserver 머신의 IP** (2번 입력). 이 IP 에서만 3306 포트 접속이 허용되고, `root'@'<이 IP>'` 계정도 이 IP 로만 생성됩니다.
  * ⚠️ 여기 입력하는 IP 는 **db 머신이 실제로 보게 되는 domserver 의 출발지 IP** 와 정확히 일치해야 합니다. 같은 사설망(VPC)으로 붙으면 domserver 의 **private IP**, 인터넷을 거쳐 붙으면 **public IP** 를 입력하세요. (NAT/다중 인터페이스로 출발지 IP 가 어긋나면 B-2 에서 `Access denied` 가 발생합니다.)
* timezone 선택: `4` → `28` → `1`
* MariaDB 보안 설정(`mysql_secure_installation`): A-1 과 동일하게 진행하고, **root 비밀번호를 기억해 둡니다.**
* `Input MariaDB root password :` → 방금 정한 root 비밀번호 입력 (2번). `root'@'<domserver IP>` 계정에 부여되어 domserver 가 원격으로 DB 설치를 수행할 수 있게 합니다.
* 이후 자동 재부팅

재부팅 후 `cat readme.txt` 로 **DB host (private/public IP)** 와 허용된 domserver IP 를 확인합니다. 이 DB host 값을 다음 단계에서 사용합니다.

> db 머신과 domserver 가 같은 사설망(예: VPC) 안에 있다면 **private IP** 를, 그렇지 않다면 public IP 를 사용하세요. 3306 포트는 domserver IP 에서만 열려 있어야 합니다.

### B-2. domserver 설치 (`dj900server.sh`, external 모드)

domserver 머신에서 실행합니다.

```bash
ssh jhnah917@test.icpc.kr

wget https://raw.githubusercontent.com/justiceHui/domjudge-installer/main/dj900server.sh
bash dj900server.sh
```

설치 중 입력 항목 (단일 호스트와 차이나는 부분만 표시):

* `apache2 or nginx? [apache2/nginx]:` → `nginx` (예시)
* (nginx) 도메인 입력: `test.icpc.kr`
* `Database location? [local/external]:` → **`external`**
* `Input DB host :` → **B-1 에서 확인한 db 머신의 IP** (2번 입력)
* timezone 선택: `4` → `28` → `1`
* 이 모드에서는 로컬에 MariaDB 를 설치하지 않고 `mariadb-client` 만 설치합니다 (`mysql_secure_installation` 단계 없음).
* `Enter the MariaDB root password ... to grant the 'domjudge' app user remote access:` → **B-1 의 root 비밀번호** 입력
  * (원격 DB 에 `domjudge` 애플리케이션 유저와 권한을 미리 생성하는 단계입니다.)
* 이후 `dj_setup_database ... install` 단계에서 **B-1 의 root 비밀번호를 다시 2번** 묻습니다 (`Enter password:`). DB 생성과 스키마 마이그레이션에서 각각 1번씩 입력하면 됩니다.
  * 즉 external 모드에서는 root 비밀번호를 grant 1번 + install 2번, 총 **3번** 입력하게 됩니다. 반복되는 `Enter password:` 는 정상이니 그대로 같은 비밀번호를 입력하세요.
* 이후 자동 재부팅

### B-3. 설치 확인 / HTTPS

A-2, A-3 과 동일합니다. `cat readme.txt` 로 admin 비밀번호와 judgehost PW 를 확인하고, 필요하면 `bash dj900https.sh` 로 HTTPS 를 적용합니다.

---

## C. judgehost (전용 채점 머신)

domserver(및 db) 설치가 끝난 뒤, judgehost 전용 머신마다 아래 과정을 반복합니다.

### C-1. judgehost 설치

```bash
ssh jhnah917@<judgehost 주소>

wget https://raw.githubusercontent.com/justiceHui/domjudge-installer/main/dj900judgehost.sh
bash dj900judgehost.sh
```

설치 중 입력 항목:

* `Did you make Domjudge server? [y/n]:` → `y`
* timezone 선택: `4` → `28` → `1`
* `Input server's URL:` → domserver 의 URL (2번 입력)
  * HTTP: `http://test.icpc.kr`
  * HTTPS 적용했다면: `https://test.icpc.kr`
* `Input judgehost PW :` → domserver 의 `readme.txt` 에 있던 **judgehost PW** 입력 (2번)
* 이후 chroot 생성 등으로 충분히 기다림 → 자동 재부팅

> `dj900judgehost.sh` 는 cgroup 사용을 위해 GRUB 커널 파라미터(`cgroup_enable=memory swapaccount=1` 등)와 `create-cgroups` 서비스를 자동으로 설정합니다. 재부팅이 끝나면 이 설정이 적용됩니다.

### C-2. 권한 설정 후 judgehost 재시작

재부팅 후, chroot 환경에 채점용 유저/그룹 정보를 반영하고 judgedaemon 을 기동합니다.

```bash
ssh jhnah917@<judgehost 주소>

sudo sh -c "grep '^domjudge-run' /etc/passwd >> /chroot/domjudge/etc/passwd"
sudo sh -c "grep '^domjudge-run' /etc/group  >> /chroot/domjudge/etc/group"
sed -i 's/DOMJUDGE_CREATE_WRITABLE_TEMP_DIR=1 //g' ~/dj900start.sh
bash ~/dj900start.sh
```

* `dj900start.sh` 는 CPU 코어 수(최대 64)에 맞춰 judgedaemon 을 자동으로 띄웁니다.
* domserver 웹 → **Judgehosts** 메뉴에서 이 judgehost 가 정상적으로 등록/활성화되었는지 확인합니다.

---

## D. domserver 성능 튜닝: `dj900mas.sh`

대회 규모가 커지면 동시 접속(참가자 스코어보드 새로고침, judgehost 체크인)을 감당할 만큼 PHP-FPM worker 수를 늘려야 합니다. `dj900mas.sh`(**M**emory **A**uto**S**caling)는 domserver 의 메모리 크기에 맞춰 PHP-FPM 의 `pm.max_children` 값을 자동으로 조정해 주는 스크립트입니다.

참고: [DOMjudge Wiki — Scaling and load testing](https://github.com/DOMjudge/domjudge/wiki/Scaling-and-load-testing)

### 무슨 일을 하나

* 현재 머신의 물리 메모리(GiB)를 읽어 `/etc/php/8.3/fpm/pool.d/domjudge.conf` 의 `pm.max_children` 를 **1GiB 당 20** 으로 설정합니다. (예: 8GiB → 160, 16GiB → 320)
* `pm.max_children` 값이 **실제로 바뀐 경우에만** php8.3-fpm 을 재시작하고 웹서버(nginx/apache2)를 reload 합니다. 즉 이 스크립트를 실행하면 **별도의 수동 서비스 재시작이 필요 없습니다.**
* `dj900mas.sh` 는 **MariaDB 설정을 변경하지 않으며, MariaDB 를 재시작하지도 않습니다.** (PHP-FPM 풀 설정만 다루므로 DB 를 건드릴 이유가 없습니다.)

### 언제·어떻게 실행하나

`dj900mas.sh` 는 `dj900server.sh` 가 설치 과정에서 domserver 의 홈 디렉터리에 내려받아 두고, `/etc/rc.local` 에 등록해 둡니다.

* **인스턴스 메모리를 변경한 경우**(예: 8GiB → 16GiB 로 리사이즈): 다음 중 하나면 충분합니다.
  * 그냥 **재부팅** → 부팅 시 `rc.local` 이 `dj900mas.sh` 를 자동 실행해 새 메모리에 맞게 `pm.max_children` 를 다시 계산합니다. (인스턴스 reboot 만으로 적용됨)
  * 재부팅 없이 즉시 적용하려면 domserver 에서 직접 실행:

    ```bash
    ssh jhnah917@test.icpc.kr
    bash dj900mas.sh
    ```

    `pm.max_children` 가 바뀌면 스크립트가 php-fpm 을 재시작하고 웹서버를 reload 하므로 **추가 재시작/재부팅은 불필요**합니다.
* **메모리 변화가 없으면** 스크립트는 `pm.max_children` 가 이미 목표값과 같음을 감지하고 아무것도 바꾸거나 재시작하지 않습니다.

### 주의 사항

* **`pm.max_children` 를 더 높게/낮게 직접 조정할 수도 있습니다.** 위키는 worker 1개가 실제로 약 **70MiB** 를 쓴다고 안내합니다(=1GiB 당 약 22개). `dj900mas.sh` 의 기본값은 **1GiB 당 20개**(worker 당 ~50MiB 가정)로 위키 권장치에 가깝게 보수적으로 잡혀 있습니다. 더 많은 동시 접속을 받아야 하거나 반대로 메모리 부족(OOM)이 우려되면 `/etc/php/8.3/fpm/pool.d/domjudge.conf` 의 `pm.max_children` 를 수동으로 조정한 뒤 `sudo service php8.3-fpm restart` 하세요.
* MariaDB 의 `max_connections` 는 전체 FPM worker 수 이상이어야 합니다. 설치 스크립트가 이미 `max_connections = 8192` 로 넉넉히 설정하므로 대부분의 경우 추가 조정이 필요 없습니다.
* **DB 튜닝은 별도입니다.** `dj900mas.sh` 는 PHP-FPM 만 다루고 MariaDB 는 건드리지 않습니다. DB 설정(`max_connections` 등)은 설치 시점에 `dj900server.sh`(local) 또는 `dj900db.sh`(external) 가 정하며, 분리(external) 모드에서 DB 를 추가로 튜닝하려면 **db 머신**에서 직접 수행해야 합니다.

---

## 참고 명령

* domserver 캐시 정리: `bash dj900clear.sh` (domserver 에 자동 설치됨)
* judgedaemon 수동 재시작: `bash ~/dj900start.sh` (judgehost)
* judgehost 의 서버 URL / PW 변경: domserver 의 `/opt/domjudge/domserver/etc/restapi.secret` 와 judgehost 의 `/opt/domjudge/judgehost/etc/restapi.secret` 를 함께 수정
* (분리 모드) db 머신에서 임시 원격 root 계정 회수:

  ```bash
  sudo mariadb -u root -e "DROP USER 'root'@'<domserver IP>'; FLUSH PRIVILEGES;"
  ```