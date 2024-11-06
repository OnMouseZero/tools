#!/bin/bash

# 检查是否以 root 用户执行
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 用户身份运行此脚本"
    exit 1
fi

# 配置项
DOMAIN="netbox.5x5y.cn"             # 替换为您的子域名
NETBOX_HOST="localhost"              # NetBox 服务器主机
NETBOX_PORT="8000"                   # NetBox 服务器端口
SSL_DIR="/etc/nginx/ssl"             # SSL 证书存放目录
CERT_FILE="$SSL_DIR/$DOMAIN.crt"     # 证书文件路径
KEY_FILE="$SSL_DIR/$DOMAIN.key"      # 私钥文件路径
CA_NAME="5x5y-Finance"
CA_KEY_FILE="$SSL_DIR/$CA_NAME.key"
CA_CRT_FILE="$SSL_DIR/$CA_NAME.crt"
COUNTRY="CN"
STATE="FuJian"
LOCATION="XiaMen"
ORGANIZATION="5x5y-Finance Inc."
ORGANIZATIONAL_UNIT="Digital Management Department"  # 组织单位
EMAIL="admin@5x5y.cn"
VALID_DAYS_CA=3650        # CA证书的有效期（单位：天）
VALID_DAYS=365            # 服务器证书的有效期（单位：天）

# 安装 NGINX
if ! command -v nginx &> /dev/null; then
    echo "安装 NGINX..."
    dnf install -y nginx
else
    echo "NGINX 已安装"
fi

# 创建 SSL 证书目录
mkdir -p "$SSL_DIR"

# 生成自签名 CA 证书（如果不存在）
if [[ ! -f "$CA_KEY_FILE" || ! -f "$CA_CRT_FILE" ]]; then
    echo "生成 CA 证书..."
    openssl genrsa -out "$CA_KEY_FILE" 4096
    openssl req -x509 -new -nodes -key "$CA_KEY_FILE" -sha256 -days "$VALID_DAYS_CA" -out "$CA_CRT_FILE" \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCATION}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=${CA_NAME}/emailAddress=${EMAIL}"
fi

# 生成服务器证书和私钥（如果不存在）
if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
    echo "生成服务器的私钥和证书签名请求..."
    openssl genrsa -out "$KEY_FILE" 2048
    openssl req -new -key "$KEY_FILE" -out "$SSL_DIR/$DOMAIN.csr" \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCATION}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=${DOMAIN}/emailAddress=${EMAIL}"

    echo "使用 CA 签署服务器证书..."
    openssl x509 -req -in "$SSL_DIR/$DOMAIN.csr" -CA "$CA_CRT_FILE" -CAkey "$CA_KEY_FILE" -CAcreateserial \
        -out "$CERT_FILE" -days "$VALID_DAYS" -sha256
    rm -f "$SSL_DIR/$DOMAIN.csr"  # 清理 CSR 文件
fi

# 配置 NGINX 代理并覆盖 /etc/nginx/nginx.conf
echo "生成 NGINX 配置文件..."

cat > /etc/nginx/nginx.conf <<EOF
worker_processes auto;
events { worker_connections 1024; }

http {
    server {
        listen 80;
        server_name $DOMAIN;
        return 301 https://$DOMAIN\$request_uri;
    }

    server {
        listen 443 ssl;
        server_name $DOMAIN;

        ssl_certificate     $CERT_FILE;
        ssl_certificate_key $KEY_FILE;

        location / {
            proxy_pass http://$NETBOX_HOST:$NETBOX_PORT;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

# 启用并启动 NGINX 服务
echo "启用并启动 NGINX 服务..."
systemctl enable nginx --now

# 测试 NGINX 配置并重启服务
echo "测试 NGINX 配置并重启服务..."
nginx -t && systemctl restart nginx

echo "NGINX 已配置完成并启动，代理到 NetBox ($NETBOX_HOST:$NETBOX_PORT)"
echo "访问地址: https://$DOMAIN"
echo "CA 证书路径: $CA_CRT_FILE"
echo "服务器证书路径: $CERT_FILE"
echo "私钥路径: $KEY_FILE"

