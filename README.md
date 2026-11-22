# openbsd-x230

OpenBSD 8.0 com Xfce no ThinkPad X230: pós-instalação, revisão e PJeOffice Pro.

No OpenBSD não há só uma lista de pacotes: um script instala os programas e configura o sistema e a sessão. As listas ficam dentro do próprio script, por categoria e com a descrição de cada pacote, seguindo o `gnome.Brewfile` do repositório [brewfile](https://github.com/pedrohqb/brewfile) e os aplicativos que já vêm no Bluefin, com equivalentes para o que não existe no OpenBSD.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `openbsd-x230.sh` | Pós-instalação: aplica correções e firmware, instala os pacotes e configura serviços, energia, desempenho, Wi-Fi, teclado, TrackPoint, tela de login, aparência do Xfce, terminal e atalhos de aplicativos web |
| `revisao-openbsd.sh` | Revisão: confere pacotes, serviços, ajustes e arquivos de configuração, sem alterar nada, e lista o que falta |
| `pjeoffice-openbsd.sh` | Instala o PJeOffice Pro do CNJ na pasta pessoal, rodando no JDK 11 do OpenBSD |
| `opensc-java.c` | Biblioteca que o script do PJeOffice compila para o Java assinar com token do OpenSC |

## Uso

### 1. Instalar o OpenBSD

Grave o `install80.img` num pendrive com `dd` (o OpenBSD não inicia pelo Ventoy) e instale com o **cabo de rede ligado**, todos os conjuntos (inclusive os do X) e teclado `us`. O firmware do Wi-Fi e do vídeo é baixado no primeiro boot, por isso a rede cabeada.

### 2. Rodar a pós-instalação

Como root (`su -`), já que o `doas` ainda não está configurado; troque `pedro` pelo seu usuário:

```sh
pkg_add git
git clone https://github.com/pedrohqb/openbsd-x230.git
sh openbsd-x230/openbsd-x230.sh pedro
reboot
```

Antes de rodar, veja os **ajustes rápidos** no topo do script: rede Wi-Fi (`WIFI_SSID` e `WIFI_SENHA`), layout do painel (`LAYOUT`), tema, fontes, teclado, shell do terminal, Hyper-Threading e cache de disco. Depois de usar, apague a senha do Wi-Fi do arquivo e não a envie para o repositório.

O script pode ser executado mais de uma vez: pula os pacotes já instalados e guarda uma cópia `.orig` de cada arquivo de configuração antes da primeira alteração. Se a sessão do Xfce estiver aberta, saia dela antes, para o Xfce não sobrescrever o que o script grava.

### 3. Conferir

Com o usuário comum, sem `doas`:

```sh
sh openbsd-x230/revisao-openbsd.sh
```

### 4. PJeOffice Pro (opcional)

Com o usuário comum; o script pede a senha do `doas` só para instalar o JDK 11:

```sh
sh openbsd-x230/pjeoffice-openbsd.sh
```

O PJeOffice Pro é um programa Java, e o CNJ só o distribui para Linux, Windows e macOS. O script baixa o `.zip` de Linux do site do CNJ, confere a soma SHA256, descarta o Java embutido e o `ffmpeg` (que são para Linux) e roda o `pjeoffice-pro.jar`, sem alteração, no JDK 11 e com o `ffmpeg` do OpenBSD. Fica em `~/.local/share/pjeoffice-pro`, com atalho no menu.

Dois ajustes fazem a janela se comportar como no GNOME e no KDE:

- `-Dpjeoffice_desktop=true` pede o modo de janela, em vez do modo bandeja.
- `--patch-module` troca, só para o PJeOffice, a classe `java.awt.SystemTray` por um substituto que responde "não há bandeja". Sem isso, no Xfce a janela se recolhe para a bandeja ao ser fechada ou minimizada, e o menu da bandeja aparece em branco. O substituto é compilado na instalação e fica em `sem-bandeja/`.

As funções de vídeo usam um `ffmpeg` externo, que o PJeOffice procura na pasta do programa com o nome `ffmpeg.exe`. O script troca o binário de Linux por um atalho para `/usr/local/bin/ffmpeg`.

Situação no OpenBSD 8.0: o login no PJe e a assinatura funcionam com **certificado A1** (arquivo `.pfx`), e as funções de vídeo que só dependem do `ffmpeg` (dividir por tamanho e por duração e extrair áudio, testadas; converter e otimizar usam o mesmo caminho) também. O **corte por trechos não funciona**: ele abre um player que precisa do JavaFX, e o OpenBSD 8.0 não tem o pacote `openjfx`. No lugar dele, o script deixa um aviso com as alternativas, entre elas cortar pelo terminal com `ffmpeg -i video.mp4 -ss 00:01:30 -to 00:04:00 -c copy trecho.mp4`. O **token ePass2003** também funciona (login no PJe testado), pelo OpenSC, mas não diretamente: o OpenSC informa que as chaves RSA assinam e decifram sem cifrar, o Java 11 descarta um mecanismo informado assim, e a assinatura falha com `is not a RSAPrivateKey instance`. O script compila o `opensc-java.c`, uma biblioteca que carrega o OpenSC e só acrescenta essa marca; na configuração de certificado do PJeOffice, aba A3, indique `~/.local/share/pjeoffice-pro/opensc-java.so` (caminho completo), e não o `opensc-pkcs11.so`. Fechar a janela encerra o programa.

## O que o script configura

- **Sistema:** `syspatch`, `fw_update`, `doas` para o grupo `wheel`, grupo `_shutdown` (desligar pelo menu) e classe de login `desktop`, com limite de memória por processo de metade da RAM.
- **Energia e desempenho:** `apmd -A` (frequência automática e suspensão com 7% de bateria), suspensão ao fechar a tampa, tela bloqueada ao voltar da suspensão (pelo `/etc/apm/suspend`, para a tampa, e pela opção do Xfce, para o botão), janela de saída sem o botão de hibernar (o swap padrão é menor que a RAM), escurecimento e desligamento da tela na bateria, `noatime`, cache de disco em 40% da RAM e Hyper-Threading ligado (`hw.blockcpu=L`).
- **Entrada:** teclado inglês internacional com teclas mortas (`us`, variante `intl`) na sessão gráfica, rolagem com o botão do meio do TrackPoint e toque para clicar no touchpad.
- **Janelas:** encaixe nas bordas e nos cantos ao arrastar, Super+setas para metades, maximizar e minimizar, e Super+Espaço para abrir o menu.
- **Aparência:** tema Greybird escuro, ícones Papirus, fontes Cantarell e JetBrains Mono, tela de login sem o console e sem bipe. Com `LAYOUT="gnome"`, o painel vira uma barra superior com dock.
- **Terminal:** o Terminal do Xfce abre o fish; o shell de login (console, SSH e root) continua sendo o ksh, com histórico e autocompletar no `~/.kshrc`.
- **Aplicativos web:** atalhos para ChatGPT, Claude, Discord, Teams, WhatsApp e Zoom, porque esses serviços não têm cliente para OpenBSD. Abrem no Chromium, em janela própria, menos o Teams e o Zoom, que abrem no Firefox por causa da webcam.
- **Microfone e webcam:** gravação de áudio e de vídeo liberada no sistema, e a webcam entregue ao usuário a cada login gráfico.
- **Discos externos:** `doas mount` e `doas umount` sem senha, mais o plugin de montagem do painel.

## Observações

- **Hardware:** o script foi feito e testado num ThinkPad X230 com placa Wi-Fi Intel trocada (driver `iwm`). A placa sem fio é detectada pelo sistema, não pelo nome; o que é próprio do X230 são a rolagem do TrackPoint e, no script de revisão, o nome `iwm0` e os 4 threads esperados.
- **Sem equivalente no OpenBSD 8.0:** Claude Code, ONLYOFFICE, PDFsam Basic, BibleTime, Wine, Tessera e os drivers SafeNet, SafeSign e SerproID, que dependem de Linux. O PJeOffice Pro roda pelo script próprio (passo 4). O token ePass2003 funciona pelo OpenSC: no Firefox, carregue `/usr/local/lib/pkcs11/opensc-pkcs11.so` em Dispositivos de segurança.
- **Pacotes com variantes ou mais de uma versão:** o `pkg_add` pergunta qual instalar. No script, `nome--variante` escolhe a variante (por exemplo `keepassxc--browser`) e `nome->=N` escolhe a versão (por exemplo `gimp->=3`). O script confere cada instalação com o `pkg_info` e lista no fim o que não instalou.
- **Pendrive no painel:** o plugin só lista o que está no `/etc/fstab`. Veja o nome do pendrive com `dmesg | tail` (por exemplo `sd3`, depois dos discos internos e do volume criptografado) e registre-o: `/dev/sd3i /home/pedro/usb msdos rw,noauto,nodev,nosuid 0 0`. Feche a janela do Thunar na pasta antes de desmontar.
- **Spotify:** não há cliente que funcione no OpenBSD 8.0. O player web não toca, por falta do componente de proteção de conteúdo nos navegadores; o `spotify-qt` depende do `librespot`, que não está nos pacotes; e o `ncspot` 1.4.0 não completa o login, porque o aplicativo dele no Spotify passou a exigir outro endereço de retorno (`/ncspot_login`), o que só a versão 1.5.0 atende.
- **Webcam:** funciona no Firefox e no comando `video`. No Chromium, a câmera é detectada, mas não chega imagem; por isso os atalhos do Teams e do Zoom usam o Firefox. No ThinkPad X230, a câmera entrega 30 quadros por segundo até 640×480 e 10 em 1280×720. O aplicativo Snapshot (Câmera do GNOME) não roda, por depender do PipeWire.
- **Impressora de rede:** o OpenBSD não resolve nomes `.local` (mDNS), e não há equivalente ao `nss-mdns` do Linux. O CUPS encontra a impressora na busca, mas falha ao imprimir com "Não foi possível localizar a impressora". Reserve o IP dela no roteador e registre o nome em `/etc/hosts`, por exemplo `192.168.3.34 BRWAC50DE54C6E4.local BRWAC50DE54C6E4`; o endereço físico da impressora está no próprio nome (`BRW` + MAC), e `arp -an` mostra o IP atual. O script instala o `brlaser`, driver das lasers monocromáticas da Brother.
- **OneDrive:** o `onedrive-cli` não existe para OpenBSD; use `rclone config` e escolha "Microsoft OneDrive".
- **VPN WireGuard:** o WireGuard faz parte do sistema; o pacote `wireguard-tools` traz o `wg-quick`, que usa o mesmo arquivo `.conf` do Linux. Guarde-o como `/etc/wireguard/wg0.conf`, com dono `root` e permissão `600`, e use `doas wg-quick up wg0` e `doas wg-quick down wg0`; `doas wg show` mostra se o túnel subiu.
- **e-SAJ:** o WebSigner e o Web PKI não existem para OpenBSD. A extensão [Jamegão](https://github.com/pedrohqb/jamegao) faz o papel deles no Firefox, sem componente nativo; funciona com certificado A1 (arquivo PFX), não com token.
- **Evolution:** o `gnome-keyring` guarda as senhas e sobe com a sessão (`LaunchGNOME`). Sem PAM, o cofre pede a senha uma vez por sessão. Se uma conta do Exchange listar as pastas mas responder "Pasta inexistente" ao abrir, feche o programa e apague o cache: `evolution --force-shutdown; rm -rf ~/.cache/evolution/mail`.
- **Pastas de rede (Samba):** com o `gvfs-smb`, o Thunar abre `smb://servidor/pasta` (Ctrl+L para digitar o endereço). Pela VPN, use o endereço IP do servidor. Se o endereço ficar vermelho logo após instalar o pacote, saia e entre na sessão.

## Licença

[CC0 1.0 Universal](LICENSE): domínio público. Use à vontade.
