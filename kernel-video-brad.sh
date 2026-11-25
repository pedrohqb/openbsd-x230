#!/bin/sh
# Monta e instala um kernel do OpenBSD 8.0 com todas as errata
# oficiais do kernel e o diff do Brad Smith em video(4)/uvideo(4)/utvfu(4)
# (VIDIOC_REQBUFS(0), tech@ 19/11/2026).
# Usa só HTTPS (não precisa de anoncvs pela porta 22).
#
# Uso:    doas sh kernel-video-brad.sh
# Voltar: doas cp /obsd /bsd && doas reboot   (ou o próximo syspatch de kernel)
set -u
[ "$(id -u)" -eq 0 ] || { echo "Execute como root: doas sh $0" >&2; exit 1; }

REL="$(uname -r)"                 # 8.0
V="$(echo "$REL" | tr -d .)"      # 80
ARCH="$(machine)"                 # amd64
SITE="https://cdn.openbsd.org/pub/OpenBSD"
CHAVE="/etc/signify/openbsd-$V-base.pub"
DIFF_BRAD='https://marc.info/?l=openbsd-tech&m=179513475544929&q=raw'
TMP="$(mktemp -d /tmp/kernel-brad.XXXXXX)" || exit 1

falha() { echo "ERRO: $*" >&2; echo "Nada foi instalado. Arquivos temporários em $TMP" >&2; exit 1; }
msg() { echo; echo "==> $*"; }

[ -e /usr/src/sys ] && falha "/usr/src/sys já existe. Mova ou apague antes: doas rm -rf /usr/src/sys"
[ -r "$CHAVE" ] || falha "chave $CHAVE não encontrada"

msg "Baixando o código do kernel do $REL"
ftp -o "$TMP/SHA256.sig" "$SITE/$REL/SHA256.sig" || falha "não baixei o SHA256.sig"
ftp -o "$TMP/sys.tar.gz" "$SITE/$REL/sys.tar.gz" || falha "não baixei o sys.tar.gz"
( cd "$TMP" && signify -Cp "$CHAVE" -x SHA256.sig sys.tar.gz ) || falha "assinatura do sys.tar.gz não confere"
tar xzf "$TMP/sys.tar.gz" -C /usr/src || falha "não extraí o sys.tar.gz"

msg "Aplicando as errata oficiais do $REL que mexem no kernel"
ftp -o "$TMP/errata.tar.gz" "$SITE/patches/$REL.tar.gz" || falha "não baixei as errata"
mkdir -p "$TMP/errata" && tar xzf "$TMP/errata.tar.gz" -C "$TMP/errata" || falha "não extraí as errata"
find "$TMP/errata" -name '004_video.patch.sig' | grep -q . ||
	falha "a errata 004_video não veio no pacote de errata"
for f in $(find "$TMP/errata" \( -path "*/common/*" -o -path "*/$ARCH/*" \) -name '*.patch.sig' |
		awk -F/ '{print $NF, $0}' | sort | cut -d' ' -f2); do
	nome="$(basename "$f" .patch.sig)"
	signify -Vep "$CHAVE" -x "$f" -m "$TMP/$nome.patch" >/dev/null 2>&1 ||
		falha "assinatura de $nome não confere"
	grep -q -E '^(Index: |[-+]{3} )sys/' "$TMP/$nome.patch" || continue
	echo "    $nome"
	# -f: pula sem perguntar as partes fora de sys/ (bibliotecas, programas)
	( cd /usr/src && patch -p0 -f -s < "$TMP/$nome.patch" ) >/dev/null 2>&1 || true
done
[ -z "$(find /usr/src/sys -name '*.rej' | head -1)" ] || falha "alguma errata não entrou (arquivos .rej em /usr/src/sys)"

msg "Aplicando o diff do Brad"
ftp -o "$TMP/brad.diff" "$DIFF_BRAD" || falha "não baixei o diff do Brad"
( cd /usr/src/sys/dev && patch -C -f -s -p0 < "$TMP/brad.diff" ) ||
	falha "o diff do Brad não encaixa no $REL com as errata"
( cd /usr/src/sys/dev && patch -f -s -p0 < "$TMP/brad.diff" ) || falha "não apliquei o diff do Brad"
echo "    ok"

msg "Compilando o kernel (uns 30 a 40 minutos)"
ORIG="$(sysctl -n hw.blockcpu)"
trap 'sysctl hw.blockcpu="$ORIG" >/dev/null 2>&1' EXIT INT TERM
sysctl hw.blockcpu=L >/dev/null 2>&1     # Hyper-Threading só durante a compilação
cd "/usr/src/sys/arch/$ARCH/compile/GENERIC.MP" || falha "pasta de compilação não encontrada"
make obj >/dev/null && make config >/dev/null || falha "make obj/config"
make -j"$(sysctl -n hw.ncpuonline)" >"$TMP/make.log" 2>&1 ||
	falha "a compilação falhou; veja $TMP/make.log"
make install || falha "make install"

echo
echo "Pronto: kernel novo em /bsd; o anterior ficou em /obsd."
echo "Reinicie com: doas reboot"
echo "No boot pode aparecer um aviso de que a reordenação do kernel (KARL) foi pulada; é normal."
rm -rf "$TMP"
