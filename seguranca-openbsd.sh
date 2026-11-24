#!/bin/sh
# Aplica numa instalação já feita os ajustes de segurança do openbsd-x230.sh
# (novembro de 2026), sem rodar o script inteiro de novo:
#   - desliga o Hyper-Threading (padrão do OpenBSD);
#   - limita o doas sem senha a montar e desmontar ~/usb.
# Microfone e câmera continuam liberados.
# Uso:  doas sh seguranca-openbsd.sh [usuário]
set -u
[ "$(id -u)" -eq 0 ] || { echo "Execute como root: doas sh $0 [usuário]" >&2; exit 1; }
ALVO="${1:-${DOAS_USER:-}}"
[ -n "$ALVO" ] || { echo "Indique o usuário: doas sh $0 usuário" >&2; exit 1; }
CASA="$(getent passwd "$ALVO" | cut -d: -f6)"
[ -n "$CASA" ] || { echo "Usuário $ALVO não encontrado" >&2; exit 1; }

echo "==> Hyper-Threading"
if grep -qxF "hw.blockcpu=L" /etc/sysctl.conf 2>/dev/null; then
	cp -p /etc/sysctl.conf /etc/sysctl.conf.antes-seguranca
	{ grep -vxF "hw.blockcpu=L" /etc/sysctl.conf || true; } > /etc/sysctl.conf.novo &&
		cat /etc/sysctl.conf.novo > /etc/sysctl.conf
	rm -f /etc/sysctl.conf.novo
	echo "    linha hw.blockcpu=L removida de /etc/sysctl.conf"
fi
sysctl hw.blockcpu=SL >/dev/null && echo "    desligado (threads ativos: $(sysctl -n hw.ncpuonline))"

echo "==> doas"
# A versão nova é montada à parte e só substitui a atual se passar no doas -C;
# assim um erro nunca deixa o doas inutilizável.
NOVO="$(mktemp /etc/doas.conf.XXXXXX)" || exit 1
chmod 600 "$NOVO"
{ grep -vxF -e "permit nopass $ALVO as root cmd mount" \
            -e "permit nopass $ALVO as root cmd umount" \
            -e "permit nopass $ALVO as root cmd ntfs-3g" /etc/doas.conf || true; } > "$NOVO"
for regra in "permit persist :wheel" \
             "permit nopass $ALVO as root cmd mount args $CASA/usb" \
             "permit nopass $ALVO as root cmd umount args $CASA/usb"; do
	grep -qxF "$regra" "$NOVO" || echo "$regra" >> "$NOVO"
done
if doas -C "$NOVO"; then
	cp -p /etc/doas.conf /etc/doas.conf.antes-seguranca
	cat "$NOVO" > /etc/doas.conf
	echo "    regras atuais:"
	sed 's/^/      /' /etc/doas.conf
else
	echo "    ERRO: a versão nova do doas.conf não passou na verificação; nada foi alterado" >&2
fi
rm -f "$NOVO"

echo
echo "Pronto. Cópias do estado anterior: /etc/sysctl.conf.antes-seguranca e /etc/doas.conf.antes-seguranca"
grep -q " $CASA/usb " /etc/fstab 2>/dev/null ||
	echo "Lembrete: registre o pendrive no /etc/fstab com o ponto $CASA/usb para montar sem senha."
