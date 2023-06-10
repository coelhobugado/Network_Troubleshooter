#!/bin/bash

# Configure estas variáveis de acordo com suas preferências
ip_address="192.168.1.100"
subnet_mask="255.255.255.0"
gateway="192.168.1.1"
primary_dns="8.8.8.8"
secondary_dns="8.8.4.4"

echo "Verificando a conexão com a internet..."
ping -c 1 -w 1 www.google.com >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Você já está conectado à internet. Fechando..."
    sleep 5
    exit 0
fi

echo "Tentando resolver problemas de rede..."

# Detecta a interface de rede ativa
active_interface=$(ip route | grep '^default' | awk '{print $5}')
if [ -z "$active_interface" ]; then
    echo "Nenhuma interface de rede ativa encontrada."
    # Tenta ativar a primeira interface de rede encontrada
    interface_name=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;exit}')
    if [ -z "$interface_name" ]; then
        echo "Não foi possível encontrar uma interface de rede."
        exit 1
    fi
    echo "Ativando a interface de rede $interface_name"
    ip link set dev $interface_name up
    active_interface=$interface_name
fi
interface_name=$active_interface

# Verificar se as configurações de IP, máscara de sub-rede e DNS estão corretas
config_correct=true

current_ip=$(ip -4 addr show $interface_name | grep -oP "(?<=inet\s)\d+(\.\d+){3}")
current_subnet_mask=$(ip -4 addr show $interface_name | grep -oP "(?<=/)\d+")
current_gateway=$(ip route | grep default | grep -oP "\d+(\.\d+){3}")
current_dns=$(grep nameserver /etc/resolv.conf | grep -oP "\d+(\.\d+){3}")

if [ "$current_ip" != "$ip_address" ] || [ "$current_subnet_mask" != "$subnet_mask" ] || [ "$current_gateway" != "$gateway" ] || [ "$current_dns" != "$primary_dns" ]; then
    config_correct=false
fi

if $config_correct; then
    echo "As configurações de IP, máscara de sub-rede e DNS estão corretas. Tentando outras correções..."
else
    echo "Configurando endereço IP, máscara de sub-rede e servidores DNS..."
    ip addr flush dev $interface_name
    ip addr add $ip_address/$subnet_mask dev $interface_name
    ip link set dev $interface_name up
    ip route add default via $gateway
    echo -e "nameserver $primary_dns\nnameserver $secondary_dns" >/etc/resolv.conf
fi

# Verifica se a interface de rede está ativa
if ! ip link show $interface_name up >/dev/null 2>&1; then
    echo "Ativando a interface de rede $interface_name"
    ip link set dev $interface_name up
fi

# Liberação e renovação de endereço IP (DHCP)
echo "Liberação e renovação de endereço IP..."
dhclient -r $interface_name
dhclient $interface_name

# Redefinindo os sockets de rede e parâmetros de IP
echo "Redefinindo os sockets de rede e parâmetros de IP..."
systemctl restart networking.service

# Verifica se a conexão com a internet foi restabelecida
echo "Verificando novamente a conexão com a internet..."
ping -c 1 -w 1 www.google.com >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Conexão com a internet restabelecida!"
else
    # Verifica se a interface de rede está ativa
    if ! ip link show $interface_name up >/dev/null 2>&1; then
        echo "A interface de rede $interface_name não está ativa."
        echo "Tentando ativar a interface de rede $interface_name..."
        ip link set dev $interface_name up
        echo "Interface de rede $interface_name ativada."
    fi

    # Verifica se as configurações de rede estão corretas
    echo "Verificando as configurações de rede..."
    current_ip=$(ip -4 addr show $interface_name | grep -oP "(?<=inet\s)\d+(\.\d+){3}")
    current_subnet_mask=$(ip -4 addr show $interface_name | grep -oP "(?<=/)\d+")
    current_gateway=$(ip route | grep default | grep -oP "\d+(\.\d+){3}")
    current_dns=$(grep nameserver /etc/resolv.conf | grep -oP "\d+(\.\d+){3}")

    if [ "$current_ip" != "$ip_address" ] || [ "$current_subnet_mask" != "$subnet_mask" ] || [ "$current_gateway" != "$gateway" ] || [ "$current_dns" != "$primary_dns" ]; then
        echo "Configurando endereço IP, máscara de sub-rede e servidores DNS..."
        ip addr flush dev $interface_name
        ip addr add $ip_address/$subnet_mask dev $interface_name
        ip link set dev $interface_name up
        ip route add default via $gateway
        echo -e "nameserver $primary_dns\nnameserver $secondary_dns" >/etc/resolv.conf

        echo "Configurações de rede atualizadas!"
    else
        echo "As configurações de rede estão corretas."
    fi

    # Verifica novamente a conexão com a internet
    echo "Verificando novamente a conexão com a internet..."
    ping -c 1 -w 1 www.google.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Conexão com a internet restabelecida!"
    else
        echo "Não foi possível restabelecer a conexão com a internet automaticamente."
        echo "Verifique suas configurações de rede."
    fi
fi

read -p "Pressione qualquer tecla para continuar..."