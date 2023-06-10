@echo off
chcp 65001 >nul

:: Verifica se o script está sendo executado com privilégios de administrador
>nul 2>&1 net session
if %errorlevel% neq 0 (
    echo Este script requer privilégios de administrador.
    echo Por favor, execute-o novamente como administrador.
    timeout /t 5 >nul
    exit /b
)

:: Configurações da Rede
set "interface_name=Ethernet"
set "ip_address=192.168.1.100"
set "subnet_mask=255.255.255.0"
set "gateway=192.168.1.1"
set "primary_dns=8.8.8.8"
set "secondary_dns=8.8.4.4"

echo Verificando a conexão com a internet...
ping www.google.com -n 1 -w 1000 >nul 2>nul
if %errorlevel% equ 0 (
    echo Você já está conectado à internet. Fechando...
    timeout /t 5 /nobreak >nul
    exit
)

echo Tentando resolver problemas de rede...

rem Detecta a interface de rede ativa
set "active_interface="
for /f "tokens=2 delims=: " %%i in ('netsh interface show interface ^| findstr /i "%interface_name%"') do (
    set "status=%%i"
    if /i "!status!"=="Habilitado" set "active_interface=%interface_name%"
)

if not defined active_interface (
    echo Nenhuma interface de rede habilitada encontrada.
    echo Tentando habilitar a interface de rede %interface_name%...
    netsh interface set interface "%interface_name%" admin=enable >nul
    ping -n 5 localhost >nul
    set "active_interface="
    for /f "tokens=2 delims=: " %%i in ('netsh interface show interface ^| findstr /i "%interface_name%"') do (
        set "status=%%i"
        if /i "!status!"=="Habilitado" set "active_interface=%interface_name%"
    )
    if not defined active_interface (
        echo Não foi possível encontrar ou habilitar a interface de rede %interface_name%.
        exit 1
    )
)

rem Verificar se as configurações de IP, máscara de sub-rede e DNS estão corretas
set "config_correct=true"

for /f "tokens=1-2 delims=:" %%a in ('ipconfig /all ^| findstr /C:"IPv4 Address" /C:"Subnet Mask" /C:"Default Gateway" /C:"DNS Servers"') do (
    set "parameter=%%a"
    set "value=%%b"
    setlocal enabledelayedexpansion
    set "value=!value:~1!"
    if "!parameter!"=="IPv4 Address" if not "!value!"=="%ip_address%" set "config_correct=false"
    if "!parameter!"=="Subnet Mask" if not "!value!"=="%subnet_mask%" set "config_correct=false"
    if "!parameter!"=="Default Gateway" if not "!value!"=="%gateway%" set "config_correct=false"
    if "!parameter!"=="DNS Servers" (
        for /f "tokens=1,2 delims=," %%c in ("!value!") do (
            if not "%%c"=="%primary_dns%" if not "%%d"=="%secondary_dns%" set "config_correct=false"
        )
    )
    endlocal
)

if %config_correct% equ true (
    echo As configurações de IP, máscara de sub-rede e DNS estão corretas. Tentando outras correções...
) else (
    echo Tentando configurar usando DHCP...
    netsh interface ip set address "%interface_name%" dhcp
    netsh interface ip set dns "%interface_name%" dhcp

    rem Verifica se as configurações via DHCP foram aplicadas corretamente
    set "dhcp_config_correct=true"

    for /f "tokens=1-2 delims=:" %%a in ('ipconfig /all ^| findstr /C:"IPv4 Address" /C:"Subnet Mask" /C:"Default Gateway" /C:"DNS Servers"') do (
        set "parameter=%%a"
        set "value=%%b"
        setlocal enabledelayedexpansion
        set "value=!value:~1!"
        if "!parameter!"=="IPv4 Address" if not "!value!"=="%ip_address%" set "dhcp_config_correct=false"
        if "!parameter!"=="Subnet Mask" if not "!value!"=="%subnet_mask%" set "dhcp_config_correct=false"
        if "!parameter!"=="Default Gateway" if not "!value!"=="%gateway%" set "dhcp_config_correct=false"
        if "!parameter!"=="DNS Servers" (
            for /f "tokens=1,2 delims=," %%c in ("!value!") do (
                if not "%%c"=="%primary_dns%" if not "%%d"=="%secondary_dns%" set "dhcp_config_correct=false"
            )
        )
        endlocal
    )

    if %dhcp_config_correct% equ false (
        echo Não foi possível configurar via DHCP. Tentando configuração manual...

        rem Define as configurações de IP manualmente
        netsh interface ip set address "%interface_name%" static %ip_address% %subnet_mask% %gateway%
        netsh interface ip set dns "%interface_name%" static %primary_dns% primary
        netsh interface ip add dns "%interface_name%" %secondary_dns% index=2
    )
)

rem Libera o endereço IP atual e força a renovação do mesmo
echo Liberação e renovação de endereço IP...
ipconfig /release "*"
ipconfig /renew "*"

rem Redefine os sockets de rede e reseta os parâmetros de IP
echo Redefinindo os sockets de rede e parâmetros de IP...
netsh winsock reset /f >nul
netsh int ip reset /f >nul

rem Redefine as configurações de firewall
echo Redefinindo configurações de firewall...
netsh advfirewall reset >nul

rem Reinicia o serviço DHCP e DNS Client
echo Reiniciando serviços de DHCP e DNS Client...
net stop dhcp
net start dhcp
net stop dnscache
net start dnscache

echo Verificando novamente a conexão com a internet...
ping www.google.com -n 1 -w 1000 >nul 2>nul
if %errorlevel% equ 0 (
    echo Conexão com a internet restabelecida!
) else (
    echo Não foi possível restabelecer a conexão com a internet automaticamente.
    echo Você pode tentar resolver pelo Painel de Controle de Rede e Compartilhamento.
)

echo.
echo Pressione qualquer tecla para sair.
pause >nul
exit