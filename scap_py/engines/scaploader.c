/*
 * scaploader - chama uma DLL de performance (Embraer ELM170 / ETME2 ...)
 * que troca dados por blocos COMMON exportados.
 *
 * Carrega a DLL, copia arquivos binarios para os COMMON de entrada, chama a
 * rotina (sem argumentos) e grava os COMMON de saida em arquivos. O layout de
 * cada COMMON (REAL*4, CHARACTER*n...) fica com quem chama (Python); este
 * programa so copia bytes, entao serve para qualquer modulo nesse formato.
 *
 *   scaploader.exe DLL ROTINA [--in SIMBOLO=arquivo]... [--out SIMBOLO=bytes:arquivo]...
 *
 *   scaploader.exe ELM170v100_CAFM-20050_200.dll ELM170DLL \
 *       --in LINPN=linpn.bin --in LINPA=linpa.bin \
 *       --out LOUTN=1600:loutn.bin --out LOUTA=19515:louta.bin
 *
 * Roda pelo Wine (Linux) ou direto no Windows; a DLL e as bases sao abertas
 * a partir da pasta atual. Saida: 0 ok, 2 uso, 3 DLL, 4 simbolo, 5 arquivo.
 *
 * Compilar (Linux):  i686-w64-mingw32-gcc -O2 -s -static -o scaploader.exe scaploader.c
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void (*rotina_t)(void);

static void *simbolo(HMODULE dll, const char *nome)
{
    void *p = (void *)GetProcAddress(dll, nome);
    if (!p)
        fprintf(stderr, "scaploader: simbolo %s nao existe na DLL\n", nome);
    return p;
}

/* --in SIMBOLO=arquivo: copia o arquivo inteiro para o COMMON */
static int entrada(HMODULE dll, char *arg)
{
    char *igual = strchr(arg, '=');
    if (!igual) {
        fprintf(stderr, "scaploader: --in espera SIMBOLO=arquivo (%s)\n", arg);
        return 2;
    }
    *igual = '\0';
    void *destino = simbolo(dll, arg);
    if (!destino)
        return 4;
    FILE *f = fopen(igual + 1, "rb");
    if (!f) {
        fprintf(stderr, "scaploader: nao abri %s\n", igual + 1);
        return 5;
    }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    size_t lidos = n > 0 ? fread(destino, 1, (size_t)n, f) : 0;
    fclose(f);
    if ((long)lidos != n) {
        fprintf(stderr, "scaploader: li %lu de %ld bytes de %s\n", (unsigned long)lidos, n, igual + 1);
        return 5;
    }
    return 0;
}

/* --out SIMBOLO=bytes:arquivo: grava os primeiros bytes do COMMON */
static int saida(HMODULE dll, char *arg)
{
    char *igual = strchr(arg, '=');
    char *dois = igual ? strchr(igual + 1, ':') : NULL;
    if (!igual || !dois) {
        fprintf(stderr, "scaploader: --out espera SIMBOLO=bytes:arquivo (%s)\n", arg);
        return 2;
    }
    *igual = '\0';
    *dois = '\0';
    long n = atol(igual + 1);
    void *origem = simbolo(dll, arg);
    if (!origem)
        return 4;
    FILE *f = fopen(dois + 1, "wb");
    if (!f) {
        fprintf(stderr, "scaploader: nao criei %s\n", dois + 1);
        return 5;
    }
    fwrite(origem, 1, (size_t)n, f);
    fclose(f);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "uso: scaploader DLL ROTINA [--in SIMBOLO=arquivo]... "
                        "[--out SIMBOLO=bytes:arquivo]...\n");
        return 2;
    }
    HMODULE dll = LoadLibraryA(argv[1]);
    if (!dll) {
        fprintf(stderr, "scaploader: nao abri %s (erro %lu)\n", argv[1], GetLastError());
        return 3;
    }
    rotina_t rotina = (rotina_t)simbolo(dll, argv[2]);
    if (!rotina)
        return 4;

    for (int i = 3; i + 1 < argc; i += 2) {
        if (strcmp(argv[i], "--in") == 0) {
            int erro = entrada(dll, argv[i + 1]);
            if (erro)
                return erro;
        }
    }
    rotina();
    for (int i = 3; i + 1 < argc; i += 2) {
        if (strcmp(argv[i], "--out") == 0) {
            int erro = saida(dll, argv[i + 1]);
            if (erro)
                return erro;
        }
    }
    return 0;
}
